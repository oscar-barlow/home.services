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
- Comments: Use descriptive comments for service configurations
- Network Configuration: Use Docker Swarm overlay networks with Traefik reverse proxy
- Environment Variables: Use quotes for values with special characters
- Mount Points: Use relative paths for container config, absolute paths for media

## Configuration Management
- `docker-swarm-stack.yml` is the single source of truth for all service configurations
- Service replicas are controlled via environment variables in env/.env.{ENV_NAME} files
- Use `make env-up ENV=prod` or `make env-up ENV=preprod` to deploy specific environments

## Repository Structure
- `docker-swarm-stack.yml` - Main service stack configuration
- `env/` - Environment-specific configuration files (.env.prod, .env.preprod)
- Service configurations are organized by component (nginx, pihole, jellyfin)
- Container persistence volumes are mapped to local directories

## Allowed External Resources
- https://github.com/pi-hole/docker-pi-hole - Pi-hole Docker repository