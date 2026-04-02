<#
.SYNOPSIS
  Runs Pester tests for Fabric Archive Bot

.PARAMETER TestType
  Type of tests to run: Unit, Integration, or All (default)

.PARAMETER Coverage
  Enable code coverage reporting

.PARAMETER OutputFormat
  Output format for test results (NUnitXml, JUnitXml)

.PARAMETER OutputFile
  Path for test results output file
#>
[CmdletBinding()]
param(
  [Parameter()]
  [ValidateSet('Unit', 'Integration', 'All')]
  [string]$TestType = 'All',

  [Parameter()]
  [switch]$Coverage,

  [Parameter()]
  [ValidateSet('NUnitXml', 'JUnitXml')]
  [string]$OutputFormat,

  [Parameter()]
  [string]$OutputFile
)

# Ensure Pester 5+ is available
$pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pesterModule -or $pesterModule.Version.Major -lt 5) {
  Write-Error "Pester 5.x or later is required. Install with: Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck"
  exit 1
}

Import-Module Pester -MinimumVersion 5.0

# Build Pester configuration
$pesterConfig = New-PesterConfiguration

# Determine which test paths to include
$testsRoot = $PSScriptRoot
switch ($TestType) {
  'Unit' { $pesterConfig.Run.Path = @(Join-Path $testsRoot 'Unit') }
  'Integration' { $pesterConfig.Run.Path = @(Join-Path $testsRoot 'Integration') }
  'All' { $pesterConfig.Run.Path = @($testsRoot) }
}

$pesterConfig.Run.Exit = $true
$pesterConfig.Output.Verbosity = 'Detailed'

# Configure output
if ($OutputFormat -and $OutputFile) {
  $pesterConfig.TestResult.Enabled = $true
  $pesterConfig.TestResult.OutputFormat = $OutputFormat
  $pesterConfig.TestResult.OutputPath = $OutputFile
}

# Configure coverage
if ($Coverage) {
  $pesterConfig.CodeCoverage.Enabled = $true
  $pesterConfig.CodeCoverage.Path = @(
    Join-Path (Split-Path $testsRoot -Parent) 'modules' 'FabricArchiveBotCore.psm1'
  )
  $pesterConfig.CodeCoverage.OutputPath = Join-Path $testsRoot 'coverage.xml'
}

# Run tests
Invoke-Pester -Configuration $pesterConfig
