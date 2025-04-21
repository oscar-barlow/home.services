# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- `docker-compose build` - Build all containers
- `docker-compose up` - Start all services
- `docker-compose up -d` - Start services in detached mode
- `docker-compose down` - Stop all services
- `make build` - Build containers using the Makefile

## Code Style Guidelines
- YAML Indentation: Use 2 spaces
- Docker Compose: Follow official naming conventions for services and volumes
- Nginx Config: Follow standard nginx configuration patterns
- Comments: Use descriptive comments for service configurations
- Network Configuration: Use bridge networking with descriptive names
- Environment Variables: Use quotes for values with special characters
- Mount Points: Use relative paths for container config, absolute paths for media

## Repository Structure
- Service configurations are organized by component (nginx, pihole, jellyfin)
- Each service has its own configuration directory
- Container persistence volumes are mapped to local directories

## Allowed External Resources
- https://github.com/pi-hole/docker-pi-hole - Pi-hole Docker repository