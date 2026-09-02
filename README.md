# Home Services

A collection of containerized services for a home network environment.

## Services

### Traefik
- Reverse proxy and ingress for all HTTP services, on ports 80 (HTTP, redirected
  to HTTPS) and 443 (HTTPS)
- Wildcard TLS via Let's Encrypt using the deSEC DNS-01 challenge
- Discovers Swarm services via labels; standalone containers (Jellyfin) are
  routed via its file provider — see [jellyfin/README.md](jellyfin/README.md)
- Runs on the `rpi-3` node in prod

### Pi-hole
- DNS filtering and ad blocking
- Web interface proxied by Traefik at `pihole.${DOMAIN_SUFFIX}`
- DNS services on port 53 (TCP/UDP)
- Custom DNS configuration via `pihole/${ENV_NAME}/etc/dnsmasq.d/02-custom-dns.conf`
- Log rotation configured (10M max size, 3 files)

### Jellyfin
- Media server with Intel Quick Sync hardware transcoding
- Runs as a standalone container (outside the Swarm stack) for iGPU access; see [jellyfin/README.md](jellyfin/README.md)
- Started and stopped with the environment via `make env-up` / `make env-down`
- Configuration persisted in `/srv/data/${ENV_NAME}/jellyfin/config`

### Home Assistant
- Home automation platform
- Web interface on port 8123, proxied by Traefik at `home-assistant.${DOMAIN_SUFFIX}`
- Configuration persisted in `/srv/data/${ENV_NAME}/home-assistant/config`
- Runs on `n100` hardware
- Reverse proxy: because HA sits behind Traefik it returns `400: Bad Request`
  to proxied requests until the proxy is trusted. HA owns and rewrites its own
  `configuration.yaml` and `.storage/` files (the UI edits them), so these are
  edited in place on the node rather than shipped from this repo. Add an
  `http:` block to `configuration.yaml`:

  ```yaml
  http:
    use_x_forwarded_for: true
    trusted_proxies:
      # Trust the whole Docker-internal address space. HA validates every hop
      # in the X-Forwarded-For chain, and the Traefik->HA hop can appear on the
      # overlay (10.10.x), the swarm ingress mesh (10.0.0.x) or docker_gwbridge
      # (172.18.x) depending on path — a single subnet leaves some requests 400.
      # Safe because HA has no published port, so only Traefik can reach it.
      - 10.0.0.0/8
      - 172.16.0.0/12
      - 127.0.0.1
  ```

  As of HA 2026.8 this block is migrated into `.storage/http` **once, on first
  boot**, then ignored — so it must be present before HA first starts. If HA
  already booted without it (migration ran empty, so you see the 400), reset
  just the http store so the block re-migrates on restart (once HA is
  reachable you can instead edit trusted proxies in the UI under
  **Settings > System > Network > HTTP server**, which writes the store
  directly):

  ```bash
  docker service scale homelab-${ENV}_home-assistant=0
  sudo rm /srv/data/${ENV}/home-assistant/config/.storage/http
  docker service scale homelab-${ENV}_home-assistant=1
  ```
- SSO via Pocket ID: HA has no built-in OIDC support, and fronting it with an
  auth proxy (Traefik forward-auth / oauth2-proxy) breaks the companion app and
  API, which depend on HA's own token auth. Instead use the
  [`hass-oidc-auth`](https://github.com/christiaangoossens/hass-oidc-auth)
  custom auth provider, which plugs into HA's native auth (so the web UI and the
  app both keep working). Like the rest of HA's config this is applied in place
  on the node, not shipped from this repo:

  1. In Pocket ID, add an OIDC client — name `Home Assistant`, callback
     `https://home-assistant.${DOMAIN_SUFFIX}/auth/oidc/callback`, type
     **Public Client** (PKCE, no secret to manage). Note the Client ID.
  2. Install the component into
     `/srv/data/${ENV_NAME}/home-assistant/config/custom_components/auth_oidc/`
     (via HACS, or by extracting a release into that folder).
  3. Add to `configuration.yaml` and restart the service (a normal restart —
     this is ordinary integration config, not the `http` store migration):

     ```yaml
     auth_oidc:
       client_id: "<client id from Pocket ID>"
       discovery_url: "https://pocket-id.${DOMAIN_SUFFIX}/.well-known/openid-configuration"
       display_name: "Pocket ID"
       features:
         automatic_person_creation: true
         # force_https: true   # only if the redirect_uri comes back as http://
       # Optional role mapping from Pocket ID groups:
       # roles:
       #   admin: <your-ha-admins group name>
     ```

  This adds an OIDC login button *alongside* the built-in username/password
  provider — keep a local admin account so you are not locked out if Pocket ID
  is down. Use a recent companion-app version (older ones predate the in-app
  OIDC flow). TLS verification can stay on: HA reaches Pocket ID over the real
  deSEC/Let's Encrypt cert, so no private-CA path is needed.

