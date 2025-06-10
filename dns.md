# DNS Management

This document explains how to manage DNS configuration in your homelab setup.

## Overview

DNS configuration is managed through static configuration files located in the `dns/` directory. Each environment (prod, preprod, etc.) has its own DNS configuration file that gets mounted directly into the Pi-hole container.

The setup uses Docker's macvlan networking to assign containers static IP addresses on your local network. For detailed network architecture, see [network.md](network.md).

## Directory Structure

```
dns/
├── example/
│   └── custom-dns.conf    # Example configuration (tracked in git)
├── prod/
│   └── custom-dns.conf    # Production DNS config (ignored by git)
└── preprod/
│   └── custom-dns.conf    # Pre-production DNS config (ignored by git)
```

## How It Works

1. **Container Networking**: Each service container gets a static IP on your LAN via macvlan (see [network.md](network.md))
2. **DNS Mounting**: The `docker-compose.application.yml` file mounts the appropriate DNS config based on the `ENV_NAME` environment variable:
   ```yaml
   - './dns/${ENV_NAME}/custom-dns.conf:/etc/dnsmasq.d/02-custom-dns.conf'
   ```
3. **Environment Selection**: When you start services with `docker-compose --env-file env/.env.prod up`, it automatically uses the production DNS config and IPs
4. **Direct Resolution**: Pi-hole resolves domain names to the static IPs assigned to containers

## Managing DNS Records

### Adding New Services

To add a new service to your DNS:

1. **Choose an available IP** from your environment's IP range (see [network.md](network.md) for allocations)
2. **Update the environment file** with the new service's IP:
   ```bash
   vim env/.env.prod
   ```
   Add: `NEW_SERVICE_IP=192.168.1.196`

3. **Edit the DNS configuration**:
   ```bash
   vim dns/prod/custom-dns.conf
   ```
   Add: `address=/newservice.home/192.168.1.196`

4. **Update docker-compose.application.yml** to assign the static IP:
   ```yaml
   newservice:
     networks:
       homelab_macvlan:
         ipv4_address: ${NEW_SERVICE_IP}
   ```

5. **Restart services**:
   ```bash
   make service-up SERVICE=pihole
   ```

### Configuration Format

The `custom-dns.conf` file uses dnsmasq configuration syntax:

```bash
# Set local domain
local=/home/

# Ignore reverse DNS for private ranges
bogus-priv

# Service DNS records - map hostnames to static container IPs
address=/jellyfin.home/192.168.1.193
address=/pi.hole.home/192.168.1.192
```

### Environment-Specific Domains

- **Production**: Uses `.home` domain (e.g., `jellyfin.home`)
- **Pre-production**: Uses `.preprod.home` domain (e.g., `jellyfin.preprod.home`)

For IP ranges, see [network.md](network.md).

## Creating New Environments

To add a new environment:

1. **Plan IP allocation** using ranges from [network.md](network.md)
2. **Create the DNS directory**:
   ```bash
   mkdir dns/staging
   ```
3. **Create the DNS configuration**:
   ```bash
   cp dns/example/custom-dns.conf dns/staging/custom-dns.conf
   vim dns/staging/custom-dns.conf
   ```
4. **Create the environment file**:
   ```bash
   cp env/.env.example env/.env.staging
   vim env/.env.staging
   ```
5. **Set environment-specific values** including `ENV_NAME=staging` and unique IP addresses

## Troubleshooting

### DNS Not Working

1. **Check if the config file exists:**
   ```bash
   ls -la dns/${ENV_NAME}/custom-dns.conf
   ```

2. **Verify container has correct IP:**
   ```bash
   docker inspect pihole-${ENV_NAME} | grep IPAddress
   ```

3. **Verify the container mount:**
   ```bash
   docker exec pihole-${ENV_NAME} cat /etc/dnsmasq.d/02-custom-dns.conf
   ```

4. **Check dnsmasq logs:**
   ```bash
   docker logs pihole-${ENV_NAME} | grep dnsmasq
   ```

5. **Restart Pi-hole:**
   ```bash
   docker-compose restart pihole
   ```

### Network Connectivity Issues

For network troubleshooting, see [network.md](network.md).

### Testing DNS Resolution

```bash
# Test from your local machine
nslookup jellyfin.home 192.168.1.192

# Test from inside the Pi-hole container
docker exec pihole-${ENV_NAME} nslookup jellyfin.home localhost

# Test direct container access
curl http://192.168.1.193:8096  # Direct Jellyfin access
```

## Git Management

- Only `dns/example/` is tracked in git
- All other environment-specific configs are ignored  
- This keeps sensitive production IPs out of version control
- Use the example as a template for new environments