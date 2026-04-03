BeforeAll {
  $modulePath = Join-Path $PSScriptRoot '..' '..' 'modules' 'FabricArchiveBotCore.psm1'
  Import-Module $modulePath -Force
}

Describe 'Get-FABOptimalThrottleLimit' {
  BeforeAll {
    # Mock Get-CimInstance in the module's scope
    Mock Get-CimInstance {
      [PSCustomObject]@{ NumberOfLogicalProcessors = 8 }
    } -ModuleName FabricArchiveBotCore
  }

  It 'Should use runtime override when provided' {
    $result = Get-FABOptimalThrottleLimit -OverrideThrottleLimit 4
    $result | Should -Be 4
  }

  It 'Should use config throttle limit when set and no override' {
    $config = [PSCustomObject]@{
      FabricPSPBIPSettings = [PSCustomObject]@{
        ThrottleLimit = 6
      }
    }
    $result = Get-FABOptimalThrottleLimit -OverrideThrottleLimit 0 -Config $config
    $result | Should -Be 6
  }

  It 'Should auto-detect from CPU cores when no override or config' {
    $config = [PSCustomObject]@{
      FabricPSPBIPSettings = [PSCustomObject]@{
        ThrottleLimit = 0
      }
    }
    $result = Get-FABOptimalThrottleLimit -OverrideThrottleLimit 0 -Config $config
    $result | Should -Be 8  # mocked CPU count
  }

  It 'Should cap auto-detect at 12' {
    Mock Get-CimInstance {
      [PSCustomObject]@{ NumberOfLogicalProcessors = 64 }
    } -ModuleName FabricArchiveBotCore

    $config = [PSCustomObject]@{
      FabricPSPBIPSettings = [PSCustomObject]@{
        ThrottleLimit = 0
      }
    }
    $result = Get-FABOptimalThrottleLimit -OverrideThrottleLimit 0 -Config $config
    $result | Should -Be 12
  }

  It 'Should handle config without FabricPSPBIPSettings' {
    Mock Get-CimInstance {
      [PSCustomObject]@{ NumberOfLogicalProcessors = 4 }
    } -ModuleName FabricArchiveBotCore

    $config = [PSCustomObject]@{
      Version = '2.0'
    }
    $result = Get-FABOptimalThrottleLimit -OverrideThrottleLimit 0 -Config $config
    $result | Should -Be 4
  }
}

Describe 'Export-FABLogSummary' {
  BeforeEach {
    Initialize-FABLogging
  }

  It 'Should export a valid JSON summary file' {
    $outputPath = Join-Path $TestDrive "summary.json"
    $result = Export-FABLogSummary -OutputPath $outputPath
    $result | Should -Be $outputPath
    Test-Path $outputPath | Should -BeTrue

    $json = Get-Content $outputPath -Raw | ConvertFrom-Json
    $json.SessionId | Should -Not -BeNullOrEmpty
    $json.ErrorCount | Should -Be 0
  }

  It 'Should include operation data in the summary' {
    $op = Start-FABOperation -OperationName 'TestExportOp'
    Complete-FABOperation -Operation $op -Success

    $outputPath = Join-Path $TestDrive "summary-with-ops.json"
    Export-FABLogSummary -OutputPath $outputPath

    $json = Get-Content $outputPath -Raw | ConvertFrom-Json
    $json.TotalOperations | Should -BeGreaterThan 0
  }

  It 'Should generate a default path when none provided and no log file' {
    Push-Location $TestDrive
    try {
      $result = Export-FABLogSummary
      $result | Should -Not -BeNullOrEmpty
      Test-Path $result | Should -BeTrue
    }
    finally {
      Pop-Location
    }
  }
}

Describe 'Test-FABFabricPSPBIPAvailability' {
  It 'Should return true when Invoke-FabricAPIRequest command exists' {
    Mock Get-Command {
      [PSCustomObject]@{ Name = 'Invoke-FabricAPIRequest' }
    } -ModuleName FabricArchiveBotCore

    $result = Test-FABFabricPSPBIPAvailability
    $result | Should -BeTrue
  }

  It 'Should return false when module is not available anywhere' {
    Mock Get-Command { throw "Command not found" } -ModuleName FabricArchiveBotCore
    Mock Test-Path { $false } -ModuleName FabricArchiveBotCore

    $result = Test-FABFabricPSPBIPAvailability
    $result | Should -BeFalse
  }
}
