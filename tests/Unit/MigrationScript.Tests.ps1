BeforeAll {
  $modulePath = Join-Path $PSScriptRoot '..' '..' 'modules' 'FabricArchiveBotCore.psm1'
  Import-Module $modulePath -Force
}

Describe 'ConvertTo-FabricArchiveBotV2 Migration' {
  BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..' '..' 'helpers' 'ConvertTo-FabricArchiveBotV2.ps1'
  }

  It 'Should convert a v1 config to a valid v2 config' {
    # Create a v1 config fixture
    $v1Config = [PSCustomObject]@{
      ServicePrincipal = [PSCustomObject]@{
        AppId     = 'test-app-id'
        AppSecret = 'test-secret'
        TenantId  = 'test-tenant-id'
      }
    }

    $v1Path = Join-Path $TestDrive 'Config.json'
    $v2Path = Join-Path $TestDrive 'FabricArchiveBot_Config.json'
    $v1Config | ConvertTo-Json -Depth 5 | Out-File $v1Path -Encoding UTF8

    # Run the migration script
    & $scriptPath -V1ConfigPath $v1Path -V2ConfigPath $v2Path

    # Validate the output
    Test-Path $v2Path | Should -BeTrue
    $v2Config = Get-Content $v2Path -Raw | ConvertFrom-Json

    $v2Config.Version | Should -Be '2.0'
    $v2Config.ServicePrincipal.AppId | Should -Be 'test-app-id'
    $v2Config.ServicePrincipal.AppSecret | Should -Be 'test-secret'
    $v2Config.ServicePrincipal.TenantId | Should -Be 'test-tenant-id'
  }

  It 'Should include all required v2 sections' {
    $v1Config = [PSCustomObject]@{
      ServicePrincipal = [PSCustomObject]@{
        AppId = 'id'; AppSecret = 'secret'; TenantId = 'tenant'
      }
    }

    $v1Path = Join-Path $TestDrive 'v1-sections.json'
    $v2Path = Join-Path $TestDrive 'v2-sections.json'
    $v1Config | ConvertTo-Json -Depth 5 | Out-File $v1Path -Encoding UTF8

    & $scriptPath -V1ConfigPath $v1Path -V2ConfigPath $v2Path

    $v2Config = Get-Content $v2Path -Raw | ConvertFrom-Json
    $v2Config.ExportSettings | Should -Not -BeNullOrEmpty
    $v2Config.FabricPSPBIPSettings | Should -Not -BeNullOrEmpty
    $v2Config.NotificationSettings | Should -Not -BeNullOrEmpty
    $v2Config.AdvancedFeatures | Should -Not -BeNullOrEmpty
  }

  It 'Should include rate limiting settings' {
    $v1Config = [PSCustomObject]@{
      ServicePrincipal = [PSCustomObject]@{
        AppId = 'id'; AppSecret = 'secret'; TenantId = 'tenant'
      }
    }

    $v1Path = Join-Path $TestDrive 'v1-rate.json'
    $v2Path = Join-Path $TestDrive 'v2-rate.json'
    $v1Config | ConvertTo-Json -Depth 5 | Out-File $v1Path -Encoding UTF8

    & $scriptPath -V1ConfigPath $v1Path -V2ConfigPath $v2Path

    $v2Config = Get-Content $v2Path -Raw | ConvertFrom-Json
    $v2Config.FabricPSPBIPSettings.RateLimitSettings | Should -Not -BeNullOrEmpty
    $v2Config.FabricPSPBIPSettings.RateLimitSettings.MaxRetries | Should -Be 3
    $v2Config.FabricPSPBIPSettings.RateLimitSettings.BackoffMultiplier | Should -Be 2
  }

  It 'Should produce a config loadable by Get-FABConfiguration' {
    $v1Config = [PSCustomObject]@{
      ServicePrincipal = [PSCustomObject]@{
        AppId = 'id'; AppSecret = 'secret'; TenantId = 'tenant'
      }
    }

    $v1Path = Join-Path $TestDrive 'v1-loadable.json'
    $v2Path = Join-Path $TestDrive 'v2-loadable.json'
    $v1Config | ConvertTo-Json -Depth 5 | Out-File $v1Path -Encoding UTF8

    & $scriptPath -V1ConfigPath $v1Path -V2ConfigPath $v2Path

    # Use the module's own config loader
    $loaded = Get-FABConfiguration -ConfigPath $v2Path
    $loaded | Should -Not -BeNullOrEmpty
    $loaded.Version | Should -Be '2.0'
  }

  It 'Should create backup when -BackupV1Config is specified' {
    $v1Config = [PSCustomObject]@{
      ServicePrincipal = [PSCustomObject]@{
        AppId = 'id'; AppSecret = 'secret'; TenantId = 'tenant'
      }
    }

    $v1Path = Join-Path $TestDrive 'Config-backup-test.json'
    $v2Path = Join-Path $TestDrive 'v2-backup-test.json'
    $v1Config | ConvertTo-Json -Depth 5 | Out-File $v1Path -Encoding UTF8

    & $scriptPath -V1ConfigPath $v1Path -V2ConfigPath $v2Path -BackupV1Config

    $backupPath = $v1Path.Replace('.json', '-backup.json')
    Test-Path $backupPath | Should -BeTrue
  }

  It 'Should fail gracefully with missing v1 config' {
    $v1Path = Join-Path $TestDrive 'nonexistent.json'
    $v2Path = Join-Path $TestDrive 'v2-missing.json'

    # The script calls exit 1 on missing config, so we need to catch it
    $result = & pwsh -NoProfile -Command "& '$scriptPath' -V1ConfigPath '$v1Path' -V2ConfigPath '$v2Path' 2>&1; `$LASTEXITCODE"
    # Last line should be the exit code
    $result[-1] | Should -Be 1
  }
}
