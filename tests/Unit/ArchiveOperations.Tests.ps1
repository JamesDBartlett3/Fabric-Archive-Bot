BeforeAll {
  $modulePath = Join-Path $PSScriptRoot '..' '..' 'modules' 'FabricArchiveBotCore.psm1'
  Import-Module $modulePath -Force
}

Describe 'Remove-FABOldArchives' {
  BeforeEach {
    Initialize-FABLogging
  }

  It 'Should remove folders older than retention period' {
    # Create a directory structure in TestDrive
    $targetFolder = Join-Path $TestDrive 'Archives'
    New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null

    # Create an "old" folder and backdate it
    $oldFolder = Join-Path $targetFolder 'OldWorkspace'
    New-Item -Path $oldFolder -ItemType Directory -Force | Out-Null
    $oldFile = Join-Path $oldFolder 'data.json'
    '{}' | Out-File $oldFile
    # Set creation time to 60 days ago
    (Get-Item $oldFolder).CreationTime = (Get-Date).AddDays(-60)

    # Create a "recent" folder
    $recentFolder = Join-Path $targetFolder 'RecentWorkspace'
    New-Item -Path $recentFolder -ItemType Directory -Force | Out-Null
    '{}' | Out-File (Join-Path $recentFolder 'data.json')

    $config = [PSCustomObject]@{
      ExportSettings = [PSCustomObject]@{
        TargetFolder  = $targetFolder
        RetentionDays = 30
      }
    }

    Remove-FABOldArchives -Config $config

    Test-Path $oldFolder | Should -BeFalse
    Test-Path $recentFolder | Should -BeTrue
  }

  It 'Should handle empty target folder gracefully' {
    $targetFolder = Join-Path $TestDrive 'EmptyArchives'
    New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null

    $config = [PSCustomObject]@{
      ExportSettings = [PSCustomObject]@{
        TargetFolder  = $targetFolder
        RetentionDays = 30
      }
    }

    { Remove-FABOldArchives -Config $config } | Should -Not -Throw
  }

  It 'Should not remove the target folder itself' {
    $targetFolder = Join-Path $TestDrive 'KeepRoot'
    New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null
    (Get-Item $targetFolder).CreationTime = (Get-Date).AddDays(-60)

    $config = [PSCustomObject]@{
      ExportSettings = [PSCustomObject]@{
        TargetFolder  = $targetFolder
        RetentionDays = 30
      }
    }

    Remove-FABOldArchives -Config $config
    Test-Path $targetFolder | Should -BeTrue
  }
}

