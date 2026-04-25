## TerrainEffect — stateless terrain modifier query layer.
##
## Governing ADR: ADR-0008 Terrain Effect System (Accepted 2026-04-25).
## Exposes query methods for terrain and combat modifiers used by Damage Calc,
## AI scoring, and Battle HUD. All state is class-scope static (lazy-loaded once
## at first access); no per-battle initialisation; no Node lifecycle.
##
## TEST ISOLATION DISCIPLINE (ADR-0008 §Risks line 562):
##   Every GdUnit4 test suite that calls ANY TerrainEffect method MUST call
##   TerrainEffect.reset_for_tests() in before_test() (or at the top of every
##   test function). Failure to do so causes static-state bleed across suites
##   in the same GdUnit4 session, corrupting default-config test expectations.
##   NOTE: GdUnit4 v6.1.2 invokes only `before_test()`/`after_test()`; a function
##   named `before_each()` is silently ignored (gotcha G-15).
##
## G-1 TYPED-DICTIONARY LIMITATION:
##   _terrain_table and _elevation_table are declared as untyped Dictionary = {}
##   rather than Dictionary[int, TerrainEntry] because GDScript 4.6 does NOT
##   support generic-Dictionary syntax in static var declarations. Do NOT
##   "fix" these to Dictionary[K, V] — the engine will reject them at parse time.
##   Same root cause as src/core/save_migration_registry.gd._migrations.
class_name TerrainEffect
extends RefCounted

# ── Compile-time defaults (ADR-0008 §Decision 7) ────────────────────────────

## Compile-time cap: maximum signed defense modifier (percentage points, ±).
## Runtime value may be overridden by terrain_config.json; read via max_defense_reduction().
const MAX_DEFENSE_REDUCTION_DEFAULT: int = 30

## Compile-time cap: maximum evasion modifier (percentage points).
## Runtime value may be overridden by terrain_config.json; read via max_evasion().
const MAX_EVASION_DEFAULT: int = 30

## Compile-time default AI evasion weight for get_terrain_score() formula F-3.
const EVASION_WEIGHT_DEFAULT: float = 1.2

## Compile-time default AI score normalisation constant for get_terrain_score() formula F-3.
## Equals FORTRESS_WALL(25) + evasion_weight * FOREST(15) = 25 + 1.2 * 15 = 43.0.
const MAX_POSSIBLE_SCORE_DEFAULT: float = 43.0

# ── Terrain-type integer constants (ADR-0008 §Key Interfaces lines 437-445) ─
# Canonical MapGrid ordering per TD-032 A-16 reconciliation.
# GDD CR-1 table uses alphabetical column order for readability;
# these integer values are the authoritative MapGrid-aligned order.

## Plains terrain type (0). No modifiers. Free movement.
const PLAINS: int = 0
## Forest terrain type (1). defense_bonus=5, evasion_bonus=15.
const FOREST: int = 1
## Hills terrain type (2). defense_bonus=15, evasion_bonus=0.
const HILLS: int = 2
## Mountain terrain type (3). defense_bonus=20, evasion_bonus=5.
const MOUNTAIN: int = 3
## River terrain type (4). No modifiers (CR-1 EC-13: valid, no error).
const RIVER: int = 4
## Bridge terrain type (5). defense_bonus=5, bridge_no_flank special rule.
const BRIDGE: int = 5
## Fortress wall terrain type (6). defense_bonus=25. Highest defensive modifier.
const FORTRESS_WALL: int = 6
## Road terrain type (7). No modifiers. Used for movement cost reduction.
const ROAD: int = 7

# ── Static state (lazy-init; reset via reset_for_tests()) ───────────────────
# G-1: Dictionary fields intentionally untyped — GDScript 4.6 forbids
# generic Dictionary[K,V] syntax in static var declarations. See header.

## True once load_config() has completed (even if config was missing or invalid).
## Idempotent guard: load_config() returns early when this is true.
static var _config_loaded: bool = false

