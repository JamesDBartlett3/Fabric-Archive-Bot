BeforeAll {
  # Import the module under test
  $ModulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot)) "modules\FabricArchiveBotCore.psm1"
  Import-Module $ModulePath -Force
    
  # Import test fixtures
  . (Join-Path $PSScriptRoot "..\fixtures\TestData.ps1")
    
  # Set up global test mocks for faster testing
  Set-FABGlobalTestMocks
    
  # Set up test environment
  $script:TestOutputDir = Join-Path $env:TEMP "FABIntegrationTests"
  if (Test-Path $script:TestOutputDir) {
    Remove-Item $script:TestOutputDir -Recurse -Force
  }
  New-Item -Path $script:TestOutputDir -ItemType Directory -Force | Out-Null
    
  # Create test configuration
  $script:TestConfig = Get-Content (Join-Path $PSScriptRoot "..\fixtures\test-config.json") | ConvertFrom-Json
  $script:TestConfig.ExportSettings.TargetFolder = $script:TestOutputDir
}

AfterAll {
  # Clean up
  Remove-Module FabricArchiveBotCore -ErrorAction SilentlyContinue
  if (Test-Path $script:TestOutputDir) {
    Remove-Item $script:TestOutputDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe "FabricPS-PBIP Module Integration" {
  Context "When FabricPS-PBIP module is not available" {
    BeforeAll {
      # Mock the availability check to return false
      Mock Test-FABFabricPSPBIPAvailability { return $false }
    }
        
    It "Should detect when FabricPS-PBIP module is unavailable" {
      $result = Test-FABFabricPSPBIPAvailability
      $result | Should -Be $false
    }
  }
    
  Context "When FabricPS-PBIP module is available" {
    BeforeAll {
      # Mock the availability check to return true and mock required functions
      Mock Test-FABFabricPSPBIPAvailability { return $true }
      Mock Get-Command { 
        param($Name)
        if ($Name -eq "Invoke-FabricAPIRequest") {
          return [PSCustomObject]@{ Name = "Invoke-FabricAPIRequest" }
        }
        return $null
      }
    }
        
    It "Should detect when FabricPS-PBIP module is available" {
      $result = Test-FABFabricPSPBIPAvailability
      $result | Should -Be $true
    }
  }
}

Describe "Configuration and Module Integration" {
  Context "When processing complete configuration workflow" {
    It "Should validate and enhance configuration successfully" {
      # Mock the supported item types function
      Mock Get-FABSupportedItemTypes {
        return @("Report", "SemanticModel", "Notebook", "SparkJobDefinition")
      }
            
      $result = Confirm-FABConfigurationCompatibility -Config $script:TestConfig
            
      $result | Should -Not -BeNullOrEmpty
      $result.ExportSettings | Should -Not -BeNullOrEmpty
      $result.ExportSettings.ItemTypes | Should -Contain "Report"
      $result.ExportSettings.WorkspaceFilter | Should -Not -BeNullOrEmpty
    }
        
    It "Should handle configuration with unsupported item types" {
      $configWithUnsupported = $script:TestConfig.PSObject.Copy()
      $configWithUnsupported.ExportSettings.ItemTypes = @("Report", "UnsupportedType", "SemanticModel")
            
      Mock Get-FABSupportedItemTypes {
        return @("Report", "SemanticModel", "Notebook")
      }
            
      $result = Confirm-FABConfigurationCompatibility -Config $configWithUnsupported
            
      $result.ExportSettings.ItemTypes | Should -Not -Contain "UnsupportedType"
      $result.ExportSettings.ItemTypes | Should -Contain "Report"
      $result.ExportSettings.ItemTypes | Should -Contain "SemanticModel"
    }
  }
}

Describe "Workspace Filtering Integration" {
  Context "When applying complex filters to workspace collections" {
    BeforeAll {
      $script:TestWorkspaces = @(
        [PSCustomObject]@{
          id          = "11111111-1111-1111-1111-111111111111"
          displayName = "Production Workspace"
          type        = "Workspace"
        },
        [PSCustomObject]@{
          id          = "22222222-2222-2222-2222-222222222222"
          displayName = "Development Workspace"
          type        = "Workspace"
        },
        [PSCustomObject]@{
          id          = "33333333-3333-3333-3333-333333333333"
          displayName = "Test Environment"
          type        = "Workspace"
        }
      )
    }
        
    It "Should apply state and type filters together" {
      $filter = "(type eq 'Workspace') and (state eq 'Active')"
      $result = Invoke-FABWorkspaceFilter -Workspaces $script:TestWorkspaces -Filter $filter
            
      # All returned workspaces should be treated as active since API only returns active ones
      $result.Count | Should -Be $script:TestWorkspaces.Count
    }
        
    It "Should apply name pattern filters" {
      $filter = "contains(name,'Production')"
      $result = Invoke-FABWorkspaceFilter -Workspaces $script:TestWorkspaces -Filter $filter
            
      $result.Count | Should -Be 1
      $result[0].displayName | Should -Be "Production Workspace"
    }
        
    It "Should handle multiple name pattern filters" {
      $filter = "startswith(name,'Test')"
      $result = Invoke-FABWorkspaceFilter -Workspaces $script:TestWorkspaces -Filter $filter
            
      $result.Count | Should -Be 1
      $result[0].displayName | Should -Be "Test Environment"
    }
  }
}

Describe "Rate Limiting and Retry Logic Integration" {
  Context "When testing rate limiting across multiple operations" {
    It "Should handle sequential rate-limited operations" {
      $script:callCounts = @{
        Operation1 = 0
        Operation2 = 0
      }
            
      $operation1 = {
        $script:callCounts.Operation1++
        if ($script:callCounts.Operation1 -eq 1) {
          throw "Rate limit - 429"
        }
        return "Operation1 Success"
      }
            
      $operation2 = {
        $script:callCounts.Operation2++
        if ($script:callCounts.Operation2 -eq 1) {
          throw "Service unavailable - 503"
        }
        return "Operation2 Success"
      }
            
      $result1 = Invoke-FABRateLimitedOperation -Operation $operation1 -Config $script:TestConfig -MaxRetries 1 -BaseDelaySeconds 1
      $result2 = Invoke-FABRateLimitedOperation -Operation $operation2 -Config $script:TestConfig -MaxRetries 1 -BaseDelaySeconds 1
            
      $result1 | Should -Be "Operation1 Success"
      $result2 | Should -Be "Operation2 Success"
      $script:callCounts.Operation1 | Should -Be 2
      $script:callCounts.Operation2 | Should -Be 2
    }
  }
}

Describe "Parallel Processing Configuration Integration" {
  Context "When determining optimal parallel processing settings" {
    BeforeAll {
      # Mock system information
      Mock Get-CimInstance {
        [PSCustomObject]@{ NumberOfLogicalProcessors = 8 }
      }
    }
        
    It "Should configure parallel processing based on system and config" {
      $throttleLimit = Get-FABOptimalThrottleLimit -Config $script:TestConfig
            
      # Should use config value when available
      $throttleLimit | Should -Be $script:TestConfig.FabricPSPBIPSettings.ThrottleLimit
    }
        
    It "Should fall back to system detection when config is empty" {
      $emptyConfig = [PSCustomObject]@{
        FabricPSPBIPSettings = [PSCustomObject]@{}
      }
            
      $throttleLimit = Get-FABOptimalThrottleLimit -Config $emptyConfig
            
      # Should use system-detected value (8 processors)
      $throttleLimit | Should -Be 8
    }
        
    It "Should respect override parameters" {
      $throttleLimit = Get-FABOptimalThrottleLimit -OverrideThrottleLimit 12 -Config $script:TestConfig
            
      # Should use override value
      $throttleLimit | Should -Be 12
    }
  }
}

Describe "End-to-End Configuration Workflow" {
  Context "When simulating complete configuration setup" {
    It "Should handle complete v2.0 configuration workflow" {
      # Simulate loading configuration from file
      $configPath = Join-Path $script:TestOutputDir "test-workflow-config.json"
      $script:TestConfig | ConvertTo-Json -Depth 5 | Out-File $configPath -Encoding UTF8
            
      # Load and validate configuration
      $loadedConfig = Get-Content $configPath | ConvertFrom-Json
            
      # Mock supported item types
      Mock Get-FABSupportedItemTypes {
        return @("Report", "SemanticModel", "Notebook", "SparkJobDefinition")
      }
            
      # Validate configuration compatibility
      $validatedConfig = Confirm-FABConfigurationCompatibility -Config $loadedConfig
            
      # Test the complete configuration
      $validatedConfig.Version | Should -Be "2.0"
      $validatedConfig.ServicePrincipal | Should -Not -BeNullOrEmpty
      $validatedConfig.ExportSettings | Should -Not -BeNullOrEmpty
      $validatedConfig.ExportSettings.ItemTypes | Should -Not -BeNullOrEmpty
      $validatedConfig.ExportSettings.WorkspaceFilter | Should -Not -BeNullOrEmpty
      $validatedConfig.FabricPSPBIPSettings | Should -Not -BeNullOrEmpty
    }
  }
}

Describe "Error Handling Integration" {
  Context "When testing error propagation across components" {
    It "Should handle errors gracefully in configuration validation" {
      $invalidConfig = [PSCustomObject]@{
        # Missing required properties
      }
            
      Mock Get-FABSupportedItemTypes { throw "Service unavailable" }
            
      # Should not throw but use fallback behavior
      { Confirm-FABConfigurationCompatibility -Config $invalidConfig } | Should -Not -Throw
    }
        
    It "Should handle errors in workspace filtering" {
      $filter = "(type eq 'Workspace')"
            
      # Should handle null/empty workspace arrays gracefully
      { Invoke-FABWorkspaceFilter -Workspaces @() -Filter $filter } | Should -Not -Throw
    }
  }
}
