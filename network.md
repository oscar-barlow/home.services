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

The `homelab-shared` network is an external Docker overlay network that provides:
- **Multi-subnet support**: 10.10.1.0/24 (prod) and 10.10.2.0/24 (preprod)
- **Cross-environment connectivity**: All services communicate through single network
- **Service discovery**: Docker's built-in DNS resolution within the network
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