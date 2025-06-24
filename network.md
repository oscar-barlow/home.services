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

# Set up environment isolation firewall rules
make firewall-setup

# Remove environment isolation firewall rules
make firewall-remove

# Show current firewall status
make firewall-status

# Test firewall isolation between environments
make network-test-isolation

# Test allowed network connectivity
make network-test-connectivity
```

### Architecture

- **macvlan networks**: Separate networks for production and preprod environments
- **IP pool separation**: Each environment has its own IP range to prevent conflicts
- **Direct network access**: Containers get IPs directly on the home network
- **Network isolation**: Production and preprod services are network-isolated

## Environment Isolation

### Firewall Rules

The homelab implements network-level isolation between production and preprod environments using iptables firewall rules. This prevents cross-environment communication while maintaining internet access and host communication.

### Isolation Implementation

- **Production containers**: 192.168.1.192/27 (192.168.1.192-223)
- **Preprod containers**: 192.168.1.224/27 (192.168.1.224-249)
- **Infrastructure**: 192.168.1.250-255 (shim, future tools)

### Firewall Rules Applied

```bash
# Block preprod → prod communication
iptables -I FORWARD -s 192.168.1.224/27 -d 192.168.1.192/27 -j DROP

# Block prod → preprod communication  
iptables -I FORWARD -s 192.168.1.192/27 -d 192.168.1.224/27 -j DROP
```

### Benefits

- **Environment Isolation**: Prevents accidental prod→preprod data leaks
- **Blast Radius Containment**: Limits impact of preprod experiments
- **Network Segmentation**: Clear separation of concerns
- **Fail-Safe Operation**: Rules applied before containers start

### Persistence

Firewall rules are automatically applied during node provisioning (`make provision-node`) and can be managed independently using the firewall commands. Rules are saved to `/etc/iptables/rules.v4` for persistence across reboots.

## Network Testing

### Testing Environment Isolation

Use the network testing commands to verify that the firewall isolation is working correctly:

```bash
# Test that cross-environment communication is blocked
make network-test-isolation

# Test that allowed communication still works
make network-test-connectivity
```

### Test Requirements

Both testing commands require:
- Hello-world and pi-hole services running in both environments:
  ```bash
  make service-up ENV=prod SERVICE=hello-world
  make service-up ENV=prod SERVICE=pihole
  make service-up ENV=preprod SERVICE=hello-world
  make service-up ENV=preprod SERVICE=pihole
  ```
- Firewall rules active (`make firewall-setup`)

### Expected Results

**Isolation Test** (`network-test-isolation`):
- Production → Preprod communication should timeout and be blocked
- Preprod → Production communication should timeout and be blocked

**Connectivity Test** (`network-test-connectivity`):
- Internet access (8.8.8.8) should work from both environments
- Host access (192.168.1.204) should work from production
- Router access (192.168.1.1) should work from preprod
- Intra-environment communication should work (hello-world can reach pi-hole within same environment)