# Fabric Archive Bot Testing Guide

## Overview

This testing framework provides comprehensive coverage for the Fabric Archive Bot v2.0 solution using the Pester testing framework. The tests are organized into unit tests and integration tests to ensure all components work correctly both in isolation and together.

## Test Structure

```
tests/
├── Invoke-Tests.ps1           # Main test runner
├── fixtures/                  # Test data and mock objects
│   ├── TestData.ps1          # Mock data definitions
│   └── test-config.json      # Sample configuration for testing
├── unit/                      # Unit tests (test individual functions)
│   ├── FabricArchiveBotCore.Tests.ps1
│   └── Configuration.Tests.ps1
└── integration/              # Integration tests (test component interaction)
    ├── ModuleIntegration.Tests.ps1
    └── MainScripts.Tests.ps1
```

## Test Configuration for Speed

The test suite is optimized for fast execution with the following settings:

- **Rate Limit Timeout**: 1 second (vs. 30 seconds in production)
- **Max Retries**: 1 (vs. 3 in production)
- **Start-Sleep Mocked**: All `Start-Sleep` calls are mocked globally
- **Parallel Processing**: Limited throttle for test scenarios

This reduces test execution time from potentially minutes to seconds without impacting test coverage or accuracy.

## Prerequisites

1. **PowerShell 7+**: The solution requires PowerShell 7 or later
2. **Pester Module**: The testing framework (automatically installed if missing)
3. **Test Environment**: Isolated test directories to avoid affecting production data

## Running Tests

### Quick Start

Run all tests with default settings:

```powershell
.\tests\Invoke-Tests.ps1
```

### Test Types

Run specific test types:

```powershell
# Unit tests only
.\tests\Invoke-Tests.ps1 -TestType Unit

# Integration tests only
.\tests\Invoke-Tests.ps1 -TestType Integration

# All tests (default)
.\tests\Invoke-Tests.ps1 -TestType All
```

### Code Coverage

Generate code coverage reports:

```powershell
.\tests\Invoke-Tests.ps1 -Coverage
```

This creates a `coverage.xml` file in the tests directory using JaCoCo format.

### Output Formats

Save test results to file:

```powershell
# NUnit XML format
.\tests\Invoke-Tests.ps1 -OutputFormat NUnitXml -OutputFile "test-results.xml"

# JUnit XML format
.\tests\Invoke-Tests.ps1 -OutputFormat JUnitXml -OutputFile "test-results.xml"
```

## Test Categories

### Unit Tests

#### FabricArchiveBotCore.Tests.ps1

Tests the core module functions in isolation:

- **Get-FABSupportedItemTypes**: Dynamic item type detection from Microsoft Learn
- **Get-FABFallbackItemTypes**: Fallback item type list
- **Find-FABDefinitionEndpoints**: TOC parsing for supported endpoints
- **Invoke-FABWorkspaceFilter**: OData-style workspace filtering
- **Get-FABOptimalThrottleLimit**: Parallel processing configuration
- **Confirm-FABConfigurationCompatibility**: Configuration validation and enhancement
- **Invoke-FABRateLimitedOperation**: Rate limiting and retry logic

#### Configuration.Tests.ps1

Tests configuration management and helper functions:

- **JSON Configuration Loading**: File-based configuration parsing
- **Environment Variable Management**: Environment variable configuration
- **Helper Script Functions**: Validation of helper script logic
- **File System Operations**: Directory creation and cleanup
- **Data Validation**: GUID, item type, and filter validation

### Integration Tests

#### ModuleIntegration.Tests.ps1

Tests how different module components work together:

- **FabricPS-PBIP Integration**: Module availability and compatibility
- **Configuration Workflows**: End-to-end configuration processing
- **Workspace Filtering**: Complex filter application
- **Rate Limiting Integration**: Multiple operation coordination
- **Parallel Processing**: Configuration and optimization
- **Error Handling**: Error propagation across components

#### MainScripts.Tests.ps1

Tests the main scripts and complete workflows:

- **Start-FabricArchiveBot.ps1**: Main orchestration script
- **Helper Scripts**: Scheduled task and environment setup
- **Export Process**: Complete export workflow
- **Configuration Management**: Environment variable overrides
- **Error Recovery**: Graceful error handling and resilience

## Test Data and Mocking

