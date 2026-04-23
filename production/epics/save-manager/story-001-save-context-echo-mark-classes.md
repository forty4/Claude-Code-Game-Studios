# Story 001: SaveContext + EchoMark Resource classes

> **Epic**: save-manager
> **Status**: Complete
> **Layer**: Platform
> **Type**: Logic
> **Estimate**: 2-3 hours (2 Resource classes + 1 unit test; spec is verbatim from ADR-0003)
> **Actual**: ~2h specialist + ~0.5h code-review round-2 correction = ~2.5h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; authoritative spec is ADR-0003 §Key Interfaces. EchoMark field list is a downstream concern from `design/gdd/scenario-progression.md`; MVP impl ships a minimal echo-archive-compatible EchoMark — reviewers confirm against the scenario-progression GDD at `/story-done` time.)
**Requirement**: `TR-save-load-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 — §Key Interfaces + §Schema Stability
**ADR Decision Summary**: "SaveContext is a typed Resource with schema_version + all fields `@export`. EchoMark MUST extend Resource, declare `class_name EchoMark`, and annotate every persisted field with `@export`. Non-exported fields are silently dropped by ResourceSaver."

**Engine**: Godot 4.6 | **Risk**: LOW (pre-cutoff Resource + @export APIs)
**Engine Notes**: `@export` annotation required on every persisted field — non-@export fields are SILENTLY DROPPED by ResourceSaver with no warning (ADR-0003 §Schema Stability). `Array[EchoMark]` round-trip requires that EchoMark declares `class_name EchoMark` (without `class_name`, Godot falls back to untyped storage on load).

**Control Manifest Rules (Platform layer)**:
- Required: All SaveContext fields annotated `@export`; EchoMark extends Resource with `class_name EchoMark` + full `@export` coverage (TR-save-load-002)
- Required: Payload typing rule — SaveContext has ≥2 fields, so typed Resource class (ADR-0001 TR-gamebus-001)
- Forbidden: untyped `Dictionary`, `Array`, or `Variant` for persisted fields (ADR-0001 payload discipline)

## Acceptance Criteria

*Derived from ADR-0003 §Key Interfaces + §Schema Stability + §Validation Criteria V-3:*

- [ ] `src/core/save_context.gd` exists: `class_name SaveContext extends Resource`
- [ ] SaveContext declares these fields with `@export`, matching ADR-0003 §Key Interfaces verbatim:
  - `schema_version: int = 1`
  - `slot_id: int = 1`
  - `chapter_id: StringName = &""`
  - `chapter_number: int = 1`
  - `last_cp: int = 1`
  - `outcome: int = 0`
  - `branch_key: StringName = &""`
  - `echo_count: int = 0`
  - `echo_marks_archive: Array[EchoMark] = []`
  - `flags_to_set: PackedStringArray = PackedStringArray()`
  - `saved_at_unix: int = 0`
  - `play_time_seconds: int = 0`
- [ ] `src/core/echo_mark.gd` exists: `class_name EchoMark extends Resource`
- [ ] EchoMark declares at minimum these fields with `@export` (exact schema TBD by scenario-progression epic; MVP baseline):
  - `beat_index: int = 0`
  - `outcome: StringName = &""`
  - `tag: StringName = &""`
- [ ] EchoMark has full `@export` coverage — no non-annotated persisted fields
- [ ] `godot --headless --import` exit 0 with both classes registered (`class_name` globals resolve)
- [ ] V-3 lint compatibility: every field in `echo_mark.gd` is `@export`-annotated (grep-check in story-008)

## Implementation Notes

*From ADR-0003 §Key Interfaces + §Schema Stability:*

1. **Field list is verbatim from ADR** — SaveContext field declarations MUST match ADR-0003 §Key Interfaces. Default values, type annotations, and ordering all preserved.

2. **EchoMark MVP schema is intentionally narrow** — scenario-progression epic will evolve EchoMark fields via the migration registry (story-006). This story ships a 3-field minimum to unblock SaveContext serialization tests in story-004. Schema additions without `@export` silently drop — story-008 CI lint guards.

3. **`class_name EchoMark` is BLOCKING per ADR-0003 §Schema Stability** — without it, `Array[EchoMark]` round-trip stores elements as untyped `RefCounted` on load. Code-review gate: grep for `class_name EchoMark` in echo_mark.gd.

4. **No `class_name` collision** — neither `SaveContext` nor `EchoMark` is an autoload, so `class_name` is safe (unlike `GameBus` / `SceneManager` — G-3 only applies to autoload scripts).

5. **Resource default values** — prefer literal defaults (`1`, `&""`, `[]`, `PackedStringArray()`) over `null`. Rationale: Resource constructors instantiated by `Resource.new()` must produce a valid serializable state on day 1.

6. **Gamebus payload compatibility** — `save_checkpoint_requested(source: SaveContext)` signal (ADR-0003 GameBus amendment) consumes SaveContext directly. Story-001 of this epic ships the typed payload; the `save_checkpoint_requested` signal slot itself already exists on GameBus as a PROVISIONAL stub (per gamebus story-001 payload inventory; ratified by ADR-0003). Verify via `grep "save_checkpoint_requested" src/core/game_bus.gd`.

## Out of Scope

- Autoload declaration — story 002
- Stub helper for tests — story 003
- Save pipeline (`duplicate_deep` + `ResourceSaver.save`) — story 004
- Load pipeline — story 005
- Migration registry (`SaveMigrationRegistry`) — story 006
- Perf validation — story 007
- CI lint — story 008

## QA Test Cases

*Test file*: `tests/unit/core/save_context_test.gd` (mirror of gamebus `payload_classes_test.gd` pattern)

- **AC-1** (SaveContext class registration):
  - Given: `--import` succeeds
  - When: instantiate via `SaveContext.new()` and read `get_script().resource_path`
  - Then: returns `res://src/core/save_context.gd` with `class_name SaveContext` globally resolved

