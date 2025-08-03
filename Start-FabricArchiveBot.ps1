<#
.SYNOPSIS 
  Starts the Fabric Archive Bot to export all items from Fabric/Power BI workspaces

.DESCRIPTION
  This is the main entry point for Fabric Archive Bot v2.0, enhanced with FabricTools integration.
  Provides advanced features like parallel processing, enhanced metadata export, 
  multiple export formats, comprehensive monitoring, and configurable workspace filtering.

.PARAMETER ConfigPath
  Path to the configuration file. Defaults to FabricArchiveBot_Config.json in the script directory.

.PARAMETER WorkspaceFilter
  Override the workspace filter from configuration.

.PARAMETER TargetFolder
  Override the target folder from configuration.

.PARAMETER UseParallelProcessing
  Enable parallel processing for faster exports (requires PowerShell 7+).

.PARAMETER ThrottleLimit
  Maximum number of concurrent workspace processing threads. Defaults to CPU core count.

.PARAMETER SkipLegacyFallback
  Skip fallback to v1.0 functionality if FabricTools is unavailable.

.INPUTS
  None - Pipeline input is not accepted.

.OUTPUTS
  None - Pipeline output is not produced.

.EXAMPLE
  .\Start-FabricArchiveBot.ps1

  Runs with default configuration settings.

.EXAMPLE
  .\Start-FabricArchiveBot.ps1 -ConfigPath ".\Config-Production.json" -UseParallelProcessing

  Runs with custom configuration and parallel processing enabled.

.EXAMPLE
  .\Start-FabricArchiveBot.ps1 -WhatIf

  Shows what would be exported without performing the actual export.

.EXAMPLE
  .\Start-FabricArchiveBot.ps1 -WorkspaceFilter "(state eq 'Active') and contains(name,'Production')"

  Runs with a custom workspace filter to only process active workspaces with 'Production' in the name.

.LINK
  [Source code](https://github.com/JamesDBartlett3/Fabric-Archive-Bot)

.LINK
  [FabricTools Module](https://github.com/dataplat/FabricTools)

.NOTES
  Requires PowerShell 7+ for optimal performance
  Requires FabricTools module (will be installed automatically if missing)
  Falls back to v1.0 functionality if FabricTools is unavailable
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter()]
  [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'FabricArchiveBot_Config.json'),
    
  [Parameter()]
  [string]$WorkspaceFilter,
    
  [Parameter()]
  [string]$TargetFolder,
    
  [Parameter()]
  [switch]$UseParallelProcessing,
    
  [Parameter()]
  [int]$ThrottleLimit = 0,
    
  [Parameter()]
  [switch]$SkipLegacyFallback
)

# Script metadata
$ScriptVersion = "2.0.0"
$ScriptName = "Fabric Archive Bot v2.0"

Write-Host "$ScriptName - Version $ScriptVersion" -ForegroundColor Green
Write-Host "Enhanced with FabricTools integration" -ForegroundColor Cyan
Write-Host "=" * 50

#region Prerequisites and Validation

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7 -and $UseParallelProcessing) {
  Write-Warning "Parallel processing requires PowerShell 7+. Disabling parallel processing."
  $UseParallelProcessing = $false
}

# Validate configuration file
if (-not (Test-Path -Path $ConfigPath)) {
  Write-Error "Configuration file not found: $ConfigPath"
  Write-Host "Please ensure your configuration file exists or run with -ConfigPath parameter."
  exit 1
}

# Load configuration
try {
  $config = Get-Content -Path $ConfigPath | ConvertFrom-Json
    
  # Ensure configuration compatibility (requires core module to be loaded)
  $config = Confirm-FABConfigurationCompatibility -Config $config
    
  Write-Host "Configuration loaded from: $ConfigPath" -ForegroundColor Green
}
catch {
  Write-Error "Failed to load configuration: $($_.Exception.Message)"
  exit 1
}

# Override configuration with parameters if provided
if ($WorkspaceFilter) { $config.ExportSettings.WorkspaceFilter = $WorkspaceFilter }
if ($TargetFolder) { $config.ExportSettings.TargetFolder = $TargetFolder }

#endregion

#region Module Management

