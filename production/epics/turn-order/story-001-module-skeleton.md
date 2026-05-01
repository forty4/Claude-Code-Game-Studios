# Story 001: TurnOrderRunner module skeleton + 5 instance fields + 3 RefCounted wrappers

> **Epic**: Turn Order
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/turn-order.md`
**Requirement**: `TR-turn-order-002`, `TR-turn-order-003`, `TR-turn-order-004`, `TR-turn-order-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011 — Turn Order — TurnOrderRunner battle-scoped Node + 5 instance fields + RefCounted typed wrappers
**ADR Decision Summary**: TR-002 = TurnOrderRunner is `class_name TurnOrderRunner extends Node` (battle-scoped Node child of BattleScene; stateless-static disqualified by listen+state combination). TR-003 = 5 instance fields (`_queue: Array[int]` + `_queue_index: int` + `_round_number: int` + `_unit_states: Dictionary[int, UnitTurnState]` + `_round_state: RoundState` enum). TR-004 = 3 RefCounted typed wrappers (UnitTurnState 6 fields + TurnOrderSnapshot 2 fields + TurnOrderEntry 5 fields; NOT Resource — battle-scoped non-serialized per CR-1b). TR-022 = `unit_id: int` locks (matches ADR-0001 line 153 + ADR-0010 UnitHPState Dictionary[int, …] key consistency; distinct from `hero_id: StringName` per ADR-0007).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Dictionary[int, UnitTurnState]` typed Dictionary (Godot 4.4+ stable, ratified by ADR-0010 precedent); `Array[int]` typed array (4.0+); `RefCounted` (4.0+ stable). UnitTurnState.snapshot() uses field-by-field copy (NOT duplicate()/duplicate_deep() — those are Resource methods; godot-specialist 2026-04-30 Item 3 RefCounted idiomatic pattern).

**Control Manifest Rules (Core layer)**:
- Required: battle-scoped Node form (3-precedent: ADR-0005 InputRouter Autoload + ADR-0010 HPStatusController battle-scoped + ADR-0011 TurnOrderRunner battle-scoped); typed Dictionary keys must match ADR-0001 line 153 signal-payload `unit_id: int` lock
- Forbidden: stateless-static utility class form (engine-level structural incompatibility — listens to `unit_died` + holds mutable state); `Resource` form for per-unit/snapshot data (battle-scoped non-serialized per CR-1b); cross-script `class_name AI*` / `import AISystem` symbol references (architecture.md §1 invariant #4 — Callable-delegation per Contract 5)
- Guardrail: instance field count ≤ 5 (state-shape minimal; any 6th field requires ADR amendment); RefCounted wrapper field count exactly per ADR-0011 spec (UnitTurnState=6, TurnOrderSnapshot=2, TurnOrderEntry=5)

---

## Acceptance Criteria

*From GDD `design/gdd/turn-order.md` + ADR-0011 §Decision §State Ownership §RefCounted typed wrappers, scoped to this story:*

- [ ] **AC-1** TurnOrderRunner declared as `class_name TurnOrderRunner extends Node` (NOT extends RefCounted; NOT stateless-static)
- [ ] **AC-2** 5 instance fields declared with exact types: `_queue: Array[int]` + `_queue_index: int` + `_round_number: int` + `_unit_states: Dictionary[int, UnitTurnState]` + `_round_state: RoundState` (typed enum with 6 values: BATTLE_NOT_STARTED, BATTLE_INITIALIZING, ROUND_STARTING, ROUND_ACTIVE, ROUND_ENDING, BATTLE_ENDED)
- [ ] **AC-3** UnitTurnState `class_name UnitTurnState extends RefCounted` with exactly 6 fields: `unit_id: int`, `move_token_spent: bool`, `action_token_spent: bool`, `accumulated_move_cost: int`, `acted_this_turn: bool`, `turn_state: TurnOrderRunner.TurnState` (typed enum {IDLE, ACTING, DONE, DEAD})
- [ ] **AC-4** TurnOrderSnapshot `class_name TurnOrderSnapshot extends RefCounted` with exactly 2 fields: `round_number: int`, `queue: Array[TurnOrderEntry]`
- [ ] **AC-5** TurnOrderEntry `class_name TurnOrderEntry extends RefCounted` with exactly 5 fields: `unit_id: int`, `is_player_controlled: bool`, `initiative: int`, `acted_this_turn: bool`, `turn_state: int`
- [ ] **AC-6** UnitTurnState.snapshot() method returns NEW UnitTurnState via field-by-field copy (NOT `.duplicate()` — Resource method); test verifies returned instance is distinct object (not reference identity) AND all 6 field values match source
- [ ] **AC-7** All 4 class_name declarations resolve cleanly in godot --headless --import (no G-12 collision; no G-14 class-cache-refresh required after import pass)
- [ ] **AC-8** Regression baseline maintained: full GdUnit4 suite passes ≥564 cases / 0 errors / ≤1 carried failure / 0 orphans; new test file adds ≥4 tests for AC-1..AC-6

---

## Implementation Notes

*Derived from ADR-0011 §Decision §Module form + §State Ownership + §RefCounted typed wrappers + godot-specialist 2026-04-30 Items 1-8:*

1. **File layout** (4 new files):
   - `src/core/turn_order_runner.gd` — main TurnOrderRunner Node class (skeleton only; methods stubbed with `pass`)
   - `src/core/unit_turn_state.gd` — UnitTurnState RefCounted wrapper
   - `src/core/turn_order_snapshot.gd` — TurnOrderSnapshot RefCounted wrapper
   - `src/core/turn_order_entry.gd` — TurnOrderEntry RefCounted wrapper

2. **TurnState + RoundState enums** declared INSIDE TurnOrderRunner (nested enum scope per ADR-0011 §State Ownership; consumers reference as `TurnOrderRunner.TurnState.IDLE` / `TurnOrderRunner.RoundState.ROUND_STARTING`).

3. **UnitTurnState.snapshot() pattern** — per godot-specialist 2026-04-30 Item 3 + G-2 prevention:
   ```gdscript
   func snapshot() -> UnitTurnState:
       var copy: UnitTurnState = UnitTurnState.new()
       copy.unit_id = self.unit_id
       copy.move_token_spent = self.move_token_spent
       copy.action_token_spent = self.action_token_spent
       copy.accumulated_move_cost = self.accumulated_move_cost
       copy.acted_this_turn = self.acted_this_turn
       copy.turn_state = self.turn_state
       return copy
   ```
   NOT `return self.duplicate()` — RefCounted has no duplicate(); NOT `return self.duplicate_deep()` — Resource method; field-by-field is idiomatic.

4. **Test file**: `tests/unit/core/turn_order_runner_skeleton_test.gd` — 4-6 tests covering AC-1..AC-6 (structural assertions on class_name, field types, enum values, snapshot identity).

5. **G-14 obligation**: after writing all 4 new `.gd` files with class_name declarations, run `godot --headless --import --path .` BEFORE first test run to refresh `.godot/global_script_class_cache.cfg`. Skipping this step costs ~2 min on first failed test run.

6. **G-12 collision pre-check**: `TurnOrderRunner` / `UnitTurnState` / `TurnOrderSnapshot` / `TurnOrderEntry` — none of these are Godot built-in class names. Verified safe.

7. **No production-method implementation in this story**: `initialize_battle()`, `declare_action()`, `_advance_turn()`, the 5 query methods, and `_on_unit_died()` are stubbed with `pass` — story-002 through story-006 implement them. This story ships the type system + structural compliance only.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: `initialize_battle(unit_roster)` BI-1..BI-6 sequence + queue construction + F-1 tie-break cascade
- **Story 003**: `_advance_turn(unit_id)` T1..T7 sequence + state machine + 3 emitted signals (round_started + unit_turn_started + unit_turn_ended)
- **Story 004**: `declare_action(unit_id, action, target)` + token validation + DEFEND_STANCE locks + 5 ActionType enum
- **Story 005**: `_on_unit_died(unit_id)` death handling + R-1 CONNECT_DEFERRED + charge accumulation F-2
- **Story 006**: Victory detection (T7 + RE2 + 4th emitted signal `victory_condition_detected`) + AC-18/AC-22 precedence rules
- **Story 007**: Perf baseline + 5 forbidden_patterns lint + G-15 6-element reset list lint + Polish-tier scaffold + TD entries

---

## QA Test Cases

*Lean mode — orchestrator-authored. Convergent /code-review at story close-out validates these.*

**AC-1 + AC-2 — Module form + 5 instance fields**:
- Given: `src/core/turn_order_runner.gd` post-creation
- When: structural source-file assertion via FileAccess.get_file_as_string + content.contains() per G-22 pattern
- Then: file contains literal `class_name TurnOrderRunner extends Node` AND 5 instance field declarations match the typed shape exactly
- Edge case: Resource form / RefCounted form / stateless-static form would FAIL these assertions

**AC-3..AC-5 — RefCounted wrapper field counts**:
- Given: 3 wrapper files post-creation
- When: structural source-file assertions for each
- Then: UnitTurnState contains exactly 6 fields with named types; TurnOrderSnapshot contains exactly 2; TurnOrderEntry contains exactly 5

**AC-6 — UnitTurnState.snapshot() identity + value parity**:
- Given: a UnitTurnState instance with non-default values for all 6 fields
- When: `var copy = original.snapshot()`
- Then: `copy != original` (object identity differs — NOT reference equal); `copy.unit_id == original.unit_id` AND all 5 other fields field-equal
- Edge case: mutating `copy.acted_this_turn = !copy.acted_this_turn` does NOT affect `original.acted_this_turn` (independence proof)

**AC-7 — Class cache resolution**:
- Given: 4 new `.gd` files with class_name declarations + ran `godot --headless --import --path .`
- When: a downstream test attempts `var t: TurnOrderRunner = TurnOrderRunner.new()` AND `var u: UnitTurnState = UnitTurnState.new()`
- Then: both succeed without "Identifier not declared" parse errors (G-14 verified)

**AC-8 — Regression baseline**:
- Given: full GdUnit4 suite post-implementation
- When: `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c`
- Then: Overall Summary shows ≥568 test cases (564 baseline + ≥4 new) / 0 errors / 1 carried failure / 0 orphans / exit code 100 (≥1 failure due to pre-existing carried test_hero_data_doc_comment_contains_required_strings)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/turn_order_runner_skeleton_test.gd` — new file (4-6 structural tests)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: ADR-0011 ✅ Accepted 2026-04-30; turn-order GDD ✅ Accepted via ADR-0011 + Contract 5 prose addition 2026-05-01 (S2-06)
- Unlocks: Stories 002, 003, 004, 005, 006, 007 (all consume the type system + 5-instance-field shape established here)
