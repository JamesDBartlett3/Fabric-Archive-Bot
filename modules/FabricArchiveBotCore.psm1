<#
.SYNOPSIS
Core module for Fabric Archive Bot v2.0 using FabricPS-PBIP

.DESCRIPTION
This module provides enhanced archiving capabilities using the FabricPS-PBIP PowerShell module
while maintaining backward compatibility with v1.0 functionality.
#>

#region Module Variables

# Global logging state
[hashtable]$Script:FABLogContext = @{
  LogLevel       = 'Info'
  LogToFile      = $false
  LogFilePath    = $null
  SessionId      = [guid]::NewGuid().ToString()
  SessionStart   = Get-Date
  ErrorCount     = 0
  WarningCount   = 0
  SuccessCount   = 0
  FailureCount   = 0
  Operations     = [System.Collections.ArrayList]::new()
}

#endregion

#region Private Functions

#region Logging Functions

function Initialize-FABLogging {
  <#
  .SYNOPSIS
  Initializes the logging subsystem with configuration
  
  .DESCRIPTION
  Sets up logging based on configuration, including log level, file logging, and session tracking
  #>
  [CmdletBinding()]
  param(
    [Parameter()]
    [PSCustomObject]$Config
  )
  
  try {
    # Reset session state
    $Script:FABLogContext.SessionId = [guid]::NewGuid().ToString()
    $Script:FABLogContext.SessionStart = Get-Date
    $Script:FABLogContext.ErrorCount = 0
    $Script:FABLogContext.WarningCount = 0
    $Script:FABLogContext.SuccessCount = 0
    $Script:FABLogContext.FailureCount = 0
    $Script:FABLogContext.Operations.Clear()
    
    # Apply configuration
    if ($Config -and $Config.PSObject.Properties['LoggingSettings']) {
      [PSCustomObject]$loggingSettings = $Config.LoggingSettings
      
      # Set log level
      if ($loggingSettings.PSObject.Properties['LogLevel']) {
        [string]$logLevel = $loggingSettings.LogLevel
        if ($logLevel -in @('Verbose', 'Info', 'Warning', 'Error')) {
          $Script:FABLogContext.LogLevel = $logLevel
        }
      }
      
      # Configure file logging
      if ($loggingSettings.PSObject.Properties['EnableFileLogging'] -and $loggingSettings.EnableFileLogging) {
        $Script:FABLogContext.LogToFile = $true
        
        if ($loggingSettings.PSObject.Properties['LogDirectory']) {
          [string]$logDir = $loggingSettings.LogDirectory
          
          # Expand environment variables
          $logDir = [System.Environment]::ExpandEnvironmentVariables($logDir)
          
          # Create log directory if it doesn't exist
          if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
          }
          
          # Generate log file name with timestamp
          [string]$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
          [string]$logFileName = "FabricArchiveBot_$timestamp.log"
          $Script:FABLogContext.LogFilePath = Join-Path -Path $logDir -ChildPath $logFileName
          
          # Write session header to log file
          $sessionHeader = @"
================================================================================
Fabric Archive Bot - Session Log
================================================================================
Session ID: $($Script:FABLogContext.SessionId)
Start Time: $($Script:FABLogContext.SessionStart.ToString('yyyy-MM-dd HH:mm:ss'))
Log Level:  $($Script:FABLogContext.LogLevel)
================================================================================

"@
          Add-Content -Path $Script:FABLogContext.LogFilePath -Value $sessionHeader
        }
      }
    }
    
    Write-FABLog -Level Info -Message "Logging initialized (SessionId: $($Script:FABLogContext.SessionId))" -NoFileLog
  }
  catch {
    Write-Warning "Failed to initialize logging: $($_.Exception.Message)"
  }
}

function Write-FABLog {
  <#
  .SYNOPSIS
  Writes a log message with the specified level
  
  .DESCRIPTION
  Core logging function that handles console output, file logging, and message formatting
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Verbose', 'Info', 'Warning', 'Error', 'Success')]
    [string]$Level,
    
    [Parameter(Mandatory = $true)]
    [string]$Message,
    
    [Parameter()]
    [string]$Operation = $null,
    
    [Parameter()]
    [hashtable]$Details = @{},
    
    [Parameter()]
    [switch]$NoConsole,
    
    [Parameter()]
    [switch]$NoFileLog
  )
  
  # Check if this log level should be output based on configured level
  [string[]]$logLevelHierarchy = @('Verbose', 'Info', 'Warning', 'Error')
  [int]$currentLevelIndex = $logLevelHierarchy.IndexOf($Script:FABLogContext.LogLevel)
  [int]$messageLevelIndex = $logLevelHierarchy.IndexOf($Level)
  
  # Special handling for Success - always show unless log level is Error
  [bool]$shouldOutput = if ($Level -eq 'Success') {
    $Script:FABLogContext.LogLevel -ne 'Error'
  }
  else {
    $messageLevelIndex -ge $currentLevelIndex
  }
  
  if (-not $shouldOutput) {
    return
  }
  
  # Format timestamp
  [string]$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  
  # Format message with level indicator
  [string]$levelPrefix = switch ($Level) {
    'Verbose' { '[VERBOSE]' }
    'Info' { '[INFO]   ' }
    'Warning' { '[WARNING]' }
    'Error' { '[ERROR]  ' }
    'Success' { '[SUCCESS]' }
  }
  
  [string]$formattedMessage = "$timestamp $levelPrefix $Message"
  
  # Console output (unless suppressed)
  if (-not $NoConsole) {
    $consoleColor = switch ($Level) {
      'Verbose' { 'Gray' }
      'Info' { 'White' }
      'Warning' { 'Yellow' }
      'Error' { 'Red' }
      'Success' { 'Green' }
    }
    
    Write-Host $formattedMessage -ForegroundColor $consoleColor
  }
  
  # File logging (if enabled and not suppressed)
  if ($Script:FABLogContext.LogToFile -and -not $NoFileLog -and $Script:FABLogContext.LogFilePath) {
    try {
      Add-Content -Path $Script:FABLogContext.LogFilePath -Value $formattedMessage
      
      # Add details if provided
      if ($Details.Count -gt 0) {
        [string]$detailsJson = $Details | ConvertTo-Json -Compress
        Add-Content -Path $Script:FABLogContext.LogFilePath -Value "  Details: $detailsJson"
      }
    }
    catch {
      # Avoid recursive logging errors
      Write-Warning "Failed to write to log file: $($_.Exception.Message)"
    }
  }
  
  # Track operation metrics
  if ($Operation) {
    [PSCustomObject]$operationRecord = [PSCustomObject]@{
      Timestamp = Get-Date
      Operation = $Operation
      Level     = $Level
      Message   = $Message
      Details   = $Details
    }
    $Script:FABLogContext.Operations.Add($operationRecord) | Out-Null
  }
  
  # Update counters
  switch ($Level) {
    'Error' { $Script:FABLogContext.ErrorCount++ }
    'Warning' { $Script:FABLogContext.WarningCount++ }
    'Success' { $Script:FABLogContext.SuccessCount++ }
  }
}

function Start-FABOperation {
  <#
  .SYNOPSIS
  Marks the start of a tracked operation
  
  .DESCRIPTION
  Creates an operation tracking context that can be used to measure duration and capture results
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$OperationName,
    
    [Parameter()]
    [hashtable]$Parameters = @{}
  )
  
  [PSCustomObject]$operation = [PSCustomObject]@{
    OperationId   = [guid]::NewGuid().ToString()
    OperationName = $OperationName
    StartTime     = Get-Date
    EndTime       = $null
    Duration      = $null
    Status        = 'Running'
    Parameters    = $Parameters
    Result        = $null
    Error         = $null
  }
  
  Write-FABLog -Level Verbose -Message "Starting operation: $OperationName" -Operation $OperationName -Details $Parameters
  
  return $operation
}

function Complete-FABOperation {
  <#
  .SYNOPSIS
  Marks the completion of a tracked operation
  
  .DESCRIPTION
  Finalizes an operation tracking context with success/failure status and duration
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Operation,
    
    [Parameter()]
    [switch]$Success,
    
    [Parameter()]
    [object]$Result = $null,
    
    [Parameter()]
    [string]$ErrorMessage = $null
  )
  
  $Operation.EndTime = Get-Date
  $Operation.Duration = $Operation.EndTime - $Operation.StartTime
  $Operation.Status = if ($Success) { 'Completed' } else { 'Failed' }
  $Operation.Result = $Result
  $Operation.Error = $ErrorMessage
  
  [hashtable]$details = @{
    Duration = $Operation.Duration.TotalSeconds
  }
  
  if ($Success) {
    Write-FABLog -Level Success -Message "Completed operation: $($Operation.OperationName) in $($Operation.Duration.TotalSeconds.ToString('F2'))s" -Operation $Operation.OperationName -Details $details
    $Script:FABLogContext.SuccessCount++
  }
  else {
    Write-FABLog -Level Error -Message "Failed operation: $($Operation.OperationName) - $ErrorMessage" -Operation $Operation.OperationName -Details $details
    $Script:FABLogContext.FailureCount++
  }
  
  $Script:FABLogContext.Operations.Add($Operation) | Out-Null
}

