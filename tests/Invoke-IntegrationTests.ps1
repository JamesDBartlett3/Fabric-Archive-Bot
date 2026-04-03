<#
.SYNOPSIS
  Integration test harness for Fabric Archive Bot v2.
  Exercises every function against a live Microsoft Fabric tenant.

.DESCRIPTION
  Run this script from a machine with access to a Fabric tenant.
  It progressively tests authentication, workspace/item retrieval,
  filtering, export, and logging — reporting PASS/FAIL for each test.

  Safe by default: only reads from the tenant and exports item
  definitions to a local temp folder. Never modifies tenant data.

.PARAMETER ConfigPath
  Path to configuration file. Defaults to FabricArchiveBot_Config.json in the repo root.

.PARAMETER ConfigFromEnv
  Load configuration from the FabricArchiveBot_ConfigObject environment variable.

.PARAMETER KeepArtifacts
  Do not delete the temp export folder after tests complete.

.PARAMETER SkipExportTests
  Skip Phase 7 (actual item export to disk). Useful for quick validation runs.

.PARAMETER TargetWorkspaceName
  Test against a specific workspace by name. If not specified, uses the first workspace returned.

.EXAMPLE
  .\tests\Invoke-IntegrationTests.ps1

.EXAMPLE
  .\tests\Invoke-IntegrationTests.ps1 -ConfigPath .\Config-Production.json -TargetWorkspaceName "Finance Prod"

.EXAMPLE
  .\tests\Invoke-IntegrationTests.ps1 -SkipExportTests -KeepArtifacts
#>
[CmdletBinding()]
param(
  [Parameter()]
  [string]$ConfigPath,

  [Parameter()]
  [switch]$ConfigFromEnv,

  [Parameter()]
  [switch]$KeepArtifacts,

  [Parameter()]
  [switch]$SkipExportTests,

  [Parameter()]
  [string]$TargetWorkspaceName
)

#requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

#region Helpers

[System.Collections.ArrayList]$Script:TestResults = @()
[hashtable]$Script:TestContext = @{}
[string[]]$Script:PhaseNames = @(
  'Configuration'
  'Item Type Detection'
  'Authentication & Connection'
  'Workspace Retrieval'
  'Workspace Filtering'
  'Item Retrieval & Filtering'
  'Export Operations'
  'Logging Subsystem'
)

function Add-TestResult {
  param(
    [string]$TestName,
    [string]$Phase,
    [string]$Status,
    [timespan]$Duration = [timespan]::Zero,
    [string]$Message = '',
    [string]$ErrorDetails = ''
  )

  $result = [PSCustomObject]@{
    TestName     = $TestName
    Phase        = $Phase
    Status       = $Status
    Duration     = $Duration
    Message      = $Message
    ErrorDetails = $ErrorDetails
  }

  $Script:TestResults.Add($result) | Out-Null
  Write-TestResult $result
}

function Assert-Condition {
  param(
    [string]$TestName,
    [string]$Phase,
    [bool]$Condition,
    [string]$FailMessage = 'Assertion failed'
  )

  if ($Condition) {
    Add-TestResult -TestName $TestName -Phase $Phase -Status 'PASS'
  }
  else {
    Add-TestResult -TestName $TestName -Phase $Phase -Status 'FAIL' -Message $FailMessage
  }
  return $Condition
}

function Assert-NotNull {
  param(
    [string]$TestName,
    [string]$Phase,
    $Value,
    [string]$Description = 'Value'
  )
  return Assert-Condition -TestName $TestName -Phase $Phase -Condition ($null -ne $Value) -FailMessage "$Description was null"
}

function Assert-CountGreaterThan {
  param(
    [string]$TestName,
    [string]$Phase,
    $Collection,
    [int]$Minimum = 0,
    [string]$Description = 'Collection'
  )

  [int]$count = if ($null -eq $Collection) { 0 } else { @($Collection).Count }
  return Assert-Condition -TestName $TestName -Phase $Phase -Condition ($count -gt $Minimum) -FailMessage "$Description had $count items, expected more than $Minimum"
}

function Skip-Test {
  param(
    [string]$TestName,
    [string]$Phase,
    [string]$Reason
  )
  Add-TestResult -TestName $TestName -Phase $Phase -Status 'SKIP' -Message $Reason
}

function Invoke-TestBlock {
  param(
    [string]$TestName,
    [string]$Phase,
    [scriptblock]$ScriptBlock
  )

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    & $ScriptBlock
    return $true
  }
  catch {
    $sw.Stop()
    Add-TestResult -TestName $TestName -Phase $Phase -Status 'FAIL' -Duration $sw.Elapsed -Message $_.Exception.Message -ErrorDetails $_.ScriptStackTrace
    return $false
  }
}

function Write-TestResult {
  param([PSCustomObject]$Result)

  $icon = switch ($Result.Status) {
    'PASS' { '[PASS]' }
    'FAIL' { '[FAIL]' }
    'SKIP' { '[SKIP]' }
  }
  $color = switch ($Result.Status) {
    'PASS' { 'Green' }
    'FAIL' { 'Red' }
    'SKIP' { 'Yellow' }
  }

  $duration = if ($Result.Duration.TotalSeconds -gt 0) { " ($($Result.Duration.TotalSeconds.ToString('F2'))s)" } else { '' }
  $detail = if ($Result.Message -and $Result.Status -ne 'PASS') { " -- $($Result.Message)" } else { '' }

  Write-Host "    $icon $($Result.TestName)$duration$detail" -ForegroundColor $color
}

