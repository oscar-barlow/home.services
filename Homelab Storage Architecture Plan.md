# Media Server Storage Architecture Plan

## Overview

This document outlines the architecture for a unified media server storage system using an N100 machine as the primary server with a Raspberry Pi providing additional network storage. The solution provides a single filesystem interface across all network devices while maintaining fault tolerance and operational flexibility.

## Architecture Components

### Core Concepts (4 Key Technologies)

1. **Mount** - Network filesystem mounting via NFS
2. **pvcreate** - LVM physical volume creation for local and remote storage
3. **vgcreate** - LVM volume group creation to combine all storage
4. **lvcreate** - LVM logical volume creation for unified storage

## System Architecture

```
┌─────────────────┐    NFS    ┌─────────────────────────────┐    NFS/SMB    ┌─────────────┐
│ Raspberry Pi    │◄─────────►│ N100 Media Server           │◄─────────────►│ Client      │
│                 │           │                             │               │ Devices     │
│ - External SSD  │           │ ┌─────────────────────────┐ │               │ - Laptop    │
│ - Limited NFS   │           │ │ LVM Logical Volume      │ │               │ - Phones    │
│   Export        │           │ │ /srv/media              │ │               │ - TVs       │
└─────────────────┘           │ │                         │ │               └─────────────┘
                              │ │ ┌─────────┐ ┌─────────┐ │ │
                              │ │ │ Local   │ │ Pi NFS  │ │ │
                              │ │ │ Storage │ │ Mount   │ │ │
                              │ │ │ (PVs)   │ │ (PV)    │ │ │
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
- [ ] Export Pi storage via NFS to N100 only (/32 subnet)
- [ ] Test NFS connectivity from N100

### Phase 3: N100 Local Storage (LVM)
- [ ] Install LVM tools on N100
- [ ] Create physical volumes from local drives
- [ ] Mount Pi NFS export on N100
- [ ] Create LVM backing file on Pi NFS mount
- [ ] Add Pi backing file as LVM physical volume
- [ ] Create volume group combining local drives and Pi storage
- [ ] Create logical volume using all available space
- [ ] Format logical volume with ext4 filesystem
- [ ] Mount LVM logical volume
- [ ] Create environment-specific directory structure (prod/preprod)
- [ ] Set environment-specific permissions on unified storage

### Phase 4: Network Export
- [ ] Install and configure NFS server on N100
- [ ] Export unified LVM storage via NFS
- [ ] Install and configure Samba for SMB/CIFS support
- [ ] Test network access from client devices
- [ ] Configure firewall rules as needed

### Phase 5: Backup Integration
- [ ] Install BorgBackup on N100
- [ ] Configure Borg repository on Backblaze B2
- [ ] Set up automated backup schedules
- [ ] Test backup and restore procedures
- [ ] Document backup retention policies

## Storage Hierarchy

```
/srv/media/                    # Unified LVM storage (exported via NFS)
├── prod/                      # Production environment (UID 5001:5001)
│   ├── movies/
│   ├── tv/
│   └── music/
└── preprod/                   # Preprod environment (UID 6001:6001)
    ├── movies/
    ├── tv/
    └── music/

# LVM Physical Volumes:
├── /dev/sda                   # N100 local drive 1
├── /dev/sdb                   # N100 local drive 2
└── /mnt/pi-remote/lvm-backing-file.img  # Pi storage as LVM PV
    └── mounted from: pi-ip:/mnt/pi-storage (NFS)
```

## Fault Tolerance Benefits

### Simplified Architecture Advantages
- **Clean single filesystem**: LVM creates one true filesystem across all storage
- **Straightforward troubleshooting**: No union filesystem complexity
- **Clear data path**: NFS → LVM → NFS export chain
- **Future migration ready**: Easy path to distributed storage (Ceph/GlusterFS)

### Acknowledged Limitations (2-Node Setup)
- **Pi failure**: Complete media library unavailable
- **N100 failure**: Complete media library unavailable  
- **Network issues**: Complete media library unavailable
- **Mitigation**: Robust backup strategy with BorgBackup to Backblaze B2

### Future Scalability
- **3+ nodes**: Migrate to GlusterFS dispersed volumes for fault tolerance
- **Erasure coding**: Achieve fault tolerance without full replication overhead
- **Storage efficiency**: Improve from 0% (current) to 67%+ (6+ nodes with erasure coding)

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
- **Production environment**: UID/GID 5001 (`prod-user`/`prod` group)
- **Preprod environment**: UID/GID 6001 (`preprod-user`/`preprod` group)

### Multi-Node User Consistency
- **Identical users required** on all nodes (N100, Pi)
- **Consistent UID/GID mapping** across entire cluster
- **No NFS user squashing** to maintain permission enforcement

### User Creation Commands
```bash
# On ALL nodes - create identical users
sudo groupadd -g 5001 prod
sudo groupadd -g 6001 preprod
sudo useradd -u 5001 -g 5001 -m -s /bin/bash prod-user
sudo useradd -u 6001 -g 6001 -m -s /bin/bash preprod-user
```

### NFS Export Configuration
```bash
# Pi /etc/exports - restricted to N100 only
/mnt/pi-storage <N100-IP>/32(rw,sync,no_root_squash)

# N100 /etc/exports - available to entire network
/srv/media 192.168.1.0/24(rw,sync,no_root_squash)
```

### Docker Container User Mapping
```yaml
services:
  service-prod:
    user: "5001:5001"  # Production UID:GID
    volumes:
      - /srv/media/prod:/media:ro
      
  service-preprod:
    user: "6001:6001"  # Preprod UID:GID  
    volumes:
      - /srv/media/preprod:/media:ro
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