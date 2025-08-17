<#
.SYNOPSIS
Converts Fabric Archive Bot v1.0 configuration to v2.0 format

.DESCRIPTION
This script converts existing v1.0 configurations to the new v2.0 format while preserving 
backward compatibility. It migrates service principal settings, adds new v2.0 features 
like parallel processing and rate limiting, and provides testing capabilities.

.PARAMETER V1ConfigPath
Path to the v1.0 configuration file. If not provided, searches for Config.json in the repository root, current directory, or helpers directory.

.PARAMETER V2ConfigPath  
Path where the v2.0 configuration will be saved. If not provided, defaults to FabricArchiveBot_Config.json in the repository root.

.PARAMETER BackupV1Config
Creates a backup of the v1.0 configuration file before conversion.

.PARAMETER TestMigration
Tests the converted configuration to ensure it loads properly and validates dependencies.

.EXAMPLE
.\ConvertTo-FabricArchiveBotV2.ps1

Automatically finds Config.json and converts to FabricArchiveBot_Config.json in the repository root.

.EXAMPLE
.\ConvertTo-FabricArchiveBotV2.ps1 -BackupV1Config -TestMigration

Converts configuration with backup and testing enabled, using auto-discovered paths.

.EXAMPLE
.\ConvertTo-FabricArchiveBotV2.ps1 -V1ConfigPath "C:\MyConfigs\Config-Production.json" -V2ConfigPath "C:\MyConfigs\FabricArchiveBot_Config-Production.json"

Converts specific configuration files with custom paths.

.NOTES
- Preserves all ServicePrincipal settings from v1.0
- Adds new v2.0 features with sensible defaults
- Compatible with both v1.0 and v2.0 runtime environments
- Automatically configures rate limiting and parallel processing settings
#>

[CmdletBinding()]
param(
  [Parameter()]
  [string]$V1ConfigPath,
    
  [Parameter()]
  [string]$V2ConfigPath,
    
  [Parameter()]
  [switch]$BackupV1Config,
    
  [Parameter()]
  [switch]$TestMigration
)

# Function to find config files dynamically
function Find-FABConfigFile {
  param(
    [string]$FileName,
    [string]$ProvidedPath
  )
  
  # If a path was provided, use it
  if ($ProvidedPath) {
    return $ProvidedPath
  }
  
  # Get the root directory (parent of helpers directory)
  [string]$rootPath = Split-Path $PSScriptRoot
  [string]$rootConfigPath = Join-Path $rootPath $FileName
  
  # Check root directory first
  if (Test-Path $rootConfigPath) {
    return $rootConfigPath
  }
  
  # Check current directory
  [string]$currentConfigPath = Join-Path (Get-Location) $FileName
  if (Test-Path $currentConfigPath) {
    return $currentConfigPath
  }
  
  # Check helpers directory (same as script)
  [string]$helperConfigPath = Join-Path $PSScriptRoot $FileName
  if (Test-Path $helperConfigPath) {
    return $helperConfigPath
  }
  
  # Return root path as default (will be created there)
  return $rootConfigPath
}

# Set default paths dynamically
if (-not $V1ConfigPath) {
  $V1ConfigPath = Find-FABConfigFile -FileName "Config.json"
}

if (-not $V2ConfigPath) {
  $V2ConfigPath = Find-FABConfigFile -FileName "FabricArchiveBot_Config.json"
}

function Convert-FABV1ConfigToV2 {
  param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$V1Config
  )
    
  # Create v2.0 configuration structure
  [hashtable]$v2Config = @{
    Version              = "2.0"
    ServicePrincipal     = $V1Config.ServicePrincipal
    ExportSettings       = @{
      TargetFolder    = ".\Workspaces"
      RetentionDays   = 30
      WorkspaceFilter = "(type eq 'Workspace') and (state eq 'Active')"
      ItemTypes       = @("Report", "SemanticModel", "Notebook", "SparkJobDefinition")
      ExportFormats   = @("PBIP")
      UseCompression  = $false
      IncludeMetadata = $true
    }
    FabricToolsSettings  = @{
      UseFabricTools          = $true
      EnableAdvancedFeatures  = $true
      BatchSize               = 50
      ParallelProcessing      = $true
      ThrottleLimit           = 0
      MaxConcurrentWorkspaces = 5
      RateLimitSettings       = @{
        EnableRetry       = $true
        MaxRetries        = 3
        RetryDelaySeconds = 30
        BackoffMultiplier = 2
      }
    }
    NotificationSettings = @{
      EnableNotifications = $false
      TeamsWebhookUrl     = ""
      EmailSettings       = @{
        SmtpServer = ""
        From       = ""
        To         = @()
      }
    }
    AdvancedFeatures     = @{
      EnableLineageTracking    = $false
      EnableUsageMetrics       = $false
      EnableCapacityMonitoring = $false
      EnableScheduledReports   = $false
    }
  }
    
  return [PSCustomObject]$v2Config
}

