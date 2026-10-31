# Jellyfin

Jellyfin is part of the same `compose.yaml` as the other services, with one
container per enabled environment. Its existing version, `/srv/data` media
and config paths, and `/var/cache/${ENV_NAME}/jellyfin` cache are retained.

The N100's `/dev/dri` is passed directly into the container, with
`JELLYFIN_RENDER_GID` supplying the host render group. Verify that group ID on
the N100 before migration. Hardware transcoding remains Intel QuickSync (QSV),
using `/dev/dri/renderD128` in Jellyfin's Transcoding settings.

Traefik now discovers Jellyfin from container labels on `homelab-ingress`.
Archive the old `jellyfin-prod.yml` and `jellyfin-preprod.yml` from production
Traefik's dynamic directory during cutover, as described in [MIGRATION.md](../MIGRATION.md).
Other file-provider configuration is retained.

```bash
sudo make jellyfin-up ENV=prod
make jellyfin-down ENV=prod
make logs ENV=prod SERVICE=jellyfin
```

The commands target the unified Compose project; there is no separate Jellyfin
project. Before starting it, stop the old `jellyfin-prod` or `jellyfin-preprod`
project so two containers cannot write the same configuration directory.
