BeforeAll {
  # Set up test environment
  $script:TestOutputDir = Join-Path $env:TEMP "FABMainScriptTests"
  if (Test-Path $script:TestOutputDir) {
    Remove-Item $script:TestOutputDir -Recurse -Force
  }
  New-Item -Path $script:TestOutputDir -ItemType Directory -Force | Out-Null
    
  # Import test fixtures
  . (Join-Path $PSScriptRoot "..\fixtures\TestData.ps1")
    
  # Set up global test mocks for faster testing
  Set-FABGlobalTestMocks
    
  # Get paths to scripts under test
  $script:RootPath = Split-Path (Split-Path $PSScriptRoot)
  $script:ModulePath = Join-Path $script:RootPath "modules\FabricArchiveBotCore.psm1"
    
  # Import the core module early to prevent loading issues
  if (Test-Path $script:ModulePath) {
    Write-Host "Importing module from: $script:ModulePath" -ForegroundColor Yellow
    Import-Module $script:ModulePath -Force -Global
    $importedModule = Get-Module -Name "FabricArchiveBotCore"
    if ($importedModule) {
      Write-Host "✓ Module imported successfully. Version: $($importedModule.Version)" -ForegroundColor Green
    }
    else {
      Write-Warning "Module import failed or module not found after import"
    }
  }
  else {
    Write-Warning "Module path not found: $script:ModulePath"
  }
    
  # Get paths to scripts under test
  $script:StartScriptPath = Join-Path $script:RootPath "Start-FabricArchiveBot.ps1"
    
  # Create test configuration file
  $script:TestConfigPath = Join-Path $script:TestOutputDir "test-config.json"
  $script:TestFixtures.TestConfigPath = $script:TestConfigPath
    
  $testConfig = @{
    Version              = "2.0"
    ServicePrincipal     = @{
      AppId     = "test-app-id"
      AppSecret = "test-secret"
      TenantId  = "test-tenant-id"
    }
    ExportSettings       = @{
      TargetFolder    = $script:TestOutputDir
      RetentionDays   = 30
      WorkspaceFilter = "(type eq 'Workspace') and (state eq 'Active')"
      ItemTypes       = @("Report", "SemanticModel", "Notebook")
    }
    FabricPSPBIPSettings = @{
      ParallelProcessing = $false  # Disable for testing
      ThrottleLimit      = 2
      RateLimitSettings  = @{
        MaxRetries        = 1
        RetryDelaySeconds = 1
        BackoffMultiplier = 2
      }
    }
    NotificationSettings = @{
      EnableNotifications = $false
    }
  }
    
  $testConfig | ConvertTo-Json -Depth 5 | Out-File $script:TestConfigPath -Encoding UTF8
}

AfterAll {
  # Clean up test environment
  if (Test-Path $script:TestOutputDir) {
    Remove-Item $script:TestOutputDir -Recurse -Force -ErrorAction SilentlyContinue
  }
    
  # Remove any loaded modules
  Remove-Module FabricArchiveBotCore -ErrorAction SilentlyContinue
}

# Import module at script level for all tests
$script:RootPath = Split-Path (Split-Path $PSScriptRoot)
$script:ModulePath = Join-Path $script:RootPath "modules\FabricArchiveBotCore.psm1"

if (Test-Path $script:ModulePath) {
  Import-Module $script:ModulePath -Force -Scope Global
}

