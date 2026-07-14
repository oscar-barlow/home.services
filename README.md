# Home Services

A collection of containerized services for a home network environment.

## Services

### NGINX
- Reverse proxy on port 80 (HTTP)
- Configuration templated from `nginx/nginx.conf.template`
- Routes requests to backend services by hostname

### Pi-hole
- DNS filtering and ad blocking
- Web interface proxied via NGINX at `pihole.home`
- DNS services on port 53 (TCP/UDP)
- Custom DNS configurations via `02-custom-dns.conf`
- Log rotation configured (10M max size, 3 files)

### Jellyfin
- Media server proxied via NGINX at `jellyfin.home`
- Access to media directories:
  - Music
  - Movies
  - TV
  - ChildrensMovies
  - ChildrensClips
  - ChildrensTV
  - Classical
- Configuration persisted in `/srv/data/${ENV}/jellyfin/config`

### Audiobookshelf
- Audiobook server proxied via NGINX at `audiobookshelf.home`

### Kavita
- Book/comic reader proxied via NGINX at `kavita.home`

### Wiki.js
- Wiki proxied via NGINX at `wiki.home`

### Release Manager
- Deployment manager proxied via NGINX at `release-manager.home`

## Network

Services run on a Docker Swarm overlay network (`homelab-shared`). Pi-hole provides DNS resolution, mapping all `*.home` hostnames to the node running NGINX. NGINX then routes by `Host` header to the correct backend service.

### Network Management

```bash
# Create shared Docker overlay network (one-time setup)
make network-up

# Remove shared Docker overlay network
make network-down
```

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
# Create shared network first (one-time)
make network-up

# Start all services for preprod environment (default)
make env-up

# Start all services for production environment
make env-up ENV=prod

# Stop services
make env-down

# Stop services for specific environment
make env-down ENV=prod
```

### Service Management

```bash
# Stop specific service
make service-down SERVICE=jellyfin

# Stop specific service in production
make service-down ENV=prod SERVICE=jellyfin
```

## Resilience

All services use the `on-failure` restart policy to automatically recover from crashes.