# Zigbee

Zigbee device network for Home Assistant, built on Zigbee2MQTT. Three services
across the two nodes, with a SONOFF ZBDongle-P (CC2652P, Z-Stack) as the
coordinator.

## Topology

```
ZBDongle-P (USB)                Pi 3                         N100
  /dev/ttyUSB0  ──▶  ser2net ──tcp:3333──▶  Zigbee2MQTT ──▶  Mosquitto ──▶  Home Assistant
                    (standalone)              (Swarm)      mqtt:1883 (Swarm)   (Swarm, MQTT
                                                                                integration)
```

- **ser2net** (Pi 3, standalone container) — bridges the dongle's serial port
  to TCP. Standalone because Swarm can't grant host devices; see
  [ser2net/README.md](ser2net/README.md).
- **Mosquitto** (Pi 3, Swarm service) — MQTT broker. LAN-only, anonymous auth.
  Config shipped as a Swarm `config` from `mosquitto/mosquitto.conf`; retained
  state persists in `/srv/data/${ENV_NAME}/mosquitto/data`.
- **Zigbee2MQTT** (N100, Swarm service) — talks to the coordinator over
  `tcp://ser2net-prod:3333` and publishes to `mqtt://homelab-prod_mosquitto:1883`.
  Web UI proxied by Traefik at `zigbee2mqtt.${DOMAIN_SUFFIX}` (port 8080). Data
  in `/srv/data/${ENV_NAME}/zigbee2mqtt/data`.

Zigbee2MQTT is placed on the N100 because it is a Node.js app (70–150 MB); the
Pi 3 has only ~159 MB free and runs Traefik + Pi-hole. Mosquitto and ser2net
are negligible and sit on the Pi with the dongle.

Inter-service addressing uses overlay DNS rather than the Pi's IP: the
fully-qualified Swarm name for Mosquitto (`homelab-${ENV_NAME}_mosquitto`, per
[network.md](network.md)) and the standalone container's network alias for
ser2net (`ser2net-${ENV_NAME}`, the same mechanism Traefik uses to reach the
standalone Jellyfin).

## Prod-only

There is one physical dongle, so the Zigbee stack runs only in prod:
`SER2NET_ENABLED=true` and `MOSQUITTO_REPLICAS`/`ZIGBEE2MQTT_REPLICAS=1` in
`env/.env.prod`; all off (`false`/`0`) in `env/.env.preprod`.

Mosquitto's published port must still differ between environments even though
preprod is scaled to 0: a Swarm service that publishes a port in ingress mode
reserves that port swarm-wide regardless of replica count, so a preprod
`mosquitto` publishing 1883 would block prod from binding it. Hence
`MOSQUITTO_MQTT_PORT=1883` in prod and `11883` in preprod — the same per-env
port split Pi-hole and Traefik already use.

## Zigbee2MQTT config is seeded, then owned by Z2M

Like Home Assistant, Zigbee2MQTT rewrites its own `configuration.yaml` (frontend
settings, the generated network key, the device database). So it is **not**
shipped read-only from this repo. `zigbee2mqtt/configuration.yaml` is a seed:
copy it once into the data volume before first boot, after which Z2M owns it.

```bash
sudo mkdir -p /srv/data/prod/zigbee2mqtt/data
sudo cp zigbee2mqtt/configuration.yaml /srv/data/prod/zigbee2mqtt/data/configuration.yaml
```

### Channel 25

The seed pins `advanced.channel: 25` to stay clear of 2.4 GHz WiFi (there is a
TP-Link repeater in the house). **Do not change the channel after devices are
paired** — it forces re-pairing everything.

## Setup sequence

Run cluster commands yourself; this repo only ships config.

1. Plug the dongle into the Pi via the USB extension cable.
2. Confirm the serial device on the Pi: `ls /dev/ttyUSB*` (or `ls /dev/ttyACM*`).
   If it is not `ttyUSB0`, set `SER2NET_DEVICE` in `env/.env.prod`.
3. Deploy. Mosquitto and Zigbee2MQTT are Swarm services and come up with
   `make env-up ENV=prod` from wherever you normally deploy (the N100).
   ser2net is a standalone container that must run **on the Pi** (the node the
   dongle is attached to) — `env-up` on the N100 skips it with a message, so run
   `make ser2net-up ENV=prod` on the Pi. See [ser2net/README.md](ser2net/README.md).
4. Confirm the bridge from the N100: `nc -z <pi-ip> 3333`.
5. Confirm MQTT from the N100: `mosquitto_sub -h <pi-ip> -t '#' -v` while
   `mosquitto_pub -h <pi-ip> -t test -m hello` from another shell.
6. Check the Zigbee2MQTT logs for successful coordinator startup, then open
   `https://zigbee2mqtt.${DOMAIN_SUFFIX}`.
7. In Home Assistant, add the **MQTT** integration pointed at
   `homelab-prod_mosquitto` port 1883 (or `<pi-ip>:1883`). Auto-discovery is on
   by default, so Z2M-paired devices appear automatically.
8. Pair a test device from the Z2M web UI. Pair the mains-powered smart plug
   first — it becomes a Zigbee router and strengthens the mesh before the bulbs.
