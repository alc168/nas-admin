# TerraMaster Server Documentation

**Server**: tm@192.168.0.172  
**Purpose**: Main media automation and storage server  
**OS**: Ubuntu/Linux  
**Last Updated**: July 2026

## Quick Overview

This server runs the complete media automation stack including:
- **Media Downloading**: qBittorrent (Torrent Leech)
- **Media Management**: Sonarr (TV), Radarr (Movies), Prowlarr (Indexers)
- **User Requests**: Seerr (Media request interface)
- **Media Serving**: Plex (with hardware transcoding)
- **Photo Management**: Immich (self-hosted photo gallery)
- **Automation**: Autobrr (advanced torrent filtering), Kometa (Plex metadata)
- **Network Monitoring**: Prometheus, Grafana, Node Exporter (7-day historical data)

## Directory Structure

```
~/
├── docker-compose.yml          # Main Docker Compose configuration
├── docker-compose-monitoring.yml # Network monitoring stack
├── .env                        # Immich environment variables
├── config/                     # Service configurations
│   ├── qbt-tl/                # qBittorrent (Torrent Leech) config
│   ├── sonarr/                # Sonarr (TV) config
│   ├── radarr/                # Radarr (Movies) config
│   ├── prowlarr/              # Prowlarr (Indexers) config
│   ├── autobrr/               # Autobrr config
│   ├── overseerr/             # Seerr config
│   ├── kometa/                # Kometa config
│   ├── plex/                  # Plex config
│   ├── prometheus/            # Prometheus monitoring config
│   └── grafana/               # Grafana dashboards config
├── scripts/                    # Automation scripts
│   ├── mam-check.sh           # MAM automation script
│   ├── plex_limit.sh          # Plex bandwidth limiting
│   └── plex_resume.sh         # Plex bandwidth resuming
├── data/                       # Monitoring data storage
│   ├── prometheus/            # Prometheus metrics data
│   └── elasticsearch/         # ELK stack data (optional)
├── .mam_script/               # MAM script data directory
└── docs/                      # This documentation directory
```

## Storage Configuration

### MergerFS Pool
- **Main Pool**: `/mnt/storage` (pooled from disk1-disk5)
- **Individual Disks**: `/mnt/disk1`, `/mnt/disk2`, `/mnt/disk3`, `/mnt/disk4`, `/mnt/disk5`
- **NVMe Cache**: `/mnt/NVMe2`

### Media Directories
- `/mnt/storage/data` - General data and downloads
- `/mnt/storage/plex-movies` - Movie library
- `/mnt/storage/plex-tv` - TV show library
- `/mnt/storage/plex-mobile` - Mobile media
- `/mnt/storage/sports` - Sports content (F1, AFL, EPL)
- `/mnt/storage/jez-photos` - Photo storage for Immich
- `/mnt/storage/torrents` - Torrent downloads

## Network Ports

| Service | Port | Purpose |
|---------|------|---------|
| qBittorrent (qbt-tl) | 8080 | Web UI |
| qBittorrent (qbt-tl) | 40012 | Torrent connections |
| Sonarr | 8989 | Web UI |
| Radarr | 7878 | Web UI |
| Prowlarr | 9696 | Web UI |
| Autobrr | 7474 | Web UI |
| Seerr | 5055 | Web UI |
| Plex | 32400 | Default (host networking) |
| Immich | 2283 | Web UI |
| Immich Power Tools | 8001 | Admin interface |
| Bitmappery | 5173 | Image editor |
| Grafana | 3001 | Network monitoring dashboards |
| Prometheus | 9090 | Metrics collection API |
| Node Exporter | 9100 | System metrics |

## Quick Start Commands

### Docker Management
```bash
# View running containers
docker ps

# View all containers (including stopped)
docker ps -a

# Restart all services
cd ~ && docker-compose restart

# Restart specific service
docker-compose restart sonarr

# View logs for a service
docker-compose logs -f sonarr
```

### Storage Management
```bash
# Check disk usage
df -h

# Check MergerFS pool status
mount | grep mergerfs

# Balance MergerFS pool
~/mergerfs.balance
```

### Backup Management
```bash
# List application backups
ls -la ~/config/*/Backups/scheduled/

# Manual backup (from within application UI)
# Access each service's web UI and use backup function
```

## Maintenance Tasks

### Daily
- Monitor Docker container health: `docker ps`
- Check available disk space: `df -h`
- Review MAM automation logs: `tail ~/scripts/activity.log`

### Weekly
- Review and clean up torrent downloads
- Check Plex for media processing issues
- Review Seerr request queue

### Monthly
- Review application backups (keep last 2)
- Check Immich storage usage
- Review and update indexers in Prowlarr
- Clean up old log files

## Important Files

### Configuration Files
- `~/docker-compose.yml` - Main Docker configuration
- `~/.env` - Immich environment variables
- `~/config/*/config.xml` - Individual service configs

### Automation Scripts
- `~/scripts/mam-check.sh` - MAM account automation
- `~/scripts/plex_limit.sh` - Plex bandwidth limiting
- `~/scripts/plex_resume.sh` - Plex bandwidth restoration

### Storage
- `/mnt/storage/` - Main media storage pool
- `/jez-cache/immich/` - Immich cache and database

## Troubleshooting

### Container Won't Start
```bash
# Check container logs
docker logs <container_name>

# Check Docker Compose configuration
docker-compose config

# Restart specific service
docker-compose restart <service_name>
```

### Storage Issues
```bash
# Check disk usage
df -h

# Check MergerFS status
mount | grep mergerfs

# Rebalance storage pool
~/mergerfs.balance
```

### Network Issues
```bash
# Check port availability
netstat -tlnp | grep <port>

# Check container networking
docker network inspect tm_immich-network
```

## Related Documentation

- [NETWORK_MONITORING.md](NETWORK_MONITORING.md) - Network monitoring setup and configuration
- [DOCKER_COMPOSE.md](DOCKER_COMPOSE.md) - Detailed service configurations
- [STORAGE.md](STORAGE.md) - Storage layout and management
- [NETWORK.md](NETWORK.md) - Network configuration
- [BACKUP_RESTORE.md](BACKUP_RESTORE.md) - Backup and restore procedures
- [MAM_AUTOMATION.md](MAM_AUTOMATION.md) - MAM script documentation

## Support & Recovery

For detailed recovery procedures or when things go wrong, refer to:
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [EMERGENCY_RECOVERY.md](EMERGENCY_RECOVERY.md) - Disaster recovery procedures

## Notes

- All services use `network_mode: host` or Docker networking as configured
- Hardware transcoding enabled for Plex via Intel QuickSync
- NFS export configured for QNAP server access
- Timezone: Australia/Melbourne
- User/group: PUID=1000, PGID=1000