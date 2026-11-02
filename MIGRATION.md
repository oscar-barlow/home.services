# Move from Swarm to Compose on the N100

Run the commands in this guide yourself on the N100. Preparing this branch
and running local tests do not migrate the live installation. Keep the Pi
powered off during cutover and the router on public DNS until verification.
This retires the old Swarm and does not require repairing its quorum first.

Image versions and `/srv/data/${ENV_NAME}` paths are retained. The N100 already
hosts the storage formerly mounted over NFS by the Pi, so that data does not
need copying from the Pi. Record the old deployed git revision and verify
backups before starting. Never run old and new writers against the same data.

## Host settings

Requires Docker Compose 2.23.1 or later, Python 3 and GNU Make. Check out
`services/migrate-to-compose` on the N100, then:

```bash
cp env/.env.local.example env/.env.local
```

Set `N100_LAN_IP` to the fixed primary LAN IPv4 address and `DNS_SECONDARY_IP`
to a second unused address in the same LAN. Reserve both outside DHCP's dynamic
pool. Assign the second address persistently through the N100's existing
network manager. Both must appear in `ip -4 address` before Pi-hole starts.
Reusing the old Pi address requires permanently disconnecting the Pi from the
LAN. Both DNS addresses reach the same container and do not provide redundancy.

Move the Zigbee dongle and extension cable to the N100. Verify `ZIGBEE_DEVICE`
in `env/.env.prod` against its stable by-id path, and verify that
`JELLYFIN_RENDER_GID` matches the host render group:

```bash
ip -4 address
ls -l /dev/dri /dev/serial/by-id/
getent group render
make config ENV=prod
make config ENV=preprod
make check
sudo test -s /srv/data/prod/immich/postgres/PG_VERSION
sudo test -s /srv/data/prod/zigbee2mqtt/data/database.db
sudo test -s /srv/data/prod/zigbee2mqtt/data/configuration.yaml
sudo test -s /srv/data/prod/traefik/letsencrypt/acme.json
findmnt -T /srv/data/prod/traefik/letsencrypt/acme.json
```

Stop if required state is absent. Keep existing Home Assistant and Zigbee2MQTT
configuration; do not overwrite them with seeds or generate a new Zigbee key.
The Compose environment overrides update USB and MQTT endpoints while keeping
the paired network. See [zigbee.md](zigbee.md).

## Secrets

The recovered directory for this migration is
`/root/home-services-secrets.VEROn2`. Copy both Pocket ID keys and the production
Immich password unchanged into their long-term locations:

```bash
sudo install -d -m 0700 /etc/home-services/secrets/prod /etc/home-services/secrets/preprod
sudo install -m 0444 /root/home-services-secrets.VEROn2/prod/pocket_id_encryption_key /etc/home-services/secrets/prod/pocket_id_encryption_key
sudo install -m 0444 /root/home-services-secrets.VEROn2/preprod/pocket_id_encryption_key /etc/home-services/secrets/preprod/pocket_id_encryption_key
sudo install -m 0444 /root/home-services-secrets.VEROn2/prod/immich_db_password /etc/home-services/secrets/prod/immich_db_password
sudo cmp /root/home-services-secrets.VEROn2/prod/pocket_id_encryption_key /etc/home-services/secrets/prod/pocket_id_encryption_key
sudo cmp /root/home-services-secrets.VEROn2/preprod/pocket_id_encryption_key /etc/home-services/secrets/preprod/pocket_id_encryption_key
sudo cmp /root/home-services-secrets.VEROn2/prod/immich_db_password /etc/home-services/secrets/prod/immich_db_password
```

The comparisons should succeed silently. Files must be readable by non-root
container processes; the 0700 host directories protect them from other host
users. Compose uses the host file permissions directly. See [secrets.md](secrets.md).

Recover the deSEC token or create a replacement with the same required DNS
permissions in deSEC. Save it without printing the value:

```bash
sudo bash <<'SH'
set -euo pipefail
umask 077
read -r -s -p 'deSEC token: ' token </dev/tty
printf '\n' >/dev/tty
test -n "$token"
printf '%s' "$token" > /etc/home-services/secrets/prod/desec_token
chmod 0444 /etc/home-services/secrets/prod/desec_token
SH
```

Preserve the existing `acme.json`; the token is needed for certificate issuance
and renewal. Recover Pi-hole's admin password if available. Otherwise generate
a replacement into its protected file, then retain it in your password manager:

```bash
sudo bash <<'SH'
set -euo pipefail
umask 077
openssl rand -base64 32 > /etc/home-services/secrets/prod/pihole_web_password
chmod 0444 /etc/home-services/secrets/prod/pihole_web_password
SH
```

These are initial-provisioning commands for missing credentials, not commands
to rerun after the files exist. Preprod's disabled consumers do not need
placeholder secrets. Keep the recovered directory intact.

## Cold backup and retire Swarm

This starts the service outage. If Swarm autolock is enabled, have the unlock
key available before stopping Docker. The backup directory is root-only because
manager state contains encrypted secrets and the keys needed to recover them.

