# Story 005: Attack action — _resolve_attack chain + DamageCalc + HPStatusController integration

> **Epic**: Grid Battle Controller | **Status**: Ready | **Layer**: Feature | **Type**: Logic | **Estimate**: 4h (largest single story in epic)
> **ADR**: ADR-0014 §5 + Implementation Notes + grid-battle.md §198

## Acceptance Criteria

- [ ] **AC-1** `is_tile_in_attack_range(tile: Vector2i, unit_id: int) -> bool` public callback per input-handling §9 partner contract — validates: tile contains an enemy unit (different `side`) AND within attacker's `attack_range` (Manhattan distance; 1 for melee, 2 for 황충 ranged)
- [ ] **AC-2** `_resolve_attack(attacker: BattleUnit, defender: BattleUnit) -> int` chain (per ADR-0014 §5):
  1. `formation_count = _count_adjacent_allies(attacker)` — same-side units within Manhattan distance 1
  2. `formation_mult = minf(1.0 + 0.05 * float(formation_count), 1.20)` — chapter-prototype proven shape; cap at +20%
  3. `angle = _attack_angle(attacker, defender)` — returns "front"/"side"/"rear" per defender's `facing`
  4. `angle_mult` per match arm: front=1.0, side=1.25, rear=1.50 (rear=1.75 if `attacker.passive == "rear_specialist"` — 황충 special)
  5. `aura_mult = 1.15 if _has_adjacent_command_aura(attacker) else 1.0` — 유비 (command_aura passive) adjacent gives +15%
  6. Construct `ResolveModifiers` with `formation_atk_bonus = formation_mult - 1.0`, `angle_mult`, `aura_mult` (3 NEW fields per story-005 same-patch obligation)
  7. `resolved_damage: int = DamageCalc.resolve(attacker_context, defender_context, modifiers)` — **STATIC call, NOT instance** per godot-specialist revision #2
  8. `_hp_controller.apply_damage(defender.unit_id, resolved_damage, attack_type, source_flags)` — **4-PARAM signature** per shipped HPStatusController (NOT 2-param per ADR sketches; story-005 must construct attack_type + source_flags Array correctly)
  9. After lethal damage: `_hp_controller.apply_death_consequences(defender.unit_id)` invoked EXPLICITLY per grid-battle.md line 198 (DEMORALIZED propagation owned by HPStatusController) BEFORE proceeding to victory check
- [ ] **AC-3** `_attack_angle(attacker, defender) -> String`: collapse 8-direction to 4 cardinal; if attacker_dir == defender.facing → "front"; if attacker_dir == (defender.facing + 2) % 4 → "rear"; else "side"
- [ ] **AC-4** `_count_adjacent_allies(unit: BattleUnit) -> int`: iterate `_units.values()`; count same-side non-dead units within Manhattan distance 1
- [ ] **AC-5** `_has_adjacent_command_aura(attacker: BattleUnit) -> bool`: iterate `_units.values()`; return true if any same-side non-dead unit with `passive == "command_aura"` within Manhattan distance 1 of attacker
- [ ] **AC-6** Emit `damage_applied(attacker_id: int, defender_id: int, damage: int)` controller-LOCAL signal AFTER apply_damage chain
- [ ] **AC-7** `ResolveModifiers` Resource extension: 3 NEW `@export` fields added to `src/feature/damage_calc/resolve_modifiers.gd` (or wherever it lives) — `formation_atk_bonus: float = 0.0`, `angle_mult: float = 1.0`, `aura_mult: float = 1.0`. Additive per ADR-0012 schema-evolution rules; existing tests not affected
- [ ] **AC-8** Multiplier verification tests (per ADR-0014 §Validation §1):
  - 황충 (rear_specialist) attacking from rear → angle_mult == 1.75
  - Same attacker from side → 1.25; from front → 1.0
  - Attacker with 2 adjacent allies → formation_mult == 1.10
  - Attacker with 4 adj → cap at 1.20
  - 유비 adjacent to attacker → aura_mult == 1.15; not adjacent → 1.0
- [ ] **AC-9** Re-entrancy regression: trigger lethal damage → assert no crash + `_check_battle_end` runs deferred (NOT synchronously inside `_resolve_attack`); CONNECT_DEFERRED on `unit_died` is the load-bearing prevention per AC-6 of story-001
- [ ] **AC-10** Regression baseline maintained: ≥757 + new tests / 0 errors / 0 orphans / Exit 0; new test file `tests/unit/feature/grid_battle/grid_battle_controller_attack_test.gd` adds ≥10 tests covering AC-1..AC-9

## Implementation Notes

*Derived from ADR-0014 §5 + Implementation Notes + grid-battle.md §198 + chapter-prototype's _do_attack:*

1. **DamageCalc call site**: `DamageCalc.resolve(...)` — STATIC (NOT instance). Per godot-specialist revision #2 + verified shipped code at `src/feature/damage_calc/damage_calc.gd:69 static func resolve(...)`.
2. **HPStatusController.apply_damage 4-param signature** per shipped code:
   ```gdscript
   func apply_damage(unit_id: int, resolved_damage: int, attack_type: int, source_flags: Array) -> void
   ```
   `attack_type`: enum int from damage-calc (PHYSICAL=0, MAGICAL=1 likely). `source_flags`: Array[StringName] of attacker passive flags (e.g., `[&"passive_charge"]`). Story-005 must construct correctly — check shipped HPStatusController for exact contract.
3. **apply_death_consequences EXPLICIT call** per grid-battle.md line 198 (NOT signal-driven): `_hp_controller.apply_death_consequences(defender.unit_id)` after lethal `apply_damage`. DEMORALIZED radius propagation happens here. Story-005 must call BEFORE the post-damage `_check_battle_end` to honor "Order is enforced by explicit method call, not by signal connection order" per GDD §198.
4. **AttackerContext / DefenderContext**: DamageCalc's `resolve` may take typed Resource contexts (per shipped DamageCalc API at `src/feature/damage_calc/`). Story-005 must construct these from BattleUnit + UnitRole queries. Read shipped code at story-005 implementation time.
5. **Lethal damage chain**: resolve_damage → apply_damage (HP decrement) → check `is_alive(defender_id)` → if false: explicit apply_death_consequences → emit damage_applied signal → CONNECT_DEFERRED on unit_died queues `_on_unit_died` to end-of-frame (story-007 + story-008 wire that handler).

## Test Evidence

**Story Type**: Logic (combat math + signal emission — pure deterministic)
**Required evidence**: `tests/unit/feature/grid_battle/grid_battle_controller_attack_test.gd` — must exist + ≥10 tests + must pass
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 001 (skeleton + DI), Story 002 (BattleUnit), Story 003 (FSM dispatch routes here), Story 004 (facing system), Story 006 (per-turn consumption); requires shipped DamageCalc + HPStatusController APIs
- **Unlocks**: Story 007 (5-turn limit consumes battle_outcome from victory check), Story 008 (fate counters consume rear_attacks + assassin_kills + boss_killed signals)
