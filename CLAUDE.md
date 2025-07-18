# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- `docker compose -f docker-compose.application.yml build` - Build all containers
- `docker compose -f docker-compose.application.yml up` - Start all services
- `docker compose -f docker-compose.application.yml up -d` - Start services in detached mode
- `docker compose -f docker-compose.application.yml down` - Stop all services
- `make env-up` - Start services using the Makefile
- `make env-down` - Stop services using the Makefile
- `make network-up` - Create macvlan network infrastructure
- `make network-down` - Remove macvlan network infrastructure

## Code Style Guidelines
- YAML Indentation: Use 2 spaces
- Docker Compose: Follow official naming conventions for services and volumes
- Nginx Config: Follow standard nginx configuration patterns
- Comments: Use descriptive comments for service configurations
- Network Configuration: Use macvlan networking managed via Makefile commands
- Environment Variables: Use quotes for values with special characters
- Mount Points: Use relative paths for container config, absolute paths for media

## Service Deployment
- **Manual Service Placement**: Services are deployed manually on specific nodes using Docker Compose
- Each node requires the macvlan network to be created: `make network-up INTERFACE=<interface>`
- Use `make env-up ENV=<env>` to start all services on a node, or `make service-up SERVICE=<service> ENV=<env>` for individual services
- Service placement across nodes is managed manually - no automatic orchestration
- Each service has a dedicated IP address in the macvlan network as defined in environment files

## Repository Structure
- Service configurations are organized by component (nginx, pihole, jellyfin)
- Each service has its own configuration directory
- Container persistence volumes are mapped to local directories

## Allowed External Resources
- https://github.com/pi-hole/docker-pi-hole - Pi-hole Docker repository