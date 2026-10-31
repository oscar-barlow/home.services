# Zigbee

The SONOFF ZBDongle-P moves physically from the Pi to the N100, still using its
USB extension cable. Zigbee2MQTT accesses it directly through Compose's
`devices` mapping; ser2net and the TCP serial bridge are no longer needed.

Set `ZIGBEE_DEVICE` in `env/.env.prod` to the dongle's stable
`/dev/serial/by-id/...` path on the N100. The container sees `/dev/ttyUSB0`.
The adapter remains `zstack`. Zigbee2MQTT's environment overrides select that
port and the environment's MQTT broker without replacing its existing
configuration file.

The data directory remains `/srv/data/prod/zigbee2mqtt/data`. Preserve its
`configuration.yaml`, `database.db`, coordinator backup and all other files.
These carry the paired network's configuration. Do not overwrite them with the
seed, generate a new network key or change channel 25 during migration.
The checked-in `zigbee2mqtt/configuration.yaml` is only a seed for a new setup.

Mosquitto moves to the N100 and keeps
`/srv/data/prod/mosquitto/data`. Its old hostname
`homelab-prod_mosquitto` remains an alias on the production backend bridge, so
Home Assistant's existing MQTT integration can continue to use it. External
MQTT clients using the Pi's LAN address must be updated to the N100 address.

Mosquitto and Zigbee2MQTT remain disabled in preprod because there is one
physical coordinator. Keep `Z2M_WATCHDOG=default` so transient coordinator
connection failures are retried internally.

```bash
ls -l /dev/serial/by-id/
sudo make service-up ENV=prod SERVICE=zigbee2mqtt
make logs ENV=prod SERVICE=zigbee2mqtt
make logs ENV=prod SERVICE=mosquitto
```

After migration, verify existing devices in Zigbee2MQTT and Home Assistant
before enabling device joins or making Zigbee configuration changes.
