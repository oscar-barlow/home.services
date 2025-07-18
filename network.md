# Network Architecture Overview
## Infrastructure

* Router - Standard home router with DHCP
* Raspberry Pi (192.168.1.204) - Primary homelab node running Traefik reverse proxy
* N100 Machine (192.168.1.11) - High-performance compute node
* Docker Swarm - Overlay network for internal service communication

## Network Design

### Dual-Environment Architecture with Traefik

The homelab uses a dual-environment architecture with separate Traefik instances:

**Production Environment (.home domain):**
- **Location**: Raspberry Pi (192.168.1.204)
- **Traefik Instance**: Production Traefik on Pi
- **DNS**: `*.home` → 192.168.1.204
- **Services**: Production services with stable configurations

**Preprod Environment (.preprod.home domain):**
- **Location**: N100 Machine (192.168.1.11)  
- **Traefik Instance**: Preprod Traefik on N100
- **DNS**: `*.preprod.home` → 192.168.1.11
- **Services**: Development/testing services

### Benefits of This Approach

- **Complete Environment Isolation**: Production and preprod are completely separate
- **Safe Experimentation**: Can test new configurations without affecting production
- **Independent Traefik Configs**: Each environment can have different Traefik settings
- **Clear Service Organization**: Easy to understand which environment you're accessing
- **Automatic Service Discovery**: Traefik discovers services via Docker Swarm labels
- **SSL Termination**: Each Traefik instance handles SSL for its domain

### Service Access Patterns

**Production Services:**
```
External Request → Pi (192.168.1.204) → Production Traefik → Docker Swarm Service
```
- `jellyfin.home` → Pi IP → Production Traefik → Production Jellyfin
- `pihole.home` → Pi IP → Production Traefik → Production Pi-hole

**Preprod Services:**
```
External Request → N100 (192.168.1.11) → Preprod Traefik → Docker Swarm Service  
```
- `jellyfin.preprod.home` → N100 IP → Preprod Traefik → Preprod Jellyfin
- `pihole.preprod.home` → N100 IP → Preprod Traefik → Preprod Pi-hole

## Docker Swarm Commands

```bash
# Initialize swarm on manager node (Pi)
make swarm-init LABEL_HARDWARE=rpi-4 LABEL_CLASS=small

# Join worker nodes
make swarm-join MANAGER_IP=192.168.1.204 TOKEN=<token>

# Deploy services
make env-up ENV=prod

# Scale services
make service-down SERVICE=jellyfin ENV=prod
```