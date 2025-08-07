# Fabric Archive Bot - Development Instructions

## Solution Overview

The Fabric Archive Bot is a PowerShell-based solution for exporting and archiving Microsoft Fabric workspace items. This is version 2.0, which represents a significant modernization from the legacy version.

## Core Architecture Principles

### Module Dependencies

- **Primary Module**: Use FabricPS-PBIP module for all Fabric operations
- **Legacy Avoidance**: Do not use legacy Power BI modules or APIs
- **Azure Integration**: Handle Azure module conflicts proactively with aggressive cleanup and fresh loading

### Configuration Management

- **Environment Variables**: Use user environment variables for configuration storage and portability
- **JSON Configuration**: Store configuration as compressed JSON in environment variables
- **File-based Fallback**: Support loading configuration from JSON files when environment variables are not available

### Data Integrity

- **Preserve Formatting**: Maintain proper spacing and formatting in filter expressions (e.g., OData WorkspaceFilter strings)
- **Avoid Aggressive Processing**: Do not strip whitespace from structured data like filter expressions
- **JSON Compression**: Use PowerShell's `ConvertTo-Json -Compress` for environment variable storage rather than manual string manipulation

### Supported Item Types

- **Dynamic Detection**: Automatically determine supported item types by querying Microsoft Learn documentation structure
- **Future-Proof**: Automatically adapt when Microsoft adds support for new item types to the Get Item Definition API
- **Web Scraping Strategy**: Query the official table of contents JSON from Microsoft Fabric REST API documentation
- **Graceful Handling**: Provide clear feedback when unsupported item types are encountered or when dynamic detection fails
- **Fallback Mechanism**: Use hardcoded list of known supported types when web service is unavailable

### Error Handling and Reliability

- **Azure Module Conflicts**: Implement proactive detection and resolution of Az.Accounts assembly loading conflicts
- **Fresh Session Recovery**: When module conflicts occur, guide users to start fresh PowerShell sessions
- **Configuration Validation**: Validate configuration compatibility and provide clear error messages for misconfigurations

### User Experience

- **Clear Documentation**: Provide comprehensive guides for common scenarios (API rate limiting, parallel processing, workspace filtering)
- **Example Scripts**: Include practical examples that demonstrate proper usage patterns
- **Helper Scripts**: Provide utility scripts for common tasks like environment setup and scheduled task registration

## Development Guidelines

### Code Quality

- **PowerShell Best Practices**: Follow PowerShell scripting best practices and conventions
- **Modular Design**: Keep core functionality in modules, with clear separation of concerns
- **Backward Compatibility**: When possible, maintain compatibility with existing configurations while encouraging migration to v2.0

### Testing and Validation

- **Configuration Testing**: Always validate configuration changes before committing
- **Module Loading**: Test module loading scenarios, especially Azure module conflict resolution
- **Export Verification**: Verify that exported metadata maintains proper formatting and structure
- **Pester Framework**: Use Pester 5.x for all testing with proper PowerShell 7+ compatibility
- **Fast Test Execution**: Mock Start-Sleep and external API calls to ensure tests run in milliseconds, not minutes
- **Comprehensive Coverage**: Maintain test coverage for all public functions with both unit and integration tests

### Naming Conventions and Code Standards

- **Function Prefixes**: All custom functions (including those in helper modules, scripts, and tests) must use the "FAB" prefix (e.g., `Get-FABWorkspaces`, `Invoke-FABOperation`)
- **Approved Verbs**: Use only PowerShell-approved verbs (Get, Set, Invoke, Start, Stop, Clear, Initialize, etc.) Never use verbs like Setup, Debug, Clean, Analyze - use Initialize, Start, Clear, Get instead. Use `Get-Verb` to find a list of approved verbs if necessary
- **Variable Usage**: All declared variables must be used; remove any unused variable declarations

### Documentation

- **Inline Comments**: Provide clear comments explaining complex logic, especially around module loading and configuration handling
- **User Guides**: Maintain comprehensive documentation for setup, configuration, and troubleshooting
- **Change Management**: Document breaking changes and provide migration guidance

### Out-of-Scope Considerations

- **Version 1.0**: Do not modify, reference, or test the legacy version 1.0 codebase (Export-FabricItemsFromAllWorkspaces.ps1). This file must remain untouched to ensure compatibility with existing deployments.
