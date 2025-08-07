<#
.SYNOPSIS
Main test runner for Fabric Archive Bot testing suite

.DESCRIPTION
This script runs all Pester tests for the Fabric Archive Bot solution.
It supports running unit tests, integration tests, or all tests with various options.

.PARAMETER TestType
Specifies which type of tests to run: 'Unit', 'Integration', or 'All'

.PARAMETER Coverage
Generate code coverage report

.PARAMETER OutputFormat
Output format for test results (NUnitXml, JUnitXml, etc.)

.PARAMETER OutputFile
Path to save test results

.EXAMPLE
.\tests\Invoke-Tests.ps1 -TestType Unit
#>

[CmdletBinding()]
param(
  [Parameter()]
  [ValidateSet('Unit', 'Integration', 'All')]
  [string]$TestType = 'All',
    
  [Parameter()]
  [switch]$Coverage,
    
  [Parameter()]
  [ValidateSet('None', 'NUnitXml', 'JUnitXml')]
  [string]$OutputFormat = 'None',
    
  [Parameter()]
  [string]$OutputFile,
    
  [Parameter()]
  [switch]$PassThru
)

# Ensure Pester is available
if (-not (Get-Module -Name Pester -ListAvailable)) {
  Write-Host "Installing Pester module..." -ForegroundColor Yellow
  Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck
}

# Import required modules
Import-Module Pester

# Set test root path
$TestRoot = $PSScriptRoot

# Configure test paths based on test type
$TestPaths = switch ($TestType) {
  'Unit' { @(Join-Path $TestRoot 'unit') }
  'Integration' { @(Join-Path $TestRoot 'integration') }
  'All' { @(Join-Path $TestRoot 'unit'), (Join-Path $TestRoot 'integration') }
}

# Configure Pester
$PesterConfiguration = [PesterConfiguration]::Default
$PesterConfiguration.Run.Path = $TestPaths
$PesterConfiguration.Run.PassThru = $PassThru.IsPresent
$PesterConfiguration.Should.ErrorAction = 'Stop'

# Configure output
if ($OutputFormat -ne 'None' -and $OutputFile) {
  $PesterConfiguration.TestResult.Enabled = $true
  $PesterConfiguration.TestResult.OutputFormat = $OutputFormat
  $PesterConfiguration.TestResult.OutputPath = $OutputFile
}

# Configure code coverage if requested
if ($Coverage) {
  $PesterConfiguration.CodeCoverage.Enabled = $true
  $PesterConfiguration.CodeCoverage.Path = @(
    Join-Path (Split-Path $TestRoot) 'modules\FabricArchiveBotCore.psm1'
    Join-Path (Split-Path $TestRoot) 'Export-FabricItemsFromAllWorkspaces.ps1'
    Join-Path (Split-Path $TestRoot) 'Start-FabricArchiveBot.ps1'
  )
  $PesterConfiguration.CodeCoverage.OutputFormat = 'JaCoCo'
  $PesterConfiguration.CodeCoverage.OutputPath = Join-Path $TestRoot 'coverage.xml'
}

# Run tests
Write-Host "Running $TestType tests..." -ForegroundColor Green
$Result = Invoke-Pester -Configuration $PesterConfiguration

# Display results summary
Write-Host "`nTest Results Summary:" -ForegroundColor Cyan
Write-Host "  Total Tests: $($Result.TotalCount)" -ForegroundColor White
Write-Host "  Passed: $($Result.PassedCount)" -ForegroundColor Green
Write-Host "  Failed: $($Result.FailedCount)" -ForegroundColor $(if ($Result.FailedCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Skipped: $($Result.SkippedCount)" -ForegroundColor Yellow

if ($Coverage -and $Result.CodeCoverage) {
  $CoveragePercent = [math]::Round(($Result.CodeCoverage.CommandsExecuted / $Result.CodeCoverage.CommandsAnalyzed) * 100, 2)
  Write-Host "  Code Coverage: $CoveragePercent%" -ForegroundColor $(if ($CoveragePercent -ge 70) { 'Green' } elseif ($CoveragePercent -ge 50) { 'Yellow' } else { 'Red' })
}

# Exit with appropriate code
if ($Result.FailedCount -gt 0) {
  exit 1
}
else {
  exit 0
}