## Terrain modifier table: int (terrain_type) → TerrainModifiers instance.
## Populated by load_config(); queried by get_terrain_modifiers() and get_combat_modifiers().
## Story-003 storage choice: TerrainModifiers instances (not raw dicts) so that
## story-004's get_terrain_modifiers() is a near-zero-cost lookup + defensive copy.
static var _terrain_table: Dictionary = {}  # G-1: untyped — see header

## Elevation modifier table: int (delta elevation, -2..+2) → Dictionary {attack_mod, defense_mod}.
## Populated by load_config(); queried by get_combat_modifiers().
## Stores raw Dictionary values (no Resource type for elevation entries; story-005
## builds CombatModifiers from raw data directly).
static var _elevation_table: Dictionary = {}  # G-1: untyped — see header

## Runtime maximum defense reduction cap (percentage points).
## Defaults to MAX_DEFENSE_REDUCTION_DEFAULT; config may override.
static var _max_defense_reduction: int = MAX_DEFENSE_REDUCTION_DEFAULT

## Runtime maximum evasion cap (percentage points).
## Defaults to MAX_EVASION_DEFAULT; config may override.
static var _max_evasion: int = MAX_EVASION_DEFAULT

## Runtime AI evasion weight for get_terrain_score().
## Defaults to EVASION_WEIGHT_DEFAULT; config may override.
static var _evasion_weight: float = EVASION_WEIGHT_DEFAULT

## Runtime AI score normalisation constant for get_terrain_score().
## Defaults to MAX_POSSIBLE_SCORE_DEFAULT; config may override.
static var _max_possible_score: float = MAX_POSSIBLE_SCORE_DEFAULT

## Default unit-type × terrain-type movement cost multiplier.
## MVP: all (unit_type, terrain_type) pairs return this value. ADR-0009 will populate.
static var _cost_default_multiplier: int = 1

# ── Lifecycle / Test Seams ───────────────────────────────────────────────────

## Resets all static state to compile-time defaults. Call in before_test() for
## every GdUnit4 test suite that touches TerrainEffect (ADR-0008 §Risks line 562).
##
## This is the ONLY method that resets _config_loaded to false. Tests must NOT
## directly mutate _terrain_table, _elevation_table, or any other static var —
## always go through reset_for_tests() + load_config(custom_path).
##
## Usage:
##   func before_test() -> void:
##       TerrainEffect.reset_for_tests()
static func reset_for_tests() -> void:
	_config_loaded = false
	_terrain_table = {}
	_elevation_table = {}
	_max_defense_reduction = MAX_DEFENSE_REDUCTION_DEFAULT
	_max_evasion = MAX_EVASION_DEFAULT
	_evasion_weight = EVASION_WEIGHT_DEFAULT
	_max_possible_score = MAX_POSSIBLE_SCORE_DEFAULT
	_cost_default_multiplier = 1

## Loads terrain configuration from a JSON file. Idempotent: if _config_loaded
## is already true, emits a push_warning and returns true immediately without
## re-parsing. Returns true on success, false on parse or validation failure
## (in which case _fall_back_to_defaults() is called and the game remains playable).
##
## Implementation (Story-003): reads via FileAccess.get_file_as_string(), parses
## via instance-form JSON.new().parse() for line/col diagnostics (ADR-0008 §Notes §2),
## calls _validate_config() then _apply_config() on the success path.
## On any failure: push_error + _fall_back_to_defaults() (sets _config_loaded=true
## so subsequent calls short-circuit without re-attempting parse on a known-bad file).
##
## Parameters:
##   path — path to the JSON config file. Defaults to the canonical location.
##           Tests may pass a user:// fixture path to exercise config-loading behaviour.
##
## Returns: true on success or when already loaded; false on parse/validation failure.
##
## Usage:
##   TerrainEffect.load_config()                              # uses default path
##   TerrainEffect.load_config("user://test_fixture.json")   # test fixture path
static func load_config(path: String = "res://assets/data/terrain/terrain_config.json") -> bool:
	if _config_loaded:
		push_warning(
			("TerrainEffect.load_config() called while _config_loaded is already true"
			+ " (path: %s) — skipping re-parse (idempotent guard).") % path
		)
		return true
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("terrain_config: file not found or empty at " + path)
		_fall_back_to_defaults()
		return false
	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error(
			("terrain_config parse error at line %d: %s")
			% [json.get_error_line(), json.get_error_message()]
		)
		_fall_back_to_defaults()
		return false
	if not _validate_config(json.data):
		_fall_back_to_defaults()
		return false
	_apply_config(json.data)
	_config_loaded = true
	return true

## Validates the parsed JSON data against the ADR-0008 §Decision 2 schema.
## Returns true if all required fields are present and within valid ranges.
## Calls push_error() with a descriptive reason on the first failing rule and
## returns false immediately (fail-fast; does not accumulate errors).
##
## Enforces:
##   - schema_version == 1
##   - terrain_modifiers keys "0".."7" present; defense_bonus/evasion_bonus
##     non-negative integers ≤ 50; special_rules is an Array
##   - elevation_modifiers keys "-2".."-1".."0".."1".."2" present;
##     attack_mod/defense_mod integers in [-25, +25]
##   - caps.max_defense_reduction and caps.max_evasion positive integers ≤ 50
##   - ai_scoring.evasion_weight finite float in (0, 5]
##   - ai_scoring.max_possible_score float present
##   - cost_matrix.default_multiplier positive integer
static func _validate_config(parsed: Variant) -> bool:
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("terrain_config: root is not a Dictionary (got type %d)" % typeof(parsed))
		return false
	var cfg: Dictionary = parsed as Dictionary

	# schema_version
	if not cfg.has("schema_version"):
		push_error("terrain_config: missing required field 'schema_version'")
		return false
	if typeof(cfg["schema_version"]) != TYPE_FLOAT or int(cfg["schema_version"]) != 1:
		push_error(
			"terrain_config: schema_version must be 1 (got %s)" % str(cfg["schema_version"])
		)
		return false

	# terrain_modifiers
	if not cfg.has("terrain_modifiers") or typeof(cfg["terrain_modifiers"]) != TYPE_DICTIONARY:
		push_error("terrain_config: missing or invalid 'terrain_modifiers'")
		return false
	var tm: Dictionary = cfg["terrain_modifiers"] as Dictionary
	for key_int: int in range(8):
		var key: String = str(key_int)
		if not tm.has(key):
			push_error(
				("terrain_config: missing terrain_modifiers key '%s'"
				+ " (terrain type %d)") % [key, key_int]
			)
			return false
		var entry: Dictionary = tm[key] as Dictionary
		if not _validate_int_field(
			entry.get("defense_bonus"),
			"terrain_modifiers[%s].defense_bonus" % key,
			0, 50
		):
			return false
		if not _validate_int_field(
			entry.get("evasion_bonus"),
			"terrain_modifiers[%s].evasion_bonus" % key,
			0, 50
		):
			return false
		if not entry.has("special_rules") or typeof(entry["special_rules"]) != TYPE_ARRAY:
			push_error(
				"terrain_config: terrain_modifiers[%s].special_rules must be an Array" % key
			)
			return false

	# elevation_modifiers
	if not cfg.has("elevation_modifiers") or typeof(cfg["elevation_modifiers"]) != TYPE_DICTIONARY:
		push_error("terrain_config: missing or invalid 'elevation_modifiers'")
		return false
	var em: Dictionary = cfg["elevation_modifiers"] as Dictionary
	for delta: int in [-2, -1, 0, 1, 2]:
		var key: String = str(delta)
		if not em.has(key):
			push_error(
				"terrain_config: missing elevation_modifiers key '%s'" % key
			)
			return false
		var entry: Dictionary = em[key] as Dictionary
		if not _validate_int_field(
			entry.get("attack_mod"),
			"elevation_modifiers[%s].attack_mod" % key,
			-25, 25
		):
			return false
		if not _validate_int_field(
			entry.get("defense_mod"),
			"elevation_modifiers[%s].defense_mod" % key,
			-25, 25
		):
			return false

	# caps
	if not cfg.has("caps") or typeof(cfg["caps"]) != TYPE_DICTIONARY:
		push_error("terrain_config: missing or invalid 'caps'")
		return false
	var caps: Dictionary = cfg["caps"] as Dictionary
	if not _validate_int_field(caps.get("max_defense_reduction"), "caps.max_defense_reduction", 1, 50):
		return false
	if not _validate_int_field(caps.get("max_evasion"), "caps.max_evasion", 1, 50):
		return false

	# ai_scoring
	if not cfg.has("ai_scoring") or typeof(cfg["ai_scoring"]) != TYPE_DICTIONARY:
		push_error("terrain_config: missing or invalid 'ai_scoring'")
		return false
	var ai: Dictionary = cfg["ai_scoring"] as Dictionary
	if not ai.has("evasion_weight"):
		push_error("terrain_config: missing ai_scoring.evasion_weight")
		return false
	var ew: Variant = ai["evasion_weight"]
	if typeof(ew) != TYPE_FLOAT:
		push_error(
			"terrain_config: ai_scoring.evasion_weight must be a float (got type %d)" % typeof(ew)
		)
		return false
	var ew_f: float = ew as float
	if not is_finite(ew_f) or ew_f <= 0.0 or ew_f > 5.0:
		push_error(
			("terrain_config: ai_scoring.evasion_weight must be finite and in (0, 5]"
			+ " (got %f)") % ew_f
		)
		return false
	if not ai.has("max_possible_score"):
		push_error("terrain_config: missing ai_scoring.max_possible_score")
		return false
	if typeof(ai["max_possible_score"]) != TYPE_FLOAT:
		push_error("terrain_config: ai_scoring.max_possible_score must be a float")
		return false
	# Guard story-004 get_terrain_score() formula F-3 against divide-by-zero / negative
	# normalisation (score / _max_possible_score). ADR-0008 §Decision 2 specifies "finite
	# float" without a numeric range; we add the strict positivity guard defensively here
	# to fail loud at config-load time rather than at first AI query.
	var mps_f: float = ai["max_possible_score"] as float
	if not is_finite(mps_f) or mps_f <= 0.0:
		push_error(
			("terrain_config: ai_scoring.max_possible_score must be a finite positive float"
			+ " (got %f)") % mps_f
		)
		return false

	# cost_matrix
	if not cfg.has("cost_matrix") or typeof(cfg["cost_matrix"]) != TYPE_DICTIONARY:
		push_error("terrain_config: missing or invalid 'cost_matrix'")
		return false
	var cm: Dictionary = cfg["cost_matrix"] as Dictionary
	if not _validate_int_field(cm.get("default_multiplier"), "cost_matrix.default_multiplier", 1, 999):
		return false

	return true

## Validates that v is an integer-typed JSON value (TYPE_FLOAT with no fractional
## part) within the inclusive range [lo, hi].
##
## Uses the ADR-0008 §Notes §3 two-clause guard:
##   clause 1: typeof(v) != TYPE_FLOAT — rejects non-numerics (null, string, object)
##   clause 2: v != int(v)             — rejects fractionals (e.g. 15.5)
## Silent truncation via int(15.9)==15 is explicitly forbidden (ADR-0008 §Notes §3).
##
## Parameters:
##   v          — the raw JSON value (Variant); null is valid input (triggers clause 1)
##   field_name — human-readable field path for push_error diagnostics
##   lo, hi     — inclusive integer bounds
##
## Returns: true if valid; false after push_error on first failing clause.
static func _validate_int_field(v: Variant, field_name: String, lo: int, hi: int) -> bool:
	if typeof(v) != TYPE_FLOAT or v != int(v):
		push_error(
			("terrain_config: %s is non-integral (got %s)")
			% [field_name, str(v)]
		)
		return false
	var iv: int = int(v)
	if iv < lo or iv > hi:
		push_error(
			("terrain_config: %s out of range [%d, %d] (got %d)")
			% [field_name, lo, hi, iv]
		)
		return false
	return true

## Applies a validated parsed config Dictionary to the TerrainEffect static state.
## Assumes _validate_config() has already returned true — no re-validation here.
## _config_loaded is NOT set here; the caller (load_config) sets it after this
## returns, so a runtime exception inside this function leaves _config_loaded=false
## correctly (partial-apply protection).
##
## Storage layout (Story-003 decision, for story-004 compatibility):
##   _terrain_table:  int key → TerrainModifiers instance (near-zero-cost lookup
##                    + defensive copy for get_terrain_modifiers() in story-004).
##   _elevation_table: int key → raw Dictionary {"attack_mod": int, "defense_mod": int}
##                    (no Resource type for elevation entries; story-005 builds
##                    CombatModifiers from raw data directly).
##
## Special rules strings from JSON are converted to StringName element-by-element
## (e.g. "bridge_no_flank" → &"bridge_no_flank") per ADR-0008 §Decision 6.
## G-2: .append() loop used instead of .duplicate() to preserve Array[StringName] typing.
static func _apply_config(parsed: Dictionary) -> void:
	var tm: Dictionary = parsed["terrain_modifiers"] as Dictionary
	_terrain_table = {}
	for key_int: int in range(8):
		var key: String = str(key_int)
		var entry: Dictionary = tm[key] as Dictionary
		var mod := TerrainModifiers.new()
		mod.defense_bonus = int(entry["defense_bonus"] as float)
		mod.evasion_bonus = int(entry["evasion_bonus"] as float)
		var rules_raw: Array = entry["special_rules"] as Array
		for rule: Variant in rules_raw:
			mod.special_rules.append(StringName(rule as String))
		_terrain_table[key_int] = mod

	var em: Dictionary = parsed["elevation_modifiers"] as Dictionary
	_elevation_table = {}
	for delta: int in [-2, -1, 0, 1, 2]:
		var key: String = str(delta)
		var entry: Dictionary = em[key] as Dictionary
		_elevation_table[delta] = {
			"attack_mod":  int(entry["attack_mod"]  as float),
			"defense_mod": int(entry["defense_mod"] as float)
		}

	var caps: Dictionary = parsed["caps"] as Dictionary
	_max_defense_reduction = int(caps["max_defense_reduction"] as float)
	_max_evasion           = int(caps["max_evasion"]           as float)

	var ai: Dictionary = parsed["ai_scoring"] as Dictionary
	_evasion_weight     = ai["evasion_weight"]     as float
	_max_possible_score = ai["max_possible_score"] as float

	var cm: Dictionary = parsed["cost_matrix"] as Dictionary
	_cost_default_multiplier = int(cm["default_multiplier"] as float)

## Populates _terrain_table and _elevation_table with canonical CR-1 + CR-2 hardcoded
## values (GDD tables, ADR-0008 §Decision 2). Called by load_config() on any parse
## or validation failure so the game remains playable (Pillar 1: "battlefield always
## readable").
##
## Cap and scoring vars (_max_defense_reduction, _max_evasion, _evasion_weight,
## _max_possible_score, _cost_default_multiplier) are NOT modified here — they
## already hold the correct compile-time defaults from class initialisation or a
## prior reset_for_tests() call. Touching them would be redundant and would obscure
## which code path populated them.
##
## Sets _config_loaded = true so that subsequent load_config() calls short-circuit
## without re-attempting parse on a known-bad file (idempotent guard contract).
static func _fall_back_to_defaults() -> void:
	_terrain_table = {}

	var plains := TerrainModifiers.new()
	plains.defense_bonus = 0
	plains.evasion_bonus = 0
	_terrain_table[PLAINS] = plains

	var forest := TerrainModifiers.new()
	forest.defense_bonus = 5
	forest.evasion_bonus = 15
	_terrain_table[FOREST] = forest

	var hills := TerrainModifiers.new()
	hills.defense_bonus = 15
	hills.evasion_bonus = 0
	_terrain_table[HILLS] = hills

	var mountain := TerrainModifiers.new()
	mountain.defense_bonus = 20
	mountain.evasion_bonus = 5
	_terrain_table[MOUNTAIN] = mountain

	var river := TerrainModifiers.new()
	river.defense_bonus = 0
	river.evasion_bonus = 0
	_terrain_table[RIVER] = river

	var bridge := TerrainModifiers.new()
	bridge.defense_bonus = 5
	bridge.evasion_bonus = 0
	bridge.special_rules.append(&"bridge_no_flank")
	_terrain_table[BRIDGE] = bridge

	var fortress_wall := TerrainModifiers.new()
	fortress_wall.defense_bonus = 25
	fortress_wall.evasion_bonus = 0
	_terrain_table[FORTRESS_WALL] = fortress_wall

	var road := TerrainModifiers.new()
	road.defense_bonus = 0
	road.evasion_bonus = 0
	_terrain_table[ROAD] = road

	_elevation_table = {}
	_elevation_table[-2] = {"attack_mod": -15, "defense_mod":  15}
	_elevation_table[-1] = {"attack_mod":  -8, "defense_mod":   8}
	_elevation_table[0]  = {"attack_mod":   0, "defense_mod":   0}
	_elevation_table[1]  = {"attack_mod":   8, "defense_mod":  -8}
	_elevation_table[2]  = {"attack_mod":  15, "defense_mod": -15}

	_config_loaded = true

# ── Public Query Methods (Story-004) ────────────────────────────────────────

## Returns raw (uncapped) terrain modifiers for the tile at [param coord].
##
## Reads [code]MapGrid.get_tile(coord).terrain_type[/code], looks up
## [code]_terrain_table[terrain_type][/code], and returns a NEW defensive-copy
## [code]TerrainModifiers[/code] instance (ADR-0008 §Notes §5 — prevents caller
## mutation from poisoning the static table).
##
## Lazy-triggers [method load_config] on first call if [member _config_loaded]
## is false (ADR-0008 §Decision 1 — pay-per-use; tests that never query terrain
## pay zero load cost).
##
## Out-of-bounds or null-grid: returns a zero-fill [code]TerrainModifiers[/code]
## (AC-14 — no crash, no error). Uses [code]MapGrid.get_tile[/code] as the single
## source of truth for what counts as OOB.
##
## CR-1d / TR-002: signature has NO [code]unit_type[/code] parameter — all unit
## classes receive the same terrain modifiers (class differentiation is the
## cost_matrix domain, not the terrain-modifier domain).
##
## Usage:
##   var m: TerrainModifiers = TerrainEffect.get_terrain_modifiers(grid, Vector2i(3, 5))
##   print(m.defense_bonus)   # 15 for HILLS
static func get_terrain_modifiers(grid: MapGrid, coord: Vector2i) -> TerrainModifiers:
	if not _config_loaded:
		load_config()
	var tile: MapTileData = grid.get_tile(coord) if grid != null else null
	if tile == null:
		return TerrainModifiers.new()  # zero-fill OOB per AC-14
	var entry: TerrainModifiers = _terrain_table.get(tile.terrain_type, null) as TerrainModifiers
	if entry == null:
		return TerrainModifiers.new()  # safety net for unknown terrain_type
	var copy := TerrainModifiers.new()
	copy.defense_bonus = entry.defense_bonus
	copy.evasion_bonus = entry.evasion_bonus
	# G-2: .assign() preserves Array[StringName] typing; .duplicate() demotes to untyped Array.
	var rules: Array[StringName] = []
	rules.assign(entry.special_rules)
	copy.special_rules = rules
	return copy

## Returns clamped combat modifiers for one attacker→defender tile pair.
##
## Reads [code]MapGrid.get_tile(attacker_coord)[/code] and
## [code]MapGrid.get_tile(defender_coord)[/code], computes
## [code]delta_elevation = atk_tile.elevation - def_tile.elevation[/code],
## clamps the delta to [-2, +2] per EC-14, looks up the elevation table and
## the defender's terrain table, applies the F-1 symmetric clamp
## [code][-_max_defense_reduction, +_max_defense_reduction][/code] to
## [code]defender_terrain_def[/code] and [code][0, _max_evasion][/code] to
## [code]defender_terrain_eva[/code], sets [code]bridge_no_flank[/code] if
## the defender tile is BRIDGE (CR-5b, TR-009), and returns the populated
## [code]CombatModifiers[/code] instance.
##
## Cross-system contract (damage-calc.md §F, ratified 2026-04-18):
##   [code]defender_terrain_def[/code] is in
##   [code][-MAX_DEFENSE_REDUCTION, +MAX_DEFENSE_REDUCTION][/code].
##   [code]defender_terrain_eva[/code] is in [code][0, MAX_EVASION][/code].
## Damage Calc treats these as opaque pre-clamped values and does NOT re-clamp.
##
## Lazy-triggers [method load_config] on first call if [member _config_loaded]
## is false (independent lazy entry point — same contract as
## [method get_terrain_modifiers]).
##
## Out-of-bounds or null-grid: returns zero-fill [code]CombatModifiers.new()[/code]
## (same OOB pattern as [method get_terrain_modifiers]).
##
## EC-14 / TR-015: if [code]delta_elevation[/code] is outside [-2, +2], the delta
## is clamped and [code]push_warning[/code] is emitted to flag that the CR-2
## elevation table needs extension when MapGrid supports a wider range.
##
## [b]Bridge flag denormalisation[/b]: when [code]def_tile.terrain_type == BRIDGE[/code],
## BOTH [code]bridge_no_flank = true[/code] AND [code]&"bridge_no_flank"[/code]
## in [code]special_rules[/code] are set (ADR-0008 §Decision 6 — Damage Calc may
## check either; the bool field is O(1) vs array scan).
##
## [b]Elevation table storage note[/b]: [code]_elevation_table[/code] entries are
## raw Dictionaries [code]{"attack_mod": int, "defense_mod": int}[/code] (not typed
## Resources) — see [method _apply_config] and [method _fall_back_to_defaults].
## Access via string keys only; [code]elev.attack_mod[/code] would be a parse error.
##
## Usage:
##   var cm: CombatModifiers = TerrainEffect.get_combat_modifiers(
##       grid, Vector2i(2, 3), Vector2i(3, 3))
##   print(cm.defender_terrain_def)   # e.g. 7 for HILLS with delta=+1
##   if cm.bridge_no_flank:
##       print("Bridge: FLANK treated as FRONT by Damage Calc")
static func get_combat_modifiers(
		grid: MapGrid,
		atk_coord: Vector2i,
		def_coord: Vector2i
) -> CombatModifiers:
	if not _config_loaded:
		load_config()
	var atk_tile: MapTileData = grid.get_tile(atk_coord) if grid != null else null
	var def_tile: MapTileData = grid.get_tile(def_coord) if grid != null else null
	if atk_tile == null or def_tile == null:
		return CombatModifiers.new()  # OOB → zero-fill (same pattern as get_terrain_modifiers)
	var raw_delta: int = atk_tile.elevation - def_tile.elevation
	var clamped_delta: int = clampi(raw_delta, -2, 2)
	if clamped_delta != raw_delta:
		push_warning(
			"delta_elevation %d clamped to ±2 — update CR-2 table for new elevation range"
			% raw_delta
		)
	# _elevation_table stores raw Dicts: {"attack_mod": int, "defense_mod": int}
	# (story-003 _apply_config() lines 387-390 + _fall_back_to_defaults() lines 461-465).
	# Access via string keys, NOT typed Resource properties.
	# Table-completeness invariant: _validate_config (story-003) rejects any config missing
	# the 5 elevation deltas (-2..+2) or 8 terrain types (0..7), and _fall_back_to_defaults
	# repopulates the canonical entries on parse/validation failure. Both paths set
	# _config_loaded=true only AFTER the tables are fully populated. The lazy-load guard
	# above plus this contract guarantees both lookups always find their key by the time
	# this method reads them — no defensive guard needed at the call site.
	var elev: Dictionary = _elevation_table[clamped_delta] as Dictionary
	var terrain: TerrainModifiers = _terrain_table[def_tile.terrain_type] as TerrainModifiers
	# total_def combines terrain base with elevation penalty/bonus for the DEFENDER.
	# Uses "defense_mod" (defender's elevation perspective), NOT "attack_mod".
	# E.g. delta=+2 → defense_mod=-15 → PLAINS(0)+(-15)=-15 amplifies damage (CR-3e+EC-1).
	var total_def: int = terrain.defense_bonus + (elev["defense_mod"] as int)
	var result := CombatModifiers.new()
	result.defender_terrain_def = clampi(total_def, -_max_defense_reduction, _max_defense_reduction)
	result.defender_terrain_eva = clampi(terrain.evasion_bonus, 0, _max_evasion)
	result.elevation_atk_mod = elev["attack_mod"] as int
	result.elevation_def_mod = elev["defense_mod"] as int
	result.bridge_no_flank = (def_tile.terrain_type == BRIDGE)
	# G-2: .assign() preserves Array[StringName] typing; .duplicate() demotes to untyped Array.
	# When def_tile is BRIDGE, terrain.special_rules already contains &"bridge_no_flank"
	# (populated in _fall_back_to_defaults() + _apply_config()), so rules.assign() propagates
	# that flag automatically — bridge_no_flank bool and special_rules remain consistent.
	var rules: Array[StringName] = []
	rules.assign(terrain.special_rules)
	result.special_rules = rules
	return result