# Import core module
$coreModulePath = Join-Path -Path $PSScriptRoot -ChildPath "modules\FabricArchiveBotCore.psm1"

if (Test-Path -Path $coreModulePath) {
  Write-Host "Loading Fabric Archive Bot Core module..." -ForegroundColor Cyan
  Import-Module -Name $coreModulePath -Force
}
else {
  Write-Error "Core module not found: $coreModulePath"
  exit 1
}

# Test FabricTools availability
$fabricToolsAvailable = $false
try {
  if (-not (Get-Module -Name FabricTools -ListAvailable)) {
    Write-Host "FabricTools module not found. Installing from PowerShell Gallery..." -ForegroundColor Yellow
    Install-Module -Name FabricTools -Scope CurrentUser -Force -AllowClobber
  }
    
  Import-Module -Name FabricTools -Force
  $fabricToolsAvailable = $true
  Write-Host "FabricTools module loaded successfully" -ForegroundColor Green
}
catch {
  Write-Warning "Failed to load FabricTools module: $($_.Exception.Message)"
    
  if (-not $SkipLegacyFallback) {
    Write-Host "Falling back to v1.0 functionality..." -ForegroundColor Yellow
    $legacyScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Export-FabricItemsFromAllWorkspaces.ps1"
        
    if (Test-Path -Path $legacyScriptPath) {
      Write-Host "Executing legacy script: $legacyScriptPath" -ForegroundColor Yellow
      & $legacyScriptPath -ConfigObject $config
      exit $LASTEXITCODE
    }
    else {
      Write-Error "Legacy script not found and FabricTools unavailable. Cannot proceed."
      exit 1
    }
  }
  else {
    Write-Error "FabricTools unavailable and legacy fallback disabled. Cannot proceed."
    exit 1
  }
}

#endregion

#region Main Execution

try {
  Write-Host "Starting Fabric Archive Process..." -ForegroundColor Green
  Write-Host "Target Folder: $($config.ExportSettings.TargetFolder)" -ForegroundColor Cyan
  Write-Host "Retention Days: $($config.ExportSettings.RetentionDays)" -ForegroundColor Cyan
  Write-Host "Parallel Processing: $(if ($UseParallelProcessing) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Cyan
    
  if ($WhatIfPreference) {
    Write-Host "WHAT-IF MODE: No actual changes will be made" -ForegroundColor Yellow
        
    # Connect to Fabric for discovery
    if ($config.ServicePrincipal.AppId -and $config.ServicePrincipal.AppSecret -and $config.ServicePrincipal.TenantId) {
      Connect-FabricAccount -ServicePrincipal -TenantId $config.ServicePrincipal.TenantId -ClientId $config.ServicePrincipal.AppId -ClientSecret $config.ServicePrincipal.AppSecret
    }
    else {
      Connect-FabricAccount
    }
        
    # Discovery mode
    $allWorkspaces = Get-FabricWorkspace
        
    # Apply workspace filtering based on configuration
    if ($config.ExportSettings.WorkspaceFilter) {
      # Import the core module function temporarily for discovery
      $workspaces = Invoke-FABWorkspaceFilter -Workspaces $allWorkspaces -Filter $config.ExportSettings.WorkspaceFilter
    }
    else {
      $workspaces = $allWorkspaces
    }
        
    Write-Host "`nWould process $($workspaces.Count) workspaces matching filter '$($config.ExportSettings.WorkspaceFilter)':" -ForegroundColor Yellow
        
    foreach ($workspace in $workspaces | Select-Object -First 10) {
      $items = Get-FabricItem -WorkspaceId $workspace.id
      $filteredItems = $items | Where-Object { $_.type -in $config.ExportSettings.ItemTypes }
      Write-Host "  - $($workspace.displayName): $($filteredItems.Count) items" -ForegroundColor Gray
    }
        
    if ($workspaces.Count -gt 10) {
      Write-Host "  ... and $($workspaces.Count - 10) more workspaces" -ForegroundColor Gray
    }
  }
  else {
    # Execute the actual archive process
    Start-FABFabricArchiveProcess -ConfigPath $ConfigPath -UseParallelProcessing:$UseParallelProcessing -ThrottleLimit $ThrottleLimit
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

Write-Host "=" * 50
Write-Host "Archive process completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
