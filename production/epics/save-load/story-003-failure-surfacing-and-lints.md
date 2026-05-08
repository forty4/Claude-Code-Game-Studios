# Story 003: Failure Surfacing Tests + 3 Enforcement Lints + systems-index Row 17 Flip (Epic-Terminal)

> **Epic**: save-load (#17 Core)
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration (failure-injection tests are integration-tier; lint scripts are Config/Data tier; epic-terminal verification summary doc closes the epic)
> **Estimate**: 4-6 hours (3 lint scripts + integration test for AC-SL-15..17 disk-fail/corrupt/crash + systems-index row 17 flip + verification summary doc)
> **Manifest Version**: 2026-05-05

## Context

**GDD**: `design/gdd/save-load.md` rev 1.0 §3.3 Atomic Write Protocol (CR-SL-9..11) + §3.4 Live-State Safety + Migration Purity (CR-SL-12..14) + §3.7 Failure Surfacing (CR-SL-21..22) + §8.5 Failure Surfacing ACs (AC-SL-15..17) + §Implementation hooks 6/7/8 (3 enforcement lints) + 13 (failure surfacing test) + 16 (systems-index flip)
**Requirement**: `TR-save-load-016` + `TR-save-load-017` + `TR-save-load-018` + `TR-save-load-019` + `TR-save-load-020`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — will be added to registry at first /story-readiness invocation)*

**ADR Governing Implementation**: ADR-0003 (atomic write + CACHE_MODE_IGNORE + migration purity + @export discipline; failure surfacing via `save_load_failed`) + ADR-0001 (signal contract for `save_load_failed` Persistence-domain signal, already shipped at sprint-7 save-manager epic)
**ADR Decision Summary**:
- ADR-0003 §Constraints: "Failures never crash; emit save_load_failed and surface to player" — every error path returns gracefully (false from save_checkpoint, null from load_latest_checkpoint); subscribers (Main Menu error toast, in-game save indicator) translate the structured `reason` into player-facing localized strings.
- ADR-0003 §Schema Stability: every SaveContext + EchoMark field MUST be `@export`-annotated; non-exported fields are silently dropped by ResourceSaver. CR-SL-2 BLOCKING.
- ADR-0003 §Decision §Atomic Write step 3: every `ResourceLoader.load()` in save_manager.gd uses `CACHE_MODE_IGNORE`. CR-SL-11 BLOCKING.
- ADR-0003 §Schema Stability §Migration Callable Purity: migration callables in `_migrations` Dictionary MUST be pure functions with no captured node/singleton/object state. CR-SL-13 BLOCKING.
- ADR-0001: `save_load_failed(op: String, reason: String)` is the existing 3rd Persistence-domain signal; story-003 verifies its emission contract via integration test + any new emission sites added by story-002 (`save_loaded` failure path).

**Engine**: Godot 4.6 | **Risk**: LOW (lint scripts use existing bash patterns from `tools/ci/lint_*.sh` precedents — battle-hud + grid-battle-controller lint families; failure-injection testing uses existing test seam patterns)
**Engine Notes**: G-7 (silent-skip detection) APPLIES to lint smoke tests — verify `Overall Summary` test count delta when adding the 3 new lints. G-29 (post-cutoff API drift) does NOT apply — bash lint scripts don't touch Godot APIs.

**Control Manifest Rules (Core layer + CI lint family)**:
- Required: 3 NEW CI lint scripts wired into `.github/workflows/tests.yml` Linux Editor + Windows D3D12 lanes (per S10-05 binding decision: macOS / iOS / Android lanes deferred post-MVP; Linux + Windows are sufficient for save-load lint enforcement)
- Required: lint scripts return Exit 0 on PASS, Exit 1 on detected violation, follow `tools/ci/lint_*.sh` precedent format (header comment + flag/next awk pattern per TG-3 + clear violation reporting)
- Required: failure surfacing integration test uses test-side fixture mocks (forced ResourceSaver error code + truncated file + os._exit-like simulation via test seam) — does NOT actually crash the test process
- Required: epic-terminal verification summary doc at `production/qa/evidence/save_load_verification_summary.md` covering all 13 TRs (TR-save-load-008..020) per save-manager epic precedent (`production/qa/evidence/save_manager_verification_summary.md` style if exists, OR battle-hud verification summary doc style at `production/qa/evidence/battle_hud_verification_summary.md`)
- Forbidden: lint scripts that produce false-negatives via TG-3 awk range pattern self-closing (verify with `flag/next` pattern per `tools/ci/lint_input_router_g15_reset.sh` precedent)
- Forbidden: failure-injection tests that actually crash the test process or corrupt the dev-machine save directory (use `user://` test-mode override + RAM-only fixtures)
- Guardrail: post-cleanup test count must reflect +N lint smoke tests + ~3-4 integration tests (estimated +5-7 net new tests; baseline 1236 → 1241-1243)

