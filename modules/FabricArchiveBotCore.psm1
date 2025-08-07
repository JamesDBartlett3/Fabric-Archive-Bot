<#
.SYNOPSIS
Core module for Fabric Archive Bot v2.0 using FabricPS-PBIP

.DESCRIPTION
This module provides enhanced archiving capabilities using the FabricPS-PBIP PowerShell module
while maintaining backward compatibility with v1.0 functionality.
#>

#region Private Functions

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
  
  $retryCount = 0
  $maxRetries = if ($Config -and $Config.PSObject.Properties['FabricPSPBIPSettings'] -and $Config.FabricPSPBIPSettings.PSObject.Properties['RateLimitSettings'] -and $Config.FabricPSPBIPSettings.RateLimitSettings.MaxRetries) {
    $Config.FabricPSPBIPSettings.RateLimitSettings.MaxRetries
  }
  else { $MaxRetries }
  
  $baseDelay = if ($Config -and $Config.PSObject.Properties['FabricPSPBIPSettings'] -and $Config.FabricPSPBIPSettings.PSObject.Properties['RateLimitSettings'] -and $Config.FabricPSPBIPSettings.RateLimitSettings.RetryDelaySeconds) {
    $Config.FabricPSPBIPSettings.RateLimitSettings.RetryDelaySeconds
  }
  else { $BaseDelaySeconds }
  
  $backoffMultiplier = if ($Config -and $Config.PSObject.Properties['FabricPSPBIPSettings'] -and $Config.FabricPSPBIPSettings.PSObject.Properties['RateLimitSettings'] -and $Config.FabricPSPBIPSettings.RateLimitSettings.BackoffMultiplier) {
    $Config.FabricPSPBIPSettings.RateLimitSettings.BackoffMultiplier
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
  elseif ($Config.PSObject.Properties['FabricPSPBIPSettings'] -and $Config.FabricPSPBIPSettings.PSObject.Properties['ThrottleLimit'] -and $Config.FabricPSPBIPSettings.ThrottleLimit -gt 0) {
    $throttleLimit = $Config.FabricPSPBIPSettings.ThrottleLimit
    Write-Host "Using config throttle limit: $throttleLimit"
  }
  else {
    # Default to logical processor count, but cap at reasonable maximum
    $throttleLimit = [Math]::Min($logicalProcessors, 12)
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
    $moduleFileName = "FabricPS-PBIP.psm1"
    $possiblePaths = @(
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
    $workspace = Invoke-FabricAPIRequest -Uri "workspaces/$WorkspaceId" -Method Get
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
    $items = Invoke-FabricAPIRequest -Uri "workspaces/$WorkspaceId/items" -Method Get
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
    $workspaces = Invoke-FabricAPIRequest -Uri "workspaces" -Method Get
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
    # Note: Fabric API doesn't return 'state' property, so we treat all returned workspaces as 'Active'
    if ($Filter -match "state\s+eq\s+'([^']+)'") {
      $stateFilter = $matches[1]
      Write-Host "  - Filtering by state: $stateFilter"
      if ($stateFilter -eq 'Active') {
        # All workspaces returned by the API are considered active/accessible
        Write-Host "    (All returned workspaces are treated as Active)"
      }
      else {
        # If filtering for inactive workspaces, return empty since API only returns active ones
        Write-Host "    (Filtering out all workspaces since API only returns active ones)"
        $filteredWorkspaces = @()
      }
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
  
  $cacheFile = Join-Path $env:TEMP "FABSupportedItemTypes.json"
  $cacheValidUntil = (Get-Date).AddHours(-$CacheHours)
  
  try {
    # Check cache first if requested
    if ($UseCache -and (Test-Path $cacheFile)) {
      $cacheInfo = Get-Item $cacheFile
      if ($cacheInfo.LastWriteTime -gt $cacheValidUntil) {
        Write-Verbose "Using cached supported item types from $cacheFile"
        $cached = Get-Content $cacheFile -Raw | ConvertFrom-Json
        if ($cached -and $cached.Count -gt 0) {
          return $cached
        }
      }
    }
    
    Write-Verbose "Fetching supported item types from $TocUrl"
    
    # Fetch the TOC JSON
    $response = Invoke-RestMethod -Uri $TocUrl -Method Get -ErrorAction Stop
    
    # Find all "Get {xyz} Definition" entries and extract parent hierarchy
    $supportedTypes = @()
    if ($response.PSObject.Properties['items'] -and $response.items) {
      foreach ($item in $response.items) {
        $supportedTypes += Find-FABDefinitionEndpoints -Node $item -ParentPath @()
      }
    }
    else {
      # Fallback: treat response as a node directly
      $supportedTypes = Find-FABDefinitionEndpoints -Node $response -ParentPath @()
    }
    
    # Clean and validate results
    $cleanTypes = $supportedTypes | Where-Object { $_ -and $_.Trim() } | 
    ForEach-Object { $_.Trim() } | 
    Where-Object { $_ -notin @("Core", "Admin", "Spark") } |  # Filter out non-item types
    Sort-Object -Unique
    
    # Validate against known good types
    $knownTypes = @("Report", "SemanticModel", "Dataflow", "Notebook", "Environment")
    $hasKnownTypes = $cleanTypes | Where-Object { $_ -in $knownTypes }
    
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
  
  $results = @()
  
  # Get current node title
  $currentTitle = if ($Node.PSObject.Properties['toc_title']) { $Node.toc_title } else { "" }
  
  # Check if current node has a toc_title indicating a "Get {xyz} Definition" endpoint
  if ($currentTitle -and $currentTitle -match '^Get .+ Definition$') {
    Write-Verbose "Found potential definition endpoint: '$currentTitle', Parent path: $($ParentPath -join ' -> ')"
    
    # The item type should be extracted from the path
    # Looking for pattern: ItemType -> Items -> "Get ItemType Definition"
    if ($ParentPath.Count -ge 2 -and $ParentPath[-1] -eq "Items") {
      $itemType = $ParentPath[-2]  # The item type is the grandparent
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
      $newPath = if ($currentTitle) { $ParentPath + @($currentTitle) } else { $ParentPath }
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
  $ItemTypes = Get-FABSupportedItemTypes -UseCache
  
  # Filter out any user-configured item types that are not supported
  if ($Config.PSObject.Properties['ExportSettings'] -and 
    $Config.ExportSettings.PSObject.Properties['ItemTypes'] -and 
    $Config.ExportSettings.ItemTypes) {
    
    $configuredTypes = $Config.ExportSettings.ItemTypes
    $supportedConfigured = $configuredTypes | Where-Object { $_ -in $ItemTypes }
    $unsupportedTypes = $configuredTypes | Where-Object { $_ -notin $ItemTypes }
    
    if ($unsupportedTypes.Count -gt 0) {
      Write-Warning "The following configured item types are not supported for definition export: $($unsupportedTypes -join ', ')"
      Write-Host "Supported item types: $($ItemTypes -join ', ')" -ForegroundColor Green
      
      # Update configuration to remove unsupported types
      $Config.ExportSettings.ItemTypes = $supportedConfigured
      Write-Host "Updated configuration to use only supported types: $($supportedConfigured -join ', ')" -ForegroundColor Yellow
    }
  }
  
  $WorkspaceFilter = "(type eq 'Workspace') and (state eq 'Active')"

  # Ensure ExportSettings exists
  if (-not $Config.PSObject.Properties['ExportSettings']) {
    Write-Warning "ExportSettings not found in configuration. Adding default settings."
    $defaultTargetFolder = ".\Workspaces"
    # Optionally resolve to absolute path for clarity
    if ($defaultTargetFolder -notmatch '^[a-zA-Z]:\\') {
      $defaultTargetFolder = (Resolve-Path $defaultTargetFolder).Path
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
  $enableParallelProcessing = (-not $SerialProcessing.IsPresent) -and
  (-not ($Config.PSObject.Properties['FabricPSPBIPSettings'] -and $Config.FabricPSPBIPSettings.PSObject.Properties['ParallelProcessing'] -and -not $Config.FabricPSPBIPSettings.ParallelProcessing))
  
  # Get optimal throttle limit
  $actualThrottleLimit = Get-FABOptimalThrottleLimit -OverrideThrottleLimit $ThrottleLimit -Config $Config
  
  Write-Host "Parallel processing: $($enableParallelProcessing ? 'Enabled' : 'Disabled')" -ForegroundColor $(if ($enableParallelProcessing) { 'Green' } else { 'Yellow' })
  if ($enableParallelProcessing) {
    Write-Host "Throttle limit: $actualThrottleLimit" -ForegroundColor Green
  }
    
  # Get workspaces using FabricPS-PBIP
  if (-not $WorkspaceIds) {
    Write-Host "Retrieving workspaces based on configuration filter..."
    $workspaces = Invoke-FABRateLimitedOperation -Operation {
      Get-FABFabricWorkspaces
    } -Config $Config -OperationName "Get-FabricWorkspaces"
    
    # Ensure we have a valid array
    if (-not $workspaces) {
      $workspaces = @()
    }
    
    # Apply workspace filtering based on configuration
    if ($Config.ExportSettings.WorkspaceFilter) {
      $workspaces = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter $Config.ExportSettings.WorkspaceFilter
      # Ensure filtering result is valid
      if (-not $workspaces) {
        $workspaces = @()
      }
    }
    
    # Safely extract workspace IDs
    if ($workspaces -and $workspaces.Count -gt 0) {
      $WorkspaceIds = $workspaces.id
    }
    else {
      $WorkspaceIds = @()
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
  $allWorkspaceData = @()
  $totalItemCount = 0
  
  foreach ($workspaceId in $WorkspaceIds) {
    try {
      Write-Host "  - Gathering info for workspace: $workspaceId"
      
      $workspaceInfo = Invoke-FABRateLimitedOperation -Operation {
        Get-FABFabricWorkspaceById -WorkspaceId $workspaceId
      } -Config $Config -OperationName "Get-FabricWorkspace-$workspaceId"
      
      $items = Invoke-FABRateLimitedOperation -Operation {
        Get-FABFabricItemsByWorkspace -WorkspaceId $workspaceId
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
    
    # Get the rate limiting function definition dynamically for parallel execution
    $rateLimitedOperationFunction = Get-Command Invoke-FABRateLimitedOperation
    $rateLimitedOperationFunctionText = $rateLimitedOperationFunction.Definition
    
    # Get the FabricPS-PBIP module path to pass to parallel threads
    $moduleFileName = "FabricPS-PBIP.psm1"
    $fabricModulePath = $null
    $possiblePaths = @(
      (Join-Path -Path $PSScriptRoot -ChildPath "..\$moduleFileName"),
      (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath $moduleFileName)
    )
    
    foreach ($path in $possiblePaths) {
      if (Test-Path -Path $path) {
        $fabricModulePath = $path
        break
      }
    }
    
    if (-not $fabricModulePath) {
      throw "FabricPS-PBIP module path not found for parallel processing"
    }
    
    $allItemJobs | ForEach-Object -Parallel {
      $itemJob = $_
      $Config = $using:Config
      $functionText = $using:rateLimitedOperationFunctionText
      $modulePath = $using:fabricModulePath
      
      try {
        # Import FabricPS-PBIP module in parallel thread
        Import-Module -Name $modulePath -Force
        
        # Define the rate limiting function in this thread scope
        $functionDefinition = "function Invoke-FABRateLimitedOperation { $functionText }"
        Invoke-Expression $functionDefinition
        
        $threadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        Write-Host "Exporting item '$($itemJob.Item.displayName)' from workspace '$($itemJob.WorkspaceInfo.displayName)' (Thread: $threadId)"
        
        # Create item-specific folder
        $itemFolderName = "$($itemJob.Item.displayName).$($itemJob.Item.type)"
        $itemFolder = Join-Path -Path $itemJob.WorkspaceFolder -ChildPath $itemFolderName
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
    
    $currentWorkspace = ""
    foreach ($itemJob in $allItemJobs) {
      try {
        # Show workspace context when we switch workspaces
        if ($currentWorkspace -ne $itemJob.WorkspaceInfo.displayName) {
          $currentWorkspace = $itemJob.WorkspaceInfo.displayName
          Write-Host "Processing workspace: $currentWorkspace" -ForegroundColor Cyan
        }
        
        Write-Host "  - Exporting: $($itemJob.Item.displayName)"
        
        # Create item-specific folder
        $itemFolderName = "$($itemJob.Item.displayName).$($itemJob.Item.type)"
        $itemFolder = Join-Path -Path $itemJob.WorkspaceFolder -ChildPath $itemFolderName
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
  $consolidatedMetadata = @{
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
    $workspaceMetadata = @{
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
  $metadataPath = Join-Path -Path $TargetFolder -ChildPath "fabric-archive-metadata.json"
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
    # Load configuration from file
    $Config = Get-Content -Path $ConfigPath | ConvertFrom-Json
    Write-Host "Configuration loaded from: $ConfigPath" -ForegroundColor Green
  }
  
  # Ensure configuration compatibility
  $Config = Confirm-FABConfigurationCompatibility -Config $Config
    
  # Validate version compatibility
  if ($Config.Version -lt "2.0") {
    Write-Warning "Configuration version $($Config.Version) detected. Consider upgrading to v2.0 format."
  }
    
  # Setup target folder with date hierarchy
  $date = Get-Date
  $dateFolder = Join-Path -Path $Config.ExportSettings.TargetFolder -ChildPath ("{0}\{1:D2}\{2:D2}" -f $date.Year, $date.Month, $date.Day)
    
  if (-not (Test-Path $dateFolder)) {
    New-Item -Path $dateFolder -ItemType Directory -Force | Out-Null
  }
    
  # Start export process
  Export-FABFabricItemsAdvanced -Config $Config -TargetFolder $dateFolder -SerialProcessing:$SerialProcessing -ThrottleLimit $ThrottleLimit
    
  # Cleanup old archives
  Remove-FABOldArchives -Config $Config
    
  # Send notifications if configured
  if ($Config.NotificationSettings.EnableNotifications) {
    Send-FABArchiveNotification -Config $Config -ArchiveFolder $dateFolder
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

Powered by FabricPS-PBIP (Credit: Rui Romano)
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
  'Invoke-FABRateLimitedOperation',
  'Export-FABItemDefinitionDirect',
  'Get-FABFabricWorkspaces',
  'Get-FABFabricWorkspaceById',
  'Get-FABFabricItemsByWorkspace',
  'Get-FABSupportedItemTypes',
  'Find-FABDefinitionEndpoints',
  'Get-FABFallbackItemTypes',
  'Test-FABFabricPSPBIPAvailability',
  'Initialize-FABFabricConnection'
)
