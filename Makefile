.PHONY: help env-up env-down network-up network-down service-up service-down

# Default environment if not specified
ENV ?= preprod
SERVICE ?=

help:
	@echo "Available commands:"
	@echo "  env-up         - Start all services for ENV (default: preprod)"
	@echo "  env-down       - Stop all services for ENV (default: preprod)"
	@echo "  network-up     - Start network services"
	@echo "  network-down   - Stop network services"
	@echo "  service-up     - Start specific SERVICE in ENV (requires SERVICE=name)"
	@echo "  service-down   - Stop specific SERVICE in ENV (requires SERVICE=name)"
	@echo ""
	@echo "Examples:"
	@echo "  make env-up ENV=prod"
	@echo "  make service-up ENV=prod SERVICE=jellyfin"

# Generic environment commands
env-up:
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) up -d

env-down:
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) down

network-up:
	docker network create -d macvlan \
		--subnet=192.168.1.0/24 \
		--gateway=192.168.1.1 \
		--ip-range=192.168.1.192/26 \
		-o parent=eth0 \
		homelab-macvlan || true

network-down:
	docker network rm homelab-macvlan || true

# Service-specific commands
service-up:
	@if [ -z "$(SERVICE)" ]; then echo "Error: SERVICE variable is required. Use: make service-up SERVICE=servicename"; exit 1; fi
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) up -d $(SERVICE)

service-down:
	@if [ -z "$(SERVICE)" ]; then echo "Error: SERVICE variable is required. Use: make service-down SERVICE=servicename"; exit 1; fi
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) stop $(SERVICE)