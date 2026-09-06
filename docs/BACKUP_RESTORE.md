# Backup and Restore Documentation

## Backup Strategy Overview

The server uses a multi-layered backup approach:
1. **Application-level backups**: Built-in backup systems for each service
2. **Configuration backups**: Service configuration files
3. **Script backups**: Automation scripts and configurations
4. **Manual backups**: Critical data that requires manual backup

## What to Backup

### Critical Backups (Required)
- `~/config/` - All service configurations
- `~/.env` - Environment variables (Immich)
- `~/scripts/` - Automation scripts
- `~/.mam_script/` - MAM script data and cookies
- Docker Compose file: `~/docker-compose.yml`

### Application-Level Backups
- **Sonarr**: Built-in backup system (keeps last 2)
- **Radarr**: Built-in backup system (keeps last 2)
- **Prowlarr**: Built-in backup system (keeps last 2)
- **Immich**: Database and photo storage
- **Plex**: Metadata and preferences

### Optional Backups
- **Media Files**: Can be re-downloaded but large
- **Cache Files**: Can be regenerated
- **Log Files**: Can be regenerated

## Backup Locations

### Local Backup Strategy
```bash
# Create backup directory
mkdir -p ~/backups

# Backup configurations
tar -czf ~/backups/config_$(date +%Y%m%d).tar.gz ~/config/

# Backup scripts
tar -czf ~/backups/scripts_$(date +%Y%m%d).tar.gz ~/scripts/

# Backup MAM data
tar -czf ~/backups/mam_$(date +%Y%m%d).tar.gz ~/.mam_script/

# Backup environment files
cp ~/.env ~/backups/env_$(date +%Y%m%d).backup
cp ~/docker-compose.yml ~/backups/docker-compose_$(date +%Y%m%d).backup
```

### Off-site Backup Strategy
Consider cloud backup for critical configurations:
- **Configuration files**: Small, critical, easy to backup
- **Scripts**: Essential for automation
- **MAM data**: Contains authentication information

## Application-Specific Backups

### Sonarr
**Location**: `~/config/sonarr/Backups/scheduled/`  
**Retention**: Last 2 backups  
**Manual Backup**: Access Sonarr web UI → System → Backups

### Radarr
**Location**: `~/config/radarr/Backups/scheduled/`  
**Retention**: Last 2 backups  
**Manual Backup**: Access Radarr web UI → System → Backups

### Prowlarr
**Location**: `~/config/prowlarr/Backups/scheduled/`  
**Retention**: Last 2 backups  
**Manual Backup**: Access Prowlarr web UI → System → Backups

### Immich
**Components**:
- **Database**: `/jez-cache/immich/postgres/`
- **Photos**: `/mnt/storage/jez-photos/`
- **ML Cache**: `/jez-cache/immich/model-cache/`

**Backup Method**:
```bash
# Backup Immich database
docker exec immich_postgres pg_dump -U postgres immich > ~/backups/immich_db_$(date +%Y%m%d).sql

# Backup photos (consider size)
rsync -av /mnt/storage/jez-photos/ ~/backups/photos_$(date +%Y%m%d)/
```

### Plex
**Components**:
- **Preferences**: `~/config/plex/Library/Application Support/Plex Media Server/Preferences.xml`
- **Metadata**: `~/config/plex/Library/Application Support/Plex Media Server/Metadata/`
- **Database**: `~/config/plex/Library/Application Support/Plex Media Server/Plug-in Support/Databases/`

**Backup Method**:
```bash
# Backup Plex configuration
tar -czf ~/backups/plex_config_$(date +%Y%m%d).tar.gz ~/config/plex/
```

## Automated Backup Script

### Create Backup Script
```bash
#!/bin/bash
# ~/scripts/backup.sh

BACKUP_DIR="$HOME/backups"
DATE=$(date +%Y%m%d)
RETENTION_DAYS=30

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup configurations
echo "Backing up configurations..."
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" ~/config/

# Backup scripts
echo "Backing up scripts..."
tar -czf "$BACKUP_DIR/scripts_$DATE.tar.gz" ~/scripts/

# Backup MAM data
echo "Backing up MAM data..."
tar -czf "$BACKUP_DIR/mam_$DATE.tar.gz" ~/.mam_script/

# Backup environment files
echo "Backing up environment files..."
cp ~/.env "$BACKUP_DIR/env_$DATE.backup"
cp ~/docker-compose.yml "$BACKUP_DIR/docker-compose_$DATE.backup"

# Immich database backup
echo "Backing up Immich database..."
docker exec immich_postgres pg_dump -U postgres immich > "$BACKUP_DIR/immich_db_$DATE.sql"

# Clean old backups
echo "Cleaning old backups..."
find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $DATE"
```

