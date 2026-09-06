# Storage Configuration Documentation

This document details the storage configuration and management on the TerraMaster server.

## Storage Overview

### Hardware Configuration
- **Individual Disks**: 5 disks (disk1-disk5)
- **NVMe Cache**: 1 NVMe drive
- **Filesystem**: ext4 for individual disks, xfs for NVMe
- **Pooling**: MergerFS for unified storage pool

### Mount Points

#### Individual Disks
```
/dev/sda1 → /mnt/disk1  (ext4)
/dev/sdb   → /mnt/disk2  (ext4)
/dev/sdc   → /mnt/disk3  (ext4)
/dev/sdd1  → /mnt/disk4  (ext4)
/dev/sde1  → /mnt/disk5  (ext4)
/dev/nvme0n1p1 → /mnt/NVMe2 (xfs)
```

#### MergerFS Pool
```
mergerfsPool → /mnt/storage (fuse.mergerfs)
```

## MergerFS Configuration

### Pool Composition
The `/mnt/storage` pool is created from the individual disks using MergerFS:
- **Source disks**: /mnt/disk1, /mnt/disk2, /mnt/disk3, /mnt/disk4, /mnt/disk5
- **Pool mount point**: /mnt/storage
- **Policy**: Default MergerFS policy (typically msplfs or similar)

### MergerFS Benefits
- **Unified namespace**: Single mount point for all disks
- **Redundancy**: Protection against single disk failure
- **Flexibility**: Easy addition/removal of disks
- **Performance**: Parallel access to multiple disks

## Directory Structure

### Main Storage Pool (/mnt/storage)
```
/mnt/storage/
├── data/                    # General data and downloads
├── plex-movies/             # Movie library
├── plex-tv/                 # TV show library
├── plex-mobile/             # Mobile media
├── sports/                  # Sports content
│   ├── F1/                  # Formula 1 content
│   ├── AFL/                 # AFL content
│   └── EPL/                 # English Premier League content
├── jez-photos/              # Photo storage for Immich
├── torrents/                # Torrent downloads
└── .DS_Store                # macOS metadata (can be ignored)
```

### NVMe Cache (/mnt/NVMe2)
- **Purpose**: High-speed cache for frequently accessed data
- **Filesystem**: xfs (optimized for NVMe)
- **Usage**: Currently used for Immich ML cache

### Immich Cache Directory (/jez-cache)
```
/jez-cache/immich/
├── model-cache/             # Machine learning model cache
└── postgres/                # Immich database
```

## Storage Usage by Service

### Media Storage
- **Plex Movies**: `/mnt/storage/plex-movies/`
- **Plex TV**: `/mnt/storage/plex-tv/`
- **Plex Mobile**: `/mnt/storage/plex-mobile/`
- **Sports**: `/mnt/storage/sports/`

### Download Storage
- **qBittorrent Downloads**: `/mnt/storage/data/`
- **Temporary Files**: `/mnt/temp/`

### Photo Storage
- **Immich Photos**: `/mnt/storage/jez-photos/`
- **Immich ML Cache**: `/jez-cache/immich/model-cache/`
- **Immich Database**: `/jez-cache/immich/postgres/`

## Storage Management

### Check Disk Usage
```bash
# Overall disk usage
df -h

# Individual disk usage
df -h /mnt/disk*

# Storage pool usage
df -h /mnt/storage

# Directory sizes
du -sh /mnt/storage/*
```

### MergerFS Management
```bash
# Check MergerFS status
mount | grep mergerfs

# View MergerFS configuration
cat /etc/fstab | grep mergerfs

# Balance storage pool
~/mergerfs.balance
```

### Storage Pool Maintenance
```bash
# Check pool health
mergerfs -f /mnt/storage

# Rebalance data across disks
~/mergerfs.balance

# Check for disk errors
sudo smartctl -a /dev/sdX
```

## Storage Performance

### Disk Layout
- **Read Performance**: Parallel reads from multiple disks
- **Write Performance**: Distributed writes across disks
- **Cache Performance**: NVMe cache for frequently accessed data

### Performance Optimization
- **NVMe Cache**: Used for Immich ML models (faster photo processing)
- **MergerFS Policy**: Optimized for media workloads
- **Hardware Acceleration**: Intel QuickSync for transcoding (not storage, but related)

## Storage Monitoring

### Regular Checks
```bash
# Daily: Check available space
df -h /mnt/storage

# Weekly: Check disk health
sudo smartctl -a /dev/sdX

# Monthly: Check for errors
dmesg | grep -i error
```

