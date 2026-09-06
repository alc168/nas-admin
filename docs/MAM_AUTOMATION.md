# MAM Automation Script Documentation

## Overview

The MAM (MyAnonamouse) automation script manages your MAM tracker account automatically, handling bonus point spending, VIP status, and account maintenance.

## Script Location

- **Script**: `~/scripts/mam-check.sh`
- **Log File**: `~/scripts/activity.log`
- **Data Directory**: `~/.mam_script/`
- **Configuration**: Embedded in script (MAMID, buffer settings, etc.)

## Script Purpose

The MAM automation script performs the following tasks:

1. **Session Management**: Maintains MAM session via cookies
2. **Bonus Point Spending**: Automatically spends bonus points on upload credit
3. **VIP Status**: Automatically purchases VIP status
4. **Wedge Purchasing**: Optionally buys wedges (currently disabled)
5. **Buffer Management**: Maintains buffer above configured threshold
6. **Activity Logging**: Logs all activities for monitoring

## Configuration

### Current Settings
```bash
MAMID="DfJzEQ24a9R8KrwwhVV3k_UAAdCVxZ8cGX_v0n8RmOuy2F1mvFKOjTTFNa8YrVuCcYSxYUwYbz60a7LyxnOl-IFuorV1y7G3lR6f1YNeNfHFsLzB6KjyD1Hbkz3NReKWrUwlaZZlVFzuuJCJnaP2V3PGB6WT_uddV26lE2OxUK1qoImxbl4A1F4rk_hakRUa_E1dDaVaOYUmFnizeYNWeA_KlTmv5eL91PtGaeN9K1AqbaJhj9HHXh3aYetWSfTJH1wTN68snVjsmVklGjPWKdefO1m5amBJRoD"

BUFFER=10000              # Stay above 10,000 points
VIP="1"                   # Enable VIP buying
WEDGEHOURS=0              # Buy wedges every 4 hours (0 = disabled)
```

### Configuration Explanation

- **MAMID**: Your MAM identifier for session authentication
- **BUFFER**: Minimum bonus points to maintain before spending
- **VIP**: Set to 1 to enable automatic VIP purchases
- **WEDGEHOURS**: Hours between wedge purchases (0 = disabled)

## Script Operation

### Execution Flow
1. **Initialization**: Create working directories and setup logging
2. **Session Check**: Verify existing MAM session via cookies
3. **Session Renewal**: Create new session if existing one is invalid
4. **Point Collection**: Get current bonus point balance
5. **Wedge Logic**: Purchase wedges if enabled and sufficient points
6. **VIP Logic**: Purchase VIP status if enabled
7. **Spending Logic**: Spend bonus points on upload credit
8. **Logging**: Record all activities to log file

### Dependencies
The script requires the following tools:
- `jq` - JSON processor for parsing API responses
- `curl` - HTTP client for API requests
- `bc` - Calculator for numeric comparisons

### Installation of Dependencies
```bash
sudo apt update
sudo apt install jq curl bc
```

## Scheduling

### Manual Execution
```bash
cd ~
./scripts/mam-check.sh
```

### Automated Scheduling
Consider adding to crontab for regular execution:
```bash
# Run every 6 hours
0 */6 * * * /home/tm/scripts/mam-check.sh
```

## Monitoring

### Check Logs
```bash
# View recent activity
tail ~/scripts/activity.log

# View entire log
cat ~/scripts/activity.log

# Follow log in real-time
tail -f ~/scripts/activity.log
```

### Check Script Status
```bash
# Check last run time
stat ~/scripts/activity.log

# Check for errors
grep -i error ~/scripts/activity.log
```

## Troubleshooting

### Session Issues
**Problem**: "Session invalid" or "Cannot create new session"  
**Solution**: 
- Verify MAMID is correct
- Check MAM account status
- Ensure network connectivity to MAM

### Dependency Issues
**Problem**: "command not found" errors  
**Solution**: Install missing dependencies:
```bash
sudo apt install jq curl bc
```

### Spending Issues
**Problem**: Points not being spent  
**Solution**:
- Check if buffer threshold is met
- Verify MAM API is accessible
- Check log for specific error messages

### Permission Issues
**Problem**: Script cannot write to directories  
**Solution**:
```bash
chmod +x ~/scripts/mam-check.sh
chmod 755 ~/.mam_script
```

## Security Considerations

### MAMID Security
- The MAMID is sensitive authentication information
- Keep script permissions restricted (700 or 750)
- Do not share script with MAMID exposed

### Cookie Security
- Cookies are stored in `~/.mam_script/MAM.cookies`
- Cookie file permissions should be restricted
- Cookies are used for session persistence

### Logging
- Log file may contain sensitive information
- Regularly review and clean log file
- Consider log rotation for long-term operation

## Maintenance

### Regular Tasks
- **Weekly**: Review activity log for issues
- **Monthly**: Verify MAM account status and ratio
- **Quarterly**: Review and adjust buffer settings

### Log Rotation
Consider implementing log rotation:
```bash
# Add to logrotate configuration
~/scripts/activity.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
}
```

## Integration with Other Services

### qBittorrent (QNAP)
The MAM automation script works in conjunction with:
- **qbittorrent on QNAP**: Downloads MAM content
- **Audiobookshelf**: Organizes MAM audiobooks

### Data Flow
```
MAM Script (Account Management)
    ↓
MAM Tracker (Bonus Points & VIP)
    ↓
qbittorrent on QNAP (Content Download)
    ↓
Audiobookshelf (Content Management)
```

## Current Account Status

Based on the latest MAM.json data:
- **Username**: alchemist168
- **Class**: VIP
- **Uploaded**: 19.951 TiB
- **Downloaded**: 66.16 GiB
- **Ratio**: 308.8
- **Seed Bonus**: 35,179 points
- **VIP Until**: 2026-10-18

## Script Modifications

### Changing Buffer Threshold
Edit the BUFFER value in the script:
```bash
BUFFER=20000  # Increase to 20,000 points
```

### Enabling Wedge Purchases
Edit the WEDGEHOURS value:
```bash
WEDGEHOURS=4  # Buy wedges every 4 hours
```

### Disabling VIP Purchases
Edit the VIP value:
```bash
VIP="0"  # Disable automatic VIP purchases
```

## Best Practices

1. **Regular Monitoring**: Check logs weekly for issues
2. **Conservative Settings**: Maintain adequate buffer
3. **Account Safety**: Monitor account status regularly
4. **Backup Configuration**: Keep backup of script with custom settings
5. **Testing**: Test configuration changes manually before automation

## Emergency Procedures

### Script Fails to Run
1. Check script permissions: `ls -la ~/scripts/mam-check.sh`
2. Verify dependencies: `which jq curl bc`
3. Check log file: `tail ~/scripts/activity.log`
4. Test manual execution: `./scripts/mam-check.sh`

### Account Issues
1. Check MAM website directly for account status
2. Verify MAMID is still valid
3. Check network connectivity to MAM
4. Review MAM rules and guidelines

### Excessive Spending
1. Immediately stop script: `pkill -f mam-check.sh`
2. Check current point balance on MAM
3. Review log for spending patterns
4. Adjust BUFFER threshold upward

## Related Documentation
- [README.md](README.md) - Overall server documentation
- [SETUP.md](SETUP.md) - Initial setup procedures
- [QNAP/AUDIOBOOK_SETUP.md](../qnap/docs/AUDIOBOOK_SETUP.md) - QNAP audiobook setup