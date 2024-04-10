<#
.SYNOPSIS 
  Exports all items from all active Workspaces in the Fabric/Power BI tenant to a local folder.

.DESCRIPTION
  This script exports all items from all active Workspaces in the Fabric/Power BI tenant to a local folder.

.PARAMETER ConfigObject
  A PSCustomObject containing the configuration settings for the script. The default value is the contents of the Config.json file in the same directory as the script.
  The object should have the following structure:
  @{
    ServicePrincipal = @{
      TenantId = 'YOUR_TENANT_ID'
      AppId = 'YOUR_APP_ID'
      AppSecret = 'YOUR_APP_SECRET'
    }
  }

.PARAMETER IgnoreObject
  A PSCustomObject containing the names of Workspaces and Reports to ignore. The default value is the contents of the IgnoreList.json file in the same directory as the script.
  The object should have the following structure:
  @{
    IgnoreWorkspaces = @('Workspace1', 'Workspace2')
    IgnoreReports = @('Report1', 'Report2')
  }

.PARAMETER WorkspaceFilter
	The filter expression for which Workspaces to export. Default value is '(type eq ''Workspace'') and (state eq ''Active'')'.

.PARAMETER ModuleUrl
  The URL of the FabricPS-PBIP.psm1 module. Default value is 'https://raw.githubusercontent.com/microsoft/Analysis-Services/master/pbidevmode/fabricps-pbip/FabricPS-PBIP.psm1'.

.PARAMETER RetentionCutoffDate
	The cutoff date for retention of exported items. Default value is 12:00AM on the current date minus 30 days. 
	The datatype is [datetime], so the input must be expressed as either:
		- A datetime-formatted string (e.g. '2024-01-01', '2024-01-01T00:00:00', etc.)
		- A [datetime] object (e.g. (Get-Date).Date.AddDays(-30), (Get-Date).Date.AddYears(-1), etc.)

.PARAMETER TargetFolder
  The path to the folder where the items will be exported. If not provided, the items will be exported to a folder named 'Workspaces\YYYY\MM\DD' in the same directory as the script.

.PARAMETER GetLatestModule
  If specified, the script will download the latest version of the FabricPS-PBIP.psm1 module from the Analysis-Services repository.

.PARAMETER ConvertToTmdl
  If specified, the script will convert model.bim files into 'definition' TMDL folder using pbi-tools.

.INPUTS
  None - Pipeline input is not accepted.

.OUTPUTS
  None - Pipeline output is not produced.

.LINK
  [Source code](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/blob/main/Export-FabricItemsFromAllWorkspaces.ps1)

.LINK
  [The author's blog](https://datavolume.xyz)
  
.LINK
  [Follow the author on LinkedIn](https://www.linkedin.com/in/jamesdbartlett3/)

.LINK
  [Follow the author on Mastodon](https://techhub.social/@JamesDBartlett3)

.LINK
  [Follow the author on BlueSky](https://bsky.app/profile/jamesdbartlett3.bsky.social)

#>

Param(
	[Parameter()][PSCustomObject]$ConfigObject = (Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Config.json') | ConvertFrom-Json),
	[Parameter()][PSCustomObject]$IgnoreObject = (Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath 'IgnoreList.json') | ConvertFrom-Json),
	[Parameter()][string]$WorkspaceFilter = '(type eq ''Workspace'') and (state eq ''Active'')',
	[Parameter()][string]$ModuleUrl = 'https://raw.githubusercontent.com/microsoft/Analysis-Services/master/pbidevmode/fabricps-pbip/FabricPS-PBIP.psm1',
	[Parameter()][datetime]$RetentionCutoffDate = (Get-Date).Date.AddDays(-30),
	[Parameter()][string]$TargetFolder = (Join-Path -Path $PSScriptRoot -ChildPath 'Workspaces'),
	[Parameter()][switch]$GetLatestModule,
	[Parameter()][switch]$ConvertToTmdl
)

# If NuGet package provider is not installed, install it
if (-not ((Get-PackageProvider).Name -contains 'NuGet')) {
	Register-PackageSource -Name 'NuGet.org' -Location 'https://api.nuget.org/v3/index.json' -ProviderName 'NuGet'
}

# Declare $moduleName variable
[string]$moduleFileName = Split-Path -Leaf $ModuleUrl

# Declare $localModulePath variable
[string]$localModulePath = (Join-Path -Path $PSScriptRoot -ChildPath $moduleFileName)

# Download latest FabricPS-PBIP.psm1 from Analysis-Services repository if it does not exist, or if $GetLatestModule is specified
if (-not (Test-Path -Path $localModulePath) -or ($GetLatestModule)) {
	Remove-Module FabricPS-PBIP -ErrorAction SilentlyContinue
	Remove-Item $localModulePath -ErrorAction SilentlyContinue
	Invoke-WebRequest -Uri $ModuleUrl -OutFile $localModulePath
}

# Unblock the downloaded FabricPS-PBIP.psm1 file so it can be imported
Unblock-File -Path $localModulePath

# Import the FabricPS-PBIP module
Import-Module $localModulePath -ErrorAction SilentlyContinue

# Get names of Workspaces and Reports to ignore from the $IgnoreObject parameter
[array]$ignoreWorkspaces = $IgnoreObject.IgnoreWorkspaces
# TODO: Implement IgnoreReports
# [array]$ignoreReports = $IgnoreObject.IgnoreReports

# Get configuration settings from the $ConfigObject parameter
[string]$tenantId = $ConfigObject.ServicePrincipal.TenantId
[string]$servicePrincipalId = $ConfigObject.ServicePrincipal.AppId
[string]$servicePrincipalSecret = $ConfigObject.ServicePrincipal.AppSecret

# Instantiate $useServicePrincipal variable as $true if Service Principal credentials are provided in the $ConfigObject parameter
[bool]$useServicePrincipal = $tenantId -and $servicePrincipalId -and $servicePrincipalSecret

# Get current date and create a folder hierarchy for the year, month, and day
[datetime]$date = Get-Date
[string]$year = $date.Year.ToString()
[string]$month = $date.Month.ToString("D2")
[string]$day = $date.Day.ToString("D2")

# Declare $sep variable to use as platform-agnostic directory separator
[string]$sep = [IO.Path]::DirectorySeparatorChar

# Add the year, month, and day to the target folder path
$TargetFolder = Join-Path -Path $TargetFolder -ChildPath ($year + $sep + $month + $sep + $day)

# Create the target folder if it does not exist
if (-not (Test-Path -Path $TargetFolder)) {
	New-Item -Path $TargetFolder -ItemType Directory -Force | Out-Null
}

# Initialize the $loopCount variable
[int]$loopCount = 0

# Define the function to get the headers for the Fabric REST API
# If $useServicePrincipal is $true, use the Service Principal credentials to get the headers
# Otherwise, use the current user's credentials
Function Get-FabricHeaders {
	if ($useServicePrincipal) {
		if ($loopCount -eq 0) {
			Logout-AzAccount | Out-Null
		}
		Set-FabricAuthToken -TenantId $tenantId -servicePrincipalId $servicePrincipalId -servicePrincipalSecret $servicePrincipalSecret
	} else {
		Set-FabricAuthToken
	}
	return @{
		Authorization = "Bearer $(Get-FabricAuthToken)"
	}
}

$headers = Get-FabricHeaders

# Get a list of all active Workspaces in batches of 5000 until all workspaces have been fetched
[guid[]]$workspaceIds = @()
[int]$skip = 0
[int]$batchSize = 5000
do {
	[string]$batchUri = 'https://api.powerbi.com/v1.0/myorg/admin/groups?$filter={0}&$top={1}&$skip={2}' -f $WorkspaceFilter, $batchSize, $skip
	$batch = Invoke-RestMethod -Uri $batchUri -Method GET -Headers $headers
	$workspaceIds += $batch.value | Where-Object {
		$_.name -notin $ignoreWorkspaces
	} | Select-Object -ExpandProperty id
	$skip += $batchSize
} while ($batch.value.Count -eq $batchSize)

# Export contents of each Workspace to the target folder
$workspaceIds | ForEach-Object {
	[guid]$workspaceId = $_
	# Export all items from the Workspace to the target folder
	Export-FabricItems -WorkspaceId $workspaceId -Path $TargetFolder -ErrorAction SilentlyContinue
	# If $ConvertToTmdl is specified, convert the model.bim file to a .tmdl folder with Microsoft.AnalysisServices.Tabular
	if ($ConvertToTmdl) {
		$bimFiles = Get-ChildItem -Path (Join-Path -Path $TargetFolder -ChildPath $workspaceId) -Filter '*.bim' -Recurse -File
		foreach ($bimFile in $bimFiles) {
			$tmdlFolder = Join-Path -Path $bimFile.DirectoryName -ChildPath 'definition'
			$modelText = Get-Content $bimFile.FullName
			$database = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::DeserializeDatabase($modelText, $null, [Microsoft.AnalysisServices.CompatibilityMode]::PowerBI)
			[Microsoft.AnalysisServices.Tabular.TmdlSerializer]::SerializeDatabaseToFolder($database, $tmdlFolder)
		}
	}
	$headers = Get-FabricHeaders
	# Get the name of the Workspace and rename the folder to the Workspace name
	[string]$workspaceName = (Invoke-RestMethod -Uri "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId" -Method GET -Headers $headers).name
	Remove-Item -Recurse (Join-Path -Path $TargetFolder -ChildPath $workspaceName) -Force -ErrorAction SilentlyContinue
	Rename-Item -Path (Join-Path -Path $TargetFolder -ChildPath $workspaceId) -NewName $workspaceName -Force -ErrorAction SilentlyContinue
	$loopCount += 1
}

# Get list of all subfolders for dates older than $RetentionCutoffDate
[string[]]$oldFolders = (Get-ChildItem -Path $TargetFolder -Directory -Recurse -Depth 2 | Where-Object { $_.LastWriteTime -lt $RetentionCutoffDate }).FullName

# Remove old folders
$oldFolders | Remove-Item -Force -ErrorAction SilentlyContinue