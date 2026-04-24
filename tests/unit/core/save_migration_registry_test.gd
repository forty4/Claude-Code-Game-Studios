extends GdUnitTestSuite

## save_migration_registry_test.gd
## Unit tests for Story 006 (SaveMigrationRegistry + schema version chain).
##
## Covers AC-EMPTY, AC-V6-CHAIN, AC-V6-MID-CHAIN, AC-GAP, AC-IDEMPOTENT per
## story-006 §QA Test Cases.
##
## GOTCHA AWARENESS:
##   G-3 — SaveMigrationRegistry IS a class_name'd RefCounted, NOT an autoload.
##          `class_name SaveMigrationRegistry` is correct and causes no autoload
##          collision. Direct SaveMigrationRegistry._migrate_inner(ctx, n) access
##          is valid — leading underscore is convention-only in GDScript.
##   G-4 — lambda captures use Array[int].append (reference-type mutation),
##          not primitive reassignment. Appending to a captured Array propagates
##          correctly across the closure boundary.
##   G-6 — no Node instances created in this suite (pure static class under test);
##          no orphan-detector risk. _reset_migrations() called at the start of
##          every test body to guarantee isolation from any prior failing test.
##
## STATIC-VAR SEAM:
##   SaveMigrationRegistry._migrations is a static var on the GDScript object.
##   Set via (load(PATH) as GDScript).set("_migrations", ...) — established
##   pattern from story-005 diagnostics. Direct class_name access used for method
##   calls; GDScript.set() used for static-var injection.
##
## TEST-ONLY LAMBDA PATTERN:
##   Each test registers inline lambdas that capture an Array[int] for invocation-
##   order tracking. This capture pattern is G-4-compliant in test code. It would
##   be REJECTED in production migrations (TR-save-load-007): production Callables
##   MUST NOT capture any ref — arrays, nodes, singletons, or objects.

const MIGRATION_REGISTRY_PATH: String = "res://src/core/save_migration_registry.gd"


# ── Helpers ───────────────────────────────────────────────────────────────────


## Clears _migrations static var to {} before each test.
## Guarantees isolation: a failing test that leaves _migrations populated
## does not corrupt the Given state of the next test.
func _reset_migrations() -> void:
	(load(MIGRATION_REGISTRY_PATH) as GDScript).set("_migrations", {})


## Injects a test migration table into the static var seam.
func _set_migrations(table: Dictionary) -> void:
	(load(MIGRATION_REGISTRY_PATH) as GDScript).set("_migrations", table)


## Constructs a minimal SaveContext with schema_version set to the given value.
func _make_ctx(schema_version: int) -> SaveContext:
	var ctx: SaveContext = SaveContext.new()
	ctx.schema_version = schema_version
	ctx.chapter_number = 1
	ctx.last_cp = 1
	return ctx


# ── AC-EMPTY ──────────────────────────────────────────────────────────────────


## AC-EMPTY: empty registry with ctx already at target version passes through unchanged.
## Given: _migrations = {}; ctx with schema_version = 1; target = 1 (== CURRENT).
## When:  migrate_to_current(ctx) — target == CURRENT_SCHEMA_VERSION == 1.
## Then:  returns ctx unchanged (schema_version still 1); no signal emitted.
func test_save_migration_registry_empty_registry_v1_passes_through_unchanged() -> void:
	# Arrange
	_reset_migrations()
	var ctx: SaveContext = _make_ctx(1)
	var signal_fired: Array[String] = []
	GameBus.save_load_failed.connect(
		func(op: String, reason: String) -> void:
			signal_fired.append("%s:%s" % [op, reason]),
		CONNECT_ONE_SHOT
	)

	# Act
	var result: SaveContext = SaveMigrationRegistry.migrate_to_current(ctx)

	# Assert
	assert_int(result.schema_version).override_failure_message(
		"schema_version must remain 1 through empty registry; got %d" % result.schema_version
	).is_equal(1)
	assert_bool(signal_fired.is_empty()).override_failure_message(
		"save_load_failed must not fire on empty registry with v1 ctx; got %s" % str(signal_fired)
	).is_true()

	# Cleanup
	_reset_migrations()


