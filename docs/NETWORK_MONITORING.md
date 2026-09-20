# Network Monitoring Documentation

## Overview

This document describes the network monitoring setup on the TerraMaster server, providing 12-month historical data for network device analysis, application identification, and activity monitoring.

## Monitoring Stack Components

### Prometheus (Port 9090)
**Purpose**: Time-series database for metrics collection and storage  
**Container**: prometheus  
**Configuration**: `~/config/prometheus/prometheus.yml`  
**Data Retention**: 12 months (365 days)  
**Storage**: `~/data/prometheus/`

**Key Features**:
- Metrics collection at 15-second intervals
- 12-month data retention for historical analysis
- Multi-dimensional data model
- Powerful query language (PromQL)

### Grafana (Port 3001)
**Purpose**: Visualization and dashboard platform  
**Container**: grafana  
**Configuration**: `~/config/grafana/`  
**Default Credentials**: admin/admin  
**Storage**: `~/config/grafana/`

**Key Features**:
- Beautiful visualizations and dashboards
- Integration with Prometheus for data source
- Custom dashboard creation
- Alerting capabilities
- User management

### Node Exporter (Port 9100)
**Purpose**: System-level metrics collection  
**Container**: node_exporter  
**Network**: monitoring network  
**Metrics**: CPU, memory, disk, network interfaces

**Key Features**:
- Hardware and OS metrics
- Network interface statistics
- Filesystem information
- System resource monitoring

## Installation and Setup

### Prerequisites
- Docker and Docker Compose installed
- Sufficient disk space for 12-month data retention
- Network access to monitoring ports

### Installation Steps

1. **Create Monitoring Stack**:
```bash
cd ~
docker compose -f docker-compose-monitoring.yml up -d
```

2. **Verify Services**:
```bash
docker ps | grep -E 'grafana|prometheus|node_exporter'
```

3. **Check Service Health**:
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Grafana
curl http://localhost:3001/api/health
```

## Service Configuration

### Prometheus Configuration

**File**: `~/config/prometheus/prometheus.yml`

**Current Targets**:
- `prometheus` (localhost:9090) - Self-monitoring
- `node_exporter` (node_exporter:9100) - System metrics

**Scrape Intervals**:
- Default: 15 seconds
- Prometheus self: 15 seconds
- Node Exporter: 15 seconds

**Data Retention**:
- Configured: 7 days
- Storage location: `~/data/prometheus/`

### Grafana Configuration

**Access**: http://192.168.0.172:3001  
**Default Login**: admin/admin  
**First Steps**:
1. Change default password
2. Add Prometheus as data source
3. Import or create dashboards

**Data Source Configuration**:
- Name: Prometheus
- Type: Prometheus
- URL: http://prometheus:9090
- Access: Server (default)

## Monitoring Capabilities

### Current Monitoring (Available Now)
With the current setup, you can monitor:

**System Metrics** (via Node Exporter):
- CPU usage and load
- Memory usage and availability
- Disk usage and I/O performance
- Network interface traffic (in/out)
- System uptime and load averages

**Server Health**:
- Container status and resource usage
- Service availability
- Performance trends over 7 days

### UniFi Dream Wall Integration (✅ Working)

**Status**: unpoller successfully authenticating and collecting data from UniFi Dream Wall.

**Current Status**:
- **✅ unpoller Container**: Running and healthy (port 9130)
- **✅ Prometheus Integration**: Configured and successfully scraping data
- **✅ Dream Wall Authentication**: Working with alphanumeric password
- **✅ Data Collection**: Collecting 28 clients, 5 access points, 1 gateway, DPI stats

**Resolved Issue**:
- Original issue: Special characters in password caused 500 errors
- Solution: Changed Dream Wall password to alphanumeric only
- Result: unpoller now successfully authenticates and collects data

**Current Configuration**:
```yaml
unpoller:
  image: ghcr.io/unpoller/unpoller:latest
  container_name: unpoller
  environment:
    - UP_UNIFI_DEFAULT_URL=https://192.168.0.250
    - UP_UNIFI_DEFAULT_USER=prometheus
    - UP_UNIFI_DEFAULT_PASS=${UP_UNIFI_DEFAULT_PASS}   # real value lives in ~/.env, never here
    - UP_UNIFI_DEFAULT_VERIFY_SSL=false
    - UP_UNIFI_DEFAULT_SAVE_SITES=true
    - UP_UNIFI_DEFAULT_SAVE_DPI=true
    - UP_UNIFI_DEFAULT_SAVE_CLIENTS=true
    - UP_PROMETHEUS_HTTP_LISTEN=0.0.0.0:9130
    - UP_PROMETHEUS_NAMESPACE=unpoller
    - UP_INFLUXDB_DISABLE=true