function Test-FABV1Compatibility {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath
  )
    
  if (-not (Test-Path -Path $ConfigPath)) {
    Write-Error "V1 configuration file not found: $ConfigPath"
    return $false
  }
    
  try {
    [PSCustomObject]$config = Get-Content -Path $ConfigPath | ConvertFrom-Json
        
    # Check required v1.0 properties
    [string[]]$requiredProperties = @('ServicePrincipal')
    foreach ($prop in $requiredProperties) {
      if (-not $config.PSObject.Properties[$prop]) {
        Write-Error "Missing required property in v1.0 config: $prop"
        return $false
      }
    }
        
    Write-Host "V1 configuration is valid" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Error "Failed to parse v1.0 configuration: $($_.Exception.Message)"
    return $false
  }
}

# Main conversion logic
Write-Host "ConvertTo-FabricArchiveBotV2 - Configuration Conversion Utility" -ForegroundColor Green
Write-Host "Converting v1.0 configuration to v2.0 format" -ForegroundColor Cyan

Write-Host "`nConfiguration Paths:" -ForegroundColor Cyan
Write-Host "- V1 Config: $V1ConfigPath" -ForegroundColor Gray
Write-Host "- V2 Config: $V2ConfigPath" -ForegroundColor Gray

# Validate v1.0 configuration
if (-not (Test-FABV1Compatibility -ConfigPath $V1ConfigPath)) {
  exit 1
}

# Load v1.0 configuration
[PSCustomObject]$v1Config = Get-Content -Path $V1ConfigPath | ConvertFrom-Json

# Backup v1.0 configuration if requested
if ($BackupV1Config) {
  [string]$backupPath = $V1ConfigPath.Replace('.json', '-backup.json')
  Copy-Item -Path $V1ConfigPath -Destination $backupPath
  Write-Host "V1 configuration backed up to: $backupPath" -ForegroundColor Yellow
}

# Convert to v2.0 format
Write-Host "Converting configuration to v2.0 format..." -ForegroundColor Cyan
[PSCustomObject]$v2Config = Convert-FABV1ConfigToV2 -V1Config $v1Config

# Save v2.0 configuration
$v2Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $V2ConfigPath -Encoding UTF8
Write-Host "V2 configuration saved to: $V2ConfigPath" -ForegroundColor Green

# Test conversion if requested
if ($TestMigration) {
  Write-Host "`nTesting conversion..." -ForegroundColor Cyan
    
  try {
    # Test that the v2 configuration can be loaded successfully
    Get-Content -Path $V2ConfigPath | ConvertFrom-Json | Out-Null
    Write-Host "✓ V2 configuration loads successfully" -ForegroundColor Green
        
    # Test FabricTools availability
    if (Get-Module -Name FabricTools -ListAvailable) {
      Write-Host "✓ FabricTools module is available" -ForegroundColor Green
    }
    else {
      Write-Warning "FabricTools module not found. It will be installed automatically when running v2.0"
    }
        
    Write-Host "`nConversion test completed successfully!" -ForegroundColor Green
  }
  catch {
    Write-Error "Conversion test failed: $($_.Exception.Message)"
  }
}

Write-Host "`nConversion Summary:" -ForegroundColor Cyan
Write-Host "- V1 Config: $V1ConfigPath" -ForegroundColor Gray
Write-Host "- V2 Config: $V2ConfigPath" -ForegroundColor Gray
Write-Host "- Status: Complete" -ForegroundColor Green

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Review the new v2.0 configuration file"
Write-Host "2. Customize advanced settings as needed"
Write-Host "3. Run: .\Start-FabricArchiveBot.ps1 -ConfigPath '$V2ConfigPath'"
