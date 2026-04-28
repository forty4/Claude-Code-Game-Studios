# Story 002: unit_roles.json schema + lazy-init JSON loader + safe-default fallback

> **Epic**: unit-role
> **Status**: Complete (2026-04-28) ✅ — 15/15 new tests passing + 8/8 story-001 regression = 23/23 foundation suite green (`tests/unit/foundation/`)
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 2-3 hours (S) — actual ~30min orchestrator + 1 specialist iteration round (clean run; only architectural decisions surfaced for approval, no test failures requiring re-iteration)
> **Implementation commit**: `a018da3` (2026-04-28)

## Context

**GDD**: `design/gdd/unit-role.md`
**Requirement**: `TR-unit-role-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 — Unit Role System (§4 Config Schema and Loading)
**ADR Decision Summary**: Per-class coefficients load from `assets/data/config/unit_roles.json` (this system's config, parallel to ADR-0008's `terrain_config.json`). Lazy-init via instance-form `JSON.new().parse()` (line/col diagnostics). Safe-default fallback per ADR-0008 precedent: missing/malformed config → push_error + populate defaults from a hardcoded fallback table matching GDD CR-1 + CR-4 + CR-6a values. Cache persists for the GDScript engine session.

**Engine**: Godot 4.6 | **Risk**: LOW (no post-cutoff APIs; `JSON.new().parse()` instance form stable since 4.0; `FileAccess.get_file_as_string` stable; `push_error` stable)
**Engine Notes**: Use the **instance form** `JSON.new().parse()` (NOT the static `JSON.parse_string()`) for line/col diagnostic access on parse error per ADR-0008 precedent and Godot 4.4+ idiomatic pattern. The 4.4 FileAccess return-type tightening (per `breaking-changes.md`) does not affect this code path — `get_file_as_string()` remains `String` typed.

**Control Manifest Rules (Foundation layer + direct ADR cites)**:
- Required (manifest, ADR-0004 precedent): "Configuration loaded from assets/data/[system]/[system]_config.json (owned by [system])" — UnitRole follows the same pattern with `assets/data/config/unit_roles.json`
- Required (direct, ADR-0009 §4): Lazy-init at first-access; no eager-load at boot. Cache persists for GDScript engine session
- Required (direct, ADR-0008 precedent + ADR-0009 §4): Safe-default fallback on missing/malformed config — `push_error` + populate defaults from hardcoded fallback table; do NOT crash; game must remain playable per Pillar 1
- Forbidden (direct, ADR-0009 §4): Direct read of `assets/data/balance/balance_entities.json` — global caps go through `BalanceConstants.get_const(...)` per ADR-0006 (introduced in Story 003)
- Forbidden (direct, ADR-0009): Eager-load JSON parse at autoload init or any boot path; UnitRole has no autoload registration
- Guardrail (direct, ADR-0009 §Performance): JSON parse <5ms one-time at first method call; cached `unit_roles.json` parse <2KB memory footprint

---

## Acceptance Criteria

*From GDD `design/gdd/unit-role.md` AC-20 + AC-21:*

- [ ] **AC-20 (Data-driven, no hardcoded gameplay values)**: `assets/data/config/unit_roles.json` exists with 6 class entries (cavalry, infantry, archer, strategist, commander, scout) × 12 fields per ADR-0009 §4 schema (`primary_stat`, `secondary_stat`, `w_primary`, `w_secondary`, `class_atk_mult`, `class_phys_def_mult`, `class_mag_def_mult`, `class_hp_mult`, `class_init_mult`, `class_move_delta`, `passive_tag`, `terrain_cost_table[6]`, `class_direction_mult[3]`)
- [ ] **AC-21 (Hot-reload on data change)**: Modifying `unit_roles.json` and re-launching the editor takes effect on next battle. **Documented MVP limitation**: editor restart required (matches ADR-0006 §6 BalanceConstants behavior); editor-time live-reload deferred to a future Alpha-tier ADR — out of scope for MVP
- [ ] `static func _load_coefficients() -> void` populates a private `static var _coefficients: Dictionary` cache from the JSON file using the `JSON.new().parse()` instance form
- [ ] `_coefficients_loaded` flag (declared in Story 001) is set to `true` after successful load AND after fallback population — never re-attempts load within the same session
- [ ] Missing file path (`unit_roles.json` not found): `_load_coefficients` calls `push_error` with the file path + reason, populates the hardcoded safe-default table matching GDD CR-1 + CR-4 + CR-6a values, sets `_coefficients_loaded = true`, and continues. Game remains playable
- [ ] Malformed JSON (parse error): same fallback behavior; `push_error` includes line/col from `JSON.get_error_line()` + `JSON.get_error_message()`
- [ ] Schema validation: missing required field on any class entry → `push_error` + fallback for that class only (NOT total fallback); other valid classes use their JSON values
- [ ] All 6 class entries in `unit_roles.json` match the GDD CR-1 + CR-4 + CR-6a values exactly: CAVALRY `class_atk_mult=1.1`, INFANTRY `class_phys_def_mult=1.3`, ARCHER `w_primary=0.6`+`w_secondary=0.4`, STRATEGIST `class_mag_def_mult=1.2`, COMMANDER `class_atk_mult=0.8`, SCOUT `class_init_mult=1.2`, etc. (verified per-field in test fixtures)

---

## Implementation Notes

*From ADR-0009 §4, §Migration Plan §1-§2, ADR-0008 precedent:*

1. JSON schema (top-level: 6 class entries keyed by lowercase class name):
   ```json
   {
     "cavalry": {
       "primary_stat": "stat_might",
       "secondary_stat": null,
       "w_primary": 1.0,
       "w_secondary": 0.0,
       "class_atk_mult": 1.1,
       "class_phys_def_mult": 0.8,
       "class_mag_def_mult": 0.7,
       "class_hp_mult": 0.9,
       "class_init_mult": 0.9,
       "class_move_delta": 1,
       "passive_tag": "passive_charge",
       "terrain_cost_table": [1.0, 1.0, 1.5, 2.0, 3.0, 1.0],
       "class_direction_mult": [1.0, 1.1, 1.09]
     },
     "infantry": { ... }, "archer": { ... }, "strategist": { ... }, "commander": { ... }, "scout": { ... }
   }
   ```
2. `_load_coefficients()` body shape:
   ```gdscript
   static func _load_coefficients() -> void:
       if _coefficients_loaded:
           return
       const PATH := "assets/data/config/unit_roles.json"
       var json_text := FileAccess.get_file_as_string(PATH)
       if json_text.is_empty():
           push_error("UnitRole: unit_roles.json not found at %s; using fallback defaults" % PATH)
           _populate_fallback_defaults()
           _coefficients_loaded = true
           return
       var parser := JSON.new()
       var parse_error := parser.parse(json_text)
       if parse_error != OK:
           push_error("UnitRole: unit_roles.json parse failed at line %d: %s; using fallback defaults" % [parser.get_error_line(), parser.get_error_message()])
           _populate_fallback_defaults()
           _coefficients_loaded = true
           return
       _coefficients = parser.data
       _coefficients_loaded = true
   ```
3. `_populate_fallback_defaults()` is a private static method that constructs the same Dictionary shape from hardcoded literals matching GDD CR-1/CR-4/CR-6a. The values MUST stay in sync with `unit_roles.json` shipped values; CI lint should compare on every push.
4. `terrain_cost_table` indexing: `[ROAD=0, PLAINS=1, HILLS=2, FOREST=3, MOUNTAIN=4, BRIDGE=5]` per ADR-0009 §5 + GDD CR-4. RIVER and FORTRESS_WALL are NOT in this 6-entry table (handled at Map/Grid layer per CR-4a).
5. `class_direction_mult` indexing: `[FRONT=0, FLANK=1, REAR=2]` per ADR-0009 §6 + ADR-0004 §5b ATK_DIR_* constants.
6. `passive_tag` is stored as a String in JSON (not StringName — JSON has no StringName type); convert with `&"%s" % cavalry_entry["passive_tag"]` at consumer call site OR pre-convert in `_load_coefficients` post-parse pass. Story 006 will use the const PASSIVE_TAG_BY_CLASS Dictionary directly (parse-time literal `&"passive_charge"` etc.); the JSON `passive_tag` field is for documentation + cross-system tracking + verification (CI lint asserts JSON `passive_tag` matches const `PASSIVE_TAG_BY_CLASS` value per class).
7. **Do not** read `BalanceConstants.get_const(...)` in this story — that's for global caps consumed by Story 003+. Story 002 only loads per-class coefficients.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 003: F-1..F-5 derived-stat methods that consume `_coefficients` + `BalanceConstants.get_const(...)`
- Story 004: `get_class_cost_table` reading the `terrain_cost_table` field
- Story 005: `get_class_direction_mult` reading the `class_direction_mult` field
- Story 006: `const PASSIVE_TAG_BY_CLASS` Dictionary (hardcoded parse-time const; NOT loaded from JSON in this story)
- Story 010: perf baseline test for the JSON parse cost

---

## QA Test Cases

*Logic story — automated unit test specs.*

- **AC-1 (Happy-path JSON load)**:
  - Given: `assets/data/config/unit_roles.json` exists with valid 6×12 schema
  - When: any test calls `UnitRole._load_coefficients()` (or triggers it indirectly via a Story 003+ method)
  - Then: `_coefficients_loaded` becomes `true`; `_coefficients["cavalry"]["class_atk_mult"]` returns `1.1` (per ADR-0009 §4 example); all 6 class keys are present
  - Edge cases: re-calling `_load_coefficients()` is a no-op (early return on flag check); per-session cache persists

- **AC-2 (Missing file → safe-default fallback)**:
  - Given: `assets/data/config/unit_roles.json` is renamed/removed
  - When: a test calls `UnitRole._load_coefficients()`
  - Then: `push_error` is logged with the file path + reason; `_coefficients_loaded` becomes `true`; `_coefficients` is populated from the hardcoded fallback table; calling a Story 003+ method (e.g., `get_atk` once it lands) returns the same value as it would with the shipped JSON. Game does NOT crash
  - Edge cases: file exists but is empty string → same fallback path triggered (`json_text.is_empty()` check)
  - **Test cleanup**: rename the file back at end-of-test (use `before_test`/`after_test` fixture pattern); G-15 obligation does NOT apply here (this story doesn't read BalanceConstants yet) but `_coefficients_loaded` reset IS required: `before_test() -> void: UnitRole._coefficients_loaded = false; UnitRole._coefficients = {}` (mirrors G-15 pattern preemptively for Story 003+ test setup)

- **AC-3 (Malformed JSON → safe-default fallback with line/col diagnostics)**:
  - Given: `assets/data/config/unit_roles.json` is replaced with invalid JSON (e.g., trailing comma, missing brace) via test fixture
  - When: a test calls `UnitRole._load_coefficients()`
  - Then: `push_error` is logged with line + col + parser error message (verify by capturing logged errors via GdUnit4's log assertions OR by pre-checking the parse_error code); fallback populated; game continues
  - Edge cases: 0-byte file (handled by AC-2); invalid root type (e.g., array instead of dict) → caught at first key access in fallback OR additional schema-shape check in `_load_coefficients`

- **AC-4 (Schema validation — partial fallback per class)**:
  - Given: `unit_roles.json` is valid JSON but missing the `class_atk_mult` field on the cavalry entry
  - When: a test calls `UnitRole._load_coefficients()` (and then a Story 003+ method on cavalry)
  - Then: `push_error` is logged identifying the missing field on the cavalry class; cavalry entry is replaced with the fallback table's cavalry values; other classes (infantry, archer, etc.) retain their JSON values
  - Edge cases: missing entry for a whole class (e.g., no "scout" key at all) → fallback for that class; extra/unknown keys in JSON → ignored (forward-compat for ADR-0007 expansion)

- **AC-5 (6×12 schema completeness)**:
  - Given: `unit_roles.json` ships with the values per ADR-0009 §4 + GDD CR-1 + CR-4 + CR-6a
  - When: per-field assertions run on each of the 6 classes × 12 fields
  - Then: every field matches the GDD-locked value: e.g., `cavalry.class_atk_mult == 1.1`, `infantry.class_phys_def_mult == 1.3`, `archer.w_primary == 0.6` AND `archer.w_secondary == 0.4`, `strategist.class_mag_def_mult == 1.2`, `commander.class_atk_mult == 0.8`, `scout.class_init_mult == 1.2`, `cavalry.terrain_cost_table[4] == 3.0` (MOUNTAIN), `scout.terrain_cost_table[3] == 0.7` (FOREST), `cavalry.class_direction_mult[2] == 1.09` (REAR rev 2.8 value), etc.
  - Edge cases: drift between `unit_roles.json` and fallback table → CI lint compare-step catches mismatch (see Implementation Note 3)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/foundation/unit_role_config_loader_test.gd` — exists and passes (15 test functions across 5 ACs; 366 LoC actual vs ~80-120 LoC story estimate — calibration confirms ~40 LoC per AC realistic for Logic stories with comprehensive override_failure_message + per-AC dividers + thorough doc-comments. Same calibration noted for story-001 234 LoC test file).
**Status**: [x] Created 2026-04-28 (commit `a018da3`); **15 new test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED + 8/8 story-001 regression = 23/23 foundation suite green** (153ms total runtime, macOS-Metal CI baseline)

### Architectural improvements applied during implementation (3 specialist decisions approved by orchestrator)

1. **DI pattern** — `_load_coefficients(path: String = "assets/data/config/unit_roles.json") -> void`. Optional path parameter enables clean test isolation for AC-2/AC-3/AC-4 failure-path tests via `user://` fixtures (per coding-standards.md "dependency injection over singletons"). Story Implementation Notes §2 showed const-path body; refactored to optional-param.

2. **`_build_fallback_dict()` shared helper** — DRY between total-fallback path (`_populate_fallback_defaults`) and per-class schema-validation path. Avoids duplicating 60+ LoC of hardcoded GDD-CR-1+CR-4+CR-6a Dictionary literals + eliminates cross-path drift risk. Story Implementation Notes §3 described behavior, not structure; refactor preserves identical runtime behavior.

3. **GDD-authoritative values** — pre-implementation cross-check caught ~20+ field-value errors in the orchestrator briefing (most significant: infantry was wrongly specified as dual-stat with stat_command secondary in briefing; GDD says single-stat with `stat_might`/`w_primary=1.0`; strategist `class_phys_def_mult=0.5` not 0.7; scout was wrongly specified as single-stat in briefing; GDD says dual-stat `stat_agility`+`stat_might`/`w=0.6+0.4`). Would have caused silent test failures in story-003 (formula tests) downstream.

### Code quality notes
- `var loaded: Dictionary = parser.data as Dictionary` — explicit cast applied (Godot 4.6 typed-assignment from `Variant` requires it; verification request honored)
- Schema validation uses `Array[String]` typed arrays per G-16
- G-15 honored: tests reset `_coefficients_loaded` + `_coefficients` in `before_test`
- 15 test functions vs story's "5 ACs" — more granular per-AC breakdown for diagnostic precision

---

## Dependencies

- Depends on: Story 001 (needs the `class_name UnitRole` + `_coefficients_loaded` flag declaration)
- Unlocks: Stories 003, 004, 005 (all consume `_coefficients` cache); Story 006 (independent of JSON loader but conceptually paired with passive_tag JSON-vs-const consistency check)
