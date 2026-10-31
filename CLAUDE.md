# Repository guidance

## Configuration

- `compose.yaml` is the single source of truth for all services on the N100.
- `env/.env.prod` and `env/.env.preprod` contain tracked versions and replica counts.
- `env/.env.local` contains host-specific overrides and is ignored. Never commit secrets.
- Secret files live outside the repo in protected per-environment directories.
- Keep existing `/srv/data/${ENV_NAME}` paths and persisted application settings intact.

## Commands

- `make config ENV=prod` or `ENV=preprod`: validate Compose without deployment.
- `make check`: run configuration and migration preflight tests.
- `sudo make preflight ENV=prod`: check the actual N100 before deployment.
- `sudo make env-up ENV=prod`: start or update services after preflight.
- `sudo make env-down ENV=prod`: stop services without deleting bind-mounted data.

## Deployment boundary

The N100 is remote infrastructure. Do not SSH into it or run deployment,
network-management, storage-management or migration commands from the development
machine. Make changes and validate locally; provide commands for the user to run.
See `MIGRATION.md` for the one-time Swarm cutover. No Swarm orchestration remains
in normal operation.

## Style and maintenance

- Use two-space YAML indentation and standard Compose service/volume names.
- Add code or configuration comments only when explicitly requested.
- Use bridge networks and Traefik's Docker provider; databases stay on backend networks.
- Preserve automatic Homepage discovery and environment-scoped routing labels.
- Correct nearby documentation against actual configuration; keep cleanup scoped.

## Branches and pull requests

Branch from `main` and merge PRs into `main`. Use `services/` plus a short
kebab-case description for service work. PR titles use imperative sentence case.

## Allowed external resources

- https://github.com/pi-hole/docker-pi-hole - Pi-hole Docker repository