function Get-FABLogSummary {
  <#
  .SYNOPSIS
  Retrieves a summary of the current logging session
  
  .DESCRIPTION
  Returns statistics and metrics about the current session including error counts and operation history
  #>
  [CmdletBinding()]
  param()
  
  [timespan]$sessionDuration = (Get-Date) - $Script:FABLogContext.SessionStart
  
  [PSCustomObject]$summary = [PSCustomObject]@{
    SessionId      = $Script:FABLogContext.SessionId
    SessionStart   = $Script:FABLogContext.SessionStart
    SessionDuration = $sessionDuration
    LogLevel       = $Script:FABLogContext.LogLevel
    LogFilePath    = $Script:FABLogContext.LogFilePath
    ErrorCount     = $Script:FABLogContext.ErrorCount
    WarningCount   = $Script:FABLogContext.WarningCount
    SuccessCount   = $Script:FABLogContext.SuccessCount
    FailureCount   = $Script:FABLogContext.FailureCount
    TotalOperations = $Script:FABLogContext.Operations.Count
    Operations     = $Script:FABLogContext.Operations
  }
  
  return $summary
}

function Export-FABLogSummary {
  <#
  .SYNOPSIS
  Exports a detailed session summary to a JSON file
  
  .DESCRIPTION
  Creates a comprehensive report of the session including all operations, errors, and metrics
  #>
  [CmdletBinding()]
  param(
    [Parameter()]
    [string]$OutputPath = $null
  )
  
  [PSCustomObject]$summary = Get-FABLogSummary
  
  # Generate output path if not provided
  if (-not $OutputPath) {
    if ($Script:FABLogContext.LogFilePath) {
      [string]$logDir = Split-Path -Path $Script:FABLogContext.LogFilePath -Parent
      [string]$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
      $OutputPath = Join-Path -Path $logDir -ChildPath "FabricArchiveBot_Summary_$timestamp.json"
    }
    else {
      [string]$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
      $OutputPath = "FabricArchiveBot_Summary_$timestamp.json"
    }
  }
  
  try {
    $summary | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath
    Write-FABLog -Level Info -Message "Session summary exported to: $OutputPath"
    return $OutputPath
  }
  catch {
    Write-FABLog -Level Error -Message "Failed to export session summary: $($_.Exception.Message)"
    throw
  }
}

#endregion Logging Functions

function Invoke-FABRateLimitedOperation {
  <#
  .SYNOPSIS
  Executes operations with built-in rate limiting and retry logic
  
  .DESCRIPTION
  Wraps FabricPS-PBIP operations with enhanced rate limiting handling, retry logic, and monitoring
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock]$Operation,
    
    [Parameter()]
    [PSCustomObject]$Config,
    
    [Parameter()]
    [string]$OperationName = "FabricOperation",
    
    [Parameter()]
    [int]$MaxRetries = 3,
    
    [Parameter()]
    [int]$BaseDelaySeconds = 30
  )
  
  [int]$retryCount = 0
  [int]$maxRetries = if ($Config -and $Config.PSObject.Properties['FabricPSPBIPSettings'] -and $Config.FabricPSPBIPSettings.PSObject.Properties['RateLimitSettings'] -and $Config.FabricPSPBIPSettings.RateLimitSettings.MaxRetries) {
    $Config.FabricPSPBIPSettings.RateLimitSettings.MaxRetries
  }
  else { $MaxRetries }
  
  [int]$baseDelay = if ($Config -and $Config.PSObject.Properties['FabricPSPBIPSettings'] -and $Config.FabricPSPBIPSettings.PSObject.Properties['RateLimitSettings'] -and $Config.FabricPSPBIPSettings.RateLimitSettings.RetryDelaySeconds) {
    $Config.FabricPSPBIPSettings.RateLimitSettings.RetryDelaySeconds
  }
  else { $BaseDelaySeconds }
  
  [int]$backoffMultiplier = if ($Config -and $Config.PSObject.Properties['FabricPSPBIPSettings'] -and $Config.FabricPSPBIPSettings.PSObject.Properties['RateLimitSettings'] -and $Config.FabricPSPBIPSettings.RateLimitSettings.BackoffMultiplier) {
    $Config.FabricPSPBIPSettings.RateLimitSettings.BackoffMultiplier
  }
  else { 2 }
  
  do {
    try {
      [string]$attemptMessage = if ($retryCount -gt 0) { " (Retry $retryCount/$maxRetries)" } else { "" }
      Write-FABLog -Level Verbose -Message "Executing $OperationName$attemptMessage"
      return & $Operation
    }
    catch {
      $retryCount++
      [string]$errorMessage = $_.Exception.Message
      
      # Check if this is a rate limiting error (429)
      if ($errorMessage -match "429|rate.limit|throttl" -or $errorMessage -match "Too Many Requests") {
        if ($retryCount -le $maxRetries) {
          [int]$delaySeconds = $baseDelay * [Math]::Pow($backoffMultiplier, $retryCount - 1)
          Write-FABLog -Level Warning -Message "Rate limit encountered for $OperationName. Waiting $delaySeconds seconds before retry $retryCount/$maxRetries" -Operation $OperationName -Details @{ ErrorType = 'RateLimit'; RetryCount = $retryCount; DelaySeconds = $delaySeconds }
          Start-Sleep -Seconds $delaySeconds
          continue
        }
        else {
          Write-FABLog -Level Error -Message "Rate limit exceeded for $OperationName after $maxRetries retries. Operation failed." -Operation $OperationName -Details @{ ErrorType = 'RateLimit'; MaxRetries = $maxRetries }
          throw
        }
      }
      # Check for other retryable errors
      elseif ($errorMessage -match "503|502|timeout|connection" -and $retryCount -le $maxRetries) {
        [int]$delaySeconds = $baseDelay
        Write-FABLog -Level Warning -Message "Transient error for $OperationName. Waiting $delaySeconds seconds before retry $retryCount/$maxRetries" -Operation $OperationName -Details @{ ErrorType = 'Transient'; ErrorMessage = $errorMessage; RetryCount = $retryCount; DelaySeconds = $delaySeconds }
        Start-Sleep -Seconds $delaySeconds
        continue
      }
      else {
        # Non-retryable error or max retries exceeded
        Write-FABLog -Level Error -Message "Non-retryable error for $OperationName or max retries exceeded: $errorMessage" -Operation $OperationName -Details @{ ErrorType = 'NonRetryable'; ErrorMessage = $errorMessage; RetryCount = $retryCount }
        throw
      }
    }
  } while ($retryCount -le $maxRetries)
}

function Get-FABOptimalThrottleLimit {
  <#
  .SYNOPSIS
  Determines the optimal throttle limit for parallel processing
  
  .DESCRIPTION
  Calculates the best throttle limit based on system CPU cores and user configuration
  #>
  [CmdletBinding()]
  param(
    [Parameter()]
    [int]$OverrideThrottleLimit,
    
    [Parameter()]
    [PSCustomObject]$Config
  )
  
  # Get system logical processor count
  [int]$logicalProcessors = (Get-CimInstance -ClassName Win32_ComputerSystem).NumberOfLogicalProcessors
  
  # Determine throttle limit from various sources (priority order)
  if ($OverrideThrottleLimit -gt 0) {
    [int]$throttleLimit = $OverrideThrottleLimit
    Write-Host "Using runtime override throttle limit: $throttleLimit"
  }
  elseif ($Config.PSObject.Properties['FabricPSPBIPSettings'] -and $Config.FabricPSPBIPSettings.PSObject.Properties['ThrottleLimit'] -and $Config.FabricPSPBIPSettings.ThrottleLimit -gt 0) {
    [int]$throttleLimit = $Config.FabricPSPBIPSettings.ThrottleLimit
    Write-Host "Using config throttle limit: $throttleLimit"
  }
  else {
    # Default to logical processor count, but cap at reasonable maximum
    [int]$throttleLimit = [Math]::Min($logicalProcessors, 12)
    Write-Host "Using auto-detected throttle limit: $throttleLimit (based on $logicalProcessors logical processors)"
  }
  
  return $throttleLimit
}

