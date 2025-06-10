.PHONY: help env-down env-up install-shim network-down network-up service-down service-up

# Default environment if not specified
ENV ?= preprod
SERVICE ?=

help:
	@echo "Available commands:"
	@echo "  env-down       - Stop all services for ENV (default: preprod)"
	@echo "  env-up         - Start all services for ENV (default: preprod)"
	@echo "  install-shim   - Install systemd network shim service"
	@echo "  network-down   - Stop network services"
	@echo "  network-up     - Start network services"
	@echo "  service-down   - Stop specific SERVICE in ENV (requires SERVICE=name)"
	@echo "  service-up     - Start specific SERVICE in ENV (requires SERVICE=name)"
	@echo ""
	@echo "Examples:"
	@echo "  make env-up ENV=prod"
	@echo "  make service-up ENV=prod SERVICE=jellyfin"

env-down:
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) down

env-up:
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) up -d

install-shim:
	@echo "Installing homelab network shim service..."
	sudo cp homelab-shim.service /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable homelab-shim.service
	sudo systemctl start homelab-shim.service
	@echo "Service installed, enabled, and started."

network-down:
	docker network rm homelab-macvlan || true

network-up:
	docker network create -d macvlan \
		--subnet=192.168.1.0/24 \
		--gateway=192.168.1.1 \
		--ip-range=192.168.1.192/26 \
		-o parent=eth0 \
		homelab-macvlan || true

service-down:
	@if [ -z "$(SERVICE)" ]; then echo "Error: SERVICE variable is required. Use: make service-down SERVICE=servicename"; exit 1; fi
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) stop $(SERVICE)

service-up:
	@if [ -z "$(SERVICE)" ]; then echo "Error: SERVICE variable is required. Use: make service-up SERVICE=servicename"; exit 1; fi
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) up -d $(SERVICE)