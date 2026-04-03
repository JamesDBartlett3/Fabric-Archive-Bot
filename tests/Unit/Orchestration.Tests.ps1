BeforeAll {
  $modulePath = Join-Path $PSScriptRoot '..' '..' 'modules' 'FabricArchiveBotCore.psm1'
  Import-Module $modulePath -Force
}

Describe 'Export-FABFabricItemsAdvanced' {
  BeforeAll {
    Mock Initialize-FABFabricConnection { $true } -ModuleName FabricArchiveBotCore

    Mock Get-FABFabricWorkspaces {
      @(
        [PSCustomObject]@{ id = 'ws-001'; displayName = 'TestWorkspace'; type = 'Workspace' }
      )
    } -ModuleName FabricArchiveBotCore

    Mock Get-FABFabricWorkspaceById {
      [PSCustomObject]@{ id = 'ws-001'; displayName = 'TestWorkspace'; type = 'Workspace' }
    } -ModuleName FabricArchiveBotCore

    Mock Get-FABFabricItemsByWorkspace {
      @(
        [PSCustomObject]@{ id = 'item-1'; displayName = 'SalesReport'; type = 'Report' }
        [PSCustomObject]@{ id = 'item-2'; displayName = 'HRModel'; type = 'SemanticModel' }
        [PSCustomObject]@{ id = 'item-3'; displayName = 'ETLPipeline'; type = 'DataPipeline' }
      )
    } -ModuleName FabricArchiveBotCore

    # Mock Export-FabricItem — this is called through a scriptblock via &,
    # so we mock it globally (not module-scoped) to ensure it's available
    Mock Export-FabricItem { } -ModuleName FabricArchiveBotCore

    Mock Get-CimInstance {
      [PSCustomObject]@{ NumberOfLogicalProcessors = 4 }
    } -ModuleName FabricArchiveBotCore
  }

  It 'Should create workspace folder structure' {
    $targetFolder = Join-Path $TestDrive 'ExportTest'
    New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null

    $config = [PSCustomObject]@{
      Version        = '2.0'
      ServicePrincipal = [PSCustomObject]@{ AppId = ''; AppSecret = ''; TenantId = '' }
      ExportSettings = [PSCustomObject]@{
        TargetFolder    = $targetFolder
        RetentionDays   = 30
        WorkspaceFilter = "(state eq 'Active')"
        ItemTypes       = @('Report', 'SemanticModel', 'DataPipeline')
      }
    }

    Export-FABFabricItemsAdvanced -Config $config -TargetFolder $targetFolder -SerialProcessing

    $wsFolder = Join-Path $targetFolder 'TestWorkspace'
    Test-Path $wsFolder | Should -BeTrue
  }

  It 'Should create item-type folders for filtered items' {
    $targetFolder = Join-Path $TestDrive 'ItemFolders'
    New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null

    $config = [PSCustomObject]@{
      Version        = '2.0'
      ServicePrincipal = [PSCustomObject]@{ AppId = ''; AppSecret = ''; TenantId = '' }
      ExportSettings = [PSCustomObject]@{
        TargetFolder    = $targetFolder
        RetentionDays   = 30
        WorkspaceFilter = "(state eq 'Active')"
        ItemTypes       = @('Report')  # Only reports
      }
    }

    Export-FABFabricItemsAdvanced -Config $config -TargetFolder $targetFolder -SerialProcessing

    # Should have created a folder for the Report item only
    $wsFolder = Join-Path $targetFolder 'TestWorkspace'
    $reportFolder = Join-Path $wsFolder 'SalesReport.Report'
    Test-Path $reportFolder | Should -BeTrue

    # Should NOT have created folders for non-matching items
    $modelFolder = Join-Path $wsFolder 'HRModel.SemanticModel'
    Test-Path $modelFolder | Should -BeFalse
  }

  It 'Should apply ItemFilter when configured' {
    $targetFolder = Join-Path $TestDrive 'ItemFilterExport'
    New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null

    $config = [PSCustomObject]@{
      Version        = '2.0'
      ServicePrincipal = [PSCustomObject]@{ AppId = ''; AppSecret = ''; TenantId = '' }
      ExportSettings = [PSCustomObject]@{
        TargetFolder    = $targetFolder
        RetentionDays   = 30
        WorkspaceFilter = "(state eq 'Active')"
        ItemTypes       = @('Report', 'SemanticModel', 'DataPipeline')
        ItemFilter      = "contains(displayName,'Sales')"
      }
    }

    Export-FABFabricItemsAdvanced -Config $config -TargetFolder $targetFolder -SerialProcessing

    $wsFolder = Join-Path $targetFolder 'TestWorkspace'
    # Only SalesReport matches the filter
    Test-Path (Join-Path $wsFolder 'SalesReport.Report') | Should -BeTrue
    Test-Path (Join-Path $wsFolder 'HRModel.SemanticModel') | Should -BeFalse
    Test-Path (Join-Path $wsFolder 'ETLPipeline.DataPipeline') | Should -BeFalse
  }

  It 'Should handle workspace with no matching items gracefully' {
    Mock Get-FABFabricItemsByWorkspace {
      @(
        [PSCustomObject]@{ id = 'item-1'; displayName = 'Pipeline1'; type = 'DataPipeline' }
      )
    } -ModuleName FabricArchiveBotCore

    $targetFolder = Join-Path $TestDrive 'NoMatchExport'
    New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null

    $config = [PSCustomObject]@{
      Version        = '2.0'
      ServicePrincipal = [PSCustomObject]@{ AppId = ''; AppSecret = ''; TenantId = '' }
      ExportSettings = [PSCustomObject]@{
        TargetFolder    = $targetFolder
        RetentionDays   = 30
        WorkspaceFilter = "(state eq 'Active')"
        ItemTypes       = @('Report')  # No reports in workspace
      }
    }

    { Export-FABFabricItemsAdvanced -Config $config -TargetFolder $targetFolder -SerialProcessing } | Should -Not -Throw

    # Restore mock
    Mock Get-FABFabricItemsByWorkspace {
      @(
        [PSCustomObject]@{ id = 'item-1'; displayName = 'SalesReport'; type = 'Report' }
        [PSCustomObject]@{ id = 'item-2'; displayName = 'HRModel'; type = 'SemanticModel' }
        [PSCustomObject]@{ id = 'item-3'; displayName = 'ETLPipeline'; type = 'DataPipeline' }
      )
    } -ModuleName FabricArchiveBotCore
  }

  It 'Should generate metadata after export' {
    $targetFolder = Join-Path $TestDrive 'MetadataExport'
    New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null

    $config = [PSCustomObject]@{
      Version        = '2.0'
      ServicePrincipal = [PSCustomObject]@{ AppId = ''; AppSecret = ''; TenantId = '' }
      ExportSettings = [PSCustomObject]@{
        TargetFolder    = $targetFolder
        RetentionDays   = 30
        WorkspaceFilter = "(state eq 'Active')"
        ItemTypes       = @('Report', 'SemanticModel', 'DataPipeline')
      }
    }

    Export-FABFabricItemsAdvanced -Config $config -TargetFolder $targetFolder -SerialProcessing

    $metadataPath = Join-Path $targetFolder 'fabric-archive-metadata.json'
    Test-Path $metadataPath | Should -BeTrue

    $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
    $metadata.ExportSummary.TotalWorkspaces | Should -Be 1
    $metadata.ExportSummary.TotalItems | Should -Be 3
  }
}

