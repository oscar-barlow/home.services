# Remote Access

The N100 runs Tailscale and takes over the Pi's subnet-router role. Before
retiring the Pi, enable IPv4 forwarding on the N100 and advertise the actual
LAN subnet. For this LAN:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo tailscale set --advertise-routes=192.168.1.0/24
```

Persist `net.ipv4.ip_forward=1` through the N100's system sysctl configuration,
and approve the advertised route in the Tailscale admin console. Verify access
to another LAN device remotely while the Pi is powered off before considering
the migration complete. The laptop's accepted subnet routes can otherwise
continue using the Pi even after service migration.

Update the tailnet's DNS resolver from the Pi to the N100's primary LAN IP
only after Pi-hole is verified. Public DNS remains useful during cutover but
cannot resolve private `lan.barlows.cool` records.

On the laptop, if temporary DNS bypass was used:

```bash
sudo tailscale set --accept-dns=true
```

Also restore any temporary per-interface public DNS override, or reconnect the
network to obtain the router's updated DHCP DNS configuration. Keep subnet
route acceptance configured for whether the laptop is at home or remote.
