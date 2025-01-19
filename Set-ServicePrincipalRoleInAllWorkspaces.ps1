# TODO: Docblock

param (
	[string][ValidateSet('Add', 'Remove')]$Action = 'Add',
	[string][ValidateSet('Admin', 'Member', 'Contributor')]$Role = 'Member',
	[string]$ServicePrincipalObjectId = ((Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Config.json') | ConvertFrom-Json).ServicePrincipal.ObjectId),
	[string]$WorkspaceFilter = '(type eq ''Workspace'') and (state eq ''Active'')'
)

# Load Power BI Management module
if (-not (Get-Module -Name MicrosoftPowerBIMgmt.Profile)) {
	Install-Module -Name MicrosoftPowerBIMgmt.Profile -Scope CurrentUser
}
Import-Module MicrosoftPowerBIMgmt.Profile

[string]$baseUrl = 'https://api.powerbi.com/v1.0/myorg/admin/groups'
$headers = $null

# Authenticate to Power BI
try {
	$headers = Get-PowerBIAccessToken
}
catch {
	Write-Host '🔒 Power BI Access Token required. Launching Azure Active Directory authentication dialog...'
	Start-Sleep -s 1
	Connect-PowerBIServiceAccount -WarningAction SilentlyContinue | Out-Null
	$headers = Get-PowerBIAccessToken
	if ($headers) {
		Write-Host '🔑 Power BI Access Token acquired. Proceeding...'
	}
	else {
		Write-Host '❌ Power BI Access Token not acquired. Exiting...'
		exit
	}
}

# Function to get all workspaces
function Get-AllWorkspaces {
	param(
		$Headers,
		$WorkspaceFilter
	)
	[guid[]]$workspaceIds = @()
	[int]$skip = 0
	[int]$batchSize = 5000
	do {
		[string]$batchUri = $baseUrl + '?$filter={0}&$top={1}&$skip={2}' -f $WorkspaceFilter, $batchSize, $skip
		$batch = Invoke-RestMethod -Uri $batchUri -Method GET -Headers $headers
		$workspaceIds += $batch.value | Select-Object -ExpandProperty id
		$skip += $batchSize
	} while ($batch.value.Count -eq $batchSize)
	return $workspaceIds
}

# Function to add Service Principal to a workspace
function Add-ServicePrincipalToWorkspace {
	param (
		[string]$WorkspaceId,
		[string]$ObjectId,
		[string]$Role,
		$Headers
	)

	$url = "$baseUrl/$workspaceId/users"

	$body = @{
		identifier           = $ObjectId
		principalType        = "App"
		groupUserAccessRight = $Role
	}

	Invoke-RestMethod -Uri $url -Headers $Headers -Method POST -Body $body
}

# Function to delete Service Principal from a workspace
function Remove-ServicePrincipalFromWorkspace {
	param (
		[string]$WorkspaceId,
		[string]$ObjectId,
		$Headers
	)

	$url = "$baseUrl/$workspaceId/users/$ObjectId"

	Invoke-RestMethod -Uri $url -Headers $Headers -Method DELETE
}

# Get all workspaces
$workspaces = Get-AllWorkspaces -Headers $headers -WorkspaceFilter $WorkspaceFilter

# Add Service Principal to each workspace
# TODO: Add rate limit handling
foreach ($workspace in $workspaces) {
	if ($Action -eq 'Add') {
		Write-Host "Adding Service Principal to workspace $workspace..."
		Add-ServicePrincipalToWorkspace -WorkspaceId $workspace -ObjectId $ServicePrincipalObjectId -Role $Role -Headers $headers 
	} elseif ($Action -eq 'Remove') {
		Write-Host "Removing Service Principal from workspace $workspace..."
		Remove-ServicePrincipalFromWorkspace -WorkspaceId $workspace -ObjectId $ServicePrincipalObjectId -Headers $headers
	} else {
		Write-Error "Invalid action: $Action. Exiting..."
		exit
	}
}