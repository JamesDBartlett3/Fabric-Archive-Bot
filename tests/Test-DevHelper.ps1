<#
.SYNOPSIS
Development helper script for Fabric Archive Bot testing

.DESCRIPTION
This script provides convenient functions for test development, debugging, and maintenance.
It includes utilities for setting up test environments, running specific test categories,
and analyzing test results.

.PARAMETER Action
The action to perform: Setup, Unit, Integration, All, Debug, Analyze, or Clean

.PARAMETER TestName
Specific test name or pattern to run (for Debug action)

.PARAMETER Coverage
Include code coverage analysis

.PARAMETER Quiet
Suppress verbose output for automated scenarios

.EXAMPLE
.\tests\Test-DevHelper.ps1 -Action Setup
.\tests\Test-DevHelper.ps1 -Action Unit -Coverage
.\tests\Test-DevHelper.ps1 -Action Debug -TestName "*Configuration*"
.\tests\Test-DevHelper.ps1 -Action All -Quiet
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Setup', 'Unit', 'Integration', 'All', 'Debug', 'Analyze', 'Clean')]
  [string]$Action,
    
  [Parameter()]
  [string]$TestName = "*",
    
  [Parameter()]
  [switch]$Coverage,
    
  [Parameter()]
  [switch]$Quiet
)

# Set up paths
$TestRoot = $PSScriptRoot
$ProjectRoot = Split-Path $TestRoot

function Write-FABTestHeader {
  param([string]$Title)
  Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
  Write-Host "  $Title" -ForegroundColor White
  Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Initialize-FABTestEnvironment {
  Write-FABTestHeader "Setting Up Test Environment"  # Check PowerShell version
  if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "PowerShell 7+ is recommended for this solution"
    Write-Host "Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
  }
  else {
    Write-Host "✓ PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Green
  }
    
  # Install/Update Pester
  Write-Host "`nChecking Pester installation..." -ForegroundColor Gray
  $pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    
  if (-not $pesterModule -or $pesterModule.Version -lt [Version]"5.0.0") {
    Write-Host "Installing/Updating Pester module..." -ForegroundColor Yellow
    Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck
    Write-Host "✓ Pester installed/updated" -ForegroundColor Green
  }
  else {
    Write-Host "✓ Pester version: $($pesterModule.Version)" -ForegroundColor Green
  }
    
  # Create test output directory
  $testOutputDir = Join-Path $env:TEMP "FABTestOutput"
  if (-not (Test-Path $testOutputDir)) {
    New-Item -Path $testOutputDir -ItemType Directory -Force | Out-Null
    Write-Host "✓ Created test output directory: $testOutputDir" -ForegroundColor Green
  }
  else {
    Write-Host "✓ Test output directory exists: $testOutputDir" -ForegroundColor Green
  }
    
  # Validate test structure
  Write-Host "`nValidating test structure..." -ForegroundColor Gray
  $requiredPaths = @(
    "tests\fixtures\TestData.ps1",
    "tests\fixtures\test-config.json",
    "tests\unit\FabricArchiveBotCore.Tests.ps1",
    "tests\unit\Configuration.Tests.ps1",
    "tests\integration\ModuleIntegration.Tests.ps1",
    "tests\integration\MainScripts.Tests.ps1"
  )
    
  foreach ($path in $requiredPaths) {
    $fullPath = Join-Path $ProjectRoot $path
    if (Test-Path $fullPath) {
      Write-Host "✓ $path" -ForegroundColor Green
    }
    else {
      Write-Host "✗ $path" -ForegroundColor Red
    }
  }
    
  Write-Host "`n✓ Test environment setup complete" -ForegroundColor Green
}

function Invoke-FABTestRun {
  param([string]$TestType = 'All')
    
  if (-not $Quiet) {
    Write-FABTestHeader "Running $TestType Tests"    Write-Host "Using fast test configuration:" -ForegroundColor Yellow
    Write-Host "  - Rate limit timeout: 1 second" -ForegroundColor Gray
    Write-Host "  - Max retries: 1" -ForegroundColor Gray
    Write-Host "  - Start-Sleep mocked globally" -ForegroundColor Gray
  }
    
  $params = @{
    TestType = $TestType
    PassThru = $true
  }
    
  if ($Coverage) {
    $params.Coverage = $true
    if (-not $Quiet) {
      Write-Host "Code coverage enabled" -ForegroundColor Yellow
    }
  }
    
  $testScript = Join-Path $TestRoot "Invoke-Tests.ps1"
    
  if ($Quiet) {
    # Suppress output for quiet mode
    $result = & $testScript @params 2>$null
    if ($result) {
      Write-Host "Tests Passed: $($result.PassedCount), Failed: $($result.FailedCount), Skipped: $($result.SkippedCount)" -ForegroundColor Cyan
    }
  }
  else {
    & $testScript @params
  }
}

