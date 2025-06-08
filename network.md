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