function Test-FABFabricPSPBIPAvailability {
  [CmdletBinding()]
  param()
    
  try {
    # Check if FabricPS-PBIP module functions are available
    if (Get-Command -Name "Invoke-FabricAPIRequest" -ErrorAction SilentlyContinue) {
      return $true
    }
    
    # If not available, try to import it from the expected location
    [string]$moduleFileName = "FabricPS-PBIP.psm1"
    [string[]]$possiblePaths = @(
      (Join-Path -Path $PSScriptRoot -ChildPath "..\$moduleFileName"),
      (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath $moduleFileName)
    )
    
    foreach ($path in $possiblePaths) {
      if (Test-Path -Path $path) {
        Import-Module -Name $path -Force
        if (Get-Command -Name "Invoke-FabricAPIRequest" -ErrorAction SilentlyContinue) {
          return $true
        }
      }
    }
    
    Write-Warning "FabricPS-PBIP module not found or not properly loaded"
    return $false
  }
  catch {
    Write-Error "Failed to load FabricPS-PBIP module: $($_.Exception.Message)"
    return $false
  }
}

function Initialize-FABFabricConnection {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config
  )
    
  try {
    # Handle Az.Accounts module loading conflicts more aggressively
    Write-Host "Initializing Fabric connection..." -ForegroundColor Gray
    
    # Remove all Azure modules to clear conflicts
    Write-Host "Clearing Azure module conflicts..." -ForegroundColor Yellow
    $azModules = Get-Module -Name "Az.*"
    if ($azModules) {
      Write-Host "Removing existing Azure modules: $($azModules.Name -join ', ')" -ForegroundColor Yellow
      $azModules | Remove-Module -Force -ErrorAction SilentlyContinue
    }
    
    # Clear any loaded assemblies (best effort)
    try {
      [System.GC]::Collect()
      [System.GC]::WaitForPendingFinalizers()
    }
    catch {
      # GC operations might fail, but continue anyway
    }
    
    # Import Az.Accounts fresh
    Write-Host "Loading Az.Accounts module..." -ForegroundColor Gray
    try {
      Import-Module -Name "Az.Accounts" -Force -Global -ErrorAction Stop
      Write-Host "Az.Accounts module loaded successfully" -ForegroundColor Green
    }
    catch {
      Write-Warning "Failed to load Az.Accounts: $($_.Exception.Message)"
      Write-Host "Attempting alternative module loading strategy..." -ForegroundColor Yellow
      
      # Try loading with minimal scope
      try {
        Import-Module -Name "Az.Accounts" -Scope Global -ErrorAction Stop
        Write-Host "Az.Accounts loaded with alternative strategy" -ForegroundColor Green
      }
      catch {
        Write-Error "Could not load Az.Accounts module. Please restart PowerShell and try again."
        throw "Az.Accounts module loading failed: $($_.Exception.Message)"
      }
    }
    
    if ($Config.ServicePrincipal.AppId -and $Config.ServicePrincipal.AppSecret -and $Config.ServicePrincipal.TenantId) {
      # Use Service Principal authentication with FabricPS-PBIP
      Write-Host "Authenticating with Service Principal..." -ForegroundColor Gray
      Set-FabricAuthToken -servicePrincipalId $Config.ServicePrincipal.AppId -servicePrincipalSecret $Config.ServicePrincipal.AppSecret -tenantId $Config.ServicePrincipal.TenantId
    }
    else {
      # Use interactive authentication
      Write-Host "Using interactive authentication..." -ForegroundColor Gray
      Set-FabricAuthToken
    }
    
    Write-Host "Fabric connection established successfully" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Error "Failed to connect to Fabric: $($_.Exception.Message)"
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Restart PowerShell to clear all module conflicts" -ForegroundColor Yellow
    Write-Host "2. Run: Get-Module Az.* | Remove-Module -Force" -ForegroundColor Yellow
    Write-Host "3. Check for multiple Az module versions: Get-Module Az.* -ListAvailable" -ForegroundColor Yellow
    Write-Host "4. Consider uninstalling old Azure PowerShell modules" -ForegroundColor Yellow
    return $false
  }
}

function Get-FABFabricWorkspaceById {
  <#
  .SYNOPSIS
  Gets a specific workspace by ID using FabricPS-PBIP
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceId
  )
  
  try {
    [PSCustomObject]$workspace = Invoke-FabricAPIRequest -Uri "workspaces/$WorkspaceId" -Method Get
    return $workspace
  }
  catch {
    Write-Warning "Failed to get workspace $WorkspaceId : $($_.Exception.Message)"
    return $null
  }
}

function Get-FABFabricItemsByWorkspace {
  <#
  .SYNOPSIS
  Gets all items from a specific workspace using FabricPS-PBIP
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceId
  )
  
  try {
    [array]$items = Invoke-FabricAPIRequest -Uri "workspaces/$WorkspaceId/items" -Method Get
    return $items
  }
  catch {
    Write-Warning "Failed to get items from workspace $WorkspaceId : $($_.Exception.Message)"
    return @()
  }
}

function Get-FABFabricWorkspaces {
  <#
  .SYNOPSIS
  Gets all workspaces using FabricPS-PBIP
  #>
  [CmdletBinding()]
  param()
  
  try {
    [array]$workspaces = Invoke-FabricAPIRequest -Uri "workspaces" -Method Get
    return $workspaces
  }
  catch {
    Write-Warning "Failed to get workspaces: $($_.Exception.Message)"
    return @()
  }
}

function Invoke-FABWorkspaceFilter {
  <#
  .SYNOPSIS
  Applies workspace filtering based on configuration filter string
  
  .DESCRIPTION
  Parses OData-style filter expressions and applies them to workspace collections.
  Supports filtering by state, type, name patterns, capacity, and domain.
  
  .PARAMETER Workspaces
  The array of workspace objects to filter
  
  .PARAMETER Filter
  The filter expression in OData style format
  
  .EXAMPLE
  $filtered = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter "(state eq 'Active')"
  
  .EXAMPLE
  $filtered = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter "(type eq 'Workspace') and (state eq 'Active')"
  
  .EXAMPLE
  $filtered = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter "(capacityId eq '56bac802-080d-4f73-8a42-1b406eb1fcac')"
  
  .EXAMPLE
  $filtered = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter "(domainId eq '9ce364e0-8e9d-4605-887a-b599b3e8b123')"
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject[]]$Workspaces,
    
    [Parameter(Mandatory = $true)]
    [string]$Filter
  )
  
  try {
    Write-Host "Applying workspace filter: $Filter"
    
    # Start with all workspaces
    [PSCustomObject[]]$filteredWorkspaces = $Workspaces
    
    # Check if we need to enrich workspaces with capacityId or domainId information
    [bool]$needsCapacityId = $Filter -match "capacityId\s+eq\s+'([^']+)'"
    [bool]$needsDomainId = $Filter -match "domainId\s+eq\s+'([^']+)'"
    
    if ($needsCapacityId -or $needsDomainId) {
      Write-Host "  - Enriching workspace data with detailed information..."
      $enrichedWorkspaces = @()
      
      foreach ($workspace in $Workspaces) {
        try {
          # Get full workspace details including capacityId and domainId
          [PSCustomObject]$workspaceInfo = Invoke-FabricAPIRequest -Uri "workspaces/$($workspace.id)" -Method Get
          $enrichedWorkspaces += $workspaceInfo
        }
        catch {
          Write-Warning "  - Failed to get details for workspace '$($workspace.displayName)' ($($workspace.id)): $($_.Exception.Message)"
          # Still include the workspace with basic info
          $enrichedWorkspaces += $workspace
        }
      }
      
      $filteredWorkspaces = $enrichedWorkspaces
    }
    
    # Handle state filtering - matches: state eq 'Active', state eq 'Inactive'
    # Note: Fabric API doesn't return 'state' property, so we treat all returned workspaces as 'Active'
    if ($Filter -match "state\s+eq\s+'([^']+)'") {
      [string]$stateFilter = $matches[1]
      Write-Host "  - Filtering by state: $stateFilter"
      if ($stateFilter -eq 'Active') {
        # All workspaces returned by the API are considered active/accessible
        Write-Host "    (All returned workspaces are treated as Active)"
      }
      else {
        # If filtering for inactive workspaces, return empty since API only returns active ones
        Write-Host "    (Filtering out all workspaces since API only returns active ones)"
        [PSCustomObject[]]$filteredWorkspaces = @()
      }
    }
    
    # Handle type filtering - matches: type eq 'Workspace'
    if ($Filter -match "type\s+eq\s+'([^']+)'") {
      [string]$typeFilter = $matches[1]
      Write-Host "  - Filtering by type: $typeFilter"
      $filteredWorkspaces = $filteredWorkspaces | Where-Object { $_.type -eq $typeFilter }
    }
    
    # Handle capacity filtering - matches: capacityId eq 'guid'
    if ($Filter -match "capacityId\s+eq\s+'([^']+)'") {
      [string]$capacityIdFilter = $matches[1]
      Write-Host "  - Filtering by capacityId: $capacityIdFilter"
      $filteredWorkspaces = $filteredWorkspaces | Where-Object { $_.capacityId -eq $capacityIdFilter }
    }
    
    # Handle domain filtering - matches: domainId eq 'guid'
    if ($Filter -match "domainId\s+eq\s+'([^']+)'") {
      [string]$domainIdFilter = $matches[1]
      Write-Host "  - Filtering by domainId: $domainIdFilter"
      $filteredWorkspaces = $filteredWorkspaces | Where-Object { $_.domainId -eq $domainIdFilter }
    }
    
    # Handle name contains filtering - matches: contains(name,'pattern')
    if ($Filter -match "contains\s*\(\s*name\s*,\s*'([^']+)'\s*\)") {
      [string]$namePattern = $matches[1]
      Write-Host "  - Filtering by name pattern: $namePattern"
      $filteredWorkspaces = $filteredWorkspaces | Where-Object { $_.displayName -like "*$namePattern*" }
    }
    
    # Handle name starts with filtering - matches: startswith(name,'pattern')
    if ($Filter -match "startswith\s*\(\s*name\s*,\s*'([^']+)'\s*\)") {
      [string]$namePattern = $matches[1]
      Write-Host "  - Filtering by name starts with: $namePattern"
      $filteredWorkspaces = $filteredWorkspaces | Where-Object { $_.displayName -like "$namePattern*" }
    }
    
    # Handle name ends with filtering - matches: endswith(name,'pattern')
    if ($Filter -match "endswith\s*\(\s*name\s*,\s*'([^']+)'\s*\)") {
      [string]$namePattern = $matches[1]
      Write-Host "  - Filtering by name ends with: $namePattern"
      $filteredWorkspaces = $filteredWorkspaces | Where-Object { $_.displayName -like "*$namePattern" }
    }
    
    Write-Host "Workspace filter result: $($Workspaces.Count) -> $($filteredWorkspaces.Count) workspaces"
    return $filteredWorkspaces
  }
  catch {
    Write-Warning "Failed to parse workspace filter '$Filter'. Using all workspaces. Error: $($_.Exception.Message)"
    return $Workspaces
  }
}

