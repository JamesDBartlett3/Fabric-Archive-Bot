# If NuGet package provider is not installed, install it
if (-not ((Get-PackageProvider).Name -contains "NuGet")) {
  Register-PackageSource -Name "NuGet.org" -Location "https://api.nuget.org/v3/index.json" -ProviderName "NuGet"
}

# Import the FabricPS-PBIP module
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'FabricPS-PBIP.psm1')

# Get names of Workspaces and Reports to ignore from IgnoreList.json file
[PSCustomObject]$ignoreObjects = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath "IgnoreList.json") | ConvertFrom-Json
[array]$ignoreWorkspaces = $ignoreObjects.IgnoreWorkspaces
# [array]$ignoreReports = $ignoreObjects.IgnoreReports

# Get configuration settings from the Config.json file
[PSCustomObject]$config = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath "Config.json") | ConvertFrom-Json
[string]$tenantId = $config.ServicePrincipal.TenantId
[string]$servicePrincipalId = $config.ServicePrincipal.AppId
[string]$servicePrincipalSecret = $config.ServicePrincipal.AppSecret

# Get current date and create a folder hierarchy for the year, month, and day
[string]$year = Get-Date -Format "yyyy"
[string]$month = Get-Date -Format "MM"
[string]$day = Get-Date -Format "dd"

# Declare the target folder path
[string]$folderPath = Join-Path -Path $PSScriptRoot -ChildPath "PowerBIWorkspaces\$year\$month\$day"

# Create the target folder if it does not exist
if (-not (Test-Path -Path $folderPath)) {
  New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
}

# Logout-AzAccount | Out-Null

# Define the function to get the headers for the Fabric REST API
Function Get-FabricHeaders {
  Set-FabricAuthToken -TenantId $tenantId -servicePrincipalId $servicePrincipalId -servicePrincipalSecret $servicePrincipalSecret
  return @{
    Authorization="Bearer $(Get-FabricAuthToken)"
  }
}

Write-Host (Get-FabricHeaders)

# Get a list of all active Workspaces
[string[]]$workspaceIds = (
  Invoke-RestMethod -Uri 'https://api.powerbi.com/v1.0/myorg/admin/groups?$filter=(type eq ''Workspace'') and (state eq ''Active'')&$top=1000' -Method GET -Headers (Get-FabricHeaders)
  ).value | Where-Object  {
    $_.name -notin $ignoreWorkspaces `
    -and $_.name -eq "_FabricTesting"
    } | Select-Object -ExpandProperty id

# Export contents of each Workspace to the target folder
$workspaceIds | ForEach-Object {
  [string]$workspaceId = $_
  Export-FabricItems -WorkspaceId $workspaceId -Path $folderPath -ErrorAction SilentlyContinue
  # TODO: Convert the model.bim file to a .tmdl folder with pbi-tools
  # Invoke-Command -ScriptBlock {pbi-tools convert -source .\model.bim -outPath .\tmdl -modelSerialization tmdl} | Out-Null
  Get-FabricHeaders | Out-Null
}

# Get list of all subfolders for dates older than 3 years
[string[]]$oldFolders = (Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath "PowerBIWorkspaces") -Directory -Recurse -Depth 2 | 
  Where-Object {$_.LastWriteTime -lt (Get-Date).AddYears(-3)}).FullName

# Remove old folders
$oldFolders | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue