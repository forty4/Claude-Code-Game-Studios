# Story 003: Config JSON authoring + load_config + _validate_config + _fall_back_to_defaults

> **Epic**: terrain-effect
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 3-4 hours (JSON file authoring + 4 helper functions + 8 unit tests covering valid + 7 invalid-config scenarios + 1 fixture-corruption integration test)

## Context

**GDD**: `design/gdd/terrain-effect.md` §AC-19, AC-20 + line 583 (config file path) + EC-9 (snapshot at attack initiation) + Tuning Knobs TK-1..TK-8
**Requirement**: `TR-terrain-effect-012` (config path), `TR-terrain-effect-014` (AC-19/20 schema validation + safe defaults)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 Terrain Effect System
**ADR Decision Summary**: Configuration loaded from a single JSON file at `assets/data/terrain/terrain_config.json` using `FileAccess.get_file_as_string()` + the **instance form** of JSON parsing (`var json := JSON.new(); var err := json.parse(text)`) for line/col diagnostics. Schema validation enforces 8 terrain entries, 5 elevation deltas, fractional-value rejection, modifier ranges. On any validation failure, `push_error` + fall back to MVP defaults (CR-1 table + caps 30/30 + EVASION_WEIGHT 1.2). Game must remain playable.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `JSON.parse_string()` (static) returns `null` with no diagnostics — godot-specialist 2026-04-25 Item 3 firm-recommends instance form (`JSON.new().parse(text)` + `get_error_message()`). All numbers parsed as `float` per Item 4 — guard against fractional integers via `value != int(value)`. The `typeof != TYPE_FLOAT` clause in the integer-rejection guard rejects non-numerics (strings, null) defensively; the `value != int(value)` clause rejects fractionals. Both clauses required (chain-of-verification confirmed in 2026-04-25 architecture-review). `FileAccess.get_file_as_string()` is pre-cutoff stable.

**Control Manifest Rules (Core layer)**:
- Required: Use instance-form JSON parser (`JSON.new().parse(text)`) for line/col diagnostics — NOT the static `JSON.parse_string()`
- Required: Reject fractional integer fields via `typeof(v) != TYPE_FLOAT or v != int(v)` defensive guard
- Required: On any validation failure, `push_error(...)` + `_fall_back_to_defaults()` — game must remain playable per Pillar 1 ("battlefield always readable")
- Forbidden: Letting an invalid config crash the game / panic (`assert(...)`) — playability over correctness at the data-loading boundary
- Forbidden: Silent truncation of fractional values via `int(15.9) == 15` — must reject + fall back

---

## Acceptance Criteria

*From ADR-0008 §Decision 2 + §Notes for Implementation §1, §2, §3 + GDD AC-19, AC-20:*

- [ ] `assets/data/terrain/terrain_config.json` authored with valid schema per ADR-0008 §Decision 2 (lines 152-186): `schema_version: 1`, 8 terrain entries (PLAINS=0..ROAD=7 with canonical CR-1 values), 5 elevation deltas (-2..+2 with ±15 / ±8 / 0 modifiers), `caps: { max_defense_reduction: 30, max_evasion: 30 }`, `ai_scoring: { evasion_weight: 1.2, max_possible_score: 43.0 }`, `cost_matrix: { default_multiplier: 1 }`
- [ ] `static func load_config(path: String = "res://assets/data/terrain/terrain_config.json") -> bool` reads the file via `FileAccess.get_file_as_string()`, parses via instance-form `JSON.new().parse(text)`, calls `_validate_config(parsed)`, then `_apply_config(parsed)` if valid; returns `true` on success
- [ ] On parse failure (instance-form `parse()` returns `!= OK`): `push_error("terrain_config: " + json.get_error_message())` + `_fall_back_to_defaults()` + return `false`
- [ ] On validation failure: `push_error("terrain_config validation: " + reason)` + `_fall_back_to_defaults()` + return `false`
- [ ] `_validate_config(parsed: Variant) -> bool` enforces: `schema_version == 1`; all 8 terrain types present (keys "0".."7"); all 5 elevation deltas present (keys "-2".."2"); `defense_bonus`/`evasion_bonus` non-negative integers ≤ 50; `attack_mod`/`defense_mod` integers in [-25, +25]; cap values positive integers ≤ 50; `ai_scoring.evasion_weight` finite float in (0, 5]; `cost_matrix.default_multiplier` positive integer
- [ ] Integer-field rejection: `typeof(v) != TYPE_FLOAT or v != int(v)` — non-numerics fire first clause, fractionals fire second clause (defensive both directions)
- [ ] `_apply_config(parsed: Dictionary) -> void` populates `_terrain_table`, `_elevation_table`, `_max_defense_reduction`, `_max_evasion`, `_evasion_weight`, `_max_possible_score`, `_cost_default_multiplier` from the parsed dict; sets `_config_loaded = true` last (after all fields set)
- [ ] `_fall_back_to_defaults()` populates `_terrain_table` and `_elevation_table` with the canonical CR-1 + CR-2 values (so default behavior matches a valid config); other static vars stay at their compile-time defaults; sets `_config_loaded = true`
- [ ] Lazy-init idempotent guard: re-calling `load_config()` when `_config_loaded == true` returns `true` immediately without re-parsing (already in story-002 skeleton; this story preserves the contract through the full implementation)