```bash
BACKUP_DIR="/root/home-services-migration-$(date -u +%Y%m%dT%H%M%SZ)"
sudo install -d -m 0700 "$BACKUP_DIR"
sudo systemctl stop docker.service docker.socket
sudo tar -C /var/lib/docker -czf "$BACKUP_DIR/swarm.tar.gz" swarm
```

With Docker stopped and the Pi off, take a verified snapshot or backup of
`/srv/data/prod` and `/srv/data/preprod`, especially the database directories,
Pocket ID data, Home Assistant and Jellyfin configs, Zigbee data, MQTT data and
all of Traefik's directory. Back up `/etc/home-services/secrets` separately.
These copies are the rollback point; databases must have no writers during
backup. The existing Borg script can back up each environment if already
configured, but it does not include the host secret directory.

After the backups succeed, start Docker and deliberately leave the retired
Swarm. Keep the Pi off. `--force` is used because this Swarm will no longer be
used, as described in [Docker's leave documentation](https://docs.docker.com/reference/cli/docker/swarm/leave/).

```bash
sudo systemctl start docker.service
docker swarm leave --force
docker info --format '{{.Swarm.LocalNodeState}}'
```

The state must be `inactive`. Remove any remaining old task containers and old
standalone Jellyfin containers by their exact old labels. This retains their
bind-mounted data:

```bash
for environment in prod preprod; do
  for label in \
    "com.docker.stack.namespace=homelab-$environment" \
    "com.docker.compose.project=jellyfin-$environment"; do
    ids=$(docker ps -aq --filter "label=$label")
    if [ -n "$ids" ]; then
      docker rm -f $ids
    fi
  done
done
```

The labels deliberately exclude the new `homelab-prod` and `homelab-preprod`
Compose projects. Archive only the generated Jellyfin file routes, since Docker
labels now supply them. Preserve other files, including `compat@file` TLS
options used by Kavita:

```bash
sudo install -d -m 0700 /srv/data/prod/traefik/legacy-routes
for environment in prod preprod; do
  route="/srv/data/prod/traefik/dynamic/jellyfin-$environment.yml"
  if sudo test -f "$route"; then
    sudo mv "$route" /srv/data/prod/traefik/legacy-routes/
  fi
done
```

## Start and verify Compose

```bash
sudo make preflight ENV=prod
sudo make preflight ENV=preprod
sudo make env-up ENV=prod
sudo make env-up ENV=preprod
make list-services ENV=prod
make list-services ENV=preprod
make logs ENV=prod SERVICE=traefik
```

Preflight checks enabled consumers only. It rejects active Swarm membership,
old local workloads, missing storage or devices, unsafe or missing secrets,
legacy Jellyfin routes and DNS addresses not assigned to the N100. It reports
paths without secret values. It does not create missing storage directories.
Homepage remains disabled in both environments.

Before restoring private DNS, test HTTPS directly against the N100 from another
LAN machine, substituting its primary address:

```bash
N100_LAN_IP='replace-with-n100-lan-ip'
curl --resolve "pocket-id.lan.barlows.cool:443:$N100_LAN_IP" --head https://pocket-id.lan.barlows.cool/
curl --resolve "jellyfin.lan.barlows.cool:443:$N100_LAN_IP" --head https://jellyfin.lan.barlows.cool/
curl --resolve "pocket-id.preprod.lan.barlows.cool:443:$N100_LAN_IP" --head https://pocket-id.preprod.lan.barlows.cool/
```

Check valid certificates and existing Pocket ID accounts in both environments,
Home Assistant and MQTT, Jellyfin libraries and GPU transcoding, Immich photos
and machine-learning jobs, and existing Zigbee devices. Compatibility aliases
preserve saved MQTT and Immich ML URLs. Verify UDP and TCP DNS through both N100
addresses as described in [dns.md](dns.md) before changing router DNS back.
Update external MQTT clients still targeting the Pi. Reconnect clients to pick
up the new DNS settings.

## Remaining Pi dependencies

Move Tailscale subnet routing to the N100, approve the advertised route, and
verify remote LAN access with the Pi off. Update Tailscale DNS to the N100 only
after Pi-hole is verified. See [ssh.md](ssh.md). Audit old Pi NFS clients and
exports before removing their access; Compose uses the N100 storage locally.

Do not bring the Pi back onto the LAN with its old Docker or Tailscale setup:
it could restart writers against shared data or advertise stale routes. An
offline reimage is the clean way to reuse it.

## Rollback

Retain the old git revision, cold Swarm archive, application snapshots and secret
copies until verification passes. Stop both Compose projects first:

```bash
sudo make env-down ENV=preprod
sudo make env-down ENV=prod
```

Restore affected application data from the matching cold snapshot with all
writers stopped. Returning to Swarm also requires restoring its cold manager
archive with Docker stopped, following [Docker's restore procedure](https://docs.docker.com/engine/swarm/admin_guide/#restore-from-a-backup).
Keep the Pi off and recover a single N100 manager before deliberately applying
the saved Swarm configuration. Its old Pi placements must be reconciled before
those services can run on the N100; rollback does not repair the failing Pi.
