<#
.SYNOPSIS
  Comprehensive test and demo script for Compare-FabricItemDefinition.ps1

.DESCRIPTION
  This script demonstrates all three comparison modes and display name support:
  1. LocalToLocal - Comparing archived versions (no authentication required)
  2. Display Name Support - How to use friendly names vs GUIDs
  3. CloudToLocal - Comparing workspace items with local (requires authentication)
  4. CloudToCloud - Comparing two workspace items (requires authentication)

.NOTES
  Author: Fabric Archive Bot
  Requires: PowerShell 7+
  Cloud tests require Az.Accounts module and Fabric workspace access
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [switch]$SkipLocalTests,
  
  [Parameter(Mandatory = $false)]
  [switch]$RunCloudTests
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot "Compare-FabricItemDefinition.ps1"

function Write-SectionHeader {
  param([string]$Title)
  Write-Host "`n========================================" -ForegroundColor Cyan
  Write-Host $Title -ForegroundColor Cyan
  Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-TestHeader {
  param([string]$Title)
  Write-Host "`n=== $Title ===" -ForegroundColor Yellow
}

# ============================================================================
# PART 1: LocalToLocal Tests (No Authentication Required)
# ============================================================================

if (-not $SkipLocalTests) {
  Write-SectionHeader "PART 1: LocalToLocal Comparison Tests"
  Write-Host "These tests use local filesystem only - no authentication required!`n" -ForegroundColor Gray
  
  # Test 1: Compare same item across different dates
  Write-TestHeader "TEST 1: LocalToLocal - Same Item, Different Dates"
  Write-Host "Comparing 'The_Matrix.Report' from 2025-09-20 vs 2025-09-23`n" -ForegroundColor Gray
  
  $path1 = Join-Path $PSScriptRoot "..\Workspaces\2025\09\20\Black\The_Matrix.Report"
  $path2 = Join-Path $PSScriptRoot "..\Workspaces\2025\09\23\Black\The_Matrix.Report"
  
  if ((Test-Path $path1) -and (Test-Path $path2)) {
    & $scriptPath `
      -LocalPath $path1 `
      -CompareLocalPath $path2 `
      -FirstItemLabel "2025-09-20" `
      -SecondItemLabel "2025-09-23" `
      -Verbose
  }
  else {
    Write-Warning "Test paths not found. Skipping this test."
    Write-Host "Path 1 exists: $(Test-Path $path1)" -ForegroundColor Gray
    Write-Host "Path 2 exists: $(Test-Path $path2)" -ForegroundColor Gray
  }
  
  # Test 2: Compare with automatic labels
  Write-TestHeader "TEST 2: LocalToLocal - Automatic Smart Labels"
  Write-Host "Comparing 'Northwinds_Composite.Report' with auto-generated labels`n" -ForegroundColor Gray
  
  $path3 = Join-Path $PSScriptRoot "..\Workspaces\2025\09\20\Black\Northwinds_Composite.Report"
  $path4 = Join-Path $PSScriptRoot "..\Workspaces\2025\09\21\Black\Northwinds_Composite.Report"
  
  if ((Test-Path $path3) -and (Test-Path $path4)) {
    & $scriptPath `
      -LocalPath $path3 `
      -CompareLocalPath $path4
  }
  else {
    Write-Warning "Test paths not found. Skipping this test."
  }
  
  # Test 3: Reverse direction
  Write-TestHeader "TEST 3: LocalToLocal - Reverse Direction"
  Write-Host "Same comparison as Test 1, but with reversed diff direction`n" -ForegroundColor Gray
  
  if ((Test-Path $path1) -and (Test-Path $path2)) {
    & $scriptPath `
      -LocalPath $path1 `
      -CompareLocalPath $path2 `
      -FirstItemLabel "2025-09-20" `
      -SecondItemLabel "2025-09-23" `
      -ReverseDirection
  }
  else {
    Write-Warning "Test paths not found. Skipping this test."
  }
  
  # Test 4: Path validation
  Write-TestHeader "TEST 4: LocalToLocal - Path Validation"
  Write-Host "Attempting to compare different item types (should fail)`n" -ForegroundColor Gray
  
  $reportPath = Join-Path $PSScriptRoot "..\Workspaces\2025\09\20\Black\The_Matrix.Report"
  $modelPath = Join-Path $PSScriptRoot "..\Workspaces\2025\09\20\Black\The_Matrix.SemanticModel"
  
  if ((Test-Path $reportPath) -and (Test-Path $modelPath)) {
    try {
      & $scriptPath `
        -LocalPath $reportPath `
        -CompareLocalPath $modelPath
      Write-Host "ERROR: Path validation should have failed!" -ForegroundColor Red
    }
    catch {
      Write-Host "✓ Path validation working correctly: $_" -ForegroundColor Green
    }
    
    Write-Host "`nNow bypassing validation with -SkipPathValidation..." -ForegroundColor Cyan
    & $scriptPath `
      -LocalPath $reportPath `
      -CompareLocalPath $modelPath `
      -SkipPathValidation
  }
  else {
    Write-Warning "Test paths not found. Skipping path validation test."
  }
}

# ============================================================================
# PART 2: Display Name Support Demo
# ============================================================================

Write-SectionHeader "PART 2: Display Name Support Demo"

Write-Host "The script now supports both GUIDs and display names!`n" -ForegroundColor Yellow

Write-TestHeader "Parameter Changes"
Write-Host "Old Parameter Names → New Parameter Names:" -ForegroundColor Gray
Write-Host "  -WorkspaceId        → " -NoNewline -ForegroundColor Red
Write-Host "-Workspace" -ForegroundColor Green
Write-Host "  -ItemId             → " -NoNewline -ForegroundColor Red
Write-Host "-Item" -ForegroundColor Green
Write-Host "  -CompareWorkspaceId → " -NoNewline -ForegroundColor Red
Write-Host "-CompareWorkspace" -ForegroundColor Green
Write-Host "  -CompareItemId      → " -NoNewline -ForegroundColor Red
Write-Host "-CompareItem" -ForegroundColor Green

Write-TestHeader "Example 1: CloudToLocal with Display Names"
Write-Host @'
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "Production" `
  -Item "Sales Report" `
  -LocalPath "C:\Repos\MyReport.Report"
'@ -ForegroundColor Gray

Write-Host "`nThe script automatically detects this is a name (not GUID)" -ForegroundColor Cyan
Write-Host "and resolves it by calling the Fabric API.`n" -ForegroundColor Cyan

Write-TestHeader "Example 2: CloudToLocal with GUIDs (still works!)"
Write-Host @'
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "12345678-1234-1234-1234-123456789012" `
  -Item "87654321-4321-4321-4321-210987654321" `
  -LocalPath "C:\Repos\MyReport.Report"
'@ -ForegroundColor Gray

Write-Host "`nGUIDs are detected by regex pattern and used directly" -ForegroundColor Cyan
Write-Host "(no API lookup needed).`n" -ForegroundColor Cyan

Write-TestHeader "Example 3: CloudToCloud DEV vs PROD"
Write-Host @'
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "Development" `
  -Item "Customer Dashboard" `
  -CompareWorkspace "Production" `
  -CompareItem "Customer Dashboard" `
  -FirstItemLabel "DEV" `
  -SecondItemLabel "PROD"
'@ -ForegroundColor Gray

Write-Host "`nCompare the same report across environments" -ForegroundColor Cyan
Write-Host "using friendly workspace names!`n" -ForegroundColor Cyan

Write-TestHeader "Example 4: Mixed (Name + GUID)"
Write-Host @'
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "Production" `
  -Item "87654321-4321-4321-4321-210987654321" `
  -LocalPath "C:\Repos\MyReport.Report"
'@ -ForegroundColor Gray

Write-Host "`nYou can mix display names and GUIDs!" -ForegroundColor Cyan
Write-Host "Use whatever is most convenient.`n" -ForegroundColor Cyan

Write-TestHeader "Benefits of Display Name Support"
Write-Host "✅ More readable scripts" -ForegroundColor Green
Write-Host "✅ No need to look up GUIDs" -ForegroundColor Green
Write-Host "✅ Easier to remember and type" -ForegroundColor Green
Write-Host "✅ GUIDs still work if you prefer" -ForegroundColor Green
Write-Host "✅ Can mix names and GUIDs" -ForegroundColor Green

Write-TestHeader "How It Works"
Write-Host "1. Script checks if input matches GUID pattern (regex)" -ForegroundColor Gray
Write-Host "2. If GUID → Use directly (fast)" -ForegroundColor Gray
Write-Host "3. If not GUID → Look up by display name (1-2 API calls)" -ForegroundColor Gray
Write-Host "4. Resolve to GUID and proceed with comparison" -ForegroundColor Gray

# ============================================================================
# PART 3: Cloud Tests (Optional - Requires Authentication)
# ============================================================================

if ($RunCloudTests) {
  Write-SectionHeader "PART 3: Cloud Comparison Tests (Requires Authentication)"
  
  Write-Host "These tests require Fabric workspace access and authentication." -ForegroundColor Yellow
  Write-Host "Checking authentication status...`n" -ForegroundColor Yellow
  
  try {
    Import-Module Az.Accounts -ErrorAction Stop
    $context = Get-AzContext
    
    if (-not $context) {
      Write-Host "Not authenticated. Please run Connect-AzAccount first." -ForegroundColor Red
      Write-Host "Example: Connect-AzAccount -UseDeviceAuthentication" -ForegroundColor Gray
      return
    }
    
    Write-Host "✓ Authenticated as: $($context.Account.Id)" -ForegroundColor Green
    Write-Host ""
    
    # Test 5: CloudToLocal with Display Name
    Write-TestHeader "TEST 5: CloudToLocal - Display Name"
    Write-Host "To run this test, update with your workspace and item names:`n" -ForegroundColor Gray
    
    Write-Host @'
$workspace = "Your Workspace Name"
$item = "Your Item Name"
$localPath = ".\Workspaces\2025\10\18\Black\YourItem.Report"

.\Compare-FabricItemDefinition.ps1 `
  -Workspace $workspace `
  -Item $item `
  -LocalPath $localPath `
  -Verbose
'@ -ForegroundColor DarkGray
    
    # Test 6: CloudToCloud with Display Names
    Write-TestHeader "TEST 6: CloudToCloud - Display Names"
    Write-Host "To run this test, update with your workspace and item names:`n" -ForegroundColor Gray
    
    Write-Host @'
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "Development" `
  -Item "Sales Dashboard" `
  -CompareWorkspace "Production" `
  -CompareItem "Sales Dashboard" `
  -FirstItemLabel "DEV" `
  -SecondItemLabel "PROD" `
  -Verbose
'@ -ForegroundColor DarkGray
    
    # Test 7: CloudToCloud with GUIDs
    Write-TestHeader "TEST 7: CloudToCloud - GUIDs"
    Write-Host "To run this test, update with your workspace and item GUIDs:`n" -ForegroundColor Gray
    
    Write-Host @'
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "workspace1-guid" `
  -Item "item1-guid" `
  -CompareWorkspace "workspace2-guid" `
  -CompareItem "item2-guid" `
  -FirstItemLabel "V1" `
  -SecondItemLabel "V2" `
  -Verbose
'@ -ForegroundColor DarkGray
    
    Write-Host "`n⚠ Cloud tests require manual configuration with your actual workspace/item values." -ForegroundColor Yellow
  }
  catch {
    Write-Warning "Failed to check authentication: $_"
    Write-Host "Make sure Az.Accounts module is installed:" -ForegroundColor Gray
    Write-Host "  Install-Module Az.Accounts -Scope CurrentUser" -ForegroundColor Gray
  }
}
else {
  Write-SectionHeader "PART 3: Cloud Tests (Skipped)"
  Write-Host "Cloud tests were skipped. To run them, use: -RunCloudTests" -ForegroundColor Yellow
  Write-Host "Note: Cloud tests require Fabric authentication and manual configuration.`n" -ForegroundColor Gray
}

# ============================================================================
# Summary
# ============================================================================

Write-SectionHeader "Test Summary"

if (-not $SkipLocalTests) {
  Write-Host "✓ LocalToLocal tests completed" -ForegroundColor Green
}
else {
  Write-Host "⊘ LocalToLocal tests skipped (-SkipLocalTests)" -ForegroundColor Gray
}

Write-Host "✓ Display name support demo completed" -ForegroundColor Green

if ($RunCloudTests) {
  Write-Host "⚠ Cloud tests shown (require manual configuration)" -ForegroundColor Yellow
}
else {
  Write-Host "⊘ Cloud tests skipped (use -RunCloudTests to show)" -ForegroundColor Gray
}

Write-Host "`nFor more information, see:" -ForegroundColor Cyan
Write-Host "  Compare-FabricItemDefinition-Guide.md" -ForegroundColor Gray
Write-Host ""