function Invoke-FABItemFilter {
  <#
  .SYNOPSIS
  Applies item-level filtering based on configuration filter string

  .DESCRIPTION
  Parses OData-style filter expressions and applies them to item collections.
  Supports filtering by type, name patterns, and optionally user/date metadata when Scanner API enrichment is enabled.

  .PARAMETER Items
  The array of item objects to filter

  .PARAMETER Filter
  The filter expression in OData style format

  .PARAMETER Config
  Configuration object (optional, used for Scanner API settings)

  .PARAMETER WorkspaceId
  Workspace ID (required for Scanner API enrichment)

  .EXAMPLE
  $filtered = Invoke-FABItemFilter -Items $items -Filter "type eq 'Report'"

  .EXAMPLE
  $filtered = Invoke-FABItemFilter -Items $items -Filter "type in ('Report', 'SemanticModel')"

  .EXAMPLE
  $filtered = Invoke-FABItemFilter -Items $items -Filter "contains(displayName,'Sales')"

  .EXAMPLE
  $filtered = Invoke-FABItemFilter -Items $items -Filter "modifiedBy eq 'john@contoso.com'" -Config $config -WorkspaceId $wsId
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject[]]$Items,

    [Parameter(Mandatory = $true)]
    [string]$Filter,

    [Parameter()]
    [PSCustomObject]$Config,

    [Parameter()]
    [string]$WorkspaceId
  )

  try {
    Write-Host "Applying item filter: $Filter"

    # Start with all items
    [PSCustomObject[]]$filteredItems = $Items

    # Check if we need Scanner API enrichment for user/date filters
    [bool]$needsEnrichment = $Filter -match "(createdBy|modifiedBy|createdDate|modifiedDate|configuredBy)"

    if ($needsEnrichment) {
      Write-Host "  - Filter requires Scanner API enrichment for user/date metadata"

      # Check if Scanner API is enabled in config
      if ($Config -and $Config.PSObject.Properties['AdvancedFeatures'] -and
          $Config.AdvancedFeatures.PSObject.Properties['EnableScannerAPI'] -and
          $Config.AdvancedFeatures.EnableScannerAPI) {

        Write-Host "  - Enriching items with Scanner API metadata..."
        # TODO: Implement Scanner API enrichment
        Write-Warning "Scanner API enrichment not yet implemented. User/date filters will be skipped."
      }
      else {
        Write-Warning "User/date filters require Scanner API enrichment. Enable 'AdvancedFeatures.EnableScannerAPI' in config."
        Write-Warning "Only basic filters (type, name) will be applied."
      }
    }

    # Handle type filtering - matches: type eq 'Report'
    if ($Filter -match "type\s+eq\s+'([^']+)'") {
      [string]$typeFilter = $matches[1]
      Write-Host "  - Filtering by type: $typeFilter"
      $filteredItems = $filteredItems | Where-Object { $_.type -eq $typeFilter }
    }

    # Handle type IN filtering - matches: type in ('Report', 'SemanticModel')
    if ($Filter -match "type\s+in\s+\(([^)]+)\)") {
      [string]$typeList = $matches[1]
      [string[]]$types = $typeList -split ',' | ForEach-Object { $_.Trim().Trim("'") }
      Write-Host "  - Filtering by types: $($types -join ', ')"
      $filteredItems = $filteredItems | Where-Object { $_.type -in $types }
    }

    # Handle displayName contains filtering - matches: contains(displayName,'pattern')
    if ($Filter -match "contains\s*\(\s*displayName\s*,\s*'([^']+)'\s*\)") {
      [string]$namePattern = $matches[1]
      Write-Host "  - Filtering by displayName pattern: $namePattern"
      $filteredItems = $filteredItems | Where-Object { $_.displayName -like "*$namePattern*" }
    }

    # Handle displayName starts with filtering - matches: startswith(displayName,'pattern')
    if ($Filter -match "startswith\s*\(\s*displayName\s*,\s*'([^']+)'\s*\)") {
      [string]$namePattern = $matches[1]
      Write-Host "  - Filtering by displayName starts with: $namePattern"
      $filteredItems = $filteredItems | Where-Object { $_.displayName -like "$namePattern*" }
    }

    # Handle displayName ends with filtering - matches: endswith(displayName,'pattern')
    if ($Filter -match "endswith\s*\(\s*displayName\s*,\s*'([^']+)'\s*\)") {
      [string]$namePattern = $matches[1]
      Write-Host "  - Filtering by displayName ends with: $namePattern"
      $filteredItems = $filteredItems | Where-Object { $_.displayName -like "*$namePattern" }
    }

    # Handle description contains filtering - matches: contains(description,'pattern')
    if ($Filter -match "contains\s*\(\s*description\s*,\s*'([^']+)'\s*\)") {
      [string]$descPattern = $matches[1]
      Write-Host "  - Filtering by description pattern: $descPattern"
      $filteredItems = $filteredItems | Where-Object { $_.description -like "*$descPattern*" }
    }

    Write-Host "Item filter result: $($Items.Count) -> $($filteredItems.Count) items"
    return $filteredItems
  }
  catch {
    Write-Warning "Failed to parse item filter '$Filter'. Using all items. Error: $($_.Exception.Message)"
    return $Items
  }
}

