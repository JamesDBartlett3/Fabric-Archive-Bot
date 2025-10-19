<#
.SYNOPSIS
  Compares Microsoft Fabric item definitions from various sources.

.DESCRIPTION
  This script supports three comparison modes:
  
  1. Cloud-to-Local: Compare a Fabric workspace item with a local Git repository version
  2. Cloud-to-Cloud: Compare two Fabric workspace items
  3. Local-to-Local: Compare two local Git repository versions
  
  The comparison is displayed in git-diff style format with color-coded output.

.PARAMETER Workspace
  The GUID or display name of the Fabric workspace containing the first item (CloudToLocal and CloudToCloud modes).
  The script automatically detects whether you provided a GUID or display name.

.PARAMETER Item
  The GUID or display name of the first Fabric item to compare (CloudToLocal and CloudToCloud modes).
  The script automatically detects whether you provided a GUID or display name.

.PARAMETER LocalPath
  The local file system path to the first item definition (CloudToLocal and LocalToLocal modes).
  Can be either the root folder (e.g., "MyReport.Report") or any file within it.
  If a file is provided, the script will automatically use its parent directory.

.PARAMETER CompareWorkspace
  The GUID or display name of the Fabric workspace containing the second item (CloudToCloud mode only).
  The script automatically detects whether you provided a GUID or display name.

.PARAMETER CompareItem
  The GUID or display name of the second Fabric item to compare (CloudToCloud mode only).
  The script automatically detects whether you provided a GUID or display name.

.PARAMETER CompareLocalPath
  The local file system path to the second item definition (LocalToLocal mode only).
  Can be either the root folder (e.g., "MyReport.Report") or any file within it.

.PARAMETER ForceReauth
  Forces re-authentication even if an Azure context exists (CloudToLocal and CloudToCloud modes).

.PARAMETER ReverseDirection
  Reverses the diff direction. By default, the first item is shown as "old" (red -) and 
  the second item as "new" (green +). This parameter swaps that direction.

.PARAMETER FirstItemLabel
  Custom label for the first item in the comparison output. If not provided, a smart 
  label will be generated based on the comparison mode.

.PARAMETER SecondItemLabel
  Custom label for the second item in the comparison output. If not provided, a smart 
  label will be generated based on the comparison mode.

.PARAMETER SkipPathValidation
  Skips validation that both paths have compatible item type folder names (LocalToLocal mode only).
  By default, both paths must have the same item type extension (e.g., both end in ".Report").

.EXAMPLE
  # Cloud-to-Local: Compare workspace item with local repository (using display names)
  .\Compare-FabricItemDefinition.ps1 -Workspace "Production" `
    -Item "Sales Report" `
    -LocalPath "C:\Repos\MyProject\MyReport.Report"

.EXAMPLE
  # Cloud-to-Local: Compare workspace item with local repository (using GUIDs)
  .\Compare-FabricItemDefinition.ps1 -Workspace "12345678-1234-1234-1234-123456789012" `
    -Item "87654321-4321-4321-4321-210987654321" `
    -LocalPath "C:\Repos\MyProject\MyReport.Report"

.EXAMPLE
  # Cloud-to-Cloud: Compare same report in DEV vs PROD workspace (using display names)
  .\Compare-FabricItemDefinition.ps1 `
    -Workspace "Development" `
    -Item "Sales Report" `
    -CompareWorkspace "Production" `
    -CompareItem "Sales Report" `
    -FirstItemLabel "DEV" `
    -SecondItemLabel "PROD"

.EXAMPLE
  # Cloud-to-Cloud: Compare two versions in the same workspace (using display names)
  .\Compare-FabricItemDefinition.ps1 `
    -Workspace "Development" `
    -Item "Customer Model v1" `
    -CompareWorkspace "Development" `
    -CompareItem "Customer Model v2" `
    -FirstItemLabel "V1" `
    -SecondItemLabel "V2"

.EXAMPLE
  # Local-to-Local: Compare main vs dev branch
  .\Compare-FabricItemDefinition.ps1 `
    -LocalPath "C:\Repos\main\MyReport.Report" `
    -CompareLocalPath "C:\Repos\dev\MyReport.Report" `
    -FirstItemLabel "MAIN" `
    -SecondItemLabel "DEV"

.EXAMPLE
  # Local-to-Local: Compare today's backup vs yesterday's
  .\Compare-FabricItemDefinition.ps1 `
    -LocalPath ".\Workspaces\2025\10\19\Black\MyReport.Report" `
    -CompareLocalPath ".\Workspaces\2025\10\18\Black\MyReport.Report"