Describe 'Export-FABWorkspaceMetadata' {
  It 'Should create a metadata JSON file' {
    $targetFolder = Join-Path $TestDrive 'MetadataTest'
    New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null

    $workspaceData = @(
      [PSCustomObject]@{
        WorkspaceId     = 'ws-001'
        WorkspaceInfo   = [PSCustomObject]@{ displayName = 'TestWorkspace'; id = 'ws-001' }
        WorkspaceFolder = $targetFolder
        Items           = @(
          [PSCustomObject]@{ id = 'item-1'; displayName = 'Report1'; type = 'Report' }
          [PSCustomObject]@{ id = 'item-2'; displayName = 'Model1'; type = 'SemanticModel' }
        )
        FilteredItems   = @(
          [PSCustomObject]@{ id = 'item-1'; displayName = 'Report1'; type = 'Report' }
          [PSCustomObject]@{ id = 'item-2'; displayName = 'Model1'; type = 'SemanticModel' }
        )
      }
    )

    $config = [PSCustomObject]@{
      ExportSettings = [PSCustomObject]@{
        ItemTypes       = @('Report', 'SemanticModel')
        WorkspaceFilter = "(state eq 'Active')"
      }
    }

    Export-FABWorkspaceMetadata -AllWorkspaceData $workspaceData -TargetFolder $targetFolder -Config $config

    $metadataPath = Join-Path $targetFolder 'fabric-archive-metadata.json'
    Test-Path $metadataPath | Should -BeTrue

    $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
    $metadata.ExportSummary.TotalWorkspaces | Should -Be 1
    $metadata.ExportSummary.TotalItems | Should -Be 2
  }

  It 'Should handle multiple workspaces' {
    $targetFolder = Join-Path $TestDrive 'MultiWS'
    New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null

    $workspaceData = @(
      [PSCustomObject]@{
        WorkspaceId     = 'ws-001'
        WorkspaceInfo   = [PSCustomObject]@{ displayName = 'WS1'; id = 'ws-001' }
        WorkspaceFolder = $targetFolder
        Items           = @([PSCustomObject]@{ id = '1'; displayName = 'R1'; type = 'Report' })
        FilteredItems   = @([PSCustomObject]@{ id = '1'; displayName = 'R1'; type = 'Report' })
      }
      [PSCustomObject]@{
        WorkspaceId     = 'ws-002'
        WorkspaceInfo   = [PSCustomObject]@{ displayName = 'WS2'; id = 'ws-002' }
        WorkspaceFolder = $targetFolder
        Items           = @([PSCustomObject]@{ id = '2'; displayName = 'R2'; type = 'Report' })
        FilteredItems   = @([PSCustomObject]@{ id = '2'; displayName = 'R2'; type = 'Report' })
      }
    )

    $config = [PSCustomObject]@{
      ExportSettings = [PSCustomObject]@{
        ItemTypes       = @('Report')
        WorkspaceFilter = "(state eq 'Active')"
      }
    }

    Export-FABWorkspaceMetadata -AllWorkspaceData $workspaceData -TargetFolder $targetFolder -Config $config

    $metadata = Get-Content (Join-Path $targetFolder 'fabric-archive-metadata.json') -Raw | ConvertFrom-Json
    $metadata.ExportSummary.TotalWorkspaces | Should -Be 2
    $metadata.ExportSummary.TotalItems | Should -Be 2
  }

  It 'Should handle empty workspace data' {
    $targetFolder = Join-Path $TestDrive 'EmptyWS'
    New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null

    $config = [PSCustomObject]@{
      ExportSettings = [PSCustomObject]@{
        ItemTypes       = @('Report')
        WorkspaceFilter = "(state eq 'Active')"
      }
    }

    Export-FABWorkspaceMetadata -AllWorkspaceData @() -TargetFolder $targetFolder -Config $config

    $metadata = Get-Content (Join-Path $targetFolder 'fabric-archive-metadata.json') -Raw | ConvertFrom-Json
    $metadata.ExportSummary.TotalWorkspaces | Should -Be 0
    # Measure-Object -Sum on empty input returns $null, so TotalItems may be $null or 0
    ($metadata.ExportSummary.TotalItems -as [int]) | Should -Be 0
  }
}

Describe 'Send-FABArchiveNotification' {
  BeforeEach {
    Initialize-FABLogging
  }

  It 'Should not throw when generating a notification' {
    $archiveFolder = Join-Path $TestDrive 'NotifyTest'
    New-Item -Path $archiveFolder -ItemType Directory -Force | Out-Null
    '{}' | Out-File (Join-Path $archiveFolder 'test.json')

    $config = [PSCustomObject]@{
      NotificationSettings = [PSCustomObject]@{
        EnableNotifications = $false
      }
    }

    { Send-FABArchiveNotification -Config $config -ArchiveFolder $archiveFolder } | Should -Not -Throw
  }

  It 'Should handle empty archive folder' {
    $archiveFolder = Join-Path $TestDrive 'EmptyNotify'
    New-Item -Path $archiveFolder -ItemType Directory -Force | Out-Null

    $config = [PSCustomObject]@{
      NotificationSettings = [PSCustomObject]@{
        EnableNotifications = $false
      }
    }

    { Send-FABArchiveNotification -Config $config -ArchiveFolder $archiveFolder } | Should -Not -Throw
  }
}
