extends GdUnitTestSuite

## unit_role_terrain_cost_integration_test.gd
## Cross-epic integration test: UnitRole × TerrainEffect cost matrix consumer.
##
## Story: unit-role/story-008 — ADR-0008 cost_multiplier placeholder retirement.
## Ratifies ADR-0008 §Context item 5 deferral by replacing TerrainEffect's `return 1`
## placeholder with UnitRole.get_class_cost_table() thin pass-through via translation.
##
## This is the FIRST cross-epic integration test in the project (foundation × core).
##
## Governing ADRs:
##   ADR-0008 §Decision 5 + §Migration Plan (TerrainEffect placeholder retirement)
##   ADR-0009 §5 (cost matrix unit-class dimension ratification; story-004 authored;
##               story-008 consumes via TerrainEffect.cost_multiplier)
## Related TRs: TR-unit-role-006, TR-terrain-effect-018.
##
## TERRAIN_TYPE ORDERING (story-008 discovery — 7th implementation-time catch):
##   TerrainEffect canonical ordering: PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3,
##   RIVER=4, BRIDGE=5, FORTRESS_WALL=6, ROAD=7.
##   UnitRole terrain_cost_table index: ROAD=0, PLAINS=1, HILLS=2, FOREST=3,
##   MOUNTAIN=4, BRIDGE=5.
##   These two orderings are DIFFERENT. Translation via _UNIT_ROLE_TERRAIN_IDX const
##   inside TerrainEffect.cost_multiplier() bridges the gap. All terrain_type values
##   in this test use TerrainEffect's canonical ordering (as callers see it).
##
## ISOLATION (G-15: before_test not before_each):
##   before_test() resets BOTH UnitRole and TerrainEffect static caches unconditionally.
##   UnitRole has no reset_for_tests() method — direct field mutation is the established
##   pattern per tests/unit/foundation/unit_role_config_loader_test.gd.

## ACs covered:
##   AC-1: placeholder retired — CAVALRY×MOUNTAIN returns 3, not 1
##   AC-3: cross-system 6-class sample cells via TerrainEffect
##   AC-5: R-1 isolation preserved at the integration boundary
##   AC-X: translation correctness — all 36 mapped cells (6 classes × 6 terrains)
##   AC-X2: RIVER (terrain_type=4) → push_error + return 1 fallback
##   AC-X3: FORTRESS_WALL (terrain_type=6) → push_error + return 1 fallback


func before_test() -> void:
	# G-15: reset BOTH static caches before each test (not before_each — see G-15).
	UnitRole._coefficients_loaded = false
	UnitRole._coefficients = {}
	TerrainEffect.reset_for_tests()


func after_test() -> void:
	# Safety net — idempotent reset in case test body throws.
	UnitRole._coefficients_loaded = false
	UnitRole._coefficients = {}
	TerrainEffect.reset_for_tests()


# ── AC-1: Placeholder retired ────────────────────────────────────────────────


## AC-1 (TR-unit-role-006 + TR-terrain-effect-018): TerrainEffect.cost_multiplier
## placeholder `return 1` is retired. Canonical verification cell: CAVALRY × MOUNTAIN.
##
## Given: default config (lazy-loaded on first call).
## When:  TerrainEffect.cost_multiplier(CAVALRY=0, MOUNTAIN=3) called.
##        (terrain_type=3 = TerrainEffect.MOUNTAIN; translated to UnitRole index 4)
## Then:  returns 3 — NOT 1 (the retired placeholder).
##
## Value chain: UnitRole cavalry terrain_cost_table[4] (MOUNTAIN) = 3.0 → int(3.0) = 3.
## If this returns 1, the placeholder was not retired (regression against story-008 AC-1).
func test_cost_multiplier_placeholder_retired_cavalry_mountain() -> void:
	var result: int = TerrainEffect.cost_multiplier(
		UnitRole.UnitClass.CAVALRY,
		TerrainEffect.MOUNTAIN  # TerrainEffect.MOUNTAIN = 3
	)
	assert_int(result).override_failure_message(
		("AC-1: TerrainEffect.cost_multiplier(CAVALRY, MOUNTAIN) must return 3 "
		+ "(placeholder retired); returned %d. If 1, the return 1 placeholder is still active.")
		% result
	).is_equal(3)

	# Regression guard: explicitly not equal to 1 (the old placeholder value).
	assert_int(result).override_failure_message(
		"AC-1: result must NOT be 1 (the retired MVP placeholder value); got %d" % result
	).is_not_equal(1)


# ── AC-3: Cross-system sample cells ─────────────────────────────────────────


## AC-3: Cross-system 6-class cost matrix sample cells via TerrainEffect.
##
## Verifies the 4 key cells from the story QA Test Cases:
##   CAVALRY × MOUNTAIN:  UnitRole 3.0 → int 3
##   INFANTRY × MOUNTAIN: UnitRole 1.5 → int 1  (truncation: 1.5 → 1)
##   SCOUT × FOREST:      UnitRole 0.7 → int 0  (truncation: 0.7 → 0)
##   ARCHER × MOUNTAIN:   UnitRole 2.0 → int 2
##
## terrain_type values use TerrainEffect's canonical ordering:
##   MOUNTAIN=3, FOREST=1 (TerrainEffect ordering).
## UnitRole index translation is internal to cost_multiplier().
func test_cost_multiplier_cross_system_sample_cells() -> void:
	# CAVALRY × MOUNTAIN (TerrainEffect.MOUNTAIN=3 → UnitRole idx 4 → 3.0 → int 3)
	var cavalry_mountain: int = TerrainEffect.cost_multiplier(
		UnitRole.UnitClass.CAVALRY, TerrainEffect.MOUNTAIN
	)
	assert_int(cavalry_mountain).override_failure_message(
		("AC-3: CAVALRY×MOUNTAIN expected int(3.0)=3; got %d. "
		+ "Check _UNIT_ROLE_TERRAIN_IDX[MOUNTAIN=3]=4 and cavalry terrain_cost_table[4]=3.0")
		% cavalry_mountain
	).is_equal(3)

	# INFANTRY × MOUNTAIN (TerrainEffect.MOUNTAIN=3 → UnitRole idx 4 → 1.5 → int 1)
	var infantry_mountain: int = TerrainEffect.cost_multiplier(
		UnitRole.UnitClass.INFANTRY, TerrainEffect.MOUNTAIN
	)
	assert_int(infantry_mountain).override_failure_message(
		("AC-3: INFANTRY×MOUNTAIN expected int(1.5)=1; got %d. "
		+ "int() truncates toward zero: int(1.5)=1, not 2.")
		% infantry_mountain
	).is_equal(1)

	# SCOUT × FOREST (TerrainEffect.FOREST=1 → UnitRole idx 3 → 0.7 → int 0)
	var scout_forest: int = TerrainEffect.cost_multiplier(
		UnitRole.UnitClass.SCOUT, TerrainEffect.FOREST
	)
	assert_int(scout_forest).override_failure_message(
		("AC-3: SCOUT×FOREST expected int(0.7)=0; got %d. "
		+ "int() truncates toward zero: int(0.7)=0. This is the load-bearing edge case.")
		% scout_forest
	).is_equal(0)

	# ARCHER × MOUNTAIN (TerrainEffect.MOUNTAIN=3 → UnitRole idx 4 → 2.0 → int 2)
	var archer_mountain: int = TerrainEffect.cost_multiplier(
		UnitRole.UnitClass.ARCHER, TerrainEffect.MOUNTAIN
	)
	assert_int(archer_mountain).override_failure_message(
		("AC-3: ARCHER×MOUNTAIN expected int(2.0)=2; got %d.")
		% archer_mountain
	).is_equal(2)


# ── AC-X: Translation table correctness — all 36 mapped cells ────────────────


## AC-X (translation correctness): All 36 cells of the 6×6 passable-terrain cost
## matrix are reachable through TerrainEffect.cost_multiplier() with correct values.
##
## Parametric: 6 classes × 6 passable terrains (PLAINS, FOREST, HILLS, MOUNTAIN,
## BRIDGE, ROAD). RIVER and FORTRESS_WALL are absent (impassable; tested in AC-X2/AC-X3).
##
## All terrain_type values use TerrainEffect's canonical ordering:
##   PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3, BRIDGE=5, ROAD=7.
## Expected values derived from unit_roles.json + int() truncation.
##
## This test is the primary regression guard for the _UNIT_ROLE_TERRAIN_IDX translation
## table. If any translation entry is wrong (e.g. PLAINS→idx 0 instead of idx 1),
## a cell in this parametric table will fail with a value mismatch.
func test_cost_multiplier_translation_table_all_36_cells() -> void:
	# Each entry: { "label": String, "unit_class": int, "terrain_type": int, "expected": int }
	# terrain_type uses TerrainEffect canonical ordering.
	# Expected: int(UnitRole float) — truncated toward zero.
	var cases: Array[Dictionary] = [
		# ── CAVALRY (UnitClass=0) ───────────────────────────────────────────
		# terrain_cost_table (UnitRole order): [1.0, 1.0, 1.5, 2.0, 3.0, 1.0]
		#   idx 0=ROAD, idx 1=PLAINS, idx 2=HILLS, idx 3=FOREST, idx 4=MOUNTAIN, idx 5=BRIDGE
		{"label": "CAVALRY×PLAINS",   "unit_class": 0, "terrain_type": 0, "expected": 1},
		{"label": "CAVALRY×FOREST",   "unit_class": 0, "terrain_type": 1, "expected": 2},  # 2.0→2
		{"label": "CAVALRY×HILLS",    "unit_class": 0, "terrain_type": 2, "expected": 1},  # 1.5→1
		{"label": "CAVALRY×MOUNTAIN", "unit_class": 0, "terrain_type": 3, "expected": 3},  # 3.0→3
		{"label": "CAVALRY×BRIDGE",   "unit_class": 0, "terrain_type": 5, "expected": 1},
		{"label": "CAVALRY×ROAD",     "unit_class": 0, "terrain_type": 7, "expected": 1},
		# ── INFANTRY (UnitClass=1) ──────────────────────────────────────────
		# terrain_cost_table: [1.0, 1.0, 1.0, 1.0, 1.5, 1.0]
		{"label": "INFANTRY×PLAINS",   "unit_class": 1, "terrain_type": 0, "expected": 1},
		{"label": "INFANTRY×FOREST",   "unit_class": 1, "terrain_type": 1, "expected": 1},
		{"label": "INFANTRY×HILLS",    "unit_class": 1, "terrain_type": 2, "expected": 1},
		{"label": "INFANTRY×MOUNTAIN", "unit_class": 1, "terrain_type": 3, "expected": 1},  # 1.5→1
		{"label": "INFANTRY×BRIDGE",   "unit_class": 1, "terrain_type": 5, "expected": 1},
		{"label": "INFANTRY×ROAD",     "unit_class": 1, "terrain_type": 7, "expected": 1},
		# ── ARCHER (UnitClass=2) ────────────────────────────────────────────
		# terrain_cost_table: [1.0, 1.0, 1.0, 1.0, 2.0, 1.0]
		{"label": "ARCHER×PLAINS",   "unit_class": 2, "terrain_type": 0, "expected": 1},
		{"label": "ARCHER×FOREST",   "unit_class": 2, "terrain_type": 1, "expected": 1},
		{"label": "ARCHER×HILLS",    "unit_class": 2, "terrain_type": 2, "expected": 1},
		{"label": "ARCHER×MOUNTAIN", "unit_class": 2, "terrain_type": 3, "expected": 2},  # 2.0→2
		{"label": "ARCHER×BRIDGE",   "unit_class": 2, "terrain_type": 5, "expected": 1},
		{"label": "ARCHER×ROAD",     "unit_class": 2, "terrain_type": 7, "expected": 1},
		# ── STRATEGIST (UnitClass=3) ────────────────────────────────────────
		# terrain_cost_table: [1.0, 1.0, 1.5, 1.5, 2.0, 1.0]
		{"label": "STRATEGIST×PLAINS",   "unit_class": 3, "terrain_type": 0, "expected": 1},
		{"label": "STRATEGIST×FOREST",   "unit_class": 3, "terrain_type": 1, "expected": 1},  # 1.5→1
		{"label": "STRATEGIST×HILLS",    "unit_class": 3, "terrain_type": 2, "expected": 1},  # 1.5→1
		{"label": "STRATEGIST×MOUNTAIN", "unit_class": 3, "terrain_type": 3, "expected": 2},  # 2.0→2
		{"label": "STRATEGIST×BRIDGE",   "unit_class": 3, "terrain_type": 5, "expected": 1},
		{"label": "STRATEGIST×ROAD",     "unit_class": 3, "terrain_type": 7, "expected": 1},
		# ── COMMANDER (UnitClass=4) ─────────────────────────────────────────
		# terrain_cost_table: [1.0, 1.0, 1.0, 1.5, 2.0, 1.0]
		{"label": "COMMANDER×PLAINS",   "unit_class": 4, "terrain_type": 0, "expected": 1},
		{"label": "COMMANDER×FOREST",   "unit_class": 4, "terrain_type": 1, "expected": 1},  # 1.5→1
		{"label": "COMMANDER×HILLS",    "unit_class": 4, "terrain_type": 2, "expected": 1},
		{"label": "COMMANDER×MOUNTAIN", "unit_class": 4, "terrain_type": 3, "expected": 2},  # 2.0→2
		{"label": "COMMANDER×BRIDGE",   "unit_class": 4, "terrain_type": 5, "expected": 1},
		{"label": "COMMANDER×ROAD",     "unit_class": 4, "terrain_type": 7, "expected": 1},
		# ── SCOUT (UnitClass=5) ─────────────────────────────────────────────
		# terrain_cost_table: [1.0, 1.0, 1.0, 0.7, 1.5, 1.0]
		{"label": "SCOUT×PLAINS",   "unit_class": 5, "terrain_type": 0, "expected": 1},
		{"label": "SCOUT×FOREST",   "unit_class": 5, "terrain_type": 1, "expected": 0},  # 0.7→0
		{"label": "SCOUT×HILLS",    "unit_class": 5, "terrain_type": 2, "expected": 1},
		{"label": "SCOUT×MOUNTAIN", "unit_class": 5, "terrain_type": 3, "expected": 1},  # 1.5→1
		{"label": "SCOUT×BRIDGE",   "unit_class": 5, "terrain_type": 5, "expected": 1},
		{"label": "SCOUT×ROAD",     "unit_class": 5, "terrain_type": 7, "expected": 1},
	]

	for case: Dictionary in cases:
		var label: String = case["label"] as String
		var unit_class: int = case["unit_class"] as int
		var terrain_type: int = case["terrain_type"] as int
		var expected: int = case["expected"] as int
		var result: int = TerrainEffect.cost_multiplier(unit_class, terrain_type)
		assert_int(result).override_failure_message(
			("AC-X: %s — cost_multiplier(%d, %d) expected %d; got %d. "
			+ "Check _UNIT_ROLE_TERRAIN_IDX translation and unit_roles.json terrain_cost_table.")
			% [label, unit_class, terrain_type, expected, result]
		).is_equal(expected)


# ── AC-X2/AC-X3: Impassable-terrain contract-violation fallback ───────────────


## AC-X2: RIVER (TerrainEffect.RIVER=4) triggers contract-violation guard.
##
## RIVER is absent from _UNIT_ROLE_TERRAIN_IDX — it is impassable per CR-4a.
## Map/Grid short-circuits via is_passable_base before cost_multiplier is reached.
## If cost_multiplier IS called with RIVER, it emits push_error and returns 1.
## This test verifies both the return value (1) and the push_error emission.
func test_cost_multiplier_river_returns_fallback_with_push_error() -> void:
	# Direct call — verify return value is 1 (safe fallback).
	var result: int = TerrainEffect.cost_multiplier(0, TerrainEffect.RIVER)
	assert_int(result).override_failure_message(
		("AC-X2: cost_multiplier(CAVALRY=0, RIVER=4) must return 1 (safe fallback); "
		+ "got %d. RIVER is impassable per CR-4a.") % result
	).is_equal(1)

	# GdUnit4 push_error capture — verify the contract violation is signalled.
	await assert_error(func() -> void:
		var _r: int = TerrainEffect.cost_multiplier(0, TerrainEffect.RIVER)
	).is_push_error(any())


## AC-X3: FORTRESS_WALL (TerrainEffect.FORTRESS_WALL=6) triggers contract-violation guard.
##
## Same contract as AC-X2 (RIVER). FORTRESS_WALL is absent from _UNIT_ROLE_TERRAIN_IDX.
## Map/Grid short-circuits via is_passable_base before cost_multiplier is reached.
func test_cost_multiplier_fortress_wall_returns_fallback_with_push_error() -> void:
	# Direct call — verify return value is 1 (safe fallback).
	var result: int = TerrainEffect.cost_multiplier(0, TerrainEffect.FORTRESS_WALL)
	assert_int(result).override_failure_message(
		("AC-X3: cost_multiplier(CAVALRY=0, FORTRESS_WALL=6) must return 1 (safe fallback); "
		+ "got %d. FORTRESS_WALL is impassable per CR-4a.") % result
	).is_equal(1)

	# GdUnit4 push_error capture.
	await assert_error(func() -> void:
		var _r: int = TerrainEffect.cost_multiplier(0, TerrainEffect.FORTRESS_WALL)
	).is_push_error(any())