### Mock Data (TestData.ps1)

The test suite uses comprehensive mock data:

- **Mock Workspaces**: Sample workspace objects with different states
- **Mock Items**: Sample items of various types
- **Mock TOC Response**: Simulated Microsoft Learn documentation structure
- **Test Configuration**: Complete v2.0 configuration for testing

### Mocking Strategy

Tests use PowerShell's `Mock` command to:

- **Isolate Components**: Prevent external API calls during testing
- **Simulate Errors**: Test error handling and retry logic
- **Control Data**: Provide predictable test data
- **Speed Execution**: Avoid network calls and long operations

## Test Patterns

### Arrange-Act-Assert

All tests follow the AAA pattern:

```powershell
It "Should perform expected behavior" {
    # Arrange - Set up test data and mocks
    $testData = @{ Property = "Value" }
    Mock External-Function { return "MockedResult" }

    # Act - Execute the function under test
    $result = Function-Under-Test -Parameter $testData

    # Assert - Verify the expected outcome
    $result | Should -Be "ExpectedValue"
}
```

### BeforeAll/AfterAll

Tests use setup and cleanup blocks:

```powershell
BeforeAll {
    # Import modules
    # Set up test environment
    # Create test data
}

AfterAll {
    # Clean up test files
    # Remove modules
    # Reset environment
}
```

## Continuous Integration

### GitHub Actions Integration

The test framework is designed for CI/CD integration:

```yaml
# Example GitHub Actions workflow
- name: Run Tests
  run: |
    .\tests\Invoke-Tests.ps1 -Coverage -OutputFormat JUnitXml -OutputFile test-results.xml

- name: Publish Test Results
  uses: dorny/test-reporter@v1
  with:
    name: Pester Tests
    path: test-results.xml
    reporter: java-junit
```

### Coverage Requirements

Recommended coverage targets:

- **Overall Coverage**: ≥ 70%
- **Critical Functions**: ≥ 90%
- **Configuration Management**: ≥ 85%
- **Error Handling**: ≥ 80%

## Writing New Tests

### Test Naming Convention

Follow descriptive naming patterns:

```powershell
Describe "Function-Name" {
    Context "When specific condition exists" {
        It "Should perform expected behavior with specific outcome" {
            # Test implementation
        }
    }
}
```

### Mock External Dependencies

Always mock external calls:

```powershell
# Mock API calls
Mock Invoke-RestMethod { return $mockResponse }

# Mock file system operations
Mock Test-Path { return $true }

# Mock system information
Mock Get-CimInstance { return $mockSystemInfo }
```

### Test Data Isolation

Use test-specific directories and cleanup:

```powershell
BeforeAll {
    $script:TestDir = Join-Path $env:TEMP "TestSpecificFolder"
    New-Item -Path $script:TestDir -ItemType Directory -Force
}

AfterAll {
    Remove-Item $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
}
```

## Troubleshooting

### Common Issues

1. **Module Import Failures**

   - Ensure module paths are correct
   - Check PowerShell execution policy
   - Verify dependencies are available

2. **Test Environment Conflicts**

   - Use isolated test directories
   - Clean up after tests
   - Avoid global state modifications

3. **Mock Failures**
   - Verify mock parameters match function signatures
   - Check mock scope (script vs. global)
   - Ensure mocks are defined before use

### Debug Mode

Run tests with verbose output:

```powershell
.\tests\Invoke-Tests.ps1 -Verbose
```

Enable Pester debug information:

```powershell
$PesterPreference = [PesterConfiguration]::Default
$PesterPreference.Debug.WriteDebugMessages = $true
```

## Best Practices

1. **Isolation**: Each test should be independent
2. **Clarity**: Test names should clearly describe the scenario
3. **Coverage**: Aim for comprehensive coverage of critical paths
4. **Performance**: Keep tests fast by using mocks
5. **Maintenance**: Update tests when code changes
6. **Documentation**: Document complex test scenarios

## Contributing

When adding new features:

1. Write tests first (TDD approach)
2. Ensure existing tests still pass
3. Add integration tests for new workflows
4. Update test documentation
5. Maintain or improve coverage percentages

## References

- [Pester Documentation](https://pester.dev/)
- [PowerShell Testing Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/writing-portable-modules)
- [Fabric Archive Bot Documentation](../README.md)
