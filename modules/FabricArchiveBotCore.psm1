using module FabricTools

<#
.SYNOPSIS
Core module for Fabric Archive Bot v2.0 using FabricTools

.DESCRIPTION
This module provides enhanced archiving capabilities using the FabricTools PowerShell module
while maintaining backward compatibility with v1.0 functionality.
#>

#region Private Functions

function Invoke-FABRateLimitedOperation {
  <#
  .SYNOPSIS
  Executes operations with built-in rate limiting and retry logic
  
  .DESCRIPTION
  Wraps FabricTools operations with enhanced rate limiting handling, retry logic, and monitoring
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
  
  $retryCount = 0
  $maxRetries = if ($Config -and $Config.FabricToolsSettings.RateLimitSettings.MaxRetries) {
    $Config.FabricToolsSettings.RateLimitSettings.MaxRetries
  }
  else { $MaxRetries }
  
  $baseDelay = if ($Config -and $Config.FabricToolsSettings.RateLimitSettings.RetryDelaySeconds) {
    $Config.FabricToolsSettings.RateLimitSettings.RetryDelaySeconds
  }
  else { $BaseDelaySeconds }
  
  $backoffMultiplier = if ($Config -and $Config.FabricToolsSettings.RateLimitSettings.BackoffMultiplier) {
    $Config.FabricToolsSettings.RateLimitSettings.BackoffMultiplier
  }
  else { 2 }
  
  do {
    try {
      Write-Host "Executing $OperationName$(if ($retryCount -gt 0) { " (Retry $retryCount/$maxRetries)" })" -ForegroundColor Gray
      return & $Operation
    }
    catch {
      $retryCount++
      
      # Check if this is a rate limiting error (429)
      if ($_.Exception.Message -match "429|rate.limit|throttl" -or $_.Exception.Message -match "Too Many Requests") {
        if ($retryCount -le $maxRetries) {
          $delaySeconds = $baseDelay * [Math]::Pow($backoffMultiplier, $retryCount - 1)
          Write-Warning "Rate limit encountered for $OperationName. Waiting $delaySeconds seconds before retry $retryCount/$maxRetries..."
          Start-Sleep -Seconds $delaySeconds
          continue
        }
        else {
          Write-Error "Rate limit exceeded for $OperationName after $maxRetries retries. Operation failed."
          throw
        }
      }
      # Check for other retryable errors
      elseif ($_.Exception.Message -match "503|502|timeout|connection" -and $retryCount -le $maxRetries) {
        $delaySeconds = $baseDelay
        Write-Warning "Transient error for $OperationName. Waiting $delaySeconds seconds before retry $retryCount/$maxRetries..."
        Start-Sleep -Seconds $delaySeconds
        continue
      }
      else {
        # Non-retryable error or max retries exceeded
        Write-Error "Non-retryable error for $OperationName or max retries exceeded: $($_.Exception.Message)"
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
  $logicalProcessors = (Get-CimInstance -ClassName Win32_ComputerSystem).NumberOfLogicalProcessors
  
  # Determine throttle limit from various sources (priority order)
  if ($OverrideThrottleLimit -gt 0) {
    $throttleLimit = $OverrideThrottleLimit
    Write-Host "Using runtime override throttle limit: $throttleLimit"
  }
  elseif ($Config.FabricToolsSettings.PSObject.Properties['ThrottleLimit'] -and $Config.FabricToolsSettings.ThrottleLimit -gt 0) {
    $throttleLimit = $Config.FabricToolsSettings.ThrottleLimit
    Write-Host "Using config throttle limit: $throttleLimit"
  }
  else {
    # Default to logical processor count, but cap at reasonable maximum
    $throttleLimit = [Math]::Min($logicalProcessors, 12)
    Write-Host "Using auto-detected throttle limit: $throttleLimit (based on $logicalProcessors logical processors)"
  }
  
  return $throttleLimit
}

function Test-FABFabricToolsAvailability {
  [CmdletBinding()]
  param()
    
  try {
    if (-not (Get-Module -Name FabricTools -ListAvailable)) {
      Write-Warning "FabricTools module not found. Installing from PowerShell Gallery..."
      Install-Module -Name FabricTools -Scope CurrentUser -Force
    }
    Import-Module -Name FabricTools -Force
    return $true
  }
  catch {
    Write-Error "Failed to load FabricTools module: $($_.Exception.Message)"
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
    if ($Config.ServicePrincipal.AppId -and $Config.ServicePrincipal.AppSecret -and $Config.ServicePrincipal.TenantId) {
      # Use Service Principal authentication with FabricTools
      Connect-FabricAccount -ServicePrincipal -TenantId $Config.ServicePrincipal.TenantId -ClientId $Config.ServicePrincipal.AppId -ClientSecret $Config.ServicePrincipal.AppSecret
    }
    else {
      # Use interactive authentication
      Connect-FabricAccount
    }
    return $true
  }
  catch {
    Write-Error "Failed to connect to Fabric: $($_.Exception.Message)"
    return $false
  }
}

function Invoke-FABWorkspaceFilter {
  <#
  .SYNOPSIS
  Applies workspace filtering based on configuration filter string
  
  .DESCRIPTION
  Parses OData-style filter expressions and applies them to workspace collections.
  Supports filtering by state, type, and name patterns.
  
  .PARAMETER Workspaces
  The array of workspace objects to filter
  
  .PARAMETER Filter
  The filter expression in OData style format
  
  .EXAMPLE
  $filtered = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter "(state eq 'Active')"
  
  .EXAMPLE
  $filtered = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter "(type eq 'Workspace') and (state eq 'Active')"
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
    $filteredWorkspaces = $Workspaces
    
    # Handle state filtering - matches: state eq 'Active', state eq 'Inactive'
    if ($Filter -match "state\s+eq\s+'([^']+)'") {
      $stateFilter = $matches[1]
      Write-Host "  - Filtering by state: $stateFilter"
      $filteredWorkspaces = $filteredWorkspaces | Where-Object { $_.state -eq $stateFilter }
    }
    
    # Handle type filtering - matches: type eq 'Workspace'
    if ($Filter -match "type\s+eq\s+'([^']+)'") {
      $typeFilter = $matches[1]
      Write-Host "  - Filtering by type: $typeFilter"
      $filteredWorkspaces = $filteredWorkspaces | Where-Object { $_.type -eq $typeFilter }
    }
    
    # Handle name contains filtering - matches: contains(name,'pattern')
    if ($Filter -match "contains\s*\(\s*name\s*,\s*'([^']+)'\s*\)") {
      $namePattern = $matches[1]
      Write-Host "  - Filtering by name pattern: $namePattern"
      $filteredWorkspaces = $filteredWorkspaces | Where-Object { $_.displayName -like "*$namePattern*" }
    }
    
    # Handle name starts with filtering - matches: startswith(name,'pattern')
    if ($Filter -match "startswith\s*\(\s*name\s*,\s*'([^']+)'\s*\)") {
      $namePattern = $matches[1]
      Write-Host "  - Filtering by name starts with: $namePattern"
      $filteredWorkspaces = $filteredWorkspaces | Where-Object { $_.displayName -like "$namePattern*" }
    }
    
    # Handle name ends with filtering - matches: endswith(name,'pattern')
    if ($Filter -match "endswith\s*\(\s*name\s*,\s*'([^']+)'\s*\)") {
      $namePattern = $matches[1]
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

function Confirm-FABConfigurationCompatibility {
  <#
  .SYNOPSIS
  Ensures configuration compatibility between v1.0 and v2.0 formats
  
  .DESCRIPTION
  Validates and enhances configuration to ensure all required settings are present
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config
  )
  
  # Ensure ExportSettings exists
  if (-not $Config.PSObject.Properties['ExportSettings']) {
    Write-Warning "ExportSettings not found in configuration. Adding default settings."
    $Config | Add-Member -MemberType NoteProperty -Name 'ExportSettings' -Value ([PSCustomObject]@{
        TargetFolder    = ".\Workspaces"
        RetentionDays   = 30
        WorkspaceFilter = "(type eq 'Workspace') and (state eq 'Active')"
        ItemTypes       = @("Report", "SemanticModel", "Notebook", "SparkJobDefinition")
      })
  }
  
  # Ensure WorkspaceFilter exists in ExportSettings
  if (-not $Config.ExportSettings.PSObject.Properties['WorkspaceFilter']) {
    Write-Warning "WorkspaceFilter not found in ExportSettings. Using default filter."
    $Config.ExportSettings | Add-Member -MemberType NoteProperty -Name 'WorkspaceFilter' -Value "(type eq 'Workspace') and (state eq 'Active')"
  }
  
  # Ensure ItemTypes exists in ExportSettings
  if (-not $Config.ExportSettings.PSObject.Properties['ItemTypes']) {
    Write-Warning "ItemTypes not found in ExportSettings. Using default item types."
    $Config.ExportSettings | Add-Member -MemberType NoteProperty -Name 'ItemTypes' -Value @("Report", "SemanticModel", "Notebook", "SparkJobDefinition")
  }
  
  return $Config
}

#endregion

#region Public Functions

function Export-FABFabricItemsAdvanced {
  <#
    .SYNOPSIS
    Enhanced export function using FabricTools capabilities
    
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
    [switch]$UseParallelProcessing,
    
    [Parameter()]
    [int]$ThrottleLimit = 0
  )
    
  # Initialize FabricTools connection
  if (-not (Initialize-FABFabricConnection -Config $Config)) {
    throw "Failed to initialize Fabric connection"
  }
  
  # Determine if parallel processing should be enabled
  $enableParallelProcessing = $UseParallelProcessing.IsPresent -or 
  ($Config.FabricToolsSettings.PSObject.Properties['ParallelProcessing'] -and $Config.FabricToolsSettings.ParallelProcessing) -or
  ($PSVersionTable.PSVersion.Major -ge 7 -and -not $UseParallelProcessing.IsPresent)
  
  # Check PowerShell version for parallel processing
  if ($enableParallelProcessing -and $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "Parallel processing requires PowerShell 7+. Falling back to sequential processing."
    $enableParallelProcessing = $false
  }
  
  # Get optimal throttle limit
  $actualThrottleLimit = Get-FABOptimalThrottleLimit -OverrideThrottleLimit $ThrottleLimit -Config $Config
  
  Write-Host "Parallel processing: $($enableParallelProcessing ? 'Enabled' : 'Disabled')" -ForegroundColor $(if ($enableParallelProcessing) { 'Green' } else { 'Yellow' })
  if ($enableParallelProcessing) {
    Write-Host "Throttle limit: $actualThrottleLimit" -ForegroundColor Green
  }
    
  # Get workspaces using FabricTools
  if (-not $WorkspaceIds) {
    Write-Host "Retrieving workspaces based on configuration filter..."
    $workspaces = Invoke-FABRateLimitedOperation -Operation {
      Get-FabricWorkspace
    } -Config $Config -OperationName "Get-FabricWorkspace"
    
    # Apply workspace filtering based on configuration
    if ($Config.ExportSettings.WorkspaceFilter) {
      $workspaces = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter $Config.ExportSettings.WorkspaceFilter
    }
    
    $WorkspaceIds = $workspaces.id
  }
    
  Write-Host "Found $($WorkspaceIds.Count) workspaces to process"
  
  # Collect all workspace info and items first
  Write-Host "Gathering workspace information and item inventories..." -ForegroundColor Cyan
  $allWorkspaceData = @()
  $totalItemCount = 0
  
  foreach ($workspaceId in $WorkspaceIds) {
    try {
      Write-Host "  - Gathering info for workspace: $workspaceId"
      
      $workspaceInfo = Invoke-FABRateLimitedOperation -Operation {
        Get-FabricWorkspace -WorkspaceId $workspaceId
      } -Config $Config -OperationName "Get-FabricWorkspace-$workspaceId"
      
      $items = Invoke-FABRateLimitedOperation -Operation {
        Get-FabricItem -WorkspaceId $workspaceId
      } -Config $Config -OperationName "Get-FabricItem-$workspaceId"
      
      $filteredItems = $items | Where-Object { $_.type -in $Config.ExportSettings.ItemTypes }
      $totalItemCount += $filteredItems.Count
      
      # Create workspace folder structure
      $workspaceFolder = Join-Path -Path $TargetFolder -ChildPath $workspaceInfo.displayName
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
  $allItemJobs = @()
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
    
    # Capture the rate limiting function definition for parallel execution
    # This is critical because parallel threads run in isolated runspaces and don't have access
    # to functions defined in the parent module unless explicitly passed
    $rateLimitedOperationFunction = ${function:Invoke-FABRateLimitedOperation}
    
    $allItemJobs | ForEach-Object -Parallel {
      $itemJob = $_
      $Config = $using:Config
      $InvokeRateLimitedOperation = $using:rateLimitedOperationFunction
      
      try {
        # Import FabricTools module in parallel thread
        Import-Module -Name FabricTools -Force
        
        # Define the rate limiting function in this thread scope
        ${function:Invoke-FABRateLimitedOperation} = $InvokeRateLimitedOperation
        
        $threadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        Write-Host "Exporting item '$($itemJob.Item.displayName)' from workspace '$($itemJob.WorkspaceInfo.displayName)' (Thread: $threadId)"
        
        # Verify function is available before use
        if (-not (Get-Command Invoke-FABRateLimitedOperation -ErrorAction SilentlyContinue)) {
          throw "Rate limiting function not available in parallel thread"
        }
        
        # Export the item with rate limiting
        Invoke-FABRateLimitedOperation -Operation {
          Export-FabricItem -WorkspaceId $itemJob.WorkspaceId -itemID $itemJob.Item.id -path $itemJob.WorkspaceFolder
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
    
    $currentWorkspace = ""
    foreach ($itemJob in $allItemJobs) {
      try {
        # Show workspace context when we switch workspaces
        if ($currentWorkspace -ne $itemJob.WorkspaceInfo.displayName) {
          $currentWorkspace = $itemJob.WorkspaceInfo.displayName
          Write-Host "Processing workspace: $currentWorkspace" -ForegroundColor Cyan
        }
        
        Write-Host "  - Exporting: $($itemJob.Item.displayName)"
        
        Invoke-FABRateLimitedOperation -Operation {
          Export-FabricItem -WorkspaceId $itemJob.WorkspaceId -itemID $itemJob.Item.id -path $itemJob.WorkspaceFolder
        } -Config $Config -OperationName "Export-FabricItem-$($itemJob.Item.id)"
      }
      catch {
        Write-Error "Failed to export item '$($itemJob.Item.displayName)' from workspace '$($itemJob.WorkspaceInfo.displayName)': $($_.Exception.Message)"
      }
    }
  }
  
  # Generate metadata for all workspaces after item processing is complete
  Write-Host "Generating workspace metadata files..." -ForegroundColor Cyan
  foreach ($workspaceData in $allWorkspaceData) {
    try {
      Export-FABWorkspaceMetadata -WorkspaceId $workspaceData.WorkspaceId -TargetFolder $workspaceData.WorkspaceFolder -Config $Config
      Write-Host "  ✓ Metadata generated for: $($workspaceData.WorkspaceInfo.displayName)" -ForegroundColor Green
    }
    catch {
      Write-Error "Failed to generate metadata for workspace '$($workspaceData.WorkspaceInfo.displayName)': $($_.Exception.Message)"
    }
  }
}

function Export-FABWorkspaceMetadata {
  <#
    .SYNOPSIS
    Exports enhanced metadata for a workspace using FabricTools capabilities
    #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceId,
        
    [Parameter(Mandatory = $true)]
    [string]$TargetFolder,
        
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config
  )
    
  $metadata = @{
    ExportTimestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
    WorkspaceInfo   = Invoke-FABRateLimitedOperation -Operation {
      Get-FabricWorkspace -WorkspaceId $WorkspaceId
    } -Config $Config -OperationName "Get-FabricWorkspace-Metadata-$WorkspaceId"
    Items           = Invoke-FABRateLimitedOperation -Operation {
      Get-FabricItem -WorkspaceId $WorkspaceId
    } -Config $Config -OperationName "Get-FabricItem-Metadata-$WorkspaceId"
    ExportConfig    = $Config.ExportSettings
  }
    
  # Add advanced metadata if enabled
  if ($Config.AdvancedFeatures.EnableUsageMetrics) {
    try {
      $metadata.UsageMetrics = Invoke-FABRateLimitedOperation -Operation {
        Get-FabricWorkspaceUsageMetricsData -WorkspaceId $WorkspaceId
      } -Config $Config -OperationName "Get-FabricWorkspaceUsageMetricsData-$WorkspaceId"
    }
    catch {
      Write-Warning "Could not retrieve usage metrics for workspace $WorkspaceId : $($_.Exception.Message)"
    }
  }
    
  # Export metadata as JSON
  $metadataPath = Join-Path -Path $TargetFolder -ChildPath "workspace-metadata.json"
  $metadata | ConvertTo-Json -Depth 10 | Out-File -FilePath $metadataPath -Encoding UTF8
}

function Start-FABFabricArchiveProcess {
  <#
    .SYNOPSIS
    Main orchestration function for the archive process
    #>
  [CmdletBinding()]
  param(
    [Parameter()]
    [string]$ConfigPath = ".\FabricArchiveBot_Config.json",
    
    [Parameter()]
    [switch]$UseParallelProcessing,
    
    [Parameter()]
    [int]$ThrottleLimit = 0
  )
    
  # Test FabricTools availability
  if (-not (Test-FABFabricToolsAvailability)) {
    throw "FabricTools module is required but not available"
  }
    
  # Load configuration
  $config = Get-Content -Path $ConfigPath | ConvertFrom-Json
  
  # Ensure configuration compatibility
  $config = Confirm-FABConfigurationCompatibility -Config $config
    
  # Validate version compatibility
  if ($config.Version -lt "2.0") {
    Write-Warning "Configuration version $($config.Version) detected. Consider upgrading to v2.0 format."
  }
    
  # Setup target folder with date hierarchy
  $date = Get-Date
  $dateFolder = Join-Path -Path $config.ExportSettings.TargetFolder -ChildPath ("{0}\{1:D2}\{2:D2}" -f $date.Year, $date.Month, $date.Day)
    
  if (-not (Test-Path $dateFolder)) {
    New-Item -Path $dateFolder -ItemType Directory -Force | Out-Null
  }
    
  # Start export process
  Export-FABFabricItemsAdvanced -Config $config -TargetFolder $dateFolder -UseParallelProcessing:$UseParallelProcessing -ThrottleLimit $ThrottleLimit
    
  # Cleanup old archives
  Remove-FABOldArchives -Config $config
    
  # Send notifications if configured
  if ($config.NotificationSettings.EnableNotifications) {
    Send-FABArchiveNotification -Config $config -ArchiveFolder $dateFolder
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
    
  $cutoffDate = (Get-Date).AddDays(-$Config.ExportSettings.RetentionDays)
  $targetFolder = $Config.ExportSettings.TargetFolder
    
  Write-Host "Cleaning up archives older than $($cutoffDate.ToString('yyyy-MM-dd'))"
    
  $oldFolders = Get-ChildItem -Path $targetFolder -Directory -Recurse | 
  Where-Object { $_.CreationTime -lt $cutoffDate -and $_.FullName -ne $targetFolder }
    
  $totalSize = 0
  foreach ($folder in $oldFolders) {
    $folderSize = (Get-ChildItem -Path $folder.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $totalSize += $folderSize
    Write-Host "Removing old archive: $($folder.FullName) ($(($folderSize / 1MB).ToString('F2')) MB)"
    Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue
  }
    
  Write-Host "Cleanup completed. Freed $(($totalSize / 1MB).ToString('F2')) MB of disk space."
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
    
  $archiveSize = (Get-ChildItem -Path $ArchiveFolder -Recurse -File | Measure-Object -Property Length -Sum).Sum
  $itemCount = (Get-ChildItem -Path $ArchiveFolder -Recurse -File | Measure-Object).Count
    
  $message = @"
Fabric Archive Bot v2.0 - Archive Completed

Archive Location: $ArchiveFolder
Items Archived: $itemCount
Total Size: $(($archiveSize / 1MB).ToString('F2')) MB
Completion Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Powered by FabricTools and Fabric Archive Bot v2.0
"@
    
  # Implementation for Teams webhook, email, etc. would go here
  Write-Host $message
}

#endregion

# Export public functions
Export-ModuleMember -Function @(
  'Export-FABFabricItemsAdvanced',
  'Export-FABWorkspaceMetadata',
  'Start-FABFabricArchiveProcess',
  'Remove-FABOldArchives',
  'Send-FABArchiveNotification',
  'Confirm-FABConfigurationCompatibility',
  'Invoke-FABWorkspaceFilter',
  'Get-FABOptimalThrottleLimit',
  'Invoke-FABRateLimitedOperation'
)
