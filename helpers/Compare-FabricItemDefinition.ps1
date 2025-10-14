<#
.SYNOPSIS
    Compares a Microsoft Fabric workspace item with its local Git repository version.

.DESCRIPTION
    This script uses the Microsoft Fabric Get Item Definition REST API to retrieve the current
    definition of an item from a workspace and compares it with the local version in a Git repository.
    The comparison is displayed in git-diff style format.

.PARAMETER WorkspaceId
    The GUID of the Fabric workspace containing the item.

.PARAMETER ItemId
    The GUID of the Fabric item to compare.

.PARAMETER LocalPath
    The local file system path to the item definition in the Git repository.
    Can be either the root folder (e.g., "MyReport.Report") or any file within it.
    If a file is provided, the script will automatically use its parent directory.

.PARAMETER ForceReauth
    Forces re-authentication even if an Azure context exists.

.PARAMETER LocalAsNew
    Reverses the diff direction to show local as "new" and cloud as "old".
    By default, cloud is shown as "new" (green +) and local as "old" (red -).

.EXAMPLE
    .\Compare-FabricItemDefinition.ps1 -WorkspaceId "12345678-1234-1234-1234-123456789012" `
        -ItemId "87654321-4321-4321-4321-210987654321" `
        -LocalPath "C:\Repos\MyProject\MyReport.Report"

.EXAMPLE
    .\Compare-FabricItemDefinition.ps1 -WorkspaceId "12345678-1234-1234-1234-123456789012" `
        -ItemId "87654321-4321-4321-4321-210987654321" `
        -LocalPath "C:\Repos\MyProject\MyReport.Report" `
        -Verbose

.EXAMPLE
    .\Compare-FabricItemDefinition.ps1 -WorkspaceId "12345678-1234-1234-1234-123456789012" `
        -ItemId "87654321-4321-4321-4321-210987654321" `
        -LocalPath "C:\Repos\MyProject\MyNotebook.Notebook" `
        -LocalAsNew

.EXAMPLE
    .\Compare-FabricItemDefinition.ps1 -WorkspaceId "12345678-1234-1234-1234-123456789012" `
        -ItemId "87654321-4321-4321-4321-210987654321" `
        -LocalPath "C:\Repos\MyProject\MyNotebook.Notebook\notebook-content.py"
    
    This example shows that you can provide a file path, and the script will automatically use the parent folder.

