BeforeAll {
  # Import the module under test
  $ModulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot)) "modules\FabricArchiveBotCore.psm1"
  Import-Module $ModulePath -Force
    
  # Import test fixtures
  . (Join-Path $PSScriptRoot "..\fixtures\TestData.ps1")
    
  # Set up global test mocks for faster testing
  Set-FABGlobalTestMocks
    
  # Create test configuration
  $script:TestConfig = Get-Content (Join-Path $PSScriptRoot "..\fixtures\test-config.json") | ConvertFrom-Json
}

AfterAll {
  # Clean up
  Remove-Module FabricArchiveBotCore -ErrorAction SilentlyContinue
}

Describe "Get-FABSupportedItemTypes" {
  Context "When TOC service is available" {
    BeforeAll {
      # Mock Invoke-RestMethod to return test data
      Mock Invoke-RestMethod {
        return $script:TestFixtures.MockTocResponse
      }
    }
        
    It "Should return supported item types from TOC" {
      $result = Get-FABSupportedItemTypes
      $result | Should -Contain "Report"
      $result | Should -Contain "SemanticModel" 
      $result | Should -Contain "Notebook"
    }
        
    It "Should cache results when UseCache is specified" {
      $cacheFile = Join-Path $env:TEMP "FABSupportedItemTypes.json"
      Remove-Item $cacheFile -ErrorAction SilentlyContinue
            
      Get-FABSupportedItemTypes -UseCache
      $cacheFile | Should -Exist
    }
        
    It "Should use cached results when cache is valid" {
      # Create a mock cache file
      $cacheFile = Join-Path $env:TEMP "FABSupportedItemTypes.json"
      @("CachedType1", "CachedType2") | ConvertTo-Json | Out-File $cacheFile
            
      $result = Get-FABSupportedItemTypes -UseCache
      $result | Should -Contain "CachedType1"
      $result | Should -Contain "CachedType2"
    }
  }
    
  Context "When TOC service is unavailable" {
    BeforeAll {
      Mock Invoke-RestMethod {
        throw "Service unavailable"
      }
    }
        
    It "Should return fallback item types when service fails" {
      $result = Get-FABSupportedItemTypes
      $result | Should -Contain "Report"
      $result | Should -Contain "SemanticModel"
      $result | Should -Contain "Notebook"
    }
  }
}

Describe "Get-FABFallbackItemTypes" {
  It "Should return a valid array of item types" {
    $result = Get-FABFallbackItemTypes
    $result | Should -BeOfType [array]
    $result.Count | Should -BeGreaterThan 0
  }
    
  It "Should include known core item types" {
    $result = Get-FABFallbackItemTypes
    $result | Should -Contain "Report"
    $result | Should -Contain "SemanticModel"
    $result | Should -Contain "Notebook"
  }
}

Describe "Find-FABDefinitionEndpoints" {
  Context "When processing TOC nodes" {
    It "Should find definition endpoints in correct hierarchy" {
      $testNode = @{
        toc_title = "Report"
        children  = @(
          @{
            toc_title = "Items"
            children  = @(
              @{ toc_title = "Get Report Definition" }
            )
          }
        )
      }
            
      $result = Find-FABDefinitionEndpoints -Node $testNode
      $result | Should -Contain "Report"
    }
        
    It "Should ignore definition endpoints not in correct hierarchy" {
      $testNode = @{
        toc_title = "Get Something Definition"
        children  = @()
      }
            
      $result = Find-FABDefinitionEndpoints -Node $testNode -ParentPath @("Admin")
      $result | Should -BeNullOrEmpty
    }
  }
}

Describe "Invoke-FABWorkspaceFilter" {
  BeforeAll {
    $script:TestWorkspaces = $script:TestFixtures.MockWorkspaces
  }
    
  Context "When filtering by state" {
    It "Should filter active workspaces correctly" {
      $filter = "(state eq 'Active')"
      $result = Invoke-FABWorkspaceFilter -Workspaces $script:TestWorkspaces -Filter $filter
      $result.Count | Should -Be 2  # Only active workspaces
    }
        
    It "Should return empty array when filtering for inactive workspaces" {
      $filter = "(state eq 'Inactive')"
      $result = Invoke-FABWorkspaceFilter -Workspaces $script:TestWorkspaces -Filter $filter
      $result.Count | Should -Be 0  # API only returns active workspaces
    }
  }
    
  Context "When filtering by type" {
    It "Should filter by workspace type correctly" {
      $filter = "(type eq 'Workspace')"
      $result = Invoke-FABWorkspaceFilter -Workspaces $script:TestWorkspaces -Filter $filter
      $result.Count | Should -Be 3  # All test workspaces are type 'Workspace'
    }
  }
    
  Context "When filtering by name patterns" {
    It "Should filter using contains pattern" {
      $filter = "contains(name,'Test')"
      $result = Invoke-FABWorkspaceFilter -Workspaces $script:TestWorkspaces -Filter $filter
      $result.Count | Should -Be 2  # Two workspaces contain 'Test'
    }
        
    It "Should filter using startswith pattern" {
      $filter = "startswith(name,'Test Workspace')"
      $result = Invoke-FABWorkspaceFilter -Workspaces $script:TestWorkspaces -Filter $filter
      $result.Count | Should -Be 2  # Two workspaces start with 'Test Workspace'
    }
        
    It "Should filter using endswith pattern" {
      $filter = "endswith(name,'1')"
      $result = Invoke-FABWorkspaceFilter -Workspaces $script:TestWorkspaces -Filter $filter
      $result.Count | Should -Be 1  # One workspace ends with '1'
    }
  }
    
  Context "When filter parsing fails" {
    It "Should return all workspaces when filter is invalid" {
      $filter = "invalid filter syntax"
      $result = Invoke-FABWorkspaceFilter -Workspaces $script:TestWorkspaces -Filter $filter
      $result.Count | Should -Be $script:TestWorkspaces.Count
    }
  }
}