### Zigbee (Zigbee2MQTT + Mosquitto + ser2net)

- Zigbee device network for Home Assistant, using a SONOFF ZBDongle-P
  coordinator. Three services across both nodes; see [zigbee.md](zigbee.md).
- **ser2net** (Pi 3, standalone container) bridges the dongle's USB serial port
  to TCP — standalone because Swarm cannot grant host devices; see
  [ser2net/README.md](ser2net/README.md).
- **Mosquitto** (Pi 3, Swarm service) is the MQTT broker, port 1883.
- **Zigbee2MQTT** (N100, Swarm service) drives the coordinator and publishes to
  Mosquitto; web UI proxied by Traefik at `zigbee2mqtt.${DOMAIN_SUFFIX}`.
- Prod-only (one physical dongle): all three are off in preprod.

## Network

Services communicate over a single external Docker Swarm overlay network,
`homelab-shared`, created with `make network-up`. Traefik is the only ingress —
services are reached by domain name through it rather than by direct host ports
(the exceptions publish a port because their protocol needs it: Pi-hole DNS on
53, Mosquitto MQTT on 1883, ser2net's TCP bridge). The network must exist
before any services are deployed.

### Network Management

```bash
# Create the shared overlay network (one-time, before deploying services)
make network-up

# Remove the shared overlay network
make network-down
```

See [network.md](network.md) for detailed network architecture and the
service-discovery caveats.

### SSH Access
See [ssh.md](ssh.md) for information about remote access to homelab nodes.

### Storage
See [storage.md](storage.md) for storage architecture and permissions model.

## Node Provisioning

For complete homelab node setup:

```bash
# Provision a new homelab node
make provision-node
```

This command joins the node to the Docker Swarm (`make swarm-join`) and then
prints the `make node-label` command to run from a manager node to apply the
node's hardware/class labels.

### Docker Swarm Setup

Initialize or join Docker Swarm with hardware labels for proper service placement:

```bash
# Initialize swarm manager with hardware labels
make swarm-init LABEL_HARDWARE=n100 LABEL_CLASS=medium

# Join as worker with hardware labels
make swarm-join MANAGER_IP=192.168.1.10 TOKEN=SWMTKN-... LABEL_HARDWARE=rpi-4 LABEL_CLASS=small
```

See [hardware.md](hardware.md) for detailed hardware specifications, installation guides, and standardized labeling conventions.

## Usage

```bash
# One-time setup: create the shared overlay network
make network-up

# Start all services for preprod environment (default)
make env-up

# Start all services for production environment
make env-up ENV=prod

# Stop services
make env-down

# Stop services for specific environment
make env-down ENV=prod

# Stop network infrastructure
make network-down
```

### Service Management

```bash
# Scale a specific service to 0 replicas (stop it) in an environment
make service-down ENV=prod SERVICE=zigbee2mqtt

# Remove a specific service from the stack entirely
make service-remove ENV=prod SERVICE=zigbee2mqtt

# List services and standalone containers for an environment
make list-services ENV=prod
```

Individual services are otherwise started and stopped as part of the whole
environment via `make env-up` / `make env-down`. The standalone containers
(Jellyfin, ser2net) also have their own `jellyfin-up`/`-down` and
`ser2net-up`/`-down` targets.

## Resilience

Swarm services use the `on-failure` restart policy; the standalone containers
(Jellyfin, ser2net) use `unless-stopped`. Both recover automatically from
crashes.