---

## Implementation Notes

*Derived from ADR-0008 §Decision 2 + §Notes for Implementation:*

- **Instance-form JSON parser is mandatory**, not optional, per godot-specialist Item 3. Pattern:
  ```gdscript
  var text: String = FileAccess.get_file_as_string(path)
  if text.is_empty():
      push_error("terrain_config: file not found or empty at " + path)
      _fall_back_to_defaults()
      return false
  var json := JSON.new()
  var err: int = json.parse(text)
  if err != OK:
      push_error("terrain_config parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
      _fall_back_to_defaults()
      return false
  if not _validate_config(json.data):
      _fall_back_to_defaults()
      return false
  _apply_config(json.data)
  _config_loaded = true
  return true
  ```
- **Order of operations matters**: `_config_loaded = true` is set ONLY at the end of the success path, after `_apply_config` completes. `_fall_back_to_defaults()` ALSO sets `_config_loaded = true` so that subsequent `load_config()` calls are no-ops (the system is now "loaded" with the safe defaults). This means a corrupt config does NOT trigger repeated parse attempts on every query call.
- **Integer-field validation guard**:
  ```gdscript
  func _validate_int_field(v: Variant, field_name: String, lo: int, hi: int) -> bool:
      if typeof(v) != TYPE_FLOAT or v != int(v):
          push_error("terrain_config: %s is non-integral (got %s)" % [field_name, str(v)])
          return false
      var iv := int(v)
      if iv < lo or iv > hi:
          push_error("terrain_config: %s out of range [%d, %d] (got %d)" % [field_name, lo, hi, iv])
          return false
      return true
  ```
- The `typeof != TYPE_FLOAT` clause is correct — JSON numbers are always parsed as `TYPE_FLOAT` in Godot 4.6 (godot-specialist Item 4). A `TYPE_INT` would mean someone passed an explicit integer literal in code, not a JSON value — but defensively rejecting non-floats catches strings/null/objects that schema corruption could introduce.
- The fixture file is committed as a real asset (`assets/data/terrain/terrain_config.json`) — not a test-only fixture in `tests/fixtures/`. This is the production config; tests load it via the default path.
- For invalid-config tests, write per-test fixture files to `user://test_terrain_config_*.json` (writable scratch path), then call `load_config(test_path)`. Clean up in `after_test`.
- The 8-terrain × 2-modifier table values are non-negotiable — they come from GDD CR-1 (PLAINS 0/0, FOREST 5/15, HILLS 15/0, MOUNTAIN 20/5, RIVER 0/0, BRIDGE 5/0+`bridge_no_flank`, FORTRESS_WALL 25/0, ROAD 0/0). The 5-delta elevation values are non-negotiable — they come from GDD CR-2 + ADR-0008 §Decision 2 (delta ±2 → ±15%, ±1 → ±8%, 0 → 0).
- The `_terrain_table` Dictionary uses int keys (terrain_type) and stores either nested Dictionaries or `TerrainModifiers` instances — the implementation choice is the developer's, but the queries in story-004/005 read from this same dict. Suggest: store `TerrainModifiers` instances directly so `get_terrain_modifiers()` is a near-zero-cost dict lookup + defensive copy.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: skeleton class declaration + static var declarations + reset_for_tests + load_config skeleton signature
- Story 004: `get_terrain_modifiers()` + `get_terrain_score()` queries that read from `_terrain_table` and `_evasion_weight` / `_max_possible_score`
- Story 005: `get_combat_modifiers()` query that reads from `_terrain_table`, `_elevation_table`, `_max_defense_reduction`, `_max_evasion`
- Story 006: `cost_multiplier()` reading from `_cost_default_multiplier`
- Story 007: `max_defense_reduction()` / `max_evasion()` accessors that lazy-trigger `load_config()`

---

## QA Test Cases

