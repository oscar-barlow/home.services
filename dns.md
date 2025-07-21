# DNS Management

Unified DNS architecture using single Pi-hole instance with Traefik reverse proxy for all environments.

## Architecture Overview

**Single Pi-hole**: Handles DNS for all environments with direct port 53 exposure
**Single Traefik**: Reverse proxy on production node routing all HTTP traffic
**Unified Swarm**: All environments run in same Docker Swarm with label-based routing

## How It Works

1. All domains (`*.home`, `*.preprod.home`) route to the machine running Traefik
2. Pi-hole provides DNS resolution, Traefik handles HTTP routing
3. Traefik uses service labels with `${ENV_NAME}` suffix for environment separation
4. Services distinguished by labels: `service-prod` vs `service-preprod`

## Port Strategy

**Pi-hole**:
- Port 53 (DNS): Direct exposure (DNS protocol requirement)  
- Web interface: HTTP proxied through Traefik

**All other services**: HTTP traffic proxied through Traefik on ports 80/443

**Why this architecture**:
- Centralized DNS and reverse proxy management
- Environment isolation via service labels, not infrastructure
- Simplified networking with single entry point

## DNS Configuration

DNS uses wildcard domain routing - both `*.home` and `*.preprod.home` resolve to the same machine where Traefik is running. Environment separation happens at the Traefik routing layer using service labels.

### Adding New Services

No DNS changes needed:

1. Add service to `docker-swarm-stack.yml` with Traefik labels including `${ENV_NAME}`
2. Deploy: `make env-up ENV=prod` or `make env-up ENV=preprod` 
3. Access automatically via `service.home` or `service.preprod.home`

### Adding New Environments

1. Add domain to DNS config routing to the Traefik machine
2. Create environment file: `env/.env.newenv` with `ENV_NAME=newenv`
3. Deploy: `make env-up ENV=newenv`

All services automatically work via `service.newenv.home` - Traefik handles routing based on service labels.

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