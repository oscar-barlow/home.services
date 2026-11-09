# Home Services

Home services run on the N100 using Docker Compose. Production and
preproduction are separate Compose projects, `homelab-prod` and
`homelab-preprod`, built from the same [compose.yaml](compose.yaml).
The Raspberry Pi and Docker Swarm are no longer required.

## Services

| Service | Purpose |
| --- | --- |
| Traefik | HTTPS ingress and automatic Docker container discovery for both environments |
| Pi-hole | DNS filtering on two LAN addresses assigned to the N100 |
| Home Assistant | Home automation |
| Mosquitto and Zigbee2MQTT | MQTT and Zigbee, with direct USB access to the coordinator |
| Jellyfin | Media server with Intel Quick Sync GPU access |
| Audiobookshelf | Audiobooks and podcasts |
| Kavita | Books and papers |
| Pocket ID | Sign-in provider |
| Trek | Home application |
| Immich | Photos, database, cache and machine learning |
| Homepage | Automatic container discovery; currently disabled in both environments |

Image versions and replica counts remain in `env/.env.prod` and
`env/.env.preprod`. A replica count of `0` disables a service. Prod runs the
single Traefik instance that routes both environments. Pi-hole, MQTT, Zigbee
and Immich are currently enabled only in prod.

## Configuration and commands

Requires Docker Engine, Docker Compose 2.23.1 or later, Python 3, and GNU Make.
Run deployment commands on the N100. Set `N100_LAN_IP` and `DNS_SECONDARY_IP`
in the tracked `env/.env.prod` and `env/.env.preprod` files. Both environments
run on the same host, so use the same addresses in both files. Commit and pull
these settings through git; no local env file needs copying to the N100.
Both addresses must already be assigned to the N100. See [dns.md](dns.md).

`env/.env.local` is an optional ignored override, loaded after the tracked file.
Remove duplicate entries or the file itself to use the tracked settings.
Secret values remain in their separate protected files; the tracked
`SECRETS_DIR` only specifies their path.

```bash
make config ENV=prod
make config ENV=preprod
make check
sudo make preflight ENV=prod
sudo make env-up ENV=prod
sudo make env-up ENV=preprod
make list-services ENV=prod
make logs ENV=prod SERVICE=traefik
make service-down ENV=prod SERVICE=homepage
sudo make service-up ENV=prod SERVICE=pocket-id
sudo make env-down ENV=preprod
```

`env-up` checks existing storage, devices and secret files before creating the
shared ingress bridge and starting containers. It rejects an active Swarm or
old containers that could access the same data. `env-down` removes the Compose
containers and project networks; it does not delete bind-mounted data.
`service-up` follows the configured replica count, so set it to `1` in the env
file before starting a disabled service. `service-down` stops it until the next
`env-up` or `service-up`.

`bin/compose` also accepts normal Compose commands with `ENV=prod` or
`ENV=preprod`. Deployment commands should go through Make so preflight runs.
Use `sudo` for startup because the host secret directories are root-only.

## Networking, storage and secrets

Each project has its own private backend bridge. HTTP services also join the
shared `homelab-ingress` bridge so production Traefik can reach both
environments. Databases and the MQTT broker are not attached to that bridge.
Saved Swarm service names remain as aliases on the private backend network.
See [network.md](network.md).

Existing data remains under `/srv/data/prod` and `/srv/data/preprod`, backed
by the N100's storage. Compose refuses to create missing bind directories.
See [storage.md](storage.md), [secrets.md](secrets.md), [jellyfin/README.md](jellyfin/README.md)
and [zigbee.md](zigbee.md). Remote access uses Tailscale on the N100; see
[ssh.md](ssh.md).

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
  ENV=prod bin/compose stop home-assistant
  sudo rm /srv/data/prod/home-assistant/config/.storage/http
  sudo make service-up ENV=prod SERVICE=home-assistant
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
