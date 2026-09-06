# Maintenance Procedures Documentation

## Overview

This document outlines regular maintenance procedures for the TerraMaster server to ensure optimal performance, reliability, and security.

## Daily Maintenance

### System Health Check
```bash
# Check system load
uptime

# Check disk usage
df -h

# Check memory usage
free -h

# Check running containers
docker ps
```

### Service Health Check
```bash
# Check all Docker containers are running
docker ps

# Check for unhealthy containers
docker ps --filter "status=unhealthy"

# Check container resource usage
docker stats --no-stream
```

### Log Check
```bash
# Check for system errors
sudo journalctl -p err -n 50 --no-pager

# Check Docker logs for errors
docker logs $(docker ps -q --filter "status=exited") --tail 50

# Check MAM automation script
tail ~/scripts/activity.log
```

## Weekly Maintenance

### Backup Verification
```bash
# Check backup directory exists
ls -la ~/backups/

# Verify recent backups exist
ls -lt ~/backups/ | head -10

# Check backup sizes
du -sh ~/backups/*
```

### Storage Cleanup
```bash
# Clean up temporary files
find /mnt/temp -type f -mtime +7 -delete

# Clean up old log files
find ~/config/*/logs -name "*.log.bak*" -mtime +30 -delete

# Check for large files
find /mnt/storage -type f -size +10G -ls
```

### Service Updates Check
```bash
# Check for Docker image updates
cd ~ && docker-compose pull

# Review available updates
docker images | grep "<none>"
```

### Security Check
```bash
# Check for failed login attempts
sudo lastb | head -20

# Check active SSH connections
who

# Review system updates
sudo apt list --upgradable
```

## Monthly Maintenance

### Full System Update
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Clean up unnecessary packages
sudo apt autoremove -y

# Update Docker images
cd ~ && docker-compose pull

# Restart services with new images
docker-compose up -d
```

### Storage Analysis
```bash
# Analyze storage usage by directory
du -sh /mnt/storage/* | sort -hr

# Check disk health
sudo smartctl -a /dev/sdX

# Rebalance MergerFS pool
~/mergerfs.balance
```

### Backup Maintenance
```bash
# Clean old backups (keep last 30 days)
find ~/backups/ -type f -mtime +30 -delete

# Test backup restoration
tar -tzf ~/backups/config_$(date +%Y%m%d).tar.gz | head -20

# Verify backup integrity
```

### Service Configuration Review
```bash
# Review Sonarr configuration
# Access web UI → System → Status

# Review Radarr configuration
# Access web UI → System → Status

# Review Prowlarr indexers
# Access web UI → Indexers

# Check for failed downloads in qBittorrent
# Access web UI → Transfers
```

## Quarterly Maintenance

### Performance Review
```bash
# Check system performance
sudo iostat -x 1 5

# Check network performance
iftop

# Review container resource usage
docker stats --no-stream
```

### Security Audit
```bash
# Review user accounts
sudo lastlog

# Review SSH configuration
sudo cat /etc/ssh/sshd_config

# Review firewall rules
sudo ufw status

# Check for open ports
sudo netstat -tlnp
```

### Documentation Update
```bash
# Review and update documentation
cd ~/docs/
# Update configuration changes
# Document any issues encountered
# Update contact information
```

### Disaster Recovery Test
```bash
# Test configuration backup restore
# Test service recovery procedures
# Verify cross-server connectivity
# Test NFS mount functionality
```

## Annual Maintenance

### Hardware Review
```bash
# Check all disk health
for disk in /dev/sd*; do sudo smartctl -a $disk; done

# Check temperature sensors
sudo sensors

# Review hardware capacity planning
# Plan for storage expansion
# Plan for hardware upgrades
```

### Full System Audit
```bash
# Review all services running
docker ps -a

# Review all storage mounts
mount

# Review network configuration
ip addr show

# Review system logs
sudo journalctl --since "1 year ago" | grep -i error
```

### Backup Strategy Review
```bash
# Review backup retention policy
# Evaluate backup storage needs
# Test full disaster recovery
# Update backup procedures
```

## Service-Specific Maintenance

### qBittorrent
```bash
# Check download queue
# Access web UI → Transfers

# Clean up completed torrents
# Remove completed torrents older than 30 days

# Check tracker status
# Access web UI → Trackers

# Verify download speeds
# Monitor during peak usage
```

### Sonarr/Radarr
```bash
# Check for import failures
# Access web UI → Activity → Queue

# Review quality profiles
# Access web UI → Settings → Profiles

# Check disk space for upcoming downloads
# Access web UI → System → Status

# Update series/movie metadata
# Access web UI → Series/Movies → Refresh
```

### Prowlarr
```bash
# Check indexer status
# Access web UI → Indexers

# Test indexer connections
# Access web UI → Indexers → Test

# Review sync status
# Access web UI → Apps

# Update indexer definitions
# Access web UI → Settings → Indexers
```

### Plex
```bash
# Check library updates
# Access web UI → Libraries → Update

# Review server resources
# Access web UI → Settings → Server

# Check for media analysis issues
# Access web UI → Settings → Library

# Update Plex Media Server
# Access web UI → Settings → Server → Check for Updates
```

### Immich
```bash
# Check photo processing status
# Access web UI → Administration → Jobs

# Review storage usage
# Access web UI → Administration → Storage

# Check ML processing queue
# Access web UI → Administration → Machine Learning

# Update Immich
# Follow official update procedures
```

### MAM Automation
```bash
# Check script execution logs
tail ~/scripts/activity.log

# Verify MAM account status
# Check MAM website directly

# Review bonus point spending
# Analyze activity.log for spending patterns

# Test script functionality
./scripts/mam-check.sh
```

## Automation Scripts

### Backup Script
Create `~/scripts/maintenance.sh`:
```bash
#!/bin/bash
# Daily maintenance script

echo "Starting daily maintenance: $(date)"

# System health check
echo "Checking system health..."
uptime
df -h
docker ps

# Clean temporary files
echo "Cleaning temporary files..."
find /mnt/temp -type f -mtime +7 -delete

# Rotate logs
echo "Rotating logs..."
find ~/config/*/logs -name "*.log.bak*" -mtime +30 -delete

