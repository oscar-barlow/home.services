# Jellyfin

Jellyfin runs as a **standalone container** on the N100, not as a Docker Swarm
service, because it needs access to the Intel iGPU (`/dev/dri/renderD128`) for
Quick Sync hardware transcoding.

Docker Swarm services cannot access host devices: `devices` and
`device_cgroup_rules` are unsupported, `group_add` is rejected, and
`privileged` is silently dropped. Without the device cgroup rule, the render
node is visible inside the container but cannot be opened, and VAAPI/QSV init
fails. A standalone container with `devices: /dev/dri` and `group_add` for the
host `render` group grants access properly.

## Integration with the rest of the stack

- Attaches to the external `homelab-shared` overlay (created `--attachable`),
  under the alias `jellyfin-${ENV_NAME}`.
- Routed by the existing Traefik instance via its **file provider**. On deploy,
  `traefik-dynamic.yml` is rendered to
  `/srv/data/prod/traefik/dynamic/jellyfin-${ENV_NAME}.yml`, pointing at
  `http://jellyfin-${ENV_NAME}:8096`. Both prod and preprod routes land in the
  prod tree because a single Traefik instance (a prod-stack service) routes both
  environments, and its file provider watches only that one directory — it
  cannot watch multiple directories or recurse into subdirectories. Per-env
  separation would require per-env Traefik instances (see network.md, Future
  Improvements).
- `/srv/data` is NFS-shared to the Traefik node, and Traefik's file-provider
  watch (inotify) does not fire for a file written by a different NFS client.
  So `jellyfin-up` compares the rendered route against the deployed one and,
  when it changed, forces a Traefik reload (`docker service update --force`) to
  make it re-scan the directory. Unchanged routes skip the reload, so routine
  deploys don't bounce the proxy.
- All state (users, libraries, playlists, metadata) persists in
  `/srv/data/${ENV_NAME}/jellyfin/config`, unchanged from the previous Swarm
  deployment.

## Commands

```bash
# Started/stopped automatically with the environment
make env-up ENV=prod
make env-down ENV=prod

# Or manage Jellyfin on its own
make jellyfin-up ENV=prod
make jellyfin-down ENV=prod
```

## Enabling hardware transcoding

After deploy, in Jellyfin **Dashboard → Playback → Transcoding**:

- Hardware acceleration: **Intel QuickSync (QSV)**, device `/dev/dri/renderD128`
- Enable hardware decode for the codecs in use (H.264, HEVC, HEVC 10-bit, VP9,
  AV1); leave VC1 unticked (no N100 decoder for it)
- Enable hardware encoding, including the low-power H.264/HEVC encoders
- Enable VPP tone mapping if transcoding HDR to SDR

Verify with `intel_gpu_top` on the host while a transcode runs.