*Authored from GDD AC-19, AC-20 + ADR-0008 §Decision 2 + §Notes directly (lean mode — QL-STORY-READY gate skipped). Developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Real config loads successfully + populates static state
  - Given: production fixture at `res://assets/data/terrain/terrain_config.json`; `reset_for_tests()` called in `before_each`
  - When: `TerrainEffect.load_config()` called with default path
  - Then: returns `true`; `_config_loaded == true`; `_terrain_table.size() == 8`; `_elevation_table.size() == 5`; `_max_defense_reduction == 30`; cap values match the JSON
  - Edge cases: this is the happy-path baseline — every other test compares against this state

- **AC-2** (AC-19 from GDD): Tuned values flow through config — modify config HILLS defense from 15 → 20 returns 20 without code change
  - Given: a test fixture at `user://test_terrain_config_tuned.json` with HILLS `defense_bonus: 20` (all other fields canonical)
  - When: `reset_for_tests()` then `load_config("user://test_terrain_config_tuned.json")`
  - Then: `_terrain_table[HILLS].defense_bonus == 20` (or equivalent; depends on storage choice)
  - Edge cases: this validates the "data-driven" promise — tuning happens in JSON, not in code

- **AC-3**: Invalid config (parse failure) → push_error + fall back to defaults + game still playable
  - Given: a malformed JSON file at `user://test_terrain_config_malformed.json` (e.g., trailing comma; unclosed brace)
  - When: `load_config` called
  - Then: returns `false`; `_config_loaded == true` (set by fallback); static state populated with canonical CR-1/CR-2 defaults so queries work; `push_error` was called (verify via `assert_error_count` or by capturing stderr)
  - Edge cases: tests that follow this one need `reset_for_tests` in `before_each` to undo the corrupt-load fallback state

- **AC-4** (AC-20 from GDD): Schema validation rejects missing required field + fall back
  - Given: a fixture missing `terrain_modifiers["3"]` (MOUNTAIN entry)
  - When: `load_config(test_path)`
  - Then: `_validate_config` returns false; `push_error` called with reason mentioning "MOUNTAIN" or "missing terrain_modifiers key 3"; fall back invoked; return `false`
  - Edge cases: validation message should help a designer find the typo — include the missing key name

- **AC-5**: Schema validation rejects fractional integer (defense_bonus = 15.5)
  - Given: a fixture with HILLS `defense_bonus: 15.5`
  - When: `load_config(test_path)`
  - Then: `_validate_int_field` (or whatever the helper is named) returns false; `push_error` mentions "non-integral" or "fractional" + the field name; fall back invoked; return `false`
  - Edge cases: this is the silent-truncation guard from ADR-0008 §Notes for Implementation §3 — `int(15.5) == 15` would silently accept; the explicit `v != int(v)` guard rejects

- **AC-6**: Schema validation rejects out-of-range field (cap value 51)
  - Given: a fixture with `caps.max_defense_reduction: 51` (sanity bound is ≤ 50)
  - When: `load_config(test_path)`
  - Then: rejected; reason mentions "out of range"; fall back invoked
  - Edge cases: the runtime cap of 30 is the GDD value but the schema sanity bound is 50 — ADR-0008 §Decision 2 line 196 distinguishes these explicitly

- **AC-7**: Schema validation rejects wrong schema_version
  - Given: a fixture with `schema_version: 2` (only 1 is valid for this MVP)
  - When: `load_config(test_path)`
  - Then: rejected with reason mentioning version; fall back invoked
  - Edge cases: schema_version > 1 in the future requires this validator updated; until then, stricter is better than permissive

- **AC-8**: Lazy-init idempotent guard preserved through full implementation
  - Given: `reset_for_tests()`; `load_config()` called once successfully
  - When: `load_config()` called a second time (with default or different path)
  - Then: returns `true` immediately without re-parsing; static state from first call is preserved (verifiable by checking `_max_defense_reduction` against an outside-config-mutation done between calls)
  - Edge cases: this contract was pinned in story-002 AC-6; this story's full implementation must not break it

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/terrain_effect_config_test.gd` — must exist and pass (8 tests covering AC-1..8)
- `assets/data/terrain/terrain_config.json` — committed real fixture; the fixture itself is verified by AC-1 + AC-2
- Test fixtures for AC-3..7 written to `user://` at test time, cleaned up in `after_test`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (TerrainEffect skeleton — `_config_loaded` static var + `reset_for_tests()` test seam + `load_config()` skeleton signature must exist before this story can hang full implementation off them)
- Unlocks: Stories 004 (`get_terrain_modifiers` reads `_terrain_table`), 005 (`get_combat_modifiers` reads `_terrain_table` + `_elevation_table` + caps), 006 (`cost_multiplier` reads `_cost_default_multiplier`), 007 (cap accessors lazy-trigger `load_config`)
