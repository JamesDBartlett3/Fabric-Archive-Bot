# Fabric Archive Bot - Filtering Guide

This guide covers all filtering capabilities in Fabric Archive Bot, including workspace-level and item-level filtering.

## Table of Contents

- [Overview](#overview)
- [Workspace Filtering](#workspace-filtering)
- [Item Filtering](#item-filtering)
- [Filter Syntax Reference](#filter-syntax-reference)
- [Configuration Examples](#configuration-examples)
- [Advanced Scenarios](#advanced-scenarios)
- [Scanner API Enrichment](#scanner-api-enrichment)

---

## Overview

Fabric Archive Bot supports two levels of filtering:

1. **Workspace Filtering** - Controls which workspaces are processed
2. **Item Filtering** - Controls which items within workspaces are exported

Both use **OData-style filter syntax** for consistency and flexibility.

### Filter Execution Order

```
1. Workspace Filter (WorkspaceFilter)
   ↓
2. Item Types Filter (ItemTypes array)
   ↓
3. Item Filter (ItemFilter)
   ↓
4. Export
```

---

## Workspace Filtering

### Configuration Location

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(type eq 'Workspace') and (state eq 'Active')"
  }
}
```

### Available Properties

When using the Standard Fabric API, workspace objects have these properties:

| Property | Type | Description | Example Value |
|----------|------|-------------|---------------|
| `id` | GUID | Workspace unique identifier | `"12345678-1234-1234-1234-123456789012"` |
| `displayName` | string | Workspace name | `"Sales Analytics"` |
| `description` | string | Workspace description | `"Q1 2024 Reports"` |
| `type` | string | Workspace type | `"Workspace"` |
| `state` | string | Workspace state | `"Active"`, `"Deleted"` |
| `capacityId` | GUID | Assigned capacity | `"87654321-4321-4321-4321-210987654321"` |
| `domainId` | GUID | Assigned domain | `"11111111-2222-3333-4444-555555555555"` |

**Note:** `capacityId` and `domainId` require workspace enrichment (automatic when used in filters).

### Supported Operators

#### Comparison Operators
- `eq` - Equals
- `ne` - Not equals

#### Logical Operators
- `and` - Logical AND
- `or` - Logical OR

#### String Functions
- `contains(property, 'value')` - Contains substring
- `startswith(property, 'value')` - Starts with substring
- `endswith(property, 'value')` - Ends with substring

### Workspace Filter Examples

#### Filter by State
```json
"WorkspaceFilter": "(state eq 'Active')"
```

#### Filter by Name Pattern
```json
"WorkspaceFilter": "contains(displayName, 'Production')"
```

#### Multiple Conditions
```json
"WorkspaceFilter": "(state eq 'Active') and contains(displayName, 'Finance')"
```

#### Filter by Capacity
```json
"WorkspaceFilter": "(capacityId eq '12345678-1234-1234-1234-123456789012')"
```

#### Filter by Domain
```json
"WorkspaceFilter": "(domainId eq '11111111-2222-3333-4444-555555555555')"
```

#### Complex Filter
```json
"WorkspaceFilter": "(state eq 'Active') and (capacityId eq '12345678-1234-1234-1234-123456789012') and contains(displayName, 'Sales')"
```

#### No Filter (Export All)
```json
"WorkspaceFilter": ""
```

---

## Item Filtering

### Configuration Location

```json
{
  "ExportSettings": {
    "ItemTypes": ["Report", "SemanticModel", "Notebook"],
    "ItemFilter": "type eq 'Report'"
  }
}
```

### Filter Execution

Item filtering happens **after** `ItemTypes` filtering:

1. All workspace items are retrieved
2. Items are filtered by `ItemTypes` array (backward compatibility)
3. Items are filtered by `ItemFilter` expression (new capability)

### Available Properties

#### Standard Properties (Always Available)

| Property | Type | Description | Example Value |
|----------|------|-------------|---------------|
| `id` | GUID | Item unique identifier | `"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"` |
| `displayName` | string | Item name | `"Sales Report"` |
| `description` | string | Item description | `"Monthly sales analysis"` |
| `type` | string | Item type | `"Report"`, `"SemanticModel"`, etc. |
| `workspaceId` | GUID | Parent workspace ID | `"12345678-1234-1234-1234-123456789012"` |

#### Scanner API Properties (Requires EnableScannerAPI)

| Property | Type | Description | Requires Admin |
|----------|------|-------------|----------------|
| `createdBy` | string | Creator username/email | Yes |
| `modifiedBy` | string | Last modifier username/email | Yes |
| `configuredBy` | string | Configurator username/email | Yes |
| `createdDateTime` | datetime | Creation timestamp | Yes |
| `modifiedDateTime` | datetime | Last modified timestamp | Yes |

**Note:** Scanner API properties require:
- `"AdvancedFeatures.EnableScannerAPI": true` in configuration
- Admin permissions in Fabric tenant
- Scanner API implementation (future feature)

### Supported Operators

#### Type Filtering
- `type eq 'Report'` - Single type
- `type in ('Report', 'SemanticModel')` - Multiple types

#### String Functions (displayName, description)
- `contains(displayName, 'Sales')` - Contains substring
- `startswith(displayName, 'Prod')` - Starts with substring
- `endswith(displayName, '_Archive')` - Ends with substring

#### Scanner API Functions (Future)
- `createdBy eq 'user@domain.com'` - Filter by creator
- `modifiedBy eq 'user@domain.com'` - Filter by modifier
- `createdDate gt '2024-01-01'` - Filter by creation date
- `modifiedDate gt '2024-01-01'` - Filter by modification date

### Item Filter Examples

#### Filter by Type (Alternative to ItemTypes)
```json
"ItemFilter": "type eq 'Report'"
```

#### Multiple Types
```json
"ItemFilter": "type in ('Report', 'SemanticModel')"
```

#### Filter by Display Name Pattern
```json
"ItemFilter": "contains(displayName, 'Sales')"
```

#### Filter by Description
```json
"ItemFilter": "contains(description, 'Q1 2024')"
```

#### Starts With Pattern
```json
"ItemFilter": "startswith(displayName, 'Production')"
```

#### Ends With Pattern
```json
"ItemFilter": "endswith(displayName, '_Archive')"
```

#### No Filter (Use ItemTypes Only)
```json
"ItemFilter": ""
```

---

## Filter Syntax Reference

### OData Filter Syntax

Both workspace and item filters use **OData query syntax** for consistency with Microsoft Fabric REST API conventions.

### Operator Precedence

1. Function calls: `contains()`, `startswith()`, `endswith()`
2. Comparison: `eq`, `ne`, `in`
3. Logical AND: `and`
4. Logical OR: `or`

### Parentheses

Use parentheses to control evaluation order:

```
(state eq 'Active') and (capacityId eq 'guid' or domainId eq 'guid')
```

### String Literals

Always use **single quotes** for string values:

```
✅ "WorkspaceFilter": "type eq 'Workspace'"
❌ "WorkspaceFilter": "type eq \"Workspace\""
```

### Case Sensitivity

- Property names: Case-sensitive (`displayName` not `DisplayName`)
- String values: Case-sensitive matching
- Operators: Lowercase only (`eq` not `EQ`)

### Whitespace

Whitespace is flexible:

```
✅ "type eq 'Report'"
✅ "type eq'Report'"
✅ "type  eq  'Report'"
```

---

## Configuration Examples

### Example 1: Active Workspaces, Reports Only

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(state eq 'Active')",
    "ItemTypes": ["Report"],
    "ItemFilter": ""
  }
}
```

### Example 2: Specific Capacity, Sales Items

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(capacityId eq '12345678-1234-1234-1234-123456789012')",
    "ItemTypes": ["Report", "SemanticModel", "Notebook"],
    "ItemFilter": "contains(displayName, 'Sales')"
  }
}
```

### Example 3: Production Workspaces, Archive Items

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "contains(displayName, 'Production')",
    "ItemTypes": ["Report", "SemanticModel"],
    "ItemFilter": "endswith(displayName, '_Archive')"
  }
}
```

### Example 4: Specific Domain, Reports and Models

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(domainId eq '11111111-2222-3333-4444-555555555555')",
    "ItemTypes": ["Report", "SemanticModel"],
    "ItemFilter": "type in ('Report', 'SemanticModel')"
  }
}
```

### Example 5: Complex Workspace Filter, Simple Item Filter

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(state eq 'Active') and (capacityId eq '12345678-1234-1234-1234-123456789012') and contains(displayName, 'Finance')",
    "ItemTypes": ["Report", "SemanticModel", "KQLDashboard"],
    "ItemFilter": "startswith(displayName, 'FY2024')"
  }
}
```

### Example 6: No Filters (Export Everything)

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "",
    "ItemTypes": [
      "Report",
      "SemanticModel",
      "Notebook",
      "DataPipeline",
      "Dataflow"
    ],
    "ItemFilter": ""
  }
}
```

---

## Advanced Scenarios

### Scenario 1: Multi-Capacity Export

Export from multiple specific capacities:

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(capacityId eq 'capacity-guid-1') or (capacityId eq 'capacity-guid-2')",
    "ItemTypes": ["Report", "SemanticModel"],
    "ItemFilter": ""
  }
}
```