function Get-FABSupportedItemTypes {
  <#
  .SYNOPSIS
  Dynamically retrieves supported Fabric item types from Microsoft Learn documentation
  
  .DESCRIPTION
  Queries the official Microsoft Fabric REST API table of contents JSON to determine
  which item types support the "Get Item Definition" endpoint. This ensures the bot
  automatically adapts to newly supported item types.
  
  .PARAMETER TocUrl
  The URL to the Microsoft Fabric REST API table of contents JSON file
  
  .PARAMETER UseCache
  Whether to use cached results if available
  
  .PARAMETER CacheHours
  How many hours to cache results (default: 24)
  
  .EXAMPLE
  $supportedTypes = Get-FABSupportedItemTypes
  Write-Host "Supported item types: $($supportedTypes -join ', ')"
  #>
  [CmdletBinding()]
  param(
    [Parameter()]
    [string]$TocUrl = "https://learn.microsoft.com/en-us/rest/api/fabric/toc.json",
    
    [Parameter()]
    [switch]$UseCache,
    
    [Parameter()]
    [int]$CacheHours = 24
  )

  [string]$cacheFile = Join-Path $env:TEMP "FABSupportedItemTypes.json"
  [datetime]$cacheValidUntil = (Get-Date).AddHours(-$CacheHours)
  
  try {
    # Check cache first if requested
    if ($UseCache -and (Test-Path $cacheFile)) {
      [System.IO.FileInfo]$cacheInfo = Get-Item $cacheFile
      if ($cacheInfo.LastWriteTime -gt $cacheValidUntil) {
        Write-Verbose "Using cached supported item types from $cacheFile"
        [array]$cached = Get-Content $cacheFile -Raw | ConvertFrom-Json
        if ($cached -and $cached.Count -gt 0) {
          return $cached
        }
      }
    }
    
    Write-Verbose "Fetching supported item types from $TocUrl"
    
    # Fetch the TOC JSON
    [PSCustomObject]$response = Invoke-RestMethod -Uri $TocUrl -Method Get -ErrorAction Stop
    
    # Find all "Get {xyz} Definition" entries and extract parent hierarchy
    [array]$supportedTypes = @()
    if ($response.PSObject.Properties['items'] -and $response.items) {
      foreach ($item in $response.items) {
        $supportedTypes += Find-FABDefinitionEndpoints -Node $item -ParentPath @()
      }
    }
    else {
      # Fallback: treat response as a node directly
      [array]$supportedTypes = Find-FABDefinitionEndpoints -Node $response -ParentPath @()
    }
    
    # Clean and validate results
    [string[]]$cleanTypes = $supportedTypes | Where-Object { $_ -and $_.Trim() } | 
    ForEach-Object { $_.Trim() } | 
    Where-Object { $_ -notin @("Core", "Admin", "Spark") } |  # Filter out non-item types
    Sort-Object -Unique
    
    # Validate against known good types
    [string[]]$knownTypes = @("Report", "SemanticModel", "Dataflow", "Notebook", "Environment")
    [array]$hasKnownTypes = $cleanTypes | Where-Object { $_ -in $knownTypes }
    
    if ($hasKnownTypes.Count -eq 0) {
      Write-Warning "No known item types found in TOC response. Using fallback list."
      return Get-FABFallbackItemTypes
    }
    
    Write-Verbose "Found $($cleanTypes.Count) supported item types: $($cleanTypes -join ', ')"
    
    # Cache the results
    if ($UseCache) {
      try {
        $cleanTypes | ConvertTo-Json -Compress | Out-File $cacheFile -Encoding UTF8
        Write-Verbose "Cached results to $cacheFile"
      }
      catch {
        Write-Warning "Failed to cache results: $($_.Exception.Message)"
      }
    }
    
    return $cleanTypes
  }
  catch {
    Write-Warning "Failed to fetch supported item types from TOC: $($_.Exception.Message)"
    return Get-FABFallbackItemTypes
  }
}

function Find-FABDefinitionEndpoints {
  <#
  .SYNOPSIS
  Recursively searches the TOC JSON structure for "Get {xyz} Definition" endpoints
  
  .DESCRIPTION
  Internal helper function that walks the JSON hierarchy to find definition endpoints
  and extracts the corresponding item type names from the parent structure.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    $Node,
    
    [Parameter()]
    [string[]]$ParentPath = @()
  )
  
  [array]$results = @()
  
  # Get current node title
  [string]$currentTitle = if ($Node.PSObject.Properties['toc_title']) { $Node.toc_title } else { "" }
  
  # Check if current node has a toc_title indicating a "Get {xyz} Definition" endpoint
  if ($currentTitle -and $currentTitle -match '^Get .+ Definition$') {
    Write-Verbose "Found potential definition endpoint: '$currentTitle', Parent path: $($ParentPath -join ' -> ')"
    
    # The item type should be extracted from the path
    # Looking for pattern: ItemType -> Items -> "Get ItemType Definition"
    if ($ParentPath.Count -ge 2 -and $ParentPath[-1] -eq "Items") {
      [string]$itemType = $ParentPath[-2]  # The item type is the grandparent
      $results += $itemType
      Write-Verbose "✓ Found supported item type: '$itemType' (from endpoint '$currentTitle')"
    }
    else {
      Write-Verbose "✗ Skipped '$currentTitle' - path doesn't match expected pattern (ItemType -> Items -> Definition)"
    }
  }
  
  # Recursively search child items
  if ($Node.PSObject.Properties['children'] -and $Node.children) {
    foreach ($child in $Node.children) {
      [string[]]$newPath = if ($currentTitle) { $ParentPath + @($currentTitle) } else { $ParentPath }
      $results += Find-FABDefinitionEndpoints -Node $child -ParentPath $newPath
    }
  }
  
  return $results
}

function Get-FABFallbackItemTypes {
  <#
  .SYNOPSIS
  Returns a fallback list of known supported item types
  
  .DESCRIPTION
  Provides a hardcoded list of item types that are known to support definition export.
  Used when the dynamic TOC query fails.
  #>
  [CmdletBinding()]
  param()
  
  return @(
    "Report", "SemanticModel", "Notebook", "SparkJobDefinition", "DataPipeline", 
    "SQLEndpoint", "Eventhouse", "Eventstream", "KQLDatabase", "KQLDashboard", 
    "KQLQueryset", "Environment", "Dataflow", "CopyJob", "GraphQLApi", "Reflex",
    "VariableLibrary", "MountedDataFactory", "MirroredDatabase", 
    "MirroredAzureDatabricksCatalog", "DigitalTwinBuilder", "DigitalTwinBuilderFlow"
  )
}

function Confirm-FABConfigurationCompatibility {
  <#
  .SYNOPSIS
  Ensures configuration compatibility between v1.0 and v2.0 formats
  
  .DESCRIPTION
  Validates and enhances configuration to ensure all required settings are present.
  This function may modify the input $Config object in-place by adding missing properties.
  Uses dynamic item type detection from Microsoft Learn documentation.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config
  )

  # Get supported item types dynamically from Microsoft Learn
  Write-Verbose "Retrieving supported item types from Microsoft Learn documentation..."
  [string[]]$ItemTypes = Get-FABSupportedItemTypes -UseCache
  
  # Filter out any user-configured item types that are not supported
  if ($Config.PSObject.Properties['ExportSettings'] -and 
    $Config.ExportSettings.PSObject.Properties['ItemTypes'] -and 
    $Config.ExportSettings.ItemTypes) {
    
    [string[]]$configuredTypes = $Config.ExportSettings.ItemTypes
    [string[]]$supportedConfigured = $configuredTypes | Where-Object { $_ -in $ItemTypes }
    [string[]]$unsupportedTypes = $configuredTypes | Where-Object { $_ -notin $ItemTypes }
    
    if ($unsupportedTypes.Count -gt 0) {
      Write-Warning "The following configured item types are not supported for definition export: $($unsupportedTypes -join ', ')"
      Write-Host "Supported item types: $($ItemTypes -join ', ')" -ForegroundColor Green
      
      # Update configuration to remove unsupported types
      $Config.ExportSettings.ItemTypes = $supportedConfigured
      Write-Host "Updated configuration to use only supported types: $($supportedConfigured -join ', ')" -ForegroundColor Yellow
    }
  }
  
  [string]$WorkspaceFilter = "(type eq 'Workspace') and (state eq 'Active')"

  # Ensure ExportSettings exists
  if (-not $Config.PSObject.Properties['ExportSettings']) {
    Write-Warning "ExportSettings not found in configuration. Adding default settings."
    [string]$defaultTargetFolder = ".\Workspaces"
    # Optionally resolve to absolute path for clarity
    if ($defaultTargetFolder -notmatch '^[a-zA-Z]:\\') {
      [string]$defaultTargetFolder = (Resolve-Path $defaultTargetFolder).Path
    }
    $Config | Add-Member -MemberType NoteProperty -Name 'ExportSettings' -Value ([PSCustomObject]@{
        TargetFolder    = $defaultTargetFolder
        RetentionDays   = 30
        WorkspaceFilter = $WorkspaceFilter
        ItemTypes       = $ItemTypes
      })
  }
  
  # Ensure WorkspaceFilter exists in ExportSettings
  if (-not $Config.ExportSettings.PSObject.Properties['WorkspaceFilter']) {
    Write-Warning "WorkspaceFilter not found in ExportSettings. Using default filter."
    $Config.ExportSettings | Add-Member -MemberType NoteProperty -Name 'WorkspaceFilter' -Value $WorkspaceFilter
  }
  
  # Ensure ItemTypes exists in ExportSettings
  if (-not $Config.ExportSettings.PSObject.Properties['ItemTypes']) {
    Write-Warning "ItemTypes not found in ExportSettings. Using default item types."
    $Config.ExportSettings | Add-Member -MemberType NoteProperty -Name 'ItemTypes' -Value $ItemTypes
  }
  
  return $Config
}

