# Network Configuration Documentation

## Network Overview

### Server Network
- **Server IP**: 192.168.0.172
- **Subnet**: 192.168.0.0/24
- **Gateway**: 192.168.0.250 (UniFi Dream Wall)
- **DNS**: (configured in Dream Wall settings)

### Network Hardware

#### UniFi Dream Wall
- **IP Address**: 192.168.0.250
- **Purpose**: Network gateway, firewall, and management
- **Monitoring**: Built-in device monitoring and historical analysis
- **API**: UniFi Network API (different from traditional UniFi controllers)
- **Access**: https://192.168.0.250

### Server Network
- **Server IP**: 192.168.0.172
- **Subnet**: 192.168.0.0/24
- **Gateway**: (router IP, typically 192.168.0.1)
- **DNS**: (configured in system network settings)

### Docker Network Modes
The server uses multiple Docker networking strategies:
- **host mode**: For services needing direct network access
- **bridge mode**: For isolated services with port mapping
- **custom networks**: For service-to-service communication

## Service Port Configuration

### Media Downloading
| Service | Port | Protocol | Network Mode | Purpose |
|---------|------|----------|--------------|---------|
| qBittorrent (qbt-tl) | 8080 | TCP | host | Web UI |
| qBittorrent (qbt-tl) | 40012 | TCP/UDP | host | Torrent connections |

### Media Automation
| Service | Port | Protocol | Network Mode | Purpose |
|---------|------|----------|--------------|---------|
| Sonarr | 8989 | TCP | host | Web UI |
| Radarr | 7878 | TCP | host | Web UI |
| Prowlarr | 9696 | TCP | host | Web UI |
| Autobrr | 7474 | TCP | host | Web UI |

### User Interface
| Service | Port | Protocol | Network Mode | Purpose |
|---------|------|----------|--------------|---------|
| Seerr | 5055 | TCP | bridge | Web UI |

### Media Server
| Service | Port | Protocol | Network Mode | Purpose |
|---------|------|----------|--------------|---------|
| Plex | 32400 | TCP | host | Default port |
| Plex | 1900 | UDP | host | DLNA/Discovery |
| Plex | 32410 | UDP | host | GDM (Discovery) |
| Plex | 32412 | UDP | host | GDM (Discovery) |
| Plex | 32413 | UDP | host | GDM (Discovery) |
| Plex | 32414 | UDP | host | GDM (Discovery) |

### Photo Management
| Service | Port | Protocol | Network Mode | Purpose |
|---------|------|----------|--------------|---------|
| Immich | 2283 | TCP | bridge | Web UI |
| Immich Power Tools | 8001 | TCP | bridge | Admin interface |

### Tools
| Service | Port | Protocol | Network Mode | Purpose |
|---------|------|----------|--------------|---------|
| Bitmappery | 5173 | TCP | bridge | Image editor |

### Network Monitoring
| Service | Port | Protocol | Network Mode | Purpose |
|---------|------|----------|--------------|---------|
| Grafana | 3001 | TCP | bridge | Monitoring dashboards |
| Prometheus | 9090 | TCP | bridge | Metrics collection API |
| Node Exporter | 9100 | TCP | bridge | System metrics |
| UniFi Poller | 9130 | TCP | bridge | UniFi integration (working with Dream Wall) |

## Docker Networks

### Default Network
- **Name**: tm_default
- **Driver**: bridge
- **Scope**: local
- **Purpose**: Default Docker bridge network

### Immich Network
- **Name**: tm_immich-network
- **Driver**: bridge
- **Subnet**: 172.19.0.0/16
- **Gateway**: 172.19.0.1
- **Purpose**: Internal Immich stack communication

#### Immich Network Allocation
| Container | IP Address | Purpose |
|-----------|-------------|---------|
| immich_postgres | 172.19.0.2 | Database |
| immich_redis | 172.19.0.3 | Cache |
| immich_machine_learning | 172.19.0.4 | ML processing |
| immich_power_tools | 172.19.0.5 | Admin tools |
| immich_server | 172.19.0.6 | Main application |

