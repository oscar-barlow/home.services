# Network Testing Guide

This guide contains the testing procedure for verifying VEPA mode macvlan isolation works correctly.

## Current Status

We've switched from macvlan bridge mode to VEPA mode to enable proper isolation between production and preprod environments while maintaining intra-environment communication.

### What Changed
- **Macvlan mode**: Changed from `bridge` to `vepa` in `homelab-shim.service`
- **Firewall approach**: Reverted from ebtables back to iptables
- **Traffic path**: Container traffic now goes Container → Router → Container, allowing iptables to filter it

## Testing Procedure

### Prerequisites
- Clean state verified (no existing isolation rules)
- Containers stopped
- Updated code pulled from `migrate/network-environment-segregation` branch

### Step 1: Stop Containers
```bash
make env-down ENV=prod
make env-down ENV=preprod
```

### Step 2: Restart Shim with VEPA Mode
```bash
sudo systemctl stop homelab-shim.service
sudo systemctl start homelab-shim.service
```

Verify VEPA mode is active:
```bash
i'm 
```

### Step 3: Set Up Firewall Rules
```bash
make firewall-setup
make firewall-status
```

Expected output: iptables rules at position 1 and 2 blocking cross-environment traffic.

### Step 4: Start Test Containers
```bash
make service-up ENV=prod SERVICE=hello-world
make service-up ENV=prod SERVICE=pihole
make service-up ENV=preprod SERVICE=hello-world
make service-up ENV=preprod SERVICE=pihole
```

### Step 5: Test Isolation
```bash
make network-test-isolation
```

**Expected Results:**
- ✅ Prod → Preprod should timeout and be blocked
- ✅ Preprod → Prod should timeout and be blocked

### Step 6: Test Connectivity (Optional)
```bash
make network-test-connectivity
```

**Expected Results:**
- ✅ Internet access works from both environments
- ✅ Host access works
- ✅ Intra-environment communication works (hello-world ↔ pihole within same env)

## Debugging

If isolation still doesn't work:

### Check Traffic is Going Through iptables
```bash
# Reset counters
sudo iptables -Z

# Run a test ping
docker exec hello-world-prod ping -c 1 192.168.1.226

# Check which rules got hit
sudo iptables -L FORWARD -v -n | head -10
```

Look for non-zero packet counts on the DROP rules.

### Check Container IPs
```bash
docker inspect hello-world-prod | grep IPAddress
docker inspect hello-world-preprod | grep IPAddress
```

Verify they're in the expected ranges:
- Production: 192.168.1.192/27 (192.168.1.192-223)
- Preprod: 192.168.1.224/27 (192.168.1.224-249)

### Check VEPA Mode
```bash
ip link show homelab-shim
```

### Fallback: Check Router Support
If VEPA mode doesn't work, it might be because your router doesn't support VEPA (hairpin/reflection). In that case, we may need to consider:
- Router configuration changes
- Alternative networking approaches
- Accepting same-host communication limitation

## Notes

- VEPA mode requires the external switch (router) to support hairpin/reflection
- If VEPA doesn't work, we learned that macvlan bridge mode bypasses all kernel filtering
- The goal is cross-environment isolation while preserving intra-environment communication