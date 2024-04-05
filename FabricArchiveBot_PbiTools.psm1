Function Get-LatestPbiTools {
  $pbiToolsLatestVersionUri = 'https://api.github.com/repos/pbi-tools/pbi-tools/releases/latest'
  $operatingSystem = ($PSVersionTable.OS).ToLower()
  $osAbbrev = if ($operatingSystem -like '*windows*') {
    'win'
  } elseif ($operatingSystem -like '*linux*') {
    'linux'
  } else {
    throw 'Operating system not supported'
  }
  $pbiToolsDir = (Join-Path -Path $PSScriptRoot -ChildPath 'pbi-tools')
  $pbiToolsCoreLatestVersion = (Invoke-RestMethod -Uri $pbiToolsLatestVersionUri).assets.browser_download_url -match "pbi-tools.core" -match "$osAbbrev-x64" | Select-Object -First 1
  $pbiToolsCoreZip = $pbiToolsDir + '.zip'
  Invoke-WebRequest -Uri $pbiToolsCoreLatestVersion -OutFile $pbiToolsCoreZip
  Remove-Item -Path $pbiToolsDir -Recurse -Force -ErrorAction SilentlyContinue
  Expand-Archive -Path $pbiToolsCoreZip -DestinationPath $pbiToolsDir -Force
  Remove-Item $pbiToolsCoreZip
  [string]$pbiToolsExe = (Get-ChildItem -Path $pbiToolsDir -Recurse -Filter 'pbi-tools*.exe').FullName
  return $pbiToolsExe
}