Describe "Get-FABOptimalThrottleLimit" {
  BeforeAll {
    # Mock Get-CimInstance to return consistent CPU count
    Mock Get-CimInstance {
      [PSCustomObject]@{ NumberOfLogicalProcessors = 8 }
    }
  }
    
  Context "When override is provided" {
    It "Should use runtime override when specified" {
      $result = Get-FABOptimalThrottleLimit -OverrideThrottleLimit 6 -Config $script:TestConfig
      $result | Should -Be 6
    }
  }
    
  Context "When config has throttle limit" {
    It "Should use config throttle limit when no override" {
      $result = Get-FABOptimalThrottleLimit -Config $script:TestConfig
      $result | Should -Be $script:TestConfig.FabricPSPBIPSettings.ThrottleLimit
    }
  }
    
  Context "When using auto-detection" {
    It "Should use logical processor count when no config" {
      $emptyConfig = [PSCustomObject]@{}
      $result = Get-FABOptimalThrottleLimit -Config $emptyConfig
      $result | Should -Be 8  # Mocked processor count
    }
        
    It "Should cap at maximum reasonable limit" {
      Mock Get-CimInstance {
        [PSCustomObject]@{ NumberOfLogicalProcessors = 32 }
      }
            
      $emptyConfig = [PSCustomObject]@{}
      $result = Get-FABOptimalThrottleLimit -Config $emptyConfig
      $result | Should -Be 12  # Capped at 12
    }
  }
}

Describe "Confirm-FABConfigurationCompatibility" {
  Context "When configuration is missing properties" {
    It "Should add missing ExportSettings" {
      $incompleteConfig = [PSCustomObject]@{
        Version = "2.0"
      }
            
      # Mock Get-FABSupportedItemTypes
      Mock Get-FABSupportedItemTypes {
        return @("Report", "SemanticModel", "Notebook")
      }
            
      $result = Confirm-FABConfigurationCompatibility -Config $incompleteConfig
      $result.PSObject.Properties['ExportSettings'] | Should -Not -BeNullOrEmpty
      $result.ExportSettings.PSObject.Properties['ItemTypes'] | Should -Not -BeNullOrEmpty
    }
        
    It "Should add missing WorkspaceFilter" {
      $incompleteConfig = [PSCustomObject]@{
        ExportSettings = [PSCustomObject]@{
          TargetFolder = ".\Test"
        }
      }
            
      Mock Get-FABSupportedItemTypes {
        return @("Report", "SemanticModel")
      }
            
      $result = Confirm-FABConfigurationCompatibility -Config $incompleteConfig
      $result.ExportSettings.PSObject.Properties['WorkspaceFilter'] | Should -Not -BeNullOrEmpty
    }
  }
    
  Context "When configuration has unsupported item types" {
    It "Should filter out unsupported item types" {
      $configWithUnsupported = [PSCustomObject]@{
        ExportSettings = [PSCustomObject]@{
          ItemTypes = @("Report", "UnsupportedType", "SemanticModel")
        }
      }
            
      Mock Get-FABSupportedItemTypes {
        return @("Report", "SemanticModel", "Notebook")
      }
            
      $result = Confirm-FABConfigurationCompatibility -Config $configWithUnsupported
      $result.ExportSettings.ItemTypes | Should -Contain "Report"
      $result.ExportSettings.ItemTypes | Should -Contain "SemanticModel"
      $result.ExportSettings.ItemTypes | Should -Not -Contain "UnsupportedType"
    }
  }
}

Describe "Invoke-FABRateLimitedOperation" {
  Context "When operation succeeds" {
    It "Should return operation result on success" {
      $operation = { return "Success" }
      $result = Invoke-FABRateLimitedOperation -Operation $operation -Config $script:TestConfig
      $result | Should -Be "Success"
    }
  }
    
  Context "When rate limiting occurs" {
    It "Should retry on rate limit error" {
      $script:callCount = 0
      $operation = {
        $script:callCount++
        if ($script:callCount -eq 1) {
          throw "Rate limit exceeded - 429 Too Many Requests"
        }
        return "Success after retry"
      }
            
      $result = Invoke-FABRateLimitedOperation -Operation $operation -Config $script:TestConfig -MaxRetries 1 -BaseDelaySeconds 1
      $result | Should -Be "Success after retry"
      $script:callCount | Should -Be 2
    }
        
    It "Should fail after max retries exceeded" {
      $operation = {
        throw "Rate limit exceeded - 429 Too Many Requests"
      }
            
      { Invoke-FABRateLimitedOperation -Operation $operation -Config $script:TestConfig -MaxRetries 1 -BaseDelaySeconds 1 } | 
      Should -Throw "*Rate limit exceeded*"
    }
  }
    
  Context "When transient errors occur" {
    It "Should retry on transient errors" {
      $script:callCount = 0
      $operation = {
        $script:callCount++
        if ($script:callCount -eq 1) {
          throw "Service temporarily unavailable - 503"
        }
        return "Success after transient error"
      }
            
      $result = Invoke-FABRateLimitedOperation -Operation $operation -Config $script:TestConfig -MaxRetries 1 -BaseDelaySeconds 1
      $result | Should -Be "Success after transient error"
    }
  }
    
  Context "When non-retryable errors occur" {
    It "Should not retry on non-retryable errors" {
      $operation = {
        throw "Authentication failed - 401"
      }
            
      { Invoke-FABRateLimitedOperation -Operation $operation -Config $script:TestConfig } | 
      Should -Throw "*Authentication failed*"
    }
  }
}
