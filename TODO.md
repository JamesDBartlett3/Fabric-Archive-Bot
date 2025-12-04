# Fabric Archive Bot - TODO List

This document tracks planned features, enhancements, and issues for the Fabric Archive Bot project.

## Priority Legend

- 🔴 **Critical** - Core functionality issues
- 🟡 **High** - Important enhancements affecting usability
- 🟢 **Medium** - Nice-to-have improvements
- 🔵 **Low** - Future considerations

## Active Issues (From GitHub)

### 🔴 Critical Priority

#### [#10: Error Handling & Logging](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/10)
**Status:** ✅ COMPLETED (2025-12-04)
**Current State:** Comprehensive logging framework implemented
**Completed Requirements:**
- [x] Add structured logging framework (custom implementation) ✅
- [x] Implement try/catch blocks throughout export process ✅
- [x] Create error reports and summaries ✅
- [x] Add retry logic for transient failures (beyond rate limiting) ✅
- [x] Log export success/failure metrics ✅
- [x] Support log levels (Verbose, Info, Warning, Error) ✅

**Implementation Details:**
- Created `Initialize-FABLogging`, `Write-FABLog`, `Start-FABOperation`, `Complete-FABOperation`, `Get-FABLogSummary`, `Export-FABLogSummary` functions
- Updated `Invoke-FABRateLimitedOperation` to use structured logging with automatic retry for rate limiting and transient failures
- Enhanced `Start-FABFabricArchiveProcess`, `Remove-FABOldArchives`, `Send-FABArchiveNotification` with operation tracking
- Added `LoggingSettings` configuration section to `FabricArchiveBot_Config.json`
- Created comprehensive [error-handling-and-logging-guide.md](docs/error-handling-and-logging-guide.md)
- Session tracking includes: ErrorCount, WarningCount, SuccessCount, FailureCount, Operations history
- Automatic JSON export of session summaries with full operation details

**Effort:** Medium
**Impact:** High - Significantly improves production reliability and observability

---

### 🟡 High Priority

#### [#18: Incremental Archive](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/18)
**Status:** Open | Labels: `enhancement`, `help-wanted`, `hacktoberfest`
**Requirements:**
- [ ] Add `ModifiedDate` property to JSON metadata
- [ ] Implement Scanner API integration for change detection
- [ ] Track item modification history
- [ ] Export only changed items
- [ ] Maintain backup versioning
- [ ] Update configuration schema for incremental mode

**Effort:** High
**Impact:** High - Reduces export time and storage for large tenants

**Notes:** Complex feature requiring significant refactoring. May need to maintain state between runs.

---

#### [#17: Cloud Storage](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/17)
**Status:** Open | Labels: `enhancement`, `help-wanted`, `hacktoberfest`
**Requirements:**
- [ ] Support OneDrive/SharePoint destinations
- [ ] Support Azure Blob Storage
- [ ] Support ADLS Gen2
- [ ] Support OneLake
- [ ] Abstract storage layer for pluggable backends
- [ ] Update configuration schema for storage targets
- [ ] Add authentication for each storage type

**Effort:** High
**Impact:** High - Enables production deployment scenarios

---

#### [#15: New Filter Criteria Options](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/15)
**Status:** Partially Complete | Labels: `enhancement`, `hacktoberfest`
**Assigned:** JamesDBartlett3
**Current State:** Item-level filtering implemented with OData-style syntax
**Requirements:**
- [x] Item type filters (more granular than current ItemTypes config) ✅ (COMPLETED)
- [ ] User-based filters (filter by owner/creator) - Requires Scanner API enrichment
- [ ] Date range filters (modified within X days) - Requires Scanner API enrichment
- [x] Capacity assignment filters ✅ (COMPLETED - recently added)
- [x] Domain assignment filters ✅ (COMPLETED - recently added)
- [x] Combine multiple filter criteria with AND/OR logic ✅ (COMPLETED)

**Effort:** Medium
**Impact:** Medium - Improves targeting of exports

**Completed Work:**
- Created `Invoke-FABItemFilter` function in [FabricArchiveBotCore.psm1:431-556](modules/FabricArchiveBotCore.psm1:431-556)
- Supports: `type eq/in`, `contains()`, `startswith()`, `endswith()` for displayName and description
- Integrated into [Export-FABFabricItemsAdvanced:910-918](modules/FabricArchiveBotCore.psm1:910-918)
- Added ItemFilter configuration to [FabricArchiveBot_Config.json:21-31](FabricArchiveBot_Config.json:21-31)
- Created comprehensive [filtering-guide.md](docs/filtering-guide.md)
- Added Scanner API enrichment placeholder for future user/date filtering