.EXAMPLE
  # Reverse direction to show local as "new" (green) and cloud as "old" (red)
  .\Compare-FabricItemDefinition.ps1 `
    -WorkspaceId "12345678-1234-1234-1234-123456789012" `
    -ItemId "87654321-4321-4321-4321-210987654321" `
    -LocalPath "C:\Repos\MyProject\MyReport.Report" `
    -ReverseDirection

.NOTES
  Author: Fabric Archive Bot
  Requires: PowerShell 7+
  Requires: Az.Accounts module for authentication (CloudToLocal and CloudToCloud modes only)
#>

[CmdletBinding(DefaultParameterSetName = 'CloudToLocal')]
param(
  # CloudToLocal and CloudToCloud parameters
  [Parameter(ParameterSetName = 'CloudToLocal', Mandatory = $true)]
  [Parameter(ParameterSetName = 'CloudToCloud', Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$Workspace,

  [Parameter(ParameterSetName = 'CloudToLocal', Mandatory = $true)]
  [Parameter(ParameterSetName = 'CloudToCloud', Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$Item,

  # CloudToLocal and LocalToLocal parameters
  [Parameter(ParameterSetName = 'CloudToLocal', Mandatory = $true)]
  [Parameter(ParameterSetName = 'LocalToLocal', Mandatory = $true)]
  [ValidateScript({ Test-Path $_ })]
  [string]$LocalPath,

  # CloudToCloud parameters
  [Parameter(ParameterSetName = 'CloudToCloud', Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$CompareWorkspace,

  [Parameter(ParameterSetName = 'CloudToCloud', Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$CompareItem,

  # LocalToLocal parameters
  [Parameter(ParameterSetName = 'LocalToLocal', Mandatory = $true)]
  [ValidateScript({ Test-Path $_ })]
  [string]$CompareLocalPath,

  # Common parameters
  [Parameter(ParameterSetName = 'CloudToLocal', Mandatory = $false)]
  [Parameter(ParameterSetName = 'CloudToCloud', Mandatory = $false)]
  [switch]$ForceReauth,

  [Parameter(Mandatory = $false)]
  [switch]$ReverseDirection,

  [Parameter(Mandatory = $false)]
  [string]$FirstItemLabel,

  [Parameter(Mandatory = $false)]
  [string]$SecondItemLabel,

  [Parameter(ParameterSetName = 'LocalToLocal', Mandatory = $false)]
  [switch]$SkipPathValidation
)

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

# Function to generate smart labels for comparison
function Get-FABSmartLabel {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet('Local', 'Cloud')]
    [string]$SourceType,
    
    [Parameter(Mandatory = $false)]
    [string]$WorkspaceId,
    
    [Parameter(Mandatory = $false)]
    [string]$ItemId
  )
  
  if ($SourceType -eq 'Local') {
    # For local paths, use the item folder name and its parent
    $itemFolder = Split-Path $Path -Leaf
    $parentFolder = Split-Path (Split-Path $Path -Parent) -Leaf
    
    if ($parentFolder) {
      return "$itemFolder ($parentFolder)"
    }
    else {
      return $itemFolder
    }
  }
  elseif ($SourceType -eq 'Cloud') {
    # For cloud items, return a label based on available info
    # In the future, could fetch workspace/item names from API
    return "CLOUD"
  }
}

# Function to validate path compatibility
function Test-FABPathCompatibility {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path1,
    
    [Parameter(Mandatory = $true)]
    [string]$Path2
  )
  
  $folder1 = Split-Path $Path1 -Leaf
  $folder2 = Split-Path $Path2 -Leaf
  
  # Extract item type extension (e.g., ".Report", ".SemanticModel", ".Notebook")
  if ($folder1 -match '\.(\w+)$') {
    $type1 = $Matches[1]
  }
  else {
    Write-Warning "Path 1 does not appear to be a Fabric item folder: $folder1"
    return $false
  }
  
  if ($folder2 -match '\.(\w+)$') {
    $type2 = $Matches[1]
  }
  else {
    Write-Warning "Path 2 does not appear to be a Fabric item folder: $folder2"
    return $false
  }
  
  if ($type1 -ne $type2) {
    Write-Warning "Item type mismatch: '$folder1' (.$type1) vs '$folder2' (.$type2)"
    return $false
  }
  
  Write-Verbose "Path compatibility verified: Both items are of type '.$type1'"
  return $true
}

# Function to test if a string is a GUID
function Test-FABIsGuid {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Value
  )
  
  $guidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  return $Value -match $guidPattern
}

# Function to resolve workspace name or GUID to GUID
function Get-FABWorkspaceId {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Workspace,
    
    [Parameter(Mandatory = $true)]
    [string]$AccessToken
  )
  
  # If already a GUID, return it
  if (Test-FABIsGuid -Value $Workspace) {
    Write-Verbose "Workspace parameter is a GUID: $Workspace"
    return $Workspace
  }
  
  # Otherwise, look up by display name
  Write-Host "Resolving workspace name '$Workspace' to GUID..." -ForegroundColor Cyan
  
  try {
    $headers = @{
      'Authorization' = "Bearer $AccessToken"
      'Content-Type'  = 'application/json'
    }
    
    $uri = "https://api.fabric.microsoft.com/v1/workspaces"
    Write-Verbose "Calling GET $uri"
    
    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop
    
    # Find workspace by display name (case-insensitive)
    $matchingWorkspace = $response.value | Where-Object { $_.displayName -eq $Workspace }
    
    if (-not $matchingWorkspace) {
      throw "Workspace '$Workspace' not found. Please check the name and try again."
    }
    
    if ($matchingWorkspace -is [array] -and $matchingWorkspace.Count -gt 1) {
      Write-Warning "Multiple workspaces found with name '$Workspace'. Using the first one."
      $matchingWorkspace = $matchingWorkspace[0]
    }
    
    Write-Host "Found workspace: $($matchingWorkspace.displayName) ($($matchingWorkspace.id))" -ForegroundColor Green
    return $matchingWorkspace.id
  }
  catch {
    throw "Failed to resolve workspace '$Workspace': $_"
  }
}

# Function to resolve item name or GUID to GUID
function Get-FABItemId {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceId,
    
    [Parameter(Mandatory = $true)]
    [string]$Item,
    
    [Parameter(Mandatory = $true)]
    [string]$AccessToken
  )
  
  # If already a GUID, return it
  if (Test-FABIsGuid -Value $Item) {
    Write-Verbose "Item parameter is a GUID: $Item"
    return $Item
  }
  
  # Otherwise, look up by display name
  Write-Host "Resolving item name '$Item' to GUID..." -ForegroundColor Cyan
  
  try {
    $headers = @{
      'Authorization' = "Bearer $AccessToken"
      'Content-Type'  = 'application/json'
    }
    
    $uri = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/items"
    Write-Verbose "Calling GET $uri"
    
    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop
    
    # Find item by display name (case-insensitive)
    $matchingItem = $response.value | Where-Object { $_.displayName -eq $Item }
    
    if (-not $matchingItem) {
      throw "Item '$Item' not found in workspace. Please check the name and try again."
    }
    
    if ($matchingItem -is [array] -and $matchingItem.Count -gt 1) {
      Write-Warning "Multiple items found with name '$Item'. Using the first one: $($matchingItem[0].type)"
      $matchingItem = $matchingItem[0]
    }
    
    Write-Host "Found item: $($matchingItem.displayName) ($($matchingItem.type)) - $($matchingItem.id)" -ForegroundColor Green
    return $matchingItem.id
  }
  catch {
    throw "Failed to resolve item '$Item': $_"
  }
}

# Function to get Fabric access token
function Get-FABAccessToken {
  [CmdletBinding()]
  param(
    [switch]$Force
  )
  
  try {
    Write-Verbose "Checking for Az.Accounts module..."
    if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
      throw "Az.Accounts module is not installed. Install it with: Install-Module Az.Accounts -Scope CurrentUser"
    }
    
    Import-Module Az.Accounts -ErrorAction Stop
    
    Write-Verbose "Checking Azure context..."
    $context = Get-AzContext
    
    if (-not $context -or $Force) {
      if ($Force) {
        Write-Host "Forcing re-authentication..." -ForegroundColor Yellow
        Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
      }
      Write-Host "No Azure context found. Initiating device code login..." -ForegroundColor Yellow
      Write-Host "A browser window will open for authentication, or you can use the device code provided." -ForegroundColor Yellow
      Connect-AzAccount -UseDeviceAuthentication -ErrorAction Stop | Out-Null
      $context = Get-AzContext
    }
    
    Write-Verbose "Getting access token for Fabric API..."
    # Use the same resource URL as FabricPS-PBIP module
    $token = Get-AzAccessToken -ResourceUrl "https://api.fabric.microsoft.com" -ErrorAction Stop
    
    if (-not $token.Token) {
      throw "Failed to retrieve access token"
    }
    
    # Convert SecureString to plain text if necessary
    $accessToken = $token.Token
    if ($accessToken -is [System.Security.SecureString]) {
      $accessToken = ConvertFrom-SecureString -SecureString $accessToken -AsPlainText
    }
    
    Write-Host "Successfully authenticated as: $($context.Account.Id)" -ForegroundColor Green
    Write-Verbose "Token expires: $($token.ExpiresOn)"
    Write-Verbose "Token type: $($token.Type)"
    Write-Verbose "Tenant ID: $($context.Tenant.Id)"
    
    return $accessToken
  }
  catch {
    Write-Host "Authentication error details: $_" -ForegroundColor Red
    Write-Host "Try running with -ForceReauth parameter" -ForegroundColor Yellow
    throw "Authentication failed: $_"
  }
}

# Function to get item definition from Fabric
function Get-FABItemDefinition {
  [CmdletBinding()]
  param(
    [string]$WorkspaceId,
    [string]$ItemId,
    [string]$AccessToken
  )
  
  try {
    $headers = @{
      'Authorization' = "Bearer $AccessToken"
      'Content-Type'  = 'application/json'
    }
    
    $uri = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/items/$ItemId/getDefinition"
    
    Write-Verbose "Calling POST $uri"
    Write-Host "Retrieving item definition from Fabric..." -ForegroundColor Cyan
    
    # Initial request - may return 200 OK or 202 Accepted (long-running operation)
    $response = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -ErrorAction Stop
    
    # Handle long-running operation (202 Accepted)
    if ($response.StatusCode -eq 202) {
      Write-Host "Operation accepted. Waiting for completion..." -ForegroundColor Yellow
      
      $operationLocation = $response.Headers['Location']
      # Headers can be arrays, so get the first value
      if ($operationLocation -is [array]) {
        $operationLocation = $operationLocation[0]
      }
      
      $retryAfterHeader = $response.Headers['Retry-After']
      if ($retryAfterHeader -is [array]) {
        $retryAfterHeader = $retryAfterHeader[0]
      }
      $retryAfter = if ($retryAfterHeader) { [int]$retryAfterHeader } else { 5 }
      
      if (-not $operationLocation) {
        throw "Received 202 Accepted but no Location header provided"
      }
      
      Write-Verbose "Operation location: $operationLocation"
      Write-Verbose "Retry after: $retryAfter seconds"
      
      # Poll the operation status until complete
      $maxRetries = 60  # Maximum 5 minutes with 5-second intervals
      $retryCount = 0
      
      while ($retryCount -lt $maxRetries) {
        Start-Sleep -Seconds $retryAfter
        $retryCount++
        
        Write-Verbose "Polling operation status (attempt $retryCount/$maxRetries)..."
        
        $statusResponse = Invoke-WebRequest -Uri $operationLocation -Method Get -Headers $headers -ErrorAction Stop
        $statusContent = $statusResponse.Content | ConvertFrom-Json -Depth 100
        
        Write-Verbose "Operation status: $($statusContent.status)"
        
        if ($statusContent.status -ieq 'Succeeded') {
          Write-Host "Operation completed successfully" -ForegroundColor Green
          
          # Check if there's a Location header in the status response for the result
          $resultLocation = $statusResponse.Headers['Location']
          if ($resultLocation -is [array]) {
            $resultLocation = $resultLocation[0]
          }
          
          if ($resultLocation) {
            Write-Verbose "Retrieving result from: $resultLocation"
            $response = Invoke-WebRequest -Uri $resultLocation -Method Get -Headers $headers -ErrorAction Stop
          }
          else {
            Write-Verbose "No result location found, operation may not return data"
            # Some operations don't return data
          }
          break
        }
        elseif ($statusContent.status -ieq 'Failed') {
          throw "Operation failed: $($statusContent.error | ConvertTo-Json -Depth 10 -Compress)"
        }
        elseif ($statusContent.status -imatch 'Running|NotStarted|InProgress') {
          Write-Verbose "Operation still in progress..."
          continue
        }
        else {
          throw "Unexpected status: $($statusContent.status)"
        }
      }
      
      if ($retryCount -ge $maxRetries) {
        throw "Operation timed out after $maxRetries attempts"
      }
    }
    
    # Parse and return the response content with full depth
    $result = $response.Content | ConvertFrom-Json -Depth 100
    
    Write-Verbose "Response structure: $($result | ConvertTo-Json -Depth 10 -Compress)"
    
    if ($result.definition -and $result.definition.parts) {
      Write-Verbose "Found $($result.definition.parts.Count) parts in definition"
    }
    else {
      Write-Warning "Response does not contain expected definition.parts structure"
      Write-Verbose "Response content (first 500 chars): $($response.Content.Substring(0, [Math]::Min(500, $response.Content.Length)))"
    }
    
    return $result
  }
  catch {
    throw "Failed to retrieve item definition: $_"
  }
}

# Function to extract and decode definition parts
function ConvertFrom-FABDefinitionParts {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object]$Definition
  )
  
  $extractedFiles = @{}
  
  if (-not $Definition.definition) {
    Write-Warning "Definition object does not contain 'definition' property"
    return $extractedFiles
  }
  
  if (-not $Definition.definition.parts) {
    Write-Warning "Definition does not contain 'parts' array"
    return $extractedFiles
  }
  
  if ($Definition.definition.parts.Count -eq 0) {
    Write-Warning "Definition parts array is empty"
    return $extractedFiles
  }
  
  foreach ($part in $Definition.definition.parts) {
    $path = $part.path
    $payload = $part.payload
    $payloadType = $part.payloadType
    
    Write-Verbose "Processing part: $path (Type: $payloadType)"
    
    if ($payloadType -eq 'InlineBase64') {
      $decodedContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload))
      $extractedFiles[$path] = $decodedContent
    }
    else {
      Write-Warning "Unsupported payload type '$payloadType' for path: $path"
    }
  }
  
  return $extractedFiles
}