# ── AC-V6-CHAIN ───────────────────────────────────────────────────────────────


## AC-V6-CHAIN: full 3-step migration chain advances ctx from v1 to v4.
## Given: _migrations = {1: fn1_to_2, 2: fn2_to_3, 3: fn3_to_4}; ctx v1; target = 4.
## When:  _migrate_inner(ctx, 4).
## Then:  schema_version == 4; each migration ran exactly once; order = [1, 2, 3].
func test_save_migration_registry_full_chain_reaches_current() -> void:
	# Arrange
	_reset_migrations()
	var order: Array[int] = []
	var fn1_to_2 := func(c: SaveContext) -> SaveContext:
		order.append(1)
		c.schema_version = 2
		return c
	var fn2_to_3 := func(c: SaveContext) -> SaveContext:
		order.append(2)
		c.schema_version = 3
		return c
	var fn3_to_4 := func(c: SaveContext) -> SaveContext:
		order.append(3)
		c.schema_version = 4
		return c
	_set_migrations({1: fn1_to_2, 2: fn2_to_3, 3: fn3_to_4})
	var ctx: SaveContext = _make_ctx(1)

	# Act
	var result: SaveContext = SaveMigrationRegistry._migrate_inner(ctx, 4)

	# Assert — final version
	assert_int(result.schema_version).override_failure_message(
		"Expected schema_version 4 after full chain; got %d" % result.schema_version
	).is_equal(4)
	# Assert — invocation count
	assert_int(order.size()).override_failure_message(
		"Expected exactly 3 migration invocations; got %d (%s)" % [order.size(), str(order)]
	).is_equal(3)
	# Assert — invocation order
	assert_int(order[0]).override_failure_message(
		"First migration must be fn1_to_2 (appends 1); got %d" % order[0]
	).is_equal(1)
	assert_int(order[1]).override_failure_message(
		"Second migration must be fn2_to_3 (appends 2); got %d" % order[1]
	).is_equal(2)
	assert_int(order[2]).override_failure_message(
		"Third migration must be fn3_to_4 (appends 3); got %d" % order[2]
	).is_equal(3)

	# Cleanup
	_reset_migrations()


# ── AC-V6-MID-CHAIN ───────────────────────────────────────────────────────────


## AC-V6-MID-CHAIN: starting from v2 skips fn1_to_2 and runs only remaining steps.
## Given: same registry {1,2,3}; ctx v2; target = 4.
## When:  _migrate_inner(ctx, 4).
## Then:  schema_version == 4; order == [2, 3] (fn1_to_2 never invoked).
func test_save_migration_registry_mid_chain_from_v2_runs_remaining_only() -> void:
	# Arrange
	_reset_migrations()
	var order: Array[int] = []
	var fn1_to_2 := func(c: SaveContext) -> SaveContext:
		order.append(1)
		c.schema_version = 2
		return c
	var fn2_to_3 := func(c: SaveContext) -> SaveContext:
		order.append(2)
		c.schema_version = 3
		return c
	var fn3_to_4 := func(c: SaveContext) -> SaveContext:
		order.append(3)
		c.schema_version = 4
		return c
	_set_migrations({1: fn1_to_2, 2: fn2_to_3, 3: fn3_to_4})
	var ctx: SaveContext = _make_ctx(2)

	# Act
	var result: SaveContext = SaveMigrationRegistry._migrate_inner(ctx, 4)

	# Assert — final version
	assert_int(result.schema_version).override_failure_message(
		"Expected schema_version 4 from mid-chain start; got %d" % result.schema_version
	).is_equal(4)
	# Assert — fn1_to_2 was NOT called
	assert_bool(order.has(1)).override_failure_message(
		"fn1_to_2 must NOT run when starting from v2; order = %s" % str(order)
	).is_false()
	# Assert — fn2_to_3 and fn3_to_4 ran in order
	assert_int(order.size()).override_failure_message(
		"Expected exactly 2 migration invocations from v2; got %d (%s)" % [order.size(), str(order)]
	).is_equal(2)
	assert_int(order[0]).override_failure_message(
		"First invocation must be fn2_to_3 (appends 2); got %d" % order[0]
	).is_equal(2)
	assert_int(order[1]).override_failure_message(
		"Second invocation must be fn3_to_4 (appends 3); got %d" % order[1]
	).is_equal(3)

	# Cleanup
	_reset_migrations()


