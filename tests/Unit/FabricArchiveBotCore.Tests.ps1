BeforeAll {
  # Import the module under test
  $modulePath = Join-Path $PSScriptRoot '..' '..' 'modules' 'FabricArchiveBotCore.psm1'
  Import-Module $modulePath -Force
}

Describe 'Get-FABConfiguration' {
  Context 'Loading from JSON file' {
    It 'Should load a valid config file' {
      $configPath = Join-Path $PSScriptRoot '..' '..' 'FabricArchiveBot_Config.json'
      $config = Get-FABConfiguration -ConfigPath $configPath
      $config | Should -Not -BeNullOrEmpty
      $config.Version | Should -Be '2.0'
    }

    It 'Should throw when config file does not exist' {
      { Get-FABConfiguration -ConfigPath 'C:\nonexistent\config.json' } | Should -Throw
    }
  }

  Context 'Loading from environment variable' {
    It 'Should throw when env var is not set' {
      # Ensure the env var is cleared
      [System.Environment]::SetEnvironmentVariable('FabricArchiveBot_ConfigObject', $null, 'User')
      { Get-FABConfiguration -ConfigFromEnv } | Should -Throw '*environment variable*'
    }
  }
}

Describe 'Confirm-FABConfigurationCompatibility' {
  BeforeAll {
    # Mock the dynamic item type fetch to avoid network calls
    Mock Get-FABSupportedItemTypes {
      return @('Report', 'SemanticModel', 'Notebook', 'DataPipeline')
    }
  }

  It 'Should return config with ExportSettings intact' {
    $config = [PSCustomObject]@{
      Version = '2.0'
      ExportSettings = [PSCustomObject]@{
        TargetFolder    = '.\Workspaces'
        RetentionDays   = 30
        WorkspaceFilter = "(state eq 'Active')"
        ItemTypes       = @('Report', 'SemanticModel')
      }
    }

    $result = Confirm-FABConfigurationCompatibility -Config $config
    $result.ExportSettings.ItemTypes | Should -Contain 'Report'
    $result.ExportSettings.ItemTypes | Should -Contain 'SemanticModel'
  }

  It 'Should add default ExportSettings when missing' {
    # Create a temp directory so Resolve-Path succeeds for the default target folder
    $tempWorkspaces = Join-Path $TestDrive 'Workspaces'
    New-Item -Path $tempWorkspaces -ItemType Directory -Force | Out-Null
    Push-Location $TestDrive
    try {
      $config = [PSCustomObject]@{
        Version = '2.0'
      }

      $result = Confirm-FABConfigurationCompatibility -Config $config
      $result.ExportSettings | Should -Not -BeNullOrEmpty
      $result.ExportSettings.TargetFolder | Should -Not -BeNullOrEmpty
      $result.ExportSettings.WorkspaceFilter | Should -Not -BeNullOrEmpty
    }
    finally {
      Pop-Location
    }
  }

  It 'Should filter out unsupported item types' {
    $config = [PSCustomObject]@{
      Version = '2.0'
      ExportSettings = [PSCustomObject]@{
        TargetFolder    = '.\Workspaces'
        RetentionDays   = 30
        WorkspaceFilter = "(state eq 'Active')"
        ItemTypes       = @('Report', 'FakeItemType')
      }
    }

    $result = Confirm-FABConfigurationCompatibility -Config $config
    $result.ExportSettings.ItemTypes | Should -Contain 'Report'
    $result.ExportSettings.ItemTypes | Should -Not -Contain 'FakeItemType'
  }
}