# Function to read local definition files
function Get-FABLocalDefinitionFiles {
  [CmdletBinding()]
  param(
    [string]$LocalPath
  )
  
  $localFiles = @{}
  
  Write-Host "Reading local files from: $LocalPath" -ForegroundColor Cyan
  
  # Resolve to absolute path for consistent substring calculation
  $resolvedPath = (Resolve-Path $LocalPath).Path
  
  # Get all files recursively
  $files = Get-ChildItem -Path $resolvedPath -File -Recurse
  
  foreach ($file in $files) {
    # Calculate relative path from the root
    $relativePath = $file.FullName.Substring($resolvedPath.Length).TrimStart('\', '/')
    # Normalize path separators to forward slashes (as used in Fabric)
    $relativePath = $relativePath -replace '\\', '/'
    
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    $localFiles[$relativePath] = $content
    
    Write-Verbose "Loaded local file: $relativePath"
  }
  
  return $localFiles
}

# Function to compare two file sets and display diff
function Show-FABFileDiff {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$FirstFiles,
    
    [Parameter(Mandatory = $true)]
    [hashtable]$SecondFiles,
    
    [Parameter(Mandatory = $true)]
    [string]$FirstLabel,
    
    [Parameter(Mandatory = $true)]
    [string]$SecondLabel,
    
    [Parameter(Mandatory = $false)]
    [switch]$ReverseDirection
  )
  
  # Determine diff direction based on parameter
  if ($ReverseDirection) {
    $oldLabel = $SecondLabel
    $newLabel = $FirstLabel
  }
  else {
    $oldLabel = $FirstLabel
    $newLabel = $SecondLabel
  }
  
  $allPaths = ($FirstFiles.Keys + $SecondFiles.Keys) | Select-Object -Unique | Sort-Object
  $hasDifferences = $false
  
  foreach ($path in $allPaths) {
    $firstContent = $FirstFiles[$path]
    $secondContent = $SecondFiles[$path]
    
    if (-not $firstContent) {
      Write-Host "`n=== File only in ${SecondLabel}: $path ===" -ForegroundColor Magenta
      $hasDifferences = $true
      continue
    }
    
    if (-not $secondContent) {
      Write-Host "`n=== File only in ${FirstLabel}: $path ===" -ForegroundColor Magenta
      $hasDifferences = $true
      continue
    }
    
    # Compare content
    if ($firstContent -ne $secondContent) {
      Write-Host "`n=== Differences in: $path ===" -ForegroundColor Yellow
      Write-Host "  Comparing: $oldLabel (old) vs $newLabel (new)" -ForegroundColor Gray
      $hasDifferences = $true
      
      # Normalize line endings for comparison
      $firstNormalized = $firstContent -replace "`r`n", "`n" -replace "`r", "`n"
      $secondNormalized = $secondContent -replace "`r`n", "`n" -replace "`r", "`n"
      
      # Check if the only difference is line endings
      if ($firstNormalized -eq $secondNormalized) {
        Write-Host "Files differ only in line endings (CRLF vs LF)" -ForegroundColor Cyan
        Write-Verbose "Different line ending styles detected"
        continue
      }
      
      # Determine which content to use as old vs new
      if ($ReverseDirection) {
        $oldContent = $secondNormalized
        $newContent = $firstNormalized
      }
      else {
        $oldContent = $firstNormalized
        $newContent = $secondNormalized
      }
      
      # Show file statistics
      $oldLines = $oldContent -split "`n"
      $newLines = $newContent -split "`n"
      Write-Verbose "${oldLabel}: $($oldLines.Count) lines, ${newLabel}: $($newLines.Count) lines"
      
      # Create temporary files for diff
      $tempOld = New-TemporaryFile
      $tempNew = New-TemporaryFile
      
      # Write with normalized line endings (LF) to avoid Git confusion
      [System.IO.File]::WriteAllText($tempOld.FullName, $oldContent, [System.Text.UTF8Encoding]::new($false))
      [System.IO.File]::WriteAllText($tempNew.FullName, $newContent, [System.Text.UTF8Encoding]::new($false))
      
      # Use git diff if available, otherwise show basic diff
      if (Get-Command git -ErrorAction SilentlyContinue) {
        $tempOldRenamed = Join-Path $tempOld.DirectoryName "$path.old"
        $tempNewRenamed = Join-Path $tempNew.DirectoryName "$path.new"
        
        $tempOld | Rename-Item -NewName "$path.old"
        $tempNew | Rename-Item -NewName "$path.new"
        
        Write-Verbose "Running git diff: $oldLabel (old) -> $newLabel (new)"
        
        # Save current Git config and disable autocrlf warnings for this operation
        $env:GIT_CONFIG_PARAMETERS = "'core.autocrlf=false'"
        
        # Run git diff with better formatting
        # Git diff always treats first file as old (-) and second as new (+)
        $diffOutput = & git diff --no-index --no-color -U3 "$tempOldRenamed" "$tempNewRenamed" 2>&1 | 
        Where-Object { $_ -notmatch 'LF will be replaced|CRLF will be replaced' }
        
        # Clear the Git config override
        $env:GIT_CONFIG_PARAMETERS = $null
        
        if ($diffOutput) {
          $diffLineCount = 0
          foreach ($line in $diffOutput) {
            # Skip the first few header lines for cleaner output
            if ($line -match '^(diff|index|---|\+\+\+)') {
              Write-Verbose $line
              continue
            }
            
            if ($line -match '^@@') {
              Write-Host $line -ForegroundColor Cyan
            }
            elseif ($line -match '^\+') {
              Write-Host $line -ForegroundColor Green
              $diffLineCount++
            }
            elseif ($line -match '^-') {
              Write-Host $line -ForegroundColor Red
              $diffLineCount++
            }
            else {
              # Only show context lines if there are actual changes nearby
              Write-Host $line -ForegroundColor DarkGray
            }
          }
          Write-Host "`nTotal changed lines: $diffLineCount" -ForegroundColor Yellow
        }
        else {
          Write-Verbose "Git diff produced no output"
        }
        
        Remove-Item $tempOldRenamed -Force -ErrorAction SilentlyContinue
        Remove-Item $tempNewRenamed -Force -ErrorAction SilentlyContinue
      }
      else {
        # Fallback: show simple line-by-line comparison
        $oldLines = $oldContent -split "`n"
        $newLines = $newContent -split "`n"
        
        Write-Host "--- $oldLabel" -ForegroundColor Red
        Write-Host "+++ $newLabel" -ForegroundColor Green
        
        $maxLines = [Math]::Max($oldLines.Count, $newLines.Count)
        
        for ($i = 0; $i -lt $maxLines; $i++) {
          if ($i -ge $oldLines.Count) {
            Write-Host "+ $($newLines[$i])" -ForegroundColor Green
          }
          elseif ($i -ge $newLines.Count) {
            Write-Host "- $($oldLines[$i])" -ForegroundColor Red
          }
          elseif ($oldLines[$i] -ne $newLines[$i]) {
            Write-Host "- $($oldLines[$i])" -ForegroundColor Red
            Write-Host "+ $($newLines[$i])" -ForegroundColor Green
          }
        }
      }
    }
    else {
      Write-Verbose "No differences in: $path"
    }
  }
  
  if (-not $hasDifferences) {
    Write-Host "`n✓ No differences found between $FirstLabel and $SecondLabel!" -ForegroundColor Green
  }
  else {
    Write-Host "`n⚠ Differences detected between $FirstLabel and $SecondLabel" -ForegroundColor Yellow
  }
}