### Scenario 2: Exclude Pattern

Export everything **except** test workspaces:

**Current Limitation:** OData doesn't support `not contains()`. Workaround:

1. Use no workspace filter
2. Manually exclude after export, or
3. Use positive patterns only

### Scenario 3: Combine Type and Name Filters

Export Reports with specific naming pattern:

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "(state eq 'Active')",
    "ItemTypes": ["Report", "SemanticModel", "Notebook"],
    "ItemFilter": "(type eq 'Report') and contains(displayName, 'Executive')"
  }
}
```

**Note:** This example shows combining type filter in ItemFilter (instead of relying on ItemTypes array).

### Scenario 4: Description-Based Filtering

Export items with specific metadata in description:

```json
{
  "ExportSettings": {
    "WorkspaceFilter": "",
    "ItemTypes": ["Report", "SemanticModel"],
    "ItemFilter": "contains(description, 'Finance-Approved')"
  }
}
```

---

## Scanner API Enrichment

### Overview

The Fabric **Scanner API** provides rich metadata not available in the standard Items API, including:

- User information (creator, modifier, configurator)
- Timestamp information (created, modified dates)
- Additional governance metadata

### Requirements

1. **Admin Permissions** - Scanner API requires Fabric administrator role
2. **Configuration Flag** - Enable in config:
   ```json
   {
     "AdvancedFeatures": {
       "EnableScannerAPI": true
     }
   }
   ```
3. **Implementation** - Currently **not yet implemented** (placeholder exists)

### Future Filter Capabilities

Once Scanner API enrichment is implemented, you'll be able to filter by:

#### User-Based Filters

```json
"ItemFilter": "createdBy eq 'john.doe@company.com'"
```

```json
"ItemFilter": "modifiedBy eq 'jane.smith@company.com'"
```

```json
"ItemFilter": "contains(createdBy, '@company.com')"
```

#### Date-Based Filters

```json
"ItemFilter": "createdDate gt '2024-01-01'"
```

```json
"ItemFilter": "modifiedDate gt '2024-06-01'"
```

```json
"ItemFilter": "(createdDate gt '2024-01-01') and (createdDate lt '2024-12-31')"
```

#### Combined User and Date Filters

```json
"ItemFilter": "(createdBy eq 'admin@company.com') and (modifiedDate gt '2024-01-01')"
```

### Current Behavior

If you use user/date filters **without** enabling Scanner API:

```json
{
  "ItemFilter": "createdBy eq 'user@domain.com'"
}
```

You'll see warning messages:

```
WARNING: User/date filters require Scanner API enrichment.
         Enable 'AdvancedFeatures.EnableScannerAPI' in config.