#endregion

#region Public Functions

function Export-FABFabricItemsAdvanced {
  <#
    .SYNOPSIS
    Enhanced export function using FabricPS-PBIP capabilities
    
    .DESCRIPTION
    Exports Fabric items with advanced features like item-level parallel processing, enhanced metadata, and multiple formats.
    Parallelism is applied at the item level across all workspaces for optimal resource utilization.
    #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config,
        
    [Parameter()]
    [string[]]$WorkspaceIds,
        
    [Parameter()]
    [string]$TargetFolder,
        
    [Parameter()]
    [switch]$SerialProcessing,
    
    [Parameter()]
    [int]$ThrottleLimit = 0
  )
    
  # Initialize FabricPS-PBIP connection
  if (-not (Initialize-FABFabricConnection -Config $Config)) {
    throw "Failed to initialize Fabric connection"
  }
  
  # Determine if parallel processing should be enabled (PowerShell 7+ is required)
  # Default to parallel processing unless explicitly disabled or config says otherwise
  [bool]$enableParallelProcessing = (-not $SerialProcessing.IsPresent) -and
  (-not ($Config.PSObject.Properties['FabricPSPBIPSettings'] -and $Config.FabricPSPBIPSettings.PSObject.Properties['ParallelProcessing'] -and -not $Config.FabricPSPBIPSettings.ParallelProcessing))
  
  # Get optimal throttle limit
  [int]$actualThrottleLimit = Get-FABOptimalThrottleLimit -OverrideThrottleLimit $ThrottleLimit -Config $Config
  
  Write-Host "Parallel processing: $($enableParallelProcessing ? 'Enabled' : 'Disabled')" -ForegroundColor $(if ($enableParallelProcessing) { 'Green' } else { 'Yellow' })
  if ($enableParallelProcessing) {
    Write-Host "Throttle limit: $actualThrottleLimit" -ForegroundColor Green
  }
    
  # Get workspaces using FabricPS-PBIP
  if (-not $WorkspaceIds) {
    Write-Host "Retrieving workspaces based on configuration filter..."
    [array]$workspaces = Invoke-FABRateLimitedOperation -Operation {
      Get-FABFabricWorkspaces
    } -Config $Config -OperationName "Get-FabricWorkspaces"
    
    # Ensure we have a valid array
    if (-not $workspaces) {
      [array]$workspaces = @()
    }
    
    # Apply workspace filtering based on configuration
    if ($Config.ExportSettings.WorkspaceFilter) {
      [array]$workspaces = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter $Config.ExportSettings.WorkspaceFilter
      # Ensure filtering result is valid
      if (-not $workspaces) {
        [array]$workspaces = @()
      }
    }
    
    # Safely extract workspace IDs
    if ($workspaces -and $workspaces.Count -gt 0) {
      [string[]]$WorkspaceIds = $workspaces.id
    }
    else {
      [string[]]$WorkspaceIds = @()
      Write-Warning "No workspaces found matching the filter criteria"
    }
  }
    
  Write-Host "Found $($WorkspaceIds.Count) workspaces to process"
  
  # Check if we have any workspaces to process
  if ($WorkspaceIds.Count -eq 0) {
    Write-Host "No workspaces found to process. Exiting gracefully." -ForegroundColor Yellow
    return
  }
  
  # Collect all workspace info and items first
  Write-Host "Gathering workspace information and item inventories..." -ForegroundColor Cyan
  [array]$allWorkspaceData = @()
  [int]$totalItemCount = 0
  
  foreach ($workspaceId in $WorkspaceIds) {
    try {
      Write-Host "  - Gathering info for workspace: $workspaceId"
      
      [PSCustomObject]$workspaceInfo = Invoke-FABRateLimitedOperation -Operation {
        Get-FABFabricWorkspaceById -WorkspaceId $workspaceId
      } -Config $Config -OperationName "Get-FabricWorkspace-$workspaceId"
      
      [array]$items = Invoke-FABRateLimitedOperation -Operation {
        Get-FABFabricItemsByWorkspace -WorkspaceId $workspaceId
      } -Config $Config -OperationName "Get-FabricItem-$workspaceId"

      # Apply item type filtering first (backward compatibility with ItemTypes config)
      [array]$filteredItems = $items | Where-Object { $_.type -in $Config.ExportSettings.ItemTypes }

      # Apply additional item-level filtering if ItemFilter is configured
      if ($Config.ExportSettings.PSObject.Properties['ItemFilter'] -and $Config.ExportSettings.ItemFilter) {
        [array]$filteredItems = Invoke-FABItemFilter -Items $filteredItems -Filter $Config.ExportSettings.ItemFilter -Config $Config -WorkspaceId $workspaceId
      }

      $totalItemCount += $filteredItems.Count
      
      # Create workspace folder structure
      [string]$workspaceFolder = Join-Path -Path $TargetFolder -ChildPath $workspaceInfo.displayName
      if (-not (Test-Path $workspaceFolder)) {
        New-Item -Path $workspaceFolder -ItemType Directory -Force | Out-Null
      }
      
      $allWorkspaceData += [PSCustomObject]@{
        WorkspaceId     = $workspaceId
        WorkspaceInfo   = $workspaceInfo
        WorkspaceFolder = $workspaceFolder
        Items           = $items
        FilteredItems   = $filteredItems
      }
      
      Write-Host "    Found $($filteredItems.Count) exportable items in $($workspaceInfo.displayName)"
    }
    catch {
      Write-Error "Failed to gather info for workspace $workspaceId : $($_.Exception.Message)"
    }
  }
  
  Write-Host "Total items to export: $totalItemCount across $($allWorkspaceData.Count) workspaces" -ForegroundColor Green
  
  # Create a flattened list of all items with their workspace context
  [array]$allItemJobs = @()
  foreach ($workspaceData in $allWorkspaceData) {
    foreach ($item in $workspaceData.FilteredItems) {
      $allItemJobs += [PSCustomObject]@{
        WorkspaceId     = $workspaceData.WorkspaceId
        WorkspaceInfo   = $workspaceData.WorkspaceInfo
        WorkspaceFolder = $workspaceData.WorkspaceFolder
        Item            = $item
        JobId           = "$($workspaceData.WorkspaceId)-$($item.id)"
      }
    }
  }
  
  # Process items with parallel processing if enabled
  if ($enableParallelProcessing -and $allItemJobs.Count -gt 1) {
    Write-Host "Processing $($allItemJobs.Count) items in parallel across all workspaces..." -ForegroundColor Green
    
    # Get the rate limiting function definition dynamically for parallel execution
    [System.Management.Automation.CommandInfo]$rateLimitedOperationFunction = Get-Command Invoke-FABRateLimitedOperation
    [string]$rateLimitedOperationFunctionText = $rateLimitedOperationFunction.Definition
    
    # Get the FabricPS-PBIP module path to pass to parallel threads
    [string]$moduleFileName = "FabricPS-PBIP.psm1"
    [string]$fabricModulePath = $null
    [string[]]$possiblePaths = @(
      (Join-Path -Path $PSScriptRoot -ChildPath "..\$moduleFileName"),
      (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath $moduleFileName)
    )
    
    foreach ($path in $possiblePaths) {
      if (Test-Path -Path $path) {
        [string]$fabricModulePath = $path
        break
      }
    }
    
    if (-not $fabricModulePath) {
      throw "FabricPS-PBIP module path not found for parallel processing"
    }
    
    $allItemJobs | ForEach-Object -Parallel {
      [PSCustomObject]$itemJob = $_
      [PSCustomObject]$Config = $using:Config
      [string]$functionText = $using:rateLimitedOperationFunctionText
      [string]$modulePath = $using:fabricModulePath
      
      try {
        # Import FabricPS-PBIP module in parallel thread
        Import-Module -Name $modulePath -Force
        
        # Define the rate limiting function in this thread scope
        [string]$functionDefinition = "function Invoke-FABRateLimitedOperation { $functionText }"
        Invoke-Expression $functionDefinition
        
        [int]$threadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        Write-Host "Exporting item '$($itemJob.Item.displayName)' from workspace '$($itemJob.WorkspaceInfo.displayName)' (Thread: $threadId)"
        
        # Create item-specific folder
        [string]$itemFolderName = "$($itemJob.Item.displayName).$($itemJob.Item.type)"
        [string]$itemFolder = Join-Path -Path $itemJob.WorkspaceFolder -ChildPath $itemFolderName
        if (-not (Test-Path $itemFolder)) {
          New-Item -Path $itemFolder -ItemType Directory -Force | Out-Null
        }
        
        # Export the item with rate limiting
        Invoke-FABRateLimitedOperation -Operation {
          Export-FabricItem -workspaceId $itemJob.WorkspaceId -itemId $itemJob.Item.id -path $itemFolder
        } -Config $Config -OperationName "Export-FabricItem-$($itemJob.Item.id)"
        
        Write-Host "  ✓ Completed: '$($itemJob.Item.displayName)' (Thread: $threadId)" -ForegroundColor Green
      }
      catch {
        Write-Error "Failed to export item '$($itemJob.Item.displayName)' from workspace '$($itemJob.WorkspaceInfo.displayName)': $($_.Exception.Message)"
      }
    } -ThrottleLimit $actualThrottleLimit
    
    Write-Host "Parallel item processing completed. Generating workspace metadata..." -ForegroundColor Green
  }
  else {
    Write-Host "Processing $($allItemJobs.Count) items sequentially..." -ForegroundColor Yellow
    
    [string]$currentWorkspace = ""
    foreach ($itemJob in $allItemJobs) {
      try {
        # Show workspace context when we switch workspaces
        if ($currentWorkspace -ne $itemJob.WorkspaceInfo.displayName) {
          [string]$currentWorkspace = $itemJob.WorkspaceInfo.displayName
          Write-Host "Processing workspace: $currentWorkspace" -ForegroundColor Cyan
        }
        
        Write-Host "  - Exporting: $($itemJob.Item.displayName)"
        
        # Create item-specific folder
        [string]$itemFolderName = "$($itemJob.Item.displayName).$($itemJob.Item.type)"
        [string]$itemFolder = Join-Path -Path $itemJob.WorkspaceFolder -ChildPath $itemFolderName
        if (-not (Test-Path $itemFolder)) {
          New-Item -Path $itemFolder -ItemType Directory -Force | Out-Null
        }
        
        Invoke-FABRateLimitedOperation -Operation {
          Export-FabricItem -workspaceId $itemJob.WorkspaceId -itemId $itemJob.Item.id -path $itemFolder
        } -Config $Config -OperationName "Export-FabricItem-$($itemJob.Item.id)"
      }
      catch {
        Write-Error "Failed to export item '$($itemJob.Item.displayName)' from workspace '$($itemJob.WorkspaceInfo.displayName)': $($_.Exception.Message)"
      }
    }
  }
  
  # Generate workspace metadata after item processing is complete
  Write-Host "Generating workspace metadata..." -ForegroundColor Cyan
  try {
    Export-FABWorkspaceMetadata -AllWorkspaceData $allWorkspaceData -TargetFolder $TargetFolder -Config $Config
    Write-Host "  ✓ Workspace metadata generated successfully" -ForegroundColor Green
  }
  catch {
    Write-Error "Failed to generate workspace metadata: $($_.Exception.Message)"
  }
}