function Write-TestSummary {
  Write-Host ''
  Write-Host ('=' * 80)
  Write-Host '  INTEGRATION TEST SUMMARY'
  Write-Host ('=' * 80)

  # Group by phase and display
  $grouped = $Script:TestResults | Group-Object -Property Phase
  foreach ($group in $grouped) {
    Write-Host ''
    Write-Host "  $($group.Name)" -ForegroundColor Cyan
    foreach ($result in $group.Group) {
      Write-TestResult $result
    }
  }

  # Totals
  [int]$passed = ($Script:TestResults | Where-Object { $_.Status -eq 'PASS' }).Count
  [int]$failed = ($Script:TestResults | Where-Object { $_.Status -eq 'FAIL' }).Count
  [int]$skipped = ($Script:TestResults | Where-Object { $_.Status -eq 'SKIP' }).Count
  [int]$total = $Script:TestResults.Count

  Write-Host ''
  Write-Host ('=' * 80)

  $summaryColor = if ($failed -eq 0) { 'Green' } else { 'Red' }
  Write-Host "  TOTALS:  $passed Passed  |  $failed Failed  |  $skipped Skipped  |  $total Total" -ForegroundColor $summaryColor
  Write-Host ('=' * 80)

  # Print failed test details
  $failures = $Script:TestResults | Where-Object { $_.Status -eq 'FAIL' }
  if ($failures) {
    Write-Host ''
    Write-Host '  FAILED TEST DETAILS:' -ForegroundColor Red
    Write-Host ('  ' + ('-' * 76))
    foreach ($f in $failures) {
      Write-Host "  $($f.Phase) > $($f.TestName)" -ForegroundColor Red
      Write-Host "    Error: $($f.Message)" -ForegroundColor Red
      if ($f.ErrorDetails) {
        Write-Host "    Stack: $($f.ErrorDetails)" -ForegroundColor DarkRed
      }
      Write-Host ''
    }
  }
}

function Skip-Phase {
  param(
    [string]$Phase,
    [string]$Reason,
    [string[]]$TestNames
  )

  foreach ($name in $TestNames) {
    Skip-Test -TestName $name -Phase $Phase -Reason $Reason
  }
}

#endregion Helpers

#region Phase Functions

function Invoke-Phase1ConfigTests {
  [string]$phase = 'Phase 1: Configuration'
  Write-Host ''
  Write-Host "  $phase" -ForegroundColor Cyan

  # 1.1 Load config from file
  $config = $null
  $loaded = Invoke-TestBlock -TestName 'Config-LoadFromFile' -Phase $phase -ScriptBlock {
    if ($Script:ConfigFromEnv) {
      $Script:TestContext.Config = Get-FABConfiguration -ConfigFromEnv
    }
    else {
      $Script:TestContext.Config = Get-FABConfiguration -ConfigPath $Script:ResolvedConfigPath
    }
    Assert-NotNull -TestName 'Config-LoadFromFile' -Phase $phase -Value $Script:TestContext.Config -Description 'Configuration object' | Out-Null
  }

  if (-not $Script:TestContext.Config) {
    Skip-Phase -Phase $phase -Reason 'Config loading failed' -TestNames @('Config-HasExportSettings', 'Config-HasServicePrincipalSection', 'Config-CompatibilityValidation')
    return $false
  }

  $config = $Script:TestContext.Config

  # 1.2 Has ExportSettings
  Invoke-TestBlock -TestName 'Config-HasExportSettings' -Phase $phase -ScriptBlock {
    $has = ($config.PSObject.Properties['ExportSettings'] -and
      $config.ExportSettings.PSObject.Properties['TargetFolder'] -and
      $config.ExportSettings.PSObject.Properties['WorkspaceFilter'] -and
      $config.ExportSettings.PSObject.Properties['ItemTypes'])
    Assert-Condition -TestName 'Config-HasExportSettings' -Phase $phase -Condition $has -FailMessage 'Missing ExportSettings, TargetFolder, WorkspaceFilter, or ItemTypes' | Out-Null
  } | Out-Null

  # 1.3 Has ServicePrincipal section
  Invoke-TestBlock -TestName 'Config-HasServicePrincipalSection' -Phase $phase -ScriptBlock {
    $has = $null -ne $config.PSObject.Properties['ServicePrincipal']
    Assert-Condition -TestName 'Config-HasServicePrincipalSection' -Phase $phase -Condition $has -FailMessage 'Missing ServicePrincipal section' | Out-Null
  } | Out-Null

  # 1.4 Compatibility validation
  Invoke-TestBlock -TestName 'Config-CompatibilityValidation' -Phase $phase -ScriptBlock {
    $validated = Confirm-FABConfigurationCompatibility -Config $config
    $Script:TestContext.Config = $validated
    $has = ($validated.ExportSettings.ItemTypes -and @($validated.ExportSettings.ItemTypes).Count -gt 0)
    Assert-Condition -TestName 'Config-CompatibilityValidation' -Phase $phase -Condition $has -FailMessage 'ItemTypes empty after compatibility check' | Out-Null
  } | Out-Null

  return $true
}

