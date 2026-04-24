## SaveMigrationRegistry — version chain for SaveContext schema upgrades.
##
## Ratified by ADR-0003 §Key Interfaces + §Schema Stability §Migration Callable Purity.
##
## RULES (BLOCKING — ADR-0003 §Migration Callable Purity):
##  - Migrations are PURE FUNCTIONS. They MUST operate only on the SaveContext
##    argument. Captured node, singleton, or object references are FORBIDDEN:
##    captured refs outlive the migration and leak for the process lifetime,
##    producing dangling references into freed scenes.
##  - Every from_version in 1..(CURRENT_SCHEMA_VERSION - 1) MUST have an entry.
##    Gaps (e.g. skipping version 2) mean pre-gap saves are unreachable — data loss.
##  - Chain must be complete: v1→v2→v3→…→CURRENT with no missing steps.
##
## TR-save-load-007 enforcement: Migration Callables in _migrations are pure
## functions; no captured node/singleton/object state permitted.
##
## MVP state: _migrations is intentionally empty. Schema is v1-origin.
## The first migration entry lands when schema_version v2 is cut (post-MVP).
##
## Example v1→v2 migration (doc-comment only — NOT active code):
##   1: func(ctx: SaveContext) -> SaveContext:
##       ctx.schema_version = 2
##       ctx.new_field_v2 = default_value_v2
##       return ctx,
##   PURE: reads and assigns only ctx fields; no captured refs whatsoever.
class_name SaveMigrationRegistry
extends RefCounted

# ── Registry ──────────────────────────────────────────────────────────────────

## Migration table: maps from_version (int) → migration Callable.
## Callable signature: func(ctx: SaveContext) -> SaveContext
##
## GDScript 4.x does not support generic Dictionary[int, Callable] syntax;
## the type annotation is enforced by convention and code-review gate only.
##
## PRODUCTION migrations MUST be pure functions — no captured refs permitted.
## TEST-ONLY: lambdas that capture a tracking Array[int] for invocation-order
## verification are acceptable in test code (Array is a reference type, so
## Array.append is G-4-compliant mutation, not primitive reassignment). These
## test lambdas are NEVER registered in production.
static var _migrations: Dictionary = {}

## Defensive max iteration count for _migrate_inner. A pathological Callable
## that fails to increment ctx.schema_version would infinite-loop without this
## guard, hanging the test runner (no GdUnit4 per-test timeout). 1000 is vastly
## higher than any realistic version chain (post-MVP schema changes are rare).
const _MAX_MIGRATION_STEPS: int = 1000

# ── Public methods ────────────────────────────────────────────────────────────

## Applies all needed migrations to bring ctx up to SaveManager.CURRENT_SCHEMA_VERSION.
## Delegates to _migrate_inner with the production target version.
## Idempotent: if ctx.schema_version >= CURRENT_SCHEMA_VERSION, returns ctx unchanged.
## On a missing migration step, emits GameBus.save_load_failed and returns ctx
## at the last successfully-migrated version (partial advance is preserved).
static func migrate_to_current(ctx: SaveContext) -> SaveContext:
	return _migrate_inner(ctx, SaveManager.CURRENT_SCHEMA_VERSION)

# ── Private methods ───────────────────────────────────────────────────────────

## Inner migration loop. Advances ctx.schema_version from its current value
## up to target_version by applying registered migration Callables in sequence.
##
## Exposed as a non-underscore-restricted static for test seam access:
## tests call SaveMigrationRegistry._migrate_inner(ctx, custom_target) to drive
## migration chain verification without mutating the production CURRENT_SCHEMA_VERSION
## constant (Option C per story-006 §Implementation Notes #7).
##
## Loop invariant: each iteration increments ctx.schema_version by exactly one
## step (the migration Callable is responsible for bumping the version field).
## If a Callable fails to bump the version, the loop will infinite-loop on that
## step — migration authors MUST increment ctx.schema_version before returning.
static func _migrate_inner(ctx: SaveContext, target_version: int) -> SaveContext:
	var iterations: int = 0
	while ctx.schema_version < target_version:
		# A-1 defensive iteration bound: a migration Callable that forgets to
		# increment ctx.schema_version would hang the runner without this guard.
		if iterations >= _MAX_MIGRATION_STEPS:
			push_error(
				"SaveMigrationRegistry: migration loop exceeded %d steps at v%d — Callable likely failed to increment ctx.schema_version"
				% [_MAX_MIGRATION_STEPS, ctx.schema_version]
			)
			GameBus.save_load_failed.emit(
				"load", "migration_loop_exceeded_at_v%d" % ctx.schema_version
			)
			return ctx
		iterations += 1

		var from_version: int = ctx.schema_version
		var step: Callable = _migrations.get(from_version, Callable())
		if not step.is_valid():
			GameBus.save_load_failed.emit(
				"load", "no_migration_from_v%d" % from_version
			)
			return ctx
		ctx = step.call(ctx) as SaveContext

		# A-2 null-return guard: if a migration Callable returns null (bug), the
		# next iteration's ctx.schema_version would null-deref. Surface the bug
		# via push_error + signal and return null so the load pipeline treats it
		# identically to the invalid_resource branch.
		if ctx == null:
			push_error(
				"SaveMigrationRegistry: migration Callable from v%d returned null (expected SaveContext)"
				% from_version
			)
			GameBus.save_load_failed.emit(
				"load", "migration_returned_null_from_v%d" % from_version
			)
			return null
	return ctx