---

## Acceptance Criteria

*From `design/gdd/save-load.md` §8.5 Failure Surfacing (verbatim AC text):*

- [ ] **AC-SL-15**: Given disk full simulated via test fixture (forced ResourceSaver error code), when `save_checkpoint(source)` is invoked, then return is `false` AND `save_load_failed.emit("save", "resource_saver_error:%d")` fires AND no partial file is left in `final_path` (`.tmp` may persist but extension filter hides it).
- [ ] **AC-SL-16**: Given a malformed SaveContext file in slot 1 (truncated mid-Resource), when `load_latest_checkpoint()` is invoked, then return is `null` AND `save_load_failed.emit("load", "invalid_resource:...")` fires. Caller surfaces error toast.
- [ ] **AC-SL-17**: Given a process kill simulated mid-write (test fixture: `os._exit()` between ResourceSaver.save and rename_absolute), when game restarts + `load_latest_checkpoint()` invokes, then loader skips the orphan `.tmp` AND returns the prior successful checkpoint OR `null` if no prior. Atomic invariant per EC-SL-1.

*Plus epic-terminal closure criteria:*

- [ ] **AC-LINT-CACHE_MODE_IGNORE**: `tools/ci/lint_save_resource_loader_cache_mode_ignore.sh` exists + executable + Exit 0 on main HEAD; Exit 1 on negative-test fixture (intentionally remove CACHE_MODE_IGNORE flag from one ResourceLoader.load call in save_manager.gd → re-run → assert Exit 1 → revert)
- [ ] **AC-LINT-MIGRATION_PURITY**: `tools/ci/lint_save_migration_callable_purity.sh` exists + executable + Exit 0 on main HEAD; Exit 1 on negative-test fixture (intentionally introduce captured-reference pattern in `_migrations` Dictionary → re-run → assert Exit 1 → revert)
- [ ] **AC-LINT-EXPORT_DISCIPLINE**: `tools/ci/lint_save_context_export_discipline.sh` exists + executable + Exit 0 on main HEAD; Exit 1 on negative-test fixture (intentionally remove `@export` annotation from one SaveContext or EchoMark field → re-run → assert Exit 1 → revert)
- [ ] **AC-CI-WIRING**: All 3 new lints wired into `.github/workflows/tests.yml` after the input-handling lint block; CI run completes Exit 0 with the 3 lints in PASS state
- [ ] **AC-INDEX-FLIP**: `design/gdd/systems-index.md` row 17 Status flips from `**Designed (rev 1.0 — 2026-05-05 sprint-8 S8-08)**` to `**Implemented (rev 1.0 — 2026-05-NN sprint-12 S12-?)**` with appropriate close-out note + linkage to this epic + verification summary
- [ ] **AC-VERIFICATION-SUMMARY**: `production/qa/evidence/save_load_verification_summary.md` exists + covers all 13 TRs (TR-save-load-008..020) + 7-engine-verification-item rollup per battle-hud precedent + ADVISORY deferrals inventory (if any)

---

## Implementation Notes

*From ADR-0003 + GDD §3.3 + §3.4 + §3.7 + §Implementation hooks 6/7/8 + 13 + 16:*

1. **Lint #6 — `tools/ci/lint_save_resource_loader_cache_mode_ignore.sh`** (CR-SL-11 enforcement):
   - Pattern: every `ResourceLoader.load(...)` call site in `src/core/save_manager.gd` (and any other save-load source file) MUST contain `CACHE_MODE_IGNORE` literal in the call args
   - Recipe: `grep -nE "ResourceLoader\.load\s*\(" src/core/save_manager.gd | grep -v "CACHE_MODE_IGNORE"` should return 0 hits
   - Exit code: 0 on PASS (0 hits in the grep -v); 1 on FAIL (any line missed CACHE_MODE_IGNORE) with violation report listing line numbers
   - Negative test recipe: edit one ResourceLoader.load to drop CACHE_MODE_IGNORE → re-run → assert Exit 1 with line number reported → revert

2. **Lint #7 — `tools/ci/lint_save_migration_callable_purity.sh`** (CR-SL-13 enforcement):
   - Pattern: `_migrations: Dictionary[int, Callable]` entries in `src/core/save_migration_registry.gd` MUST be lambda expressions OR static method references; any closure with captured non-static-context references is FORBIDDEN
   - Recipe: parse `_migrations` Dictionary entries; for each Callable value, verify it is either (a) `Callable(SomeClass.static_method_name)` OR (b) `func(ctx: SaveContext) -> SaveContext: ...` lambda WITHOUT capturing outer-scope identifiers
   - Heuristic: grep for `func(ctx:` in the migration registry; verify each lambda body does NOT reference identifiers outside `ctx` (excluding language keywords + standard library calls). False-positive risk acknowledged; pattern needs validation at /story-readiness time
   - Exit code: 0 on PASS (no captured-reference patterns detected); 1 on FAIL with line numbers
   - Negative test recipe: introduce `var captured_singleton = SaveManager` outside a lambda + reference inside → re-run → assert Exit 1 → revert

3. **Lint #8 — `tools/ci/lint_save_context_export_discipline.sh`** (CR-SL-2 enforcement):
   - Pattern: every `var <name>: <type>` declaration in `src/core/payloads/save_context.gd` AND `src/core/payloads/echo_mark.gd` (any future Resource-derived classes that participate in save serialization) MUST be preceded by `@export` annotation on the line above
   - Recipe: parse each file line-by-line; for each `^\s*var\s+\w+:` line, verify the prior non-empty non-comment line is `@export` OR `@export_*` variant
   - Exit code: 0 on PASS (every var line has @export prior); 1 on FAIL with line numbers + missing-annotation field names
   - Negative test recipe: remove `@export` from one SaveContext field → re-run → assert Exit 1 → revert

4. **Failure surfacing integration test** (`tests/integration/save_load/failure_surfacing_test.gd`):
   - **Test 1 (AC-SL-15 disk full)**: use a SaveManager test seam to inject a forced ResourceSaver error code at write time. SaveManager test seam may not yet exist; if so, add a test-only `_force_save_error: int = OK` field that ResourceSaver checks. Assert: save_checkpoint returns false; capture `save_load_failed` emission with op="save" + reason starting with "resource_saver_error:". Verify .tmp may persist but final_path does NOT exist post-error.
   - **Test 2 (AC-SL-16 truncated file)**: write a valid SaveContext, then corrupt the file on disk by truncating to half-size via FileAccess.open + truncate. Call load_latest_checkpoint; assert null return + save_load_failed emission with op="load" + reason starting with "invalid_resource:".
   - **Test 3 (AC-SL-17 mid-write crash)**: simulate via writing a `.tmp` file directly without renaming (acts as orphan from a hypothetical crash). Call load_latest_checkpoint; assert loader skips the orphan .tmp + returns prior successful checkpoint OR null. Verify orphan .tmp is NOT renamed/deleted by the loader (per CR-SL-9 cleanup is save-side responsibility).
   - Edge cases: zero-byte file (FileAccess.get_length() == 0), wrong-type Resource (e.g., a non-SaveContext Resource saved at the slot path), permissions-denied write (skip if platform doesn't support; document as platform-specific test).

5. **CI wiring** (`.github/workflows/tests.yml`):
   - Add 3 new lint invocations after the existing input-handling lint block (per battle-hud + grid-battle-controller wiring precedent)
   - Each lint runs as a separate step with `- name: Run lint_save_*.sh` + `run: bash tools/ci/lint_save_*.sh` + Exit 0 expected
   - Verify locally before pushing: run all 3 lints on main HEAD → all Exit 0

6. **systems-index row 17 flip** (per CR-SL-?? + GDD §Implementation hooks 16):
   - Edit `design/gdd/systems-index.md` row 17 (Save/Load System) Status cell from `**Designed (rev 1.0 — 2026-05-05 sprint-8 S8-08)**` to `**Implemented (rev 1.0 — 2026-05-NN sprint-12 S12-?)**`
   - Add close-out note: "Implementation epic at `production/epics/save-load/EPIC.md` 3/3 stories shipped; verification summary at `production/qa/evidence/save_load_verification_summary.md`"
   - Update Notes column or footer with linkage to this epic-terminal close

7. **Verification summary doc** at `production/qa/evidence/save_load_verification_summary.md`:
   - Mirror battle-hud verification summary structure: epic outcome rollup + per-engine-verification-item closure markers + master inventory of lints + ADVISORY deferrals + AC-coverage table + cross-system closure markers + epic status + co-author tag
   - 13 TRs covered (TR-save-load-008..020) — produce a TR coverage table linking each TR to story + AC + test/lint
   - ADVISORY items inventory: any deferred items from this epic (e.g., MVP scope didn't ship scenario_path_key live composition; mid-battle autosave deferred per OQ-SL-1; cloud-sync deferred per OQ-SL-2)
   - Epic-terminal commit message references this doc

8. **Test pattern caveats**:
   - G-10 (autoload identifier binding): tests subscribing to `save_load_failed` must emit on real GameBus, not on a stub
   - G-28 (bulk-disconnect-all): tests must NOT bulk-disconnect; use cached-Callable pattern
   - G-7 (silent-skip detection): verify Overall Summary test count delta when running the full suite post-implementation

---

## Out of Scope

*Handled by neighbouring stories or already shipped — do not implement here:*

- **Story 001** (CP-1/2/3 emission contract): ScenarioRunner emission shipped in story-001; story-003 tests subscribe to the existing emissions for failure-injection scenarios but does not implement them.
- **Story 002** (Cross-chapter continuity): Destiny State populator + save_loaded signal addition. Story 003 verifies save_loaded null-payload handling + save_load_failed emission contract via integration tests, but does not author the populator or signal.
- **save-manager epic** (already 8/8 Complete): SaveManager autoload + atomic write protocol + ResourceSaver/Loader call sites. Story 003 adds lint enforcement on the existing call sites, NOT new save/load logic.
- **Mid-battle autosave** (per OQ-SL-1): explicitly deferred to post-MVP; out of scope.
- **Cloud sync** (per OQ-SL-2): deferred to post-launch live-ops scope; out of scope.
- **Save Slot UI metadata extensions** (per OQ-SL-4): Save Slot UI authoring is Alpha-tier per systems-index #18; out of scope for this Core epic.
- **Soft-delete vs hard-delete** (per OQ-SL-5): Save Slot UI's wipe button decision; out of scope.

---

## QA Test Cases

*Lean-mode skipped QL-STORY-READY gate; test specs derived from GDD ACs + epic-terminal precedent.*

**Story Type: Integration — automated test specs**

- **AC-SL-15** (disk full):
  - Given: SaveManager test seam configured to force ResourceSaver.save() to return ERR_FILE_NO_SPACE; valid SaveContext source
  - When: `SaveManager.save_checkpoint(source)` invoked
  - Then: return value is `false`; `GameBus.save_load_failed` captures 1 emission with op == "save" AND reason starts with "resource_saver_error:"; `FileAccess.file_exists(final_path)` returns false (no partial file at final path)
  - Edge cases: ERR_PERMISSION_DENIED (different error code; still emits save_load_failed with appropriate reason); ERR_OUT_OF_MEMORY

- **AC-SL-16** (truncated file):
  - Given: Valid SaveContext written to slot_1; file then corrupted by FileAccess truncate to half-length
  - When: `SaveManager.load_latest_checkpoint()` invoked
  - Then: return value is `null`; `GameBus.save_load_failed` captures 1 emission with op == "load" AND reason starts with "invalid_resource:"
  - Edge cases: zero-byte file (length 0); wrong Resource type (non-SaveContext .res file); valid file but missing required field (post-migration scenario)

- **AC-SL-17** (mid-write crash simulation):
  - Given: `final_path + ".tmp"` file exists on disk (orphan from hypothetical crash); no `final_path` exists; OR `final_path` exists from prior successful checkpoint
  - When: `SaveManager.load_latest_checkpoint()` invoked
  - Then: loader skips the .tmp orphan; returns prior successful checkpoint if any, else null. Orphan .tmp file remains on disk (not auto-deleted by loader)
  - Edge cases: only .tmp exists with no prior final_path → null return; multiple .tmp orphans across slots → each slot's loader is independent

- **AC-LINT-CACHE_MODE_IGNORE** (lint smoke):
  - Given: `tools/ci/lint_save_resource_loader_cache_mode_ignore.sh` exists + executable
  - When: lint runs on main HEAD
  - Then: Exit 0; stdout reports zero violations
  - When: lint runs after intentionally removing CACHE_MODE_IGNORE from one call site
  - Then: Exit 1; stdout reports the violating line number; revert + re-run returns Exit 0

- **AC-LINT-MIGRATION_PURITY** (lint smoke):
  - Given: `tools/ci/lint_save_migration_callable_purity.sh` exists + executable
  - When: lint runs on main HEAD with `_migrations` Dictionary using only static methods or pure lambdas
  - Then: Exit 0
  - When: lint runs after intentionally introducing a captured-reference closure
  - Then: Exit 1 with line number; revert + re-run returns Exit 0

- **AC-LINT-EXPORT_DISCIPLINE** (lint smoke):
  - Given: `tools/ci/lint_save_context_export_discipline.sh` exists + executable
  - When: lint runs on main HEAD with all SaveContext + EchoMark fields @export-annotated
  - Then: Exit 0
  - When: lint runs after intentionally removing @export from one field
  - Then: Exit 1 with field name + line number; revert + re-run returns Exit 0

- **AC-CI-WIRING**:
  - Given: 3 new lint invocations added to `.github/workflows/tests.yml`
  - When: CI run completes on main HEAD
  - Then: all 3 lint steps Exit 0; total CI run Exit 0

- **AC-INDEX-FLIP**:
  - Given: `design/gdd/systems-index.md` row 17 Status currently `**Designed (rev 1.0 — 2026-05-05 sprint-8 S8-08)**`
  - When: epic-terminal close-out commit lands
  - Then: row 17 Status equals `**Implemented (rev 1.0 — 2026-05-NN sprint-12 S12-?)**` with linkage note

- **AC-VERIFICATION-SUMMARY**:
  - Given: epic-terminal close-out commit lands
  - When: file `production/qa/evidence/save_load_verification_summary.md` is checked
  - Then: file exists; contains TR coverage table for TR-save-load-008..020; contains AC coverage table for AC-SL-1..20; contains ADVISORY deferral inventory; mirrors battle-hud verification summary structure

---

## Test Evidence

**Story Type**: Integration (failure-injection) + Config/Data (lint scripts)
**Required evidence**:
- Integration: `tests/integration/save_load/failure_surfacing_test.gd` — must exist and pass; ~3 test functions (one per AC-SL-15/16/17) + ~4-6 edge case tests = 7-9 tests total
- Lint smoke: `tests/unit/tools_ci/lint_save_load_smoke_test.gd` (NEW) — must exist and pass; ~3-6 smoke tests (1 PASS + 1 negative-test per lint × 3 lints)
- Verification summary doc: `production/qa/evidence/save_load_verification_summary.md` — epic-terminal mandatory artifact

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**:
  - **Story 001** (CP-1/2/3 emission) — provides the emission framework; AC-SL-15 disk-full test triggers via CP-2 emission
  - **Story 002** (Cross-chapter continuity + save_loaded signal) — provides save_loaded for null-payload handling tests (failure path emits save_load_failed instead of save_loaded)
  - save-manager epic 8/8 Complete — atomic write protocol + SaveManager test seam (test seam may need extension at /story-readiness if not present)
- **Unlocks**: epic-terminal close — `production/epics/save-load/EPIC.md` 3/3 stories ship + systems-index row 17 flip Designed → Implemented + verification summary doc
