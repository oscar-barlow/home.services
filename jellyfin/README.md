# Jellyfin

Jellyfin is part of the same `compose.yaml` as the other services, with one
container per enabled environment. Its existing version, `/srv/data` media
and config paths, and `/var/cache/${ENV_NAME}/jellyfin` cache are retained.

The N100's `/dev/dri` is passed directly into the container, with
`JELLYFIN_RENDER_GID` supplying the host render group. Verify that group ID on
the N100 when configuring hardware transcoding. Hardware transcoding uses Intel QuickSync (QSV),
using `/dev/dri/renderD128` in Jellyfin's Transcoding settings.

Traefik discovers Jellyfin from container labels on `homelab-ingress`.
The file provider remains available for other dynamic configuration.

```bash
sudo make jellyfin-up ENV=prod
make jellyfin-down ENV=prod
make logs ENV=prod SERVICE=jellyfin
```

The commands target the unified Compose project.