function Export-FABWorkspaceMetadata {
  <#
    .SYNOPSIS
    Exports metadata for all workspaces using FabricPS-PBIP capabilities
    
    .DESCRIPTION
    Creates a single JSON file containing metadata for all exported workspaces and items
    #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [array]$AllWorkspaceData,
        
    [Parameter(Mandatory = $true)]
    [string]$TargetFolder,
        
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config
  )
    
  # Build metadata structure
  [hashtable]$consolidatedMetadata = @{
    ExportTimestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
    ExportSummary   = @{
      TotalWorkspaces   = $AllWorkspaceData.Count
      TotalItems        = ($AllWorkspaceData | ForEach-Object { $_.FilteredItems.Count } | Measure-Object -Sum).Sum
      ExportedItemTypes = $Config.ExportSettings.ItemTypes
      WorkspaceFilter   = $Config.ExportSettings.WorkspaceFilter
    }
    ExportConfig    = $Config.ExportSettings
    Workspaces      = @()
  }
  
  # Add detailed information for each workspace
  foreach ($workspaceData in $AllWorkspaceData) {
    [hashtable]$workspaceMetadata = @{
      WorkspaceInfo     = $workspaceData.WorkspaceInfo
      Items             = $workspaceData.Items
      FilteredItems     = $workspaceData.FilteredItems
      ExportedItemCount = $workspaceData.FilteredItems.Count
      ItemTypes         = ($workspaceData.FilteredItems | Group-Object -Property type | ForEach-Object { @{ Type = $_.Name; Count = $_.Count } })
    }
    
    # Add advanced metadata if enabled
    if ($Config.PSObject.Properties['AdvancedFeatures'] -and $Config.AdvancedFeatures.PSObject.Properties['EnableUsageMetrics'] -and $Config.AdvancedFeatures.EnableUsageMetrics) {
      try {
        # Usage metrics functionality not yet implemented for FabricPS-PBIP
        Write-Verbose "Usage metrics export not yet supported with FabricPS-PBIP module"
        $workspaceMetadata.UsageMetrics = @{
          Note      = "Usage metrics not available with FabricPS-PBIP"
          Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
        }
      }
      catch {
        Write-Warning "Could not retrieve usage metrics for workspace $($workspaceData.WorkspaceInfo.displayName): $($_.Exception.Message)"
      }
    }
    
    $consolidatedMetadata.Workspaces += $workspaceMetadata
  }
    
  # Export metadata as JSON
  [string]$metadataPath = Join-Path -Path $TargetFolder -ChildPath "fabric-archive-metadata.json"
  $consolidatedMetadata | ConvertTo-Json -Depth 10 | Out-File -FilePath $metadataPath -Encoding UTF8
  
  Write-Host "Metadata saved to: $metadataPath" -ForegroundColor Gray
}

function Start-FABFabricArchiveProcess {
  <#
    .SYNOPSIS
    Main orchestration function for the archive process
    #>
  [CmdletBinding()]
  param(
    [Parameter(ParameterSetName = 'ConfigPath')]
    [string]$ConfigPath = ".\FabricArchiveBot_Config.json",
    
    [Parameter(ParameterSetName = 'ConfigObject')]
    [PSCustomObject]$Config,
    
    [Parameter()]
    [switch]$SerialProcessing,
    
    [Parameter()]
    [int]$ThrottleLimit = 0
  )
    
  # Test FabricPS-PBIP availability
  if (-not (Test-FABFabricPSPBIPAvailability)) {
    throw "FabricPS-PBIP module is required but not available"
  }
    
  # Load configuration based on parameter set
  if ($PSCmdlet.ParameterSetName -eq 'ConfigObject') {
    # Configuration object was passed directly
    Write-Host "Using provided configuration object" -ForegroundColor Green
  }
  else {
    # Load configuration from file using helper function
    [PSCustomObject]$Config = Get-FABConfiguration -ConfigPath $ConfigPath
    Write-Host "Configuration loaded from: $ConfigPath" -ForegroundColor Green
  }
  
  # Ensure configuration compatibility
  [PSCustomObject]$Config = Confirm-FABConfigurationCompatibility -Config $Config
  
  # Initialize logging subsystem
  Initialize-FABLogging -Config $Config
  
  # Start main archive operation tracking
  [PSCustomObject]$archiveOperation = Start-FABOperation -OperationName "FabricArchiveProcess" -Parameters @{
    ConfigPath     = $ConfigPath
    SerialProcessing = $SerialProcessing.IsPresent
    ThrottleLimit  = $ThrottleLimit
  }
  
  try {
    # Validate version compatibility
    if ($Config.Version -lt "2.0") {
      Write-FABLog -Level Warning -Message "Configuration version $($Config.Version) detected. Consider upgrading to v2.0 format."
    }
      
    # Setup target folder with date hierarchy
    [datetime]$date = Get-Date
    [string]$dateFolder = Join-Path -Path $Config.ExportSettings.TargetFolder -ChildPath ("{0}\{1:D2}\{2:D2}" -f $date.Year, $date.Month, $date.Day)
      
    if (-not (Test-Path $dateFolder)) {
      New-Item -Path $dateFolder -ItemType Directory -Force | Out-Null
      Write-FABLog -Level Info -Message "Created target folder: $dateFolder"
    }
      
    # Start export process
    Write-FABLog -Level Info -Message "Starting export process"
    Export-FABFabricItemsAdvanced -Config $Config -TargetFolder $dateFolder -SerialProcessing:$SerialProcessing -ThrottleLimit $ThrottleLimit
      
    # Cleanup old archives
    Write-FABLog -Level Info -Message "Starting cleanup of old archives"
    Remove-FABOldArchives -Config $Config
      
    # Send notifications if configured
    if ($Config.NotificationSettings.EnableNotifications) {
      Write-FABLog -Level Info -Message "Sending archive notification"
      Send-FABArchiveNotification -Config $Config -ArchiveFolder $dateFolder
    }
    
    # Complete operation successfully
    Complete-FABOperation -Operation $archiveOperation -Success -Result @{
      ArchiveFolder = $dateFolder
      Summary      = Get-FABLogSummary
    }
    
    # Export session summary
    [string]$summaryPath = Export-FABLogSummary
    Write-FABLog -Level Info -Message "Archive process completed successfully. Summary: $summaryPath"
  }
  catch {
    # Log the error and complete operation as failed
    Write-FABLog -Level Error -Message "Archive process failed: $($_.Exception.Message)" -Operation "FabricArchiveProcess"
    Complete-FABOperation -Operation $archiveOperation -ErrorMessage $_.Exception.Message
    
    # Export session summary even on failure
    Export-FABLogSummary
    
    throw
  }
}

