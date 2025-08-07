# Test Data Fixtures for Fabric Archive Bot

# Global test configuration for faster testing
$script:FastTestConfig = @{
  RateLimitSettings = @{
    MaxRetries        = 1
    RetryDelaySeconds = 1
    BackoffMultiplier = 2
  }
}

# Mock workspace data
$script:MockWorkspaces = @(
  @{
    id          = "11111111-1111-1111-1111-111111111111"
    displayName = "Test Workspace 1"
    type        = "Workspace"
    state       = "Active"
  },
  @{
    id          = "22222222-2222-2222-2222-222222222222"
    displayName = "Test Workspace 2"
    type        = "Workspace"
    state       = "Active"
  },
  @{
    id          = "33333333-3333-3333-3333-333333333333"
    displayName = "Inactive Workspace"
    type        = "Workspace"
    state       = "Inactive"
  }
)

# Mock item data
$script:MockItems = @(
  @{
    id          = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    displayName = "Test Report 1"
    type        = "Report"
    workspaceId = "11111111-1111-1111-1111-111111111111"
  },
  @{
    id          = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
    displayName = "Test Semantic Model 1"
    type        = "SemanticModel"
    workspaceId = "11111111-1111-1111-1111-111111111111"
  },
  @{
    id          = "cccccccc-cccc-cccc-cccc-cccccccccccc"
    displayName = "Test Notebook 1"
    type        = "Notebook"
    workspaceId = "22222222-2222-2222-2222-222222222222"
  },
  @{
    id          = "dddddddd-dddd-dddd-dddd-dddddddddddd"
    displayName = "Test Unsupported Item"
    type        = "Dashboard"
    workspaceId = "22222222-2222-2222-2222-222222222222"
  }
)

# Mock supported item types from Microsoft Learn TOC
$script:MockTocResponse = @{
  items = @(
    @{
      toc_title = "Core"
      children  = @(
        @{
          toc_title = "Items"
          children  = @(
            @{ toc_title = "Get Report Definition" },
            @{ toc_title = "Get SemanticModel Definition" }
          )
        }
      )
    },
    @{
      toc_title = "Data Engineering"
      children  = @(
        @{
          toc_title = "Notebook"
          children  = @(
            @{
              toc_title = "Items"
              children  = @(
                @{ toc_title = "Get Notebook Definition" }
              )
            }
          )
        }
      )
    }
  )
}

# Export fixtures for use in tests
$script:TestFixtures = @{
  MockWorkspaces  = $script:MockWorkspaces
  MockItems       = $script:MockItems
  MockTocResponse = $script:MockTocResponse
  TestConfigPath  = Join-Path $PSScriptRoot "test-config.json"
  FastTestConfig  = $script:FastTestConfig
}

# Global mock for Start-Sleep to speed up all tests
function Set-FABGlobalTestMocks {
  # Mock Start-Sleep globally to speed up rate limiting tests
  Mock Start-Sleep {} -ModuleName FabricArchiveBotCore
  Mock Start-Sleep {}
}