# Main execution
try {
  Write-Host "Starting Fabric item comparison..." -ForegroundColor Cyan
  
  # Determine comparison mode
  $comparisonMode = $PSCmdlet.ParameterSetName
  Write-Verbose "Comparison mode: $comparisonMode"
  
  # Initialize variables for files and labels
  $firstFiles = $null
  $secondFiles = $null
  $firstLabel = $null
  $secondLabel = $null
  
  switch ($comparisonMode) {
    'CloudToLocal' {
      Write-Host "Mode: Cloud-to-Local Comparison" -ForegroundColor Cyan
      Write-Host "Workspace: $Workspace" -ForegroundColor Gray
      Write-Host "Item: $Item" -ForegroundColor Gray
      
      # Normalize LocalPath - if user provided a file, use its parent directory
      $originalPath = $LocalPath
      if (Test-Path $LocalPath -PathType Leaf) {
        $LocalPath = Split-Path $LocalPath -Parent
        Write-Verbose "LocalPath was a file, using parent directory: $LocalPath"
      }
      
      # Verify the normalized path is a directory
      if (-not (Test-Path $LocalPath -PathType Container)) {
        throw "LocalPath must be a directory or a file within the item definition folder. Provided: $originalPath"
      }
      
      Write-Host "Local Path: $LocalPath" -ForegroundColor Gray
      
      # Authenticate and get access token
      $accessToken = Get-FABAccessToken -Force:$ForceReauth
      
      # Resolve workspace and item to GUIDs
      $workspaceId = Get-FABWorkspaceId -Workspace $Workspace -AccessToken $accessToken
      $itemId = Get-FABItemId -WorkspaceId $workspaceId -Item $Item -AccessToken $accessToken
      
      # Get item definition from Fabric
      $cloudDefinition = Get-FABItemDefinition -WorkspaceId $workspaceId -ItemId $itemId -AccessToken $accessToken
      
      # Extract and decode cloud files
      $firstFiles = ConvertFrom-FABDefinitionParts -Definition $cloudDefinition
      Write-Host "Retrieved $($firstFiles.Count) file(s) from cloud" -ForegroundColor Green
      
      # Get local files
      $secondFiles = Get-FABLocalDefinitionFiles -LocalPath $LocalPath
      Write-Host "Retrieved $($secondFiles.Count) file(s) from local repository" -ForegroundColor Green
      
      # Set labels
      if (-not $FirstItemLabel) {
        $FirstItemLabel = "CLOUD"
      }
      if (-not $SecondItemLabel) {
        $SecondItemLabel = Get-FABSmartLabel -Path $LocalPath -SourceType 'Local'
      }
      
      $firstLabel = $FirstItemLabel
      $secondLabel = $SecondItemLabel
    }
    
    'CloudToCloud' {
      Write-Host "Mode: Cloud-to-Cloud Comparison" -ForegroundColor Cyan
      Write-Host "First Item  - Workspace: $Workspace, Item: $Item" -ForegroundColor Gray
      Write-Host "Second Item - Workspace: $CompareWorkspace, Item: $CompareItem" -ForegroundColor Gray
      
      # Authenticate and get access token
      $accessToken = Get-FABAccessToken -Force:$ForceReauth
      
      # Resolve first workspace and item to GUIDs
      Write-Host "`nResolving first item..." -ForegroundColor Cyan
      $workspaceId = Get-FABWorkspaceId -Workspace $Workspace -AccessToken $accessToken
      $itemId = Get-FABItemId -WorkspaceId $workspaceId -Item $Item -AccessToken $accessToken
      
      # Get first item definition from Fabric
      $firstDefinition = Get-FABItemDefinition -WorkspaceId $workspaceId -ItemId $itemId -AccessToken $accessToken
      
      # Extract and decode first item files
      $firstFiles = ConvertFrom-FABDefinitionParts -Definition $firstDefinition
      Write-Host "Retrieved $($firstFiles.Count) file(s) from first item" -ForegroundColor Green
      
      # Resolve second workspace and item to GUIDs
      Write-Host "`nResolving second item..." -ForegroundColor Cyan
      $compareWorkspaceId = Get-FABWorkspaceId -Workspace $CompareWorkspace -AccessToken $accessToken
      $compareItemId = Get-FABItemId -WorkspaceId $compareWorkspaceId -Item $CompareItem -AccessToken $accessToken
      
      # Get second item definition from Fabric
      $secondDefinition = Get-FABItemDefinition -WorkspaceId $compareWorkspaceId -ItemId $compareItemId -AccessToken $accessToken
      
      # Extract and decode second item files
      $secondFiles = ConvertFrom-FABDefinitionParts -Definition $secondDefinition
      Write-Host "Retrieved $($secondFiles.Count) file(s) from second item" -ForegroundColor Green
      
      # Set labels
      if (-not $FirstItemLabel) {
        $FirstItemLabel = "ITEM1"
      }
      if (-not $SecondItemLabel) {
        $SecondItemLabel = "ITEM2"
      }
      
      $firstLabel = $FirstItemLabel
      $secondLabel = $SecondItemLabel
    }
    
    'LocalToLocal' {
      Write-Host "Mode: Local-to-Local Comparison" -ForegroundColor Cyan
      
      # Normalize first LocalPath
      $originalPath1 = $LocalPath
      if (Test-Path $LocalPath -PathType Leaf) {
        $LocalPath = Split-Path $LocalPath -Parent
        Write-Verbose "First LocalPath was a file, using parent directory: $LocalPath"
      }
      
      # Verify first path is a directory
      if (-not (Test-Path $LocalPath -PathType Container)) {
        throw "LocalPath must be a directory or a file within the item definition folder. Provided: $originalPath1"
      }
      
      Write-Host "First Path: $LocalPath" -ForegroundColor Gray
      
      # Normalize second LocalPath
      $originalPath2 = $CompareLocalPath
      if (Test-Path $CompareLocalPath -PathType Leaf) {
        $CompareLocalPath = Split-Path $CompareLocalPath -Parent
        Write-Verbose "Second LocalPath was a file, using parent directory: $CompareLocalPath"
      }
      
      # Verify second path is a directory
      if (-not (Test-Path $CompareLocalPath -PathType Container)) {
        throw "CompareLocalPath must be a directory or a file within the item definition folder. Provided: $originalPath2"
      }
      
      Write-Host "Second Path: $CompareLocalPath" -ForegroundColor Gray
      
      # Validate path compatibility unless skip is requested
      if (-not $SkipPathValidation) {
        Write-Verbose "Validating path compatibility..."
        $pathsCompatible = Test-FABPathCompatibility -Path1 $LocalPath -Path2 $CompareLocalPath
        
        if (-not $pathsCompatible) {
          throw "Paths are not compatible. Both paths should point to the same item type (e.g., both .Report). Use -SkipPathValidation to bypass this check."
        }
      }
      else {
        Write-Warning "Path validation skipped. Comparing folders with potentially different item types."
      }
      
      # Get first local files
      $firstFiles = Get-FABLocalDefinitionFiles -LocalPath $LocalPath
      Write-Host "Retrieved $($firstFiles.Count) file(s) from first path" -ForegroundColor Green
      
      # Get second local files
      $secondFiles = Get-FABLocalDefinitionFiles -LocalPath $CompareLocalPath
      Write-Host "Retrieved $($secondFiles.Count) file(s) from second path" -ForegroundColor Green
      
      # Set labels
      if (-not $FirstItemLabel) {
        $FirstItemLabel = Get-FABSmartLabel -Path $LocalPath -SourceType 'Local'
      }
      if (-not $SecondItemLabel) {
        $SecondItemLabel = Get-FABSmartLabel -Path $CompareLocalPath -SourceType 'Local'
      }
      
      $firstLabel = $FirstItemLabel
      $secondLabel = $SecondItemLabel
    }
  }
  
  # Display diff direction
  if ($ReverseDirection) {
    Write-Host "`nDiff direction: $secondLabel (old) -> $firstLabel (new)" -ForegroundColor Cyan
    Write-Host "Green (+) lines are in $firstLabel, Red (-) lines are in $secondLabel" -ForegroundColor Gray
  }
  else {
    Write-Host "`nDiff direction: $firstLabel (old) -> $secondLabel (new)" -ForegroundColor Cyan
    Write-Host "Green (+) lines are in $secondLabel, Red (-) lines are in $firstLabel" -ForegroundColor Gray
  }
  
  # Compare and display differences
  Show-FABFileDiff -FirstFiles $firstFiles -SecondFiles $secondFiles `
    -FirstLabel $firstLabel -SecondLabel $secondLabel `
    -ReverseDirection:$ReverseDirection
  
  Write-Host "`nComparison complete!" -ForegroundColor Cyan
}
catch {
  Write-Error "Error: $_"
  exit 1
}