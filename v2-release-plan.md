# Fabric Archive Bot v2 Release Plan

**Created:** 2026-04-02
**Branch:** `jdb/FAB2dev#15` (current, strictly ahead of `jdb/FABv2dev`)

---

## Phase 1: Stabilize & Merge

- [ ] **1.1 — Verify core module end-to-end**
  Review `Start-FabricArchiveBot.ps1` and `modules/FabricArchiveBotCore.psm1` for broken references, dead code paths, or obvious gaps.

- [ ] **1.2 — Get Pester tests running**
  Re-enable `.github/workflows/test.yml.disabled`, fix any failing tests, ensure at least the happy path is covered for core functions.

- [ ] **1.3 — Close completed GitHub issues**
  - Close #10 (Error Handling & Logging — done)
  - Update #15 (Filtering) to reflect Scanner API work is deferred to a future release

- [ ] **1.4 — Open PR from `jdb/FAB2dev#15` → `main`**
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
