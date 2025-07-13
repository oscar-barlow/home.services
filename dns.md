# DNS Management

This document explains how to manage DNS configuration in your Docker Swarm homelab setup.

## Overview

DNS configuration is managed through static configuration files located in `/srv/data/${ENV_NAME}/pihole/etc/dnsmasq.d/` on your shared storage. Each environment (prod, preprod, etc.) has its own DNS configuration that gets mounted directly into the Pi-hole container via Docker Swarm.

The setup uses Docker's macvlan networking to assign containers static IP addresses on your local network. For detailed network architecture, see [network.md](network.md).

## Directory Structure

DNS configuration is stored in shared storage accessible by all swarm nodes:

```
/srv/data/
├── prod/
│   └── pihole/
│       └── etc/
│           └── dnsmasq.d/           # Production DNS configs
│               └── 02-custom-dns.conf  # Custom DNS records
└── preprod/
    └── pihole/
        └── etc/
            └── dnsmasq.d/           # Pre-production DNS configs
                └── 02-custom-dns.conf  # Custom DNS records
```

## How It Works

1. **Container Networking**: Each service container gets a static IP on your LAN via macvlan (see [network.md](network.md))
2. **DNS Mounting**: The `docker-swarm-stack.yml` file mounts the entire dnsmasq.d directory:
   ```yaml
   - '/srv/data/${ENV_NAME}/pihole/etc/dnsmasq.d:/etc/dnsmasq.d'
   ```
3. **Direct Resolution**: Pi-hole resolves domain names to the static IPs assigned to containers

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
   sudo vim /srv/data/prod/pihole/etc/dnsmasq.d/02-custom-dns.conf
   ```
   Add: `address=/newservice.home/192.168.1.196`

4. **Update docker-swarm-stack.yml** to assign the static IP:
   ```yaml
   newservice:
     networks:
       homelab-macvlan:
         ipv4_address: ${NEW_SERVICE_IP}
   ```

5. **Restart services**:
   ```bash
   make env-down ENV=prod
   make env-up ENV=prod
   ```

### Configuration Format

The `02-custom-dns.conf` file uses dnsmasq configuration syntax:

```bash
# Set local domain
local=/home/

# Ignore reverse DNS for private ranges
bogus-priv

# Service DNS records - map hostnames to static container IPs
address=/jellyfin.home/192.168.1.225
address=/pihole.home/192.168.1.224
address=/hello.home/192.168.1.226
```

### Environment-Specific Domains

- **Production**: Uses `.home` domain (e.g., `jellyfin.home`)
- **Pre-production**: Uses `.preprod.home` domain (e.g., `jellyfin.preprod.home`)

For IP ranges, see [network.md](network.md).

## Creating New Environments

To add a new environment:

1. **Plan IP allocation** using ranges from [network.md](network.md)
2. **Create the DNS directory structure**:
   ```bash
   sudo mkdir -p /srv/data/staging/pihole/etc/dnsmasq.d
   ```
3. **Copy DNS configuration from existing environment**:
   ```bash
   sudo cp /srv/data/prod/pihole/etc/dnsmasq.d/02-custom-dns.conf /srv/data/staging/pihole/etc/dnsmasq.d/
   sudo vim /srv/data/staging/pihole/etc/dnsmasq.d/02-custom-dns.conf
   ```
4. **Create the environment file**:
   ```bash
   cp env/.env.example env/.env.staging
   vim env/.env.staging
   ```
5. **Set environment-specific values** including `ENV_NAME=staging` and unique IP addresses
6. **Set correct permissions**:
   ```bash
   # If staging uses UID/GID 7001:7001 (adjust as needed)
   sudo chown -R 7001:7001 /srv/data/staging/
   ```

## Troubleshooting

### DNS Not Working

1. **Check if the config file exists:**
   ```bash
   sudo ls -la /srv/data/${ENV_NAME}/pihole/etc/dnsmasq.d/02-custom-dns.conf
   ```

2. **Verify container has correct IP:**
   ```bash
   docker service ps homelab-${ENV_NAME}_pihole
   ```

3. **Verify the container mount:**
   ```bash
   # Get container ID from docker service ps output
   docker exec <container-id> cat /etc/dnsmasq.d/02-custom-dns.conf
   ```

4. **Check service logs:**
   ```bash
   docker service logs homelab-${ENV_NAME}_pihole
   ```

5. **Restart Pi-hole:**
   ```bash
   make env-down ENV=${ENV_NAME}
   make env-up ENV=${ENV_NAME}
   ```

### Network Connectivity Issues

For network troubleshooting, see [network.md](network.md).

### Testing DNS Resolution

```bash
# Test from your local machine (assuming Pi-hole IP is 192.168.1.224)
nslookup jellyfin.home 192.168.1.224

# Test direct container access
curl http://192.168.1.225:8096  # Direct Jellyfin access
```

## Docker Swarm Considerations

- **Shared Storage**: DNS configs must be accessible from all swarm nodes via `/srv/data/`
- **Node Placement**: Pi-hole is constrained to run on `rpi-3` hardware via placement constraints
- **Service Management**: Use `make env-up/env-down` instead of docker-compose commands
- **Configuration Changes**: Require service restart to take effect

## Backup and Migration

DNS configurations are automatically backed up as part of your `/srv/data/` shared storage backup strategy. When migrating between environments or nodes, ensure:

1. `/srv/data/${ENV_NAME}/` contains all necessary DNS configs
2. Correct ownership permissions are set for the environment's UID/GID
3. Network configuration matches IP allocations in DNS records