# Storage Architecture

This document describes the storage system architecture and permissions model for the homelab.

## Permissions Model

### Environment Segregation

All services run as root within their containers for simplicity. Environment isolation is achieved through:

- **Directory separation**: `/srv/data/prod/` vs `/srv/data/preprod/`
- **Network isolation**: Separate IP ranges and DNS resolution
- **Service naming**: Different stack names (`homelab-prod` vs `homelab-preprod`)


## Mount Point Conventions

The system follows consistent mount point conventions based on storage type:

- **Physical media directly attached to a node**: Always mounted at `/media`
  - Examples: `/media/usb-drive`, `/media/pi/Data-0`
  - Used for local storage devices, USB drives, directly attached disks

- **Logical volumes**: Always mounted at `/mnt`
  - Examples: `/mnt/Data-1`, `/mnt/Data-2`
  - Used for LVM logical volumes (local physical storage only)
  - These volumes can be exported over NFS to other nodes

- **Network-imported storage**: Always mounted at `/mnt`
  - Examples: `/mnt/nfs-share`, `/mnt/pi-remote`
  - Used for NFS mounts from other nodes

- **Unified storage systems**: Mounted at `/srv`
  - Examples: `/srv/data` (LVM-backed unified storage)
  - Used for system-wide services and consolidated storage pools
  - Built from local physical storage, can be exported over NFS

## Storage Export

For exporting storage volumes via NFS:

```bash
# Export storage volume via NFS
make export-storage VOL=1 IP=192.168.1.100
```

This command:
- Validates required VOL and IP parameters
- Checks if mount point exists at /mnt/Data-$(VOL)
- Adds NFS export to /etc/exports (idempotent)
- Enables and starts NFS kernel server
- Shows current exports for verification

## Storage Import

For importing (mounting) storage volumes via NFS:

```bash
# Import storage volume via NFS
make import-storage VOL=1 IP=192.168.1.100
```

This command:
- Validates required VOL and IP parameters
- Checks if volume is already mounted (idempotent)
- Creates mount directory if needed
- Mounts NFS volume from remote server
- Adds persistent mount entry to /etc/fstab (idempotent)
- Verifies successful mount and shows disk usage
- Lists directory contents for verification

*Note: Additional storage architecture details will be added as the system is implemented.*