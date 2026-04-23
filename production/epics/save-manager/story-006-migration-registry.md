# Story 006: SaveMigrationRegistry + schema version chain

> **Epic**: save-manager
> **Status**: Ready
> **Layer**: Platform
> **Type**: Logic
> **Estimate**: 3-4 hours (migration registry shell + chain test + pure-function enforcement + integration with story-005 load path)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; authoritative spec is ADR-0003 §Decision + §Schema Stability §Migration Callable Purity)
**Requirement**: `TR-save-load-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 — §Key Interfaces (SaveMigrationRegistry) + §Schema Stability §Migration Callable Purity
**ADR Decision Summary**: "Static `SaveMigrationRegistry` holds `Dictionary[int, Callable(SaveContext) -> SaveContext]` mapping `from_version → migration_fn`. `migrate_to_current` applies migrations in sequence until `CURRENT_SCHEMA_VERSION`. Callables MUST be pure functions — no captured node/singleton/object state (leaks for registry lifetime)."

**Engine**: Godot 4.6 | **Risk**: LOW (Dictionary + Callable APIs pre-cutoff stable)
**Engine Notes**: `Callable.is_valid()` and `Callable.call()` both pre-cutoff. `static var _migrations: Dictionary` on a RefCounted-extending class is idiomatic for registries (confirmed against `docs/engine-reference/godot/modules/core.md`). Pure-function discipline is by convention, not compiler-enforced — code-review gate.

**Control Manifest Rules (Platform layer)**:
- Required: Migration Callables in `SaveMigrationRegistry` are pure functions — no captured node/singleton/object refs (TR-save-load-007)
- Required: Every schema change bumps `CURRENT_SCHEMA_VERSION` + adds migration function
- Forbidden: capturing node/singleton/object refs inside migration Callables (ADR-0003 §Schema Stability §Migration Callable Purity — BLOCKING)

## Acceptance Criteria

*Derived from ADR-0003 §Key Interfaces + §Validation Criteria V-6:*

- [ ] `src/core/save_migration_registry.gd` exists: `class_name SaveMigrationRegistry extends RefCounted`
- [ ] Declares `static var _migrations: Dictionary = {}` (initially empty — MVP schema is v1 origin; first migration lands when first breaking schema change arrives post-MVP)
- [ ] Implements `static func migrate_to_current(ctx: SaveContext) -> SaveContext` exactly per ADR §Key Interfaces:
  1. `current = SaveManager.CURRENT_SCHEMA_VERSION`
  2. Loop `while ctx.schema_version < current`:
     - `step = _migrations.get(ctx.schema_version, Callable())`
     - If `not step.is_valid()`: emit `GameBus.save_load_failed.emit("load", "no_migration_from_v%d" % ctx.schema_version)`; return ctx (unmigrated)
     - `ctx = step.call(ctx) as SaveContext`
  3. Return ctx
- [ ] Story-005 `load_latest_checkpoint` TODO comment resolved: calls `SaveMigrationRegistry.migrate_to_current(ctx)` before returning
- [ ] V-6: schema migration chain reaches CURRENT — test registers 3 fake migrations (v1→v2, v2→v3, v3→v4), sets `CURRENT_SCHEMA_VERSION = 4` via test seam, creates a v1 ctx, calls `migrate_to_current`, asserts final schema_version == 4 AND each migration ran exactly once
- [ ] Missing-step signaling: migration chain with a gap (v1→v2 registered, v2→v3 MISSING, CURRENT=3) emits `save_load_failed("load", "no_migration_from_v2")` and returns ctx unmodified beyond v2
- [ ] Pure-function discipline documentation: README comment block citing ADR-0003 §Migration Callable Purity + memory-leak rationale
- [ ] Unit test for registry purity contract: registered Callable that captures an outer Node reference → code-review REJECTS this pattern (documented in test comments as "this is the anti-pattern")

## Implementation Notes

*From ADR-0003 §Key Interfaces + §Schema Stability §Migration Callable Purity:*

1. **Registry is initially empty** — MVP schema is v1 origin; no migrations needed yet. First entry lands when schema_version v2 is cut (post-MVP schema addition). ADR-0003 §Migration Plan Phase 5 notes this is a post-MVP item.

2. **Pure-function contract is BLOCKING by convention** — GDScript does not enforce pure-function-ness. Code-review gate must reject:
   - Callables that reference a node outside the function body scope
   - Callables that call autoload methods (GameBus, SaveManager, etc.)
   - Callables that capture `self` or any object reference
   - Acceptable: Callables that reference only the `SaveContext` argument + built-in types

3. **Migration chain invariant** — for every `from_version` in `1..CURRENT-1`, there MUST be a `_migrations[v]` entry. Gap = data loss (pre-gap saves unreachable). V-6 test enforces.

4. **`migrate_to_current` idempotency** — calling on a ctx already at CURRENT_SCHEMA_VERSION is no-op (while loop exits immediately). Safe to call on any loaded ctx.

5. **Integration with story-005 `load_latest_checkpoint`** — this story unblocks story-005's deferred TODO. After this story lands, story-005's load pipeline is complete.

6. **Static-var access in tests** — `(load("res://src/core/save_migration_registry.gd") as GDScript).set("_migrations", test_dict)` pattern (precedent from gamebus story-005 diagnostics static-var test seam).

7. **CURRENT_SCHEMA_VERSION test seam** — to test migration chain, need to override `SaveManager.CURRENT_SCHEMA_VERSION` per-test. Options:
   - **A**: `SaveManager.CURRENT_SCHEMA_VERSION` is a const — cannot override. Test uses `SaveMigrationRegistry.migrate_to_current_with_target(ctx, target_version)` test-only overload.
   - **B**: Refactor `CURRENT_SCHEMA_VERSION` to a static var (not const) to allow test override. Not preferred — risks prod-code mutation.
   - **C**: Write `migrate_to_current_inner(ctx, target: int)` private helper + public `migrate_to_current(ctx)` delegates with SaveManager.CURRENT_SCHEMA_VERSION. Tests call `migrate_to_current_inner` directly with custom target.
   - Option C recommended; preserves prod contract integrity.

8. **Example Callable pattern** (to embed in migration file doc-comment, not implementation):
   ```gdscript
   # Example v1→v2 migration (lands when schema_version v2 is cut):
   # 1: func(ctx: SaveContext) -> SaveContext:
   #     ctx.schema_version = 2
   #     ctx.new_field_v2 = default_value_v2
   #     return ctx,
   # PURE: only reads ctx; only assigns ctx fields; no captured refs.
   ```

9. **G-10 N/A here** — this story's tests do not involve GameBus emit-handler-firing flows; they test the registry in isolation via direct method call. GameBus emit in failure path IS tested (missing-step case); that is a one-direction emit with no subscriber requirement in test.

## Out of Scope

- SaveContext / EchoMark classes — story 001
- Autoload skeleton — story 002
- Test stub — story 003
- Save pipeline — story 004
- Load pipeline skeleton — story 005 (this story fills in the migration call)
- Perf validation — story 007
- CI lint — story 008
- Actual v2+ migration Callables — post-MVP (when first schema change arrives)

## QA Test Cases

*Test file*: `tests/unit/core/save_migration_registry_test.gd`

- **AC-EMPTY** (MVP registry is empty; v1 ctx passes through unchanged):
  - Given: fresh `SaveMigrationRegistry`; ctx with `schema_version = 1`; CURRENT = 1
  - When: `migrate_to_current(ctx)`
  - Then: returns same ctx unchanged; no migration callables invoked; no emissions

- **AC-V6-CHAIN** (full migration chain reaches CURRENT):
  - Given: stub registry with `_migrations = {1: fn1_to_2, 2: fn2_to_3, 3: fn3_to_4}`; test target `CURRENT = 4` (via Option C inner helper); ctx with schema_version = 1; auxiliary counters per-migration
  - When: `migrate_to_current_inner(ctx, 4)`
  - Then: returned ctx has `schema_version == 4`; each counter incremented exactly once; order: fn1_to_2 ran before fn2_to_3 before fn3_to_4

- **AC-V6-MID-CHAIN** (migration from v2 works):
  - Given: same stub registry; ctx with `schema_version = 2`
  - When: `migrate_to_current_inner(ctx, 4)`
  - Then: returned ctx has `schema_version == 4`; fn1_to_2 NOT called; fn2_to_3 + fn3_to_4 called in order

- **AC-GAP** (missing-step emits save_load_failed):
  - Given: stub registry with `_migrations = {1: fn1_to_2}` (missing v2→v3); target CURRENT = 3; ctx with schema_version = 1
  - When: `migrate_to_current_inner(ctx, 3)` + capture `save_load_failed` via lambda
  - Then: fn1_to_2 runs (ctx.schema_version = 2); then gap detected; `save_load_failed` fires with `("load", "no_migration_from_v2")`; returned ctx has schema_version == 2 (stopped at gap, not further advanced)

- **AC-IDEMPOTENT** (already-current ctx is no-op):
  - Given: ctx with `schema_version = CURRENT`; registry with 1 migration (unused path)
  - When: `migrate_to_current(ctx)`
  - Then: returns ctx unchanged; no migration callables invoked

- **AC-INTEGRATION-STORY-005** (story-005 load pipeline calls migration):
  - Given: stub with registered test migration v1→v2; test CURRENT = 2; save ctx v1 via story-004 pipeline; ensure loaded file has schema_version = 1 on disk
  - When: `load_latest_checkpoint()` (via SaveManager)
  - Then: returned ctx has `schema_version == 2` (migration ran via load pipeline integration)

- **AC-PURITY-ANTI-PATTERN** (doc-comment example, not actual assertion):
  - Given: a Callable that captures an outer Node ref (anti-pattern)
  - When: documented inline as the REJECTED pattern
  - Then: code-review gate rejects PRs introducing this; no compile-time enforcement possible

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/save_migration_registry_test.gd` — 5 AC tests + 1 integration test pass (BLOCKING gate)
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: story-005 (load pipeline integrates migration at load-time)
- **Unlocks**: post-MVP schema changes (once v2 arrives, add migration Callable + test)
