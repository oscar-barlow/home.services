# DNS Management

This document explains how to manage DNS configuration in your Docker Swarm homelab setup.

## Overview

DNS configuration is managed through version-controlled files in this repository. A single `dns/custom-dns.conf` file defines the DNS routing for both production and preprod environments using Traefik reverse proxy architecture.

The setup uses Docker Swarm overlay networks with Traefik reverse proxies handling service routing. For detailed network architecture, see [network.md](network.md).

## Configuration Structure

DNS configuration is stored in the repository and mounted to Pi-hole:

```
dns/
└── custom-dns.conf    # Single DNS config for all environments
```

This file gets mounted to both production and preprod Pi-hole instances via:
```yaml
- './dns/custom-dns.conf:/etc/dnsmasq.d/02-custom-dns.conf'
```

## How It Works

1. **Version-Controlled DNS**: Single DNS config file tracked in git
2. **Traefik Routing**: DNS routes domains to Traefik instances, Traefik routes to services
3. **Environment Separation**: Different domains route to different Traefik instances
   - `*.home` → Pi (192.168.1.204) → Production Traefik
   - `*.preprod.home` → N100 (192.168.1.11) → Preprod Traefik

## Managing DNS Records

### Current Configuration

The `dns/custom-dns.conf` file contains:

```bash
local=/home/
local=/preprod.home/

bogus-priv

# Production environment - all services route to Pi where Traefik runs
address=/home/192.168.1.204

# Preprod environment - all services route to N100 where Traefik runs  
address=/preprod.home/192.168.1.11
```

### Adding New Services

With the Traefik architecture, adding new services requires **no DNS changes**:

1. **Add service to docker-swarm-stack.yml** with appropriate Traefik labels
2. **Deploy the service**: `make env-up ENV=prod`
3. **Access via subdomain**: `newservice.home` automatically routes to the service

Traefik handles service discovery and routing automatically - no manual DNS records needed.

### Configuration Format

The DNS configuration uses dnsmasq wildcard routing:

- `local=/home/` - Defines `.home` as local domain
- `local=/preprod.home/` - Defines `.preprod.home` as local domain  
- `address=/home/192.168.1.204` - Routes all `.home` subdomains to Pi
- `address=/preprod.home/192.168.1.11` - Routes all `.preprod.home` subdomains to N100

### Environment-Specific Domains

- **Production**: Uses `.home` domain (e.g., `jellyfin.home`)
- **Pre-production**: Uses `.preprod.home` domain (e.g., `jellyfin.preprod.home`)

All subdomains automatically route to the appropriate Traefik instance.

## Creating New Environments

To add a new environment (e.g., staging):

1. **Add DNS routing** to `dns/custom-dns.conf`:
   ```bash
   local=/staging.home/
   address=/staging.home/192.168.1.12  # Choose available IP
   ```

2. **Create environment file**:
   ```bash
   cp env/.env.example env/.env.staging
   vim env/.env.staging
   ```

3. **Set environment-specific values** including `ENV_NAME=staging`

4. **Create storage directories**:
   ```bash
   sudo mkdir -p /srv/data/staging/
   ```

5. **Deploy staging Traefik** on the chosen node

No individual service DNS records needed - all services automatically work via `service.staging.home`.

## Troubleshooting

### DNS Not Working

1. **Check if the config file is mounted:**
   ```bash
   # Get Pi-hole container ID
   docker service ps homelab-${ENV_NAME}_pihole
   docker exec <container-id> cat /etc/dnsmasq.d/02-custom-dns.conf
   ```

2. **Verify DNS resolution:**
   ```bash
   # Test from your local machine
   nslookup jellyfin.home 192.168.1.204  # Production Pi-hole
   nslookup jellyfin.preprod.home 192.168.1.11  # Preprod Pi-hole
   ```

3. **Check service logs:**
   ```bash
   docker service logs homelab-${ENV_NAME}_pihole
   ```

4. **Restart Pi-hole:**
   ```bash
   make service-down SERVICE=pihole ENV=${ENV_NAME}
   make env-up ENV=${ENV_NAME}
   ```

### Traefik Not Routing

1. **Check Traefik dashboard** (if enabled)
2. **Verify service labels** in docker-swarm-stack.yml
3. **Check Traefik logs** for routing issues

### Testing Access

```bash
# Test DNS resolution
nslookup jellyfin.home

# Test end-to-end access
curl -H "Host: jellyfin.home" http://192.168.1.204
```

## Version Control

The DNS configuration is now version-controlled in this repository:

- **File**: `dns/custom-dns.conf`
- **Changes**: Commit changes to DNS config like any other code
- **Deployment**: Changes take effect when Pi-hole restarts
- **Rollback**: Use git to revert DNS changes if needed

This approach provides full change tracking and rollback capability for DNS configuration.