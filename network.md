# Network Architecture Overview
## Infrastructure

* Router - Standard home router with DHCP
* Raspberry Pi (192.168.1.204) - Primary homelab node
* N100 Machine (192.168.1.10) - High-performance compute node
* macvlan shim (192.168.1.254) - Gives containers their own IPs in the network

## Network Design
### IP Address Allocation
Router DHCP Range:    192.168.1.2 - 192.168.1.191
Container Subnet:     192.168.1.192/26 (192.168.1.192-255)
├── Production:       192.168.1.192/27 (192.168.1.192-223)
└── Preproduction:    192.168.1.224/27 (192.168.1.224-255)