Describe 'Invoke-FABWorkspaceFilter' {
  BeforeAll {
    $testWorkspaces = @(
      [PSCustomObject]@{ id = '1'; displayName = 'Production Finance'; type = 'Workspace'; state = 'Active' }
      [PSCustomObject]@{ id = '2'; displayName = 'Dev Sandbox'; type = 'Workspace'; state = 'Active' }
      [PSCustomObject]@{ id = '3'; displayName = 'Production HR'; type = 'Workspace'; state = 'Active' }
      [PSCustomObject]@{ id = '4'; displayName = 'Test Environment'; type = 'AdminWorkspace'; state = 'Active' }
    )
  }

  It 'Should filter by name contains' {
    $result = Invoke-FABWorkspaceFilter -Workspaces $testWorkspaces -Filter "contains(name,'Production')"
    $result.Count | Should -Be 2
    $result[0].displayName | Should -BeLike '*Production*'
  }

  It 'Should filter by name startswith' {
    $result = Invoke-FABWorkspaceFilter -Workspaces $testWorkspaces -Filter "startswith(name,'Dev')"
    $result.Count | Should -Be 1
    $result[0].displayName | Should -Be 'Dev Sandbox'
  }

  It 'Should filter by name endswith' {
    $result = Invoke-FABWorkspaceFilter -Workspaces $testWorkspaces -Filter "endswith(name,'HR')"
    $result.Count | Should -Be 1
    $result[0].displayName | Should -Be 'Production HR'
  }

  It 'Should filter by type' {
    $result = Invoke-FABWorkspaceFilter -Workspaces $testWorkspaces -Filter "type eq 'Workspace'"
    $result.Count | Should -Be 3
  }

  It 'Should filter by state Active (returns all)' {
    $result = Invoke-FABWorkspaceFilter -Workspaces $testWorkspaces -Filter "state eq 'Active'"
    $result.Count | Should -Be 4
  }

  It 'Should filter by state Inactive (returns none)' {
    $result = Invoke-FABWorkspaceFilter -Workspaces $testWorkspaces -Filter "state eq 'Inactive'"
    $result.Count | Should -Be 0
  }

  It 'Should handle combined filters' {
    $result = Invoke-FABWorkspaceFilter -Workspaces $testWorkspaces -Filter "(type eq 'Workspace') and contains(name,'Production')"
    $result.Count | Should -Be 2
  }
}

Describe 'Invoke-FABItemFilter' {
  BeforeAll {
    $testItems = @(
      [PSCustomObject]@{ id = '1'; displayName = 'Sales Report'; type = 'Report'; description = 'Monthly sales data' }
      [PSCustomObject]@{ id = '2'; displayName = 'Revenue Model'; type = 'SemanticModel'; description = 'Revenue calculations' }
      [PSCustomObject]@{ id = '3'; displayName = 'HR Report'; type = 'Report'; description = 'Employee metrics' }
      [PSCustomObject]@{ id = '4'; displayName = 'ETL Pipeline'; type = 'DataPipeline'; description = 'Data ingestion' }
      [PSCustomObject]@{ id = '5'; displayName = 'Sales Notebook'; type = 'Notebook'; description = 'Sales analysis notebook' }
    )
  }

  It 'Should filter by type eq' {
    $result = Invoke-FABItemFilter -Items $testItems -Filter "type eq 'Report'"
    $result.Count | Should -Be 2
  }

  It 'Should filter by type in' {
    $result = Invoke-FABItemFilter -Items $testItems -Filter "type in ('Report', 'SemanticModel')"
    $result.Count | Should -Be 3
  }

  It 'Should filter by displayName contains' {
    $result = Invoke-FABItemFilter -Items $testItems -Filter "contains(displayName,'Sales')"
    $result.Count | Should -Be 2
  }

  It 'Should filter by displayName startswith' {
    $result = Invoke-FABItemFilter -Items $testItems -Filter "startswith(displayName,'ETL')"
    $result.Count | Should -Be 1
    $result[0].displayName | Should -Be 'ETL Pipeline'
  }

  It 'Should filter by displayName endswith' {
    $result = Invoke-FABItemFilter -Items $testItems -Filter "endswith(displayName,'Report')"
    $result.Count | Should -Be 2
  }

  It 'Should filter by description contains' {
    $result = Invoke-FABItemFilter -Items $testItems -Filter "contains(description,'sales')"
    $result.Count | Should -Be 2
  }

  It 'Should warn for Scanner API filters without config' {
    $result = Invoke-FABItemFilter -Items $testItems -Filter "modifiedBy eq 'user@contoso.com'"
    # Should return all items since Scanner API is not enabled
    $result.Count | Should -Be 5
  }
}

