# DNS Management

One production Pi-hole container serves both environments on the N100. Its
TCP/UDP port 53 is published on `N100_LAN_IP` and `DNS_SECONDARY_IP`. These must
be two distinct addresses assigned to the N100's LAN interface. Reserve both
outside the router's dynamic DHCP allocation. Persist the secondary address
using the N100's existing network configuration before switching router DNS.

Set both values in the ignored `env/.env.local`, starting from
`env/.env.local.example`. The second address belongs to the N100 host; no
macvlan network or separate Pi-hole container IP is required. Explicit address
binding avoids claiming a loopback DNS listener such as systemd-resolved's
`127.0.0.53:53`.

## Local names

The `pihole_custom_dns` config in `compose.yaml` defines wildcard records for
`home`, `preprod.home`, `lan.barlows.cool` and `preprod.lan.barlows.cool`. All
point to `N100_LAN_IP`. Traefik distinguishes environments using host rules.
The current HTTPS routers use the `lan.barlows.cool` domains from the env files;
the old `.home` DNS aliases do not add HTTP routers on their own.

Compose interpolates the address into the inline DNS config. Redeploy Pi-hole
after changing it; Swarm config version bumps are no longer required.
Preprod Pi-hole remains disabled and retains its alternative port 5353.

## Verification

Keep the router on public DNS until both addresses answer UDP and TCP queries.
Run from another LAN machine, substituting the assigned addresses:

```bash
dig @N100_PRIMARY_IP example.com
dig +tcp @N100_PRIMARY_IP example.com
dig @N100_SECONDARY_IP example.com
dig +tcp @N100_SECONDARY_IP example.com
dig @N100_PRIMARY_IP pocket-id.lan.barlows.cool
```

The local record must return the primary N100 address. Only then set the
router's two DNS entries and renew clients' DHCP leases or reconnect them.
Changing router DNS does not immediately change cached client settings.

Pi-hole retains the previous tmpfs setup for `/etc/pihole`: UI changes to its
filtering configuration are not persisted across recreation. Its admin
password is supplied from a protected host secret file. See [secrets.md](secrets.md).

Update Tailscale's tailnet DNS resolver to the N100's primary address too; its
existing Pi address otherwise remains a dependency for tailnet clients.