### Monitoring Network
- **Name**: tm_monitoring
- **Driver**: bridge
- **Purpose**: Monitoring stack internal communication
- **Services**: Prometheus, Grafana, Node Exporter, UniFi Poller

### Host Network
- **Purpose**: Direct host network access for performance
- **Services**: qBittorrent, Sonarr, Radarr, Prowlarr, Autobrr, Plex
- **Benefits**: Better performance, simpler networking

## Cross-Server Communication

### NFS Configuration
- **Server**: TerraMaster (192.168.0.172)
- **Client**: QNAP (192.168.0.173)
- **Export**: `/mnt/storage`
- **Mount Point**: `/mnt/storage` (on QNAP)
- **Protocol**: NFSv3
- **Options**: large transfer sizes, hard mounting

### NFS Management
```bash
# Check NFS exports (TerraMaster)
showmount -e

# Check NFS mount status (QNAP)
mount | grep nfs

# Test NFS connectivity
ping 192.168.0.172
```

## Network Security

### Firewall Configuration
- **Internal Network**: Services accessible on local network
- **External Access**: Port forwarding configured for external access
- **VPN**: Consider VPN for remote access instead of port forwarding

### Security Best Practices
1. **VPN**: Use VPN for remote access instead of exposing ports
2. **Authentication**: Enable authentication on all services
3. **Updates**: Keep services updated for security patches
4. **Monitoring**: Monitor network access logs

## Network Troubleshooting

### Port Conflicts
```bash
# Check port usage
netstat -tlnp | grep <port>

# Check which process is using a port
sudo lsof -i :<port>

# Check Docker port mappings
docker port <container_name>
```

### Network Connectivity
```bash
# Test local connectivity
ping 192.168.0.172

# Test DNS resolution
nslookup google.com

# Test external connectivity
curl -I https://google.com
```

### Docker Network Issues
```bash
# Check Docker networks
docker network ls

# Inspect specific network
docker network inspect tm_immich-network

# Restart Docker networking
sudo systemctl restart docker
```

### NFS Issues
```bash
# Check NFS server status
sudo systemctl status nfs-server

# Check NFS exports
showmount -e

# Test NFS mount
mount -t nfs 192.168.0.172:/mnt/storage /mnt/test
```

## Performance Optimization

### Network Performance
- **Host Networking**: Used for high-performance services
- **Bridge Networking**: Used for isolated services
- **Custom Networks**: Optimized for service-to-service communication

### NFS Performance
- **Large Transfer Sizes**: Configured for better performance
- **Hard Mounting**: Ensures reliability
- **Local Network**: Gigabit local network

## Monitoring

### Network Monitoring
```bash
# Check network interfaces
ip addr show

# Check network statistics
ip -s link show

# Check active connections
netstat -an
```

### Service Monitoring
```bash
# Check if service ports are listening
netstat -tlnp | grep <service_name>

# Check Docker container networking
docker inspect <container_name> | grep Network

# Test service accessibility
curl -I http://localhost:<port>
```

## Configuration Files

### Docker Compose Networking
```yaml
# Host networking example
qbt-tl:
  network_mode: host

# Bridge networking with port mapping
seerr:
  ports:
    - "5055:5055"

# Custom network
immich_server:
  networks:
    - immich-network
```

### NFS Exports
```bash
# /etc/exports
/mnt/storage 192.168.0.0/24(rw,sync,no_subtree_check)
```

## Future Improvements

### Network Optimization
- **VLANs**: Consider VLANs for service isolation
- **Load Balancing**: Consider load balancing for high-availability
- **Network Monitoring**: Implement network monitoring solutions

### Security Enhancements
- **VPN**: Implement VPN for remote access
- **Firewall**: Configure firewall rules
- **Intrusion Detection**: Consider IDS/IPS solutions

## Related Documentation
- [DOCKER_COMPOSE.md](DOCKER_COMPOSE.md) - Service network configuration
- [STORAGE.md](STORAGE.md) - NFS storage configuration
- [README.md](README.md) - Overall server documentation