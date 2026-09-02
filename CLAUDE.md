# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- `make swarm-init` - Initialize Docker Swarm on manager node
- `make swarm-join` - Join Docker Swarm as worker node
- `make env-up` - Deploy services stack to Docker Swarm
- `make env-down` - Remove services stack from Docker Swarm
- `make service-down` - Scale individual service to 0 replicas
- `make node-label` - Add hardware/class labels to swarm nodes

## Code Style Guidelines
- YAML Indentation: Use 2 spaces
- Docker Compose: Follow official naming conventions for services and volumes
- Nginx Config: Follow standard nginx configuration patterns
- Comments: Only add comments to code/config when the user explicitly requests them; otherwise leave the code to speak for itself
- Network Configuration: Use Docker Swarm overlay networks with Traefik reverse proxy
- Environment Variables: Use quotes for values with special characters
- Mount Points: Use relative paths for container config, absolute paths for media

## Boy Scout Principle
- Leave the codebase and docs better than you found them. Homelab work
  routinely surfaces documentation that is stale or contradicted by the code
  (sometimes the same inaccuracy more than once).
- When you touch an area and notice a doc that is wrong, fix it in passing —
  challenge claims against the actual code/config rather than trusting the
  prose, and remove or correct inaccuracies rather than working around them.
- Keep such cleanups scoped to what you can verify; don't invent behaviour to
  fill a gap.

## Configuration Management
- `docker-swarm-stack.yml` is the single source of truth for all service configurations
- Service replicas are controlled via environment variables in env/.env.{ENV_NAME} files
- Use `make env-up ENV=prod` or `make env-up ENV=preprod` to deploy specific environments
- Environment files `env/.env.prod` and `env/.env.preprod` are tracked in git and hold each environment's service versions and replica counts

## Cluster Management
- The Docker Swarm cluster runs on remote infrastructure, not on the development machine
- DO NOT execute cluster management commands (make commands, docker stack deploy, etc.)
- Instead, suggest the appropriate commands for the user to run on their cluster nodes
- Configuration files and documentation should be created/modified as needed

## Repository Structure
- `docker-swarm-stack.yml` - Main service stack configuration
- `env/` - Environment-specific configuration files (.env.prod, .env.preprod)
- Service configurations are organized by component (nginx, pihole, jellyfin)
- Container persistence volumes are mapped to local directories

## Allowed External Resources
- https://github.com/pi-hole/docker-pi-hole - Pi-hole Docker repository