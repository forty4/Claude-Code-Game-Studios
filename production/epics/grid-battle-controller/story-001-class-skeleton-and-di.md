# Story 001: GridBattleController class skeleton + 8-param DI + 6-backend assertion + _exit_tree

> **Epic**: Grid Battle Controller | **Status**: Complete (2026-05-03) | **Layer**: Feature | **Type**: Logic (skeleton) | **Estimate**: 2h
> **ADR**: ADR-0014 §1, §3, §10 + R-4 + R-8 (Implementation Notes amended same-patch with signal-routing-via-GameBus drift fix + BattleUnit pre-existing class note + DI cleanup candidate)

## Acceptance Criteria

- [ ] **AC-1** `class_name GridBattleController extends Node` declared at `src/feature/grid_battle/grid_battle_controller.gd` (verified no Godot 4.6 ClassDB collision per ADR-0014 §1)
- [ ] **AC-2** `setup(units: Array[BattleUnit], map_grid: MapGrid, camera: BattleCamera, hero_db: HeroDatabase, turn_runner: TurnOrderRunner, hp_controller: HPStatusController, terrain_effect: TerrainEffect, unit_role: UnitRole) -> void` — **8 typed parameters** (DamageCalc NOT in DI per godot-specialist revision #2 — DamageCalc methods are `static func`, called via `DamageCalc.resolve(...)` directly)
- [ ] **AC-3** `_ready()` body asserts `_units.size() > 0` AND all 6 backend deps non-null AND BattleCamera non-null (7 separate non-null checks); without `setup()` called pre-mount, scene fails fast at mount time
- [ ] **AC-4** `_ready()` initializes `_max_turns = int(BalanceConstants.get_const("MAX_TURNS_PER_BATTLE"))` (added by story-010)
- [ ] **AC-5** `_ready()` connects 4 signals via `Object.CONNECT_DEFERRED`: `GameBus.input_action_fired` + `_hp_controller.unit_died` + `_turn_runner.unit_turn_started` + `_turn_runner.round_started`
- [ ] **AC-6** **CRITICAL** explicit comment in `_ready()` body marking `CONNECT_DEFERRED` on `unit_died` as **load-bearing reentrance prevention** (per godot-specialist revision #1 + ADR-0014 R-8): without DEFERRED, `_on_unit_died` fires synchronously inside `HPStatusController.apply_damage()` from `_resolve_attack()`, causing reentrant `_check_battle_end` mid-resolve. Future maintainers MUST NOT remove the DEFERRED flag
- [ ] **AC-7** `_exit_tree()` body explicitly disconnects all 4 signal subscriptions; null-guards on `_hp_controller` + `_turn_runner` (battle-scoped Nodes — free order not guaranteed; explicit disconnect is defensive); GameBus disconnect is mandatory (autoload, never freed → callable would dangle without explicit disconnect)
- [ ] **AC-8** Test stub for missing-setup → `_ready()` assertion fires: instantiate without `setup()` + add to tree → expect parser-time assert hit (test pattern: verify `_units` empty + `_map_grid` null pre-mount as proxy, since asserts in `_ready()` would crash test runner)
- [ ] **AC-9** Regression baseline maintained: full GdUnit4 suite passes ≥757 cases (post-camera baseline) + new tests / 0 errors / 0 failures / 0 orphans / Exit 0; new test file `tests/unit/feature/grid_battle/grid_battle_controller_lifecycle_test.gd` adds ≥4 tests covering AC-1..AC-8

## Implementation Notes

*Derived from ADR-0014 §3 + camera epic story-001 precedent:*

1. **File location**: `src/feature/grid_battle/grid_battle_controller.gd` (mirrors `src/feature/camera/battle_camera.gd` Feature-layer pattern)
2. **DI seam**: `setup()` callable BEFORE `add_child()`. `_ready()` asserts populated. Mirrors ADR-0010 + ADR-0011 + ADR-0013 pattern (4th invocation).
3. **CONNECT_DEFERRED comment template** (verbatim per ADR-0014 §3):
   ```gdscript
   # CRITICAL: CONNECT_DEFERRED on unit_died is NOT merely advisory — it is
   # load-bearing reentrance prevention. Without it, _on_unit_died could fire
   # synchronously inside HPStatusController.apply_damage() called from
   # _resolve_attack(), producing reentrant _check_battle_end() invocation
   # mid-resolve. Future maintainers MUST NOT remove the DEFERRED flag here.
   # (Per godot-specialist 2026-05-02 ADR-0014 review revision #1.)
   ```
4. **Cross-ADR audit prerequisite**: ADR-0010 HPStatusController._exit_tree ALREADY EXISTS at line 45 (verified at ADR-0014 authoring) — no retrofit needed. TurnOrderRunner audit deferred to story-009.
5. **Test pattern**: GdUnit4 `GdUnitTestSuite`, mirror `tests/unit/feature/camera/battle_camera_lifecycle_test.gd` shape — including `auto_free` discipline + GameBus subscription enumeration via `GameBus.input_action_fired.get_connections()`.

## Test Evidence

**Story Type**: Logic (skeleton; scaffolding-heavy with structural assertions)
**Required evidence**: `tests/unit/feature/grid_battle/grid_battle_controller_lifecycle_test.gd` — must exist + ≥4 tests + must pass
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: ADR-0014 Accepted ✓ (2026-05-02); BattleCamera shipped ✓ (S4-02 done)
- **Unlocks**: All other grid-battle-controller stories (002-010)
