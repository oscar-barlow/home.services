## Overview

This document outlines the architecture for a unified storage system using an N100 machine as the primary server with a Raspberry Pi providing additional network storage. The solution provides a single filesystem interface across all network devices while maintaining fault tolerance and operational flexibility.

## Architecture Components

### Core Concepts (5 Key Technologies)

1. **Mount** - Network filesystem mounting via NFS
2. **pvcreate** - LVM physical volume creation for local storage
3. **vgcreate** - LVM volume group creation to combine local drives
4. **lvcreate** - LVM logical volume creation for unified local storage
5. **mergerfs** - Union filesystem to combine local and remote storage

## System Architecture

```
┌─────────────────┐    NFS    ┌─────────────────────────────┐    NFS/SMB    ┌─────────────┐
│ Raspberry Pi    │◄─────────►│ N100 Storage Server         │◄─────────────►│ Client      │
│                 │           │                             │               │ Devices     │
│ - External SSD  │           │ ┌─────────────────────────┐ │               │ - Laptop    │
│ - NFS Export    │           │ │ MergerFS Unified View   │ │               │ - Phones    │
└─────────────────┘           │ │ /srv/storage            │ │               │ - TVs       │
                              │ │                         │ │               └─────────────┘
                              │ │ ┌─────────┐ ┌─────────┐ │ │
                              │ │ │ Local   │ │ Remote  │ │ │
                              │ │ │ LVM     │ │ Pi NFS  │ │ │
                              │ │ │ Storage │ │ Mount   │ │ │
                              │ │ └─────────┘ └─────────┘ │ │
                              │ └─────────────────────────┘ │
                              │                             │
                              │ ┌─────────────────────────┐ │
                              │ │ BorgBackup              │ │
                              │ │ to Backblaze B2         │ │
                              │ └─────────────────────────┘ │
                              └─────────────────────────────┘
```

## Implementation Plan

### Phase 1: User and Group Setup
- [ ] Create identical users and groups on all nodes (N100, Pi)
- [ ] Verify UID/GID consistency across all systems
- [ ] Document user assignments for future reference
- [ ] Test user authentication and group membership

### Phase 2: Raspberry Pi Setup
- [ ] Install and configure NFS server on Raspberry Pi
- [ ] Create environment-specific directories (prod/preprod)
- [ ] Set filesystem permissions using environment UIDs/GIDs
- [ ] Export Pi storage via NFS (no user squashing)
- [ ] Test NFS connectivity from N100

### Phase 3: N100 Local Storage (LVM)
- [ ] Install LVM tools on N100
- [ ] Create physical volumes from local drives
- [ ] Create volume group combining local drives
- [ ] Create logical volume using all available space
- [ ] Format logical volume with ext4 filesystem
- [ ] Mount LVM logical volume
- [ ] Set environment-specific permissions on local storage

### Phase 4: Network Storage Integration
- [ ] Install NFS client tools on N100
- [ ] Mount Pi NFS export on N100
- [ ] Verify remote storage accessibility and permissions
- [ ] Configure persistent mounting in /etc/fstab

### Phase 5: Unified Storage (MergerFS)
- [ ] Install MergerFS on N100
- [ ] Create MergerFS union combining local LVM and remote NFS
- [ ] Configure MergerFS policies for file placement
- [ ] Set up persistent MergerFS mounting
- [ ] Test unified storage functionality and environment isolation

### Phase 6: Network Export
- [ ] Install and configure NFS server on N100
- [ ] Export unified storage via NFS
- [ ] Install and configure Samba for SMB/CIFS support
- [ ] Test network access from client devices
- [ ] Configure firewall rules as needed

### Phase 7: Backup Integration
- [ ] Install BorgBackup on N100
- [ ] Configure Borg repository on Backblaze B2
- [ ] Set up automated backup schedules
- [ ] Test backup and restore procedures
- [ ] Document backup retention policies

## Storage Hierarchy

```
/srv/storage/                  # Unified storage view (MergerFS)
├── prod/                      # Production environment (UID 5001:5001)
│   └── data/
├── preprod/                   # Preprod environment (UID 6001:6001)
│   └── data/
├── /mnt/local/               # Local N100 storage (LVM)
│   └── /dev/storage_vg/storage_lv # LVM logical volume
│       ├── /dev/sda          # Physical drive 1
│       └── /dev/sdb          # Physical drive 2
└── /mnt/pi-remote/           # Pi storage (NFS mount)
    ├── prod/                 # Pi production storage
    └── preprod/              # Pi preprod storage
```