function Invoke-Phase2ItemTypeTests {
  [string]$phase = 'Phase 2: Item Type Detection'
  Write-Host ''
  Write-Host "  $phase" -ForegroundColor Cyan

  # 2.1 Dynamic fetch
  Invoke-TestBlock -TestName 'ItemTypes-DynamicFetch' -Phase $phase -ScriptBlock {
    $types = Get-FABSupportedItemTypes
    $Script:TestContext.SupportedItemTypes = $types
    Assert-CountGreaterThan -TestName 'ItemTypes-DynamicFetch' -Phase $phase -Collection $types -Minimum 0 -Description 'Supported item types' | Out-Null
  } | Out-Null

  # 2.2 Contains known types
  Invoke-TestBlock -TestName 'ItemTypes-ContainsKnownTypes' -Phase $phase -ScriptBlock {
    $types = $Script:TestContext.SupportedItemTypes
    $hasReport = 'Report' -in $types
    $hasModel = 'SemanticModel' -in $types
    Assert-Condition -TestName 'ItemTypes-ContainsKnownTypes' -Phase $phase -Condition ($hasReport -and $hasModel) -FailMessage "Missing Report ($hasReport) or SemanticModel ($hasModel) in: $($types -join ', ')" | Out-Null
  } | Out-Null

  # 2.3 Fallback list
  Invoke-TestBlock -TestName 'ItemTypes-FallbackList' -Phase $phase -ScriptBlock {
    $fallback = Get-FABFallbackItemTypes
    $hasReport = 'Report' -in $fallback
    Assert-Condition -TestName 'ItemTypes-FallbackList' -Phase $phase -Condition ($fallback.Count -gt 0 -and $hasReport) -FailMessage "Fallback list empty or missing Report" | Out-Null
  } | Out-Null

  # 2.4 Config types are subset of supported
  Invoke-TestBlock -TestName 'ItemTypes-ConfigTypesAreSubset' -Phase $phase -ScriptBlock {
    $configTypes = @($Script:TestContext.Config.ExportSettings.ItemTypes)
    $supported = @($Script:TestContext.SupportedItemTypes)
    $unsupported = $configTypes | Where-Object { $_ -notin $supported }
    Assert-Condition -TestName 'ItemTypes-ConfigTypesAreSubset' -Phase $phase -Condition ($unsupported.Count -eq 0) -FailMessage "Unsupported types in config: $($unsupported -join ', ')" | Out-Null
  } | Out-Null
}

function Invoke-Phase3AuthTests {
  [string]$phase = 'Phase 3: Authentication & Connection'
  Write-Host ''
  Write-Host "  $phase" -ForegroundColor Cyan

  # 3.1 FabricPS-PBIP available
  Invoke-TestBlock -TestName 'Auth-FabricPSPBIPAvailable' -Phase $phase -ScriptBlock {
    $available = Test-FABFabricPSPBIPAvailability
    Assert-Condition -TestName 'Auth-FabricPSPBIPAvailable' -Phase $phase -Condition $available -FailMessage 'FabricPS-PBIP module not available' | Out-Null
  } | Out-Null

  # 3.2 Initialize connection (critical gate)
  [bool]$authSuccess = $false
  Invoke-TestBlock -TestName 'Auth-InitializeConnection' -Phase $phase -ScriptBlock {
    $result = Initialize-FABFabricConnection -Config $Script:TestContext.Config
    $Script:AuthSuccess = $result
    Assert-Condition -TestName 'Auth-InitializeConnection' -Phase $phase -Condition $result -FailMessage 'Initialize-FABFabricConnection returned false' | Out-Null
  } | Out-Null

  $authSuccess = $Script:AuthSuccess -eq $true

  # 3.3 Set-FabricAuthToken exists
  if ($authSuccess) {
    Invoke-TestBlock -TestName 'Auth-SetFabricAuthTokenExists' -Phase $phase -ScriptBlock {
      $cmd = Get-Command Set-FabricAuthToken -ErrorAction SilentlyContinue
      Assert-NotNull -TestName 'Auth-SetFabricAuthTokenExists' -Phase $phase -Value $cmd -Description 'Set-FabricAuthToken command' | Out-Null
    } | Out-Null
  }
  else {
    Skip-Test -TestName 'Auth-SetFabricAuthTokenExists' -Phase $phase -Reason 'Auth failed'
  }

  return $authSuccess
}

