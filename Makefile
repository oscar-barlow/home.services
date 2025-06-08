.PHONY: help env-up env-down service-up service-down

# Default environment if not specified
ENV ?= preprod
SERVICE ?=

help:
	@echo "Available commands:"
	@echo "  env-up         - Start all services for ENV (default: preprod)"
	@echo "  env-down       - Stop all services for ENV (default: preprod)"
	@echo "  service-up     - Start specific SERVICE in ENV (requires SERVICE=name)"
	@echo "  service-down   - Stop specific SERVICE in ENV (requires SERVICE=name)"
	@echo ""
	@echo "Examples:"
	@echo "  make env-up ENV=prod"
	@echo "  make service-up ENV=prod SERVICE=jellyfin"

# Generic environment commands
env-up:
	docker compose --env-file env/.env.$(ENV) up -d

env-down:
	docker compose --env-file env/.env.$(ENV) down

# Service-specific commands
service-up:
	@if [ -z "$(SERVICE)" ]; then echo "Error: SERVICE variable is required. Use: make service-up SERVICE=servicename"; exit 1; fi
	docker compose --env-file env/.env.$(ENV) up -d $(SERVICE)

service-down:
	@if [ -z "$(SERVICE)" ]; then echo "Error: SERVICE variable is required. Use: make service-down SERVICE=servicename"; exit 1; fi
	docker compose --env-file env/.env.$(ENV) stop $(SERVICE)