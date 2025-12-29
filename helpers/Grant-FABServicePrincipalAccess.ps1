<#
.SYNOPSIS
Grants a service principal access to Fabric workspaces

.DESCRIPTION
This helper script grants an Entra ID service principal (app registration) access to 
one or more Fabric workspaces. This is useful for setup before running the Fabric Archive Bot
with service principal authentication.

The script can:
- Grant access to all workspaces in the tenant
- Grant access to filtered workspaces (using OData-style filters)
- Grant access to specific workspaces by ID
- Support different roles: Admin, Member, Contributor, Viewer

.PARAMETER ServicePrincipalId
The Application (Client) ID of the service principal

.PARAMETER TenantId
The Tenant ID where the service principal is registered

.PARAMETER Role
The workspace role to grant. Valid values: Admin, Member, Contributor, Viewer
Default: Member

.PARAMETER WorkspaceFilter
Optional OData-style filter to limit which workspaces receive access.
Examples:
  - "(type eq 'Workspace')"
  - "(domainId eq 'guid')"
  - "contains(name,'Production')"

.PARAMETER WorkspaceIds
Optional array of specific workspace IDs to grant access to

.PARAMETER WhatIf
Show what would be done without making changes

.EXAMPLE
.\Grant-FABServicePrincipalAccess.ps1 -ServicePrincipalId "12345678-1234-1234-1234-123456789012" -TenantId "87654321-4321-4321-4321-210987654321"

Grants Member role to the service principal for all workspaces

.EXAMPLE
.\Grant-FABServicePrincipalAccess.ps1 -ServicePrincipalId "12345678-1234-1234-1234-123456789012" -TenantId "87654321-4321-4321-4321-210987654321" -Role Admin -WorkspaceFilter "(type eq 'Workspace')"

Grants Admin role to the service principal for all workspaces of type 'Workspace'

.EXAMPLE
.\Grant-FABServicePrincipalAccess.ps1 -ServicePrincipalId "12345678-1234-1234-1234-123456789012" -TenantId "87654321-4321-4321-4321-210987654321" -WorkspaceIds @("workspace-id-1", "workspace-id-2") -WhatIf

Shows what would happen when granting access to specific workspaces

.NOTES
Requirements:
- PowerShell 7+
- FabricPS-PBIP module (will be loaded from parent directory)
- Az.Accounts module (for Get-AzADServicePrincipal)
- User must be authenticated with permissions to modify workspace role assignments
- The service principal must exist in the tenant

Author: Fabric Archive Bot Team
Version: 2.0.0
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory = $false)]
  [string]$ServicePrincipalId,
  
  [Parameter(Mandatory = $false)]
  [string]$TenantId,
  
  [Parameter()]
  [ValidateSet('Admin', 'Member', 'Contributor', 'Viewer')]
  [string]$Role = 'Member',
  
  [Parameter()]
  [string]$WorkspaceFilter,
  
  [Parameter()]
  [string[]]$WorkspaceIds,

  [Parameter()]
  [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath '..\FabricArchiveBot_Config.json'),
    
  [Parameter()]
  [switch]$ConfigFromEnv
)

# Script metadata
[string]$ScriptVersion = "2.0.0"
[string]$ScriptName = "Grant Service Principal Workspace Access"

Write-Host "`n$ScriptName - Version $ScriptVersion" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Cyan

# Validate PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Error "This script requires PowerShell 7 or later. Current version: $($PSVersionTable.PSVersion)"
  exit 1
}

# Load required modules
try {
  Write-Host "`nLoading required modules..." -ForegroundColor Yellow
  
  # Load FabricPS-PBIP from parent directory
  [string]$fabricModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\FabricPS-PBIP.psm1'
  if (-not (Test-Path $fabricModulePath)) {
    throw "FabricPS-PBIP module not found at: $fabricModulePath"
  }
  Import-Module $fabricModulePath -Force -ErrorAction Stop
  
  # Load FabricArchiveBotCore for workspace filtering
  [string]$coreModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\modules\FabricArchiveBotCore.psm1'
  if (-not (Test-Path $coreModulePath)) {
    throw "FabricArchiveBotCore module not found at: $coreModulePath"
  }
  Import-Module $coreModulePath -Force -ErrorAction Stop
  
  # Load Az.Accounts for Get-AzADServicePrincipal (same as v1.0)
  if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    throw "Az.Accounts module is required. Install it with: Install-Module Az.Accounts -Scope CurrentUser"
  }
  Import-Module Az.Accounts -ErrorAction Stop
  
  Write-Host "✓ Modules loaded successfully`n" -ForegroundColor Green
}
catch {
  Write-Error "Failed to load required modules: $($_.Exception.Message)"
  exit 1
}