function Invoke-Phase4WorkspaceTests {
  [string]$phase = 'Phase 4: Workspace Retrieval'
  Write-Host ''
  Write-Host "  $phase" -ForegroundColor Cyan

  # 4.1 Get all workspaces
  Invoke-TestBlock -TestName 'Workspaces-GetAll' -Phase $phase -ScriptBlock {
    $workspaces = Get-FABFabricWorkspaces
    $Script:TestContext.Workspaces = $workspaces
    Assert-CountGreaterThan -TestName 'Workspaces-GetAll' -Phase $phase -Collection $workspaces -Minimum 0 -Description 'Workspaces' | Out-Null
  } | Out-Null

  if (-not $Script:TestContext.Workspaces -or @($Script:TestContext.Workspaces).Count -eq 0) {
    Skip-Phase -Phase $phase -Reason 'No workspaces found in tenant' -TestNames @('Workspaces-HaveRequiredProperties', 'Workspaces-GetById', 'Workspaces-ByIdHasCapacityInfo')
    return $false
  }

  # Select target workspace
  if ($TargetWorkspaceName) {
    $targetWs = $Script:TestContext.Workspaces | Where-Object { $_.displayName -eq $TargetWorkspaceName } | Select-Object -First 1
    if (-not $targetWs) {
      Write-Host "    WARNING: Workspace '$TargetWorkspaceName' not found. Using first workspace." -ForegroundColor Yellow
      $targetWs = @($Script:TestContext.Workspaces)[0]
    }
  }
  else {
    $targetWs = @($Script:TestContext.Workspaces)[0]
  }

  Write-Host "    Using workspace: '$($targetWs.displayName)' ($($targetWs.id))" -ForegroundColor Gray

  # 4.2 Required properties
  Invoke-TestBlock -TestName 'Workspaces-HaveRequiredProperties' -Phase $phase -ScriptBlock {
    $ws = $targetWs
    $hasId = $null -ne $ws.PSObject.Properties['id']
    $hasName = $null -ne $ws.PSObject.Properties['displayName']
    $hasType = $null -ne $ws.PSObject.Properties['type']
    Assert-Condition -TestName 'Workspaces-HaveRequiredProperties' -Phase $phase -Condition ($hasId -and $hasName -and $hasType) -FailMessage "Missing properties: id=$hasId, displayName=$hasName, type=$hasType" | Out-Null
  } | Out-Null

  # 4.3 Get by ID
  $Script:TestContext.SelectedWorkspaceId = $targetWs.id
  $Script:TestContext.SelectedWorkspaceName = $targetWs.displayName

  Invoke-TestBlock -TestName 'Workspaces-GetById' -Phase $phase -ScriptBlock {
    $ws = Get-FABFabricWorkspaceById -WorkspaceId $Script:TestContext.SelectedWorkspaceId
    Assert-Condition -TestName 'Workspaces-GetById' -Phase $phase -Condition ($ws -and $ws.id -eq $Script:TestContext.SelectedWorkspaceId) -FailMessage "GetById returned null or wrong id" | Out-Null
    $Script:TestContext.DetailedWorkspace = $ws
  } | Out-Null

  # 4.4 Capacity info on detailed response
  Invoke-TestBlock -TestName 'Workspaces-ByIdHasCapacityInfo' -Phase $phase -ScriptBlock {
    $ws = $Script:TestContext.DetailedWorkspace
    if (-not $ws) { throw 'No detailed workspace available' }
    $hasProp = $null -ne $ws.PSObject.Properties['capacityId']
    Assert-Condition -TestName 'Workspaces-ByIdHasCapacityInfo' -Phase $phase -Condition $hasProp -FailMessage "Detailed workspace missing capacityId property" | Out-Null
  } | Out-Null

  return $true
}

function Invoke-Phase5WorkspaceFilterTests {
  [string]$phase = 'Phase 5: Workspace Filtering'
  Write-Host ''
  Write-Host "  $phase" -ForegroundColor Cyan

  $workspaces = $Script:TestContext.Workspaces

  # 5.1 Active state
  Invoke-TestBlock -TestName 'WsFilter-ActiveState' -Phase $phase -ScriptBlock {
    $result = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter "(state eq 'Active')"
    Assert-Condition -TestName 'WsFilter-ActiveState' -Phase $phase -Condition (@($result).Count -eq @($workspaces).Count) -FailMessage "Active filter returned $(@($result).Count), expected $(@($workspaces).Count)" | Out-Null
  } | Out-Null

  # 5.2 Type eq Workspace
  Invoke-TestBlock -TestName 'WsFilter-TypeWorkspace' -Phase $phase -ScriptBlock {
    $result = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter "(type eq 'Workspace')"
    $allMatch = @($result) | Where-Object { $_.type -ne 'Workspace' }
    Assert-Condition -TestName 'WsFilter-TypeWorkspace' -Phase $phase -Condition ($allMatch.Count -eq 0) -FailMessage "Filter returned items with wrong type" | Out-Null
  } | Out-Null

  # 5.3 Name contains (use real workspace name)
  Invoke-TestBlock -TestName 'WsFilter-NameContains' -Phase $phase -ScriptBlock {
    $name = $Script:TestContext.SelectedWorkspaceName
    # Use first 4 chars as substring (or full name if short)
    $substring = if ($name.Length -gt 4) { $name.Substring(0, 4) } else { $name }
    $result = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter "contains(name,'$substring')"
    $found = @($result) | Where-Object { $_.displayName -like "*$substring*" }
    Assert-Condition -TestName 'WsFilter-NameContains' -Phase $phase -Condition ($found.Count -gt 0) -FailMessage "Name filter for '$substring' returned 0 matching results" | Out-Null
  } | Out-Null

  # 5.4 Combined filter
  Invoke-TestBlock -TestName 'WsFilter-CombinedFilter' -Phase $phase -ScriptBlock {
    $result = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter "(type eq 'Workspace') and (state eq 'Active')"
    Assert-Condition -TestName 'WsFilter-CombinedFilter' -Phase $phase -Condition ($null -ne $result) -FailMessage "Combined filter returned null" | Out-Null
  } | Out-Null

  # 5.5 Impossible name returns empty
  Invoke-TestBlock -TestName 'WsFilter-NoMatchReturnsEmpty' -Phase $phase -ScriptBlock {
    $result = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter "contains(name,'ZZZZZ_NO_MATCH_99999')"
    Assert-Condition -TestName 'WsFilter-NoMatchReturnsEmpty' -Phase $phase -Condition (@($result).Count -eq 0) -FailMessage "Impossible name filter returned $(@($result).Count) results" | Out-Null
  } | Out-Null

  # 5.6 Inactive returns empty
  Invoke-TestBlock -TestName 'WsFilter-InactiveReturnsEmpty' -Phase $phase -ScriptBlock {
    $result = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter "(state eq 'Inactive')"
    Assert-Condition -TestName 'WsFilter-InactiveReturnsEmpty' -Phase $phase -Condition (@($result).Count -eq 0) -FailMessage "Inactive filter returned $(@($result).Count) results" | Out-Null
  } | Out-Null
}

