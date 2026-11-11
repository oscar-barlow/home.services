# Readeck

[Readeck](https://readeck.org/en/apps) saves articles and bookmarks for later.
Both environments run `codeberg.org/readeck/readeck:0.23.5`, with separate data
and accounts. Traefik provides HTTPS at:

- Production: `https://readeck.lan.barlows.cool`
- Preproduction: `https://readeck.preprod.lan.barlows.cool`

## First start

Run these commands on the N100 after pulling this branch:

```bash
sudo install -d -o 1000 -g 1000 -m 0750 /srv/data/prod/readeck/data
sudo install -d -o 1000 -g 1000 -m 0750 /srv/data/preprod/readeck/data
sudo make service-up ENV=prod SERVICE=readeck
sudo make service-up ENV=preprod SERVICE=readeck
```

Open each URL and create its initial account. The container runs as UID/GID
`1000:1000`, so its data directory must be writable by that account. No initial
password or application secret is committed to the repository.

Configuration, SQLite database and archived content all persist in
`/srv/data/${ENV_NAME}/readeck/data`, mounted at `/readeck`. Keep this on the
N100's local data volume: Readeck does not support SQLite over NFS or CIFS.
Include the whole directory in application-state backups; stop the service
before making a cold copy, then start it again:

```bash
make service-down ENV=prod SERVICE=readeck
sudo make service-up ENV=prod SERVICE=readeck
```

The service publishes no host port. Its allowed hostname and canonical HTTPS
URL are set per environment. The built-in healthcheck verifies the application;
use `make logs ENV=prod SERVICE=readeck` to investigate startup problems.
Versions and enablement are controlled by `READECK_VERSION` and
`READECK_REPLICAS` in the tracked env files.

See the official [deployment](https://readeck.org/en/docs/deploy),
[Compose examples](https://readeck.org/en/docs/compose) and
[configuration](https://readeck.org/en/docs/configuration) documentation.
