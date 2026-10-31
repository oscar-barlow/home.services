# Network Architecture

All containers run on the N100. Docker Compose creates one backend bridge per
project: `homelab-prod_backend` and `homelab-preprod_backend`. There is no
Swarm routing mesh or cross-host overlay.

## Ingress

`make network-up` creates the external `homelab-ingress` bridge. Both
projects' HTTP services attach to it, and production Traefik discovers their
container labels through the Docker provider. Each routed container explicitly
selects `traefik.docker.network=homelab-ingress`. Discovery is limited to
containers labeled `home-services.managed=true`, and exposure remains opt-in.
Router and service names include the environment to avoid collisions.

Production Traefik publishes HTTP, HTTPS and the existing dashboard port on the
N100. Preproduction Traefik is disabled. Jellyfin uses Docker labels too;
there are no generated Jellyfin file routes or forced proxy reloads. The file
provider remains enabled for existing dynamic configuration, including
`compat@file` TLS options used by Kavita.

The ingress bridge is shared by the HTTP applications in both environments;
it is not complete network isolation. Databases, cache, machine learning and
the MQTT broker attach only to their environment's backend bridge. MQTT still
publishes its configured LAN port for external clients.

## Backend names

Short service names resolve within a project's backend bridge. Compatibility
aliases such as `homelab-prod_mosquitto` and
`homelab-prod_immich-machine-learning` preserve saved Home Assistant and Immich
settings. Use these aliases or backend service names for application traffic;
do not depend on short-name DNS on the shared ingress bridge.

## Homepage discovery

Each environment has an internal `homepage-discovery` bridge and one read-only
socket proxy. Only Homepage and its proxy attach to that bridge. The proxy has
container reads enabled and no published port. Homepage's `instanceName` and
`homepage.instance.${ENV_NAME}.*` labels scope discovery to its own environment.
Both Homepage and its proxy are currently scaled to zero.

## DNS and LAN addresses

Pi-hole publishes TCP and UDP DNS on two specific N100 LAN addresses. The
router receives those two addresses once migration is verified. Both addresses
reach the same Pi-hole instance and do not provide machine-level redundancy.
Local wildcard records point directly at the N100's primary LAN address.
See [dns.md](dns.md).

## Commands

```bash
make network-up
make list-services ENV=prod
```

Run `make network-down` only after both environments have been stopped. Compose
removes its own backend and discovery networks on `env-down`; the external
ingress bridge remains until explicitly removed.