### Alerting
Consider setting up alerts for:
- Disk space > 80% usage
- Disk errors in SMART logs
- MergerFS mount failures

## Storage Expansion

### Adding New Disks
1. **Physical Installation**: Add new disk to system
2. **Format**: Create filesystem (ext4)
3. **Mount**: Add to MergerFS pool
4. **Rebalance**: Run `~/mergerfs.balance`

### Replacing Failed Disks
1. **Identify Failed Disk**: Check SMART logs and system logs
2. **Replace Disk**: Physical replacement
3. **Restore Data**: From backup or MergerFS redundancy
4. **Rebuild Pool**: Update MergerFS configuration

## Backup Strategy

### What to Backup
- **Configuration Files**: `~/config/`
- **Scripts**: `~/scripts/`
- **Environment Variables**: `~/.env`
- **MAM Data**: `~/.mam_script/`

### What Doesn't Need Backup
- **Media Files**: Can be re-downloaded
- **Application Data**: Most services rebuild their databases
- **Cache Files**: Can be regenerated

### Backup Locations
- **Local**: Backup to separate disk or external drive
- **Off-site**: Consider cloud backup for critical configurations
- **Application-level**: Use built-in backup features (Sonarr, Radarr, etc.)

## Storage Troubleshooting

### MergerFS Issues
```bash
# Check if pool is mounted
mount | grep mergerfs

# Remount pool
sudo mount -a

# Check MergerFS logs
dmesg | grep mergerfs
```

### Disk Issues
```bash
# Check disk health
sudo smartctl -a /dev/sdX

# Check for filesystem errors
sudo fsck /dev/sdX

# Check disk performance
sudo hdparm -tT /dev/sdX
```

### Space Issues
```bash
# Find large files
find /mnt/storage -type f -size +10G -ls

# Find large directories
du -sh /mnt/storage/* | sort -hr

# Clean up temporary files
find /mnt/temp -type f -mtime +7 -delete
```

## NFS Export Configuration

### Export Details
- **Export Path**: `/mnt/storage`
- **Network**: 192.168.0.0/24
- **Access**: Read/write for QNAP server

### Client Mount (QNAP)
- **Mount Point**: `/mnt/storage`
- **Server**: 192.168.0.172:/mnt/storage
- **Options**: NFSv3, large transfer sizes

### NFS Management
```bash
# Check NFS exports
showmount -e

# Check NFS status
sudo systemctl status nfs-server

# Restart NFS
sudo systemctl restart nfs-server
```

## Storage Best Practices

### Regular Maintenance
- **Weekly**: Check disk usage and health
- **Monthly**: Rebalance MergerFS pool
- **Quarterly**: Review storage needs and plan expansion

### Data Organization
- **Consistent Structure**: Maintain the established directory structure
- **Naming Conventions**: Use clear, consistent naming
- **Regular Cleanup**: Remove temporary and old files

### Performance
- **Monitor**: Regular performance monitoring
- **Optimize**: Adjust MergerFS policies if needed
- **Cache**: Utilize NVMe cache for frequently accessed data

## Emergency Procedures

### Storage Pool Failure
1. **Assess**: Identify which component failed
2. **Recover**: Restore from backup if needed
3. **Rebuild**: Rebuild MergerFS pool
4. **Verify**: Test all services

### Disk Failure
1. **Identify**: Determine which disk failed
2. **Replace**: Physical replacement
3. **Restore**: Restore data from redundancy or backup
4. **Rebuild**: Rebuild storage pool

### Data Corruption
1. **Stop**: Stop all writes to affected storage
2. **Assess**: Determine extent of corruption
3. **Restore**: Restore from backup
4. **Verify**: Verify data integrity

## Storage Capacity Planning

### Current Usage Analysis
```bash
# Analyze current usage
du -sh /mnt/storage/* | sort -hr

# Project future needs
# Consider: new media acquisition, photo growth, system updates
```

### Expansion Planning
- **Monitor Trends**: Track storage growth over time
- **Plan Ahead**: Add storage before reaching capacity
- **Consider Redundancy**: Plan for backup and redundancy

## Related Documentation
- [DOCKER_COMPOSE.md](DOCKER_COMPOSE.md) - Service storage requirements
- [BACKUP_RESTORE.md](BACKUP_RESTORE.md) - Backup procedures
- [NETWORK.md](NETWORK.md) - NFS configuration