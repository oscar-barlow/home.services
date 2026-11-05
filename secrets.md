# Secrets Management

Compose mounts explicitly granted host secret files read-only at
`/run/secrets/<name>`. Secret values are not stored in env files or git.
Unlike Swarm's encrypted secret store, these files are plaintext on the host
and need protection through filesystem permissions and backups.

The default directory is `/etc/home-services/secrets`, with `prod` and
`preprod` subdirectories. Set the root using `SECRETS_DIR` in the tracked
`env/.env.prod` and `env/.env.preprod` files. The path is public configuration;
secret values stay in the protected files. Each environment directory must
belong to root and have mode 0700. Install secret files as root with mode 0444 so processes
inside containers can read them even when they run as a non-root UID. The
protected parent directory prevents ordinary host users from reading them.
Compose cannot remap ownership or mode for file-backed secrets; the host
permissions are used directly.

| Filename | Used by | Migration requirement |
| --- | --- | --- |
| `pocket_id_encryption_key` | Pocket ID | Preserve each environment's existing key |
| `immich_db_password` | Immich server and Postgres | Preserve the existing production password |
| `desec_token` | Traefik | Recover the existing token or issue a replacement |
| `pihole_web_password` | Pi-hole | Recover it or generate a new admin password |

Preprod only needs the Pocket ID key with its current enabled-service settings.
The other secret declarations can remain without corresponding host files
while their consumers are scaled to zero. Before enabling those services,
provision the appropriate environment's secrets. `release_manager_github_token`
was unused and is no longer declared.

`sudo make preflight ENV=prod` checks only enabled services and reports paths,
never values. See [MIGRATION.md](MIGRATION.md) for installing the recovered keys.
Do not generate replacements for Pocket ID's existing encryption keys or for
the password used by an existing Immich database during this migration.

The recovered directory and cold Swarm-state backup are additional recovery
copies; retain them until migration is verified. Back up this host secret
directory separately with encryption: the current data backup script only
covers `/srv/data/${ENV_NAME}`.