.NOTES
    Author: Fabric Archive Bot
    Requires: PowerShell 7+
    Requires: Az.Accounts module for authentication
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$WorkspaceId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ItemId,

    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$LocalPath,

    [Parameter(Mandatory = $false)]
    [switch]$ForceReauth,

    [Parameter(Mandatory = $false)]
    [switch]$LocalAsNew
)

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

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
                $statusContent = $statusResponse.Content | ConvertFrom-Json
                
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
                    throw "Operation failed: $($statusContent.error | ConvertTo-Json)"
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
        
        # Parse and return the response content
        $result = $response.Content | ConvertFrom-Json
        
        Write-Verbose "Response structure: $($result | ConvertTo-Json -Depth 2)"
        
        if ($result.definition -and $result.definition.parts) {
            Write-Verbose "Found $($result.definition.parts.Count) parts in definition"
        }
        else {
            Write-Warning "Response does not contain expected definition.parts structure"
            Write-Verbose "Response content: $($response.Content)"
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
    
    # Get all files recursively
    $files = Get-ChildItem -Path $LocalPath -File -Recurse
    
    foreach ($file in $files) {
        # Calculate relative path from the root
        $relativePath = $file.FullName.Substring($LocalPath.Length).TrimStart('\', '/')
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
        [hashtable]$CloudFiles,
        [hashtable]$LocalFiles,
        [switch]$LocalAsNew
    )
    
    # Determine diff direction based on parameter
    if ($LocalAsNew) {
        $oldLabel = "CLOUD"
        $newLabel = "LOCAL"
    }
    else {
        $oldLabel = "LOCAL"
        $newLabel = "CLOUD"
    }
    
    $allPaths = ($CloudFiles.Keys + $LocalFiles.Keys) | Select-Object -Unique | Sort-Object
    $hasDifferences = $false
    
    foreach ($path in $allPaths) {
        $cloudContent = $CloudFiles[$path]
        $localContent = $LocalFiles[$path]
        
        if (-not $cloudContent) {
            Write-Host "`n=== File only in LOCAL: $path ===" -ForegroundColor Magenta
            $hasDifferences = $true
            continue
        }
        
        if (-not $localContent) {
            Write-Host "`n=== File only in CLOUD: $path ===" -ForegroundColor Magenta
            $hasDifferences = $true
            continue
        }
        
        # Compare content
        if ($cloudContent -ne $localContent) {
            Write-Host "`n=== Differences in: $path ===" -ForegroundColor Yellow
            Write-Host "    Comparing: $oldLabel (old) vs $newLabel (new)" -ForegroundColor Gray
            $hasDifferences = $true
            
            # Normalize line endings for comparison
            $cloudNormalized = $cloudContent -replace "`r`n", "`n" -replace "`r", "`n"
            $localNormalized = $localContent -replace "`r`n", "`n" -replace "`r", "`n"
            
            # Check if the only difference is line endings
            if ($cloudNormalized -eq $localNormalized) {
                Write-Host "Files differ only in line endings (CRLF vs LF)" -ForegroundColor Cyan
                Write-Verbose "Cloud uses LF, Local uses CRLF (or vice versa)"
                continue
            }
            
            # Determine which content to use as old vs new
            if ($LocalAsNew) {
                $oldContent = $cloudNormalized
                $newContent = $localNormalized
            }
            else {
                $oldContent = $localNormalized
                $newContent = $cloudNormalized
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
        Write-Host "`n✓ No differences found between cloud and local versions!" -ForegroundColor Green
    }
    else {
        Write-Host "`n⚠ Differences detected between cloud and local versions" -ForegroundColor Yellow
    }
}

# Main execution
try {
    Write-Host "Starting Fabric item comparison..." -ForegroundColor Cyan
    Write-Host "Workspace ID: $WorkspaceId" -ForegroundColor Gray
    Write-Host "Item ID: $ItemId" -ForegroundColor Gray
    
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
    
    # Get item definition from Fabric
    $cloudDefinition = Get-FABItemDefinition -WorkspaceId $WorkspaceId -ItemId $ItemId -AccessToken $accessToken
    
    # Extract and decode cloud files
    $cloudFiles = ConvertFrom-FABDefinitionParts -Definition $cloudDefinition
    Write-Host "Retrieved $($cloudFiles.Count) file(s) from cloud" -ForegroundColor Green
    
    # Get local files
    $localFiles = Get-FABLocalDefinitionFiles -LocalPath $LocalPath
    Write-Host "Retrieved $($localFiles.Count) file(s) from local repository" -ForegroundColor Green
    
    # Display diff direction
    if ($LocalAsNew) {
        Write-Host "`nDiff direction: CLOUD (old) -> LOCAL (new)" -ForegroundColor Cyan
        Write-Host "Green (+) lines are in LOCAL, Red (-) lines are in CLOUD" -ForegroundColor Gray
    }
    else {
        Write-Host "`nDiff direction: LOCAL (old) -> CLOUD (new)" -ForegroundColor Cyan
        Write-Host "Green (+) lines are in CLOUD, Red (-) lines are in LOCAL" -ForegroundColor Gray
    }
    
    # Compare and display differences
    Show-FABFileDiff -CloudFiles $cloudFiles -LocalFiles $localFiles -LocalAsNew:$LocalAsNew
    
    Write-Host "`nComparison complete!" -ForegroundColor Cyan
}
catch {
    Write-Error "Error: $_"
    exit 1
}