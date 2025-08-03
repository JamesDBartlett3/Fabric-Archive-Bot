<#
.SYNOPSIS
Migration helper for upgrading from Fabric Archive Bot v1.0 to v2.0

.DESCRIPTION
This script helps migrate existing v1.0 configurations and data to the new v2.0 format
while preserving backward compatibility.
#>

[CmdletBinding()]
param(
  [Parameter()]
  [string]$V1ConfigPath = ".\Config.json",
    
  [Parameter()]
  [string]$V2ConfigPath = ".\FabricArchiveBot_Config.json",
    
  [Parameter()]
  [switch]$BackupV1Config,
    
  [Parameter()]
  [switch]$TestMigration
)

function Convert-V1ConfigToV2 {
  param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$V1Config
  )
    
  # Create v2.0 configuration structure
  $v2Config = @{
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

function Test-V1Compatibility {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath
  )
    
  if (-not (Test-Path -Path $ConfigPath)) {
    Write-Error "V1 configuration file not found: $ConfigPath"
    return $false
  }
    
  try {
    $config = Get-Content -Path $ConfigPath | ConvertFrom-Json
        
    # Check required v1.0 properties
    $requiredProperties = @('ServicePrincipal')
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

# Main migration logic
Write-Host "Fabric Archive Bot Migration Utility" -ForegroundColor Green
Write-Host "Converting v1.0 configuration to v2.0 format" -ForegroundColor Cyan

# Validate v1.0 configuration
if (-not (Test-V1Compatibility -ConfigPath $V1ConfigPath)) {
  exit 1
}

# Load v1.0 configuration
$v1Config = Get-Content -Path $V1ConfigPath | ConvertFrom-Json

# Backup v1.0 configuration if requested
if ($BackupV1Config) {
  $backupPath = $V1ConfigPath.Replace('.json', '-backup.json')
  Copy-Item -Path $V1ConfigPath -Destination $backupPath
  Write-Host "V1 configuration backed up to: $backupPath" -ForegroundColor Yellow
}

# Convert to v2.0 format
Write-Host "Converting configuration to v2.0 format..." -ForegroundColor Cyan
$v2Config = Convert-V1ConfigToV2 -V1Config $v1Config

# Save v2.0 configuration
$v2Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $V2ConfigPath -Encoding UTF8
Write-Host "V2 configuration saved to: $V2ConfigPath" -ForegroundColor Green

# Test migration if requested
if ($TestMigration) {
  Write-Host "`nTesting migration..." -ForegroundColor Cyan
    
  try {
    $testConfig = Get-Content -Path $V2ConfigPath | ConvertFrom-Json
    Write-Host "✓ V2 configuration loads successfully" -ForegroundColor Green
        
    # Test FabricTools availability
    if (Get-Module -Name FabricTools -ListAvailable) {
      Write-Host "✓ FabricTools module is available" -ForegroundColor Green
    }
    else {
      Write-Warning "FabricTools module not found. It will be installed automatically when running v2.0"
    }
        
    Write-Host "`nMigration test completed successfully!" -ForegroundColor Green
  }
  catch {
    Write-Error "Migration test failed: $($_.Exception.Message)"
  }
}

Write-Host "`nMigration Summary:" -ForegroundColor Cyan
Write-Host "- V1 Config: $V1ConfigPath" -ForegroundColor Gray
Write-Host "- V2 Config: $V2ConfigPath" -ForegroundColor Gray
Write-Host "- Status: Complete" -ForegroundColor Green

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Review the new v2.0 configuration file"
Write-Host "2. Customize advanced settings as needed"
Write-Host "3. Run: .\Start-FabricArchiveBot.ps1 -ConfigPath '$V2ConfigPath'"