WARNING: Only basic filters (type, name) will be applied.
```

The filter will be **safely ignored** and only basic filters will apply.

### Implementation Status

Current implementation in `Invoke-FABItemFilter` function:

```powershell
# Check if we need Scanner API enrichment for user/date filters
[bool]$needsEnrichment = $Filter -match "(createdBy|modifiedBy|createdDate|modifiedDate|configuredBy)"

if ($needsEnrichment) {
  Write-Host "  - Filter requires Scanner API enrichment for user/date metadata"

  if ($Config -and $Config.PSObject.Properties['AdvancedFeatures'] -and
      $Config.AdvancedFeatures.PSObject.Properties['EnableScannerAPI'] -and
      $Config.AdvancedFeatures.EnableScannerAPI) {
    Write-Host "  - Enriching items with Scanner API metadata..."
    # TODO: Implement Scanner API enrichment
    Write-Warning "Scanner API enrichment not yet implemented. User/date filters will be skipped."
  }
  else {
    Write-Warning "User/date filters require Scanner API enrichment."
    Write-Warning "Only basic filters (type, name) will be applied."
  }
}
```

### Contributing

Scanner API enrichment is tracked in GitHub Issue [#18: Incremental Archive](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/18).

If you'd like to contribute this feature, see:
- [Microsoft Fabric Scanner API Documentation](https://learn.microsoft.com/en-us/rest/api/fabric/admin/scanner)
- [Project Contributing Guidelines](.github/copilot-instructions.md)

---

## Testing Filters

### Dry Run Testing

To test filters without actually exporting:

1. Add verbose output to config:
   ```json
   {
     "FabricToolsSettings": {
       "ParallelProcessing": false
     }
   }
   ```

2. Check console output for filter results:
   ```
   Applying workspace filter: (state eq 'Active')
   Workspace filter result: 150 -> 120 workspaces

   Applying item filter: contains(displayName, 'Sales')
   Item filter result: 500 -> 45 items
   ```

### Validation

Before running large exports:

1. **Test workspace filter first** - Use restrictive filter to limit scope
2. **Check item counts** - Review console output for expected numbers
3. **Verify filter syntax** - Check for typos in property names
4. **Start small** - Test with single workspace before full tenant export

### Common Mistakes

| Issue | Solution |
|-------|----------|
| No items exported | Check ItemTypes array includes desired types |
| Too many items exported | Add ItemFilter to narrow selection |
| Workspace filter not working | Verify property names (case-sensitive) |
| Capacity filter not working | Ensure workspace enrichment is enabled (automatic) |

---

## Related Documentation

- [Workspace Filtering Guide](workspace-filtering-guide.md) - Detailed workspace filtering examples
- [Parallel Processing Guide](parallel-processing-guide.md) - Performance optimization
- [API Rate Limiting Guide](api-rate-limiting-guide.md) - Throttling and retry logic
- [README.md](../README.md) - Project overview and setup

---

## Support

For issues or questions:
- [GitHub Issues](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues)
- [Project Documentation](https://github.com/JamesDBartlett3/Fabric-Archive-Bot)

---

*Last Updated: 2025-12-04*
