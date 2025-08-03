# Fabric Archive Bot - Changelog

This file contains the version history and changes for Fabric Archive Bot.

---

## Version 2.0.0 - Enhanced Architecture (2025)

### 🚀 Major Features

#### **FabricTools Integration**
- **Modern PowerShell Module**: Enhanced with the community-driven FabricTools PowerShell module
- **Built-in Rate Limiting**: Automatic HTTP 429 handling with exponential backoff
- **Improved Reliability**: Better error handling and connection management
- **Enhanced Security**: More secure authentication methods

#### **Modular Architecture**
- **Core Module**: Functionality extracted into `FabricArchiveBotCore.psm1` for better maintainability
- **Separation of Concerns**: Clear separation between UI, logic, and configuration
- **Reusable Components**: Functions can be imported and used independently
- **Enhanced Testing**: Modular structure enables better unit testing

#### **Item-Level Parallel Processing**
- **Optimal Resource Utilization**: Processes individual items in parallel across all workspaces
- **Smart Thread Management**: Threads seamlessly move between workspaces as items complete
- **Auto CPU Detection**: Automatically detects logical processor count for optimal throttling
- **PowerShell 7+ Support**: Leverages modern PowerShell parallel processing capabilities

#### **Configuration-Driven Workspace Filtering**
- **OData-Style Expressions**: Support for complex filtering expressions
- **Dynamic Filtering**: No more hard-coded workspace lists
- **Flexible Criteria**: Filter by state, type, name patterns, and more
- **Easy Configuration**: All filters defined in JSON configuration

### 🎯 New Features

#### **Enhanced Metadata Export**
- **Comprehensive Workspace Metadata**: Detailed workspace information in JSON format
- **Item Inventories**: Complete item lists with type and metadata information
- **Export Configuration Tracking**: Records of what was exported and when
- **Usage Metrics** (Optional): Workspace usage data when enabled
- **Lineage Tracking** (Optional): Item relationships and dependencies

#### **WhatIf Mode**
- **Preview Mode**: See what would be exported without performing actual exports
- **Safe Testing**: Test configuration changes without impact
- **Item Count Validation**: Verify filtering logic before execution
- **Workspace Discovery**: Explore available workspaces and items

#### **Automatic Migration**
- **Seamless Upgrade Path**: Helper script to migrate v1.0 configurations to v2.0
- **Compatibility Validation**: Ensures v1.0 configs work with v2.0 features
- **Backup Creation**: Automatically backs up existing configurations
- **Configuration Testing**: Validates migrated configurations

### 📁 File Structure Changes

#### **New Files**
- `Start-FabricArchiveBot.ps1` - Main v2.0 entry point (renamed from Export-FabricItemsFromAllWorkspaces-v2.ps1)
- `FabricArchiveBot_Config.json` - Enhanced v2.0 configuration file
- `modules/FabricArchiveBotCore.psm1` - Core functionality module
- `helpers/ConvertTo-FabricArchiveBotV2.ps1` - Configuration migration utility (renamed from Migrate-ToV2.ps1)
- `helpers/Register-FabricArchiveBotScheduledTask.ps1` - Enhanced task scheduler
- `helpers/Set-FabricArchiveBotUserEnvironmentVariable.ps1` - Environment setup utility
- `examples/Show-FabricArchiveBotExamples.ps1` - Usage examples (renamed from quick-start-examples.ps1)
- `docs/workspace-filtering-guide.md` - Comprehensive filtering documentation
- `docs/parallel-processing-guide.md` - Performance optimization guide
- `docs/api-rate-limiting-guide.md` - Rate limiting implementation details

#### **Enhanced Files**
- `README.md` - Updated with v2.0 features and migration path
- `Config.json` - Remains for v1.0 backward compatibility

### ⚙️ Configuration Enhancements

#### **Workspace Filtering Examples**
```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(type eq 'Workspace') and (state eq 'Active')",
    "ItemTypes": ["Report", "SemanticModel", "Notebook", "SparkJobDefinition"]
  }
}
```

**Advanced Filtering:**
```json
{
  "ExportSettings": {
    "WorkspaceFilter": "contains(name,'Production') and (state eq 'Active')",
    "WorkspaceFilter": "startswith(name,'Finance') and (state eq 'Active')",
    "WorkspaceFilter": "endswith(name,'Prod') and (type eq 'Workspace')"
  }
}
```

