## Provisional balance-data wrapper. Reads numeric tuning constants from
## `assets/data/balance/entities.json` until ADR-0006 ratifies the
## DataRegistry pattern. Call sites use `BalanceConstants.get_const(key)`
## throughout; when ADR-0006 lands, only `_load_cache()` changes — all
## call sites remain stable.
##
## Migration trigger: ADR-0006 Accepted → swap `_load_cache()` body to
## delegate to `DataRegistry.get_const()` with the same call-site signature.
##
## ADR: ADR-0008 (TerrainConfig provisional-wrapper precedent) +
##      ADR-0012 §6 (tuning constants in entities.json only) +
##      ADR-0012 §8 (provisional-dependency contract).
##
## TEST ISOLATION DISCIPLINE:
##   Every GdUnit4 test suite that calls ANY BalanceConstants method, OR
##   that mocks the cache, MUST reset the static state in before_test():
##       (load("res://src/feature/balance/balance_constants.gd") as GDScript) \
##           .set("_cache_loaded", false)
##   Failure to do so causes static-state bleed across suites in the same
##   GdUnit4 session. See balance_constants_test.gd for the canonical pattern.
class_name BalanceConstants
extends RefCounted


# ---------------------------------------------------------------------------
# Internal state — lazy-loaded on first get_const() call
# ---------------------------------------------------------------------------

const _ENTITIES_JSON_PATH: String = "res://assets/data/balance/balance_entities.json"

## Parsed constants table. Populated once by _load_cache(); never mutated thereafter.
## G-1 note: untyped Dictionary (GDScript 4.6 forbids generic Dictionary[K,V]
## syntax in static var declarations).
static var _cache: Dictionary = {}

## True once _load_cache() has completed (even if the parse failed).
## Guards re-entry: a second get_const() call after a failed load short-circuits
## rather than re-attempting the parse.
static var _cache_loaded: bool = false


# ---------------------------------------------------------------------------
# Public API (surface = 1 public static function)
# ---------------------------------------------------------------------------

## Returns the balance constant for [param key] from entities.json.
## Triggers a one-time JSON parse on the first call (lazy-load).
## Returns null and emits push_error if the key is absent from entities.json.
## Caller is responsible for casting the returned Variant to the expected type:
##   var cap: float = BalanceConstants.get_const("P_MULT_COMBINED_CAP") as float
static func get_const(key: String) -> Variant:
	if not _cache_loaded:
		_load_cache()
	if not _cache.has(key):
		push_error(
			("BalanceConstants.get_const: unknown key '%s'"
			+ " (entities.json missing this entry?)") % key
		)
		return null
	return _cache[key]


# ---------------------------------------------------------------------------
# Private — JSON load + parse (called once; subsequent calls skip via guard)
# ---------------------------------------------------------------------------

## Reads and parses `entities.json` into `_cache`. Sets `_cache_loaded = true`
## whether or not the parse succeeds so that a bad file short-circuits
## subsequent calls rather than hammering the disk on every get_const() call.
## On parse failure: `_cache` remains empty; every subsequent get_const() call
## will emit push_error for the missing key (graceful degradation).
static func _load_cache() -> void:
	var raw: String = FileAccess.get_file_as_string(_ENTITIES_JSON_PATH)
	if raw.is_empty():
		push_error(
			"BalanceConstants._load_cache: file not found or empty at "
			+ _ENTITIES_JSON_PATH
		)
		_cache_loaded = true
		return
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_cache = parsed
	else:
		push_error(
			"BalanceConstants._load_cache: JSON parse for %s yielded %s, expected Dictionary"
			% [_ENTITIES_JSON_PATH, type_string(typeof(parsed))]
		)
	_cache_loaded = true