# Load configuration
try {
  [PSCustomObject]$config = Get-FABConfiguration -ConfigPath $ConfigPath -ConfigFromEnv:$ConfigFromEnv
  Write-Host "Configuration loaded successfully" -ForegroundColor Green
}
catch {
  Write-Warning "Failed to load configuration: $($_.Exception.Message)"
}

# Apply configuration defaults if parameters are missing
if ([string]::IsNullOrWhiteSpace($ServicePrincipalId) -and $config -and $config.ServicePrincipal) {
  $ServicePrincipalId = $config.ServicePrincipal.AppId
  if ($ServicePrincipalId) {
    Write-Host "Using ServicePrincipalId from configuration" -ForegroundColor Gray
  }
}

if ([string]::IsNullOrWhiteSpace($TenantId) -and $config -and $config.ServicePrincipal) {
  $TenantId = $config.ServicePrincipal.TenantId
  if ($TenantId) {
    Write-Host "Using TenantId from configuration" -ForegroundColor Gray
  }
}

# Validate mandatory parameters
if ([string]::IsNullOrWhiteSpace($ServicePrincipalId)) {
  Write-Error "ServicePrincipalId is required. Please provide it via parameter or configuration."
  exit 1
}

# Auto-detect TenantId if not provided
if ([string]::IsNullOrWhiteSpace($TenantId)) {
  Write-Host "TenantId not provided. Attempting to detect from current Azure context..." -ForegroundColor Yellow
  $currentContext = Get-AzContext -ErrorAction SilentlyContinue
  
  if ($currentContext -and $currentContext.Tenant.Id) {
    $TenantId = $currentContext.Tenant.Id
    Write-Host "✓ Detected TenantId: $TenantId" -ForegroundColor Green
  }
  else {
    Write-Error "Could not detect TenantId. Please provide -TenantId parameter or login to Azure with Connect-AzAccount."
    exit 1
  }
}

# Authenticate to Azure (required for Get-AzADServicePrincipal)
try {
  Write-Host "Authenticating to Azure..." -ForegroundColor Yellow
  
  # Check if already connected to the correct tenant
  [PSCustomObject]$currentContext = Get-AzContext -ErrorAction SilentlyContinue
  
  if ($currentContext -and $currentContext.Tenant.Id -eq $TenantId) {
    Write-Host "✓ Already connected to Azure (Tenant: $TenantId)`n" -ForegroundColor Green
  }
  else {
    if ($currentContext) {
      Write-Host "  Switching to tenant: $TenantId" -ForegroundColor Gray
    }
    try {
      $null = Connect-AzAccount -TenantId $TenantId -ErrorAction Stop -WarningAction SilentlyContinue
      Write-Host "✓ Connected to Azure`n" -ForegroundColor Green
    }
    catch {
      # Sometimes Connect-AzAccount throws errors but still succeeds
      # Check if we're now connected
      $currentContext = Get-AzContext -ErrorAction SilentlyContinue
      if ($currentContext -and $currentContext.Tenant.Id -eq $TenantId) {
        Write-Host "✓ Connected to Azure (with warnings)`n" -ForegroundColor Green
      }
      else {
        throw
      }
    }
  }
}
catch {
  Write-Error "Failed to connect to Azure: $($_.Exception.Message)"
  Write-Host "`nNote: The 'Object reference not set' error can sometimes be ignored if you're already authenticated." -ForegroundColor Yellow
  Write-Host "Continuing to check service principal...`n" -ForegroundColor Yellow
}

# Get service principal Object ID (same method as v1.0)
try {
  Write-Host "Getting service principal Object ID..." -ForegroundColor Yellow
  [string]$servicePrincipalObjectId = (Get-AzADServicePrincipal -ApplicationId $ServicePrincipalId).Id
  
  if (-not $servicePrincipalObjectId) {
    throw "Service principal with Application ID '$ServicePrincipalId' not found in tenant '$TenantId'"
  }
  
  # Get the display name for reporting
  [PSCustomObject]$sp = Get-AzADServicePrincipal -ApplicationId $ServicePrincipalId
  [string]$servicePrincipalName = $sp.DisplayName
  
  Write-Host "✓ Found service principal:" -ForegroundColor Green
  Write-Host "  Display Name: $servicePrincipalName" -ForegroundColor White
  Write-Host "  Object ID: $servicePrincipalObjectId" -ForegroundColor White
  Write-Host "  Application ID: $ServicePrincipalId`n" -ForegroundColor White
}
catch {
  Write-Error "Failed to get service principal: $($_.Exception.Message)"
  Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
  Write-Host "  1. Verify the Application ID is correct: $ServicePrincipalId" -ForegroundColor White
  Write-Host "  2. Ensure the service principal exists in tenant: $TenantId" -ForegroundColor White
  Write-Host "  3. Make sure you're connected to Azure with Connect-AzAccount" -ForegroundColor White
  exit 1
}

