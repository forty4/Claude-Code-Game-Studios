# Story 002: BattleUnit typed Resource + unit registry + tag-based fate-counter detection

> **Epic**: Grid Battle Controller | **Status**: Ready | **Layer**: Feature | **Type**: Logic | **Estimate**: 2h
> **ADR**: ADR-0014 §3

## Acceptance Criteria

- [ ] **AC-1** `BattleUnit` typed Resource at `src/feature/grid_battle/battle_unit.gd` — `class_name BattleUnit extends Resource` with `@export` fields: `unit_id: int`, `name: String`, `side: int` (0=player, 1=enemy), `hero_id: StringName` (lookup key for HeroDatabase), `unit_class: int` (UnitClass enum), `position: Vector2i`, `facing: int` (0..3 cardinal), `passive: StringName` (e.g., `&"bridge_blocker"`, `&"hit_and_run"`, `&"rear_specialist"`, `&"command_aura"`), `tag: StringName` (e.g., `&"tank"`, `&"assassin"`, `&"boss"` — used for fate-counter unit detection), `move_range: int`, `attack_range: int` (1=melee, 2=ranged for 황충)
- [ ] **AC-2** `_units: Dictionary[int, BattleUnit] = {}` instance field on GridBattleController; populated in `setup()` from `units: Array[BattleUnit]` parameter via `for u in units: _units[u.unit_id] = u`
- [ ] **AC-3** Tag-based fate-counter unit detection in `setup()` (per ADR-0014 §3 + chapter-prototype pattern): `_fate_tank_unit_id = _find_unit_by_tag("tank")`; `_fate_assassin_unit_id = _find_unit_by_tag("assassin")`; `_fate_boss_unit_id = _find_unit_by_tag("boss")`
- [ ] **AC-4** `_find_unit_by_tag(tag: String) -> int` helper: iterates `_units.values()`, returns first matching unit_id, or -1 if none
- [ ] **AC-5** Sole writer of `_units` (battle_runtime_state ownership per registry entry): no other class mutates the dict; HP delegated to HPStatusController per ADR-0010 ownership; position mutations only via `_do_move` (story-004)
- [ ] **AC-6** Test: instantiate 4 BattleUnits (1 tank + 1 assassin + 1 boss + 1 untagged) → assert `_fate_tank_unit_id` / `_fate_assassin_unit_id` / `_fate_boss_unit_id` populated correctly; assert untagged unit detection returns -1
- [ ] **AC-7** Regression baseline maintained: full GdUnit4 suite passes ≥757 + new tests / 0 errors / 0 orphans / Exit 0; new test file `tests/unit/feature/grid_battle/grid_battle_controller_registry_test.gd` adds ≥3 tests covering AC-2..AC-6

## Implementation Notes

*Derived from ADR-0014 §3 + chapter-prototype's HERO_POOL Dictionary structure:*

1. **BattleUnit field set** (~10 fields per AC-1) — kept intentionally lean for MVP; HP/status NOT here (delegated to HPStatusController.UnitHpState per ADR-0010 ownership)
2. **Cross-ADR delegation contract**: `BattleUnit.unit_id` is the integer key for HPStatusController + TurnOrderRunner queries; `BattleUnit.hero_id` is the StringName key for HeroDatabase lookups (BattleUnit holds the SHORTHAND; full HeroData lives in HeroDatabase)
3. **Tag taxonomy** (MVP): "tank" / "assassin" / "boss" — used ONLY for fate-counter unit detection. Per ADR-0014 §3 these are required for hidden-fate-condition tracking (story-008). Future tags may extend (e.g., "commander" for Rally ADR) — additive per CR-1d (ADR-0005 schema-evolution discipline shared across project).
4. **Sole-writer contract**: `_units` mutations live ONLY in `setup()` (initial populate) + `_do_move` (story-004 — position update). Any other class mutating `_units` triggers `grid_battle_controller_static_state` forbidden_pattern violation (story-010 lint enforces).

## Test Evidence

**Story Type**: Logic (data structure + tag detection)
**Required evidence**: `tests/unit/feature/grid_battle/grid_battle_controller_registry_test.gd` — must exist + ≥3 tests + must pass; `BattleUnit` class instantiates cleanly
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 001 (class skeleton + DI)
- **Unlocks**: Story 003 (FSM consumes _units), Story 004 (move action mutates position), Story 005 (attack consumes BattleUnit fields), Story 008 (fate counters use tag IDs)
