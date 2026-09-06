# UniFi API Alternatives for Enhanced Device Fingerprinting

## Overview
Since unpoller doesn't extract the internal Dream Wall device tracking ID, here are alternative approaches to access more detailed device fingerprint information.

## Option 1: Direct UniFi Dream Wall API Access

### Challenges Identified
- Dream Wall uses newer API structure (`/proxy/network/`)
- Traditional UniFi API endpoints (`/api/s/`) don't work with Dream Wall
- Authentication differences between Dream Wall and traditional controllers

### Available UniFi API Methods

**Option A: Use Existing Python Libraries**
```python
# Use the official UniFi Python library
from unifi.controller import Controller

c = Controller('192.168.0.250', 'prometheus', 'mr8Sv3lJZYl6Rnlc')
clients = c.get_clients()
# This provides more detailed client information including device IDs
```

**Option B: Use API through Dream Wall Web Interface**
- Access: https://192.168.0.250
- Developer tools can extract API calls used by the web interface
- Dream Wall web interface uses GraphQL APIs internally

**Option C: Use UniFi Protect API (if available)**
- Dream Wall may have additional APIs for advanced features
- Check UniFi developer documentation for Dream Wall specific endpoints

## Option 2: Enhanced unpoller Configuration

### Check unpoller Configuration Options

**Available unpoller features for device tracking:**
```yaml
# In unpoller environment variables
- UP_UNIFI_DEFAULT_SAVE_IDS=true          # Enable ID tracking
- UP_UNIFI_DEFAULT_SAVE_IDENTITY=true    # Enable identity tracking
- UP_UNIFI_DEFAULT_HASH_PII=false        # Don't hash device info
- UP_UNIFI_DEFAULT_FULL_DPI=true         # Full deep packet inspection
```

**Test with enhanced configuration:**
```yaml
unpoller:
  environment:
    - UP_UNIFI_DEFAULT_SAVE_IDS=true
    - UP_UNIFI_DEFAULT_SAVE_IDENTITY=true
    - UP_UNIFI_DEFAULT_HASH_PII=false
    - UP_UNIFI_DEFAULT_FULL_DPI=true
```

## Option 3: Custom API Integration Script

### Create Custom Device Fingerprinting Script

**Python script to access Dream Wall API:**
```python
import requests
import json

# Authenticate with Dream Wall
auth_url = "https://192.168.0.250/api/auth/login"
auth_data = {
    "username": "prometheus",
    "password": "mr8Sv3lJZYl6Rnlc"
}

session = requests.Session()
response = session.post(auth_url, json=auth_data, verify=False)
token = response.json().get('deviceToken')

# Try different Dream Wall API endpoints
endpoints = [
    "/proxy/network/api/s/default/stat/client",
    "/proxy/network/v2/api/site/default/clients",
    "/proxy/network/api/s/default/stat/clients",
    "/api/s/default/stat/client",
]

for endpoint in endpoints:
    try:
        url = f"https://192.168.0.250{endpoint}"
        headers = {"Authorization": f"Bearer {token}"}
        response = session.get(url, headers=headers, verify=False)
        if response.status_code == 200:
            print(f"Success with {endpoint}")
            print(response.json())
    except Exception as e:
        print(f"Failed {endpoint}: {e}")
```

## Option 4: Use Third-Party UniFi API Libraries

### Available Libraries

**1. python-unifi (Most Popular)**
```bash
pip install python-unifi
```

**2. pyunifi**
```bash
pip install pyunifi
```

**3. Custom UniFi API Wrapper**
- Create a custom wrapper for Dream Wall specific endpoints
- Extract device IDs and fingerprinting data
- Export to Prometheus format for Grafana integration

## Option 5: Export and Import Method

### Export from Dream Wall Dashboard

**Method:**
1. Access Dream Wall: https://192.168.0.250
2. Navigate to Clients → Export client data
3. Import client data into your monitoring system
4. Use device IDs for tracking across MAC changes

**Scheduled Export:**
- Set up automated exports from Dream Wall
- Import into Grafana as external data source
- Create custom dashboards using exported data

## Option 6: Network-Level Device Fingerprinting

### Use Additional Network Monitoring Tools

**1. nmap Scanning**
```bash
# Scan network and identify devices by characteristics
nmap -sn 192.168.0.0/24
```

**2. ARP Table Analysis**
```bash
# Monitor ARP table for device patterns
arp -a
```

**3. DHCP Lease Analysis**
- Extract DHCP lease information from Dream Wall
- Use lease times as device identifiers
- Cross-reference with unpoller data

## Option 7: Machine Learning Device Identification

### Create Device Fingerprinting Model

**Features for device identification:**
- Device name (consistent)
- IP address patterns
- Connection time patterns
- Bandwidth usage characteristics
- Access point preference
- Radio type preference
- Vendor information

**Implementation:**
```python
# Use scikit-learn for device clustering
from sklearn.cluster import DBSCAN
import pandas as pd

# Create device features from unpoller data
features = ['name', 'ip', 'ap_name', 'radio_desc', 'oui']
# Cluster devices based on behavior patterns
# Identify same device across MAC changes
```

## Recommended Approach

### Immediate Solution (Most Practical)

**Use Dream Wall Dashboard for device tracking:**
1. Access https://192.168.0.250
2. Use built-in client identification
3. Export device data periodically
4. Cross-reference with Grafana metrics

### Long-term Solution (Most Robust)

**Implement custom API integration:**
1. Create Python script to access Dream Wall API
2. Extract device IDs and fingerprinting data
3. Export to Prometheus custom metrics
4. Integrate with existing Grafana dashboards

### Short-term Enhancement

**Enhance unpoller configuration:**
1. Enable additional unpoller tracking features
2. Test if device IDs become available
3. Configure custom unpoller metrics export

## Implementation Priority

**High Priority:**
- Use Dream Wall built-in tracking (immediate solution)
- Enable enhanced unpoller configuration

**Medium Priority:**
- Implement custom API integration script
- Set up automated exports from Dream Wall

**Low Priority:**
- Machine learning device identification
- Network-level fingerprinting

## Key Considerations

**Authentication:**
- Dream Wall uses token-based authentication
- Traditional UniFi APIs may not work
- Need to find Dream Wall specific endpoints

**API Documentation:**
- Dream Wall API differs from traditional UniFi controllers
- UniFi developer documentation may need Dream Wall specific updates
- Reverse engineering may be required for undocumented features

**Performance:**
- Direct API calls may impact Dream Wall performance
- Rate limiting may be required
- Caching strategies recommended

## Next Steps

1. **Test enhanced unpoller configuration** first (easiest)
2. **Explore Dream Wall web interface API calls** (via browser dev tools)
3. **Implement custom Python script** for API integration
4. **Set up automated exports** from Dream Wall dashboard

The most practical immediate solution is to use the Dream Wall's built-in device tracking while developing a custom API integration for enhanced Grafana integration.