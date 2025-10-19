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

### 3. Capacity Filtering

Filter workspaces by their assigned capacity ID:

```json
"WorkspaceFilter": "(capacityId eq '56bac802-080d-4f73-8a42-1b406eb1fcac')"
```

**Note:** Capacity filtering requires an additional API call per workspace to retrieve the full workspace details. This may increase execution time when filtering large numbers of workspaces.

### 4. Domain Filtering

Filter workspaces by their assigned domain ID:

```json
"WorkspaceFilter": "(domainId eq '9ce364e0-8e9d-4605-887a-b599b3e8b123')"
```

**Note:** Domain filtering requires an additional API call per workspace to retrieve the full workspace details. This may increase execution time when filtering large numbers of workspaces.

### 5. Name Pattern Filtering

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

### 6. Combined Filters

Combine multiple filter criteria using `and`:

```json
"WorkspaceFilter": "(type eq 'Workspace') and (state eq 'Active') and contains(name,'Production')"
```

```json
"WorkspaceFilter": "(capacityId eq '56bac802-080d-4f73-8a42-1b406eb1fcac') and (state eq 'Active')"
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

### Example 4: Workspaces on Specific Capacity

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(capacityId eq '56bac802-080d-4f73-8a42-1b406eb1fcac')"
  }
}
```

### Example 5: Workspaces in Specific Domain

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(domainId eq '9ce364e0-8e9d-4605-887a-b599b3e8b123')"
  }
}
```

### Example 6: Active Workspaces on Specific Capacity and Domain

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(state eq 'Active') and (capacityId eq '56bac802-080d-4f73-8a42-1b406eb1fcac') and (domainId eq '9ce364e0-8e9d-4605-887a-b599b3e8b123')"
  }
}
```

### Example 7: No Filtering (All Workspaces)

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

## Finding Capacity and Domain IDs

To filter by capacity or domain, you'll need the corresponding GUIDs:

### Finding Capacity ID

1. Navigate to the Fabric Admin Portal
2. Go to **Capacity settings** → **[Your Capacity Name]**
3. Copy the capacity ID from the URL or details page

Or use PowerShell to list all capacities with their IDs.

### Finding Domain ID

1. Navigate to the Fabric Admin Portal
2. Go to **Domains**
3. Select your domain
4. Copy the domain ID from the URL or details page

Or use PowerShell to query domain information via the Fabric REST API.

## Testing Filters

Use the `-WhatIf` parameter to test your filters without performing actual exports:

```powershell
.\Start-FabricArchiveBot.ps1 -WhatIf
```

This will show you which workspaces would be processed with your current filter configuration.

## Filter Syntax Reference

| Filter Type      | Syntax                       | Example                                         |
| ---------------- | ---------------------------- | ----------------------------------------------- |
| State            | `(state eq 'value')`         | `(state eq 'Active')`                           |
| Type             | `(type eq 'value')`          | `(type eq 'Workspace')`                         |
| Capacity ID      | `(capacityId eq 'guid')`     | `(capacityId eq '56bac802...')`                 |
| Domain ID        | `(domainId eq 'guid')`       | `(domainId eq '9ce364e0...')`                   |
| Name Contains    | `contains(name,'pattern')`   | `contains(name,'Prod')`                         |
| Name Starts With | `startswith(name,'pattern')` | `startswith(name,'Finance')`                    |
| Name Ends With   | `endswith(name,'pattern')`   | `endswith(name,'Test')`                         |
| Combine Filters  | `filter1 and filter2`        | `(state eq 'Active') and contains(name,'Prod')` |

## Error Handling

If a filter expression cannot be parsed:

- A warning will be displayed
- All workspaces will be processed (fail-safe behavior)
- The error details will be logged for troubleshooting

If workspace details cannot be retrieved for capacity/domain filtering:

- A warning will be displayed for that specific workspace
- The workspace will still be included with basic information
- Filtering will continue for remaining workspaces

## Performance Considerations

- Basic filters (state, type, name) are applied in-memory after retrieving workspace listings
- **Capacity and domain filters require additional API calls** to retrieve full workspace details
- More specific filters can improve performance by reducing the number of workspaces processed
- Use name-based filters to target specific departments or projects when possible
- Consider using capacity or domain filters sparingly, especially with large numbers of workspaces