```

**Data Being Collected**:
- **28 Clients**: Device names, MAC addresses, IP addresses, signal quality
- **5 Access Points**: U6+, U6 IW Upstairs, DW19 (Dream Wall)
- **1 Gateway**: DW19 (Dream Wall)
- **DPI Stats**: Application-level traffic analysis
- **Network Topology**: Complete network mapping
- **Performance Metrics**: Signal strength, connection quality, bandwidth

**Working Credentials**:
- **Dream Wall IP**: 192.168.0.250
- **Username**: prometheus
- **Password**: (configured in docker-compose.yml)
- **Authentication**: Valid for manual access but not via unpoller

**Current Configuration**:
```yaml
unpoller:
  image: ghcr.io/unpoller/unpoller:latest
  container_name: unpoller
  environment:
    - UP_UNIFI_DEFAULT_URL=https://192.168.0.250
    - UP_UNIFI_DEFAULT_USER=prometheus
    - UP_UNIFI_DEFAULT_PASS=${UP_UNIFI_DEFAULT_PASS}   # real value lives in ~/.env, never here
    - UP_UNIFI_DEFAULT_VERIFY_SSL=false
    - UP_PROMETHEUS_HTTP_LISTEN=0.0.0.0:9130
    - UP_PROMETHEUS_NAMESPACE=unpoller
    - UP_INFLUXDB_DISABLE=true
```

### Network Device Monitoring (✅ Fully Operational)

**Primary Solution: unpoller Integration**
- Access Dream Wall dashboard at https://192.168.0.250
- **Device-level monitoring**: 28 tracked clients with detailed information
- **12-month historical data**: Available via Prometheus + Grafana
- **Application identification**: DPI stats for traffic analysis
- **Network topology**: Complete mapping of access points and gateways
- **Performance metrics**: Signal quality, bandwidth, connection health

**Data Available via unpoller**:
- **Client Information**: Device names, MAC addresses, IP addresses, manufacturers
- **Access Point Data**: Signal strength, channel usage, connection quality
- **Gateway Statistics**: Dream Wall performance and network stats
- **DPI Analytics**: Application-level traffic categorization
- **Historical Trends**: 12-month data retention in Prometheus
- **Real-time Metrics**: 30-second scrape intervals for live data

**Grafana Dashboard Setup**:
1. Access Grafana: http://192.168.0.172:3001
2. Add Prometheus data source: http://prometheus:9090
3. Import UniFi dashboard (search for "unpoller" or "UniFi")
4. Visualize client devices, network topology, and traffic patterns

### UniFi Dream Wall Integration (Manual Setup Required)

**Current Status**: Automated UniFi exporter setup not available due to Docker image availability issues.

**Alternative Approaches**:

**Option 1: Use UniFi Dream Wall Built-in Features**
- Access Dream Wall dashboard at https://192.168.0.250
- Built-in device monitoring and traffic analysis
- Historical data available in UniFi interface
- No additional setup required

**Option 2: Manual NetFlow Configuration**
1. Enable NetFlow on Dream Wall:
   - Access Dream Wall dashboard
   - Settings → Network Settings → NetFlow
   - Configure NetFlow collector: 192.168.0.172, port 2055
2. Use existing Prometheus + Grafana for visualization
3. Install NetFlow collector if needed

**Option 3: Alternative Exporter Images**
Try these alternative UniFi exporter images:
- `joshuabrooks/unifi-exporter`
- `dnixiod/unifi-poller`
- `jojo135/unifi-exporter`

**For Docker Image Issues**:
1. Check Docker Hub for available UniFi exporter images
2. Verify image availability: `docker search unifi`
3. Test alternative images manually

## Dashboard Setup

### Recommended Dashboards

**System Overview Dashboard**:
- CPU, Memory, Disk usage gauges
- Network traffic graphs
- System load averages
- Container status indicators

**Network Analysis Dashboard**:
- Interface traffic in/out
- Connection statistics
- Bandwidth utilization
- Error rates

**7-Day Historical Analysis**:
- Traffic trends over time
- Peak usage periods
- Resource utilization patterns
- Growth trends

### Dashboard Import

1. **Access Grafana**: http://192.168.0.172:3001
2. **Navigate**: Dashboards → Import
3. **Import ID**: Search for "Node Exporter Full" (ID: 1860)
4. **Select Prometheus**: Choose Prometheus as data source

## Access URLs

### Services
- **Grafana**: http://192.168.0.172:3001
- **Prometheus**: http://192.168.0.172:9090
- **Node Exporter**: http://192.168.0.172:9100

### API Endpoints
- **Prometheus API**: http://192.168.0.172:9090/api/v1/
- **Node Exporter Metrics**: http://192.168.0.172:9100/metrics

## Data Management

### Backup Configuration
```bash
# Backup Prometheus configuration
tar -czf ~/backups/prometheus_config_$(date +%Y%m%d).tar.gz ~/config/prometheus/

