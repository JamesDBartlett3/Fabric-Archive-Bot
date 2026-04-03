# Fabric Archive Bot v2 Release Plan

**Created:** 2026-04-02
**Branch:** `jdb/FAB2dev#15` (current, strictly ahead of `jdb/FABv2dev`)

---

## Phase 1: Stabilize & Merge

- [x] **1.1 — Verify core module end-to-end**
  Fixed: ghost export, config key mismatch (`FabricToolsSettings` → `FabricPSPBIPSettings`), missing `LoggingSettings`, double-counting bug, null guard in `Get-FABOptimalThrottleLimit`, `[AllowEmptyCollection()]` on `Export-FABWorkspaceMetadata`.

- [x] **1.2 — Get Pester tests running**
  77 unit tests across 7 test files, all passing. CI workflow re-enabled.

- [x] **1.3 — Close completed GitHub issues**
  Closed #10, updated #15 with Scanner API deferral note.

- [ ] **1.4 — Run integration tests against a live Fabric tenant**
  Run `tests/Invoke-IntegrationTests.ps1` from a machine with tenant access.
  38 tests across 8 phases: config, item type detection, auth, workspace retrieval, workspace filtering, item filtering, export (serial + parallel), logging.
  Fix any failures found.

- [ ] **1.5 — Open PR from `jdb/FAB2dev#15` → `main`**
  Create the v2 pull request with a summary of all changes since v1.

---

## Phase 2: Release

- [ ] **2.1 — Final review and merge the PR**

- [ ] **2.2 — Tag `v2.0.0` on main**
  Write release notes (leverage existing CHANGELOG.md).

- [ ] **2.3 — Clean up dev branches**
  Delete `jdb/FABv2dev` and `jdb/FAB2dev#15` after merge.

---

## Phase 3: Post-Release Enhancements (by priority)

| Priority | Issue | Description |
|----------|-------|-------------|
| High | #15 (remainder) | Scanner API integration for user-based and date-range filters |
| High | #18 | Incremental Archive (also requires Scanner API) |
| High | #17 | Cloud Storage (OneDrive, Blob, ADLS Gen2, OneLake) |
| High | #16 | Restore From Archive |
| Medium | #5 | Archive items as zip files |
| Medium | #11 | Generate PBIP files |
| Medium | #3 | Paginated Reports |
| Low | #12 | Support file paths for Config & Ignore parameters |
| Low | #2 | Documentation improvements |
| Low | #1 | Azure Function deployment |
| Low | #19 | Port to Python / Notebook |