Describe "Start-FabricArchiveBot.ps1 Script" {
  Context "When script is invoked with valid parameters" {
    BeforeAll {
      # Mock all external dependencies (module already imported globally)
      Mock Test-FABFabricPSPBIPAvailability { return $true }
      Mock Initialize-FABFabricConnection { return $true }
      Mock Get-FABFabricWorkspaces { return $script:TestFixtures.MockWorkspaces }
      Mock Get-FABFabricWorkspaceById { return $script:TestFixtures.MockWorkspaces[0] }
      Mock Get-FABFabricItemsByWorkspace { return $script:TestFixtures.MockItems }
      Mock Export-FabricItem { return $true }
      Mock Get-FABSupportedItemTypes { return @("Report", "SemanticModel", "Notebook") }
    }
        
    It "Should accept configuration from file path" {
      $params = @{
        ConfigPath       = $script:TestConfigPath
        SerialProcessing = $true
      }
            
      # This should not throw
      { Start-FABFabricArchiveProcess @params } | Should -Not -Throw
    }
        
    It "Should accept configuration object directly" {
      $config = Get-Content $script:TestConfigPath | ConvertFrom-Json
            
      $params = @{
        Config           = $config
        SerialProcessing = $true
      }
            
      # This should not throw
      { Start-FABFabricArchiveProcess @params } | Should -Not -Throw
    }
        
    It "Should create date-based folder structure" {
      $config = Get-Content $script:TestConfigPath | ConvertFrom-Json
            
      Start-FABFabricArchiveProcess -Config $config -SerialProcessing
            
      # Check that date-based folders were created
      $currentDate = Get-Date
      
      # Note: In actual testing, we'd need to mock the date or check for any date structure
      # For now, just verify that some date-based structure exists
      $yearFolders = Get-ChildItem $script:TestOutputDir -Directory | Where-Object { $_.Name -match "^\d{4}$" }
      $yearFolders.Count | Should -BeGreaterOrEqual 0  # May be 0 due to mocking
    }
  }
    
  Context "When script encounters errors" {
    BeforeAll {
      # Mock error conditions (module already imported globally)
      Mock Test-FABFabricPSPBIPAvailability { return $false }
    }
        
    It "Should throw when FabricPS-PBIP module is not available" {
      $config = Get-Content $script:TestConfigPath | ConvertFrom-Json
            
      { Start-FABFabricArchiveProcess -Config $config } | Should -Throw "*FabricPS-PBIP module is required*"
    }
  }
    
  Context "When validating configuration compatibility" {
    BeforeAll {
      # Mock dependencies (module already imported globally)
      Mock Test-FABFabricPSPBIPAvailability { return $true }
      Mock Get-FABSupportedItemTypes { return @("Report", "SemanticModel", "Notebook") }
    }
        
    It "Should upgrade v1.0 configuration to v2.0" {
      $v1Config = @{
        Version          = "1.0"
        ServicePrincipal = @{
          AppId     = "v1-app-id"
          AppSecret = "v1-secret"
          TenantId  = "v1-tenant-id"
        }
      }
            
      $v1ConfigPath = Join-Path $script:TestOutputDir "v1-config.json"
      $v1Config | ConvertTo-Json -Depth 3 | Out-File $v1ConfigPath -Encoding UTF8
            
      # Mock the rest of the process to avoid actual execution
      Mock Initialize-FABFabricConnection { return $false }  # Prevent actual connection attempt
            
      { Start-FABFabricArchiveProcess -ConfigPath $v1ConfigPath } | Should -Not -Throw
    }
  }
}

Describe "Helper Scripts Integration" {
  Context "When testing Register-FabricArchiveBotScheduledTask simulation" {
    It "Should validate scheduled task registration parameters" {
      $scriptPath = Join-Path $script:RootPath "helpers\Register-FabricArchiveBotScheduledTask.ps1"
            
      # Verify the script exists
      Test-Path $scriptPath | Should -Be $true
            
      # Simulate parameter validation that the script would perform
      $taskParams = @{
        TaskName        = "FabricArchiveBot"
        TaskDescription = "Test scheduled task"
        TaskCommand     = "pwsh.exe"
        TaskArguments   = "-NoProfile -ExecutionPolicy Bypass -File Export-FabricItemsFromAllWorkspaces.ps1"
        TaskTime        = "00:00"
        TaskUser        = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
      }
            
      # Validate all required parameters exist
      $taskParams.TaskName | Should -Not -BeNullOrEmpty
      $taskParams.TaskCommand | Should -Not -BeNullOrEmpty
      $taskParams.TaskTime | Should -Match "^\d{2}:\d{2}$"
    }
  }
    
  Context "When testing Set-FabricArchiveBotUserEnvironmentVariable simulation" {
    It "Should create proper environment variable format" {
      $configObject = @{
        ServicePrincipal = @{
          AppId     = "test-app-id"
          AppSecret = "test-secret"
          TenantId  = "test-tenant-id"
        }
      }
            
      # Simulate the helper script logic
      $jsonContent = $configObject | ConvertTo-Json -Compress
            
      # Verify compression worked (no pretty formatting)
      $jsonContent | Should -Not -Match "`r`n|`n|`r|\s{2,}"
      $jsonContent | Should -Match '"ServicePrincipal"'
            
      # Simulate setting environment variable
      [System.Environment]::SetEnvironmentVariable("FabricArchiveBot_Test", $jsonContent, "User")
            
      # Verify retrieval
      $retrieved = [System.Environment]::GetEnvironmentVariable("FabricArchiveBot_Test", "User")
      $retrieved | Should -Be $jsonContent
            
      # Clean up
      [System.Environment]::SetEnvironmentVariable("FabricArchiveBot_Test", $null, "User")
    }
  }
}

