.PHONY: backup-install env-down env-up export-storage help import-storage inspect-node list-services lvm-extend lvm-init network-up network-down node-label provision-node service-down service-remove swarm-init swarm-join swarm-deploy swarm-down

# Default environment if not specified
ENV ?= preprod
SERVICE ?=

help:
	@echo "Available commands:"
	@echo "  backup-install - Install backup system (script, systemd units)"
	@echo "  env-down       - Stop all services for ENV (default: preprod)"
	@echo "  env-up         - Start all services for ENV (default: preprod)"
	@echo "  export-storage - Export storage volume via NFS (requires LOCAL_PATH and IP)"
	@echo "  import-storage - Import storage volume via NFS (requires IP, REMOTE_PATH, LOCAL_PATH)"
	@echo "  inspect-node   - Inspect Docker Swarm node details (requires HOSTNAME)"
	@echo "  lvm-init       - Initialize LVM storage system (requires DEVICES)"
	@echo "  lvm-extend     - Extend LVM with additional devices (requires DEVICES)"
	@echo "  list-services  - List services for ENV (default: preprod)"
	@echo "  network-up     - Create shared Docker overlay network for all environments"
	@echo "  network-down   - Remove shared Docker overlay network"
	@echo "  node-label     - Add labels to swarm node (requires NODE_ID, optional: LABEL_HARDWARE, LABEL_CLASS)"
	@echo "  provision-node - Complete node setup (join swarm, configure labels)"
	@echo "  service-down   - Stop specific SERVICE in ENV (requires SERVICE=name)"
	@echo "  service-remove - Remove specific SERVICE from ENV stack (requires SERVICE=name)"
	@echo "  swarm-init     - Initialize Docker Swarm on this node as manager (optional: LABEL_HARDWARE, LABEL_CLASS)"
	@echo "  swarm-join     - Join Docker Swarm as worker (requires MANAGER_IP and TOKEN)"
	@echo "  swarm-deploy   - Deploy stack to Docker Swarm for ENV (default: preprod)"
	@echo "  swarm-down     - Remove stack from Docker Swarm for ENV (default: preprod)"
	@echo ""
	@echo "Examples:"
	@echo "  make env-up ENV=prod"
	@echo "  make service-down ENV=prod SERVICE=jellyfin"
	@echo "  make service-remove ENV=prod SERVICE=prometheus"
	@echo "  make export-storage LOCAL_PATH=/srv/data IP=192.168.1.100"
	@echo "  make import-storage IP=192.168.1.10 REMOTE_PATH=/media/pi/Data-2 LOCAL_PATH=/mnt/Data-2"
	@echo "  make inspect-node HOSTNAME=rpi-3-0"
	@echo "  make list-services ENV=prod"
	@echo "  make lvm-init DEVICES='/dev/sda /dev/sdb'"
	@echo "  make lvm-extend DEVICES='/dev/sdc'"
	@echo "  make network-up"
	@echo "  make network-down"
	@echo "  make node-label NODE_ID=xyz123abc LABEL_HARDWARE=rpi-3 LABEL_CLASS=small"
	@echo "  make swarm-join MANAGER_IP=192.168.1.10 TOKEN=SWMTKN-..."
	@echo "  make swarm-init LABEL_HARDWARE=rpi-4 LABEL_CLASS=medium"
	@echo "  make swarm-deploy ENV=prod"

backup-install:
	@echo "🚀 Installing backup system..."
	@echo "📝 Installing backup script..."
	sudo cp backup/backup.sh /usr/local/bin/
	sudo chmod +x /usr/local/bin/backup.sh
	@echo "📦 Installing systemd units..."
	sudo cp backup/backup.service backup/backup.timer /etc/systemd/system/
	sudo systemctl daemon-reload
	@echo "🔧 Enabling backup timer..."
	sudo systemctl enable backup.timer
	sudo systemctl start backup.timer
	@echo "🔧 Setting up configuration directory..."
	sudo mkdir -p /etc/backup
	sudo cp backup/example-secrets.conf /etc/backup/prod-secrets.conf
	sudo cp backup/example-secrets.conf /etc/backup/preprod-secrets.conf
	sudo chmod 600 /etc/backup/*-secrets.conf
	sudo chown root:root /etc/backup/*-secrets.conf
	@echo "✅ Backup system installed!"
	@echo "📋 Edit configuration files with your credentials:"
	@echo "  sudo vim /etc/backup/prod-secrets.conf"
	@echo "  sudo vim /etc/backup/preprod-secrets.conf"
	@echo "📋 Timer status:"
	systemctl status backup.timer --no-pager

env-down:
	@echo "🛑 Removing stack from Docker Swarm for environment: $(ENV)"
	@echo "🔍 Checking if stack exists..."
	@if docker stack ls --format "{{.Name}}" | grep -q "^homelab-$(ENV)$$"; then \
		echo "📦 Removing homelab-$(ENV) stack..."; \
		docker stack rm homelab-$(ENV); \
		echo "✅ Stack removal complete!"; \
	else \
		echo "⚠️  Stack homelab-$(ENV) not found"; \
	fi

env-up:
	@echo "🚀 Deploying stack to Docker Swarm for environment: $(ENV)"
	@echo "🔍 Checking if swarm is initialized..."
	@if docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "inactive"; then \
		echo "❌ Error: Docker Swarm not initialized. Run 'make swarm-init' first."; \
		exit 1; \
	fi
	@echo "📦 Generating resolved config files..."
	@export $$(cat env/.env.$(ENV) | xargs) && \
	envsubst '$${DOMAIN_SUFFIX}' < nginx/nginx.conf.template > nginx/nginx.$(ENV).conf && \
	envsubst < docker-swarm-stack.yml > docker-swarm-stack.$(ENV).yml
	@echo "📦 Deploying homelab stack..."
	docker stack deploy --detach=true --compose-file docker-swarm-stack.$(ENV).yml --prune homelab-$(ENV)
	@echo "✅ Stack deployment complete!"
	@echo "📋 Current services:"
	docker service ls --filter label=com.docker.stack.namespace=homelab-$(ENV)

export-storage:
	@echo "📦 Starting NFS storage export process..."
	@if [ -z "$(LOCAL_PATH)" ]; then echo "❌ Error: LOCAL_PATH variable is required. Use: make export-storage LOCAL_PATH=/srv/data IP=192.168.1.100"; exit 1; fi
	@if [ -z "$(IP)" ]; then echo "❌ Error: IP variable is required. Use: make export-storage LOCAL_PATH=/srv/data IP=192.168.1.100"; exit 1; fi
	@echo "🔍 Checking if $(LOCAL_PATH) exists and is accessible..."
	@if [ ! -d "$(LOCAL_PATH)" ]; then echo "❌ Error: $(LOCAL_PATH) does not exist. Please create the directory first."; exit 1; fi
	@echo "✅ Path verified: $(LOCAL_PATH)"
	@echo "🔧 Checking if export already exists..."
	@if grep -q "^$(LOCAL_PATH) $(IP)/32" /etc/exports 2>/dev/null; then \
		echo "✅ Export already exists for $(LOCAL_PATH) to $(IP)/32"; \
	else \
		echo "📝 Adding new NFS export: $(LOCAL_PATH) $(IP)/32(rw,sync,no_subtree_check,no_root_squash)"; \
		echo '$(LOCAL_PATH) $(IP)/32(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports; \
	fi
	@echo "🔄 Refreshing NFS exports..."
	sudo exportfs -ra
	@echo "🚀 Enabling and starting NFS kernel server..."
	sudo systemctl enable nfs-kernel-server
	sudo systemctl start nfs-kernel-server
	@echo "✅ NFS export complete! Storage at $(LOCAL_PATH) is now accessible from $(IP)"
	@echo "📋 Current exports:"
	@sudo exportfs -v

import-storage:
	@echo "📦 Starting NFS storage import process..."
	@if [ -z "$(IP)" ]; then echo "❌ Error: IP variable is required. Use: make import-storage IP=192.168.1.10 REMOTE_PATH=/media/pi/Data-2 LOCAL_PATH=/mnt/Data-2"; exit 1; fi
	@if [ -z "$(REMOTE_PATH)" ]; then echo "❌ Error: REMOTE_PATH variable is required. Use: make import-storage IP=192.168.1.10 REMOTE_PATH=/media/pi/Data-2 LOCAL_PATH=/mnt/Data-2"; exit 1; fi
	@if [ -z "$(LOCAL_PATH)" ]; then echo "❌ Error: LOCAL_PATH variable is required. Use: make import-storage IP=192.168.1.10 REMOTE_PATH=/media/pi/Data-2 LOCAL_PATH=/mnt/Data-2"; exit 1; fi
	@echo "🔍 Checking if $(LOCAL_PATH) is already mounted..."
	@if mountpoint -q $(LOCAL_PATH); then \
		echo "✅ Storage is already mounted at $(LOCAL_PATH)"; \
		echo "📋 Current mount details:"; \
		mount | grep "$(LOCAL_PATH)" || echo "   No matching mount found"; \
	else \
		echo "📁 Creating mount directory: $(LOCAL_PATH)"; \
		sudo mkdir -p $(LOCAL_PATH); \
		echo "🔗 Mounting NFS volume: $(IP):$(REMOTE_PATH) -> $(LOCAL_PATH)"; \
		sudo mount -t nfs $(IP):$(REMOTE_PATH) $(LOCAL_PATH); \
		if mountpoint -q $(LOCAL_PATH); then \
			echo "✅ NFS import complete! Storage mounted successfully at $(LOCAL_PATH)"; \
		else \
			echo "❌ Error: Failed to mount NFS volume. Check network connectivity and NFS server status."; \
			exit 1; \
		fi; \
	fi
	@echo "🔧 Checking if persistent mount already exists in /etc/fstab..."
	@if grep -q "$(IP):$(REMOTE_PATH)" /etc/fstab 2>/dev/null; then \
		echo "✅ Persistent mount already exists in /etc/fstab"; \
	else \
		echo "📝 Adding persistent mount to /etc/fstab: $(IP):$(REMOTE_PATH) $(LOCAL_PATH) nfs defaults 0 0"; \
		echo '$(IP):$(REMOTE_PATH) $(LOCAL_PATH) nfs defaults 0 0' | sudo tee -a /etc/fstab; \
	fi
	@echo "📋 Mount verification:"
	@df -h $(LOCAL_PATH) 2>/dev/null || echo "   Unable to show disk usage for $(LOCAL_PATH)"
	@echo "📂 Directory contents:"
	@ls -la $(LOCAL_PATH) 2>/dev/null | head -10 || echo "   Unable to list directory contents"

inspect-node:
	@echo "🔍 Inspecting Docker Swarm node..."
	@if [ -z "$(HOSTNAME)" ]; then echo "❌ Error: HOSTNAME variable is required. Use: make inspect-node HOSTNAME=rpi-3-0"; exit 1; fi
	@echo "🔍 Checking if this is a manager node..."
	@if ! docker info --format '{{.Swarm.ControlAvailable}}' | grep -q "true"; then \
		echo "❌ Error: This command must be run from a swarm manager node."; \
		exit 1; \
	fi
	@echo "📋 Finding node by hostname: $(HOSTNAME)"
	@NODE_ID=$$(docker node ls --format '{{.ID}} {{.Hostname}}' | grep '$(HOSTNAME)' | awk '{print $$1}' | head -1); \
	if [ -z "$$NODE_ID" ]; then \
		echo "❌ Error: Node with hostname '$(HOSTNAME)' not found."; \
		echo "📋 Available nodes:"; \
		docker node ls --format "table {{.ID}}\t{{.Hostname}}\t{{.Status}}\t{{.Availability}}"; \
		exit 1; \
	fi; \
	echo "✅ Found node: $$NODE_ID"; \
	echo "📋 Node details:"; \
	docker node inspect $$NODE_ID --format '{{.Description.Hostname}} ({{.ID}}): {{range $$k,$$v := .Spec.Labels}}{{$$k}}={{$$v}} {{end}}'; \
	echo "📊 Node status: $$(docker node inspect $$NODE_ID --format '{{.Status.State}}')" ; \
	echo "🏷️  Node availability: $$(docker node inspect $$NODE_ID --format '{{.Spec.Availability}}')" ; \
	echo "🏛️  Node role: $$(docker node inspect $$NODE_ID --format '{{.Spec.Role}}')" ; \
	echo "📍 Node address: $$(docker node inspect $$NODE_ID --format '{{.Status.Addr}}')" ; \
	echo "🖥️  Platform: $$(docker node inspect $$NODE_ID --format '{{.Description.Platform.OS}}/{{.Description.Platform.Architecture}}')" ; \
	echo "🔧 Docker version: $$(docker node inspect $$NODE_ID --format '{{.Description.Engine.EngineVersion}}')"

lvm-extend:
	@echo "📈 Extending LVM storage system..."
	@if [ -z "$(DEVICES)" ]; then echo "❌ Error: DEVICES variable is required. Use: make lvm-extend DEVICES='/dev/sdc'"; exit 1; fi
	@echo "📋 Devices to add: $(DEVICES)"
	@echo "🔍 Verifying volume group 'homelab-vg' exists..."
	@if ! sudo vgs homelab-vg 2>/dev/null; then \
		echo "❌ Error: Volume group 'homelab-vg' not found. Use lvm-init first."; \
		exit 1; \
	fi
	@echo "🔧 Creating physical volumes on new devices..."
	@for device in $(DEVICES); do \
		echo "  Creating PV on $$device..."; \
		sudo pvcreate $$device; \
	done
	@echo "📦 Extending volume group with new devices..."
	sudo vgextend homelab-vg $(DEVICES)
	@echo "💾 Extending logical volume to use new space..."
	sudo lvextend -l +100%FREE /dev/homelab-vg/data-lv
	@echo "🗂️ Resizing filesystem to use new space..."
	sudo resize2fs /dev/homelab-vg/data-lv
	@echo "✅ LVM extension complete!"
	@echo "📊 Updated storage summary:"
	@sudo vgs homelab-vg
	@sudo lvs homelab-vg
	@df -h /srv/data

lvm-init:
	@echo "🚀 Initializing LVM storage system..."
	@if [ -z "$(DEVICES)" ]; then echo "❌ Error: DEVICES variable is required. Use: make lvm-init DEVICES='/dev/sda /dev/sdb'"; exit 1; fi
	@echo "📋 Devices to initialize: $(DEVICES)"
	@echo "🔍 Checking if volume group 'homelab-vg' already exists..."
	@if sudo vgs homelab-vg 2>/dev/null; then \
		echo "❌ Error: Volume group 'homelab-vg' already exists. Use lvm-extend to add devices."; \
		exit 1; \
	fi
	@echo "🔧 Creating physical volumes..."
	@for device in $(DEVICES); do \
		echo "  Creating PV on $$device..."; \
		sudo pvcreate $$device; \
	done
	@echo "📦 Creating volume group 'homelab-vg'..."
	sudo vgcreate homelab-vg $(DEVICES)
	@echo "💾 Creating logical volume 'data-lv' (using 100% of available space)..."
	sudo lvcreate -l 100%FREE -n data-lv homelab-vg
	@echo "🗂️ Formatting logical volume with ext4..."
	sudo mkfs.ext4 /dev/homelab-vg/data-lv
	@echo "📁 Creating mount point /srv/data..."
	sudo mkdir -p /srv/data
	@echo "🔗 Mounting logical volume..."
	sudo mount /dev/homelab-vg/data-lv /srv/data
	@echo "📝 Adding to /etc/fstab for persistent mounting..."
	@if ! grep -q "/dev/homelab-vg/data-lv" /etc/fstab 2>/dev/null; then \
		echo '/dev/homelab-vg/data-lv /srv/data ext4 defaults 0 2' | sudo tee -a /etc/fstab; \
	fi
	@echo "📁 Creating environment directories..."
	sudo mkdir -p /srv/data/prod /srv/data/preprod
	@echo "✅ LVM initialization complete!"
	@echo "📊 Storage summary:"
	@sudo vgs homelab-vg
	@sudo lvs homelab-vg
	@df -h /srv/data


list-services:
	@echo "📋 Services for environment: $(ENV)"
	docker service ls --filter label=com.docker.stack.namespace=homelab-$(ENV)

network-up:
	@echo "🚀 Creating Docker network"
	docker network create --driver overlay --attachable --scope swarm --subnet=10.10.1.0/24 --subnet=10.10.2.0/24 homelab-shared

network-down:
	@echo "🛑 Removing Docker network"
	@if docker network ls --filter name=homelab-shared --format "{{.Name}}" | grep -q "homelab-shared"; then \
		docker network rm homelab-shared; \
		echo "✅ Network removed successfully!"; \
	else \
		echo "⚠️  Network homelab-shared not found"; \
	fi

node-label:
	@echo "🏷️ Adding labels to swarm node..."
	@if [ -z "$(NODE_ID)" ]; then echo "❌ Error: NODE_ID variable is required. Use: make node-label NODE_ID=xyz123abc LABEL_HARDWARE=rpi-3 LABEL_CLASS=small"; exit 1; fi
	@echo "🔍 Checking if this is a manager node..."
	@if ! docker info --format '{{.Swarm.ControlAvailable}}' | grep -q "true"; then \
		echo "❌ Error: This command must be run from a swarm manager node."; \
		exit 1; \

	fi
	@echo "📋 Verifying node $(NODE_ID) exists..."
	@if ! docker node inspect $(NODE_ID) >/dev/null 2>&1; then \
		echo "❌ Error: Node $(NODE_ID) not found."; \
		echo "   Available nodes:"; \
		docker node ls --format "table {{.ID}}\t{{.Hostname}}\t{{.Status}}\t{{.Availability}}"; \
		exit 1; \
	fi
	@if [ -n "$(LABEL_HARDWARE)" ]; then \
		echo "🔧 Adding hardware label 'hardware=$(LABEL_HARDWARE)'..."; \
		docker node update --label-add hardware=$(LABEL_HARDWARE) $(NODE_ID); \
	fi
	@if [ -n "$(LABEL_CLASS)" ]; then \
		echo "🔧 Adding class label 'class=$(LABEL_CLASS)'..."; \
		docker node update --label-add class=$(LABEL_CLASS) $(NODE_ID); \
	fi
	@echo "✅ Node labeling complete!"
	@echo "📋 Node details:"
	@docker node inspect $(NODE_ID) --format 'Node: {{.Description.Hostname}} ({{.ID}}){{range $$k, $$v := .Spec.Labels}}{{printf "\n  %s: %s" $$k $$v}}{{end}}'

provision-node:
	@echo "🚀 Provisioning homelab node..."
	@echo "Step 1: Joining Docker Swarm..."
	@if [ -n "$(MANAGER_IP)" ] && [ -n "$(TOKEN)" ]; then \
		$(MAKE) swarm-join MANAGER_IP=$(MANAGER_IP) TOKEN=$(TOKEN); \
	else \
		echo "🔍 Docker Swarm join parameters needed."; \
		read -p "Enter manager IP (or press Enter to skip): " manager_ip; \
		if [ -n "$$manager_ip" ]; then \
			read -p "Enter join token: " token; \
			$(MAKE) swarm-join MANAGER_IP=$$manager_ip TOKEN=$$token; \
		else \
			echo "⚠️  Skipping swarm join"; \
			echo "   To join swarm later: make swarm-join MANAGER_IP=<ip> TOKEN=<token>"; \
		fi; \
	fi
	@echo "Step 2: Node labeling..."
	@echo "⚠️  Node labels must be added from a manager node using:"
	@echo "   make node-label NODE_ID=<node-id> LABEL_HARDWARE=<hardware> LABEL_CLASS=<class>"
	@echo "   Use 'docker node ls' on manager to see node IDs"
	@echo "✅ Node provisioning complete!"

service-down:
	@if [ -z "$(SERVICE)" ]; then echo "Error: SERVICE variable is required. Use: make service-down SERVICE=servicename"; exit 1; fi
	@echo "🛑 Scaling $(SERVICE) to 0 replicas in homelab-$(ENV) stack..."
	@if docker service ls --filter name=homelab-$(ENV)_$(SERVICE) --format "{{.Name}}" | grep -q "homelab-$(ENV)_$(SERVICE)"; then \
		docker service scale homelab-$(ENV)_$(SERVICE)=0; \
		echo "✅ Service $(SERVICE) scaled to 0 replicas"; \
	else \
		echo "⚠️  Service homelab-$(ENV)_$(SERVICE) not found"; \
	fi

service-remove:
	@if [ -z "$(SERVICE)" ]; then echo "Error: SERVICE variable is required. Use: make service-remove SERVICE=servicename"; exit 1; fi
	@echo "🗑️ Removing $(SERVICE) from homelab-$(ENV) stack..."
	@if docker service ls --filter name=homelab-$(ENV)_$(SERVICE) --format "{{.Name}}" | grep -q "homelab-$(ENV)_$(SERVICE)"; then \
		docker service rm homelab-$(ENV)_$(SERVICE); \
		echo "✅ Service $(SERVICE) removed from stack"; \
	else \
		echo "⚠️  Service homelab-$(ENV)_$(SERVICE) not found"; \
	fi


swarm-init:
	@echo "🚀 Initializing Docker Swarm on this node as manager..."
	@echo "🔍 Checking if node is already part of a swarm..."
	@if docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "inactive"; then \
		echo "🔧 Initializing new swarm..."; \
		docker swarm init; \
		echo "✅ Swarm initialization complete!"; \
		NODE_ID=$$(docker info --format '{{.Swarm.NodeID}}'); \
		if [ -n "$(LABEL_HARDWARE)" ]; then \
			echo "🏷️ Adding hardware label 'hardware=$(LABEL_HARDWARE)' to manager node..."; \
			docker node update --label-add hardware=$(LABEL_HARDWARE) $$NODE_ID; \
		fi; \
		if [ -n "$(LABEL_CLASS)" ]; then \
			echo "🏷️ Adding class label 'class=$(LABEL_CLASS)' to manager node..."; \
			docker node update --label-add class=$(LABEL_CLASS) $$NODE_ID; \
		fi; \
		if [ -n "$(LABEL_HARDWARE)" ] && [ -n "$(LABEL_CLASS)" ]; then \
			echo "✅ Labels added successfully!"; \
		fi; \
		echo "📋 Join tokens for worker nodes:"; \
		docker swarm join-token worker; \
		echo "📋 Join tokens for manager nodes:"; \
		docker swarm join-token manager; \
	else \
		echo "✅ Node is already part of a swarm"; \
		echo "📋 Current swarm status:"; \
		docker node ls; \
		NODE_ID=$$(docker info --format '{{.Swarm.NodeID}}'); \
		if [ -n "$(LABEL_HARDWARE)" ]; then \
			echo "🏷️ Adding hardware label 'hardware=$(LABEL_HARDWARE)' to manager node..."; \
			docker node update --label-add hardware=$(LABEL_HARDWARE) $$NODE_ID; \
		fi; \
		if [ -n "$(LABEL_CLASS)" ]; then \
			echo "🏷️ Adding class label 'class=$(LABEL_CLASS)' to manager node..."; \
			docker node update --label-add class=$(LABEL_CLASS) $$NODE_ID; \
		fi; \
		if [ -n "$(LABEL_HARDWARE)" ] && [ -n "$(LABEL_CLASS)" ]; then \
			echo "✅ Labels added successfully!"; \
		fi; \
	fi

swarm-join:
	@echo "🤝 Joining Docker Swarm as worker node..."
	@if [ -z "$(MANAGER_IP)" ]; then echo "❌ Error: MANAGER_IP variable is required. Use: make swarm-join MANAGER_IP=192.168.1.10 TOKEN=SWMTKN-..."; exit 1; fi
	@if [ -z "$(TOKEN)" ]; then echo "❌ Error: TOKEN variable is required. Use: make swarm-join MANAGER_IP=192.168.1.10 TOKEN=SWMTKN-..."; exit 1; fi
	@echo "🔍 Checking if node is already part of a swarm..."
	@if docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "inactive"; then \
		echo "🔗 Joining swarm at $(MANAGER_IP):2377..."; \
		docker swarm join --token $(TOKEN) $(MANAGER_IP):2377; \
		echo "✅ Successfully joined swarm!"; \
		NODE_ID=$$(docker info --format '{{.Swarm.NodeID}}'); \
		echo "📋 Node ID: $$NODE_ID"; \
		echo "⚠️  To add labels, run from a manager node:"; \
		echo "   make node-label NODE_ID=$$NODE_ID LABEL_HARDWARE=<hardware> LABEL_CLASS=<class>"; \
	else \
		echo "✅ Node is already part of a swarm"; \
		NODE_ID=$$(docker info --format '{{.Swarm.NodeID}}'); \
		echo "📋 Node ID: $$NODE_ID (Address: $$(docker info --format '{{.Swarm.NodeAddr}}'))"; \
		echo "⚠️  To add/update labels, run from a manager node:"; \
		echo "   make node-label NODE_ID=$$NODE_ID LABEL_HARDWARE=<hardware> LABEL_CLASS=<class>"; \
	fi

