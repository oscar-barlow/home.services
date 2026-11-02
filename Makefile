.PHONY: help config check preflight env-up env-down service-up service-down service-remove list-services logs network-up network-down jellyfin-up jellyfin-down backup-install export-storage import-storage lvm-extend lvm-init

ENV ?= preprod
SERVICE ?=
COMPOSE = ENV="$(ENV)" bin/compose

help:
	@echo "make config ENV=prod|preprod         Validate the Compose configuration"
	@echo "make check                          Run migration configuration checks"
	@echo "sudo make preflight ENV=prod|preprod Check secrets, storage and old containers"
	@echo "sudo make env-up ENV=prod|preprod    Start or update an environment on the N100"
	@echo "sudo make env-down ENV=prod|preprod  Stop an environment without deleting data"
	@echo "sudo make service-up ENV=prod SERVICE=name"
	@echo "make service-down ENV=prod SERVICE=name"
	@echo "make list-services ENV=prod"
	@echo "make logs ENV=prod SERVICE=name"
	@echo "make network-up|network-down        Manage the shared ingress bridge"
	@echo "Storage and backup: backup-install, export-storage, import-storage, lvm-init, lvm-extend"

config:
	$(COMPOSE) config --quiet

check:
	python3 -m unittest discover -s tests -v

preflight:
	ENV="$(ENV)" bin/preflight

env-up: preflight
	$(MAKE) network-up
	$(COMPOSE) up -d --remove-orphans
	$(COMPOSE) ps

env-down:
	$(COMPOSE) down --remove-orphans

service-up:
	@test -n "$(SERVICE)" || { echo "SERVICE is required" >&2; exit 1; }
	ENV="$(ENV)" bin/preflight "$(SERVICE)"
	$(MAKE) network-up
	$(COMPOSE) up -d "$(SERVICE)"

service-down:
	@test -n "$(SERVICE)" || { echo "SERVICE is required" >&2; exit 1; }
	$(COMPOSE) stop "$(SERVICE)"

service-remove:
	@test -n "$(SERVICE)" || { echo "SERVICE is required" >&2; exit 1; }
	$(COMPOSE) rm --stop --force "$(SERVICE)"

list-services:
	$(COMPOSE) ps -a

logs:
	$(COMPOSE) logs --tail 100 $(SERVICE)

network-up:
	@if docker network inspect homelab-ingress >/dev/null 2>&1; then \
		test "$$(docker network inspect homelab-ingress --format '{{.Driver}}')" = bridge || { echo "homelab-ingress must be a bridge network" >&2; exit 1; }; \
	else \
		docker network create --driver bridge homelab-ingress; \
	fi

network-down:
	docker network rm homelab-ingress

jellyfin-up:
	$(MAKE) service-up ENV="$(ENV)" SERVICE=jellyfin

jellyfin-down:
	$(MAKE) service-down ENV="$(ENV)" SERVICE=jellyfin


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