## Fault Tolerance Benefits

### MergerFS Advantages
- **Partial availability**: Local storage remains accessible if Pi goes offline
- **Operational flexibility**: Can modify/reboot Pi without affecting N100 storage
- **Graceful degradation**: System continues operating with reduced capacity
- **Independent troubleshooting**: Can access underlying storage directly

### Failure Scenarios Handled
- Pi hardware failure or maintenance
- Network connectivity issues between N100 and Pi
- Pi storage corruption or filesystem issues
- Individual drive failures within LVM volume group

## Configuration Files

### Key Locations
- `/etc/fstab` - Persistent mount configuration
- `/etc/exports` - NFS export configuration (both Pi and N100)
- `/etc/samba/smb.conf` - SMB/CIFS configuration
- Borg configuration files and scripts

## Performance Considerations

### Network Requirements
- Gigabit Ethernet recommended
- Stable network connection between N100 and Pi
- Consider dedicated network segment for storage traffic

### Storage Policies
- MergerFS can be configured for different file placement strategies
- Default: Most free space (mfs) policy
- Alternative: First found (ff) for sequential filling

## Maintenance Tasks

### Regular Operations
- Monitor storage usage across all devices
- Verify backup integrity and test restore procedures
- Check NFS connectivity and mount status
- Monitor LVM volume group health

### Expansion Procedures
- Adding new drives to N100 LVM volume group
- Adding additional Pi devices to MergerFS union
- Scaling backup storage and retention

## User and Group Management

### UID/GID Strategy
- **Production environment**: 5000-5999 UID range
- **Preprod environment**: 6000-6999 UID range
- **Base service UIDs**:
  ```bash
  PROD_UID=5001      # Production services
  PROD_GID=5001      # Production group
  PREPROD_UID=6001   # Preprod services  
  PREPROD_GID=6001   # Preprod group
  ```

### Multi-Node User Consistency
- **Identical users required** on all nodes (N100-A, N100-B, Pi)
- **Consistent UID/GID mapping** across entire cluster
- **No NFS user squashing** to maintain permission enforcement

### User Creation Commands
```bash
# On ALL nodes - create identical users
sudo groupadd -g 5001 prod
sudo groupadd -g 6001 preprod
sudo useradd -u 5001 -g 5001 prod-user
sudo useradd -u 6001 -g 6001 preprod-user
```

### NFS Export Configuration
```bash
# Pi /etc/exports - no user squashing for true segregation
/mnt/pi-storage/prod 192.168.1.0/24(rw,sync,no_root_squash)
/mnt/pi-storage/preprod 192.168.1.0/24(rw,sync,no_root_squash)
```

### Docker Container User Mapping
```yaml
services:
  service-prod:
    user: "5001:5001"  # Production UID:GID
    volumes:
      - /srv/storage/prod:/data:ro
      
  service-preprod:
    user: "6001:6001"  # Preprod UID:GID  
    volumes:
      - /srv/storage/preprod:/data:ro
```

## Security Considerations

### Environment Segregation
- **Filesystem-level isolation**: Unix permissions enforce environment boundaries
- **Network-level isolation**: iptables rules prevent cross-environment communication
- **Container-level isolation**: Different UIDs prevent accidental cross-access
- **NFS permission enforcement**: Server validates client UID against file ownership

### Network Security
- NFS access controls via IP restrictions
- SMB user authentication and access controls
- Firewall configuration for required ports
- Consider VPN access for remote connectivity

### Data Protection
- Regular backup verification
- Encryption for backup data in transit and at rest
- Access logging and monitoring

## Troubleshooting

### Common Issues
- NFS mount failures: Check network connectivity and export configuration
- LVM issues: Verify physical volume status and volume group integrity
- MergerFS problems: Check underlying mount points and policies
- Performance issues: Monitor network utilization and disk I/O

### Recovery Procedures
- Pi offline recovery: Continue with local storage only
- N100 failure: Access Pi storage directly via network
- Individual drive failure: LVM volume group management
- Complete system recovery: Restore from Borg backup

## Future Enhancements

### Potential Improvements
- Additional Pi devices for expanded storage
- Load balancing across multiple storage nodes
- Advanced MergerFS policies for content type optimization
- Monitoring and alerting system integration
- Automated storage tiering based on usage patterns

---

*This document serves as the blueprint for implementing a robust, fault-tolerant media server storage architecture suitable for home use with room for future expansion and experimentation.*