# Check MAM automation
echo "Checking MAM automation..."
tail -5 ~/scripts/activity.log

echo "Daily maintenance completed: $(date)"
```

### Weekly Maintenance Script
Create `~/scripts/weekly_maintenance.sh`:
```bash
#!/bin/bash
# Weekly maintenance script

echo "Starting weekly maintenance: $(date)"

# Check backups
echo "Checking backups..."
ls -lh ~/backups/ | tail -5

# Storage analysis
echo "Analyzing storage..."
du -sh /mnt/storage/* | sort -hr | head -10

# Check for large files
echo "Checking for large files..."
find /mnt/storage -type f -size +10G -ls

# Security check
echo "Security check..."
sudo lastb | head -5

echo "Weekly maintenance completed: $(date)"
```

## Scheduling

### Cron Jobs
```bash
# Daily maintenance at 2 AM
0 2 * * * /home/tm/scripts/maintenance.sh >> ~/scripts/maintenance.log 2>&1

# Weekly maintenance on Sunday at 3 AM
0 3 * * 0 /home/tm/scripts/weekly_maintenance.sh >> ~/scripts/weekly_maintenance.log 2>&1

# MAM automation every 6 hours
0 */6 * * * /home/tm/scripts/mam-check.sh
```

## Monitoring and Alerts

### System Monitoring
Consider implementing monitoring for:
- Disk space usage (>80% alert)
- Memory usage (>90% alert)
- Container failures
- High system load
- Network connectivity issues

### Log Monitoring
```bash
# Monitor system logs
sudo journalctl -f

# Monitor Docker logs
docker logs -f $(docker ps -q)

# Monitor application logs
tail -f ~/scripts/activity.log
```

## Emergency Procedures

### System Overload
1. **Identify Cause**: Check system load and processes
2. **Stop Non-Essential Services**: Temporarily stop non-critical containers
3. **Clear Space**: Clean up temporary files and old logs
4. **Restart Services**: Restart affected services
5. **Monitor**: Monitor system recovery

### Storage Emergency
1. **Assess Situation**: Determine which storage is affected
2. **Stop Writes**: Stop all write operations to affected storage
3. **Free Space**: Clean up unnecessary files
4. **Expand Storage**: Add storage if needed
5. **Monitor**: Monitor storage recovery

### Service Failure
1. **Identify Service**: Determine which service failed
2. **Check Logs**: Review service logs for errors
3. **Restart Service**: Attempt to restart the service
4. **Restore Backup**: If restart fails, restore from backup
5. **Monitor**: Monitor service recovery

## Maintenance Log

Keep a maintenance log to track all maintenance activities:
```bash
# Create maintenance log
echo "Maintenance Log" > ~/docs/maintenance_log.txt
echo "=================" >> ~/docs/maintenance_log.txt

# Log maintenance activities
echo "$(date): Daily maintenance completed" >> ~/docs/maintenance_log.txt
echo "$(date): Weekly storage analysis completed" >> ~/docs/maintenance_log.txt
```

## Best Practices

### Proactive Maintenance
1. **Regular Schedule**: Stick to maintenance schedule
2. **Documentation**: Document all maintenance activities
3. **Testing**: Test procedures before implementation
4. **Backup**: Always backup before making changes

### Safety Procedures
1. **Backup First**: Always backup before maintenance
2. **Test Changes**: Test changes in non-production first
3. **Rollback Plan**: Have rollback plan ready
4. **Monitor**: Monitor systems after changes

### Continuous Improvement
1. **Review Procedures**: Regularly review and update procedures
2. **Learn from Issues**: Document and learn from issues
3. **Update Documentation**: Keep documentation current
4. **Share Knowledge**: Share maintenance knowledge

## Related Documentation
- [README.md](README.md) - Overall server documentation
- [BACKUP_RESTORE.md](BACKUP_RESTORE.md) - Backup procedures
- [STORAGE.md](STORAGE.md) - Storage management
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues