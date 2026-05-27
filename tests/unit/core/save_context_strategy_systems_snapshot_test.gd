## save_context_strategy_systems_snapshot_test.gd
##
## S91 Phase B step 8b — round-trip persistence of the new SaveContext fields
## per_hero_inventory_snapshot + per_hero_pending_buff_snapshot. Strategy
## Systems v0.3 §6.1 cross-doc obligation row 6 (save-load.md schema extension).
##
## Coverage:
##   - In-memory default — both fields default to empty Dictionary {}
##   - ResourceSaver/Loader round-trip preserves Dict[int -> Array[StringName]]
##   - Per-hero pending_buff Dict shape (kind/magnitude/expires_at_turn) survives
##   - Empty-slot sentinel (&"") preserved through serialization
##   - Mid-chapter use_item snapshot (slot 0 → "", slots 1-2 intact) — EC-SS-9
##
## Mirrors save_manager_test.gd round-trip pattern via SaveManagerStub.swap_in.
extends GdUnitTestSuite

const SaveManagerStubScript: GDScript = preload("res://tests/unit/core/save_manager_stub.gd")


# ─── Default values ───────────────────────────────────────────────────────────


## Fresh SaveContext has both snapshot fields = empty Dictionary. Regression
## safe — older saves without these fields load with the same default.
func test_save_context_strategy_systems_snapshot_default_empty() -> void:
	var ctx: SaveContext = SaveContext.new()

	assert_bool(ctx.per_hero_inventory_snapshot.is_empty()).override_failure_message(
		"step 8b: per_hero_inventory_snapshot must default to empty Dictionary "
		+ "(backward-safe for older saves without this field)"
	).is_true()
	assert_bool(ctx.per_hero_pending_buff_snapshot.is_empty()).override_failure_message(
		"step 8b: per_hero_pending_buff_snapshot must default to empty Dictionary "
		+ "(backward-safe for older saves without this field)"
	).is_true()


# ─── Round-trip: per_hero_inventory_snapshot ─────────────────────────────────


## Populated inventory snapshot survives ResourceSaver → ResourceLoader cycle.
## Mid-chapter use_item snapshot pattern (EC-SS-9): unit 0 used heal_potion
## (slot 0 = ""), unit 1 untouched (full inventory). Round-trip preserves
## post-decrement state.
func test_save_context_inventory_snapshot_round_trips_via_resource_saver() -> void:
	# Arrange
	var stub: Node = SaveManagerStubScript.swap_in()
	stub.set_active_slot(1)

	var ctx: SaveContext = SaveContext.new()
	ctx.chapter_id = &"ch01"
	ctx.chapter_number = 1
	ctx.last_cp = 1
	# Unit 0: heal_potion consumed (slot 0 empty); slots 1-2 intact.
	# Unit 1: untouched starting inventory.
	ctx.per_hero_inventory_snapshot = {
		0: [&"", &"strength_scroll", &"march_scroll"] as Array[StringName],
		1: [&"heal_potion", &"heal_potion", &""] as Array[StringName],
	}

	# Act
	var loaded: SaveContext = _save_and_load(stub, ctx)

	# Assert
	assert_object(loaded).override_failure_message(
		"step 8b: round-trip must succeed (loaded != null)"
	).is_not_null()
	if loaded == null:
		SaveManagerStubScript.swap_out()
		return

	assert_int(loaded.per_hero_inventory_snapshot.size()).override_failure_message(
		"step 8b: snapshot must preserve both hero entries through round-trip"
	).is_equal(2)

	# Unit 0 — slot 0 empty (post-consumption), slots 1-2 intact (EC-SS-9 spec).
	var unit_0: Array = loaded.per_hero_inventory_snapshot[0] as Array
	assert_int(unit_0.size()).is_equal(3)
	assert_str(String(unit_0[0] as StringName)).override_failure_message(
		"EC-SS-9: post-use slot 0 must round-trip as empty (\"\")"
	).is_equal("")
	assert_str(String(unit_0[1] as StringName)).is_equal("strength_scroll")
	assert_str(String(unit_0[2] as StringName)).is_equal("march_scroll")

	# Unit 1 — untouched starting inventory survives.
	var unit_1: Array = loaded.per_hero_inventory_snapshot[1] as Array
	assert_str(String(unit_1[0] as StringName)).is_equal("heal_potion")
	assert_str(String(unit_1[1] as StringName)).is_equal("heal_potion")
	assert_str(String(unit_1[2] as StringName)).is_equal("")

	SaveManagerStubScript.swap_out()


