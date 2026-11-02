# Storage Architecture

This document describes the storage system architecture and permissions model for the homelab.

## Permissions Model

### Environment Segregation

Services retain the user settings supplied by their images. Environment separation uses:

- **Directory separation**: `/srv/data/prod/` vs `/srv/data/preprod/`
- **Backend networks**: Separate Compose bridges, with a shared HTTP ingress bridge
- **Service naming**: Different Compose project names (`homelab-prod` vs `homelab-preprod`)


Existing service data and Traefik certificates remain on the N100 under
`/srv/data/${ENV_NAME}`. The Pi previously mounted that storage over NFS;
Compose on the N100 uses the same paths locally. Verify the backing mount
before deployment. Missing bind sources fail instead of being silently created.

Secrets live outside this data tree; see [secrets.md](secrets.md) for their
permissions and separate backup requirement.

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
make export-storage LOCAL_PATH=/srv/data IP=192.168.1.100
```

This command:
- Validates required LOCAL_PATH and IP parameters
- Checks that LOCAL_PATH exists
- Adds NFS export to /etc/exports (idempotent)
- Enables and starts NFS kernel server
- Shows current exports for verification

## Storage Import

For importing (mounting) storage volumes via NFS:

```bash
# Import storage volume via NFS
make import-storage IP=192.168.1.10 REMOTE_PATH=/media/pi/Data-2 LOCAL_PATH=/mnt/Data-2
```

This command:
- Validates required IP, REMOTE_PATH and LOCAL_PATH parameters
- Checks if volume is already mounted (idempotent)
- Creates mount directory if needed
- Mounts NFS volume from remote server
- Adds persistent mount entry to /etc/fstab (idempotent)
- Verifies successful mount and shows disk usage
- Lists directory contents for verification

## Backup System

Automated daily backups using Borg and B2 cloud storage.

```bash
# Install backup system
make backup-install

# Configure secrets files (edit with your credentials)
sudo vim /etc/backup/prod-secrets.conf
sudo vim /etc/backup/preprod-secrets.conf

# Manual backup
sudo /usr/local/bin/backup.sh prod
```

*Note: Additional storage architecture details will be added as the system is implemented.*