**Remaining Work:**
- Scanner API integration for user-based filters (see issue [#18: Incremental Archive](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/18))
- Scanner API integration for date-based filters (see issue [#18: Incremental Archive](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/18))

---

#### [#16: Restore From Archive](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/16)
**Status:** Open | Labels: `enhancement`, `help-wanted`, `hacktoberfest`
**Requirements:**
- [ ] Create new restoration script
- [ ] Support item-level restoration
- [ ] Support workspace-level restoration
- [ ] Support tenant-level restoration
- [ ] Allow date selection for point-in-time recovery
- [ ] Handle conflicts (overwrite vs. create new)
- [ ] Validate restored items

**Effort:** High
**Impact:** Medium - Completes the backup/restore cycle

**Notes:** Requires FabricPS-PBIP's Import-FabricItem or equivalent API calls.

---

### 🟢 Medium Priority

#### [#5: Archive Items as Zip Files](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/5)
**Status:** Open | Labels: `enhancement`
**Requirements:**
- [ ] Archive each item in its own zip file
- [ ] Configurable: compress at item vs. workspace vs. tenant level
- [ ] Update metadata to track compressed archives
- [ ] Support extraction for restore operations
- [ ] Maintain folder structure within archives

**Effort:** Low
**Impact:** Medium - Reduces storage footprint and simplifies downloads

---

#### [#11: Generate PBIP Files](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/11)
**Status:** Open | Labels: `enhancement`, `good-first-issue`
**Requirements:**
- [ ] Automatically generate .pbip files for archived reports
- [ ] Automatically generate .pbip files for archived semantic models
- [ ] Include proper folder structure and metadata
- [ ] Test with Power BI Desktop import

**Effort:** Low
**Impact:** Low - Convenience feature for Power BI Desktop users

**Notes:** Good first issue for new contributors.

---

#### [#12: Support File Paths for Config & Ignore Parameters](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/12)
**Status:** Open | Labels: `enhancement`
**Current State:** Configuration supports JSON file or PSCustomObject, but not file paths as parameters
**Requirements:**
- [ ] Allow JSON file paths as alternative to PSCustomObject for `-Config` parameter
- [ ] Allow JSON file paths for ignore lists
- [ ] Validate file existence and format
- [ ] Update documentation with examples

**Effort:** Low
**Impact:** Low - Minor usability improvement

---

#### [#3: Paginated Reports](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/3)
**Status:** Open | Labels: `enhancement`, `hacktoberfest`
**Requirements:**
- [ ] Add support for Paginated Report files (.rdl)
- [ ] Check if Fabric API supports paginated report export
- [ ] Update supported item types list
- [ ] Test export/restore cycle

**Effort:** Low (if API supports it)
**Impact:** Low - Niche feature for SSRS-style reports

**Notes:** Depends on Microsoft Fabric API support. Check [Get Item Definition API docs](https://learn.microsoft.com/en-us/rest/api/fabric/articles/item-management/definitions/item-definition-overview).

---

### 🔵 Low Priority

#### [#1: Azure Function](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/1)
**Status:** Open | Labels: `enhancement`
**Requirements:**
- [ ] Refactor for serverless execution model
- [ ] Handle authentication in Azure context (Managed Identity)
- [ ] Manage state across function invocations
- [ ] Support timer triggers for scheduling
- [ ] Update deployment documentation

**Effort:** High
**Impact:** Low - Alternative deployment model

**Notes:** Requires significant architectural changes. Consider after core features stabilize.

---

#### [#2: Documentation](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/2)
**Status:** Open | Labels: `documentation`
**Requirements:**
- [ ] Comprehensive README for local deployment
- [ ] Azure Functions deployment guide (if/when implemented)
- [ ] Configuration reference documentation
- [ ] API usage examples
- [ ] Troubleshooting guide
- [ ] Architecture diagram

**Effort:** Medium
**Impact:** Medium - Improves onboarding and reduces support burden

---

#### [#19: Port to Python with Notebook Execution](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues/19)
**Status:** Open | Labels: `hacktoberfest`, `refactor`
**Requirements:**
- [ ] Complete rewrite in Python
- [ ] Execute as Fabric Notebook
- [ ] Use Semantic Link for API interactions
- [ ] Store archives in OneLake (Lakehouse)
- [ ] Schedule via Data Pipeline
- [ ] Maintain feature parity with PowerShell version

**Effort:** Very High
**Impact:** Low - Alternative implementation approach

**Notes:** This would be a parallel project, not a replacement for the PowerShell version. Consider as a separate repository or branch.

---

## Recently Completed

### ✅ Error Handling & Logging Framework (Issue #10)
- **Completed:** 2025-12-04
- Implemented comprehensive structured logging framework with 6 core functions:
  - `Initialize-FABLogging` - Session initialization with configuration
  - `Write-FABLog` - Core logging with levels (Verbose, Info, Warning, Error, Success)
  - `Start-FABOperation` / `Complete-FABOperation` - Operation tracking with timing
  - `Get-FABLogSummary` - Real-time session statistics
  - `Export-FABLogSummary` - JSON export of complete session report
- Enhanced retry logic in `Invoke-FABRateLimitedOperation` with structured logging
- Added operation tracking to main orchestration functions
- Created `LoggingSettings` configuration section with file logging support
- Session tracking includes: ErrorCount, WarningCount, SuccessCount, FailureCount, Operations
- Created comprehensive [docs/error-handling-and-logging-guide.md](docs/error-handling-and-logging-guide.md)
- Automatic retry with exponential backoff for rate limiting (429) and transient failures (503, 502, timeout)
- Session summaries exported to timestamped JSON files with full operation history

### ✅ Item-Level Filtering (Issue #15 - Partial)
- **Completed:** 2025-12-04
- Created `Invoke-FABItemFilter` function with OData-style filter syntax
- Implemented support for:
  - Type filtering: `type eq 'Report'`, `type in ('Report', 'SemanticModel')`
  - Name pattern matching: `contains()`, `startswith()`, `endswith()` on displayName
  - Description filtering: `contains()` on description
  - Logical operators: `and`, `or` for combining criteria
- Integrated into [Export-FABFabricItemsAdvanced:910-918](modules/FabricArchiveBotCore.psm1:910-918)
- Updated [FabricArchiveBot_Config.json](FabricArchiveBot_Config.json) with ItemFilter examples
- Created comprehensive [docs/filtering-guide.md](docs/filtering-guide.md)
- Added Scanner API enrichment placeholder for future user/date filters
- See [Invoke-FABItemFilter](modules/FabricArchiveBotCore.psm1:431-556) for implementation

### ✅ Workspace Filtering Enhancements
- **Completed:** 2024-12-04 (recent commit: `76e7170`)
- Added support for filtering by `capacityId`
- Added support for filtering by `domainId`
- Implemented workspace enrichment to fetch detailed information when needed
- See [Invoke-FABWorkspaceFilter](modules/FabricArchiveBotCore.psm1:298-429) for implementation

### ✅ Enhanced Item Definition Parsing
- **Completed:** 2024-12-04 (recent commit: `421e699`)
- Improved `Get-FABItemDefinition` function with deeper JSON parsing
- Enhanced error handling

### ✅ MCP Server Configuration
- **Completed:** 2024-12-04 (recent commit: `e66f62e`)
- Added Microsoft Fabric MCP server configuration in `.vscode/mcp.json`

### ✅ Previous Completed Issues (From GitHub)
- **#4:** Notebooks support
- **#6:** Parameterization
- **#7:** Convert Model.bim to TMDL
- **#8:** Large tenant support
- **#9:** Support installing dotnet-core
- **#14:** Replace FabricPS-PBIP (Closed - Not Planned)
- **#20:** Enhanced Compare-FabricItemDefinition.ps1 (PR Merged)
- **#13:** Add changeauthor.sh (PR Merged)

---

## Testing & Quality

### Testing Framework (Currently Not Implemented)
From [.github/copilot-instructions.md:73-82](. github/copilot-instructions.md), testing is temporarily disabled pending framework setup.

**Requirements:**
- [ ] Set up Pester 5.x framework
- [ ] Ensure PowerShell 7+ compatibility
- [ ] Mock `Start-Sleep` and external API calls for fast execution
- [ ] Create unit tests for all public functions
- [ ] Create integration tests for end-to-end scenarios
- [ ] Add test coverage reporting
- [ ] Configure CI/CD pipeline for automated testing

**Effort:** Medium
**Impact:** High - Essential for code quality and maintainability

---

## Development Guidelines

When working on these items, follow the [.github/copilot-instructions.md](.github/copilot-instructions.md):

- **Module Dependencies:** Use FabricPS-PBIP for all Fabric operations
- **Function Naming:** All custom functions MUST use "FAB" prefix (e.g., `Get-FABWorkspaces`)
- **Approved Verbs:** Use only PowerShell-approved verbs (Get, Set, Invoke, Start, etc.)
- **Variable Usage:** All declared variables must be used
- **Configuration:** Store configuration as compressed JSON in environment variables or files
- **Error Handling:** Implement robust error handling with clear messages
- **Performance:** Use parallel processing where appropriate (PowerShell 7+ required)

---

## Contributing

Issues labeled with `hacktoberfest` are good candidates for open-source contributions.
Issues labeled with `good-first-issue` are suitable for new contributors.
Issues labeled with `help-wanted` are priorities where community help is appreciated.

See the repository's [Issues page](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues) for the latest status.

---

## References

- [GitHub Issues](https://github.com/JamesDBartlett3/Fabric-Archive-Bot/issues)
- [FabricPS-PBIP Module](https://github.com/microsoft/Analysis-Services/tree/master/pbidevmode/fabricps-pbip)
- [Microsoft Fabric REST API Documentation](https://learn.microsoft.com/en-us/rest/api/fabric/)
- [Get Item Definition API](https://learn.microsoft.com/en-us/rest/api/fabric/articles/item-management/definitions/item-definition-overview)

---

*Last Updated: 2025-12-04*
