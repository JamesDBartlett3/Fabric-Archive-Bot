# Error Handling and Logging Guide

## Overview

Fabric Archive Bot v2.0 includes a comprehensive error handling and logging framework that provides:

- **Structured Logging**: Consistent log format with timestamps, levels, and operation tracking
- **File Logging**: Optional persistent logs with configurable retention
- **Error Tracking**: Automatic counting and categorization of errors, warnings, and successes
- **Operation Metrics**: Detailed tracking of operation duration and results
- **Session Summaries**: JSON export of complete session statistics
- **Retry Logic**: Automatic retry with exponential backoff for transient failures

## Configuration

### Basic Logging Setup

Add the `LoggingSettings` section to your `FabricArchiveBot_Config.json`:

```json
{
  "LoggingSettings": {
    "LogLevel": "Info",
    "EnableFileLogging": true,
    "LogDirectory": "%TEMP%\\FabricArchiveBot\\Logs",
    "RetainLogDays": 30
  }
}
```

### Configuration Options

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `LogLevel` | string | `"Info"` | Minimum log level to output: `Verbose`, `Info`, `Warning`, `Error` |
| `EnableFileLogging` | boolean | `false` | Enable writing logs to files |
| `LogDirectory` | string | `""` | Directory for log files (supports environment variables) |
| `RetainLogDays` | integer | `30` | Days to retain old log files (future feature) |

### Log Levels

The logging framework supports four hierarchical log levels:

1. **Verbose** - Detailed diagnostic information for troubleshooting
2. **Info** - General informational messages about operations
3. **Warning** - Non-critical issues that don't stop execution
4. **Error** - Critical failures that stop operations

When you set a log level, all messages at that level and higher will be displayed. For example:

- `LogLevel: "Verbose"` → Shows everything
- `LogLevel: "Info"` → Shows Info, Warning, Error
- `LogLevel: "Warning"` → Shows Warning, Error
- `LogLevel: "Error"` → Shows only Errors

## Log File Format

### Console Output

```text
2025-12-04 14:32:15 [INFO]    Logging initialized (SessionId: a1b2c3d4-e5f6-...)
2025-12-04 14:32:16 [INFO]    Created target folder: .\Workspaces\2025\12\04
2025-12-04 14:32:17 [VERBOSE] Executing Get-FabricItem-workspace123
2025-12-04 14:32:18 [WARNING] Rate limit encountered. Waiting 30 seconds...
2025-12-04 14:32:50 [SUCCESS] Completed operation: Export-Item in 1.23s
```

### Log File Structure

Log files are created with timestamps in the filename:

```
FabricArchiveBot_20251204_143215.log
```

Each file begins with a session header:

```text
================================================================================
Fabric Archive Bot - Session Log
================================================================================
Session ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
Start Time: 2025-12-04 14:32:15
Log Level:  Info
================================================================================
```

## Using Logging Functions

### Write-FABLog

Core logging function for custom messages:

```powershell
# Basic usage
Write-FABLog -Level Info -Message "Starting export process"

# With operation tracking
Write-FABLog -Level Warning -Message "Rate limit encountered" `
  -Operation "ExportItems" `
  -Details @{ RetryCount = 3; DelaySeconds = 60 }

# Suppress console output
Write-FABLog -Level Verbose -Message "Detailed debug info" -NoConsole

# Suppress file logging
Write-FABLog -Level Info -Message "Console-only message" -NoFileLog
```

### Start-FABOperation / Complete-FABOperation

Track operations with automatic timing and metrics:

```powershell
# Start tracking an operation
$operation = Start-FABOperation -OperationName "ExportWorkspace" `
  -Parameters @{
    WorkspaceId = "abc123"
    ItemCount   = 25
  }

