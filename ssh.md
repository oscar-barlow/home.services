## Tailscale Setup for Remote Homelab Access

### Device Configuration

**Pi (Subnet Router):**
```bash
sudo tailscale up --advertise-routes=192.168.1.0/24
```
- Advertises your home network to other Tailscale devices
- Allows remote devices to reach local services and devices
- Runs continuously

**Geekom (Home Device):**
```bash
sudo tailscale up
```
- Basic Tailscale connectivity only
- No route handling needed since it's always at home
- Can be reached remotely via Tailscale IP

**Laptop (Roaming Device):**

*When at home:*
```bash
sudo tailscale up --reset
```

*When away from home:*
```bash
sudo tailscale up --accept-routes
```

### Why This Works

- **Pi advertises routes** so remote devices know how to reach your home network (192.168.1.0/24)
- **Laptop accepts routes only when away** to avoid routing conflicts when already on the home network
- **--reset is crucial** to clear any previous route configurations that could cause local network conflicts
- **Geekom needs no special config** since it's always local and just needs to be reachable

### Usage Patterns

- **At home:** Use local IPs (192.168.1.x) for everything
- **Remote:** Use Tailscale IPs (100.x.x.x) or local IPs (which route through Pi)
- **DNS:** Works automatically via Pi-hole at 192.168.1.192 when remote