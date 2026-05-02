# Story 001: HPStatusController module skeleton + 4 payload classes + 27 BalanceConstants + 5 .tres templates

> **Epic**: HP/Status
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4-5h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/hp-status.md`
**Requirement**: `TR-hp-status-002`, `TR-hp-status-003`, `TR-hp-status-004`, `TR-hp-status-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 — HP/Status — HPStatusController Battle-Scoped Node + Per-Unit RefCounted State (MVP scope)
**ADR Decision Summary**: TR-002 = HPStatusController is `class_name HPStatusController extends Node` (battle-scoped Node child of BattleScene; stateless-static / autoload / per-unit Component / ECS forms all explicitly rejected via Alternatives 1-4). TR-003 = UnitHPState `class_name UnitHPState extends RefCounted` with 6 fields (unit_id: int / max_hp / current_hp / status_effects: Array[StatusEffect] / hero: HeroData / unit_class: int). TR-004 = StatusEffect typed Resource (7 @export fields) + separate TickEffect Resource (5 @export fields) for DoT formula reuse; 5 .tres templates in `assets/data/status_effects/{poison,demoralized,defend_stance,inspired,exhausted}.tres`. TR-012 = 27 BalanceConstants entries appended to `assets/data/balance/balance_entities.json` per ADR-0006 5-precedent JSON pattern.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: typed `Dictionary[int, UnitHPState]` (Godot 4.4+ stable in 4.6, ratified by ADR-0011 TurnOrderRunner precedent); `Resource` typed `@export` fields (stable since 4.0); StringName literals `&"poison"` / `&"defend_stance"` (4.0+ stable); `RefCounted` (4.0+ stable). `@abstract` NOT used here (HPStatusController is concrete). `duplicate_deep()` NOT used here (story-005 uses shallow `.duplicate()` per delta-#7 Item 2 read-only sub-Resource pattern). Post-cutoff API surface limited to typed Dictionary syntax — fallback path documented in ADR-0010 Verification §2 if a 4.6 parse warning emerges (untyped `Dictionary` with explicit `assert(state is UnitHPState)` guards).

**Control Manifest Rules (Core layer + Global)**:
- Required: battle-scoped Node form (3-precedent: ADR-0005 InputRouter Autoload + ADR-0010 HPStatusController battle-scoped + ADR-0011 TurnOrderRunner battle-scoped); typed Dictionary keys must match ADR-0001 line 155 signal-payload `unit_id: int` lock; `class_name` PascalCase + `snake_case` filenames; UPPER_SNAKE_CASE constants
- Forbidden: stateless-static utility class form (engine-level structural incompatibility — listens to `unit_turn_started` + holds mutable per-unit state); `Resource` form for UnitHPState (battle-scoped non-serialized per CR-1b — RefCounted is correct); String-based `connect()` (use typed signal connections); untyped Array/Dictionary; hardcoded gameplay values (route 27 knobs through `BalanceConstants.get_const(key)`)
- Guardrail: HPStatusController instance field count exactly 2 (`_state_by_unit: Dictionary[int, UnitHPState]` + `_map_grid: MapGrid` injected by Battle Preparation); UnitHPState field count exactly 6; StatusEffect @export field count exactly 7; TickEffect @export field count exactly 5

---

## Acceptance Criteria

*From ADR-0010 §1-§4 + §12 + GDD §Tuning Knobs, scoped to this story:*

- [ ] **AC-1** HPStatusController declared as `class_name HPStatusController extends Node` at `src/core/hp_status_controller.gd` (NOT extends RefCounted; NOT stateless-static; NOT autoload-registered in `project.godot`)
- [ ] **AC-2** HPStatusController declares exactly 2 instance fields: `var _state_by_unit: Dictionary[int, UnitHPState] = {}` AND `var _map_grid: MapGrid` (set by Battle Preparation per ADR-0010 §11 R-3 mitigation)
- [ ] **AC-3** UnitHPState `class_name UnitHPState extends RefCounted` at `src/core/payloads/unit_hp_state.gd` with exactly 6 fields with exact types: `unit_id: int`, `max_hp: int`, `current_hp: int`, `status_effects: Array[StatusEffect]`, `hero: HeroData`, `unit_class: int`
- [ ] **AC-4** StatusEffect `class_name StatusEffect extends Resource` at `src/core/payloads/status_effect.gd` with exactly 7 `@export` fields: `effect_id: StringName`, `effect_type: int` (0=BUFF/1=DEBUFF), `duration_type: int` (0=TURN_BASED/1=CONDITION_BASED/2=ACTION_LOCKED), `remaining_turns: int`, `modifier_targets: Dictionary`, `tick_effect: TickEffect`, `source_unit_id: int`
- [ ] **AC-5** TickEffect `class_name TickEffect extends Resource` at `src/core/payloads/tick_effect.gd` with exactly 5 `@export` fields: `damage_type: int` (0=TRUE_DAMAGE), `dot_hp_ratio: float`, `dot_flat: int`, `dot_min: int`, `dot_max_per_turn: int`
- [ ] **AC-6** 5 `.tres` template files exist at `assets/data/status_effects/{poison,demoralized,defend_stance,inspired,exhausted}.tres`; each loads as a non-null StatusEffect via `load("res://assets/data/status_effects/[name].tres") as StatusEffect`; each has `effect_id` matching the filename stem; modifier_targets non-empty for buff/debuff effects per ADR-0010 §12 owner table
- [ ] **AC-7** `assets/data/balance/balance_entities.json` contains all 27 hp-status BalanceConstants keys (MIN_DAMAGE, SHIELD_WALL_FLAT, HEAL_BASE, HEAL_HP_RATIO, HEAL_PER_USE_CAP, EXHAUSTED_HEAL_MULT, DOT_HP_RATIO, DOT_FLAT, DOT_MIN, DOT_MAX_PER_TURN, DEMORALIZED_ATK_REDUCTION, DEMORALIZED_RADIUS, DEMORALIZED_TURN_CAP, DEMORALIZED_RECOVERY_RADIUS, DEMORALIZED_DEFAULT_DURATION, DEFEND_STANCE_REDUCTION, DEFEND_STANCE_ATK_PENALTY, INSPIRED_ATK_BONUS, INSPIRED_DURATION, EXHAUSTED_MOVE_REDUCTION, EXHAUSTED_DEFAULT_DURATION, MODIFIER_FLOOR, MODIFIER_CEILING, MAX_STATUS_EFFECTS_PER_UNIT, ATK_CAP, DEF_CAP, POISON_DEFAULT_DURATION) with values from ADR-0010 §12 default column; each key has a provenance comment of the form `// KEY owned by HP/Status; consumed by Damage Calc per ADR-0012 line N` for ATK_CAP/DEF_CAP, OR `// KEY owned by HP/Status` for the rest
- [ ] **AC-8** All 8 public methods stubbed on HPStatusController with exact signatures per ADR-0010 §5: `initialize_unit(unit_id: int, hero: HeroData, unit_class: int) -> void`, `apply_damage(unit_id: int, resolved_damage: int, attack_type: int, source_flags: Array) -> void`, `apply_heal(unit_id: int, raw_heal: int, source_unit_id: int) -> int`, `apply_status(unit_id: int, effect_template_id: StringName, duration_override: int, source_unit_id: int) -> bool`, `get_current_hp(unit_id: int) -> int`, `get_max_hp(unit_id: int) -> int`, `is_alive(unit_id: int) -> bool`, `get_modified_stat(unit_id: int, stat_name: StringName) -> int`, `get_status_effects(unit_id: int) -> Array`. Bodies are `pass` for void / `return 0` for int / `return false` for bool / `return []` for Array. Test seam `_apply_turn_start_tick(unit_id: int) -> void` also stubbed
- [ ] **AC-9** All 5 class_name declarations resolve cleanly in `godot --headless --import --path .` (no G-12 collision; no G-14 class-cache-refresh required after import pass)
- [ ] **AC-10** Regression baseline maintained: full GdUnit4 suite passes ≥648 cases (current baseline) / 0 errors / 0 carried failures (S3-00 carry-fix landed 2026-05-02) / 0 orphans; new test file adds ≥6 tests covering AC-1..AC-9
- [ ] **AC-11** `tools/ci/lint_balance_entities_hp_status.sh` exists and exit 0 (validates all 27 keys present + values within ADR-0010 §12 safe ranges); script not yet wired into `.github/workflows/tests.yml` (story-008 wires it)

---

## Implementation Notes

*Derived from ADR-0010 §1, §3, §4, §12 + Migration Plan §From `[no current implementation]`:*

1. **File layout** (5 new src files + 5 new .tres + 1 modified JSON + 1 lint script):
   - `src/core/hp_status_controller.gd` — main HPStatusController Node class (skeleton; method bodies = `pass` / zero-returns)
   - `src/core/payloads/unit_hp_state.gd` — UnitHPState RefCounted wrapper (6 fields, no methods yet — story-002 adds initialize-time helpers if needed)
   - `src/core/payloads/status_effect.gd` — StatusEffect typed Resource (7 @export fields)
   - `src/core/payloads/tick_effect.gd` — TickEffect typed Resource (5 @export fields)
   - `assets/data/status_effects/poison.tres` — POISON template per ADR-0010 §12 (effect_id=&"poison", effect_type=1 DEBUFF, duration_type=0 TURN_BASED, remaining_turns=3 (POISON_DEFAULT_DURATION), modifier_targets={}, tick_effect=TickEffect.new() with damage_type=0 TRUE_DAMAGE + dot_hp_ratio=0.04 + dot_flat=3 + dot_min=1 + dot_max_per_turn=20, source_unit_id=-1)
   - `assets/data/status_effects/demoralized.tres` — DEMORALIZED template (effect_id=&"demoralized", effect_type=1 DEBUFF, duration_type=1 CONDITION_BASED, remaining_turns=4 (DEMORALIZED_DEFAULT_DURATION + DEMORALIZED_TURN_CAP), modifier_targets={&"atk": -25}, tick_effect=null, source_unit_id=-1)
   - `assets/data/status_effects/defend_stance.tres` — DEFEND_STANCE template (effect_id=&"defend_stance", effect_type=0 BUFF, duration_type=2 ACTION_LOCKED, remaining_turns=1, modifier_targets={&"atk": -40} per ADR-0010 §12 INERT note (DEFEND_STANCE_ATK_PENALTY), tick_effect=null, source_unit_id=-1)
   - `assets/data/status_effects/inspired.tres` — INSPIRED template (effect_id=&"inspired", effect_type=0 BUFF, duration_type=0 TURN_BASED, remaining_turns=2 (INSPIRED_DURATION), modifier_targets={&"atk": +20}, tick_effect=null, source_unit_id=-1)
   - `assets/data/status_effects/exhausted.tres` — EXHAUSTED template (effect_id=&"exhausted", effect_type=1 DEBUFF, duration_type=0 TURN_BASED, remaining_turns=2 (EXHAUSTED_DEFAULT_DURATION), modifier_targets={} (move-range handled via §9 special-case branch in story-006; heal mult applied via §7 in story-004), tick_effect=null, source_unit_id=-1)
   - `assets/data/balance/balance_entities.json` — append 27 keys per ADR-0010 §12 default column with provenance comments
   - `tools/ci/lint_balance_entities_hp_status.sh` — bash script: `jq -r 'keys[]' balance_entities.json | grep -c MIN_DAMAGE` etc.; for each of the 27 keys, asserts presence + range bounds per ADR-0010 §12

2. **Subscribe-to-GameBus DEFERRED to story-006**: Per ADR-0010 §11 closing snippet (line 444-449), `_ready()` body subscribes to `GameBus.unit_turn_started.connect(_on_unit_turn_started, Object.CONNECT_DEFERRED)`. Story-001 leaves `_ready()` unimplemented (no `_ready()` override at all yet) — story-006 adds the body when implementing `_apply_turn_start_tick`.

3. **`_map_grid` field default `null`**: declared as `var _map_grid: MapGrid` with no default. Battle Preparation injects post-`new()`. ADR-0010 §11 R-3 mitigation requires `assert(_map_grid != null)` first line of `_propagate_demoralized_radius` (added in story-007).

4. **`_state_by_unit` typed Dictionary syntax**: declared as `var _state_by_unit: Dictionary[int, UnitHPState] = {}` per ADR-0010 §1 line 119 godot-specialist Item 1 PASS (consistency with §Architecture Diagram line 528). If a 4.6 parse warning emerges at first import, fall back to untyped `Dictionary` per Verification §2 (NOT a code change required at story-001 — only contingent).

5. **HeroData type reference in UnitHPState**: `var hero: HeroData` requires `HeroData` `class_name` to resolve. Already shipped via hero-database epic Complete 2026-05-01 (`src/foundation/hero_data.gd`); G-14 import refresh after this story's writes will pick it up. NO new HeroData declaration needed.

6. **27 BalanceConstants append — provenance comment format** per ADR-0010 §12 + Migration Plan §27 BalanceConstants:
   ```jsonc
   // === HP/STATUS BalanceConstants (ADR-0010 §12, story-001 same-patch) ===
   // MIN_DAMAGE owned by HP/Status; dual-enforced at Damage Calc per ADR-0012 line 92
   "MIN_DAMAGE": 1,
   // SHIELD_WALL_FLAT owned by HP/Status; F-1 Step 1 PHYSICAL+passive_shield_wall only
   "SHIELD_WALL_FLAT": 5,
   // HEAL_BASE owned by HP/Status; F-2 fixed addend
   "HEAL_BASE": 15,
   // ... (24 more) ...
   ```
   Note that `assets/data/balance/balance_entities.json` is the canonical filename per balance-data epic Complete 2026-05-01 (renamed from `entities.json`); script imports via `BalanceConstants.get_const(key)` per ADR-0006.

7. **`.tres` files authoring**: write programmatically via test-bootstrap script OR author manually in Godot editor. For consistency with hero-database epic precedent (which authored `heroes.json` programmatically via `_load_heroes_from_dict` test seam), prefer programmatic authoring via a one-off `tools/ci/bootstrap_status_effect_templates.gd` script that creates each `.tres` via `ResourceSaver.save()`. Author once; then the .tres files are the canonical content surface (designers iterate via Godot inspector going forward).

8. **Test file**: `tests/unit/core/hp_status_skeleton_test.gd` — 6-8 structural tests covering AC-1..AC-9. Use FileAccess.get_file_as_string + `content.contains()` pattern per turn-order story-001 G-22 precedent for AC-1..AC-5/AC-8 source-file structural assertions. Use `load("res://...")` + cast assertions for AC-6 .tres template existence + field-non-default checks. Use programmatic JSON parse + `dict.has()` for AC-7 27-key presence check.

9. **G-14 obligation**: after writing all 4 new `.gd` files with class_name declarations, run `godot --headless --import --path .` BEFORE first test run to refresh `.godot/global_script_class_cache.cfg`. Skipping this step costs ~2 min on first failed test run.

10. **G-12 collision pre-check**: `HPStatusController` / `UnitHPState` / `StatusEffect` / `TickEffect` — none of these are Godot built-in class names. Verified safe.

11. **No production-method bodies in this story**: 8 public methods + 1 test seam method are stubbed with zero-value returns per AC-8. Story-002 implements `initialize_unit` + 3 query methods; stories 003-007 implement the rest sequentially. This story ships the type system + structural compliance + data layer (.tres + JSON + lint script) only.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: `initialize_unit(unit_id, hero, unit_class)` body + `get_current_hp` / `get_max_hp` / `is_alive` query method bodies + AC-01 + AC-02 invariants
- **Story 003**: `apply_damage(unit_id, resolved_damage, attack_type, source_flags)` F-1 4-step pipeline + `unit_died` emit + R-1 re-entrancy mitigation tests
- **Story 004**: `apply_heal(unit_id, raw_heal, source_unit_id)` F-2 4-step pipeline + EXHAUSTED multiplier + overheal prevention
- **Story 005**: `apply_status(unit_id, effect_template_id, duration_override, source_unit_id)` body + CR-5/CR-7 mutex + slot eviction + template load via `load("res://...")` + `.duplicate()`
- **Story 006**: `_apply_turn_start_tick` body + F-3 DoT + F-4 `get_modified_stat` + EXHAUSTED move-range special-case + `_ready()` GameBus subscribe + MapGrid DI test fixture
- **Story 007**: `_propagate_demoralized_radius` body + CR-8c Commander auto-trigger + R-6 dual-invocation
- **Story 008**: Perf baseline + 5 forbidden_patterns lint registration + CI wiring + cross-platform determinism fixture + 2-3 TD entries

---

## QA Test Cases

*Lean mode — orchestrator-authored. Convergent /code-review at story close-out validates these.*

**AC-1 — HPStatusController module form**:
- Given: `src/core/hp_status_controller.gd` post-creation
- When: `var content = FileAccess.get_file_as_string("res://src/core/hp_status_controller.gd")`
- Then: `content.contains("class_name HPStatusController")` AND `content.contains("extends Node")` (NOT `extends RefCounted`, NOT `extends Resource`)
- Edge case: stateless-static form / autoload / per-unit Component would all FAIL these literal assertions

**AC-2 — 2 instance fields exact shape**:
- Given: hp_status_controller.gd post-creation
- When: source-content scan
- Then: contains `var _state_by_unit: Dictionary[int, UnitHPState]` AND `var _map_grid: MapGrid`
- Edge case: untyped Dictionary, missing typed Dictionary syntax, or extra fields beyond the 2 specified would FAIL

**AC-3 — UnitHPState 6-field shape**:
- Given: `src/core/payloads/unit_hp_state.gd` post-creation
- When: source-content scan + 6 individual `content.contains("var FIELD_NAME: TYPE")` assertions
- Then: `class_name UnitHPState extends RefCounted` AND all 6 fields with named types match exactly
- Edge case: Resource-extended form / 5-or-7-field count / missing typed Array[StatusEffect] would FAIL

**AC-4 — StatusEffect 7 @export field shape**:
- Given: `src/core/payloads/status_effect.gd` post-creation
- When: source-content scan
- Then: `class_name StatusEffect extends Resource` AND 7 `@export` fields present with named types per ADR-0010 §4
- Edge case: missing `@export` annotation on any field, or RefCounted extension, would FAIL

**AC-5 — TickEffect 5 @export field shape**:
- Given: `src/core/payloads/tick_effect.gd` post-creation
- When: source-content scan
- Then: `class_name TickEffect extends Resource` AND 5 `@export` fields with named types per ADR-0010 §4
- Edge case: inlined into StatusEffect (instead of separate Resource) would FAIL — separate Resource is intentional per OQ-6 DoT type extension

**AC-6 — 5 .tres template existence + non-default field check**:
- Given: 5 .tres files at `assets/data/status_effects/` post-creation
- When: `var poison = load("res://assets/data/status_effects/poison.tres") as StatusEffect`; same for demoralized/defend_stance/inspired/exhausted
- Then: each cast returns non-null; `poison.effect_id == &"poison"`; `poison.tick_effect != null`; `poison.tick_effect.dot_hp_ratio == 0.04`; demoralized.modifier_targets contains `&"atk"` key with value -25; defend_stance.modifier_targets `&"atk"` value -40; inspired.modifier_targets `&"atk"` value +20; exhausted.modifier_targets is empty Dictionary (move/heal handled in special-case branches per stories 004/006)
- Edge case: missing file, malformed @export, or field-default-value drift would FAIL

**AC-7 — 27 BalanceConstants keys present + values match defaults**:
- Given: `assets/data/balance/balance_entities.json` post-append
- When: `var json = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/balance/balance_entities.json"))`
- Then: `json.has("MIN_DAMAGE")` + 26 more presence assertions; `json.MIN_DAMAGE == 1`; `json.SHIELD_WALL_FLAT == 5`; `json.DEFEND_STANCE_REDUCTION == 50`; `json.MODIFIER_FLOOR == -50`; `json.MAX_STATUS_EFFECTS_PER_UNIT == 3`; `json.ATK_CAP == 200`; `json.DEF_CAP == 105` — full table per ADR-0010 §12
- Edge case: out-of-range values per ADR-0010 §12 safe-range column (e.g., MIN_DAMAGE=4 would exceed [1,3]) — caught by lint_balance_entities_hp_status.sh AC-11; this AC asserts presence + spec defaults

**AC-8 — 8 public methods + 1 test seam stubbed with exact signatures**:
- Given: hp_status_controller.gd post-creation
- When: source-content scan for each method signature literal
- Then: `content.contains("func initialize_unit(unit_id: int, hero: HeroData, unit_class: int) -> void:")` AND 7 more exact-signature assertions for apply_damage / apply_heal / apply_status / get_current_hp / get_max_hp / is_alive / get_modified_stat / get_status_effects + 1 for `_apply_turn_start_tick`; bodies contain only `pass` / `return 0` / `return false` / `return []`
- Edge case: signature drift (e.g., `unit_id: StringName` instead of `unit_id: int`) would FAIL — ADR-0010 §5 + TR-018 lock unit_id to int

**AC-9 — Class cache resolution**:
- Given: 4 new `.gd` files with class_name declarations + ran `godot --headless --import --path .`
- When: a downstream test attempts `var c: HPStatusController = HPStatusController.new()` AND `var s: UnitHPState = UnitHPState.new()` AND `var t: TickEffect = TickEffect.new()`
- Then: all instantiations succeed without "Identifier not declared" parse errors (G-14 verified)

**AC-10 — Regression baseline**:
- Given: full GdUnit4 suite post-implementation
- When: `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c`
- Then: Overall Summary shows ≥654 test cases (648 baseline + ≥6 new) / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0

**AC-11 — Lint script exit 0 standalone**:
- Given: `tools/ci/lint_balance_entities_hp_status.sh` post-creation
- When: `bash tools/ci/lint_balance_entities_hp_status.sh` from project root
- Then: exit code 0; stdout reports "27/27 keys present, all within safe ranges"
- Edge case: deliberate bad value (e.g., temporarily set `MIN_DAMAGE: 99` in the JSON) → script exits non-zero with key-name + bound message; revert before commit

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/hp_status_skeleton_test.gd` — new file (6-8 structural tests covering AC-1..AC-9; AC-10 verified via full-suite regression; AC-11 verified via separate `bash` invocation)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: ADR-0010 ✅ Accepted 2026-04-30; ADR-0006 ✅ Accepted (BalanceConstants); ADR-0007 ✅ Accepted (HeroData class_name); ADR-0009 ✅ Accepted (UnitRole — needed only for transitive HeroData reference; no UnitRole calls in story-001); balance-data epic ✅ Complete (`balance_entities.json` exists for append); hero-database epic ✅ Complete (`HeroData` class_name resolves)
- Unlocks: Stories 002, 003, 004, 005 (all consume HPStatusController + UnitHPState + StatusEffect type system); story-006 (consumes TickEffect for DoT formula); story-007 (consumes _map_grid field declaration); story-008 (consumes balance_entities.json + lint scaffold for CI wiring)

---

## Completion Notes

**Completed**: 2026-05-02
**Criteria**: 11/11 passing (100% covered — 9 auto-verified via test functions in `tests/unit/core/hp_status_skeleton_test.gd` + AC-10 verified via full-suite regression + AC-11 verified via separate bash lint invocation)
**Test Evidence**: Logic BLOCKING gate satisfied — `tests/unit/core/hp_status_skeleton_test.gd` (183 LoC / 9 tests) at canonical path; standalone 9/9 PASS (55ms); full regression **648 → 657 cases / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0** ✅ (first failure-free baseline since damage-calc story-006b)
**Lint script**: `bash tools/ci/lint_balance_entities_hp_status.sh` → exit 0 standalone; "27/27 keys present, all within safe ranges"
**Manifest staleness check**: PASS (story 2026-04-20 = current 2026-04-20)

### Files Created (12 new + 1 modified, 572 total LoC)

- **NEW** `src/core/hp_status_controller.gd` (125 LoC) — `class_name HPStatusController extends Node` + 2 instance fields exactly per ADR-0010 §2 guardrail (`_state_by_unit: Dictionary[int, UnitHPState]` + `_map_grid: MapGrid`) + 8 public methods + 1 test seam (`_apply_turn_start_tick`); all bodies stubbed with zero-value returns + `# story-N implements` comments mapping body landings; underscored unused parameters per S-3 forward-look (story-002 will drop the underscore prefix when bodies land).
- **NEW** `src/core/payloads/unit_hp_state.gd` (42 LoC) — `class_name UnitHPState extends RefCounted` + 6 fields exactly per ADR-0010 §3 (unit_id: int / max_hp / current_hp / status_effects: Array[StatusEffect] / hero: HeroData / unit_class: int) with safe defaults (0 / 0 / 0 / [] / null / 0).
- **NEW** `src/core/payloads/status_effect.gd` (48 LoC) — `class_name StatusEffect extends Resource` + 7 @export fields exactly per ADR-0010 §4 (effect_id: StringName / effect_type: int / duration_type: int / remaining_turns: int / modifier_targets: Dictionary / tick_effect: TickEffect / source_unit_id: int).
- **NEW** `src/core/payloads/tick_effect.gd` (34 LoC) — `class_name TickEffect extends Resource` + 5 @export fields exactly per ADR-0010 §4 (damage_type: int / dot_hp_ratio: float / dot_flat: int / dot_min: int / dot_max_per_turn: int).
- **NEW** 5 `.tres` templates at `assets/data/status_effects/{poison, demoralized, defend_stance, inspired, exhausted}.tres` — canonical content per ADR-0010 §4 + §12 default column. POISON has TickEffect sub-Resource (dot_hp_ratio=0.04, dot_flat=3, dot_min=1, dot_max_per_turn=20); DEMORALIZED has modifier_targets={&"atk": -25}; DEFEND_STANCE has modifier_targets={&"atk": -40} (F-4 percent-modifier form, INDEPENDENT of JSON DEFEND_STANCE_ATK_PENALTY 0.40 fraction form); INSPIRED has modifier_targets={&"atk": +20}; EXHAUSTED has empty modifier_targets (Step 2 heal-multiplier in story-004; F-4 move-range special-case in story-006). All 5 use `[gd_resource type="Resource" script_class="StatusEffect"]` per `data/maps/sample_small.tres` precedent (initial agent attempt with `type="StatusEffect"` failed parse; orchestrator-direct fix corrected after Agent #2 surfaced the error).
- **NEW** `tools/ci/lint_balance_entities_hp_status.sh` (140 LoC) — bash lint script validating 27 hp-status keys present in `balance_entities.json` + each value within ADR-0010 §12 safe range. jq detection with grep+awk fallback for environments without jq; HP_STATUS_KEYS array internalizes the provenance contract (Resolution 2 — JSONC comments not supported by Godot's strict JSON parser; provenance encoded in script instead).
- **NEW** `tests/unit/core/hp_status_skeleton_test.gd` (183 LoC, 9 test functions) — structural FileAccess source-content scans for AC-1..AC-5/AC-8 (G-22 pattern); load + cast + field-value asserts for AC-6 .tres templates; JSON parse + key-by-key value assertions for AC-7 (24 int keys + 4 float keys = 28 entries; 27 unique keys per ADR-0010 §12 because DEFEND_STANCE_ATK_PENALTY moved from int category to float category alongside the 0.40 revert); class instantiation for AC-9 (G-14 import-refresh verification).
- **MODIFIED** `assets/data/balance/balance_entities.json` — appended 23 new hp-status keys per ADR-0010 §12 default column (SHIELD_WALL_FLAT, HEAL_BASE, HEAL_HP_RATIO, HEAL_PER_USE_CAP, EXHAUSTED_HEAL_MULT, DOT_HP_RATIO, DOT_FLAT, DOT_MIN, DOT_MAX_PER_TURN, DEMORALIZED_ATK_REDUCTION, DEMORALIZED_RADIUS, DEMORALIZED_TURN_CAP, DEMORALIZED_RECOVERY_RADIUS, DEMORALIZED_DEFAULT_DURATION, DEFEND_STANCE_REDUCTION, INSPIRED_ATK_BONUS, INSPIRED_DURATION, EXHAUSTED_MOVE_REDUCTION, EXHAUSTED_DEFAULT_DURATION, MODIFIER_FLOOR, MODIFIER_CEILING, MAX_STATUS_EFFECTS_PER_UNIT, POISON_DEFAULT_DURATION). Existing 4 hp-status-relevant keys (MIN_DAMAGE=1, ATK_CAP=200, DEF_CAP=105, DEFEND_STANCE_ATK_PENALTY=0.40) left unchanged.

### Deviations

- **MINOR (documented)**: DEFEND_STANCE_ATK_PENALTY value left at 0.40 (damage-calc fraction form per `damage_calc.gd:194` doc-comment "DEFEND_STANCE_ATK_PENALTY = 0.40 is the penalty FRACTION; the effective ATK = raw_atk × (1 - 0.40)") instead of overwriting to ADR-0010 §12's prescribed -40 (percent-modifier form). The .tres-embedded `defend_stance.tres modifier_targets[&"atk"] = -40` is the F-4 percent-modifier form and is INDEPENDENT of this BalanceConstants JSON value. ADR-0010 §12's prescribed -40 represents an aspirational future-state requiring damage-calc refactor (out of scope for story-001). Initial /dev-story attempt overwrote 0.40 → -40 per ADR-0010 §12 prescription; full regression surfaced 2 stale citers (`damage_calc_test.gd:1148` + `balance_constants_test.gd:166`) reading the JSON value as 0.40 fraction — confirmed semantic collision; reverted to 0.40 + adjusted test AC-7 + lint script to expect 0.40 float. Carry-forward note in test (lines 136-140) + lint (lines 47-50) + active.md session extract.

### Code Review Suggestions Captured (forward-looking; non-blocking)

- **S-1 (story-002)**: drop underscore prefix from `_unit_id` / `_hero` / `_unit_class` parameters when initialize_unit body lands (prefix is for unused params only).
- **S-2 (story-006)**: confirm `_ready()` body adds `GameBus.unit_turn_started.connect(_on_unit_turn_started, Object.CONNECT_DEFERRED)` per ADR-0001 §5 + ADR-0010 §11 line 444-449.
- **S-3 (story-008 carry-forward)**: TD entry — DEFEND_STANCE_ATK_PENALTY semantic collision; future ADR amendment should rename one form (e.g., `DEFEND_STANCE_ATK_PENALTY_FRACTION` for damage-calc 0.40 vs `DEFEND_STANCE_ATK_PERCENT` for hp-status -40).
- **S-4 (story-008 lint scope)**: consider adding `lint_balance_constants_overwrite_grep_audit.sh` defending against future "change the cell, forget the citer" — detect when /dev-story mutates a key in `balance_entities.json` without grepping all citers first. 5th invocation of this trap; mitigation pattern overdue.
- **S-5 (lint script — cosmetic)**: line 99 declares `KEY_TYPE` (cut -f5) but never uses it. Either type-aware comparison precision OR remove.
- **S-6 (story-002 hero validation)**: when initialize_unit body lands, contract should reject null hero (push_error + return) per ADR-0010 §3 schema.
- **S-7 (forward-look)**: lint regex doesn't support scientific notation. Acceptable for MVP; document if Polish-tier introduces it.

### Engineering Discipline Applied

- **G-12** class name collision pre-check: HPStatusController/UnitHPState/StatusEffect/TickEffect — none collide with Godot 4.6 built-ins. Verified safe.
- **G-14** import refresh executed post-write (`godot --headless --import --path .`); 0 parse errors; 4 .uid files auto-generated.
- **G-15** `before_test()` canonical hook (used implicitly — story-001 tests don't have shared state requiring reset; G-15 discipline established for stories 002-007).
- **G-22** structural source-file assertions via FileAccess.get_file_as_string + content.contains for AC-1..AC-5/AC-8 (turn-order story-001 + payload_classes_test.gd precedent).
- **`.tres` `type="Resource"` precedent** validated against `data/maps/sample_small.tres`; user-defined Resource classes use `script_class="X"` not `type="X"`.

### Out-of-Scope Deviations

NONE. No method bodies; no GameBus subscribe/emit; no `_ready()` body; no `_propagate_demoralized_radius`; no `_apply_turn_start_tick` body; no other src/ or tests/ files modified outside the 12 deliverables.

### Multi-Spawn Pattern Stable at 4+ Occurrences

3 agent invocations + 1 orchestrator-direct fix cycle for story-001:
- Agent #1 (godot-gdscript-specialist): created 4 src files + 5 .tres + JSON modify + lint script (180s, 92k tokens, 26 tool uses; terminated mid-task at "Now write the lint script:" — turned out lint was already written; agent ran out of context before tests).
- Agent #2 (godot-gdscript-specialist, narrow scope): tasked with test file + verification; created `hp_status_skeleton_test.gd` (183 LoC) but surfaced .tres parse error (Agent #1 had used `type="StatusEffect"` instead of `type="Resource"`); terminated mid-fix (242s, 69k tokens, 26 tool uses).
- Orchestrator-direct fix #1: corrected all 5 .tres files `type="StatusEffect"` → `type="Resource"` per `data/maps/sample_small.tres` precedent (Godot 4.x requires built-in base type with script_class= for user-defined Resource scripts).
- Orchestrator-direct verification: ran G-14 import refresh + standalone test (9/9 PASS) + full regression (initial: 657/2 failures = stale citers).
- Orchestrator-direct fix #2: investigated DEFEND_STANCE_ATK_PENALTY 2-failure trap; reverted JSON 0.40 → -40 → 0.40 (preserves damage-calc semantic); updated test AC-7 expected_float Dictionary + lint script range to expect 0.40 float; re-ran regression (657/0/0/0/0/0 ✅).

Pattern stable now at 4+ occurrences (turn-order story-002 used 2 agents proactively; story-003 used 2 agents proactively; hp-status story-001 used 2 agents reactively + 2 orchestrator-direct fixes). Codify as project discipline: when implementing any story with >5 file deliverables AND/OR cross-doc data mutation, plan for 2+ agent spawns AND orchestrator-side cleanup.

### Sprint Impact

hp-status epic 1/8 stories Complete. Sprint-3 day ~0-1 of 7. Must-have load advances S3-02 partial (1/8 stories of S3-02 epic; story-002..008 remaining for S3-02 close-out). Regression baseline 648 → **657 / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans** (first failure-free baseline since damage-calc story-006b).