function Invoke-Phase6ItemTests {
  [string]$phase = 'Phase 6: Item Retrieval & Filtering'
  Write-Host ''
  Write-Host "  $phase" -ForegroundColor Cyan

  $wsId = $Script:TestContext.SelectedWorkspaceId

  # 6.1 Get items
  Invoke-TestBlock -TestName 'Items-GetByWorkspace' -Phase $phase -ScriptBlock {
    $items = Get-FABFabricItemsByWorkspace -WorkspaceId $wsId
    $Script:TestContext.WorkspaceItems = $items
    # Empty workspace is valid — this test just checks it doesn't throw
    Add-TestResult -TestName 'Items-GetByWorkspace' -Phase $phase -Status 'PASS' -Message "$(@($items).Count) items found"
  } | Out-Null

  $items = $Script:TestContext.WorkspaceItems
  [int]$itemCount = if ($null -eq $items) { 0 } else { @($items).Count }

  if ($itemCount -eq 0) {
    Skip-Phase -Phase $phase -Reason 'Selected workspace has no items' -TestNames @('Items-HaveRequiredProperties', 'ItemFilter-TypeEq', 'ItemFilter-TypeIn', 'ItemFilter-NameContains', 'ItemFilter-NoMatchReturnsEmpty')
    return $false
  }

  # 6.2 Required properties
  Invoke-TestBlock -TestName 'Items-HaveRequiredProperties' -Phase $phase -ScriptBlock {
    $item = @($items)[0]
    $hasId = $null -ne $item.PSObject.Properties['id']
    $hasName = $null -ne $item.PSObject.Properties['displayName']
    $hasType = $null -ne $item.PSObject.Properties['type']
    Assert-Condition -TestName 'Items-HaveRequiredProperties' -Phase $phase -Condition ($hasId -and $hasName -and $hasType) -FailMessage "Missing: id=$hasId, displayName=$hasName, type=$hasType" | Out-Null
  } | Out-Null

  # 6.3 Type eq filter
  Invoke-TestBlock -TestName 'ItemFilter-TypeEq' -Phase $phase -ScriptBlock {
    $targetType = @($items)[0].type
    $result = Invoke-FABItemFilter -Items $items -Filter "type eq '$targetType'"
    $allCorrect = @($result) | Where-Object { $_.type -ne $targetType }
    Assert-Condition -TestName 'ItemFilter-TypeEq' -Phase $phase -Condition (@($result).Count -gt 0 -and $allCorrect.Count -eq 0) -FailMessage "Type filter for '$targetType' returned wrong results" | Out-Null
  } | Out-Null

  # 6.4 Type in filter
  $distinctTypes = @($items | Select-Object -ExpandProperty type -Unique)
  if ($distinctTypes.Count -ge 2) {
    Invoke-TestBlock -TestName 'ItemFilter-TypeIn' -Phase $phase -ScriptBlock {
      $t1 = $distinctTypes[0]
      $t2 = $distinctTypes[1]
      $result = Invoke-FABItemFilter -Items $items -Filter "type in ('$t1', '$t2')"
      $allCorrect = @($result) | Where-Object { $_.type -notin @($t1, $t2) }
      Assert-Condition -TestName 'ItemFilter-TypeIn' -Phase $phase -Condition (@($result).Count -gt 0 -and $allCorrect.Count -eq 0) -FailMessage "Type in filter returned wrong types" | Out-Null
    } | Out-Null
  }
  else {
    Skip-Test -TestName 'ItemFilter-TypeIn' -Phase $phase -Reason "Only 1 distinct item type in workspace"
  }

  # 6.5 Name contains
  Invoke-TestBlock -TestName 'ItemFilter-NameContains' -Phase $phase -ScriptBlock {
    $name = @($items)[0].displayName
    $substring = if ($name.Length -gt 3) { $name.Substring(0, 3) } else { $name }
    $result = Invoke-FABItemFilter -Items $items -Filter "contains(displayName,'$substring')"
    Assert-Condition -TestName 'ItemFilter-NameContains' -Phase $phase -Condition (@($result).Count -gt 0) -FailMessage "Name filter for '$substring' returned 0 results" | Out-Null
  } | Out-Null

  # 6.6 No match returns empty
  Invoke-TestBlock -TestName 'ItemFilter-NoMatchReturnsEmpty' -Phase $phase -ScriptBlock {
    $result = Invoke-FABItemFilter -Items $items -Filter "contains(displayName,'ZZZZZ_NO_MATCH_99999')"
    Assert-Condition -TestName 'ItemFilter-NoMatchReturnsEmpty' -Phase $phase -Condition (@($result).Count -eq 0) -FailMessage "Impossible name filter returned $(@($result).Count) results" | Out-Null
  } | Out-Null

  return $true
}

function Invoke-Phase7ExportTests {
  [string]$phase = 'Phase 7: Export Operations'
  Write-Host ''
  Write-Host "  $phase" -ForegroundColor Cyan

  $config = $Script:TestContext.Config
  $wsId = $Script:TestContext.SelectedWorkspaceId
  $items = $Script:TestContext.WorkspaceItems
  $tempFolder = $Script:TestContext.ExportTempFolder

  # Build a config that exports to our temp folder
  $testConfig = $config.PSObject.Copy()
  $testConfig.ExportSettings.TargetFolder = $tempFolder

  # 7.1 Serial export
  [string]$serialFolder = Join-Path $tempFolder 'serial'
  New-Item -Path $serialFolder -ItemType Directory -Force | Out-Null

  Invoke-TestBlock -TestName 'Export-SingleItemSerial' -Phase $phase -ScriptBlock {
    Export-FABFabricItemsAdvanced -Config $testConfig -WorkspaceIds @($wsId) -TargetFolder $serialFolder -SerialProcessing
    $wsFolder = Join-Path $serialFolder $Script:TestContext.SelectedWorkspaceName
    $hasContent = (Test-Path $wsFolder) -and ((Get-ChildItem $wsFolder -Recurse -File -ErrorAction SilentlyContinue).Count -gt 0)
    Assert-Condition -TestName 'Export-SingleItemSerial' -Phase $phase -Condition $hasContent -FailMessage "No files exported to $wsFolder" | Out-Null
  } | Out-Null

  # 7.2 Folder structure
  Invoke-TestBlock -TestName 'Export-FolderStructure' -Phase $phase -ScriptBlock {
    $wsFolder = Join-Path $serialFolder $Script:TestContext.SelectedWorkspaceName
    $subfolders = Get-ChildItem $wsFolder -Directory -ErrorAction SilentlyContinue
    Assert-Condition -TestName 'Export-FolderStructure' -Phase $phase -Condition ($subfolders.Count -gt 0) -FailMessage "No item subfolders in workspace folder" | Out-Null
  } | Out-Null

  # 7.3 Metadata generated
  Invoke-TestBlock -TestName 'Export-MetadataGenerated' -Phase $phase -ScriptBlock {
    $metadataPath = Join-Path $serialFolder 'fabric-archive-metadata.json'
    $exists = Test-Path $metadataPath
    if ($exists) {
      $json = Get-Content $metadataPath -Raw | ConvertFrom-Json
      $valid = ($null -ne $json.PSObject.Properties['ExportTimestamp']) -and ($null -ne $json.PSObject.Properties['Workspaces'])
      Assert-Condition -TestName 'Export-MetadataGenerated' -Phase $phase -Condition $valid -FailMessage "Metadata JSON missing ExportTimestamp or Workspaces" | Out-Null
    }
    else {
      Assert-Condition -TestName 'Export-MetadataGenerated' -Phase $phase -Condition $false -FailMessage "fabric-archive-metadata.json not found" | Out-Null
    }
  } | Out-Null

  # 7.4 Parallel export (only if 2+ items)
  [int]$itemCount = if ($null -eq $items) { 0 } else { @($items).Count }
  if ($itemCount -ge 2) {
    [string]$parallelFolder = Join-Path $tempFolder 'parallel'
    New-Item -Path $parallelFolder -ItemType Directory -Force | Out-Null

    Invoke-TestBlock -TestName 'Export-ParallelMode' -Phase $phase -ScriptBlock {
      Export-FABFabricItemsAdvanced -Config $testConfig -WorkspaceIds @($wsId) -TargetFolder $parallelFolder
      $wsFolder = Join-Path $parallelFolder $Script:TestContext.SelectedWorkspaceName
      $hasContent = (Test-Path $wsFolder) -and ((Get-ChildItem $wsFolder -Recurse -File -ErrorAction SilentlyContinue).Count -gt 0)
      Assert-Condition -TestName 'Export-ParallelMode' -Phase $phase -Condition $hasContent -FailMessage "Parallel export produced no files" | Out-Null
    } | Out-Null
  }
  else {
    Skip-Test -TestName 'Export-ParallelMode' -Phase $phase -Reason "Need 2+ items for parallel test, found $itemCount"
  }

  # 7.5 Throttle limit
  Invoke-TestBlock -TestName 'Export-ThrottleLimit' -Phase $phase -ScriptBlock {
    $limit = Get-FABOptimalThrottleLimit -Config $config
    Assert-Condition -TestName 'Export-ThrottleLimit' -Phase $phase -Condition ($limit -gt 0) -FailMessage "ThrottleLimit was $limit" | Out-Null
  } | Out-Null
}

