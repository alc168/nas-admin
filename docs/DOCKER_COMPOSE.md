# Docker Compose Services Documentation

This document details all Docker services running on the TerraMaster server.

## Service Overview

### Media Downloading

#### qbt-tl (qBittorrent - Torrent Leech)
**Purpose**: Download movies, TV shows, and sports content from Torrent Leech  
**Container**: qbt-tl  
**Image**: lscr.io/linuxserver/qbittorrent:latest  
**Ports**: 8080 (Web UI), 40012 (Torrent connections)  
**Network**: host  
**Config**: `~/config/qbt-tl/`  
**Storage**: `/mnt` (full mount)  
**Default Save Path**: `/mnt/storage/data`  
**Categories**: 
- Movies, TV shows, Sports (F1, AFL, EPL)
- Sports content handled via categories, not separate instance

**Key Configuration**:
- WebUI Port: 8080
- Torrent Port: 40012
- Auto TMM (Torrent Management Mode): Enabled
- Default save path: `/mnt/storage/data`

### Media Automation (The "Arr" Stack)

#### Sonarr (TV Series Management)
**Purpose**: Automated TV show downloading and management  
**Container**: sonarr  
**Image**: lscr.io/linuxserver/sonarr:latest  
**Port**: 8989  
**Network**: host  
**Config**: `~/config/sonarr/`  
**Storage**: `/mnt` (full mount)  
**Download Client**: qbt-tl

**Key Features**:
- Automatic episode downloading
- Quality profiles and renaming
- Series metadata management
- Integration with Seerr for requests

#### Radarr (Movie Management)
**Purpose**: Automated movie downloading and management  
**Container**: radarr  
**Image**: lscr.io/linuxserver/radarr:latest  
**Port**: 7878  
**Network**: host  
**Config**: `~/config/radarr/`  
**Storage**: `/mnt` (full mount)  
**Download Client**: qbt-tl

**Key Features**:
- Automatic movie downloading
- Quality profiles and renaming
- Movie metadata management
- Integration with Seerr for requests

#### Prowlarr (Indexer Manager)
**Purpose**: Centralized torrent indexer management  
**Container**: prowlarr  
**Image**: lscr.io/linuxserver/prowlarr:latest  
**Port**: 9696  
**Network**: host  
**Config**: `~/config/prowlarr/`  
**Storage**: No external storage mount

**Key Features**:
- Manages all torrent indexers
- Syncs indexers to Sonarr/Radarr
- Supports various tracker types
- API-based integration

#### Autobrr (Torrent Automation)
**Purpose**: Advanced torrent filtering and automation  
**Container**: autobrr  
**Image**: ghcr.io/autobrr/autobrr:latest  
**Port**: 7474  
**Network**: host  
**Config**: `~/config/autobrr/`  
**Storage**: No external storage mount

**Key Features**:
- Advanced release filtering
- IRC-based announcements
- Custom filters and actions
- Integration with Prowlarr

### User Interface & Requests

#### Seerr (Media Request Interface)
**Purpose**: User-friendly media request interface  
**Container**: seerr  
**Image**: ghcr.io/seerr-team/seerr:latest  
**Port**: 5055  
**Network**: bridge (port mapping)  
**Config**: `~/config/overseerr/`  
**Storage**: No external storage mount

**Key Features**:
- User request management
- Integration with Sonarr/Radarr
- User management and permissions
- Request notifications

### Media Server

#### Plex (Media Serving)
**Purpose**: Media streaming server  
**Container**: plex2  
**Image**: lscr.io/linuxserver/plex:latest  
**Network**: host  
**Config**: `~/config/` (note: maps to ./config in compose file)  
**Storage**: 
- `/mnt` (full mount)
- `/mnt/storage/plex-mobile` (mapped to /plex-mobile)
- `/mnt/storage/plex-movies` (mapped to /plex-movies)
- `/mnt/storage/plex-tv` (mapped to /plex-tv)
- `/mnt/temp` (temporary/transcode)

**Hardware Acceleration**:
- Intel QuickSync via `/dev/dri`
- Hardware transcoding enabled

**Key Features**:
- Media organization and streaming
- Multiple user support
- Live TV and DVR (if configured)
- Hardware transcoding

### Photo Management

#### Immich Stack
**Purpose**: Self-hosted photo management alternative to Google Photos

##### immich_server
**Container**: immich_server  
**Image**: ghcr.io/immich-app/immich-server:v3  
**Port**: 2283  
**Network**: tm_immich-network  
**Storage**: 
- `/mnt/storage/jez-photos` (mapped to /usr/src/app/upload)
- `/etc/localtime` (read-only)

**Environment**: From `.env` file

##### immich_machine_learning
**Container**: immich_machine_learning  
**Image**: ghcr.io/immich-app/immich-machine-learning:v3  
**Network**: tm_immich-network  
**Storage**: `/jez-cache/immich/model-cache` (mapped to /cache)

**Environment**: From `.env` file

##### immich_postgres
**Container**: immich_postgres  
**Image**: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0  
**Network**: tm_immich-network  
**Storage**: 
- `/jez-cache/immich/postgres` (database)
- `/mnt` (access to storage)

**Environment**:
- POSTGRES_PASSWORD: ${DB_PASSWORD}
- POSTGRES_USER: ${DB_USERNAME}
- POSTGRES_DB: ${DB_DATABASE}
- DB_STORAGE_TYPE: 'HDD'

