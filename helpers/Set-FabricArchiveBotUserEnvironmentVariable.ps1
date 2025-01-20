# Create a user environment variable called FabricArchiveBot_ConfigObject with the value from the Config.json file

# Get the content of the Config.json file
$ConfigObject = Get-Content -Path "$PSScriptRoot\..\Config.json"

# Remove all new lines, carriage returns, and whitespace from the ConfigObject
$ConfigObject = $ConfigObject -replace '\r\n', '' -replace '\n', '' -replace '\r', '' -replace '\s', ''

# Set the FabricArchiveBot_ConfigObject user environment variable
[System.Environment]::SetEnvironmentVariable("FabricArchiveBot_ConfigObject", $ConfigObject, "User")