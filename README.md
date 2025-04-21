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

All services use a bridge network named `local_network` except Jellyfin, which uses host networking for performance.

## Usage

```bash
# Start all services in detached mode
docker-compose up -d

# View logs
docker-compose logs

# Stop all services
docker-compose down

# Rebuild containers
docker-compose build
# or
make build
```

## Resilience

All services use the `unless-stopped` restart policy to automatically recover from crashes.