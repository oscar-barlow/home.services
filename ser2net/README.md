# ser2net (Zigbee serial bridge)

`ser2net` exposes the SONOFF ZBDongle-P's USB serial port over TCP so that
Zigbee2MQTT — which runs on the N100 — can reach a coordinator that is
physically plugged into the Pi 3.

## Why this runs as a standalone container (not a Swarm service)

Like Jellyfin (`jellyfin/README.md`), ser2net needs a **host device**: the
dongle at `/dev/ttyUSB0`. Docker Swarm services cannot access host devices —
`devices` and `device_cgroup_rules` are unsupported and `privileged` is
silently dropped — so the container is run standalone with `docker compose`
and a `devices:` mapping, on the node the dongle is attached to.

## How Zigbee2MQTT reaches it

ser2net is reached over the **LAN via its host-published port**, not the Swarm
overlay: Zigbee2MQTT connects to `tcp://192.168.1.204:3333` (the Pi's fixed
address, the same anchor Pi-hole/Traefik use). The container publishes
`${SER2NET_TCP_PORT}:3333` on the host and is otherwise on the default bridge —
it is deliberately **not** attached to `homelab-shared`.

The overlay was the obvious first choice (an alias like `ser2net-prod` avoids a
hard-coded IP), and it was tried, but it is the wrong tool here: a non-Swarm
container's overlay endpoint is not managed by Swarm service discovery, so its
IP churns on every recreate and stale gossip entries linger — a swarm service
resolving the alias intermittently gets a dead IP and sees `ECONNREFUSED`. The
host-published port has none of that fragility and is the path the `nc -z
<pi-ip> 3333` smoke test already exercises. (Mosquitto, a real Swarm service,
keeps its overlay DNS name — that discovery *is* swarm-managed and stable.)

## Configuration

- `Dockerfile` — installs `ser2net` from Alpine's package repo (no reliable
  upstream image exists for it; building from the distro package keeps it
  auditable). Alpine over Debian was settled empirically on the Pi: the Alpine
  image is ~9 MB vs ~139 MB for a `debian:bookworm-slim` equivalent, and the
  `ser2net` apk builds cleanly on the Pi's architecture.
- `ser2net.conf` — maps the in-container device `/dev/ttyUSB0` (115200 8N1) to
  TCP port 3333 in ser2net's **legacy line format**
  (`port:raw:0:device:settings`). `LOCAL` keeps ser2net from toggling the
  modem-control lines, which would otherwise reset the CC2652P on connect.
  Note: this must be the legacy format, **not** the newer `%YAML` config —
  Alpine's `ser2net` package is built without YAML support, and feeding it a
  YAML file makes it parse every line with the legacy parser and fail with
  `No state given on line N`, coming up with zero ports (a running container
  that listens on nothing).
- The **host** device path is set per environment via `SER2NET_DEVICE`, mapped
  to the fixed in-container path `/dev/ttyUSB0` that `ser2net.yaml` references.
  Prod uses the dongle's stable `/dev/serial/by-id/usb-ITead_Sonoff_...-if00-port0`
  symlink rather than the bare `/dev/ttyUSB0`: the `ttyUSBn` name is assigned by
  USB enumeration order, so a second serial device or a reboot race could shift
  the dongle to `ttyUSB1`. The by-id path is keyed to the dongle's serial and
  is stable. Docker resolves the symlink when mapping the device, so it still
  lands on `/dev/ttyUSB0` inside the container. Find the path with
  `ls -l /dev/serial/by-id/` (the ZBDongle-P is a CP210x, vendor `10c4`).

The whole Zigbee stack is prod-only because there is a single physical dongle.
`SER2NET_ENABLED` gates the standalone container (`true` in prod, `false` in
preprod); Mosquitto and Zigbee2MQTT are Swarm services scaled to 0 replicas in
preprod for the same reason.

## Must be deployed on the node with the dongle

Unlike the Swarm services, ser2net is a plain `docker compose` container, which
is **not** cluster-aware: it starts on whichever node runs `make`, not on a
node Swarm picks. The dongle lives on the Pi, so ser2net must be brought up
**on the Pi**. Deploys are normally driven from the N100, where the serial
device does not exist — so `make env-up` there skips ser2net (with a message)
rather than failing, and you run `make ser2net-up ENV=prod` on the Pi once.

ser2net is set-and-forget: it only needs redeploying if its image or config
changes, or the Pi reboots (it has `restart: unless-stopped`, so a reboot
brings it back on its own).

## Commands

```bash
# On the Pi (the node with the dongle):
make ser2net-up ENV=prod
make ser2net-down ENV=prod
```

`make env-up`/`env-down` also invoke these targets, but they only do the real
work on the node where the dongle is present; on any other node they skip.