#### **FabricTools Settings**
```json
{
  "FabricToolsSettings": {
    "UseFabricTools": true,
    "ParallelProcessing": true,
    "ThrottleLimit": 0,
    "RateLimitSettings": {
      "MaxRetries": 3,
      "RetryDelaySeconds": 30,
      "BackoffMultiplier": 2
    }
  }
}
```

#### **Advanced Features**
```json
{
  "AdvancedFeatures": {
    "EnableUsageMetrics": false,
    "EnableLineageTracking": false,
    "EnableCapacityMonitoring": false
  }
}
```

### 🔄 Migration Path

1. **Backup Current Setup**: Copy existing `Config.json` and `IgnoreList.json`
2. **Run Migration Script**: `.\helpers\ConvertTo-FabricArchiveBotV2.ps1`
3. **Test Configuration**: `.\Start-FabricArchiveBot.ps1 -WhatIf`
4. **Validate Results**: Review workspace and item discovery
5. **Execute v2.0**: `.\Start-FabricArchiveBot.ps1`

### 🔧 Technical Improvements

#### **Function Naming Standardization**
- **FAB Prefix**: All custom cmdlets use "FAB" prefix for consistent branding
- **PowerShell Compliance**: All scripts follow Verb-Noun naming conventions
- **Module Organization**: Clear separation between public and private functions

#### **Multi-Layer Rate Limiting**
- **FabricTools Built-in**: Leverages FabricTools' native HTTP 429 handling
- **Custom Wrapper**: Additional `Invoke-FABRateLimitedOperation` for enhanced control
- **Exponential Backoff**: Smart retry logic with configurable multipliers
- **Operation Monitoring**: Detailed logging of rate limit encounters

#### **Enhanced Error Handling**
- **Comprehensive Try-Catch**: Robust error handling throughout the solution
- **Detailed Logging**: Clear error messages with context and stack traces
- **Graceful Degradation**: Fallback to v1.0 functionality when needed
- **Validation Checks**: Pre-execution validation of configuration and dependencies

### 🔙 Backward Compatibility

#### **v1.0 Support Maintained**
- `Export-FabricItemsFromAllWorkspaces.ps1` - Unchanged and fully functional
- `Config.json` - Continues to work with legacy script
- `IgnoreList.json` - Legacy ignore patterns remain supported
- **Automatic Fallback**: v2.0 script falls back to v1.0 if FabricTools unavailable

#### **Configuration Compatibility**
- **Dual Format Support**: Handles both v1.0 and v2.0 configuration formats
- **Automatic Enhancement**: Adds missing v2.0 settings to v1.0 configs
- **Validation Logic**: Ensures backward compatibility without breaking changes

### 📋 Requirements

- **PowerShell**: 5.1+ (PowerShell 7+ recommended for optimal performance)
- **Modules**: FabricTools (installed automatically if missing)
- **Permissions**: Appropriate Microsoft Fabric/Power BI permissions
- **Network**: Internet access for module installation and Fabric API access

---

## Version 1.0.0 - Initial Release (2024)

### 🎯 Core Features

#### **Automated Fabric Exports**
- **Complete Workspace Export**: Export all items from all active workspaces
- **Service Principal Authentication**: Unattended execution with app registrations
- **Item Type Support**: Reports, Semantic Models (Datasets), Notebooks, Spark Job Definitions
- **Automatic Folder Structure**: Organized by workspace and date hierarchy

#### **FabricPS-PBIP Integration** 
- **Microsoft Official Module**: Built on Microsoft's FabricPS-PBIP PowerShell module
- **PBIP Format Support**: Native Power BI Project (PBIP) format exports
- **TMDL Support**: Tabular Model Definition Language for semantic models
- **Direct API Access**: Leverages Microsoft Fabric REST APIs

#### **Flexible Configuration**
- **JSON Configuration**: Easy-to-edit configuration files
- **Service Principal Setup**: Support for automated authentication
- **Workspace Filtering**: OData-style workspace filtering expressions
- **Ignore Lists**: Configurable workspace and item exclusions

#### **Retention Management**
- **Automatic Cleanup**: Configurable retention policies for exported files
- **Date-based Organization**: Hierarchical folder structure (Year/Month/Day)
- **Storage Optimization**: Automatic removal of old exports to save disk space