# ── AC-GAP ────────────────────────────────────────────────────────────────────


## AC-GAP: missing migration step emits save_load_failed and stops at the gap.
## Given: _migrations = {1: fn1_to_2} only (v2→v3 missing); ctx v1; target = 3.
## When:  _migrate_inner(ctx, 3).
## Then:  fn1_to_2 runs (ctx advances to v2); save_load_failed fires with
##        ("load", "no_migration_from_v2"); returned ctx has schema_version == 2.
func test_save_migration_registry_gap_emits_save_load_failed() -> void:
	# Arrange
	_reset_migrations()
	var order: Array[int] = []
	var fn1_to_2 := func(c: SaveContext) -> SaveContext:
		order.append(1)
		c.schema_version = 2
		return c
	_set_migrations({1: fn1_to_2})

	var signal_args: Array = []
	var capture := func(op: String, reason: String) -> void:
		signal_args.append([op, reason])
	GameBus.save_load_failed.connect(capture, CONNECT_ONE_SHOT)

	var ctx: SaveContext = _make_ctx(1)

	# Act
	var result: SaveContext = SaveMigrationRegistry._migrate_inner(ctx, 3)

	# Assert — fn1_to_2 ran (chain advanced before gap)
	assert_bool(order.has(1)).override_failure_message(
		"fn1_to_2 must run before gap is detected; order = %s" % str(order)
	).is_true()
	# Assert — signal fired exactly once
	assert_int(signal_args.size()).override_failure_message(
		"save_load_failed must fire exactly once at gap; got %d emissions" % signal_args.size()
	).is_equal(1)
	# Assert — signal payload
	assert_str(signal_args[0][0]).override_failure_message(
		"save_load_failed op must be 'load'; got '%s'" % signal_args[0][0]
	).is_equal("load")
	assert_str(signal_args[0][1]).override_failure_message(
		"save_load_failed reason must be 'no_migration_from_v2'; got '%s'" % signal_args[0][1]
	).is_equal("no_migration_from_v2")
	# Assert — ctx stopped at v2 (did not advance past gap)
	assert_int(result.schema_version).override_failure_message(
		"ctx must stop at schema_version 2 (gap boundary); got %d" % result.schema_version
	).is_equal(2)

	# Cleanup — disconnect in case CONNECT_ONE_SHOT did not fire (belt-and-suspenders)
	if GameBus.save_load_failed.is_connected(capture):
		GameBus.save_load_failed.disconnect(capture)
	_reset_migrations()


# ── AC-IDEMPOTENT ─────────────────────────────────────────────────────────────


## AC-IDEMPOTENT: ctx already at target version is returned unchanged; no migration runs.
## Given: _migrations = {1: fn_that_should_not_run}; ctx schema_version = 2; target = 2.
## When:  _migrate_inner(ctx, 2).
## Then:  returned ctx unchanged (schema_version still 2); order.is_empty().
func test_save_migration_registry_already_current_is_noop() -> void:
	# Arrange
	_reset_migrations()
	var order: Array[int] = []
	var fn_that_should_not_run := func(c: SaveContext) -> SaveContext:
		order.append(1)
		c.schema_version = 2
		return c
	_set_migrations({1: fn_that_should_not_run})
	var ctx: SaveContext = _make_ctx(2)

	# Act
	var result: SaveContext = SaveMigrationRegistry._migrate_inner(ctx, 2)

	# Assert — no migration ran
	assert_bool(order.is_empty()).override_failure_message(
		"No migration must run when ctx.schema_version >= target; order = %s" % str(order)
	).is_true()
	# Assert — ctx unchanged
	assert_int(result.schema_version).override_failure_message(
		"schema_version must remain 2 on idempotent call; got %d" % result.schema_version
	).is_equal(2)

	# Cleanup
	_reset_migrations()