# ── AC-5: R-1 isolation at integration boundary ──────────────────────────────


## AC-5: R-1 mitigation (ADR-0009 §5) preserved at the TerrainEffect consumer boundary.
##
## UnitRole.get_class_cost_table() constructs a fresh PackedFloat32Array per call
## (R-1 mitigation: COW semantics, no cached shared backing array). TerrainEffect's
## cost_multiplier() reads int(cost_row[index]) and discards the array immediately —
## it does NOT cache the returned PackedFloat32Array across calls.
##
## This test verifies that two successive calls to cost_multiplier() for the same
## (unit_class, terrain_type) return identical values with no cross-call corruption.
## It extends Story 004's mutation-isolation test to the TerrainEffect consumer boundary.
##
## Pattern: call cost_multiplier(CAVALRY, MOUNTAIN) twice; in between, call a second
## (SCOUT, FOREST) pair. If TerrainEffect cached and returned a shared array, the
## second SCOUT call could corrupt the array that a hypothetical cache had stored for
## CAVALRY (or vice versa). The repeated CAVALRY call must still return 3.
func test_cost_multiplier_r1_isolation_at_integration_boundary() -> void:
	# First call: CAVALRY × MOUNTAIN → expect 3.
	var first: int = TerrainEffect.cost_multiplier(
		UnitRole.UnitClass.CAVALRY, TerrainEffect.MOUNTAIN
	)
	assert_int(first).override_failure_message(
		("AC-5/R-1: first call cost_multiplier(CAVALRY, MOUNTAIN) must return 3; "
		+ "got %d") % first
	).is_equal(3)

	# Interleaved call: SCOUT × FOREST → expect 0.
	# If cost_multiplier cached and returned a shared PackedFloat32Array from the first call,
	# this interleaved call with a different unit_class could corrupt it.
	var scout_forest: int = TerrainEffect.cost_multiplier(
		UnitRole.UnitClass.SCOUT, TerrainEffect.FOREST
	)
	assert_int(scout_forest).override_failure_message(
		("AC-5/R-1: interleaved call cost_multiplier(SCOUT, FOREST) must return 0; "
		+ "got %d") % scout_forest
	).is_equal(0)

	# Second call: CAVALRY × MOUNTAIN again — must still return 3 (no corruption).
	var second: int = TerrainEffect.cost_multiplier(
		UnitRole.UnitClass.CAVALRY, TerrainEffect.MOUNTAIN
	)
	assert_int(second).override_failure_message(
		("AC-5/R-1: second call cost_multiplier(CAVALRY, MOUNTAIN) must return 3 "
		+ "after interleaved SCOUT call; got %d. "
		+ "Non-3 value indicates shared-array corruption via cached PackedFloat32Array.")
		% second
	).is_equal(3)

	# Repeat SCOUT × FOREST — must still return 0 (no corruption from CAVALRY calls).
	var scout_forest_2: int = TerrainEffect.cost_multiplier(
		UnitRole.UnitClass.SCOUT, TerrainEffect.FOREST
	)
	assert_int(scout_forest_2).override_failure_message(
		("AC-5/R-1: second SCOUT×FOREST call must return 0; got %d. "
		+ "Non-0 value indicates shared-array corruption via cached PackedFloat32Array.")
		% scout_forest_2
	).is_equal(0)
