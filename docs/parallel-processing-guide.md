# Fabric Archive Bot v2.0 - Parallel Processing Guide

## Overview

Fabric Archive Bot v2.0 includes enhanced parallel processing capabilities that can significantly speed up exports by processing multiple **items** simultaneously across all workspaces, rather than processing workspaces one at a time.

## Key Features

### 🚀 **Item-Level Parallel Processing (Default)**
- Parallel processing is **enabled by default** in v2.0
- Processes individual items in parallel across all workspaces
- Automatically detects if PowerShell 7+ is available
- Falls back to sequential processing on PowerShell 5.x

### 🎯 **Smart Resource Utilization**
- Collects all workspace info and item inventories first
- Creates a flattened job queue of all items across workspaces
- Threads can seamlessly move between workspaces as items complete
- Maximizes CPU and network utilization

### ⚙️ **Smart Throttle Limit Detection**
- Automatically detects the number of logical CPU cores
- Uses CPU core count as the default throttle limit (capped at 12 for safety)
- Balances performance with system stability and API rate limits

### 🔄 **Flexible Configuration**
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
- Multiple items across workspaces (10+ items total)
- PowerShell 7+
- Systems with 4+ CPU cores
- Fast network connections
- Sufficient system memory (items are processed individually)

❌ **Not recommended for:**
- Very few items to export (< 5 items)
- PowerShell 5.x
- Low-memory systems
- Slow network connections
- High system load scenarios

### Optimal Throttle Limits

| System Type | Suggested Throttle Limit | Reasoning |
|------------|-------------------------|-----------|
| Desktop (4-8 cores) | 4-6 | Balance between speed and system responsiveness |
| Workstation (8-16 cores) | 6-10 | Maximize throughput while respecting API limits |
| Server (16+ cores) | 8-12 | Optimal for high-throughput scenarios |
| Laptop/Limited RAM | 2-4 | Conservative to avoid overwhelming system |

### Processing Architecture

The new item-level parallel processing works as follows:

1. **Discovery Phase**: All workspaces are processed sequentially to gather:
   - Workspace information
   - Complete item inventories
   - Folder structure creation

2. **Item Processing Phase**: All items across all workspaces are processed in parallel:
   - Items are queued in a flattened job list
   - Threads seamlessly move between workspaces
   - Real-time progress tracking per item and workspace

3. **Metadata Generation**: After all items are processed, workspace metadata is generated

This approach ensures:
- **Better Resource Utilization**: No idle threads waiting for workspaces
- **Consistent Progress**: Even distribution of work across threads
- **Optimal Performance**: Maximum parallel efficiency regardless of workspace size distribution

## Monitoring and Troubleshooting

### Performance Indicators

The script provides real-time feedback showing the new item-level processing:

```
Parallel processing: Enabled
Throttle limit: 6
Gathering workspace information and item inventories...
  - Gathering info for workspace: xxx-xxx-xxx
    Found 15 exportable items in Sales Analytics
  - Gathering info for workspace: yyy-yyy-yyy
    Found 8 exportable items in Marketing Dashboard
Total items to export: 23 across 2 workspaces
Processing 23 items in parallel across all workspaces...
Exporting item 'Sales Report Q3' from workspace 'Sales Analytics' (Thread: 3)
Exporting item 'Customer Dashboard' from workspace 'Marketing Dashboard' (Thread: 5)
  ✓ Completed: 'Sales Report Q3' (Thread: 3)
  ✓ Completed: 'Customer Dashboard' (Thread: 5)
Parallel item processing completed. Generating workspace metadata...
  ✓ Metadata generated for: Sales Analytics
  ✓ Metadata generated for: Marketing Dashboard
```

### Common Issues

**Issue: "Parallel processing requires PowerShell 7+"**
- **Solution**: Upgrade to PowerShell 7+ or disable parallel processing

**Issue: System becomes unresponsive during item processing**
- **Solution**: Reduce throttle limit (fewer concurrent item exports)

**Issue: Memory issues with many items**
- **Solution**: Reduce throttle limit or process fewer workspaces at once

**Issue: API rate limiting during item export**
- **Solution**: Built-in rate limiting handles this, but you can reduce throttle limit for extra safety

**Issue: Items from the same workspace being processed by different threads**
- **Expected Behavior**: This is normal and optimal - threads work across workspaces for maximum efficiency

## Advanced Examples

### Development/Testing
```powershell
# Conservative parallel processing for testing (fewer concurrent items)
.\Start-FabricArchiveBot.ps1 -ThrottleLimit 2 -WhatIf
```

### Production High-Performance
```powershell
# Maximum performance with optimal item-level parallelism
.\Start-FabricArchiveBot.ps1 -UseParallelProcessing -ThrottleLimit 8
```

### Large Tenant Optimization
```powershell
# High-throughput processing for tenants with many items
.\Start-FabricArchiveBot.ps1 -ThrottleLimit 12
```

### Legacy System Compatibility
```powershell
# Force sequential processing (one item at a time)
.\Start-FabricArchiveBot.ps1 -UseParallelProcessing:$false
```

## Performance Benefits

The new item-level parallel processing provides significant improvements:

- **Better Thread Utilization**: No threads waiting for workspace completion
- **Predictable Performance**: Processing time scales with total item count, not workspace distribution
- **Flexible Resource Usage**: Threads seamlessly work across workspace boundaries
- **Improved Monitoring**: Real-time progress tracking per item and workspace
- **Optimal API Usage**: Maximizes throughput while respecting rate limits

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
