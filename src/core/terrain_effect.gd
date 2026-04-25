## TerrainEffect — stateless terrain modifier query layer.
##
## Governing ADR: ADR-0008 Terrain Effect System (Accepted 2026-04-25).
## Exposes query methods for terrain and combat modifiers used by Damage Calc,
## AI scoring, and Battle HUD. All state is class-scope static (lazy-loaded once
## at first access); no per-battle initialisation; no Node lifecycle.
##
## TEST ISOLATION DISCIPLINE (ADR-0008 §Risks line 562):
##   Every GdUnit4 test suite that calls ANY TerrainEffect method MUST call
##   TerrainEffect.reset_for_tests() in before_each() (or at the top of every
##   test function). Failure to do so causes static-state bleed across suites
##   in the same GdUnit4 session, corrupting default-config test expectations.
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

## Terrain modifier table: int (terrain_type) → TerrainEntry data.
## Populated by load_config(); queried by get_terrain_modifiers() and get_combat_modifiers().
static var _terrain_table: Dictionary = {}  # G-1: untyped — see header

## Elevation modifier table: int (delta elevation, -2..+2) → ElevationEntry data.
## Populated by load_config(); queried by get_combat_modifiers().
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

## Resets all static state to compile-time defaults. Call in before_each() for
## every GdUnit4 test suite that touches TerrainEffect (ADR-0008 §Risks line 562).
##
## This is the ONLY method that resets _config_loaded to false. Tests must NOT
## directly mutate _terrain_table, _elevation_table, or any other static var —
## always go through reset_for_tests() + load_config(custom_path).
##
## Usage:
##   func before_each() -> void:
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

## Loads terrain configuration from a JSON file. Idempotent: if called again
## while _config_loaded is true, emits a push_warning and returns true immediately.
## The contractual signal is the return value (AC-6); the push_warning is
## informational diagnostics — it aids debugging but is NOT asserted by tests.
##
## Story-002 skeleton: returns false unconditionally; actual JSON parsing,
## _validate_config(), _apply_config(), and _fall_back_to_defaults() land in story-003.
##
## Parameters:
##   path — path to the JSON config file. Defaults to the canonical location.
##           Tests may pass a fixture path to exercise config-loading behaviour.
##
## Returns: false (skeleton; story-003 will return true on success).
##
## Usage:
##   TerrainEffect.load_config()                          # uses default path
##   TerrainEffect.load_config("res://tests/fixtures/…") # test fixture path
static func load_config(path: String = "res://assets/data/terrain/terrain_config.json") -> bool:
	if _config_loaded:
		push_warning(
			("TerrainEffect.load_config() called while _config_loaded is already true"
			+ " (path: %s) — skipping re-parse (idempotent guard).") % path
		)
		return true
	# Story-003 fills in: JSON parse, _validate_config(), _apply_config(),
	# _fall_back_to_defaults(). Skeleton returns false without parsing.
	return false
