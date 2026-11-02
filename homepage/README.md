# Homepage

Homepage is part of `compose.yaml`, routed at `homepage.${DOMAIN_SUFFIX}` by
Traefik. Its existing config directory remains
`/srv/data/${ENV_NAME}/homepage/config`. Homepage and its socket proxy are
currently disabled (`HOMEPAGE_REPLICAS=0`) in both environments.

`homepage/docker.yaml` uses one local connection to `homepage-proxy`.
Discovery reads container labels through a read-only socket proxy on a private
internal bridge. `instanceName` and `homepage.instance.${ENV_NAME}.*` labels
separate prod and preprod cards even though the proxy can see both projects.
Jellyfin is discovered like every other container. There is no Swarm or Pi
connection and no manual service list.

The checked-in Docker, settings and services YAML files are mounted as Compose
configs. Edit them directly and recreate Homepage through `env-up`; config
version suffixes are no longer needed. Preserve the environment-specific
`HOMEPAGE_ALLOWED_HOSTS` value when changing its domain.

To enable it, set `HOMEPAGE_REPLICAS=1` in that environment's env file, ensure
its persistent config directory exists, then run on the N100:

```bash
sudo make env-up ENV=prod
make logs ENV=prod SERVICE=homepage
```
