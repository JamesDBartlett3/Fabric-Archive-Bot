<#
.SYNOPSIS 
  Starts the Fabric Archive Bot to export all items from Fabric/Power BI workspaces

.DESCRIPTION
  This is the main entry point for Fabric Archive Bot v2.0, powered by FabricPS-PBIP (Credit: Rui Romano).
  Provides advanced features like parallel processing, enhanced metadata export, 
  multiple export formats, comprehensive monitoring, and configurable workspace filtering.

.PARAMETER ConfigPath
  Path to the configuration file. Defaults to FabricArchiveBot_Config.json in the script directory.

.PARAMETER ConfigFromEnv
  Load configuration from the FabricArchiveBot_ConfigObject environment variable instead of a file.

.PARAMETER WorkspaceFilter
  Override the workspace filter from configuration.

.PARAMETER TargetFolder
  Override the target folder from configuration.

.PARAMETER SerialProcessing
  Disable parallel processing and run exports in serial mode.

.PARAMETER ThrottleLimit
  Maximum number of concurrent workspace processing threads. Defaults to CPU core count.

.INPUTS
  None - Pipeline input is not accepted.

.OUTPUTS
  None - Pipeline output is not produced.

.EXAMPLE
  .\Start-FabricArchiveBot.ps1

  Runs with default configuration settings.

.EXAMPLE
  .\Start-FabricArchiveBot.ps1 -ConfigPath ".\Config-Production.json" -SerialProcessing

  Runs with custom configuration and serial processing (parallel processing disabled).

.EXAMPLE
  .\Start-FabricArchiveBot.ps1 -ConfigFromEnv

  Runs using configuration loaded from the FabricArchiveBot_ConfigObject environment variable. Note: This requires the environment variable to be set up beforehand (Tip: Use the provided Set-FabricArchiveBotUserEnvironmentVariable.ps1 script).

.EXAMPLE
  .\Start-FabricArchiveBot.ps1 -WhatIf

  Shows what would be exported without performing the actual export.

.EXAMPLE
  .\Start-FabricArchiveBot.ps1 -WorkspaceFilter "(state eq 'Active') and contains(name,'Production')"

  Runs with a custom workspace filter to only process active workspaces with 'Production' in the name.

.LINK
  [Source code](https://github.com/JamesDBartlett3/Fabric-Archive-Bot)

.LINK
  [FabricPS-PBIP Module](https://github.com/microsoft/Analysis-Services/tree/master/pbidevmode/fabricps-pbip)

.NOTES
  Requires PowerShell 7+
  Requires FabricPS-PBIP module (will be downloaded automatically if missing)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter()]
  [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'FabricArchiveBot_Config.json'),
    
  [Parameter()]
  [switch]$ConfigFromEnv,
    
  [Parameter()]
  [string]$WorkspaceFilter,
    
  [Parameter()]
  [string]$TargetFolder,
    
  [Parameter()]
  [switch]$SerialProcessing,
    
  [Parameter()]
  [int]$ThrottleLimit = 0
)

# Script metadata
[string]$ScriptVersion = "2.0.0"
[string]$ScriptName = "Fabric Archive Bot v2.0"

Write-Host "$ScriptName - Version $ScriptVersion" -ForegroundColor Green
Write-Host "Enhanced with FabricPS-PBIP integration" -ForegroundColor Cyan
Write-Host ("=" * 50)

#region Prerequisites and Validation

# Check PowerShell version - require PowerShell 7+
if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Error "This solution requires PowerShell 7 or later. Please upgrade to PowerShell 7+ and try again."
  Write-Host "Download PowerShell 7+ from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Yellow
  exit 1
}

