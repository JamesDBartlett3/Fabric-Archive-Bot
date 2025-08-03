# Create a user environment variable called FabricArchiveBot_ConfigObject with the value from the configuration file

# Define the root directory
$RootPath = Split-Path $PSScriptRoot

# Check for v2.0 config file first, then fall back to v1.0 config file
$V2ConfigPath = Join-Path $RootPath "FabricArchiveBot_Config.json"
$V1ConfigPath = Join-Path $RootPath "Config.json"

if (Test-Path $V2ConfigPath) {
  Write-Host "Using v2.0 configuration: FabricArchiveBot_Config.json" -ForegroundColor Green
  $ConfigObject = Get-Content -Path $V2ConfigPath
  $ConfigVersion = "v2.0"
}
elseif (Test-Path $V1ConfigPath) {
  Write-Host "Using v1.0 configuration: Config.json" -ForegroundColor Yellow
  Write-Host "Consider migrating to v2.0 using: .\helpers\ConvertTo-FabricArchiveBotV2.ps1" -ForegroundColor Yellow
  $ConfigObject = Get-Content -Path $V1ConfigPath
  $ConfigVersion = "v1.0"
}
else {
  Write-Error "No configuration file found. Please ensure either 'FabricArchiveBot_Config.json' or 'Config.json' exists."
  exit 1
}

# Remove all new lines, carriage returns, and whitespace from the ConfigObject
$ConfigObject = $ConfigObject -replace '\r\n', '' -replace '\n', '' -replace '\r', '' -replace '\s', ''

# Set the FabricArchiveBot_ConfigObject user environment variable
[System.Environment]::SetEnvironmentVariable("FabricArchiveBot_ConfigObject", $ConfigObject, "User")

Write-Host "Successfully set FabricArchiveBot_ConfigObject environment variable using $ConfigVersion configuration." -ForegroundColor Green