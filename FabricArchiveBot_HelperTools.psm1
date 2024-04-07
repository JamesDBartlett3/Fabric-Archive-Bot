Function Get-FABotOS {
	[string]$OS = ($PSVersionTable.OS).ToLower()
	if ($OS -like '*windows*') {
		return 'win'
	}
	elseif ($OS -like '*linux*') {
		return 'linux'
	}
	else {
		throw 'Operating system not supported'
	}
}

Function Get-FABotExecutableInfo {
	Param(
		[Parameter(Mandatory)][ValidateSet('dotnet', 'pbi-tools')][string]$ExecutableName
	)
	[string]$ExecutableSuffix = if ($ExecutableName -eq 'pbi-tools') { '.core' } else { $null }
	[string]$executablePath = Join-Path -Path $PSScriptRoot -ChildPath (Join-Path -Path $ExecutableName -ChildPath ($ExecutableName + $ExecutableSuffix)) -ErrorAction SilentlyContinue
	[string]$executableVersion = if ($ExecutableName -eq 'dotnet') {
		Invoke-Expression "$executablePath --version" -ErrorAction SilentlyContinue
	}
	else {
		Invoke-Expression "$executablePath info" | ConvertFrom-Json | Select-Object -ExpandProperty version -ErrorAction SilentlyContinue
	}
	return [PSCustomObject]@{
		Path    = $executablePath
		Version = $executableVersion
	}
}

Function Install-FABotDotNetCore {
	[string]$OS = Get-FABotOS
	[string]$DotNetCoreInstallScriptUrl = 'https://dot.net/v1/dotnet-install'
	[string]$DotNetCoreLocalInstallDir = (Join-Path -Path $PSScriptRoot -ChildPath 'dotnet')
	Write-Host "Installing .NET Core to $DotNetCoreLocalInstallDir. Please wait..."
	if ($OS -eq 'win') {
		$DotNetCoreInstallScriptUrl += '.ps1'
		$dotNetCoreInstallScriptPath = Join-Path -Path $PSScriptRoot -ChildPath (Split-Path -Leaf $DotNetCoreInstallScriptUrl)
		Invoke-WebRequest -Uri $DotNetCoreInstallScriptUrl -OutFile $dotNetCoreInstallScriptPath
		Unblock-File -Path $dotNetCoreInstallScriptPath
		& $dotNetCoreInstallScriptPath -InstallDir $DotNetCoreLocalInstallDir -Channel STS
	}
	else {
		# TODO: Test this on a Linux machine
		$DotNetCoreInstallScriptUrl += '.sh'
		$dotNetCoreInstallScriptPath = Join-Path -Path $PSScriptRoot -ChildPath (Split-Path -Leaf $DotNetCoreInstallScriptUrl)
		Invoke-WebRequest -Uri $DotNetCoreInstallScriptUrl -OutFile $dotNetCoreInstallScriptPath
		Invoke-Expression "bash chmod +x $dotNetCoreInstallScriptPath"
		Invoke-Expression "bash $dotNetCoreInstallScriptPath --install-dir $DotNetCoreLocalInstallDir --channel STS"
	}
}

Function Install-FABotPbiToolsCore {
	[string]$OS = Get-FABotOS
	[string]$pbiToolsCoreLatestVersionUri = 'https://api.github.com/repos/pbi-tools/pbi-tools/releases/latest'
	$pbiToolsCoreDir = (Join-Path -Path $PSScriptRoot -ChildPath 'pbi-tools')
	$pbiToolsCoreZip = $pbiToolsCoreDir + '.zip'
	$pbiToolsCoreLatestVersion = (Invoke-RestMethod -Uri $pbiToolsCoreLatestVersionUri).assets.browser_download_url -match "pbi-tools.core" -match "$OS-x64" | Select-Object -First 1
	Invoke-WebRequest -Uri $pbiToolsCoreLatestVersion -OutFile $pbiToolsCoreZip
	Remove-Item -Path $pbiToolsCoreDir -Recurse -Force -ErrorAction SilentlyContinue
	Expand-Archive -Path $pbiToolsCoreZip -DestinationPath $pbiToolsCoreDir -Force
	Remove-Item $pbiToolsCoreZip
}

Function Install-FABotHelperTools {
	[PSCustomObject]$dotNetCoreInfo = Get-FABotExecutableInfo -ExecutableName 'dotnet' -ErrorAction SilentlyContinue
	[version]$dotNetCoreVersion = $dotNetCoreInfo.Version
	if (!$dotNetCoreVersion -or $dotNetCoreVersion -lt [version]'6.0') {
		Install-FABotDotNetCore
		Install-FABotHelperTools
	}
	[PSCustomObject]$pbiToolsCoreInfo = Get-FABotExecutableInfo -ExecutableName 'pbi-tools' -ErrorAction SilentlyContinue
	if (!($pbiToolsCoreInfo).Path) {
		Install-FABotPbiToolsCore
		Install-FABotHelperTools
	}
}