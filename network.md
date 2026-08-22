# Network Architecture

## Overview

Unified architecture using single Traefik reverse proxy with Docker Swarm overlay networking for all environments.

## Architecture Components

**Pi-hole**: Network DNS server with direct port 53 exposure
**Traefik**: Single reverse proxy instance handling all HTTP traffic
**Docker Swarm**: Overlay network for internal service communication
**Shared Network**: External `homelab-shared` overlay network for all services
**Environment Isolation**: Via service labels, not separate infrastructure

## Port Strategy

### Why This Approach

**Reverse Proxy Benefits**:
- Centralized SSL termination
- Single entry point for all HTTP services
- Automatic service discovery via Docker labels
- Domain-based routing without port numbers

**Port Exposure Rules**:
- **Traefik only**: Exposes ports 80, 443, 8080 to host
- **Special protocols**: Direct exposure only when necessary (e.g., Pi-hole DNS port 53)
- **All other services**: No direct port exposure, proxied internally

### Service Access Pattern

```
External Request → Traefik Machine → Traefik → Docker Swarm Service
```

**Examples**:
- `jellyfin.home` → Traefik:80 → jellyfin:8096 (internal)
- `pihole.home` → Traefik:80 → pihole:80 (internal)
- DNS queries → pihole:53 (direct - DNS protocol)

### Environment Separation

Both production and preprod services run in the same Docker Swarm with label-based routing:
- Production services: `service-prod` labels, accessed via `service.home`
- Preprod services: `service-preprod` labels, accessed via `service.preprod.home`
- Same Traefik instance handles both environments

## Network Configuration

### Shared Overlay Network

The `homelab-shared` network is a single external Docker overlay network that provides:
- **Two IP pools**: created with `--subnet=10.10.1.0/24 --subnet=10.10.2.0/24` (`Makefile:249`) for address headroom. These are **not** split by environment — Docker's IPAM fills `10.10.1.0/24` first and only allocates from `10.10.2.0/24` once the first pool is full, regardless of which stack a container belongs to. Confirmed via `docker network inspect homelab-shared`: `homelab-preprod_audiobookshelf` sits on `10.10.1.22` while `homelab-prod_trek` sits on `10.10.2.2` — prod and preprod containers are mixed across both pools.
- **Cross-environment connectivity**: All services communicate through single network
- **Service discovery**: Docker's built-in DNS resolution within the network — **with a collision caveat**: prod and preprod both attach services under the *same short compose name* (e.g. `jellyfin`) to this shared network, and each stack's service also registers a network alias equal to its short compose name. Confirmed via `getent hosts jellyfin` from inside a prod container (both `JELLYFIN_REPLICAS=1` in prod and preprod): the short name resolves to **both** the prod and preprod VIPs simultaneously (order not guaranteed). Only the fully-qualified Swarm service name — `homelab-${ENV_NAME}_<service>` (e.g. `homelab-prod_jellyfin`) — reliably resolves to the correct environment's VIP.
  - **The collision only occurs when both environments actually run tasks for that service name.** Confirmed via `getent hosts pihole` (1 replica in prod, `PIHOLE_REPLICAS=0` in preprod): the short name resolves to a single IP, the prod VIP only. A service scaled to 0 replicas does not register in short-name DNS answers, even though its Swarm service object (and VIP) still exists.
  - This has been harmless so far because Traefik discovers backends via the Docker/Swarm provider (container introspection + labels), not DNS name resolution — no existing service has ever relied on short-name DNS to reach another service.
  - Any service that *does* need to reach another service by hostname (first such case: Immich, `docker-swarm-stack.yml`) should use the fully-qualified `homelab-${ENV_NAME}_<service>` form rather than the bare short name, even while it's prod-only and technically safe today — this avoids relying on preprod staying at 0 replicas forever. Immich's `DB_HOSTNAME`/`REDIS_HOSTNAME` env vars use the fully-qualified form directly. Its machine-learning connection has no env var of its own — it's only settable via the Admin UI (persisted in Postgres) or via Immich's `IMMICH_CONFIG_FILE` mechanism. This repo deliberately does **not** use `IMMICH_CONFIG_FILE`: it disables *all* admin-settings UI editing while active (confirmed in `server/src/services/system-config.service.ts`'s `updateAdminConfig()`), which would get in the way of the planned Pocket ID OAuth setup (`oauth.clientSecret` has no env-var override either, so it'd have to live in that same file — and unlike the ML URL, that's a real secret with no business being a git-committed Swarm `config`). Machine-learning URL is instead a manual one-time step after first login — see the comment above `immich-machine-learning` in `docker-swarm-stack.yml`.
- **Swarm-wide availability**: Network spans all nodes in the Docker Swarm

### Network Management

```bash
# Create the shared network (run once before deploying services)
make network-up

# Remove the shared network (when decommissioning)
make network-down
```

The network must be created before deploying any services. All services in both production and preprod environments connect to this shared network.

## Docker Swarm Commands

```bash
# Initialize swarm on manager node (Pi)
make swarm-init LABEL_HARDWARE=rpi-4 LABEL_CLASS=small

# Create shared network
make network-up

# Join worker nodes
make swarm-join MANAGER_IP=192.168.1.204 TOKEN=<token>

# Deploy services
make env-up ENV=prod

# Scale services
make service-down SERVICE=jellyfin ENV=prod
```

## Future Improvements

**Split `homelab-shared` into per-environment overlay networks** (`homelab-prod` on `10.10.1.0/24`, `homelab-preprod` on `10.10.2.0/24`), rather than one shared network with two IP pools. This would fix both issues documented above at the source: real address-space separation instead of IPAM just overflowing into the second pool once the first fills, and no more short-name DNS collision between environments, since Swarm's DNS aliasing is scoped per-network — two networks means two isolated DNS namespaces. Traefik would need to join both networks (it already routes both environments from a single instance today), while every other service would only ever attach to its own environment's network. Bigger lift than it sounds: touches `Makefile`'s `network-up`/`network-down` targets, every service's `networks:` list in `docker-swarm-stack.yml`, and Traefik's `--providers.swarm.network` config — not undertaken as part of the Immich work, but worth doing before this repo accumulates more services that might someday need real inter-container DNS (Immich is the first, and had to work around the current setup with fully-qualified hostnames instead).