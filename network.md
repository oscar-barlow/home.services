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

### Systemd Network Shim

A network "shim" is an intermediary layer that bridges communication between different network segments. In this homelab setup, the `homelab-shim.service` systemd unit creates a persistent macvlan interface that acts as a gateway between the host system and containerized services.

**Why a shim is needed:**
- Docker's macvlan networks isolate containers from the host by default
- The host cannot directly communicate with containers on macvlan networks
- The shim creates a bridge interface that enables host-to-container communication
- Without the shim, the host would be unable to reach services running in containers

The service runs four commands in sequence to establish this bridge:

1. **Create macvlan interface**: `ip link add homelab-shim link eth0 type macvlan mode bridge`
   - Creates a macvlan interface named "homelab-shim" linked to the host's eth0 interface
   - Uses bridge mode to allow communication between macvlan interfaces

2. **Assign IP address**: `ip addr add 192.168.1.254/32 dev homelab-shim`
   - Assigns the reserved IP address 192.168.1.254 to the shim interface
   - Uses /32 subnet mask (single host) - this IP acts as the host's presence on the container network

3. **Bring interface up**: `ip link set homelab-shim up`
   - Activates the network interface

4. **Add routing**: `ip route add 192.168.1.192/26 dev homelab-shim`
   - Routes the container subnet (192.168.1.192-255) through the shim interface
   - Tells the host kernel how to reach container IPs

The service automatically starts after network initialization and removes the interface on stop (`ExecStop=/sbin/ip link del homelab-shim`).

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