Describe 'Start-FABFabricArchiveProcess' {
  BeforeAll {
    Mock Test-FABFabricPSPBIPAvailability { $true } -ModuleName FabricArchiveBotCore
    Mock Initialize-FABFabricConnection { $true } -ModuleName FabricArchiveBotCore
    Mock Get-FABSupportedItemTypes { @('Report', 'SemanticModel') } -ModuleName FabricArchiveBotCore

    Mock Get-FABFabricWorkspaces {
      @([PSCustomObject]@{ id = 'ws-001'; displayName = 'TestWS'; type = 'Workspace' })
    } -ModuleName FabricArchiveBotCore

    Mock Get-FABFabricWorkspaceById {
      [PSCustomObject]@{ id = 'ws-001'; displayName = 'TestWS'; type = 'Workspace' }
    } -ModuleName FabricArchiveBotCore

    Mock Get-FABFabricItemsByWorkspace {
      @([PSCustomObject]@{ id = 'i-1'; displayName = 'R1'; type = 'Report' })
    } -ModuleName FabricArchiveBotCore

    Mock Export-FabricItem { } -ModuleName FabricArchiveBotCore
    Mock Get-CimInstance { [PSCustomObject]@{ NumberOfLogicalProcessors = 4 } } -ModuleName FabricArchiveBotCore
  }

  It 'Should create date-stamped folder structure' {
    $targetFolder = Join-Path $TestDrive 'ArchiveProcess'
    New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null

    $config = [PSCustomObject]@{
      Version        = '2.0'
      ServicePrincipal = [PSCustomObject]@{ AppId = ''; AppSecret = ''; TenantId = '' }
      ExportSettings = [PSCustomObject]@{
        TargetFolder    = $targetFolder
        RetentionDays   = 30
        WorkspaceFilter = "(state eq 'Active')"
        ItemTypes       = @('Report')
      }
      NotificationSettings = [PSCustomObject]@{
        EnableNotifications = $false
      }
    }

    Start-FABFabricArchiveProcess -Config $config -SerialProcessing

    $today = Get-Date
    $dateFolder = Join-Path $targetFolder ("{0}\{1:D2}\{2:D2}" -f $today.Year, $today.Month, $today.Day)
    Test-Path $dateFolder | Should -BeTrue
  }

  It 'Should throw when FabricPS-PBIP is not available' {
    Mock Test-FABFabricPSPBIPAvailability { $false } -ModuleName FabricArchiveBotCore

    $config = [PSCustomObject]@{
      Version        = '2.0'
      ExportSettings = [PSCustomObject]@{
        TargetFolder    = $TestDrive
        RetentionDays   = 30
        WorkspaceFilter = "(state eq 'Active')"
        ItemTypes       = @('Report')
      }
    }

    { Start-FABFabricArchiveProcess -Config $config } | Should -Throw '*FabricPS-PBIP*'

    Mock Test-FABFabricPSPBIPAvailability { $true } -ModuleName FabricArchiveBotCore
  }

  It 'Should track operations in the logging subsystem' {
    $targetFolder = Join-Path $TestDrive 'OpTracking'
    New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null

    $config = [PSCustomObject]@{
      Version        = '2.0'
      ServicePrincipal = [PSCustomObject]@{ AppId = ''; AppSecret = ''; TenantId = '' }
      ExportSettings = [PSCustomObject]@{
        TargetFolder    = $targetFolder
        RetentionDays   = 30
        WorkspaceFilter = "(state eq 'Active')"
        ItemTypes       = @('Report')
      }
      NotificationSettings = [PSCustomObject]@{
        EnableNotifications = $false
      }
    }

    Start-FABFabricArchiveProcess -Config $config -SerialProcessing

    $summary = Get-FABLogSummary
    $summary.TotalOperations | Should -BeGreaterThan 0
  }
}