# Validate configuration source and load configuration
if ($ConfigFromEnv) {
  # Load configuration from environment variable
  [string]$envConfig = [System.Environment]::GetEnvironmentVariable("FabricArchiveBot_ConfigObject", "User")
  
  if (-not $envConfig) {
    Write-Error "FabricArchiveBot_ConfigObject environment variable not found or is empty."
    Write-Host "Please run the Set-FabricArchiveBotUserEnvironmentVariable.ps1 script first to set up the environment variable."
    exit 1
  }
  
  try {
    [PSCustomObject]$config = $envConfig | ConvertFrom-Json
    Write-Host "Configuration loaded from environment variable" -ForegroundColor Green
  }
  catch {
    Write-Error "Failed to parse configuration from environment variable: $($_.Exception.Message)"
    Write-Host "The environment variable may contain invalid JSON. Please run Set-FabricArchiveBotUserEnvironmentVariable.ps1 again."
    exit 1
  }
}
else {
  # Load configuration from file
  if (-not (Test-Path -Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    Write-Host "Please ensure your configuration file exists or run with -ConfigPath parameter, or use -ConfigFromEnv to load from environment variable."
    exit 1
  }
  
  try {
    [PSCustomObject]$config = Get-Content -Path $ConfigPath | ConvertFrom-Json
    Write-Host "Configuration loaded from: $ConfigPath" -ForegroundColor Green
  }
  catch {
    Write-Error "Failed to load configuration: $($_.Exception.Message)"
    exit 1
  }
}

# Override configuration with parameters if provided
if ($WorkspaceFilter) { $config.ExportSettings.WorkspaceFilter = $WorkspaceFilter }
if ($TargetFolder) { $config.ExportSettings.TargetFolder = $TargetFolder }

#endregion

#region Module Management

# Import core module
[string]$coreModulePath = Join-Path -Path $PSScriptRoot -ChildPath "modules\FabricArchiveBotCore.psm1"

if (Test-Path -Path $coreModulePath) {
  Write-Host "Loading Fabric Archive Bot Core module..." -ForegroundColor Cyan
  try {
    Import-Module -Name $coreModulePath -Force
    Write-Host "Core module loaded successfully" -ForegroundColor Green
    
    # Ensure configuration compatibility now that core module is loaded
    try {
      [PSCustomObject]$config = Confirm-FABConfigurationCompatibility -Config $config
      Write-Host "Configuration compatibility validated" -ForegroundColor Green
    }
    catch {
      Write-Error "Configuration compatibility check failed: $($_.Exception.Message)"
      exit 1
    }
  }
  catch {
    Write-Error "Failed to import core module: $($_.Exception.Message)"
    exit 1
  }
}
else {
  Write-Error "Core module not found: $coreModulePath"
  exit 1
}

# Test FabricPS-PBIP availability and download if needed
try {
  # Handle potential Azure module conflicts before loading FabricPS-PBIP
  Write-Host "Checking for Azure module conflicts..." -ForegroundColor Cyan
  
  # Get all loaded Azure modules
  [Microsoft.PowerShell.Commands.ModuleInfoGrouping[]]$loadedAzModules = Get-Module -Name "Az.*"
  if ($loadedAzModules) {
    Write-Host "Found loaded Azure modules that may cause conflicts: $($loadedAzModules.Name -join ', ')" -ForegroundColor Yellow
    Write-Host "Removing all Azure modules to prevent assembly conflicts..." -ForegroundColor Yellow
    
    # Remove all Azure modules
    $loadedAzModules | Remove-Module -Force -ErrorAction SilentlyContinue
    
    # Force garbage collection to help clear assemblies
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    Write-Host "Azure modules cleared successfully" -ForegroundColor Green
  }
  else {
    Write-Host "No conflicting Azure modules found" -ForegroundColor Green
  }

  # Ensure NuGet package provider is available (required for FabricPS-PBIP dependencies)
  if (-not ((Get-PackageProvider).Name -contains 'NuGet')) {
    Write-Host "Registering NuGet package provider..." -ForegroundColor Yellow
    Register-PackageSource -Name 'NuGet.org' -Location 'https://api.nuget.org/v3/index.json' -ProviderName 'NuGet'
  }
  
  # Define module URL and local path
  [string]$moduleUrl = 'https://raw.githubusercontent.com/microsoft/Analysis-Services/master/pbidevmode/fabricps-pbip/FabricPS-PBIP.psm1'
  [string]$moduleFileName = Split-Path -Leaf $moduleUrl
  [string]$localModulePath = Join-Path -Path $PSScriptRoot -ChildPath $moduleFileName
  
  # Download latest FabricPS-PBIP.psm1 if it doesn't exist or if we want the latest
  if (-not (Test-Path -Path $localModulePath)) {
    Write-Host "FabricPS-PBIP module not found. Downloading from GitHub..." -ForegroundColor Yellow
    try {
      Invoke-WebRequest -Uri $moduleUrl -OutFile $localModulePath
      Unblock-File -Path $localModulePath
      Write-Host "FabricPS-PBIP module downloaded successfully" -ForegroundColor Green
    }
    catch {
      Write-Error "Failed to download FabricPS-PBIP module: $($_.Exception.Message)"
      throw
    }
  }
  
  # Ensure required Az modules are available
  [string[]]$requiredModules = @('Az.Accounts', 'Az.Resources')
  foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
      Write-Host "Installing required module: $module" -ForegroundColor Yellow
      Install-Module -Name $module -Scope CurrentUser -Force
    }
  }
  
  # Import the FabricPS-PBIP module
  Import-Module -Name $localModulePath -Force
  Write-Host "FabricPS-PBIP module loaded successfully" -ForegroundColor Green
}
catch {
  Write-Error "Failed to load FabricPS-PBIP module: $($_.Exception.Message)"
  Write-Error "FabricPS-PBIP module is required for operation. Cannot proceed."
  exit 1
}

