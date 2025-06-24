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