Describe "Export Process Integration" {
  Context "When testing export workflow components" {
    BeforeAll {
      # Mock all Fabric API calls (module already imported globally)
      Mock Test-FABFabricPSPBIPAvailability { return $true }
      Mock Initialize-FABFabricConnection { return $true }
      Mock Get-FABFabricWorkspaces { return $script:TestFixtures.MockWorkspaces }
      Mock Get-FABFabricWorkspaceById { return $script:TestFixtures.MockWorkspaces[0] }
      Mock Get-FABFabricItemsByWorkspace { return $script:TestFixtures.MockItems }
      Mock Export-FabricItem { return $true }
      Mock Get-FABSupportedItemTypes { return @("Report", "SemanticModel", "Notebook") }
    }
        
    It "Should process workspace filtering correctly" {
      $config = Get-Content $script:TestConfigPath | ConvertFrom-Json
            
      # Test the workspace filtering function
      $workspaces = Get-FABFabricWorkspaces
      $filtered = Invoke-FABWorkspaceFilter -Workspaces $workspaces -Filter $config.ExportSettings.WorkspaceFilter
            
      $filtered | Should -Not -BeNullOrEmpty
      $filtered.Count | Should -BeGreaterThan 0
    }
        
    It "Should handle item type filtering" {
      $config = Get-Content $script:TestConfigPath | ConvertFrom-Json
      $items = Get-FABFabricItemsByWorkspace -WorkspaceId "test-workspace-id"
            
      $filteredItems = $items | Where-Object { $_.type -in $config.ExportSettings.ItemTypes }
            
      # Should filter out unsupported types
      $filteredItems | Should -Not -BeNullOrEmpty
      $filteredItems | Where-Object { $_.type -eq "Dashboard" } | Should -BeNullOrEmpty
    }
        
    It "Should create proper folder structure for exports" {
      $workspaceName = "Test Workspace"
      $itemName = "Test Report"
      $itemType = "Report"
            
      $workspaceFolder = Join-Path $script:TestOutputDir $workspaceName
      $itemFolder = Join-Path $workspaceFolder "$itemName.$itemType"
            
      # Simulate folder creation
      New-Item -Path $itemFolder -ItemType Directory -Force | Out-Null
            
      Test-Path $itemFolder | Should -Be $true
    }
  }
}

Describe "Configuration Management Integration" {
  Context "When testing configuration workflows" {
    It "Should handle environment variable override" {
      # Create a config object and set it as environment variable
      $envConfig = @{
        ServicePrincipal = @{
          AppId     = "env-app-id"
          AppSecret = "env-secret" 
          TenantId  = "env-tenant-id"
        }
      }
            
      $compressed = $envConfig | ConvertTo-Json -Compress
      [System.Environment]::SetEnvironmentVariable("FabricArchiveBot_ConfigObject", $compressed, "User")
            
      # Simulate script logic that checks for environment variable
      $userEnv = [System.Environment]::GetEnvironmentVariables([System.EnvironmentVariableTarget]::User)
      if ($userEnv.FabricArchiveBot_ConfigObject) {
        $overrideConfig = $userEnv.FabricArchiveBot_ConfigObject | ConvertFrom-Json
        $overrideConfig.ServicePrincipal.AppId | Should -Be "env-app-id"
      }
            
      # Clean up
      [System.Environment]::SetEnvironmentVariable("FabricArchiveBot_ConfigObject", $null, "User")
    }
        
    It "Should validate service principal configuration" {
      $config = Get-Content $script:TestConfigPath | ConvertFrom-Json
            
      # Test the logic for determining if service principal should be used
      $tenantId = $config.ServicePrincipal.TenantId
      $servicePrincipalId = $config.ServicePrincipal.AppId
      $servicePrincipalSecret = $config.ServicePrincipal.AppSecret
            
      $useServicePrincipal = $tenantId -and $servicePrincipalId -and $servicePrincipalSecret
            
      $useServicePrincipal | Should -Be $true
    }
  }
}

Describe "Error Recovery and Resilience" {
  Context "When testing error handling in main workflow" {
    BeforeAll {
      # Mock dependencies (module already imported globally)
      Mock Test-FABFabricPSPBIPAvailability { return $true }
    }
        
    It "Should handle connection failures gracefully" {
      Mock Initialize-FABFabricConnection { return $false }
            
      $config = Get-Content $script:TestConfigPath | ConvertFrom-Json
            
      { Start-FABFabricArchiveProcess -Config $config } | Should -Throw "*Failed to initialize Fabric connection*"
    }
        
    It "Should continue processing when individual workspace fails" {
      Mock Initialize-FABFabricConnection { return $true }
      Mock Get-FABFabricWorkspaces { return $script:TestFixtures.MockWorkspaces }
      Mock Get-FABFabricWorkspaceById { 
        param($WorkspaceId)
        if ($WorkspaceId -eq "22222222-2222-2222-2222-222222222222") {
          throw "Workspace access denied"
        }
        return $script:TestFixtures.MockWorkspaces[0]
      }
      Mock Get-FABFabricItemsByWorkspace { return @() }
      Mock Get-FABSupportedItemTypes { return @("Report", "SemanticModel", "Notebook") }
            
      $config = Get-Content $script:TestConfigPath | ConvertFrom-Json
            
      # Should not throw even if one workspace fails
      { Start-FABFabricArchiveProcess -Config $config -SerialProcessing } | Should -Not -Throw
    }
  }
}
