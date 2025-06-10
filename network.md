# Network Architecture Overview
## Infrastructure

* Router - Standard home router with DHCP
* Raspberry Pi (192.168.1.204) - Primary homelab node
* N100 Machine (192.168.1.10) - High-performance compute node
* macvlan shim (192.168.1.254) - Gives containers their own IPs in the network

## Network Design
### IP Address Allocation
DHCP Range (dynamic devices):     192.168.1.2 - 192.168.1.191
Container Ranges:
├── Production:                   192.168.1.192 - 192.168.1.223 (/27)
└── Preprod:                     192.168.1.224 - 192.168.1.249 (/27)

Infrastructure (reserved):        192.168.1.250 - 192.168.1.255
├── macvlan shim:                192.168.1.254
└── Future network tools:        192.168.1.250 - 192.168.1.253

## Network Management

The network infrastructure is managed separately from application services using macvlan networks that provide containers with direct IP addresses on the local network.

### Commands

```bash
# Start network infrastructure (creates macvlan networks)
make network-up

# Stop network infrastructure  
make network-down

# Start services (requires network to be up first)
make env-up [ENV=prod|preprod]

# Stop services
make env-down [ENV=prod|preprod]
```

### Architecture

- **macvlan networks**: Separate networks for production and preprod environments
- **IP pool separation**: Each environment has its own IP range to prevent conflicts
- **Direct network access**: Containers get IPs directly on the home network
- **Network isolation**: Production and preprod services are network-isolated