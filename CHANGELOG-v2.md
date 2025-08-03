# Fabric Archive Bot v2.0 Changelog

## Version 2.0.0 - Initial Release

### New Features
- **FabricTools Integration**: Enhanced with the FabricTools PowerShell module for improved reliability and performance
- **Modular Architecture**: Core functionality extracted into `FabricArchiveBotCore.psm1` module
- **Configuration-Driven Workspace Filtering**: OData-style filter expressions support
- **Parallel Processing**: Optional parallel processing for faster exports (PowerShell 7+)
- **Enhanced Metadata Export**: Comprehensive workspace and item metadata
- **WhatIf Mode**: Preview what would be exported without performing actual exports
- **Automatic Migration**: Helper script to migrate v1.0 configurations to v2.0

### File Changes
- **Renamed**: `Export-FabricItemsFromAllWorkspaces-v2.ps1` → `Start-FabricArchiveBot.ps1`
- **Renamed**: `Config-v2-example.json` → `FabricArchiveBot_Config.json`
- **Added**: `modules/FabricArchiveBotCore.psm1` - Core functionality module
- **Added**: `helpers/Migrate-ToV2.ps1` - Configuration migration utility
- **Added**: `docs/workspace-filtering-guide.md` - Comprehensive filtering documentation
- **Added**: `examples/quick-start-examples.ps1` - Usage examples

### Configuration Enhancements
- **WorkspaceFilter**: Configure workspace filtering with OData-style expressions
- **FabricToolsSettings**: Control FabricTools-specific behavior
- **AdvancedFeatures**: Enable usage metrics, enhanced metadata, and more
- **ExportSettings**: Comprehensive export configuration options

### Backward Compatibility
- v1.0 `Export-FabricItemsFromAllWorkspaces.ps1` remains unchanged
- v1.0 `Config.json` continues to work with legacy script
- Automatic fallback to v1.0 functionality if FabricTools is unavailable

### Workspace Filtering Examples
```json
"WorkspaceFilter": "(type eq 'Workspace') and (state eq 'Active')"
"WorkspaceFilter": "contains(name,'Production')"
"WorkspaceFilter": "startswith(name,'Finance') and (state eq 'Active')"
```

### Migration Path
1. Run `.\helpers\Migrate-ToV2.ps1` to upgrade your configuration
2. Test with `.\Start-FabricArchiveBot.ps1 -WhatIf`
3. Run `.\Start-FabricArchiveBot.ps1` for full v2.0 functionality

### Requirements
- PowerShell 5.1+ (PowerShell 7+ recommended for optimal performance)
- FabricTools module (installed automatically if missing)
- Appropriate Microsoft Fabric permissions
