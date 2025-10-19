# Compare-FabricItemDefinition.ps1 - Complete Guide

## Table of Contents

1. [Overview](#overview)
2. [Three Comparison Modes](#three-comparison-modes)
3. [Display Name Support](#display-name-support)
4. [Quick Reference](#quick-reference)
5. [Implementation Details](#implementation-details)
6. [Troubleshooting](#troubleshooting)

---

## Overview

`Compare-FabricItemDefinition.ps1` is a PowerShell tool that compares Microsoft Fabric item definitions from various sources, displaying differences in git-diff style with color-coded output.

### Key Features

✅ **Three Comparison Modes**: Cloud-to-Local, Cloud-to-Cloud, and Local-to-Local  
✅ **Display Name Support**: Use friendly names instead of GUIDs  
✅ **Smart Labeling**: Automatic or custom labels for comparison output  
✅ **Path Validation**: Ensures compatible item types (with bypass option)  
✅ **Git Integration**: Beautiful diff output using git (if available)

---

## Three Comparison Modes

### 🔵 CloudToLocal - Compare cloud item with local repository

Compare a Fabric workspace item with a local Git repository version. Perfect for checking deployment drift.

**Using Display Names (Recommended):**

```powershell
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "Production" `
  -Item "Sales Report" `
  -LocalPath "C:\Repos\MyReport.Report"
```

**Using GUIDs (Also Supported):**

```powershell
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "12345678-1234-1234-1234-123456789012" `
  -Item "87654321-4321-4321-4321-210987654321" `
  -LocalPath "C:\Repos\MyReport.Report"
```

### 🟢 CloudToCloud - Compare two cloud items

Compare two Fabric workspace items. Ideal for comparing DEV vs PROD or different versions.

**Using Display Names (Recommended):**

```powershell
# Compare same report in DEV vs PROD workspace
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "Development" `
  -Item "Sales Report" `
  -CompareWorkspace "Production" `
  -CompareItem "Sales Report" `
  -FirstItemLabel "DEV" `
  -SecondItemLabel "PROD"
```

**Compare Two Versions in Same Workspace:**

```powershell
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "Development" `
  -Item "Customer Model v1" `
  -CompareWorkspace "Development" `
  -CompareItem "Customer Model v2" `
  -FirstItemLabel "V1" `
  -SecondItemLabel "V2"
```

### 🟣 LocalToLocal - Compare two local repositories

Compare two local Git repository versions. Perfect for comparing archived versions or different branches. **No authentication required!**

**Compare Archived Versions:**

```powershell
.\Compare-FabricItemDefinition.ps1 `
  -LocalPath ".\Workspaces\2025\09\20\Black\MyReport.Report" `
  -CompareLocalPath ".\Workspaces\2025\10\18\Black\MyReport.Report" `
  -FirstItemLabel "Sept-20" `
  -SecondItemLabel "Oct-18"
```

**Compare Git Branches:**

```powershell
.\Compare-FabricItemDefinition.ps1 `
  -LocalPath "C:\Repos\main\MyReport.Report" `
  -CompareLocalPath "C:\Repos\feature\MyReport.Report" `
  -FirstItemLabel "MAIN" `
  -SecondItemLabel "FEATURE"
```

**Automatic Labels (Folder Names):**

```powershell
# Script generates smart labels automatically
.\Compare-FabricItemDefinition.ps1 `
  -LocalPath ".\Workspaces\2025\09\20\Black\MyReport.Report" `
  -CompareLocalPath ".\Workspaces\2025\09\23\Black\MyReport.Report"
```

---

## Display Name Support

### Overview

The script intelligently handles both **GUIDs** and **display names** for workspace and item parameters.

### Parameter Changes

| Old Parameter         | New Parameter       |
| --------------------- | ------------------- |
| `-WorkspaceId`        | `-Workspace`        |
| `-ItemId`             | `-Item`             |
| `-CompareWorkspaceId` | `-CompareWorkspace` |
| `-CompareItemId`      | `-CompareItem`      |

### How It Works

```
1. User provides: -Workspace "Production" -Item "Sales Report"
2. Script checks if input matches GUID pattern (regex)
3. If GUID → Use directly (fast, no API lookup)
4. If Name → Call Fabric API to resolve to GUID
5. Use resolved GUIDs for comparison
```

### Benefits

✅ **More Readable**: Scripts are much easier to understand  
✅ **User-Friendly**: No need to look up GUIDs in portal  
✅ **Flexible**: Mix names and GUIDs as needed  
✅ **Backward Compatible**: GUIDs still work perfectly  
✅ **Intelligent**: Automatic detection with clear errors

### Examples

**Display Names (Easy to Read):**

```powershell
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "Production" `
  -Item "Sales Report" `
  -LocalPath "C:\Repos\MyReport.Report"
```

**GUIDs (Still Supported):**

```powershell
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "12345678-1234-1234-1234-123456789012" `
  -Item "87654321-4321-4321-4321-210987654321" `
  -LocalPath "C:\Repos\MyReport.Report"
```

**Mixed (Use What's Convenient):**

```powershell
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "Production" `
  -Item "87654321-4321-4321-4321-210987654321" `
  -LocalPath "C:\Repos\MyReport.Report"
```

---

## Quick Reference

### Common Parameters

| Parameter             | Modes                      | Purpose                                 |
| --------------------- | -------------------------- | --------------------------------------- |
| `-Workspace`          | CloudToLocal, CloudToCloud | First workspace (GUID or name)          |
| `-Item`               | CloudToLocal, CloudToCloud | First item (GUID or name)               |
| `-LocalPath`          | CloudToLocal, LocalToLocal | First local path                        |
| `-CompareWorkspace`   | CloudToCloud               | Second workspace (GUID or name)         |
| `-CompareItem`        | CloudToCloud               | Second item (GUID or name)              |
| `-CompareLocalPath`   | LocalToLocal               | Second local path                       |
| `-ReverseDirection`   | All                        | Swap which item shows as "old" vs "new" |
| `-FirstItemLabel`     | All                        | Custom label for first item             |
| `-SecondItemLabel`    | All                        | Custom label for second item            |
| `-ForceReauth`        | Cloud modes                | Force re-authentication                 |
| `-SkipPathValidation` | LocalToLocal               | Allow comparing different item types    |
| `-Verbose`            | All                        | Show detailed processing information    |

### Understanding the Output

**Color Coding:**

- 🟢 **Green (+)**: Lines in the "new" version
- 🔴 **Red (-)**: Lines in the "old" version
- 🔵 **Cyan**: Context lines (unchanged)

**Default Direction:**

- **First item** = "old" (red -)
- **Second item** = "new" (green +)

**With -ReverseDirection:**

- **Second item** = "old" (red -)
- **First item** = "new" (green +)

### Path Validation (LocalToLocal Only)

By default, both paths must be the same item type:

- ✅ Both `.Report` folders → Allowed
- ✅ Both `.SemanticModel` folders → Allowed
- ❌ `.Report` vs `.SemanticModel` → Blocked

**Bypass validation:**

```powershell
.\Compare-FabricItemDefinition.ps1 `
  -LocalPath ".\MyReport.Report" `
  -CompareLocalPath ".\MyModel.SemanticModel" `
  -SkipPathValidation
```

### Smart Labels

If you don't provide labels, the script generates them automatically:

- **CloudToLocal**: "CLOUD" vs folder name with parent
- **CloudToCloud**: "ITEM1" vs "ITEM2"
- **LocalToLocal**: Folder name with parent folder in parentheses

Example: `MyReport.Report (Black)` vs `MyReport.Report (Blue)`

### File Paths

You can provide either:

- The item folder: `.\MyReport.Report`
- Any file inside: `.\MyReport.Report\report.json`

The script automatically uses the parent folder if you provide a file.

---

## Implementation Details

### New Helper Functions

#### `Test-FABIsGuid`

Detects if a string matches GUID pattern.

```powershell
function Test-FABIsGuid {
  param([string]$Value)
  $guidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  return $Value -match $guidPattern
}
```

#### `Get-FABWorkspaceId`

Resolves workspace name or GUID to GUID.

```powershell
function Get-FABWorkspaceId {
  param([string]$Workspace, [string]$AccessToken)
  # If GUID: returns it directly
  # If name: calls GET /v1/workspaces to find by displayName
  # Returns: workspace GUID
}
```

#### `Get-FABItemId`

Resolves item name or GUID to GUID.

```powershell
function Get-FABItemId {
  param([string]$WorkspaceId, [string]$Item, [string]$AccessToken)
  # If GUID: returns it directly
  # If name: calls GET /v1/workspaces/{id}/items to find by displayName
  # Returns: item GUID
}
```

#### `Get-FABSmartLabel`

Generates meaningful labels from paths.

```powershell
function Get-FABSmartLabel {
  param([string]$Path, [string]$SourceType)
  # For local: extracts folder name and parent
  # For cloud: returns "CLOUD" (could be enhanced to fetch names)
}
```

#### `Test-FABPathCompatibility`

Validates that both paths have the same item type.

```powershell
function Test-FABPathCompatibility {
  param([string]$Path1, [string]$Path2)
  # Extracts item type (e.g., ".Report") from folder names
  # Returns $true if both have same type
}
```

### Performance Considerations

**GUID Input (Fast):**

- CloudToLocal: 1 API call (Get Item Definition)
- CloudToCloud: 2 API calls (Get Item Definition × 2)
- LocalToLocal: 0 API calls (filesystem only)

**Display Name Input (Adds Lookups):**

- CloudToLocal: 3 API calls
  1. GET /v1/workspaces (find workspace)
  2. GET /v1/workspaces/{id}/items (find item)
  3. POST /v1/workspaces/{id}/items/{id}/getDefinition
- CloudToCloud: 6 API calls
  - 2 for first item lookup
  - 2 for second item lookup
  - 2 for Get Item Definition

For most use cases, the small overhead is worth the improved usability.

### Edge Cases Handled

**Multiple Items with Same Name:**

```
WARNING: Multiple items found with name 'Sales Report'. Using the first one: Report
```

Script warns and uses first match. Users can provide GUID for precision.

**Name Not Found:**

```
Error: Item 'Salse Report' not found in workspace. Please check the name and try again.
```

Clear error message helps identify typos.

**Case Sensitivity:**
Display name matching is case-sensitive (matches Fabric API behavior).

---

## Troubleshooting

### "Workspace not found" or "Item not found"

The display name you provided doesn't match exactly (names are case-sensitive).

**Solutions:**

- Check spelling and capitalization
- Use GUID instead of display name
- Use `-Verbose` to see the resolution process

### "Multiple items found with name..."

You have multiple items with the same name in the workspace. The script uses the first one.

**Solutions:**

- Use the item's GUID instead of display name for precision
- Rename items to have unique names

### "Item type mismatch"

You're comparing different item types (e.g., Report vs SemanticModel) in LocalToLocal mode.

**Solution:**

- Use `-SkipPathValidation` to bypass this check

### "Authentication failed"

Your Azure context expired or is invalid.

**Solutions:**

- Use `-ForceReauth` to re-authenticate
- Run `Connect-AzAccount` manually first

### "No differences found" (but you expect differences)

Both versions might be identical, or you might be comparing the wrong items.

**Solutions:**

- Use `-Verbose` to verify which files are being compared
- Check that you're using correct workspace/item names or GUIDs
- Verify file paths are correct for LocalToLocal mode

### Git diff not showing colors

The script uses git for diff formatting.

**Solutions:**

- Ensure Git is installed and in your PATH
- Verify your terminal supports ANSI colors
- Script falls back to simple diff if git not available

### "Path must be a directory"

You provided a path that doesn't exist or isn't a directory.

**Solutions:**

- Verify the path exists
- Use forward slashes or properly escaped backslashes
- You can provide a file path; script will use parent directory

---

## Tips & Best Practices

### Use Display Names for Readability

```powershell
# Easy to understand what's being compared
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "Development" `
  -Item "Sales Dashboard" `
  -CompareWorkspace "Production" `
  -CompareItem "Sales Dashboard" `
  -FirstItemLabel "DEV" `
  -SecondItemLabel "PROD"
```

### Use GUIDs for Scripting/Automation

When automating with scripts, GUIDs are more reliable (no name changes, no duplicates).

```powershell
# Automation script
$items = @(
  @{ Workspace = "guid1"; Item = "guid2"; Label = "DEV" }
  @{ Workspace = "guid3"; Item = "guid4"; Label = "PROD" }
)
```

### LocalToLocal Requires No Authentication

Perfect for offline analysis of archived versions!

```powershell
# Works without internet connection
.\Compare-FabricItemDefinition.ps1 `
  -LocalPath ".\Archive\2025-01\MyReport.Report" `
  -CompareLocalPath ".\Archive\2025-10\MyReport.Report"
```

### Use -Verbose for Debugging

See exactly what the script is doing:

```powershell
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "Production" `
  -Item "Sales Report" `
  -LocalPath "C:\Repos\MyReport.Report" `
  -Verbose
```

### Reverse Direction for Different Perspectives

```powershell
# Show local as "new" instead of cloud
.\Compare-FabricItemDefinition.ps1 `
  -Workspace "Production" `
  -Item "Sales Report" `
  -LocalPath "C:\Repos\MyReport.Report" `
  -ReverseDirection
```

---

## Requirements

- **PowerShell**: 7.0 or higher
- **Az.Accounts Module**: For cloud authentication (CloudToLocal and CloudToCloud modes)
- **Git** (Optional): For enhanced diff output
- **Fabric Permissions**: Read access to workspaces and items

---

## Version History

### v2.0 - October 2025

- ✨ Added CloudToCloud comparison mode
- ✨ Added LocalToLocal comparison mode
- ✨ Added display name support for workspace/item parameters
- 🔄 Renamed parameters: WorkspaceId→Workspace, ItemId→Item
- 🔄 Renamed parameter: LocalAsNew→ReverseDirection
- ✅ Added path validation for LocalToLocal mode
- ✅ Added smart label generation
- 📚 Comprehensive documentation and examples

### v1.0 - Original

- ✅ CloudToLocal comparison mode
- ✅ Git-style diff output
- ✅ Azure authentication support