### Schedule Automated Backups
```bash
# Add to crontab
0 2 * * * /home/tm/scripts/backup.sh
```

## Restore Procedures

### Configuration Restore
```bash
# Stop services
cd ~ && docker-compose stop

# Restore configurations
tar -xzf ~/backups/config_YYYYMMDD.tar.gz -C ~/

# Restore scripts
tar -xzf ~/backups/scripts_YYYYMMDD.tar.gz -C ~/

# Restore MAM data
tar -xzf ~/backups/mam_YYYYMMDD.tar.gz -C ~/

# Restore environment files
cp ~/backups/env_YYYYMMDD.backup ~/.env
cp ~/backups/docker-compose_YYYYMMDD.backup ~/docker-compose.yml

# Restart services
docker-compose start
```

### Application-Level Restore

#### Sonarr/Radarr/Prowlarr
1. Access web UI
2. Navigate to System → Backups
3. Select backup to restore
4. Click restore
5. Wait for restoration and restart

#### Immich
```bash
# Stop Immich services
docker-compose stop immich_server immich_machine_learning

# Restore database
cat ~/backups/immich_db_YYYYMMDD.sql | docker exec -i immich_postgres psql -U postgres immich

# Restart services
docker-compose start immich_server immich_machine_learning
```

#### Plex
```bash
# Stop Plex
docker-compose stop plex2

# Restore configuration
tar -xzf ~/backups/plex_config_YYYYMMDD.tar.gz -C ~/

# Restart Plex
docker-compose start plex2
```

## Disaster Recovery

### Complete System Failure
1. **Hardware Replacement**: Replace failed hardware
2. **OS Reinstallation**: Reinstall operating system
3. **Docker Installation**: Install Docker and Docker Compose
4. **Configuration Restore**: Restore configurations from backup
5. **Service Restart**: Start all services
6. **Data Verification**: Verify all data is intact

### Storage Failure
1. **Identify Failed Disk**: Determine which disk failed
2. **Replace Hardware**: Replace failed disk
3. **Restore Data**: Restore from backup or MergerFS redundancy
4. **Rebuild Pool**: Rebuild MergerFS pool
5. **Verify Services**: Verify all services function correctly

### Corruption Recovery
1. **Stop Services**: Stop all affected services
2. **Assess Damage**: Determine extent of corruption
3. **Restore from Backup**: Restore from most recent good backup
4. **Verify Data**: Verify data integrity
5. **Restart Services**: Restart all services

## Backup Testing

### Regular Testing
- **Monthly**: Test configuration restore
- **Quarterly**: Test complete disaster recovery
- **Annually**: Full system recovery test

### Testing Procedure
1. **Create Test Environment**: Use separate system or test directory
2. **Restore Backup**: Restore backup to test environment
3. **Verify Functionality**: Test all services and configurations
4. **Document Results**: Document test results and any issues
5. **Update Procedures**: Update backup/restore procedures based on test results

## Monitoring and Maintenance

### Backup Monitoring
```bash
# Check backup directory
ls -lh ~/backups/

# Check backup sizes
du -sh ~/backups/*

# Verify backup integrity
tar -tzf ~/backups/config_YYYYMMDD.tar.gz | head -20
```

### Backup Maintenance
- **Weekly**: Verify backups are created successfully
- **Monthly**: Test backup restoration
- **Quarterly**: Review backup strategy and retention policy
- **Annually**: Full backup system review

## Best Practices

### Backup Strategy
1. **3-2-1 Rule**: 3 copies, 2 different media, 1 off-site
2. **Regular Schedule**: Daily automated backups
3. **Testing**: Regular testing of backup restoration
4. **Documentation**: Document all backup/restore procedures

### Backup Security
1. **Encryption**: Encrypt sensitive backups
2. **Access Control**: Restrict backup access
3. **Off-site Storage**: Store critical backups off-site
4. **Version Control**: Keep multiple backup versions

### Backup Retention
- **Daily**: Keep last 7 days
- **Weekly**: Keep last 4 weeks
- **Monthly**: Keep last 12 months
- **Yearly**: Keep annual backups

## Emergency Contact

### Critical Failure
1. **Stop Services**: Immediately stop all services
2. **Assess Situation**: Determine extent of failure
3. **Document**: Document all actions taken
4. **Restore**: Begin restoration from backup
5. **Verify**: Verify all systems are functional

### Data Loss
1. **Stop Writes**: Immediately stop all write operations
2. **Assess Loss**: Determine extent of data loss
3. **Restore**: Restore from most recent good backup
4. **Investigate**: Investigate cause of data loss
5. **Prevent**: Implement measures to prevent recurrence

## Related Documentation
- [STORAGE.md](STORAGE.md) - Storage configuration
- [DOCKER_COMPOSE.md](DOCKER_COMPOSE.md) - Service configurations
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions