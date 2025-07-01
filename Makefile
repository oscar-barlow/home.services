.PHONY: create-lvm-backing-file env-down env-up export-storage help import-storage install-shim lvm-extend lvm-init network-down network-up provision-node service-down service-up users-create users-remove users-verify

# Default environment if not specified
ENV ?= preprod
SERVICE ?=

help:
	@echo "Available commands:"
	@echo "  create-lvm-backing-file - Create LVM backing file on mounted volume (requires SIZE and VOL)"
	@echo "  env-down       - Stop all services for ENV (default: preprod)"
	@echo "  env-up         - Start all services for ENV (default: preprod)"
	@echo "  export-storage - Export storage volume via NFS (requires LOCAL_PATH and IP)"
	@echo "  import-storage - Import storage volume via NFS (requires IP, REMOTE_PATH, LOCAL_PATH)"
	@echo "  install-shim   - Install systemd network shim service"
	@echo "  lvm-init       - Initialize LVM storage system (requires DEVICES)"
	@echo "  lvm-extend     - Extend LVM with additional devices (requires DEVICES)"
	@echo "  network-down   - Stop network services"
	@echo "  network-up     - Start network services"
	@echo "  provision-node - Complete node setup (users, shim, docker swarm)"
	@echo "  service-down   - Stop specific SERVICE in ENV (requires SERVICE=name)"
	@echo "  service-up     - Start specific SERVICE in ENV (requires SERVICE=name)"
	@echo "  users-create   - Create prod/preprod users and groups on current node"
	@echo "  users-remove   - Remove prod/preprod users and groups from current node"
	@echo "  users-verify   - Verify user/group consistency on current node"
	@echo ""
	@echo "Examples:"
	@echo "  make create-lvm-backing-file SIZE=500G VOL=/mnt/Data-2"
	@echo "  make env-up ENV=prod"
	@echo "  make service-up ENV=prod SERVICE=jellyfin"
	@echo "  make export-storage LOCAL_PATH=/srv/data IP=192.168.1.100"
	@echo "  make import-storage IP=192.168.1.10 REMOTE_PATH=/media/pi/Data-2 LOCAL_PATH=/mnt/Data-2"
	@echo "  make lvm-init DEVICES='/dev/sda /dev/sdb'"
	@echo "  make lvm-extend DEVICES='/dev/sdc'"
	@echo "  make users-create"

create-lvm-backing-file:
	@echo "📦 Creating LVM backing file on mounted volume..."
	@if [ -z "$(SIZE)" ]; then echo "❌ Error: SIZE variable is required. Use: make create-lvm-backing-file SIZE=500G VOL=/mnt/Data-2"; exit 1; fi
	@if [ -z "$(VOL)" ]; then echo "❌ Error: VOL variable is required. Use: make create-lvm-backing-file SIZE=500G VOL=/mnt/Data-2"; exit 1; fi
	@echo "🔍 Verifying mount point $(VOL) exists and is mounted..."
	@if [ ! -d "$(VOL)" ]; then echo "❌ Error: $(VOL) does not exist. Please mount the volume first."; exit 1; fi
	@if ! mountpoint -q $(VOL); then echo "❌ Error: $(VOL) is not mounted. Please mount the volume first."; exit 1; fi
	@echo "✅ Mount point verified: $(VOL)"
	@echo "💾 Checking available space on $(VOL)..."
	@df -h $(VOL)
	@echo "🔧 Creating backing file $(VOL)/lvm-backing.img with size $(SIZE)..."
	@if [ -f "$(VOL)/lvm-backing.img" ]; then \
		echo "⚠️  Backing file already exists at $(VOL)/lvm-backing.img"; \
		ls -lh $(VOL)/lvm-backing.img; \
	else \
		sudo fallocate -l $(SIZE) $(VOL)/lvm-backing.img; \
		echo "✅ Backing file created successfully"; \
		ls -lh $(VOL)/lvm-backing.img; \
	fi
	@echo "🔒 Setting appropriate permissions on backing file..."
	sudo chmod 600 $(VOL)/lvm-backing.img
	@echo "🔗 Creating loop device for backing file..."
	@LOOP_DEVICE=$$(sudo losetup -f --show $(VOL)/lvm-backing.img); \
	echo "✅ Loop device created: $$LOOP_DEVICE"; \
	echo "📋 Loop device ready for LVM. Use: make lvm-extend DEVICES='$$LOOP_DEVICE'"

env-down:
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) down

env-up:
	docker compose -f docker-compose.application.yml --env-file env/.env.$(ENV) up -d

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
	@sudo exportfs -v | grep "$(LOCAL_PATH)" || echo "   No matching exports found"

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

install-shim:
	@echo "Installing homelab network shim service..."
	sudo cp homelab-shim.service /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable homelab-shim.service
	sudo systemctl start homelab-shim.service
	@echo "Service installed, enabled, and started."

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
	@echo "👥 Creating environment directories with proper ownership..."
	sudo mkdir -p /srv/data/prod /srv/data/preprod
	sudo chown -R 5001:5001 /srv/data/prod
	sudo chown -R 6001:6001 /srv/data/preprod
	@echo "✅ LVM initialization complete!"
	@echo "📊 Storage summary:"
	@sudo vgs homelab-vg
	@sudo lvs homelab-vg
	@df -h /srv/data

network-down:
	docker network rm homelab-macvlan || true

network-up:
	docker network create -d macvlan \
		--subnet=192.168.1.0/24 \
		--gateway=192.168.1.1 \
		--ip-range=192.168.1.192/26 \
		-o parent=eth0 \
		homelab-macvlan || true

provision-node:
	@echo "Provisioning homelab node..."
	@echo "Step 1: Creating users and groups..."
	@$(MAKE) users-create
	@echo "Step 2: Installing systemd shim..."
	@$(MAKE) install-shim
	@echo "Step 3: Verifying setup..."
	@$(MAKE) users-verify
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