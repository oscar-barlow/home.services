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

It attaches to the external `homelab-shared` overlay under the alias
`ser2net-${ENV_NAME}`, so Zigbee2MQTT reaches it at `tcp://ser2net-${ENV_NAME}:3333`
without hard-coding the Pi's IP. The TCP port is also published to the host
(`${SER2NET_TCP_PORT}:3333`) so it can be reached directly on the LAN — e.g.
`nc -z <pi-ip> 3333` from the N100 to confirm the bridge is up.

## Configuration

- `Dockerfile` — installs `ser2net` from Alpine's package repo (no reliable
  upstream image exists for it; building from the distro package keeps it
  auditable). Alpine over Debian was settled empirically on the Pi: the Alpine
  image is ~9 MB vs ~139 MB for a `debian:bookworm-slim` equivalent, and the
  `ser2net` apk builds cleanly on the Pi's architecture.
- `ser2net.yaml` — maps the in-container device `/dev/ttyUSB0` (115200 8N1) to
  TCP port 3333. `local` keeps ser2net from toggling the modem-control lines,
  which would otherwise reset the CC2652P on connect.
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

## Commands

```bash
# Started/stopped automatically with the environment
make env-up ENV=prod
make env-down ENV=prod

# Or manage ser2net on its own
make ser2net-up ENV=prod
make ser2net-down ENV=prod
```