# ─── Round-trip: per_hero_pending_buff_snapshot ──────────────────────────────


## Populated pending_buff snapshot survives ResourceSaver → ResourceLoader cycle.
## EC-SS-3 buff revive lifecycle: caster killed mid-buff window — buff persists
## in snapshot and survives save+load. Resolution gate at attack time still
## handles stale buffs (expires_at_turn vs current_round comparison).
func test_save_context_pending_buff_snapshot_round_trips_via_resource_saver() -> void:
	# Arrange
	var stub: Node = SaveManagerStubScript.swap_in()
	stub.set_active_slot(1)

	var ctx: SaveContext = SaveContext.new()
	ctx.chapter_id = &"ch01"
	ctx.chapter_number = 1
	ctx.last_cp = 1
	# Unit 0: active strength_scroll buff (fired round 7, expires round 8).
	# Unit 1: no pending_buff (empty inner dict — explicit no-buff state).
	ctx.per_hero_pending_buff_snapshot = {
		0: {
			&"kind": &"strength",
			&"magnitude": 1.50,
			&"expires_at_turn": 8,
		},
		1: {},
	}

	# Act
	var loaded: SaveContext = _save_and_load(stub, ctx)

	# Assert
	assert_object(loaded).is_not_null()
	if loaded == null:
		SaveManagerStubScript.swap_out()
		return

	assert_int(loaded.per_hero_pending_buff_snapshot.size()).is_equal(2)

	# Unit 0 — strength buff with magnitude + expires_at_turn preserved.
	var buff_0: Dictionary = loaded.per_hero_pending_buff_snapshot[0] as Dictionary
	assert_str(String(buff_0.get(&"kind", &"") as StringName)).override_failure_message(
		"step 8b: pending_buff.kind must round-trip as StringName"
	).is_equal("strength")
	assert_float(buff_0.get(&"magnitude", 0.0) as float).override_failure_message(
		"step 8b: pending_buff.magnitude must round-trip as float"
	).is_equal_approx(1.50, 0.001)
	assert_int(buff_0.get(&"expires_at_turn", 0) as int).is_equal(8)

	# Unit 1 — empty inner Dictionary preserved as is_empty().
	var buff_1: Dictionary = loaded.per_hero_pending_buff_snapshot[1] as Dictionary
	assert_bool(buff_1.is_empty()).override_failure_message(
		"step 8b: empty per-unit buff entry must round-trip as empty Dictionary"
	).is_true()

	SaveManagerStubScript.swap_out()


# ─── Backward compat: legacy SaveContext (no new fields) ─────────────────────


## A SaveContext that does NOT populate the new fields (relying on Resource
## defaults) round-trips cleanly with both fields = empty. Confirms that pre-
## step-8b saves load without parse error after the schema extension.
func test_save_context_omitted_snapshot_fields_round_trip_as_default_empty() -> void:
	# Arrange — only populate the "old" fields; leave the new ones untouched.
	var stub: Node = SaveManagerStubScript.swap_in()
	stub.set_active_slot(1)

	var ctx: SaveContext = SaveContext.new()
	ctx.chapter_id = &"ch01"
	ctx.chapter_number = 1
	ctx.last_cp = 1
	# Both new fields stay at Resource default ({}).

	# Act
	var loaded: SaveContext = _save_and_load(stub, ctx)

	# Assert
	assert_object(loaded).is_not_null()
	if loaded == null:
		SaveManagerStubScript.swap_out()
		return

	assert_bool(loaded.per_hero_inventory_snapshot.is_empty()).override_failure_message(
		"step 8b: saves omitting per_hero_inventory_snapshot must load as empty"
	).is_true()
	assert_bool(loaded.per_hero_pending_buff_snapshot.is_empty()).override_failure_message(
		"step 8b: saves omitting per_hero_pending_buff_snapshot must load as empty"
	).is_true()

	SaveManagerStubScript.swap_out()


# ─── Helpers ──────────────────────────────────────────────────────────────────


## DRY helper mirroring save_manager_test.gd::_save_and_load — calls
## save_checkpoint on the stub and reloads via ResourceLoader.CACHE_MODE_IGNORE.
func _save_and_load(stub: Node, ctx: SaveContext) -> SaveContext:
	var ok: bool = stub.save_checkpoint(ctx)
	if not ok:
		return null
	var path: String = stub._path_for(
		stub.active_slot as int,
		ctx.chapter_number,
		ctx.last_cp
	)
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveContext
