Function Get-LatestPbiTools {
  [string]$pbiToolsLatestVersionUri = 'https://api.github.com/repos/pbi-tools/pbi-tools/releases/latest'
  [string]$OS = ($PSVersionTable.OS).ToLower()
  [string]$osAbbrev = $null
	[string]$dotNetInstallScriptUrl = 'https://dot.net/v1/dotnet-install'
	[string]$dotNetLocalInstallDir = Join-Path -Path $PSScriptRoot -ChildPath 'dotnet'
	[version]$dotNetCoreVersion = (dotnet --version) -replace '\r\n', ''
	
	if ($OS -like '*windows*') {
		$osAbbrev = 'win'
		$dotNetInstallScriptUrl += '.ps1'
  } elseif ($OS -like '*linux*') {
		$osAbbrev = 'linux'
		$dotNetInstallScriptUrl += '.sh'
  } else {
		throw 'Operating system not supported'
  }
	
	[string]$dotNetCoreInstallScriptPath = Join-Path -Path $PSScriptRoot -ChildPath (Split-Path -Leaf $dotNetInstallScriptUrl)

	if (!$dotNetCoreVersion) {
		Invoke-WebRequest -Uri $dotNetInstallScriptUrl -OutFile $dotNetCoreInstallScriptPath
		if ($osAbbrev -eq 'win') {
			Unblock-File -Path $dotNetCoreInstallScriptPath
			& $dotNetCoreInstallScriptPath -InstallDir $dotNetLocalInstallDir
		} else {
			Invoke-Expression "bash chmod +x $dotNetCoreInstallScriptPath" 
			Invoke-Expression "bash $dotNetCoreInstallScriptPath --install-dir $dotNetLocalInstallDir"
		}
	}

  $pbiToolsDir = (Join-Path -Path $PSScriptRoot -ChildPath 'pbi-tools')
  $pbiToolsCoreZip = $pbiToolsDir + '.zip'
  $pbiToolsCoreLatestVersion = (Invoke-RestMethod -Uri $pbiToolsLatestVersionUri).assets.browser_download_url -match "pbi-tools.core" -match "$osAbbrev-x64" | Select-Object -First 1
  Invoke-WebRequest -Uri $pbiToolsCoreLatestVersion -OutFile $pbiToolsCoreZip
  Remove-Item -Path $pbiToolsDir -Recurse -Force -ErrorAction SilentlyContinue
  Expand-Archive -Path $pbiToolsCoreZip -DestinationPath $pbiToolsDir -Force
  Remove-Item $pbiToolsCoreZip
  [string]$pbiToolsExe = (Get-ChildItem -Path $pbiToolsDir -Recurse -Filter 'pbi-tools*.exe').FullName
  return $pbiToolsExe
}