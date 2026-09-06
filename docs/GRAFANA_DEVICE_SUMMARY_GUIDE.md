# Grafana Network Device Summary Queries

## Overview
Use these PromQL queries in Grafana to generate summaries of devices that connected to your network in the last month, week, and day.

## Access Grafana
**URL**: http://192.168.0.172:3001
**Login**: admin/admin (change if you haven't already)

## Creating Summary Panels

### Method 1: Using Grafana Query Editor

1. **Go to Dashboard**: Edit your existing UniFi dashboard or create new
2. **Add Panel**: Click "Add panel" → "Choose visualization"
3. **Select Panel Type**: Choose "Table" for device lists or "Stat" for counts
4. **Add Query**: In the query editor, use the PromQL queries below

### Method 2: Using Explore Feature

1. **Click Explore** in left sidebar
2. **Select Prometheus** as data source
3. **Enter the queries** below
4. **Set time range** using the time selector

## PromQL Queries for Device Summaries

### Devices Connected in Last Day (24 Hours)

**Count of unique devices:**
```promql
count(increase(unpoller_client_wifi_attempts_transmit_total[24h]))
```

**List of devices with activity:**
```promql
label_replace(unpoller_client_wifi_attempts_transmit_total, "device", "$1", "name", "(.*)")
```

**Devices with bandwidth usage (last 24h):**
```promql
topk(20, sum by (name, mac, ip) (rate(unpoller_client_wifi_tx_bytes[24h])))
```

### Devices Connected in Last Week (7 Days)

**Count of unique devices:**
```promql
count(increase(unpoller_client_wifi_attempts_transmit_total[7d]))
```

**Most active devices (last 7 days):**
```promql
topk(20, sum by (name, mac, ip) (rate(unpoller_client_wifi_tx_bytes[7d])))
```

**All devices seen in last 7 days:**
```promql
label_replace(unpoller_client_wifi_attempts_transmit_total, "device", "$1", "name", "(.*)")
```

### Devices Connected in Last Month (30 Days)

**Count of unique devices:**
```promql
count(increase(unpoller_client_wifi_attempts_transmit_total[30d]))
```

**Most active devices (last 30 days):**
```promql
topk(20, sum by (name, mac, ip) (rate(unpoller_client_wifi_tx_bytes[30d])))
```

**Device activity summary:**
```promql
sum by (name, mac, ip, ap_name) (increase(unpoller_client_wifi_attempts_transmit_total[30d]))
```

## Advanced Queries

### Device Connection Patterns

**Devices that connected in last day but not in previous week:**
```promql
count(increase(unpoller_client_wifi_attempts_transmit_total[24h])) - count(increase(unpoller_client_wifi_attempts_transmit_total[7d:24h]))
```

**Currently connected devices (active in last 5 minutes):**
```promql
sum by (name, mac, ip) (rate(unpoller_client_wifi_tx_bytes[5m])) > 0
```

### Bandwidth Analysis

**Top bandwidth consumers (last 24h):**
```promql
topk(10, sum by (name) (rate(unpoller_client_wifi_tx_bytes[24h])))
```

**Device bandwidth by hour (last 24h):**
```promql
sum by (name) (rate(unpoller_client_wifi_tx_bytes[1h]))
```

### Access Point Analysis

**Devices per access point (last 24h):**
```promql
count by (ap_name) (unpoller_client_wifi_attempts_transmit_total)
```

**Device distribution across APs:**
```promql
sum by (ap_name, name) (unpoller_client_wifi_attempts_transmit_total)
```

## Creating Summary Dashboard

### Step 1: Create New Dashboard
1. Click **Dashboards** → **New dashboard**
2. Click **Add an empty panel**

### Step 2: Add Device Count Panels

**Panel 1: Devices Today**
- **Type**: Stat
- **Title**: "Devices Connected Today"
- **Query**: `count(increase(unpoller_client_wifi_attempts_transmit_total[24h]))`
- **Time range**: Last 24 hours

**Panel 2: Devices This Week**
- **Type**: Stat
- **Title**: "Devices Connected This Week"
- **Query**: `count(increase(unpoller_client_wifi_attempts_transmit_total[7d]))`
- **Time range**: Last 7 days

**Panel 3: Devices This Month**
- **Type**: Stat
- **Title**: "Devices Connected This Month"
- **Query**: `count(increase(unpoller_client_wifi_attempts_transmit_total[30d]))`
- **Time range**: Last 30 days

### Step 3: Add Device List Panels

**Panel 4: Top Devices Today**
- **Type**: Table
- **Title**: "Most Active Devices Today"
- **Query**: `topk(10, sum by (name, mac, ip) (rate(unpoller_client_wifi_tx_bytes[24h])))`
- **Transform**: Add "Organize fields" to format as table

**Panel 5: All Devices This Week**
- **Type**: Table
- **Title**: "All Devices This Week"
- **Query**: `sum by (name, mac, ip, ap_name) (increase(unpoller_client_wifi_attempts_transmit_total[7d]))`
- **Transform**: Add "Organize fields" to format as table

## Time Range Selection

**In Grafana:**
- **Last 24 hours**: Click time selector → "Last 24 hours"
- **Last 7 days**: Click time selector → "Last 7 days"
- **Last 30 days**: Click time selector → "Last 30 days"
- **Custom range**: Click time selector → "Custom" → Set specific dates

## Alternative: Use Dream Wall Dashboard

For immediate device history (before 12-month data accumulates):

**Access Dream Wall:**
- **URL**: https://192.168.0.250
- **Navigate**: Clients → Insights
- **Time Range**: Use built-in time selector (24h, 7d, 30d, custom)
- **Features**: 
  - Device connection history
  - Bandwidth usage per device
  - Activity patterns
  - Application usage

## Important Notes

### Data Freshness
- **Current Status**: Monitoring just started (July 23, 2026)
- **Available Data**: Only devices collected since setup
- **Historical Data**: Will accumulate over time with 12-month retention
- **Full Reports**: Available after sufficient time has passed

### Query Performance
- **Time ranges**: Longer time ranges may take longer to query
- **Data volume**: More devices = more data to process
- **Optimization**: Use `topk()` to limit results for performance

### Query Tips
- **Always test queries** in Explore before adding to dashboards
- **Use time filters** in Grafana instead of complex PromQL time ranges
- **Label filtering**: Add label filters to focus on specific devices or APs
- **Rate vs increase**: Use `rate()` for bandwidth, `increase()` for counts

## Quick Reference Queries

**Quick device count:**
```promql
count(unpoller_client_wifi_attempts_transmit_total)
```

**Current active devices:**
```promql
sum by (name) (rate(unpoller_client_wifi_tx_bytes[5m])) > 0
```

**All devices ever seen:**
```promql
group by (name, mac, ip) (unpoller_client_wifi_attempts_transmit_total)
```

**Devices with bandwidth usage:**
```promql
sum by (name) (rate(unpoller_client_wifi_tx_bytes[1h]))
```

## Troubleshooting

**No data showing:**
- Check Prometheus is running: `docker ps | grep prometheus`
- Verify unpoller is collecting: `docker logs unpoller`
- Check time range in Grafana (may need to adjust)
- Ensure correct data source selected

**Queries returning zeros:**
- Data may not have accumulated yet for the time range
- Try shorter time ranges (1h, 6h) to verify data exists
- Check unpoller logs for collection errors

**Performance issues:**
- Reduce time range in queries
- Use `topk()` to limit results
- Consider aggregating data with `sum by()`

## Next Steps

1. **Create summary dashboard** with the panels above
2. **Test queries** with different time ranges
3. **Add alerts** for unusual device activity
4. **Customize** queries based on your specific needs
5. **Monitor** storage usage as data accumulates

Your monitoring setup will provide comprehensive device summaries once sufficient data has been collected over the configured time periods.