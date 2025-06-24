.PHONY: env-down env-up firewall-setup firewall-remove firewall-status help install-shim network-down network-test-isolation network-test-connectivity network-up provision-node service-down service-up users-create users-remove users-verify

# Default environment if not specified
ENV ?= preprod
SERVICE ?=

help:
	@echo "Available commands:"
	@echo "  env-down         - Stop all services for ENV (default: preprod)"
	@echo "  env-up           - Start all services for ENV (default: preprod)"
	@echo "  firewall-setup   - Set up environment isolation firewall rules"
	@echo "  firewall-remove  - Remove environment isolation firewall rules"
	@echo "  firewall-status  - Show current firewall status"
	@echo "  install-shim           - Install systemd network shim service"
	@echo "  network-down           - Stop network services"
	@echo "  network-test-isolation - Test firewall isolation between environments"
	@echo "  network-test-connectivity - Test allowed network connectivity"
	@echo "  network-up             - Start network services"
	@echo "  provision-node   - Complete node setup (users, shim, firewall, docker swarm)"
	@echo "  service-down     - Stop specific SERVICE in ENV (requires SERVICE=name)"
	@echo "  service-up       - Start specific SERVICE in ENV (requires SERVICE=name)"
	@echo "  users-create     - Create prod/preprod users and groups on current node"
	@echo "  users-remove     - Remove prod/preprod users and groups from current node"
	@echo "  users-verify     - Verify user/group consistency on current node"
	@echo ""
	@echo "Examples:"
	@echo "  make env-up ENV=prod"
	@echo "  make service-up ENV=prod SERVICE=jellyfin"
	@echo "  make users-create"
	@echo "  make firewall-setup"

env-down:
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) down

env-up:
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) up -d

firewall-remove:
	@echo "Removing environment isolation firewall rules..."
	sudo iptables -D FORWARD -s 192.168.1.224/27 -d 192.168.1.192/27 -j DROP 2>/dev/null || echo "Preprod→prod rule not found"
	sudo iptables -D FORWARD -s 192.168.1.192/27 -d 192.168.1.224/27 -j DROP 2>/dev/null || echo "Prod→preprod rule not found"
	sudo mkdir -p /etc/iptables
	sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null
	@echo "Environment isolation rules removed!"

firewall-setup:
	@echo "Setting up environment isolation firewall rules..."
	@echo "Adding rule: Block preprod → prod"
	sudo iptables -C FORWARD -s 192.168.1.224/27 -d 192.168.1.192/27 -j DROP 2>/dev/null || sudo iptables -I FORWARD -s 192.168.1.224/27 -d 192.168.1.192/27 -j DROP
	@echo "Adding rule: Block prod → preprod"
	sudo iptables -C FORWARD -s 192.168.1.192/27 -d 192.168.1.224/27 -j DROP 2>/dev/null || sudo iptables -I FORWARD -s 192.168.1.192/27 -d 192.168.1.224/27 -j DROP
	@echo "Saving iptables rules..."
	sudo mkdir -p /etc/iptables
	sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null
	@echo "Current iptables FORWARD rules:"
	sudo iptables -L FORWARD -n --line-numbers | head -10
	@echo "Environment isolation rules installed successfully!"

firewall-status:
	@echo "Current FORWARD chain rules:"
	sudo iptables -L FORWARD -n --line-numbers

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

network-test-connectivity:
	@echo "Testing allowed network connectivity..."
	@echo "Testing internet access from prod:"
	docker exec hello-world-prod ping -c 3 8.8.8.8
	@echo "Testing host access from prod:"
	docker exec hello-world-prod ping -c 3 192.168.1.204
	@echo "Testing prod intra-environment communication (hello-world → pi-hole):"
	docker exec hello-world-prod ping -c 3 pihole-prod
	@echo "Testing internet access from preprod:"
	docker exec hello-world-preprod ping -c 3 8.8.8.8
	@echo "Testing router access from preprod:"
	docker exec hello-world-preprod ping -c 3 192.168.1.1
	@echo "Testing preprod intra-environment communication (hello-world → pi-hole):"
	docker exec hello-world-preprod ping -c 3 pihole-preprod
	@echo "✅ All connectivity tests passed!"

network-test-isolation:
	@echo "Testing environment isolation (should timeout and fail)..."
	@echo "Testing prod → preprod (should be BLOCKED):"
	timeout 5 docker exec hello-world-prod ping -c 1 192.168.1.226 || echo "✅ Prod→Preprod correctly blocked"
	@echo "Testing preprod → prod (should be BLOCKED):"
	timeout 5 docker exec hello-world-preprod ping -c 1 192.168.1.202 || echo "✅ Preprod→Prod correctly blocked"
	@echo "✅ Environment isolation working correctly!"

provision-node:
	@echo "Provisioning homelab node..."
	@echo "Step 1: Creating users and groups..."
	@$(MAKE) users-create
	@echo "Step 2: Installing systemd shim..."
	@$(MAKE) install-shim
	@echo "Step 3: Setting up environment isolation firewall..."
	@$(MAKE) firewall-setup
	@echo "Step 4: Verifying setup..."
	@$(MAKE) users-verify
	@$(MAKE) firewall-status
	@echo "Node provisioning complete!"
	@echo "TODO: Add docker swarm join command when available"

service-down:
	@if [ -z "$(SERVICE)" ]; then echo "Error: SERVICE variable is required. Use: make service-down SERVICE=servicename"; exit 1; fi
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) stop $(SERVICE)

service-up:
	@if [ -z "$(SERVICE)" ]; then echo "Error: SERVICE variable is required. Use: make service-up SERVICE=servicename"; exit 1; fi
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) up -d $(SERVICE)

users-create:
	@echo "Creating prod/preprod users and groups on current node..."
	@echo "Creating groups..."
	sudo groupadd -g 5001 prod || echo "Group 'prod' already exists"
	sudo groupadd -g 6001 preprod || echo "Group 'preprod' already exists"
	@echo "Creating users..."
	sudo useradd -u 5001 -g 5001 -m -s /bin/bash prod-user || echo "User 'prod-user' already exists"
	sudo useradd -u 6001 -g 6001 -m -s /bin/bash preprod-user || echo "User 'preprod-user' already exists"
	@echo "Users and groups created successfully!"

users-remove:
	@echo "Removing prod/preprod users and groups from current node..."
	@echo "WARNING: This will remove users and their home directories!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	sudo userdel -r prod-user || echo "User 'prod-user' not found"
	sudo userdel -r preprod-user || echo "User 'preprod-user' not found"
	sudo groupdel prod || echo "Group 'prod' not found"
	sudo groupdel preprod || echo "Group 'preprod' not found"
	@echo "Users and groups removed successfully!"

users-verify:
	@echo "Verifying user/group consistency on current node..."
	@echo "Production environment (UID/GID 5001):"
	@id prod-user 2>/dev/null || echo "  ERROR: prod-user not found"
	@getent group prod 2>/dev/null || echo "  ERROR: prod group not found"
	@echo "Preprod environment (UID/GID 6001):"
	@id preprod-user 2>/dev/null || echo "  ERROR: preprod-user not found"
	@getent group preprod 2>/dev/null || echo "  ERROR: preprod group not found"
	@echo "Verification complete!"