- **AC-2** (SaveContext default values match ADR-0003 §Key Interfaces):
  - Given: `var ctx := SaveContext.new()`
  - When: read each field
  - Then: `schema_version == 1`, `slot_id == 1`, `chapter_number == 1`, `last_cp == 1`, `outcome == 0`, `echo_count == 0`, `saved_at_unix == 0`, `play_time_seconds == 0`, `chapter_id == &""`, `branch_key == &""`, `echo_marks_archive == []`, `flags_to_set == PackedStringArray()`

- **AC-3** (SaveContext @export coverage):
  - Given: `SaveContext.new().get_property_list()`
  - When: filter where `usage & PROPERTY_USAGE_STORAGE`
  - Then: includes all 12 declared persisted fields (verify by name match)

- **AC-4** (EchoMark class registration + class_name global):
  - Given: `--import` succeeds
  - When: instantiate `EchoMark.new()` and read `get_script().resource_path`
  - Then: returns `res://src/core/echo_mark.gd` with `class_name EchoMark` globally resolved

- **AC-5** (EchoMark @export coverage — V-3 equivalent assertion):
  - Given: `EchoMark.new().get_property_list()`
  - When: filter where `usage & PROPERTY_USAGE_STORAGE`
  - Then: matches the declared field count exactly (if schema drifts, test fails)

- **AC-6** (SaveContext.echo_marks_archive element type):
  - Given: `var ctx := SaveContext.new()`
  - When: `ctx.echo_marks_archive.append(EchoMark.new())` and read `typeof(ctx.echo_marks_archive[0])`
  - Then: element is `EchoMark` instance (not generic Object)
  - Edge case: appending a non-EchoMark Resource should fail type check (Godot runtime narrowing via `Array[EchoMark]`)

- **AC-7** (SaveContext payload compatibility with GameBus):
  - Given: `grep "save_checkpoint_requested" src/core/game_bus.gd`
  - When: inspect signal declaration
  - Then: signature takes `source: SaveContext` (not untyped Resource); gamebus provisional stub slot still exists — ratified by ADR-0003 amendment (per §GameBus Signal Amendments)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/save_context_test.gd` — must exist and pass (BLOCKING gate)
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: gamebus epic Complete on main (provisional `save_checkpoint_requested` slot exists on GameBus)
- **Unlocks**: Stories 002-008 (all consume SaveContext + EchoMark types)

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 8/8 story-header ACs + 7/7 QA test cases passing
**Test Evidence**: `tests/unit/core/save_context_test.gd` (212 LoC, 7 tests + `_get_user_storage_fields` helper) — 107/107 suite pass, 0 errors, 0 failures, 0 orphans, exit 0
**Files delivered**:
- `src/core/payloads/save_context.gd` (59 LoC) — REPLACES gamebus story-002 PROVISIONAL stub at same path
- `src/core/payloads/echo_mark.gd` (25 LoC) — REPLACES gamebus story-002 PROVISIONAL stub at same path
- `tests/unit/core/save_context_test.gd` (212 LoC, NEW)

**Deviations (all ADVISORY)**:
1. **Path correction**: Story §Files-to-Create + EPIC.md §Scope stated `src/core/save_context.gd` + `src/core/echo_mark.gd`, but actual implementation lives at `src/core/payloads/*.gd` per pre-existing gamebus story-002 stub coordination comment ("intentionally stable so save-manager epic Story 001 replaces this stub seamlessly"). Stub path takes precedence; EPIC.md §Scope worth updating.
2. **AC-6 invalid-append edge case deferred** to story-004 serialization tests. Godot 4.6 Array[T] runtime rejection uses `push_error` + silent drop — reliable interception in GdUnit4 v6.1.2 not available. Rationale documented inline in test function docstring.
3. **Round-2 code-review fix applied**: B-1 (schema-drift detection via `_get_user_storage_fields()` baseline subtraction — G-1 pattern applied to properties instead of signals), S-1 (8 doc comments), S-3/S-4 (cosmetic cleanups), Gap 1 (AC-6 deferral documented).

**Code Review**: Complete (standalone `/code-review` 2026-04-23 — CHANGES REQUIRED → APPROVED after Option A fixes + round-2 path correction)

**Gates skipped** (lean mode): QL-TEST-COVERAGE, LP-CODE-REVIEW phase-gates (standalone `/code-review` already ran with 2 specialists)

**Manifest Version compliance**: 2026-04-20 matches current — no staleness

**New gotcha candidate (G-12 — not yet codified)**: **Godot 4.6 silent class_name collision resolution**. Two files declaring the same `class_name` produce NO parse error; Godot resolves via first-registered-wins silently. Only detected via combined `resource_path` + field-content assertions. Discovered when save-manager story-001 specialist wrote files to `src/core/` but pre-existing stubs at `src/core/payloads/` won the registry race, masking the mismatch until test AC-2/AC-3 failures revealed the empty stub was being tested. Candidate for `.claude/rules/godot-4x-gotchas.md` as G-12 on next recurrence — one occurrence is not yet pattern.
