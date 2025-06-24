# Storage Architecture

This document describes the storage system architecture and permissions model for the homelab.

## Permissions Model

### Environment Segregation

The system uses Unix UID/GID for strict environment isolation:

- **Production environment**: UID/GID 5001 (`prod-user`/`prod` group)
- **Preprod environment**: UID/GID 6001 (`preprod-user`/`preprod` group)

### User Management

All homelab nodes must have identical users and groups for consistent permissions across the cluster.

#### Creating Users

```bash
# Create users on current node
make users-create

# Verify users exist with correct UIDs/GIDs
make users-verify

# Remove users (with confirmation)
make users-remove
```

#### Manual User Creation

If needed, users can be created manually on each node:

```bash
# Create groups
sudo groupadd -g 5001 prod
sudo groupadd -g 6001 preprod

# Create users
sudo useradd -u 5001 -g 5001 -m -s /bin/bash prod-user
sudo useradd -u 6001 -g 6001 -m -s /bin/bash preprod-user
```

### Docker Container Integration

Services should run with environment-specific UIDs:

```yaml
services:
  service-prod:
    user: "5001:5001"  # Production UID:GID
    
  service-preprod:
    user: "6001:6001"  # Preprod UID:GID
```

## Node Provisioning

For complete node setup:

```bash
# Provision a new homelab node
make provision-node
```

This command runs:
1. User and group creation
2. Systemd shim installation  
3. User verification

*Note: Additional storage architecture details will be added as the system is implemented.*