## Returns the normalized AI terrain-score for the tile at [param coord].
##
## Formula F-3 (GDD terrain-effect.md):
##   [code](defense_bonus + evasion_bonus * _evasion_weight) / _max_possible_score[/code]
##
## Result is in [0.0, 1.0] for all canonical CR-1 terrain types with default
## configuration (MAX_POSSIBLE_SCORE = 43.0 = FORTRESS_WALL_DEF(25) + FOREST_EVA(15)*1.2).
## No terrain in the canonical CR-1 table reaches exactly 1.0 by design.
##
## EC-5: elevation-agnostic — this method has no [code]attacker_coord[/code] or
## elevation parameter. AI consumers that need elevation-aware scoring must call
## [method get_combat_modifiers] separately and combine results.
##
## Lazy-triggers [method load_config] on first call if not yet loaded (same
## contract as [method get_terrain_modifiers] — the two methods are independent
## lazy entry points; neither assumes the other was called first).
##
## Usage:
##   var score: float = TerrainEffect.get_terrain_score(grid, Vector2i(3, 5))
##   # HILLS → (15 + 0) / 43.0 ≈ 0.3488
static func get_terrain_score(grid: MapGrid, coord: Vector2i) -> float:
	if not _config_loaded:
		load_config()
	var mods: TerrainModifiers = get_terrain_modifiers(grid, coord)
	return (mods.defense_bonus + mods.evasion_bonus * _evasion_weight) / _max_possible_score
