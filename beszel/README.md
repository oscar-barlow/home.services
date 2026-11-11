# Beszel

[Beszel](https://beszel.dev/guide/hub-installation#docker-or-podman) monitors
N100 CPU, memory, network, disks and Docker containers. The hub and agent are
pinned together to `0.21.1`. The production agent monitors both Compose projects;
a second preprod agent is unnecessary. Both preprod services default to zero.

The hub is routed at `https://beszel.lan.barlows.cool`. It stores its database,
accounts and private key in `/srv/data/prod/beszel/data`. Include this directory
in application-state backups. Keep its generated keys in that persisted storage.

## First start

Run these commands on the N100 after pulling this branch:

```bash
sudo install -d -m 0750 /srv/data/prod/beszel/{data,agent,socket}
sudo install -d -m 0755 /var/lib/home-services/prod/beszel-root /srv/data/.beszel
sudo make service-up ENV=prod SERVICE=beszel
```

Open `https://beszel.lan.barlows.cool` and create the initial administrator
account. Choose **Add System**, name it `N100`, and set **Host / IP** to
`/beszel_socket/beszel.sock`. Copy the hub's **public key** from the setup dialog.
In `env/.env.prod`, set:

```dotenv
BESZEL_AGENT_REPLICAS=1
BESZEL_AGENT_KEY="ssh-ed25519 ...the hub public key..."
```

The public key is safe to track in git; it is not the hub's private key or a
registration token. Commit the public configuration through your normal git
workflow. The agent defaults to zero until this key is available, and preflight
rejects an enabled agent without it. Then run:

```bash
sudo make service-up ENV=prod SERVICE=beszel-agent
make logs ENV=prod SERVICE=beszel-agent
```

Save the system in the hub if the dialog is still open. Confirm it becomes
connected and displays the N100's metrics and containers. The agent healthcheck
only confirms its process is running; the dashboard verifies the connection.

To remove any old Homepage containers and apply the cleaned routing labels,
run `sudo make env-up ENV=prod` and `sudo make env-up ENV=preprod`. Compose
removes orphaned containers; existing Homepage bind-mounted data is retained.

## Agent access and storage

The agent uses host networking so it can measure N100 network interfaces.
It listens only on the Unix socket shared with the hub, with no published TCP
agent port. The hub authenticates using its public key. This uses Beszel's
SSH transport over the local socket; no WebSocket registration token is needed.

The agent reads the Docker socket for container metrics. A read-only bind does
not restrict Docker API operations; this agent has privileged access to the
Docker daemon and should remain a trusted component.

Empty marker directories on the root filesystem and the data volume are mounted
read-only into `/extra-filesystems/root` and `/extra-filesystems/data`. These
allow disk usage and I/O discovery without exposing the host's files. Do not
put application files in the markers or move them to another filesystem.
Agent state persists in `/srv/data/prod/beszel/agent`; the shared socket lives
in `/srv/data/prod/beszel/socket`.

If enabling a separate preprod hub, use the equivalent paths under
`/srv/data/preprod/beszel` and `/var/lib/home-services/preprod/beszel-root`,
set `BESZEL_REPLICAS=1` in `env/.env.preprod`, and pair with that hub's own
public key. Its URL is `https://beszel.preprod.lan.barlows.cool`.

See the official [agent installation](https://beszel.dev/guide/agent-installation),
[additional disks](https://beszel.dev/guide/additional-disks) and
[security](https://beszel.dev/guide/security) documentation.