##### immich_redis
**Container**: immich_redis  
**Image**: registry.hub.docker.com/library/redis:6.2-alpine  
**Network**: tm_immich-network  
**Storage**: None

##### immich_power_tools
**Container**: immich_power_tools  
**Image**: ghcr.io/varun-raj/immich-power-tools:latest  
**Port**: 8001 (mapped to 3000)  
**Network**: tm_immich-network  
**Environment**: From `.env` file

**Health Check**: 
- Updated to use correct Docker network IP: `http://172.19.0.5:3000/api/health`
- Interval: 30s, Timeout: 10s, Retries: 3

### Metadata & Tools

#### Kometa (Plex Metadata)
**Purpose**: Automated Plex metadata management  
**Container**: kometa  
**Image**: kometateam/kometa  
**Network**: bridge  
**Config**: `~/config/kometa/`  
**Schedule**: Daily at 3 AM (KOMETA_TIMES=03:00)

**Key Features**:
- Automated metadata collection
- Collection management
- Poster and banner management
- Playlist creation

#### Bitmappery (Image Editor)
**Purpose**: Web-based image editing  
**Container**: bitmappery  
**Image**: Custom build from GitHub  
**Port**: 5173  
**Network**: bridge  
**Storage**: bitmappery_data volume  
**User**: 1000:1000 (non-root)

**Key Features**:
- Web-based image editing
- Custom build from igorski/bitmappery
- Volume for persistent data

## Docker Compose Structure

```yaml
services:
  # Downloaders
  qbt-tl:
    # qBittorrent for Torrent Leech
  
  # Media Automation
  sonarr:
    # TV show management
  
  radarr:
    # Movie management
  
  prowlarr:
    # Indexer management
  
  autobrr:
    # Torrent automation
  
  # User Interface
  seerr:
    # Media requests
  
  # Media Server
  plex2:
    # Media serving
  
  # Photo Management
  immich_server:
    # Main Immich application
  
  immich_machine_learning:
    # ML features
  
  immich_postgres:
    # Database
  
  immich_redis:
    # Cache
  
  immich_power_tools:
    # Admin tools
  
  # Metadata & Tools
  kometa:
    # Plex metadata
  
  bitmappery:
    # Image editor

networks:
  immich-network:
    # Internal Immich networking

volumes:
  bitmappery_data:
    # Persistent data for Bitmappery
```

## Service Dependencies

### Immich Stack Dependencies
```
immich_server
├── depends_on: redis, database
├── network: immich-network
└── env_file: .env

immich_machine_learning
├── network: immich-network
└── env_file: .env

redis
└── network: immich-network

database (immich_postgres)
├── network: immich-network
└── environment variables

immich_power_tools
├── network: immich-network
└── env_file: .env
```

### Media Automation Dependencies
```
Seerr → Sonarr/Radarr → Prowlarr → Autobrr → qbt-tl
```

## Environment Variables

### Immich (.env file)
```bash
IMMICH_URL=http://192.168.0.172:2283
IMMICH_API_KEY=<your_api_key>
POWER_TOOLS_ENDPOINT_URL=http://192.168.0.172:8001/api
IMMICH_VERSION=v3

DB_HOST=database
DB_PORT=5432
DB_DATABASE=immich
DB_DATABASE_NAME=immich
DB_USERNAME=postgres
DB_PASSWORD=immich

JWT_SECRET=<your_jwt_secret>
```

## Restart Policies

- **unless-stopped**: Most services (qbt-tl, sonarr, radarr, prowlarr, autobrr, seerr, kometa, plex2)
- **always**: Immich stack (immich_server, immich_machine_learning, immich_postgres, immich_redis, immich_power_tools)

## Network Modes

- **host**: qbt-tl, sonarr, radarr, prowlarr, autobrr, plex2 (for performance and local network access)
- **bridge**: seerr, bitmappery, kometa (with port mappings)
- **custom**: Immich stack (tm_immich-network for internal communication)

## Hardware Acceleration

### Plex
- Device: `/dev/dri:/dev/dri`
- Purpose: Intel QuickSync hardware transcoding

### Immich
- Device: Not currently configured (can be added for hardware acceleration)

## Troubleshooting Docker Services

### Service Won't Start
```bash
# Check logs
docker logs <container_name>

# Check configuration
docker-compose config

# Restart service
docker-compose restart <service_name>

# Rebuild service
docker-compose up -d --force-recreate <service_name>
```

### Network Issues
```bash
# Check container network
docker network inspect tm_immich-network

# Check container IP
docker inspect <container_name> | grep IPAddress

# Test connectivity
docker exec <container_name> ping <target_container>
```

### Storage Issues
```bash
# Check mounts
docker inspect <container_name> | grep Mounts

# Check volume usage
docker system df

# Clean up unused volumes
docker volume prune
```

## Backup Considerations

### What to Backup
- `~/config/` - All service configurations
- `~/.env` - Environment variables
- `~/scripts/` - Automation scripts
- `~/.mam_script/` - MAM script data

### What Doesn't Need Backup
- Docker images (can be recreated)
- Container temporary data
- Log files (can be regenerated)

### Application-Level Backups
- Sonarr/Radarr/Prowlarr: Built-in backup systems (keep last 2)
- Immich: Database and photo storage
- Plex: Metadata and preferences