### 📁 File Structure

#### **Main Scripts**
- `Export-FabricItemsFromAllWorkspaces.ps1` - Main export script
- `Config.json` - Configuration file with service principal settings
- `IgnoreList.json` - Workspace and item exclusion lists

#### **Helper Scripts**
- `Register-FabricArchiveBotScheduledTask.ps1` - Windows Task Scheduler setup
- `Set-FabricArchiveBotUserEnvironmentVariable.ps1` - Environment configuration

### ⚙️ Configuration Options

#### **Service Principal Configuration**
```json
{
  "ServicePrincipal": {
    "AppId": "YOUR_APPLICATION_ID",
    "AppSecret": "YOUR_APP_SECRET", 
    "TenantId": "YOUR_TENANT_ID"
  }
}
```

#### **Workspace Filtering**
- **Default Filter**: `(type eq 'Workspace') and (state eq 'Active')`
- **OData Support**: Standard OData query expressions
- **Dynamic Filtering**: Runtime filter specification

#### **Ignore Lists**
```json
{
  "IgnoreWorkspaces": ["Test Workspace", "Development"],
  "IgnoreReports": ["Draft Report", "Template"],
  "IgnoreSemanticModels": ["Test Dataset"]
}
```

### 🎛️ Command Line Options

#### **Basic Usage**
```powershell
.\Export-FabricItemsFromAllWorkspaces.ps1
```

#### **Advanced Options**
```powershell
# Custom configuration
.\Export-FabricItemsFromAllWorkspaces.ps1 -ConfigObject $customConfig

# Custom target folder
.\Export-FabricItemsFromAllWorkspaces.ps1 -TargetFolder "C:\Exports"

# Custom retention period
.\Export-FabricItemsFromAllWorkspaces.ps1 -RetentionCutoffDate (Get-Date).AddDays(-60)

# Custom workspace filter
.\Export-FabricItemsFromAllWorkspaces.ps1 -WorkspaceFilter "contains(name,'Production')"

# Download latest module
.\Export-FabricItemsFromAllWorkspaces.ps1 -GetLatestModule
```

### 🔧 Technical Foundation

#### **PowerShell Requirements**
- **PowerShell 7+**: Required for optimal performance and compatibility
- **Module Dependencies**: Az.Account, FabricPS-PBIP (downloaded automatically)
- **Execution Policy**: Requires appropriate PowerShell execution policy

#### **Authentication Methods**
- **Service Principal**: Recommended for automated/scheduled execution
- **Interactive Authentication**: Fallback for manual execution
- **Multi-Factor Authentication**: Supported through interactive mode

#### **Export Formats**
- **PBIP**: Power BI Project format (default)
- **TMDL**: Tabular Model Definition Language for semantic models
- **JSON Metadata**: Item and workspace metadata

### 📋 Requirements

- **PowerShell**: 7.0+ required
- **Modules**: Az.Account, FabricPS-PBIP (installed automatically)
- **Permissions**: Fabric Admin or appropriate workspace permissions
- **Authentication**: Service Principal or interactive user authentication

### 🚀 Key Benefits

- **Free & Open Source**: No licensing costs, full source code access
- **Automated Scheduling**: Windows Task Scheduler integration
- **Enterprise Ready**: Service Principal authentication for production use
- **Configurable**: Flexible filtering and retention policies
- **Reliable**: Built on Microsoft's official PowerShell modules

---

## Migration Notes

### From v1.0 to v2.0
- **Automatic Migration**: Use `.\helpers\ConvertTo-FabricArchiveBotV2.ps1` for seamless upgrade
- **Backward Compatibility**: v1.0 scripts continue to work unchanged
- **Enhanced Features**: v2.0 provides significant performance and reliability improvements
- **Gradual Migration**: Can run both versions side-by-side during transition

### Breaking Changes
- **None**: v2.0 maintains full backward compatibility with v1.0 configurations
- **New Dependencies**: FabricTools module (installed automatically)
- **Enhanced Configuration**: New settings available but not required

### Recommended Upgrade Path
1. **Keep v1.0 Working**: Existing setup continues to function
2. **Test v2.0**: Run migration script and test with `-WhatIf` mode
3. **Gradual Transition**: Switch to v2.0 when comfortable with new features
4. **Full Migration**: Eventually standardize on v2.0 for best performance