function Invoke-Phase8LoggingTests {
  [string]$phase = 'Phase 8: Logging Subsystem'
  Write-Host ''
  Write-Host "  $phase" -ForegroundColor Cyan

  # 8.1 Initialize
  Invoke-TestBlock -TestName 'Logging-Initialize' -Phase $phase -ScriptBlock {
    Initialize-FABLogging -Config $Script:TestContext.Config
    Add-TestResult -TestName 'Logging-Initialize' -Phase $phase -Status 'PASS'
  } | Out-Null

  # 8.2 Write log
  Invoke-TestBlock -TestName 'Logging-WriteLog' -Phase $phase -ScriptBlock {
    Write-FABLog -Level Info -Message 'Integration test log message' -NoConsole
    Add-TestResult -TestName 'Logging-WriteLog' -Phase $phase -Status 'PASS'
  } | Out-Null

  # 8.3 Start/Complete operation
  Invoke-TestBlock -TestName 'Logging-StartCompleteOperation' -Phase $phase -ScriptBlock {
    $op = Start-FABOperation -OperationName 'IntegrationTestOp'
    $running = $op.Status -eq 'Running'
    Complete-FABOperation -Operation $op -Success
    $completed = $op.Status -eq 'Completed'
    Assert-Condition -TestName 'Logging-StartCompleteOperation' -Phase $phase -Condition ($running -and $completed) -FailMessage "Status flow: Running=$running, Completed=$completed" | Out-Null
  } | Out-Null

  # 8.4 Get summary
  Invoke-TestBlock -TestName 'Logging-GetSummary' -Phase $phase -ScriptBlock {
    $summary = Get-FABLogSummary
    $valid = ($null -ne $summary.SessionId) -and ($null -ne $summary.PSObject.Properties['ErrorCount']) -and ($null -ne $summary.PSObject.Properties['SuccessCount'])
    Assert-Condition -TestName 'Logging-GetSummary' -Phase $phase -Condition $valid -FailMessage "Summary missing SessionId, ErrorCount, or SuccessCount" | Out-Null
  } | Out-Null

  # 8.5 Export summary
  Invoke-TestBlock -TestName 'Logging-ExportSummary' -Phase $phase -ScriptBlock {
    $outputPath = Join-Path $Script:TestContext.ExportTempFolder 'test-summary.json'
    $result = Export-FABLogSummary -OutputPath $outputPath
    $valid = (Test-Path $result) -and ($null -ne (Get-Content $result -Raw | ConvertFrom-Json))
    Assert-Condition -TestName 'Logging-ExportSummary' -Phase $phase -Condition $valid -FailMessage "Export summary failed or produced invalid JSON" | Out-Null
  } | Out-Null

  # 8.6 Rate-limited operation
  Invoke-TestBlock -TestName 'Logging-RateLimitedOperation' -Phase $phase -ScriptBlock {
    $result = Invoke-FABRateLimitedOperation -Operation { 42 } -OperationName 'IntegrationTestRateLimit'
    Assert-Condition -TestName 'Logging-RateLimitedOperation' -Phase $phase -Condition ($result -eq 42) -FailMessage "Expected 42, got $result" | Out-Null
  } | Out-Null
}

#endregion Phase Functions

#region Main

Write-Host ''
Write-Host ('=' * 80)
Write-Host '  Fabric Archive Bot v2.0 - Integration Test Harness'
Write-Host ('=' * 80)
Write-Host "  Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ''

# Resolve paths
[string]$repoRoot = Split-Path $PSScriptRoot -Parent
[string]$Script:ResolvedConfigPath = if ($ConfigPath) {
  $ConfigPath
}
else {
  Join-Path $repoRoot 'FabricArchiveBot_Config.json'
}

# Import core module
[string]$coreModulePath = Join-Path $repoRoot 'modules' 'FabricArchiveBotCore.psm1'
if (-not (Test-Path $coreModulePath)) {
  Write-Host "  ERROR: Core module not found at $coreModulePath" -ForegroundColor Red
  exit 1
}
Write-Host "  Importing core module..." -ForegroundColor Gray
Import-Module $coreModulePath -Force

# Import FabricPS-PBIP
[string]$fabricModulePath = Join-Path $repoRoot 'FabricPS-PBIP.psm1'
if (Test-Path $fabricModulePath) {
  Write-Host "  Importing FabricPS-PBIP..." -ForegroundColor Gray
  Import-Module $fabricModulePath -Force
}
else {
  Write-Host "  WARNING: FabricPS-PBIP.psm1 not found at repo root. Auth tests will attempt to locate it." -ForegroundColor Yellow
}

# Auth mode detection
if (-not $ConfigFromEnv -and (Test-Path $Script:ResolvedConfigPath)) {
  $preloadConfig = Get-Content $Script:ResolvedConfigPath -Raw | ConvertFrom-Json
  $usingSP = ($preloadConfig.ServicePrincipal.AppId -and
    $preloadConfig.ServicePrincipal.AppId -ne 'YOUR_APPLICATION_ID' -and
    $preloadConfig.ServicePrincipal.AppSecret -and
    $preloadConfig.ServicePrincipal.AppSecret -ne 'YOUR_APP_SECRET')
  Write-Host "  Auth mode: $(if ($usingSP) { 'Service Principal' } else { 'Interactive (browser will open)' })" -ForegroundColor Cyan
}

