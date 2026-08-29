# Home Services

A collection of containerized services for a home network environment.

## Services

### Nginx
- Reverse proxy on ports 80 (HTTP) and 443 (HTTPS)
- Configuration in `./nginx/conf.d`
- SSL certificates in `./nginx/certs`

### Pi-hole
- DNS filtering and ad blocking
- Web interface on port 81
- DNS services on port 53 (TCP/UDP)
- Custom DNS configurations via `custom-dns.conf`
- Log rotation configured (10M max size, 3 files)

### Jellyfin
- Media server using host networking
- Access to media directories:
  - Music
  - Movies
  - Books
  - ChildrensMovies
- Configuration persisted in `./jellyfin/config`

### Home Assistant
- Home automation platform
- Web interface on port 8123, proxied by Traefik at `home-assistant.${DOMAIN_SUFFIX}`
- Configuration persisted in `/srv/data/${ENV_NAME}/home-assistant/config`
- Runs on `n100` hardware
- Reverse proxy: because HA sits behind Traefik it returns `400: Bad Request`
  to proxied requests until the proxy is trusted. HA owns and rewrites its own
  `configuration.yaml` and `.storage/` files (the UI edits them), so these are
  edited in place on the node rather than shipped from this repo. Add an
  `http:` block to `configuration.yaml`:

  ```yaml
  http:
    use_x_forwarded_for: true
    trusted_proxies:
      # Trust the whole Docker-internal address space. HA validates every hop
      # in the X-Forwarded-For chain, and the Traefik->HA hop can appear on the
      # overlay (10.10.x), the swarm ingress mesh (10.0.0.x) or docker_gwbridge
      # (172.18.x) depending on path — a single subnet leaves some requests 400.
      # Safe because HA has no published port, so only Traefik can reach it.
      - 10.0.0.0/8
      - 172.16.0.0/12
      - 127.0.0.1
  ```

  As of HA 2026.8 this block is migrated into `.storage/http` **once, on first
  boot**, then ignored — so it must be present before HA first starts. If HA
  already booted without it (migration ran empty, so you see the 400), reset
  just the http store so the block re-migrates on restart (once HA is
  reachable you can instead edit trusted proxies in the UI under
  **Settings > System > Network > HTTP server**, which writes the store
  directly):

  ```bash
  docker service scale homelab-${ENV}_home-assistant=0
  sudo rm /srv/data/${ENV}/home-assistant/config/.storage/http
  docker service scale homelab-${ENV}_home-assistant=1
  ```

## Network

Services use macvlan networking to get direct IP addresses on the local network. The network infrastructure is managed separately from application services.

A systemd service (`homelab-shim.service`) creates a network shim that enables the host to communicate with containers on macvlan networks. This shim is essential because Docker's macvlan isolation normally prevents host-to-container communication.

### Network Management

```bash
# Install systemd network shim service (one-time setup)
make install-shim

# Start network infrastructure (required before services)
make network-up

# Stop network infrastructure
make network-down
```

See [network.md](network.md) for detailed network architecture and IP allocation.

### SSH Access
See [ssh.md](ssh.md) for information about remote access to homelab nodes.

### Storage
See [storage.md](storage.md) for storage architecture and permissions model.

## Node Provisioning

For complete homelab node setup:

```bash
# Provision a new homelab node
make provision-node
```

This command runs:
1. User and group creation
2. Systemd shim installation  
3. User verification

### Docker Swarm Setup

Initialize or join Docker Swarm with hardware labels for proper service placement:

```bash
# Initialize swarm manager with hardware labels
make swarm-init LABEL_HARDWARE=n100 LABEL_CLASS=medium

# Join as worker with hardware labels
make swarm-join MANAGER_IP=192.168.1.10 TOKEN=SWMTKN-... LABEL_HARDWARE=rpi-4 LABEL_CLASS=small
```

See [hardware.md](hardware.md) for detailed hardware specifications, installation guides, and standardized labeling conventions.

## Usage

```bash
# One-time setup: Install systemd network shim
make install-shim

# Start network infrastructure first
make network-up

# Start all services for preprod environment (default)
make env-up

# Start all services for production environment
make env-up ENV=prod

# Stop services
make env-down

# Stop services for specific environment
make env-down ENV=prod

# Stop network infrastructure
make network-down
```

### Service Management

```bash
# Start specific service
make service-up SERVICE=jellyfin

# Start specific service in production
make service-up ENV=prod SERVICE=jellyfin

# Stop specific service
make service-down SERVICE=jellyfin
```

## Resilience

All services use the `unless-stopped` restart policy to automatically recover from crashes.