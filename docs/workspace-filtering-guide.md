# Workspace Filtering Guide for Fabric Archive Bot v2.0

## Overview

Fabric Archive Bot v2.0 supports flexible workspace filtering through configuration-driven filter expressions. This allows you to control which workspaces are processed during the archive operation.

## Configuration Location

Workspace filters are defined in the `ExportSettings.WorkspaceFilter` property of your configuration file:

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(type eq 'Workspace') and (state eq 'Active')"
  }
}
```

## Supported Filter Types

### 1. State Filtering

Filter workspaces by their state (Active, Inactive, etc.):

```json
"WorkspaceFilter": "(state eq 'Active')"
```

### 2. Type Filtering

Filter workspaces by their type:

```json
"WorkspaceFilter": "(type eq 'Workspace')"
```

### 3. Name Pattern Filtering

Filter workspaces by name patterns:

**Contains:**
```json
"WorkspaceFilter": "contains(name,'Production')"
```

**Starts with:**
```json
"WorkspaceFilter": "startswith(name,'Finance')"
```

**Ends with:**
```json
"WorkspaceFilter": "endswith(name,'Backup')"
```

### 4. Combined Filters

Combine multiple filter criteria using `and`:

```json
"WorkspaceFilter": "(type eq 'Workspace') and (state eq 'Active') and contains(name,'Production')"
```

## Examples

### Example 1: Active Workspaces Only
```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(state eq 'Active')"
  }
}
```

### Example 2: Production Workspaces
```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(state eq 'Active') and contains(name,'Production')"
  }
}
```

### Example 3: Finance Department Workspaces
```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(state eq 'Active') and startswith(name,'Finance')"
  }
}
```

### Example 4: Exclude Backup Workspaces
```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(state eq 'Active') and not(endswith(name,'Backup'))"
  }
}
```

### Example 5: No Filtering (All Workspaces)
```json
{
  "ExportSettings": {
    "WorkspaceFilter": ""
  }
}
```

## Migration from v1.0

If you're migrating from v1.0, the default filter maintains backward compatibility:

- **v1.0 behavior**: Hard-coded to active workspaces only
- **v2.0 default**: `"(type eq 'Workspace') and (state eq 'Active')"`

## Testing Filters

Use the `-WhatIf` parameter to test your filters without performing actual exports:

```powershell
.\Start-FabricArchiveBot.ps1 -WhatIf
```

This will show you which workspaces would be processed with your current filter configuration.

## Filter Syntax Reference

| Filter Type | Syntax | Example |
|-------------|--------|---------|
| State | `(state eq 'value')` | `(state eq 'Active')` |
| Type | `(type eq 'value')` | `(type eq 'Workspace')` |
| Name Contains | `contains(name,'pattern')` | `contains(name,'Prod')` |
| Name Starts With | `startswith(name,'pattern')` | `startswith(name,'Finance')` |
| Name Ends With | `endswith(name,'pattern')` | `endswith(name,'Test')` |
| Combine Filters | `filter1 and filter2` | `(state eq 'Active') and contains(name,'Prod')` |

## Error Handling

If a filter expression cannot be parsed:
- A warning will be displayed
- All workspaces will be processed (fail-safe behavior)
- The error details will be logged for troubleshooting

## Performance Considerations

- Filters are applied in-memory after retrieving all workspaces
- More specific filters can improve performance by reducing the number of workspaces processed
- Use name-based filters to target specific departments or projects
