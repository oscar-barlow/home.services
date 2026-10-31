# Traefik

Production Traefik runs on the N100 manager. Its placement requires both
`node.role == manager` and `node.labels.hardware == n100`. The manager role
is required because its Swarm provider uses the node's local Docker socket.
The production instance routes both production and preproduction services;
preproduction Traefik remains disabled.

## Moving from the Pi

Run these checks and deployment commands on the N100, from a checkout of this
branch. Swarm must have manager quorum before the deployment can proceed.

1. Confirm the N100 is an available manager with the `hardware=n100` label:

   ```bash
   docker node ls
   docker node inspect self --format '{{.Spec.Role}} {{json .Spec.Labels}}'
   ```

2. Ensure the existing production certificate store and dynamic configuration
   are accessible at the same paths on the N100:

   ```bash
   findmnt -T /srv/data/prod/traefik/letsencrypt
   sudo test -s /srv/data/prod/traefik/letsencrypt/acme.json
   sudo test -d /srv/data/prod/traefik/dynamic
   ```

   The `test` commands must succeed. Preserve the existing `acme.json`, its
   permissions, and all dynamic configuration files. If storage is not already
   shared, transfer that state before deployment. Ensure its backing storage
   remains available without the Pi before retiring the Pi.

3. Deploy through the usual environment workflow:

   ```bash
   make env-up ENV=prod
   ```

4. Verify the Traefik task is running on the N100 and inspect startup logs:

   ```bash
   docker service ps homelab-prod_traefik --no-trunc
   docker service logs --since 5m --tail 100 homelab-prod_traefik
   ```

   Test HTTPS through the N100 directly, substituting its LAN address:

   ```bash
   N100_LAN_IP='replace-with-n100-lan-ip'
   curl --resolve "pocket-id.lan.barlows.cool:443:${N100_LAN_IP}" --head https://pocket-id.lan.barlows.cool/
   ```

   Check certificate validation, Swarm-discovered routes, and the Jellyfin file
   routes for both environments before demoting the Pi.

## Remaining Pi dependencies

The tracked Pi-hole wildcard records still point to `192.168.1.204`, the Pi's
address. While the Pi is available, Swarm's published-port routing mesh can
forward those HTTP requests to Traefik on the N100. To make HTTP access
independent of the Pi, update those records to the N100's LAN address in a
separate DNS migration. DNS service placement and the router's DNS addresses
also need migration before retiring the Pi.