function Start-FABTestDebug {
  Write-FABTestHeader "Debug Mode - Running Specific Tests"  if (-not (Get-Module -Name Pester -ListAvailable)) {
    Write-Error "Pester module not found. Run Setup action first."
    return
  }
    
  Import-Module Pester
    
  # Configure Pester for debugging
  $config = [PesterConfiguration]::Default
  $config.Run.Path = @(
    Join-Path $TestRoot "unit"
    Join-Path $TestRoot "integration"
  )
  $config.Filter.FullName = $TestName
  $config.Output.Verbosity = 'Detailed'
  $config.Run.PassThru = $true
  $config.Should.ErrorAction = 'Continue'  # Continue on errors for debugging
    
  Write-Host "Running tests matching: $TestName" -ForegroundColor Yellow
  Write-Host "Verbosity: Detailed" -ForegroundColor Yellow
    
  $result = Invoke-Pester -Configuration $config
    
  Write-Host "`nDebug Summary:" -ForegroundColor Cyan
  Write-Host "  Tests Found: $($result.TotalCount)" -ForegroundColor White
  Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
  Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor Red
  Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
  Write-Host "  Not Run: $($result.NotRunCount)" -ForegroundColor DarkGray
    
  # Validation check
  $accountedFor = $result.PassedCount + $result.FailedCount + $result.SkippedCount + $result.NotRunCount
  if ($accountedFor -ne $result.TotalCount) {
    Write-Host "  ⚠️ Numbers don't add up! Expected: $($result.TotalCount), Got: $accountedFor" -ForegroundColor Yellow
  }
    
  if ($result.FailedCount -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    foreach ($failed in $result.Failed) {
      Write-Host "  - $($failed.ExpandedName)" -ForegroundColor Red
      if ($failed.ErrorRecord) {
        Write-Host "    Error: $($failed.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed
      }
    }
  }
}

function Get-FABTestResults {
  Write-FABTestHeader "Analyzing Test Results"  # Look for recent test result files
  $resultFiles = Get-ChildItem -Path $TestRoot -Filter "*test-results.xml" -ErrorAction SilentlyContinue
  $coverageFiles = Get-ChildItem -Path $TestRoot -Filter "coverage.xml" -ErrorAction SilentlyContinue
    
  if ($resultFiles) {
    Write-Host "Found test result files:" -ForegroundColor Green
    foreach ($file in $resultFiles) {
      Write-Host "  - $($file.Name) ($(Get-Date $file.LastWriteTime -Format 'yyyy-MM-dd HH:mm'))" -ForegroundColor Gray
    }
  }
  else {
    Write-Host "No test result files found" -ForegroundColor Yellow
  }
    
  if ($coverageFiles) {
    Write-Host "`nFound coverage files:" -ForegroundColor Green
    foreach ($file in $coverageFiles) {
      Write-Host "  - $($file.Name) ($(Get-Date $file.LastWriteTime -Format 'yyyy-MM-dd HH:mm'))" -ForegroundColor Gray
    }
  }
  else {
    Write-Host "No coverage files found" -ForegroundColor Yellow
  }
    
  # Analyze module structure for test coverage
  Write-Host "`nModule Analysis:" -ForegroundColor Cyan
  $moduleFile = Join-Path $ProjectRoot "modules\FabricArchiveBotCore.psm1"
  if (Test-Path $moduleFile) {
    $content = Get-Content $moduleFile
    $functions = $content | Select-String "^function\s+(\w+-\w+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }
        
    Write-Host "Public functions in module: $($functions.Count)" -ForegroundColor White
    foreach ($func in $functions) {
      # Check if function has tests
      $hasTests = Get-ChildItem -Path $TestRoot -Recurse -Filter "*.Tests.ps1" | 
      Select-String -Pattern $func -Quiet
            
      $status = if ($hasTests) { "✓" } else { "✗" }
      $color = if ($hasTests) { "Green" } else { "Red" }
      Write-Host "  $status $func" -ForegroundColor $color
    }
  }
}

function Clear-FABTestEnvironment {
  Write-FABTestHeader "Cleaning Test Environment"  # Remove test output files
  $filesToClean = @(
    Join-Path $TestRoot "*test-results.xml"
    Join-Path $TestRoot "coverage.xml"
    Join-Path $env:TEMP "FAB*"
  )
    
  foreach ($pattern in $filesToClean) {
    $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
    if ($files) {
      Write-Host "Removing: $pattern" -ForegroundColor Yellow
      $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }
  }
    
  # Clean up environment variables
  $envVars = [System.Environment]::GetEnvironmentVariables([System.EnvironmentVariableTarget]::User)
  $fabVars = $envVars.Keys | Where-Object { $_ -like "FabricArchiveBot*Test*" }
    
  foreach ($var in $fabVars) {
    Write-Host "Removing environment variable: $var" -ForegroundColor Yellow
    [System.Environment]::SetEnvironmentVariable($var, $null, "User")
  }
    
  Write-Host "✓ Test environment cleaned" -ForegroundColor Green
}

# Main execution
switch ($Action) {
  'Setup' { Initialize-FABTestEnvironment }
  'Unit' { Invoke-FABTestRun -TestType 'Unit' }
  'Integration' { Invoke-FABTestRun -TestType 'Integration' }
  'All' { Invoke-FABTestRun -TestType 'All' }
  'Debug' { Start-FABTestDebug }
  'Analyze' { Get-FABTestResults }
  'Clean' { Clear-FABTestEnvironment }
}if (-not $Quiet) {
  Write-Host "`nAction '$Action' completed." -ForegroundColor Cyan
}
