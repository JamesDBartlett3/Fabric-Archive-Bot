# Create a user environment variable called FabricArchiveBot_ConfigObject with the value from the configuration file

param(
  [Parameter(Mandatory = $true)]
  [string]$ConfigFile
)

# Define the root directory
$RootPath = Split-Path $PSScriptRoot

# Build the full path to the config file
$ConfigPath = if ([System.IO.Path]::IsPathRooted($ConfigFile)) {
  $ConfigFile
}
else {
  Join-Path $RootPath $ConfigFile
}

# Verify the config file exists
if (-not (Test-Path $ConfigPath)) {
  Write-Error "Configuration file not found: $ConfigPath"
  Write-Host "Please specify a valid configuration file path."
  exit 1
}

# Verify it's a JSON file
if (-not $ConfigPath.EndsWith(".json")) {
  Write-Error "Configuration file must be a JSON file: $ConfigPath"
  exit 1
}

# Load and validate the configuration file
try {
  $ConfigContent = Get-Content -Path $ConfigPath | ConvertFrom-Json
  
  # Check if this looks like a Fabric Archive Bot configuration file
  if (-not ($ConfigContent.PSObject.Properties['ServicePrincipal'] -or 
      $ConfigContent.PSObject.Properties['AppSecret'] -or
      $ConfigContent.PSObject.Properties['TenantId'] -or
      $ConfigContent.PSObject.Properties['AppId'])) {
    Write-Error "The specified file does not appear to be a valid Fabric Archive Bot configuration file."
    Write-Host "Expected to find ServicePrincipal, AppSecret, TenantId, or AppId properties."
    exit 1
  }
  
  # Determine the version
  $ConfigVersion = if ($ConfigContent.PSObject.Properties['Version']) { 
    $ConfigContent.Version
  }
  else { 
    "v1.0"
  }
  
  # Check if the ServicePrincipal has been properly configured
  if ($ConfigContent.PSObject.Properties['ServicePrincipal']) {
    $templateValues = @()
    foreach ($prop in $ConfigContent.ServicePrincipal.PSObject.Properties) {
      if ($prop.Value -is [string] -and $prop.Value.StartsWith("YOUR_")) {
        $templateValues += "ServicePrincipal.$($prop.Name) = $($prop.Value)"
      }
    }
    
    if ($templateValues.Count -gt 0) {
      Write-Error "The ServicePrincipal object contains template values that need to be configured:"
      foreach ($templateValue in $templateValues) {
        Write-Error "  - $templateValue"
      }
      Write-Error "Please update these values with your actual configuration before proceeding."
      exit 1
    }
  }
  
  Write-Host "Valid configuration file found: $(Split-Path -Leaf $ConfigPath) (Version: $ConfigVersion)" -ForegroundColor Green
  
}
catch {
  Write-Error "Failed to parse configuration file: $($_.Exception.Message)"
  exit 1
}

# Load the raw config content for the environment variable
$ConfigObject = Get-Content -Path $ConfigPath

if ($ConfigVersion -eq "v1.0") {
  Write-Host "Consider migrating to v2.0 using: .\helpers\ConvertTo-FabricArchiveBotV2.ps1" -ForegroundColor Yellow
}

# Remove all new lines, carriage returns, and whitespace from the ConfigObject
$ConfigObject = $ConfigObject -replace '\r\n', '' -replace '\n', '' -replace '\r', '' -replace '\s', ''

# Set the FabricArchiveBot_ConfigObject user environment variable
[System.Environment]::SetEnvironmentVariable("FabricArchiveBot_ConfigObject", $ConfigObject, "User")

Write-Host "Successfully set FabricArchiveBot_ConfigObject environment variable using $ConfigVersion configuration from: $(Split-Path -Leaf $ConfigPath)" -ForegroundColor Green