# Authenticate to Fabric
try {
  Write-Host "Authenticating to Fabric..." -ForegroundColor Yellow
  
  # Check if already authenticated
  [string]$currentToken = Get-FabricAuthToken -ErrorAction SilentlyContinue
  
  if ($currentToken) {
    Write-Host "✓ Already authenticated to Fabric`n" -ForegroundColor Green
  }
  else {
    Set-FabricAuthToken -Reset
    Write-Host "✓ Authenticated to Fabric`n" -ForegroundColor Green
  }
}
catch {
  Write-Error "Failed to authenticate to Fabric: $($_.Exception.Message)"
  exit 1
}

# Get workspaces to process
try {
  Write-Host "Getting workspaces..." -ForegroundColor Yellow
  
  if ($WorkspaceIds) {
    # Use specific workspace IDs
    Write-Host "Using provided workspace IDs: $($WorkspaceIds.Count) workspace(s)" -ForegroundColor White
    [array]$workspaces = @()
    foreach ($wsId in $WorkspaceIds) {
      try {
        [PSCustomObject]$ws = Get-FABFabricWorkspaceById -WorkspaceId $wsId
        $workspaces += $ws
      }
      catch {
        Write-Warning "Failed to get workspace $wsId : $($_.Exception.Message)"
      }
    }
  }
  else {
    # Get all workspaces
    [array]$workspaces = Get-FABFabricWorkspaces -Verbose
    
    # Apply filter if provided
    if ($WorkspaceFilter) {
      Write-Host "Applying workspace filter: $WorkspaceFilter" -ForegroundColor White
      $workspaces = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter $WorkspaceFilter
    }
  }
  
  if ($workspaces.Count -eq 0) {
    Write-Warning "No workspaces found matching criteria. Exiting."
    exit 0
  }
  
  Write-Host "✓ Found $($workspaces.Count) workspace(s) to process`n" -ForegroundColor Green
}
catch {
  Write-Error "Failed to get workspaces: $($_.Exception.Message)"
  exit 1
}

# Grant access to workspaces
Write-Host "Granting '$Role' role to service principal..." -ForegroundColor Yellow
Write-Host ("=" * 60) -ForegroundColor Cyan

[int]$successCount = 0
[int]$skipCount = 0
[int]$errorCount = 0
[array]$errors = @()

foreach ($workspace in $workspaces) {
  [string]$workspaceName = $workspace.displayName
  [string]$workspaceId = $workspace.id
  
  try {
    # Prepare permission object
    [PSCustomObject]$permission = @{
      principal = @{
        id   = $servicePrincipalObjectId
        type = "ServicePrincipal"
      }
      role      = $Role
    }
    
    if ($PSCmdlet.ShouldProcess($workspaceName, "Grant '$Role' role to service principal")) {
      # Check if service principal already has a role
      [array]$existingRoles = Invoke-FabricAPIRequest -Uri "workspaces/$workspaceId/roleAssignments" -Method Get
      [PSCustomObject]$existingRole = $existingRoles | Where-Object { $_.principal.id -eq $servicePrincipalObjectId } | Select-Object -First 1
      
      if ($existingRole) {
        if ($existingRole.role -eq $Role) {
          Write-Host "✓ Already has '$Role' role: $workspaceName" -ForegroundColor Gray
          $skipCount++
        }
        else {
          # Update existing role
          Write-Host "↻ Updating role from '$($existingRole.role)' to '$Role': $workspaceName" -ForegroundColor Yellow
          Set-FabricWorkspacePermissions -WorkspaceId $workspaceId -Permissions @($permission)
          $successCount++
        }
      }
      else {
        # Grant new role
        Write-Host "✓ Granted '$Role' role: $workspaceName" -ForegroundColor Green
        Set-FabricWorkspacePermissions -WorkspaceId $workspaceId -Permissions @($permission)
        $successCount++
      }
    }
  }
  catch {
    Write-Host "✗ Failed: $workspaceName - $($_.Exception.Message)" -ForegroundColor Red
    $errorCount++
    $errors += [PSCustomObject]@{
      Workspace   = $workspaceName
      WorkspaceId = $workspaceId
      Error       = $_.Exception.Message
    }
  }
}

# Summary
Write-Host "`n" -NoNewline
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

Write-Host "`nTotal workspaces: $($workspaces.Count)" -ForegroundColor White
Write-Host "  Granted/Updated: $successCount" -ForegroundColor Green
Write-Host "  Already had role: $skipCount" -ForegroundColor Gray
Write-Host "  Errors: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "White" })

if ($errorCount -gt 0) {
  Write-Host "`nErrors encountered:" -ForegroundColor Red
  $errors | Format-Table -AutoSize | Out-String | Write-Host
}

Write-Host "`n$ScriptName completed!" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Cyan
