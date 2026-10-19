# Beszel

Lightweight host and container monitoring: one hub dashboard plus a per-node
agent that reports CPU, memory, disks, Docker containers, systemd services,
and more. Beszel replaces Netdata, which was binned for being too heavy.

## Architecture

- **Hub** — Swarm service (`beszel` in `docker-swarm-stack.yml`), prod-only,
  on the N100, proxied by Traefik at `beszel.${DOMAIN_SUFFIX}`. Data lives in
  `/srv/data/${ENV_NAME}/beszel/data`. Preprod runs 0 replicas: agents are
  per physical node, so a single prod hub covers everything.
- **Agents** — one per node, installed as a host-level systemd service
  (binary install, not a container — host metrics and Docker monitoring need
  host access). Agents are managed on each node, not shipped from this repo.

## One-time hub setup

1. Deploy the stack (`make env-up ENV=prod`) and open
   `https://beszel.${DOMAIN_SUFFIX}`.
2. Create the admin account when prompted.
3. Generate a **universal token** under *Settings → Tokens* so agents can be
   added without pre-creating each system in the UI.

## Agent installation (per node)

Run on each node:

```bash
curl -sL https://get.beszel.dev -o /tmp/install-agent.sh \
  && chmod +x /tmp/install-agent.sh \
  && /tmp/install-agent.sh -t <universal-token> -url https://beszel.${DOMAIN_SUFFIX} -auto-update
```

The script creates a `beszel` user, installs the agent binary, and starts a
systemd service that keeps it running after reboot. `-auto-update` enables
daily agent updates; drop it to pin the agent version instead. The node
appears in the hub dashboard on first heartbeat (it may take a minute to go
green).

### Docker monitoring

The agent discovers Docker containers by reading `/var/run/docker.sock`.
Grant the beszel user read access, then restart the agent:

```bash
sudo usermod -aG docker beszel
sudo systemctl restart beszel
```

### Monitoring extra disks/partitions

Mount a directory into the agent's extra-filesystems location (see the
Beszel "Additional Disks" guide) to report on partitions not covered by
default.

## Removing an agent

```bash
/tmp/install-agent.sh -u    # if the script is still present
sudo systemctl disable --now beszel && sudo userdel -r beszel
```

Then remove the node's entry in the hub (dashboards → systems).

## Netdata removal (completed migration)

Nodes previously ran Netdata; it was uninstalled and replaced by the Beszel
agent above:

```bash
sudo ./netdata-uninstaller.sh --no-prompt
```
