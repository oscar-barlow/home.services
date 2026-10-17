# Homepage

Homepage runs on the N100 with Traefik HTTPS ingress:

| Environment | URL |
| --- | --- |
| Production | https://homepage.lan.barlows.cool |
| Preprod | https://homepage.preprod.lan.barlows.cool |

Both environments pin `ghcr.io/gethomepage/homepage:v2.6.0`. Configuration
persists in `/srv/data/${ENV_NAME}/homepage/config`, and
`HOMEPAGE_ALLOWED_HOSTS` matches the environment's hostname.

## Automatic service discovery

The dashboard discovers services from Docker labels, following Homepage's
[Docker discovery configuration](https://gethomepage.dev/configs/docker/).

- The `swarm` connection reads services and tasks through
  `homepage-swarm-proxy`, which runs on the Pi manager, matching the existing
  Traefik setup. The Pi must have `hardware=rpi-3` and the manager role.
- The `pi` connection uses that same proxy to discover standalone ser2net.
- The `n100` connection reads standalone containers through
  `homepage-container-proxy`, which runs alongside Jellyfin on the N100.
- Both proxies pin `ghcr.io/tecnativa/docker-socket-proxy:v0.5.0`. They allow
  read requests for the required API endpoints and deny writes. They publish
  no ports and connect only to the stack's private `homepage-discovery`
  overlay network. Homepage also joins `homelab-shared` for Traefik ingress.
- `instanceName` is the environment name. Every discovery label uses
  `homepage.instance.${ENV_NAME}.…`, so prod and preprod entries stay on their
  respective dashboards even though Docker can see both environments.

The dashboard includes Jellyfin, Audiobookshelf, Kavita, Immich, Home Assistant,
Zigbee2MQTT, Trek, Pi-hole, Pocket ID, Traefik, Mosquitto, and Immich's three
backend services, plus ser2net on the Pi. Application cards have HTTPS links;
infrastructure and backend cards without links show Docker status.
Homepage's own service and its socket proxies
have no discovery labels.

Docker discovery also lists services with zero replicas and stopped containers.
For example, preprod's disabled Immich, Pi-hole, Zigbee2MQTT, and Mosquitto
entries remain visible with their Docker status. ser2net is created only in
production by the existing deployment target.

## First deployment

On the N100, create the persistent configuration directories:

```bash
sudo mkdir -p /srv/data/prod/homepage/config /srv/data/preprod/homepage/config
```

From the repository on a Swarm manager, deploy each environment as usual:

```bash
make env-up ENV=preprod
make env-up ENV=prod
```

Deployment mounts `docker.yaml`, `settings.yaml`, and an empty `services.yaml`
from this directory as read-only Swarm configs. No copying of dashboard links
is required. Homepage generates its remaining configuration files in the
persistent directory. Redeploying also recreates Jellyfin with its discovery
labels through the existing `jellyfin-up` target. The production `ser2net-up`
target similarly applies its discovery labels.

If Homepage was already deployed, the Swarm configs override any existing
`docker.yaml`, `settings.yaml`, and `services.yaml` in the persistent directory;
those underlying files remain on disk.

## Adding or customizing services

For a new Swarm service, add labels under `deploy.labels`; for a standalone
container on the N100 or Pi, add them under the service's `labels`:

```yaml
- "homepage.instance.${ENV_NAME}.group=Media"
- "homepage.instance.${ENV_NAME}.name=Example"
- "homepage.instance.${ENV_NAME}.icon=example.png"
- "homepage.instance.${ENV_NAME}.href=https://example.${DOMAIN_SUFFIX}"
```

Redeploy that service and refresh Homepage to see it. Additional standalone
hosts need their own Docker API connection. Keep API keys out of labels;
service widgets that require credentials should use Homepage's environment or
file substitution with secrets.

Edit `homepage/settings.yaml` for dashboard settings, `homepage/docker.yaml`
for Docker connections, and `homepage/services.yaml` for any additional manual
entries. Swarm configs are immutable: when changing one of these files, bump
its corresponding `homepage_*_v1` key and service reference in
`docker-swarm-stack.yml` before redeploying. Edit generated `bookmarks.yaml`,
`widgets.yaml`, and custom CSS in the persistent directory as needed.

## Verification

On a Swarm manager:

```bash
docker service ps homelab-preprod_homepage
docker service ps homelab-preprod_homepage-swarm-proxy
docker service ps homelab-preprod_homepage-container-proxy
docker service logs --tail 50 homelab-preprod_homepage
curl --fail https://homepage.preprod.lan.barlows.cool/api/healthcheck
```

Open the dashboard and confirm it contains only preprod links and one Jellyfin
entry. Repeat with the prod stack and https://homepage.lan.barlows.cool.