try {
  # Do work here
  $result = Export-FABFabricItemsAdvanced -Config $config
  
  # Mark as successful
  Complete-FABOperation -Operation $operation -Success -Result $result
}
catch {
  # Mark as failed
  Complete-FABOperation -Operation $operation `
    -ErrorMessage $_.Exception.Message
  throw
}
```

### Get-FABLogSummary

Retrieve current session statistics:

```powershell
$summary = Get-FABLogSummary

Write-Host "Session Duration: $($summary.SessionDuration)"
Write-Host "Total Errors: $($summary.ErrorCount)"
Write-Host "Total Warnings: $($summary.WarningCount)"
Write-Host "Success Count: $($summary.SuccessCount)"
Write-Host "Failure Count: $($summary.FailureCount)"
Write-Host "Operations Tracked: $($summary.TotalOperations)"
```

### Export-FABLogSummary

Export complete session report to JSON:

```powershell
# Export to auto-generated path
$summaryPath = Export-FABLogSummary

# Export to specific path
$summaryPath = Export-FABLogSummary -OutputPath "C:\Reports\session_summary.json"
```

The exported JSON includes:

```json
{
  "SessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "SessionStart": "2025-12-04T14:32:15",
  "SessionDuration": "00:45:33",
  "LogLevel": "Info",
  "LogFilePath": "C:\\Temp\\FabricArchiveBot\\Logs\\FabricArchiveBot_20251204_143215.log",
  "ErrorCount": 2,
  "WarningCount": 5,
  "SuccessCount": 47,
  "FailureCount": 2,
  "TotalOperations": 52,
  "Operations": [
    {
      "OperationId": "op-guid-1",
      "OperationName": "ExportWorkspace",
      "StartTime": "2025-12-04T14:32:20",
      "EndTime": "2025-12-04T14:35:45",
      "Duration": "00:03:25",
      "Status": "Completed",
      "Parameters": {
        "WorkspaceId": "abc123",
        "ItemCount": 25
      },
      "Result": { },
      "Error": null
    }
  ]
}
```

## Error Handling

### Automatic Retry Logic

The framework includes built-in retry logic for common failure scenarios:

#### Rate Limiting (429 errors)

```powershell
# Automatically retries with exponential backoff
Invoke-FABRateLimitedOperation -Operation {
  Get-FABFabricItemsByWorkspace -WorkspaceId $id
} -Config $config -OperationName "GetItems"
```

Configuration for retry behavior:

```json
{
  "FabricPSPBIPSettings": {
    "RateLimitSettings": {
      "EnableRetry": true,
      "MaxRetries": 3,
      "RetryDelaySeconds": 30,
      "BackoffMultiplier": 2
    }
  }
}
```

This configuration results in retry delays of:
- Retry 1: 30 seconds
- Retry 2: 60 seconds (30 * 2^1)
- Retry 3: 120 seconds (30 * 2^2)

#### Transient Failures

The following errors automatically trigger retries:

- HTTP 503 (Service Unavailable)
- HTTP 502 (Bad Gateway)
- Timeout errors
- Connection errors

### Error Categories

Errors are categorized for better diagnostics:

| Category | Description | Retryable |
|----------|-------------|-----------|
| `RateLimit` | API rate limit exceeded (429) | Yes |
| `Transient` | Temporary service issues (503, 502, timeout) | Yes |
| `NonRetryable` | Permanent errors (400, 401, 404) | No |

### Best Practices

1. **Always use try/catch blocks** around operations that can fail:

```powershell
try {
  $items = Get-FABFabricItemsByWorkspace -WorkspaceId $id
}
catch {
  Write-FABLog -Level Error -Message "Failed to get items: $($_.Exception.Message)" `
    -Operation "GetItems" `
    -Details @{ WorkspaceId = $id }
  throw
}
```

2. **Track long-running operations** with Start/Complete-FABOperation:

```powershell
$op = Start-FABOperation -OperationName "LongRunningTask"
try {
  # Do work
  Complete-FABOperation -Operation $op -Success
}
catch {
  Complete-FABOperation -Operation $op -ErrorMessage $_.Exception.Message
  throw
}
```

3. **Use appropriate log levels**:
   - `Verbose` for detailed diagnostics
   - `Info` for normal operations
   - `Warning` for recoverable issues
   - `Error` for failures

4. **Include context in error messages**:

```powershell
Write-FABLog -Level Error `
  -Message "Failed to export item" `
  -Operation "ExportItem" `
  -Details @{
    WorkspaceId = $workspaceId
    ItemId      = $itemId
    ItemType    = $itemType
    ErrorCode   = $_.Exception.HResult
  }
```

## Monitoring and Troubleshooting

### Real-time Monitoring

Use different log levels for different scenarios:

```powershell
# Development/debugging - see everything
$config.LoggingSettings.LogLevel = "Verbose"

# Production - normal operations
$config.LoggingSettings.LogLevel = "Info"

# Quiet mode - only issues
$config.LoggingSettings.LogLevel = "Warning"
```

### Post-Execution Analysis

After a run completes, examine:

1. **Console output** for real-time status
2. **Log file** for complete operation history
3. **Session summary JSON** for statistics and metrics

```powershell
# Load and analyze session summary
$summary = Get-Content "FabricArchiveBot_Summary_20251204_151500.json" | ConvertFrom-Json

# Find failed operations
$failures = $summary.Operations | Where-Object { $_.Status -eq 'Failed' }

# Calculate success rate
$successRate = ($summary.SuccessCount / $summary.TotalOperations) * 100
Write-Host "Success Rate: $([math]::Round($successRate, 2))%"
```

### Common Issues and Solutions

#### High Error Count

Check the session summary for error patterns:

```powershell
$summary = Get-FABLogSummary
$summary.Operations | Where-Object { $_.Status -eq 'Failed' } | 
  Group-Object { $_.Error } | 
  Sort-Object Count -Descending
```

#### Rate Limiting Issues

If you see frequent rate limit warnings:

1. Reduce parallel processing throttle limit
2. Increase retry delays
3. Add delays between operations

```json
{
  "FabricPSPBIPSettings": {
    "ThrottleLimit": 4,
    "RateLimitSettings": {
      "RetryDelaySeconds": 60,
      "BackoffMultiplier": 3
    }
  }
}
```

#### Missing Operations

If operations aren't being tracked:

1. Ensure `Initialize-FABLogging` is called at startup
2. Verify log level isn't filtering out messages
3. Check that operations use `Start-FABOperation`/`Complete-FABOperation`

## Integration Examples

### Custom Script Integration

```powershell
# Import the module
Import-Module ".\modules\FabricArchiveBotCore.psm1"

# Initialize logging
Initialize-FABLogging -Config $config

# Your custom operations
$op = Start-FABOperation -OperationName "CustomTask"
try {
  Write-FABLog -Level Info -Message "Starting custom processing"
  
  # Your code here
  
  Write-FABLog -Level Success -Message "Custom processing completed"
  Complete-FABOperation -Operation $op -Success
}
catch {
  Write-FABLog -Level Error -Message "Custom processing failed: $($_.Exception.Message)"
  Complete-FABOperation -Operation $op -ErrorMessage $_.Exception.Message
}
finally {
  # Export summary at the end
  Export-FABLogSummary
}
```

### Scheduled Task Integration

For scheduled tasks, configure file logging to capture unattended runs:

```json
{
  "LoggingSettings": {
    "LogLevel": "Info",
    "EnableFileLogging": true,
    "LogDirectory": "C:\\FabricArchiveBot\\Logs",
    "RetainLogDays": 30
  }
}
```

Then review log files periodically:

```powershell
# Find recent failures
Get-ChildItem "C:\FabricArchiveBot\Logs\*.log" | 
  Select-String "\[ERROR\]" -Context 2, 2
```

## Performance Considerations

### Log Level Impact

- **Verbose**: Highest overhead, use only for debugging
- **Info**: Moderate overhead, good for production
- **Warning/Error**: Minimal overhead, fastest performance

### File Logging Impact

File logging adds minimal overhead but:

- Ensure log directory has sufficient disk space
- Consider log rotation for long-running deployments
- Use fast storage (SSD) for high-volume logging

### Operation Tracking

Operation tracking with `Start-FABOperation`/`Complete-FABOperation`:

- Adds negligible overhead (< 1ms per operation)
- Provides valuable metrics for optimization
- Recommended for all significant operations

## Future Enhancements

Planned improvements for logging and error handling:

- [ ] Automatic log file rotation and cleanup
- [ ] Real-time log streaming to external systems
- [ ] Error trend analysis and alerting
- [ ] Integration with Azure Monitor / Application Insights
- [ ] Configurable log retention policies
- [ ] Compressed log archive generation

## Related Documentation

- [API Rate Limiting Guide](api-rate-limiting-guide.md)
- [Parallel Processing Guide](parallel-processing-guide.md)
- [Workspace Filtering Guide](workspace-filtering-guide.md)
- [Filtering Guide](filtering-guide.md)

## Support

For issues or questions about error handling and logging:

1. Check the log files for detailed error messages
2. Review the session summary JSON for patterns
3. Open an issue on [GitHub](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues)
4. Include relevant log excerpts (redact sensitive information)

---

*Last Updated: 2025-12-04*