# Create temp folder
[string]$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$Script:TestContext.ExportTempFolder = Join-Path $env:TEMP "FAB_IntegrationTest_$timestamp"
New-Item -Path $Script:TestContext.ExportTempFolder -ItemType Directory -Force | Out-Null
Write-Host "  Temp folder: $($Script:TestContext.ExportTempFolder)" -ForegroundColor Gray

if ($TargetWorkspaceName) {
  Write-Host "  Target workspace: $TargetWorkspaceName" -ForegroundColor Gray
}
if ($SkipExportTests) {
  Write-Host "  Export tests: SKIPPED (by request)" -ForegroundColor Yellow
}

Write-Host ''
Write-Host ('=' * 80)

# Store switches in script scope for access inside scriptblocks
$Script:ConfigFromEnv = $ConfigFromEnv

try {
  # Phase 1: Configuration
  [bool]$configOk = Invoke-Phase1ConfigTests

  # Phase 2: Item Type Detection
  if ($configOk) {
    Invoke-Phase2ItemTypeTests
  }
  else {
    Skip-Phase -Phase 'Phase 2: Item Type Detection' -Reason 'Configuration loading failed' -TestNames @('ItemTypes-DynamicFetch', 'ItemTypes-ContainsKnownTypes', 'ItemTypes-FallbackList', 'ItemTypes-ConfigTypesAreSubset')
  }

  # Phase 3: Authentication
  [bool]$authOk = $false
  if ($configOk) {
    $authOk = Invoke-Phase3AuthTests
  }
  else {
    Skip-Phase -Phase 'Phase 3: Authentication & Connection' -Reason 'Configuration loading failed' -TestNames @('Auth-FabricPSPBIPAvailable', 'Auth-InitializeConnection', 'Auth-SetFabricAuthTokenExists')
  }

  # Phase 4: Workspace Retrieval
  [bool]$workspacesOk = $false
  if ($authOk) {
    $workspacesOk = Invoke-Phase4WorkspaceTests
  }
  else {
    Skip-Phase -Phase 'Phase 4: Workspace Retrieval' -Reason 'Authentication failed' -TestNames @('Workspaces-GetAll', 'Workspaces-HaveRequiredProperties', 'Workspaces-GetById', 'Workspaces-ByIdHasCapacityInfo')
  }

  # Phase 5: Workspace Filtering
  if ($workspacesOk) {
    Invoke-Phase5WorkspaceFilterTests
  }
  else {
    Skip-Phase -Phase 'Phase 5: Workspace Filtering' -Reason 'No workspaces available' -TestNames @('WsFilter-ActiveState', 'WsFilter-TypeWorkspace', 'WsFilter-NameContains', 'WsFilter-CombinedFilter', 'WsFilter-NoMatchReturnsEmpty', 'WsFilter-InactiveReturnsEmpty')
  }

  # Phase 6: Item Retrieval & Filtering
  [bool]$itemsOk = $false
  if ($workspacesOk) {
    $itemsOk = Invoke-Phase6ItemTests
  }
  else {
    Skip-Phase -Phase 'Phase 6: Item Retrieval & Filtering' -Reason 'No workspaces available' -TestNames @('Items-GetByWorkspace', 'Items-HaveRequiredProperties', 'ItemFilter-TypeEq', 'ItemFilter-TypeIn', 'ItemFilter-NameContains', 'ItemFilter-NoMatchReturnsEmpty')
  }

  # Phase 7: Export Operations
  if ($SkipExportTests) {
    Skip-Phase -Phase 'Phase 7: Export Operations' -Reason 'Skipped by -SkipExportTests' -TestNames @('Export-SingleItemSerial', 'Export-FolderStructure', 'Export-MetadataGenerated', 'Export-ParallelMode', 'Export-ThrottleLimit')
  }
  elseif ($authOk -and $itemsOk) {
    Invoke-Phase7ExportTests
  }
  else {
    [string]$skipReason = if (-not $authOk) { 'Authentication failed' } else { 'No items available for export' }
    Skip-Phase -Phase 'Phase 7: Export Operations' -Reason $skipReason -TestNames @('Export-SingleItemSerial', 'Export-FolderStructure', 'Export-MetadataGenerated', 'Export-ParallelMode', 'Export-ThrottleLimit')
  }

  # Phase 8: Logging (always runs)
  Invoke-Phase8LoggingTests
}
finally {
  # Cleanup
  if (-not $KeepArtifacts -and (Test-Path $Script:TestContext.ExportTempFolder)) {
    Remove-Item $Script:TestContext.ExportTempFolder -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ''
    Write-Host "  Cleaned up temp folder" -ForegroundColor Gray
  }
  elseif ($KeepArtifacts) {
    Write-Host ''
    Write-Host "  Test artifacts preserved at: $($Script:TestContext.ExportTempFolder)" -ForegroundColor Yellow
  }
}

# Summary
Write-TestSummary

# Exit code
[int]$failCount = ($Script:TestResults | Where-Object { $_.Status -eq 'FAIL' }).Count
exit $failCount

#endregion Main
