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

This is a simplicity choice, not a forced one: the overlay alias `ser2net-prod`
would also work (ser2net binds all interfaces, so it listens on the overlay IP
too). But ser2net is inherently host-bound — it exists to bridge a device on
one specific node — so reaching it via that host's stable address and published
port is the natural fit and has the fewest moving parts: no non-Swarm container
enrolled in Swarm overlay DNS, no dependence on gossip propagating a standalone
endpoint that gets a fresh IP on every recreate. `192.168.1.204` is the Pi's
fixed address, the same anchor Pi-hole and Traefik rely on. (Mosquitto, by
contrast, is a real Swarm service, so it keeps its swarm-managed overlay DNS
name.)

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
  that listens on nothing). `ser2net.conf` is **baked into the image** at build
  time (`COPY` in the Dockerfile), not bind-mounted — see the deployment section
  below for why. A config change therefore needs a rebuild (`make ser2net-up`
  runs `--build`), not just a container restart.
- The **host** device path is set per environment via `SER2NET_DEVICE`, mapped
  to the fixed in-container path `/dev/ttyUSB0` that `ser2net.conf` references.
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

## Deployed remotely, from the same node as everything else

ser2net is a plain `docker compose` container, not a Swarm service, so it
targets whichever Docker daemon `make` talks to — not a node Swarm picks. The
dongle is on the Pi, but deploys are driven from the N100. Rather than making
you SSH into the Pi for this one container, `make ser2net-up`/`-down` run
`docker --context <ctx> compose …`, driving the Pi's Docker daemon over SSH.
The context name comes from `SER2NET_DOCKER_CONTEXT` in the env file (`pi` in
prod); it defaults to `default` (the local daemon) if unset.

Two things make this clean over SSH:

- **The build context is uploaded** to the remote daemon, so the image builds
  on the Pi (native arm, ~3 s) from files sent over SSH.
- **The config is baked into the image** (`COPY ser2net.conf …`) rather than
  bind-mounted. A remote context resolves bind-mount *source* paths on the
  **remote** filesystem, so `./ser2net.conf` would make the Pi look for a file
  that only exists on the N100 and fail. Baking it in sidesteps that entirely —
  nothing needs to pre-exist on the Pi. The `devices:` mapping and published
  port already resolve correctly on the Pi, because that is where the daemon
  runs.

### One-time setup (on the deploy machine, e.g. the N100)

Create an SSH key that reaches a Pi user in the `docker` group, then a Docker
context pointing at the Pi:

```bash
docker context create pi --docker "host=ssh://<user>@192.168.1.204"
docker --context pi ps   # verify it reaches the Pi's daemon
```

Prefer a dedicated deploy key over your login key: an SSH key that can reach a
`docker`-group user is root-equivalent on that host. The trust boundary already
exists — the N100 orchestrates the Pi through Swarm — so this doesn't widen it,
but a scoped key keeps it tidy.

ser2net is set-and-forget: it only needs redeploying if its image or config
changes, or the Pi reboots (`restart: unless-stopped` brings it back on its
own).

## Commands

```bash
# From the deploy machine (N100), targeting the Pi via the 'pi' context:
make ser2net-up ENV=prod
make ser2net-down ENV=prod
```

`make env-up`/`env-down ENV=prod` invoke these too, so a single `make env-up
ENV=prod` from the N100 now deploys the whole stack — Swarm services via Swarm,
ser2net onto the Pi via the context. If the `pi` context is missing or the Pi
is unreachable, the ser2net step fails loudly rather than skipping.