#endregion

#region Main Execution

try {
  Write-Host "Starting Fabric Archive Process..." -ForegroundColor Green
  Write-Host "Target Folder: $($config.ExportSettings.TargetFolder)" -ForegroundColor Cyan
  Write-Host "Retention Days: $($config.ExportSettings.RetentionDays)" -ForegroundColor Cyan
  Write-Host "Parallel Processing: $(if ($SerialProcessing) { 'Disabled' } else { 'Enabled (Default)' })" -ForegroundColor Cyan
    
  if ($WhatIfPreference) {
    Write-Host "WHAT-IF MODE: No actual changes will be made" -ForegroundColor Yellow
        
    # Connect to Fabric for discovery using FabricPS-PBIP
    if ($config.ServicePrincipal.AppId -and $config.ServicePrincipal.AppSecret -and $config.ServicePrincipal.TenantId) {
      # Use service principal authentication
      Set-FabricAuthToken -servicePrincipalId $config.ServicePrincipal.AppId -servicePrincipalSecret $config.ServicePrincipal.AppSecret -tenantId $config.ServicePrincipal.TenantId
    }
    else {
      # Use interactive authentication
      Set-FabricAuthToken
    }
        
    # Discovery mode - get workspaces using FabricPS-PBIP
    [array]$allWorkspaces = Invoke-FabricAPIRequest -Uri "workspaces" -Method Get
        
    # Apply workspace filtering based on configuration
    if ($config.ExportSettings.WorkspaceFilter) {
      [array]$workspaces = Invoke-FABWorkspaceFilter -Workspaces $allWorkspaces -Filter $config.ExportSettings.WorkspaceFilter
    }
    else {
      [array]$workspaces = $allWorkspaces
    }
        
    Write-Host "`nWould process $($workspaces.Count) workspaces matching filter '$($config.ExportSettings.WorkspaceFilter)':" -ForegroundColor Yellow
        
    foreach ($workspace in $workspaces | Select-Object -First 10) {
      # Get items using FabricPS-PBIP API call pattern
      [array]$items = Invoke-FabricAPIRequest -Uri "workspaces/$($workspace.id)/items" -Method Get
      [array]$filteredItems = $items | Where-Object { $_.type -in $config.ExportSettings.ItemTypes }
      Write-Host "  - $($workspace.displayName): $($filteredItems.Count) items" -ForegroundColor Gray
    }
        
    if ($workspaces.Count -gt 10) {
      Write-Host "  ... and $($workspaces.Count - 10) more workspaces" -ForegroundColor Gray
    }
  }
  else {
    # Execute the actual archive process
    if ($ConfigFromEnv) {
      # When using environment variable, pass the config object directly
      Start-FABFabricArchiveProcess -Config $config -SerialProcessing:$SerialProcessing -ThrottleLimit $ThrottleLimit
    }
    else {
      # When using config file, pass the file path
      Start-FABFabricArchiveProcess -ConfigPath $ConfigPath -SerialProcessing:$SerialProcessing -ThrottleLimit $ThrottleLimit
    }
  }
    
  Write-Host "`n$ScriptName completed successfully!" -ForegroundColor Green
}
catch {
  Write-Error "Archive process failed: $($_.Exception.Message)"
  Write-Host "Stack Trace:" -ForegroundColor Red
  Write-Host $_.ScriptStackTrace -ForegroundColor Red
  exit 1
}
finally {
  # Cleanup
  Write-Host "`nCleaning up..." -ForegroundColor Cyan
    
  # Remove sensitive information from memory
  if (Get-Variable -Name config -ErrorAction SilentlyContinue) {
    Remove-Variable -Name config -Force
  }
}

#endregion

Write-Host ("=" * 50)
Write-Host "Archive process completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
