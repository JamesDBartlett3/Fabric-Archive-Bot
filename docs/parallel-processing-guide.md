# Fabric Archive Bot v2.0 - Parallel Processing Guide

## Overview

Fabric Archive Bot v2.0 includes enhanced parallel processing capabilities that can significantly speed up workspace exports by processing multiple workspaces simultaneously.

## Key Features

### 🚀 **Automatic Parallel Processing (Default)**
- Parallel processing is **enabled by default** in v2.0
- Automatically detects if PowerShell 7+ is available
- Falls back to sequential processing on PowerShell 5.x

### 🎯 **Smart Throttle Limit Detection**
- Automatically detects the number of logical CPU cores
- Uses CPU core count as the default throttle limit (capped at 10 for safety)
- Balances performance with system stability

### ⚙️ **Flexible Configuration**
Configure parallel processing in multiple ways:

1. **Runtime Parameters** (highest priority)
2. **Configuration File Settings**
3. **Automatic Detection** (fallback)

## Configuration Options

### Runtime Parameters

```powershell
# Enable parallel processing with default throttle limit (CPU cores)
.\Start-FabricArchiveBot.ps1 -UseParallelProcessing

# Custom throttle limit
.\Start-FabricArchiveBot.ps1 -UseParallelProcessing -ThrottleLimit 4

# Disable parallel processing (force sequential)
.\Start-FabricArchiveBot.ps1 -UseParallelProcessing:$false
```

### Configuration File

Add to your `FabricArchiveBot_Config.json`:

```json
{
  "FabricToolsSettings": {
    "ParallelProcessing": true,
    "ThrottleLimit": 6
  }
}
```

**ThrottleLimit Values:**
- `0` = Auto-detect (uses CPU core count, default)
- `1` = Sequential processing (same as disabled)
- `2-20` = Custom throttle limit

## Performance Considerations

### When to Use Parallel Processing

✅ **Recommended for:**
- Multiple workspaces (3+ workspaces)
- PowerShell 7+
- Systems with 4+ CPU cores
- Fast network connections
- Sufficient system memory

❌ **Not recommended for:**
- Single workspace exports
- PowerShell 5.x
- Low-memory systems
- Slow network connections
- High system load scenarios

### Optimal Throttle Limits

| System Type | Suggested Throttle Limit |
|------------|-------------------------|
| Desktop (4-8 cores) | 4-6 |
| Workstation (8-16 cores) | 6-10 |
| Server (16+ cores) | 8-12 |
| Laptop/Limited RAM | 2-4 |

## Monitoring and Troubleshooting

### Performance Indicators

The script provides real-time feedback:

```
Parallel processing: Enabled
Throttle limit: 6
Processing workspaces in parallel...
Processing workspace: xxx-xxx-xxx (Thread: 5)
Processing workspace: yyy-yyy-yyy (Thread: 7)
```

### Common Issues

**Issue: "Parallel processing requires PowerShell 7+"**
- **Solution**: Upgrade to PowerShell 7+ or disable parallel processing

**Issue: System becomes unresponsive**
- **Solution**: Reduce throttle limit or disable parallel processing

**Issue: Memory issues with large workspaces**
- **Solution**: Reduce throttle limit or process workspaces sequentially

**Issue: API rate limiting**
- **Solution**: Reduce throttle limit to stay within API limits

## Advanced Examples

### Development/Testing
```powershell
# Conservative parallel processing for testing
.\Start-FabricArchiveBot.ps1 -ThrottleLimit 2 -WhatIf
```

### Production High-Performance
```powershell
# Maximum performance with monitoring
.\Start-FabricArchiveBot.ps1 -UseParallelProcessing -ThrottleLimit 8
```

### Legacy System Compatibility
```powershell
# Force sequential processing
.\Start-FabricArchiveBot.ps1 -UseParallelProcessing:$false
```

## Best Practices

1. **Start Conservative**: Begin with lower throttle limits and increase based on performance
2. **Monitor Resources**: Watch CPU, memory, and network usage during exports
3. **Consider API Limits**: Microsoft Fabric APIs have rate limits - don't exceed them
4. **Test First**: Use `-WhatIf` parameter to test configuration before actual exports
5. **Environment-Specific**: Adjust settings based on your specific environment and requirements

## Migration from v1.0

The migration helper automatically enables parallel processing in v2.0 configs:

```powershell
.\helpers\Migrate-ToV2.ps1
```

Your migrated configuration will include:
```json
{
  "FabricToolsSettings": {
    "ParallelProcessing": true,
    "ThrottleLimit": 0
  }
}
```

This ensures optimal performance while maintaining compatibility with your existing setup.
