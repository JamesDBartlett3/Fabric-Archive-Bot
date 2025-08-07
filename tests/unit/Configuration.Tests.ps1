BeforeAll {
    # Import test fixtures
    . (Join-Path $PSScriptRoot "..\fixtures\TestData.ps1")
    
    # Set up test environment
    $script:TestOutputDir = Join-Path $env:TEMP "FABTests"
    $script:TestConfigPath = Join-Path $script:TestOutputDir "test-config.json"
    
    # Create test directory
    if (-not (Test-Path $script:TestOutputDir)) {
        New-Item -Path $script:TestOutputDir -ItemType Directory -Force
    }
}

AfterAll {
    # Clean up test environment
    if (Test-Path $script:TestOutputDir) {
        Remove-Item $script:TestOutputDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Clean up any test environment variables
    [System.Environment]::SetEnvironmentVariable("FabricArchiveBot_ConfigObject_Test", $null, "User")
}

Describe "Configuration Management" {
    Context "When loading configuration from JSON file" {
        BeforeEach {
            # Create a test config file
            $testConfig = @{
                Version = "2.0"
                ServicePrincipal = @{
                    AppId = "test-app-id"
                    AppSecret = "test-secret"
                    TenantId = "test-tenant-id"
                }
                ExportSettings = @{
                    TargetFolder = ".\TestOutput"
                    RetentionDays = 30
                    WorkspaceFilter = "(type eq 'Workspace')"
                    ItemTypes = @("Report", "SemanticModel")
                }
            }
            
            $testConfig | ConvertTo-Json -Depth 5 | Out-File $script:TestConfigPath -Encoding UTF8
        }
        
        It "Should load valid JSON configuration" {
            $config = Get-Content $script:TestConfigPath | ConvertFrom-Json
            $config.Version | Should -Be "2.0"
            $config.ServicePrincipal.AppId | Should -Be "test-app-id"
            $config.ExportSettings.RetentionDays | Should -Be 30
        }
        
        It "Should handle malformed JSON gracefully" {
            "{ invalid json" | Out-File $script:TestConfigPath -Encoding UTF8
            
            { Get-Content $script:TestConfigPath | ConvertFrom-Json } | Should -Throw
        }
    }
    
    Context "When using environment variables" {
        It "Should set and retrieve environment variable configuration" {
            $configObject = @{
                ServicePrincipal = @{
                    AppId = "env-test-app-id"
                    TenantId = "env-test-tenant-id"
                }
            }
            
            $compressed = $configObject | ConvertTo-Json -Compress
            [System.Environment]::SetEnvironmentVariable("FabricArchiveBot_ConfigObject_Test", $compressed, "User")
            
            $retrieved = [System.Environment]::GetEnvironmentVariable("FabricArchiveBot_ConfigObject_Test", "User")
            $retrieved | Should -Not -BeNullOrEmpty
            
            $parsedConfig = $retrieved | ConvertFrom-Json
            $parsedConfig.ServicePrincipal.AppId | Should -Be "env-test-app-id"
        }
    }
}

Describe "Helper Script Functions" {
    Context "Set-FabricArchiveBotUserEnvironmentVariable simulation" {
        It "Should create compressed JSON from configuration object" {
            $testConfig = @{
                ServicePrincipal = @{
                    AppId = "helper-test-app-id"
                    AppSecret = "helper-test-secret"
                    TenantId = "helper-test-tenant-id"
                }
            }
            
            # Simulate the helper script behavior
            $jsonContent = $testConfig | ConvertTo-Json -Compress
            $jsonContent | Should -Not -Match "`r`n|`n|`r|\s{2,}"  # Should not contain newlines or multiple spaces
            $jsonContent | Should -Match '"ServicePrincipal"'
        }
    }
    
    Context "Register-FabricArchiveBotScheduledTask simulation" {
        It "Should validate task parameters" {
            $taskParams = @{
                TaskName = "FabricArchiveBot"
                TaskDescription = "Test task description"
                TaskCommand = "pwsh.exe"
                TaskArguments = "-NoProfile -ExecutionPolicy Bypass"
                TaskTime = "00:00"
            }
            
            # Validate required parameters
            $taskParams.TaskName | Should -Not -BeNullOrEmpty
            $taskParams.TaskCommand | Should -Not -BeNullOrEmpty
            $taskParams.TaskTime | Should -Match "^\d{2}:\d{2}$"  # HH:MM format
        }
    }
    
    Context "ConvertTo-FabricArchiveBotV2 simulation" {
        It "Should handle v1.0 to v2.0 configuration migration" {
            $v1Config = [PSCustomObject]@{
                Version = "1.0"
                ServicePrincipal = @{
                    AppId = "v1-app-id"
                    AppSecret = "v1-secret"
                    TenantId = "v1-tenant-id"
                }
                # Missing v2.0 properties
            }
            
            # Simulate migration logic
            $v2Config = [PSCustomObject]@{
                Version = "2.0"
                ServicePrincipal = $v1Config.ServicePrincipal
                ExportSettings = [PSCustomObject]@{
                    TargetFolder = ".\Workspaces"  # Default value
                    RetentionDays = 30
                    WorkspaceFilter = "(type eq 'Workspace') and (state eq 'Active')"
                    ItemTypes = @("Report", "SemanticModel", "Notebook", "SparkJobDefinition")
                }
                FabricPSPBIPSettings = [PSCustomObject]@{
                    ParallelProcessing = $true
                    ThrottleLimit = 0  # Auto-detect
                    RateLimitSettings = [PSCustomObject]@{
                        MaxRetries = 3
                        RetryDelaySeconds = 30
                        BackoffMultiplier = 2
                    }
                }
                NotificationSettings = [PSCustomObject]@{
                    EnableNotifications = $false
                }
            }
            
            $v2Config.Version | Should -Be "2.0"
            $v2Config.ExportSettings | Should -Not -BeNullOrEmpty
            $v2Config.FabricPSPBIPSettings | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "File System Operations" {
    Context "When creating target directories" {
        It "Should create directory hierarchy" {
            $testPath = Join-Path $script:TestOutputDir "2025\08\04"
            
            if (Test-Path $testPath) {
                Remove-Item $testPath -Recurse -Force
            }
            
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null
            Test-Path $testPath | Should -Be $true
        }
        
        It "Should handle existing directories gracefully" {
            $testPath = Join-Path $script:TestOutputDir "existing-dir"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null
            
            # Should not throw when directory already exists
            { New-Item -Path $testPath -ItemType Directory -Force } | Should -Not -Throw
        }
    }
    
    Context "When cleaning up old archives" {
        It "Should calculate cutoff date correctly" {
            $retentionDays = 30
            $cutoffDate = (Get-Date).AddDays(-$retentionDays)
            
            $cutoffDate | Should -BeOfType [DateTime]
            $cutoffDate | Should -BeLessThan (Get-Date)
        }
        
        It "Should identify old directories" {
            # Create a test directory with old timestamp
            $oldDir = Join-Path $script:TestOutputDir "old-archive"
            New-Item -Path $oldDir -ItemType Directory -Force | Out-Null
            
            # Set creation time to 60 days ago
            $oldDate = (Get-Date).AddDays(-60)
            (Get-Item $oldDir).CreationTime = $oldDate
            
            $cutoffDate = (Get-Date).AddDays(-30)
            $oldFolders = Get-ChildItem -Path $script:TestOutputDir -Directory | 
                Where-Object { $_.CreationTime -lt $cutoffDate }
            
            $oldFolders | Should -Contain (Get-Item $oldDir)
        }
    }
}

Describe "Data Validation" {
    Context "When validating workspace IDs" {
        It "Should validate GUID format" {
            $validGuid = "12345678-1234-1234-1234-123456789abc"
            $invalidGuid = "not-a-guid"
            
            # Test GUID validation pattern
            $guidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
            
            $validGuid | Should -Match $guidPattern
            $invalidGuid | Should -Not -Match $guidPattern
        }
    }
    
    Context "When validating item types" {
        It "Should validate against supported types" {
            $supportedTypes = @("Report", "SemanticModel", "Notebook", "SparkJobDefinition")
            $testType = "Report"
            $invalidType = "InvalidType"
            
            $supportedTypes | Should -Contain $testType
            $supportedTypes | Should -Not -Contain $invalidType
        }
    }
    
    Context "When validating filter expressions" {
        It "Should validate OData filter syntax" {
            $validFilters = @(
                "(type eq 'Workspace')",
                "(state eq 'Active')",
                "contains(name,'Test')",
                "startswith(name,'Dev')",
                "(type eq 'Workspace') and (state eq 'Active')"
            )
            
            foreach ($filter in $validFilters) {
                # Basic validation - contains recognized OData operators
                $filter | Should -Match "(eq|contains|startswith|endswith|and|or)"
            }
        }
    }
}