# Backup Grafana configuration
tar -czf ~/backups/grafana_config_$(date +%Y%m%d).tar.gz ~/config/grafana/
```

### Data Cleanup
Prometheus automatically manages data retention based on the 12-month setting. No manual cleanup required for metrics data.

### Storage Monitoring
```bash
# Check Prometheus data usage
du -sh ~/data/prometheus/

# Check Grafana data usage
du -sh ~/config/grafana/
```

## Troubleshooting

### Common Issues

**Grafana Won't Start**:
```bash
# Check logs
docker logs grafana

# Check permissions
ls -la ~/config/grafana/

# Fix permissions if needed
chown -R 1000:1000 ~/config/grafana/
```

**Prometheus Not Collecting Data**:
```bash
# Check logs
docker logs prometheus

# Check configuration
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Check targets
curl http://localhost:9090/api/v1/targets
```

**Node Exporter Not Reachable**:
```bash
# Check network connectivity
docker exec prometheus ping node_exporter

# Check if node_exporter is running
docker ps | grep node_exporter

# Restart node_exporter
docker restart node_exporter
```

### Performance Issues

**High Memory Usage**:
- Reduce data retention if needed
- Adjust scrape intervals
- Optimize dashboard queries

**Slow Dashboards**:
- Reduce query complexity
- Use time range filters
- Optimize panel refresh rates

## Maintenance

### Regular Tasks

**Daily**:
- Check service status: `docker ps | grep -E 'grafana|prometheus|node_exporter'`
- Monitor disk usage: `df -h`

**Weekly**:
- Review dashboard performance
- Check for data anomalies
- Verify 12-month retention is working

**Monthly**:
- Review and optimize dashboards
- Update Grafana plugins
- Check for security updates

### Service Updates

```bash
# Update monitoring stack
cd ~
docker compose -f docker-compose-monitoring.yml pull
docker compose -f docker-compose-monitoring.yml up -d
```

## Security Considerations

### Current Security
- Default Grafana password (change immediately)
- No authentication on Prometheus (internal use)
- Network exposure limited to local network

### Security Improvements
1. **Change Grafana Password**: Access Grafana → Configuration → Users
2. **Enable SSL**: Use reverse proxy with SSL termination
3. **Network Isolation**: Use firewall rules to restrict access
4. **User Management**: Create limited access users for dashboards

## Advanced Configuration

### Custom Metrics
To add custom metrics, extend the Prometheus configuration:

```yaml
scrape_configs:
  - job_name: 'custom_exporter'
    static_configs:
      - targets: ['custom_exporter:9101']
    scrape_interval: 30s
```

### Alerting
Configure Prometheus alerting rules:

```yaml
groups:
  - name: system_alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))) > 80
        for: 5m
        annotations:
          summary: "High CPU usage detected"
```

## Integration with Existing Services

### Docker Compose Integration
The monitoring stack runs as a separate compose file to avoid conflicts with existing services.

### Cross-Server Monitoring
To monitor QNAP server:
1. Install Node Exporter on QNAP
2. Add QNAP as target in Prometheus configuration
3. Create separate dashboard for QNAP metrics

## Performance Impact

### Resource Usage
- **CPU**: Minimal (<5% total)
- **Memory**: ~500MB for full stack
- **Disk**: Varies based on metrics volume (estimated 1-2GB for 7 days)

### Optimization
- Adjust scrape intervals if needed
- Optimize Prometheus storage configuration
- Use data source caching in Grafana

## Next Steps

### Immediate
1. Access Grafana and change default password
2. Add Prometheus as data source in Grafana
3. Import recommended dashboards
4. Verify 12-month data retention is working

### Short-term
1. Configure UniFi Dream Wall integration
2. Set up custom dashboards for your needs
3. Configure alerting rules
4. Document dashboard configurations

### Long-term
1. Implement advanced network monitoring
2. Set up log aggregation
3. Create automated reports
4. Implement predictive monitoring

## Support and Resources

### Documentation
- Prometheus Documentation: https://prometheus.io/docs/
- Grafana Documentation: https://grafana.com/docs/
- Node Exporter: https://github.com/prometheus/node_exporter

### Community
- Grafana Community: https://community.grafana.com/
- Prometheus Community: https://prometheus.io/community/

## Related Documentation
- [README.md](README.md) - Overall server documentation
- [MAINTENANCE.md](MAINTENANCE.md) - Server maintenance procedures
- [NETWORK.md](NETWORK.md) - Network configuration details
- [GRAFANA_DEVICE_SUMMARY_GUIDE.md](GRAFANA_DEVICE_SUMMARY_GUIDE.md) - Guide for generating device summaries
- [QUICK_GRAFANA_START.md](QUICK_GRAFANA_START.md) - Quick start for Grafana dashboards