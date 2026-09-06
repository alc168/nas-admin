# Quick Start: Grafana Device Summary Dashboard

## Step-by-Step Instructions

### 1. Access Grafana
```
http://192.168.0.172:3001
```
Login: admin/admin

### 2. Create New Dashboard
1. Click **Dashboards** → **New dashboard**
2. Click **Add an empty panel**

### 3. Add "Devices Today" Panel
- **Panel Type**: Stat
- **Title**: "Devices Connected Today"
- **Query**: `count(unpoller_client_wifi_attempts_transmit_total)`
- **Time Range**: Last 24 hours
- **Click Apply**

### 4. Add "Devices This Week" Panel
- **Panel Type**: Stat  
- **Title**: "Devices Connected This Week"
- **Query**: `count(unpoller_client_wifi_attempts_transmit_total)`
- **Time Range**: Last 7 days
- **Click Apply**

### 5. Add "Devices This Month" Panel
- **Panel Type**: Stat
- **Title**: "Devices Connected This Month"
- **Query**: `count(unpoller_client_wifi_attempts_transmit_total)`
- **Time Range**: Last 30 days
- **Click Apply**

### 6. Add Device List Panel
- **Panel Type**: Table
- **Title**: "All Devices"
- **Query**: `group by (name, mac, ip, ap_name) (unpoller_client_wifi_attempts_transmit_total)`
- **Time Range**: Last 30 days
- **Transform**: Add "Organize fields" → Format as table
- **Click Apply**

### 7. Save Dashboard
- Click **Save** → "Device Summary Dashboard"
- Save to "General" folder

## Important Notes

**Current Data Status:**
- Monitoring started: July 23, 2026 (~1 hour ago)
- Current devices tracked: 16
- Historical data: Will accumulate over time

**For Full Reports:**
- Wait 24 hours for daily reports
- Wait 7 days for weekly reports  
- Wait 30 days for monthly reports

**Alternative for Immediate Historical Data:**
- Use Dream Wall dashboard: https://192.168.0.250
- Navigate to Clients → Insights
- Built-in historical data available immediately

## Quick Reference Queries

**Total devices tracked:**
```promql
count(unpoller_client_wifi_attempts_transmit_total)
```

**Device names and IPs:**
```promql
group by (name, mac, ip) (unpoller_client_wifi_attempts_transmit_total)
```

**Devices by access point:**
```promql
count by (ap_name) (unpoller_client_wifi_attempts_transmit_total)
```

**Most active devices:**
```promql
topk(10, sum by (name) (unpoller_client_wifi_tx_bytes))
```