Describe 'Logging Functions' {
  BeforeEach {
    # Reset logging state before each test
    Initialize-FABLogging
  }

  Context 'Initialize-FABLogging' {
    It 'Should initialize with default settings' {
      $summary = Get-FABLogSummary
      $summary.ErrorCount | Should -Be 0
      $summary.WarningCount | Should -Be 0
      $summary.SuccessCount | Should -Be 0
      $summary.FailureCount | Should -Be 0
      $summary.SessionId | Should -Not -BeNullOrEmpty
    }

    It 'Should reset counters on re-initialization' {
      Write-FABLog -Level Error -Message 'test error' -NoConsole
      Write-FABLog -Level Warning -Message 'test warning' -NoConsole
      $before = Get-FABLogSummary
      $before.ErrorCount | Should -Be 1

      Initialize-FABLogging
      $after = Get-FABLogSummary
      $after.ErrorCount | Should -Be 0
      $after.WarningCount | Should -Be 0
    }
  }

  Context 'Write-FABLog' {
    It 'Should increment error count' {
      Write-FABLog -Level Error -Message 'test' -NoConsole
      $summary = Get-FABLogSummary
      $summary.ErrorCount | Should -Be 1
    }

    It 'Should increment warning count' {
      Write-FABLog -Level Warning -Message 'test' -NoConsole
      $summary = Get-FABLogSummary
      $summary.WarningCount | Should -Be 1
    }

    It 'Should increment success count' {
      Write-FABLog -Level Success -Message 'test' -NoConsole
      $summary = Get-FABLogSummary
      $summary.SuccessCount | Should -Be 1
    }
  }

  Context 'Start-FABOperation / Complete-FABOperation' {
    It 'Should track a successful operation' {
      $op = Start-FABOperation -OperationName 'TestOp'
      $op.Status | Should -Be 'Running'

      Complete-FABOperation -Operation $op -Success
      $op.Status | Should -Be 'Completed'
      $op.Duration | Should -Not -BeNullOrEmpty
    }

    It 'Should track a failed operation' {
      $op = Start-FABOperation -OperationName 'FailOp'
      Complete-FABOperation -Operation $op -ErrorMessage 'Something broke'
      $op.Status | Should -Be 'Failed'
      $op.Error | Should -Be 'Something broke'
    }

    It 'Should not double-count success' {
      Initialize-FABLogging
      $op = Start-FABOperation -OperationName 'CountTest'
      Complete-FABOperation -Operation $op -Success
      $summary = Get-FABLogSummary
      # SuccessCount should be 1 (from Write-FABLog), not 2
      $summary.SuccessCount | Should -Be 1
    }
  }
}

Describe 'Get-FABFallbackItemTypes' {
  It 'Should return a non-empty array of known types' {
    $types = Get-FABFallbackItemTypes
    $types | Should -Not -BeNullOrEmpty
    $types | Should -Contain 'Report'
    $types | Should -Contain 'SemanticModel'
    $types | Should -Contain 'Notebook'
  }
}

Describe 'Invoke-FABRateLimitedOperation' {
  It 'Should execute a simple operation successfully' {
    $result = Invoke-FABRateLimitedOperation -Operation { 42 } -OperationName 'SimpleTest'
    $result | Should -Be 42
  }

  It 'Should throw on non-retryable errors' {
    { Invoke-FABRateLimitedOperation -Operation { throw 'fatal error' } -OperationName 'FailTest' -MaxRetries 0 } | Should -Throw
  }
}