function Remove-FABOldArchives {
  <#
    .SYNOPSIS
    Enhanced cleanup function with better logging and safety checks
    #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config
  )
  
  [PSCustomObject]$cleanupOp = Start-FABOperation -OperationName "CleanupOldArchives"
  
  try {
    [datetime]$cutoffDate = (Get-Date).AddDays(-$Config.ExportSettings.RetentionDays)
    [string]$targetFolder = $Config.ExportSettings.TargetFolder
      
    Write-FABLog -Level Info -Message "Cleaning up archives older than $($cutoffDate.ToString('yyyy-MM-dd'))"
      
    [array]$oldFolders = Get-ChildItem -Path $targetFolder -Directory -Recurse | 
    Where-Object { $_.CreationTime -lt $cutoffDate -and $_.FullName -ne $targetFolder }
      
    [long]$totalSize = 0
    [int]$folderCount = 0
    
    foreach ($folder in $oldFolders) {
      try {
        [long]$folderSize = (Get-ChildItem -Path $folder.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $totalSize += $folderSize
        Write-FABLog -Level Info -Message "Removing old archive: $($folder.FullName) ($(($folderSize / 1MB).ToString('F2')) MB)"
        Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Stop
        $folderCount++
      }
      catch {
        Write-FABLog -Level Warning -Message "Failed to remove archive folder: $($folder.FullName) - $($_.Exception.Message)"
      }
    }
      
    Write-FABLog -Level Success -Message "Cleanup completed. Removed $folderCount folders, freed $(($totalSize / 1MB).ToString('F2')) MB of disk space."
    Complete-FABOperation -Operation $cleanupOp -Success -Result @{
      FoldersRemoved = $folderCount
      SpaceFreedMB   = [math]::Round($totalSize / 1MB, 2)
    }
  }
  catch {
    Write-FABLog -Level Error -Message "Cleanup operation failed: $($_.Exception.Message)"
    Complete-FABOperation -Operation $cleanupOp -ErrorMessage $_.Exception.Message
    throw
  }
}

function Send-FABArchiveNotification {
  <#
    .SYNOPSIS
    Sends notifications about archive completion
    #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config,
        
    [Parameter(Mandatory = $true)]
    [string]$ArchiveFolder
  )
  
  try {
    [long]$archiveSize = (Get-ChildItem -Path $ArchiveFolder -Recurse -File | Measure-Object -Property Length -Sum).Sum
    [int]$itemCount = (Get-ChildItem -Path $ArchiveFolder -Recurse -File | Measure-Object).Count
    [PSCustomObject]$summary = Get-FABLogSummary
      
    [string]$message = @"
Fabric Archive Bot v2.0 - Archive Completed

Archive Location: $ArchiveFolder
Items Archived: $itemCount
Total Size: $(($archiveSize / 1MB).ToString('F2')) MB
Completion Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Session Statistics:
- Operations: $($summary.TotalOperations)
- Successes: $($summary.SuccessCount)
- Failures: $($summary.FailureCount)
- Warnings: $($summary.WarningCount)
- Errors: $($summary.ErrorCount)
- Duration: $($summary.SessionDuration.ToString('hh\:mm\:ss'))

Powered by FabricPS-PBIP (Credit: Rui Romano)
"@
      
    # Implementation for Teams webhook, email, etc. would go here
    Write-FABLog -Level Info -Message "Archive notification generated"
    Write-Host $message
  }
  catch {
    Write-FABLog -Level Warning -Message "Failed to send notification: $($_.Exception.Message)"
  }
}

function Get-FABConfiguration {
  <#
  .SYNOPSIS
  Loads the Fabric Archive Bot configuration.

  .DESCRIPTION
  Loads configuration from a JSON file or an environment variable.
  
  .PARAMETER ConfigPath
  Path to the configuration file. Defaults to FabricArchiveBot_Config.json in the parent directory of the module.
  
  .PARAMETER ConfigFromEnv
  If set, loads configuration from the FabricArchiveBot_ConfigObject environment variable.
  #>
  [CmdletBinding()]
  param(
    [Parameter()]
    [string]$ConfigPath,
    
    [Parameter()]
    [switch]$ConfigFromEnv
  )
  
  if ($ConfigFromEnv) {
    # Load configuration from environment variable
    [string]$envConfig = [System.Environment]::GetEnvironmentVariable("FabricArchiveBot_ConfigObject", "User")
    
    if (-not $envConfig) {
      throw "FabricArchiveBot_ConfigObject environment variable not found or is empty. Please run Set-FabricArchiveBotUserEnvironmentVariable.ps1 first."
    }
    
    try {
      [PSCustomObject]$config = $envConfig | ConvertFrom-Json
      Write-Verbose "Configuration loaded from environment variable"
      return $config
    }
    catch {
      throw "Failed to parse configuration from environment variable: $($_.Exception.Message)"
    }
  }
  else {
    # Default ConfigPath if not provided
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        if (Test-Path ".\FabricArchiveBot_Config.json") {
            $ConfigPath = ".\FabricArchiveBot_Config.json"
        } elseif (Test-Path (Join-Path $PSScriptRoot "..\FabricArchiveBot_Config.json")) {
            $ConfigPath = Join-Path $PSScriptRoot "..\FabricArchiveBot_Config.json"
        } else {
             throw "ConfigPath not provided and FabricArchiveBot_Config.json not found in current or parent directory."
        }
    }
    
    # Resolve absolute path to avoid ambiguity
    $ConfigPath = Resolve-Path $ConfigPath

    # Load configuration from file
    if (-not (Test-Path -Path $ConfigPath)) {
      throw "Configuration file not found: $ConfigPath"
    }
    
    try {
      [PSCustomObject]$config = Get-Content -Path $ConfigPath | ConvertFrom-Json
      Write-Verbose "Configuration loaded from: $ConfigPath"
      return $config
    }
    catch {
      throw "Failed to load configuration: $($_.Exception.Message)"
    }
  }
}

#endregion

# Export public functions
Export-ModuleMember -Function @(
  'Get-FABConfiguration',
  'Export-FABFabricItemsAdvanced',
  'Export-FABWorkspaceMetadata',
  'Start-FABFabricArchiveProcess',
  'Remove-FABOldArchives',
  'Send-FABArchiveNotification',
  'Confirm-FABConfigurationCompatibility',
  'Invoke-FABWorkspaceFilter',
  'Invoke-FABItemFilter',
  'Get-FABOptimalThrottleLimit',
  'Invoke-FABRateLimitedOperation',
  'Export-FABItemDefinitionDirect',
  'Get-FABFabricWorkspaces',
  'Get-FABFabricWorkspaceById',
  'Get-FABFabricItemsByWorkspace',
  'Get-FABSupportedItemTypes',
  'Find-FABDefinitionEndpoints',
  'Get-FABFallbackItemTypes',
  'Test-FABFabricPSPBIPAvailability',
  'Initialize-FABFabricConnection',
  'Initialize-FABLogging',
  'Write-FABLog',
  'Start-FABOperation',
  'Complete-FABOperation',
  'Get-FABLogSummary',
  'Export-FABLogSummary'
)
