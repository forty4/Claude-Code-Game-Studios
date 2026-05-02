# Story 006: _apply_turn_start_tick + F-3 DoT + F-4 get_modified_stat + EXHAUSTED move-range special-case + GameBus.unit_turn_started CONNECT_DEFERRED + MapGrid DI

> **Epic**: HP/Status
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/hp-status.md`
**Requirement**: `TR-hp-status-005` (consumed signal — `unit_turn_started` subscription via CONNECT_DEFERRED), `TR-hp-status-008` (turn-start tick: DoT before duration decrement; reverse-index removal; ACTION_LOCKED expiry; DEMORALIZED CONDITION_BASED recovery), `TR-hp-status-009` (F-4 modifier application + EXHAUSTED move-range special-case + DEFEND_STANCE_ATK_PENALTY pre-fold), `TR-hp-status-013` (DI test seam — `_apply_turn_start_tick` direct call + `_map_grid` constructor injection)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 — HP/Status §8 (turn-start tick) + §9 (F-4) + §11 (R-3 MapGrid DI assert) + §13 (DI test seam)
**ADR Decision Summary**: §8 `_apply_turn_start_tick(unit_id)` — production: called via GameBus.unit_turn_started subscription with CONNECT_DEFERRED per ADR-0001 §5 mandate; tests: called directly to bypass signal infrastructure. Body: (1) F-3 DoT tick BEFORE duration decrement (per GDD §States and Transitions line 243-245 ordering — POISON 3-turn ticks 3 times); (2) reverse-index `while i >= 0` Array removal pattern for TURN_BASED expiry; (3) ACTION_LOCKED `defend_stance` 1-turn expiry; (4) CR-6 SE-2 DEMORALIZED CONDITION_BASED recovery check via `_has_ally_hero_within_radius` MapGrid query. §9 `get_modified_stat(unit_id, stat_name) -> int` — F-4 sums modifier_targets across status_effects, clamps to [MODIFIER_FLOOR, MODIFIER_CEILING], applies `max(1, int(floor(base_stat * (1 + total_modifier / 100.0))))` per delta-#7 Item 9 cast; EXHAUSTED move-range special-case branch (`_has_status(state, &"exhausted")` → `result -= EXHAUSTED_MOVE_REDUCTION` after F-4 then `max(1, ...)`).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Object.CONNECT_DEFERRED` flag (4.0+ stable through 4.6 per godot-specialist 2026-04-30 Item 4); ensures cross-scene subscriber re-entrancy safety per R-1 mitigation. `Array.remove_at(i)` in reverse-index iteration (4.x stable; idiomatic Godot 4.x — forward iteration with `remove_at` would skip elements). `clamp(int, int, int) -> int` (4.x stable). `int(floor(base * (1 + mod / 100.0)))` explicit cast pattern per delta-#7 Item 9. MapGrid stub via `_map_grid: MapGrid` constructor-injected field (DI seam pattern mirrors ADR-0005 `_handle_event` + ADR-0012 ResolveModifiers.rng — 4-precedent stable).

**Control Manifest Rules (Core layer + Global)**:
- Required: `Object.CONNECT_DEFERRED` flag for GameBus.unit_turn_started subscription per ADR-0001 §5; method-reference signal handler `_on_unit_turn_started` (NOT lambda — sidesteps G-4); G-15 `_state_by_unit` cleared in `before_test()` via fresh HPStatusController.new() per test; G-15 `BalanceConstants._cache_loaded = false` reset; reverse-index Array iteration for in-place removal per delta-#7 Item 7; explicit `int(floor(...))` cast at F-4 per delta-#7 Item 9
- Forbidden: forward iteration with `remove_at` (skips elements — G-2 hazard); mutate `state.status_effects` Array element references returned from `get_status_effects` (`hp_status_consumer_mutation` forbidden_pattern lands in story-008 — story-006 ensures `get_status_effects` returns shallow copy via `state.status_effects.duplicate()`); calling `_apply_turn_start_tick` from production code directly (only via GameBus subscription); subscribing to GameBus signals OTHER than `unit_turn_started` (Validation §4 grep gate — story-008 lint enforces)
- Guardrail: `_apply_turn_start_tick` < 0.20ms minimum-spec mobile (max 3 status_effects × DoT/decrement; ADR-0010 Validation §8); `get_modified_stat` < 0.05ms; on-device measurement deferred to story-008

---

## Acceptance Criteria

*From GDD AC-13..AC-14 + AC-19 + EC-06..EC-07 + EC-11..EC-12 + EC-15 + ADR-0010 §8 + §9 + §13, scoped to this story:*

- [ ] **AC-1** `_ready()` body subscribes to `GameBus.unit_turn_started.connect(_on_unit_turn_started, Object.CONNECT_DEFERRED)` per ADR-0001 §5 + ADR-0010 §11 line 444-449 snippet; `_exit_tree()` matching `disconnect` guarded by `is_connected` per coordination-rules + control-manifest. `_on_unit_turn_started(unit_id: int) -> void` is a thin delegator: `_apply_turn_start_tick(unit_id)`. Test verifies subscription via `assert(GameBus.unit_turn_started.is_connected(_controller._on_unit_turn_started))` after `add_child(_controller)`
- [ ] **AC-2** F-3 DoT tick — POISON applied for 3 turns, ticks fire on 3 successive `_apply_turn_start_tick(1)` calls with HP decreasing per F-3 formula. Given Infantry with max_hp = 232 + POISON: `dot_damage = clamp(floor(232 * 0.04) + 3, 1, 20) = clamp(12, 1, 20) = 12`; current_hp -= 12 per tick × 3 ticks = -36 total over POISON's lifetime
- [ ] **AC-3** F-3 DoT BYPASSES F-1 intake pipeline (true damage; defense ignored): Given Infantry with passive_shield_wall + DEFEND_STANCE active, When POISON tick fires, Then `state.current_hp` decrements by F-3 result directly (bypasses Step 1 SHIELD_WALL_FLAT subtraction, Step 2 DEFEND_STANCE -50%, Step 3 MIN_DAMAGE floor); proves DoT path goes via `state.current_hp = max(0, state.current_hp - dot)` directly
- [ ] **AC-4** EC-06 POISON tick to current_hp == 0 emits unit_died: Given current_hp = 5, POISON dot_damage = 12, When tick fires, Then `current_hp = max(0, 5 - 12) = 0`; `GameBus.unit_died.emit(unit_id)` AFTER mutation; subscriber reading `get_current_hp(unit_id)` sees 0; loop returns early per "don't process further effects on dead unit" per ADR-0010 §8 line 347
- [ ] **AC-5** Reverse-index TURN_BASED duration decrement + expiry: Given unit with 3 TURN_BASED effects [POISON 3 turns, INSPIRED 2 turns, EXHAUSTED 1 turn], When tick fires once, Then POISON.remaining_turns = 2 (not yet expired), INSPIRED.remaining_turns = 1, EXHAUSTED.remaining_turns = 0 → expired and removed via `remove_at(2)`; status_effects.size() decreases from 3 to 2; reverse-index iteration confirms POISON (index 0) and INSPIRED (index 1) NOT skipped despite size mutation
- [ ] **AC-6** ACTION_LOCKED DEFEND_STANCE 1-turn expiry: Given unit with DEFEND_STANCE active (ACTION_LOCKED, remaining_turns = 1 per .tres template), When `_apply_turn_start_tick(1)` fires, Then DEFEND_STANCE removed regardless of remaining_turns counter (ACTION_LOCKED expires at next unit_turn_started per CR-13 grid-battle.md ratification + ADR-0010 §8 line 358-360)
- [ ] **AC-7** Mirrors GDD AC-19 + CR-6 SE-2: DEMORALIZED CONDITION_BASED recovery via MapGrid ally proximity. Given unit with DEMORALIZED active (CONDITION_BASED) AND `_has_ally_hero_within_radius(state, DEMORALIZED_RECOVERY_RADIUS=2) == true` (test stub returns true), When tick fires, Then DEMORALIZED removed via `_force_remove_status(state, &"demoralized")`; status_effects no longer contains DEMORALIZED. When stub returns false, DEMORALIZED retained (recovery not triggered)
- [ ] **AC-8** Mirrors GDD AC-13 + F-4: `get_modified_stat(unit_id, &"atk")` with DEMORALIZED(-25) + INSPIRED(+20) active returns base_atk × (1 + clamp(-25 + 20, -50, +50) / 100) = base_atk × 0.95. With base_atk = 82: `max(1, int(floor(82 * 0.95))) = max(1, 77) = 77`
- [ ] **AC-9** Mirrors GDD AC-14 + EC-11 + F-4 cap clamp: `get_modified_stat(unit_id, &"atk")` with DEMORALIZED(-25) + DEFEND_STANCE(-40 INERT pre-fold) active returns base_atk × (1 + clamp(-65, -50, +50) / 100) = base_atk × 0.50; with base_atk = 100: `max(1, int(floor(100 * 0.5))) = 50`
- [ ] **AC-10** EC-12: `get_modified_stat(unit_id, &"atk")` with INSPIRED(+20) + DEFEND_STANCE(-40) active returns base_atk × 0.80 (`clamp(20 - 40, -50, +50) = -20`); with base_atk = 100: 80
- [ ] **AC-11** EXHAUSTED move-range special-case (§9 special branch): `get_modified_stat(unit_id, &"effective_move_range")` with EXHAUSTED active returns `max(1, base_effective_move_range - EXHAUSTED_MOVE_REDUCTION)` (flat -1, not percent). EXHAUSTED's modifier_targets is empty for `&"effective_move_range"`; the special-case branch checks `_has_status(state, &"exhausted")` and applies `result -= 1` after F-4 then `max(1, ...)`. Verified for both EXHAUSTED-active (move = base - 1) and EXHAUSTED-not-active (move = base) cases
- [ ] **AC-12** Unknown stat_name push_error + return 0: `get_modified_stat(1, &"foo_bar")` triggers `push_error("get_modified_stat: unknown stat_name foo_bar")` AND returns 0 (defense-in-depth per ADR-0010 §9 line 388)
- [ ] **AC-13** DI seam: tests call `_apply_turn_start_tick(synthetic_unit_id)` directly via `_controller._apply_turn_start_tick(1)` — bypasses GameBus dispatch entirely. `_map_grid` injected via test fixture: `_controller._map_grid = MapGridStub.new()` where MapGridStub is a minimal stub providing `get_tile(coord)` returning controlled occupant_id values for ally-radius checks
- [ ] **AC-14** EC-07 POISON tick on current_hp = 1: Given current_hp = 1, POISON dot_damage = 1 (clamped to DOT_MIN), When tick fires, Then `max(0, 1 - 1) = 0`; unit dies. DoT MIN_DAMAGE floor (DOT_MIN = 1) is separate from F-1 MIN_DAMAGE floor (intake-only); F-3 has its own `clamp(..., DOT_MIN, DOT_MAX_PER_TURN)` per ADR-0010 §8 line 342-343
- [ ] **AC-15** Regression baseline maintained: full GdUnit4 suite passes ≥715 cases (story-005 baseline ~696 + ≥18 new) / 0 errors / 0 carried failures / 0 orphans

---

## Implementation Notes

*Derived from ADR-0010 §8 (lines 334-365 pseudocode) + §9 (lines 372-405) + §11 (R-3 MapGrid DI) + §13 (DI test seam) + Verification §11 + delta-#7 Item 7 reverse-index pattern + delta-#7 Item 9 cast convention:*

1. **`_ready()` + `_on_unit_turn_started` body** — production GameBus subscription:
   ```gdscript
   func _ready() -> void:
       GameBus.unit_turn_started.connect(_on_unit_turn_started, Object.CONNECT_DEFERRED)
       # NOTE: ADR-0010 §11 line 444-449. CONNECT_DEFERRED required by ADR-0001 §5
       # for cross-scene subscribers + R-1 re-entrancy mitigation.

   func _exit_tree() -> void:
       if GameBus.unit_turn_started.is_connected(_on_unit_turn_started):
           GameBus.unit_turn_started.disconnect(_on_unit_turn_started)

   func _on_unit_turn_started(unit_id: int) -> void:
       _apply_turn_start_tick(unit_id)  # delegates to test seam method
   ```

2. **`_apply_turn_start_tick` body** — exact structure per ADR-0010 §8 lines 334-365:
   ```gdscript
   func _apply_turn_start_tick(unit_id: int) -> void:
       var state: UnitHPState = _state_by_unit.get(unit_id)
       if state == null or state.current_hp == 0:
           return

       # F-3 DoT tick (BEFORE duration decrement so DoT gets one final tick at expiry-turn)
       for effect in state.status_effects:
           if effect.tick_effect != null and effect.tick_effect.damage_type == 0:  # 0 = TRUE_DAMAGE
               var dot: int = clamp(
                   int(floor(state.max_hp * effect.tick_effect.dot_hp_ratio)) + effect.tick_effect.dot_flat,
                   effect.tick_effect.dot_min,
                   effect.tick_effect.dot_max_per_turn
               )
               state.current_hp = max(0, state.current_hp - dot)  # bypasses F-1 intake (true damage)
               if state.current_hp == 0:
                   GameBus.unit_died.emit(unit_id)  # POISON-killed unit per EC-06
                   # CR-8c Commander auto-trigger DEMORALIZED via DoT-kill branch (R-6 mitigation):
                   # story-007 wires the call to _propagate_demoralized_radius(state) here.
                   # Story-006 stubs the comment marker; story-007 fills it.
                   return  # don't process further effects on dead unit

       # CR-5: TURN_BASED duration decrement + expiry (reverse-index for safe in-place removal)
       var i: int = state.status_effects.size() - 1
       while i >= 0:
           var effect: StatusEffect = state.status_effects[i]
           if effect.duration_type == 0:  # 0 = TURN_BASED
               effect.remaining_turns -= 1
               if effect.remaining_turns <= 0:
                   state.status_effects.remove_at(i)  # expire
           elif effect.duration_type == 2 and effect.effect_id == &"defend_stance":  # 2 = ACTION_LOCKED
               # SE-3: 1-turn DEFEND_STANCE expiry at next unit_turn_started per CR-13 grid-battle.md
               state.status_effects.remove_at(i)
           i -= 1

       # CR-6 SE-2: DEMORALIZED CONDITION_BASED recovery check (ally hero ≤ 2 manhattan)
       var demoralized: StatusEffect = _find_status(state, &"demoralized")
       if demoralized != null and _has_ally_hero_within_radius(state, BalanceConstants.get_const("DEMORALIZED_RECOVERY_RADIUS")):
           _force_remove_status(state, &"demoralized")
   ```

3. **`_has_ally_hero_within_radius(state, radius)` private helper** — uses MapGrid DI:
   ```gdscript
   func _has_ally_hero_within_radius(state: UnitHPState, radius: int) -> bool:
       assert(_map_grid != null, "HPStatusController._map_grid must be injected by Battle Preparation")
       # MVP simplified — returns true if any ally hero (Commander or named hero) is within
       # manhattan distance ≤ radius. Detailed coord lookup via _map_grid.get_tile.occupant_id.
       # Story-007 expands this for full DEMORALIZED propagation; story-006 ships the
       # minimum viable check that test stubs can override.
       var unit_coord: Vector2i = _get_unit_coord(state.unit_id)
       for other_unit_id in _state_by_unit.keys():
           var other_state: UnitHPState = _state_by_unit[other_unit_id]
           if other_state.current_hp == 0:
               continue
           if not _is_ally(state, other_state):
               continue
           if other_state.unit_class == UnitRole.UnitClass.COMMANDER or _is_hero(other_state):
               var other_coord: Vector2i = _get_unit_coord(other_unit_id)
               if _manhattan_distance(unit_coord, other_coord) <= radius:
                   return true
       return false
   ```

4. **`_get_unit_coord(unit_id)` private helper** — MapGrid query:
   ```gdscript
   func _get_unit_coord(unit_id: int) -> Vector2i:
       # Iterate _map_grid tiles to find unit; MVP O(N) scan acceptable per ADR-0010 §Performance.
       # Optimization opportunity: cache coord_to_unit reverse map (Polish-tier per TD entry — story-008).
       for x in range(_map_grid.get_map_dimensions().x):
           for y in range(_map_grid.get_map_dimensions().y):
               var coord := Vector2i(x, y)
               var tile: TileData = _map_grid.get_tile(coord)
               if tile != null and tile.occupant_id == unit_id:
                   return coord
       return Vector2i(-1, -1)  # not found — defense-in-depth
   ```

5. **`_is_ally(state_a, state_b)` + `_is_hero(state)` + `_manhattan_distance(a, b)` private helpers** — minimum stubs:
   ```gdscript
   func _is_ally(state_a: UnitHPState, state_b: UnitHPState) -> bool:
       # MVP: same hero faction. HeroData.faction not yet finalized (post-MVP scope per OQ-2).
       # Until faction field is ratified by Battle Preparation ADR, MVP uses
       # placeholder logic: same player_controlled flag. Test stubs override.
       return state_a.hero != null and state_b.hero != null and state_a.hero.faction == state_b.hero.faction

   func _is_hero(state: UnitHPState) -> bool:
       # MVP: hero defined as HeroData with non-empty name field (excludes generic Soldier units).
       # Until is_morale_anchor field lands (post-MVP per OQ-2), this approximates "named hero".
       return state.hero != null and state.hero.name != ""

   func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
       return abs(a.x - b.x) + abs(a.y - b.y)
   ```
   **Note**: `state_a.hero.faction` and `state.hero.name` field references depend on HeroData schema (shipped via hero-database epic); confirm exact field names at /dev-story spawn time. If field names differ, adjust accordingly.

6. **`get_modified_stat` body** — per ADR-0010 §9 lines 372-405:
   ```gdscript
   func get_modified_stat(unit_id: int, stat_name: StringName) -> int:
       var state: UnitHPState = _state_by_unit.get(unit_id)
       if state == null:
           return 0

       # Get base stat from UnitRole accessors per stat_name dispatch
       var base_stat: int
       match stat_name:
           &"atk": base_stat = UnitRole.get_atk(state.hero, state.unit_class)
           &"phys_def": base_stat = UnitRole.get_phys_def(state.hero, state.unit_class)
           &"mag_def": base_stat = UnitRole.get_mag_def(state.hero, state.unit_class)
           &"initiative": base_stat = UnitRole.get_initiative(state.hero, state.unit_class)
           &"effective_move_range": base_stat = UnitRole.get_effective_move_range(state.hero, state.unit_class)
           _:
               push_error("get_modified_stat: unknown stat_name %s" % stat_name)
               return 0

       # F-4: Sum modifier_targets[stat_name] across active effects
       var total_modifier: int = 0
       for effect in state.status_effects:
           if stat_name in effect.modifier_targets:
               total_modifier += effect.modifier_targets[stat_name]

       # Clamp to [MODIFIER_FLOOR, MODIFIER_CEILING] per CR-5f
       total_modifier = clamp(
           total_modifier,
           BalanceConstants.get_const("MODIFIER_FLOOR"),
           BalanceConstants.get_const("MODIFIER_CEILING")
       )

       # Apply: max(1, int(floor(base × (1 + total_modifier / 100.0))))
       var result: int = max(1, int(floor(base_stat * (1 + total_modifier / 100.0))))

       # EXHAUSTED move-range special-case branch (flat -1, not percent)
       if stat_name == &"effective_move_range" and _has_status(state, &"exhausted"):
           result -= BalanceConstants.get_const("EXHAUSTED_MOVE_REDUCTION")
           result = max(1, result)

       return result
   ```

7. **`get_status_effects` body** — shallow Array copy:
   ```gdscript
   func get_status_effects(unit_id: int) -> Array:
       var state: UnitHPState = _state_by_unit.get(unit_id)
       if state == null:
           return []
       return state.status_effects.duplicate()  # shallow Array copy; StatusEffect refs shared
       # Consumer mutation forbidden by convention (forbidden_pattern hp_status_consumer_mutation
       # — lint enforced in story-008). The shallow copy prevents accidental Array.append(),
       # but element-level mutation (e.g., `effect.remaining_turns -= 1`) would still corrupt
       # authoritative state — convention is sole defense per R-5.
   ```

8. **MapGridStub for tests** — minimum DI seam:
   ```gdscript
   # tests/helpers/map_grid_stub.gd
   class_name MapGridStub extends Node

   var _stub_dimensions: Vector2i = Vector2i(8, 8)
   var _occupants: Dictionary[Vector2i, int] = {}  # coord → unit_id

   func get_map_dimensions() -> Vector2i:
       return _stub_dimensions

   func get_tile(coord: Vector2i) -> TileData:
       var tile := TileData.new()
       tile.occupant_id = _occupants.get(coord, -1)
       return tile

   func set_occupant_for_test(coord: Vector2i, unit_id: int) -> void:
       _occupants[coord] = unit_id
   ```
   Note: this stub assumes TileData has an `occupant_id` field — verified per ADR-0004 + map-grid epic Complete 2026-04-25. Confirm at /dev-story spawn time.

9. **G-15 `before_test()` discipline**:
   ```gdscript
   func before_test() -> void:
       BalanceConstants._cache_loaded = false
       _controller = HPStatusController.new()
       _map_grid_stub = MapGridStub.new()
       _controller._map_grid = _map_grid_stub  # DI injection
       add_child(_controller)
   ```

10. **G-15 `after_test()` discipline**:
    ```gdscript
    func after_test() -> void:
        # _controller._exit_tree() handles GameBus.unit_turn_started disconnect
        # (auto-fired when remove_child + queue_free executes via Godot scene-tree teardown)
        pass
    ```

11. **Test file**: `tests/integration/core/hp_status_turn_start_tick_test.gd` — 18-22 tests covering AC-1..AC-14 (AC-15 = full regression). Tests use `_controller._apply_turn_start_tick(1)` direct calls (NOT via GameBus.unit_turn_started.emit) to keep tests deterministic and isolated.

12. **Cross-system Integration test category**: This story is the FIRST hp-status story to interact with multiple systems (GameBus signal subscription + UnitRole accessors + MapGrid DI + BalanceConstants for 4 keys). Test type `Integration` reflects the cross-system surface; located in `tests/integration/core/`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 007**: `_propagate_demoralized_radius` full body + R-6 dual-invocation (DoT-kill branch already wired in story-006 with stub comment; story-007 fills the call site). `_get_unit_coord` and `_is_ally` MVP stubs in story-006 may be REPLACED by more rigorous logic in story-007.
- **Story 008**: Perf baseline tests (`_apply_turn_start_tick` < 0.20ms, `get_modified_stat` < 0.05ms); cross-platform determinism deterministic-fixture; lint scripts including `hp_status_signal_emission_outside_domain` (verifies story-006's GameBus emit pattern is restricted to `unit_died` + subscribes only to `unit_turn_started`); `hp_status_consumer_mutation` lint test (R-5 mitigation regression); 1-2 TD entries (e.g., TD for coord_to_unit reverse cache optimization deferred to Polish).

---

## QA Test Cases

*Lean mode — orchestrator-authored.*

**AC-1 — GameBus subscription with CONNECT_DEFERRED**:
- Given: `add_child(_controller)` invoked → `_ready()` runs
- When: `GameBus.unit_turn_started.is_connected(_controller._on_unit_turn_started)` queried
- Then: returns `true`
- Edge case: `_exit_tree()` (via `remove_child(_controller)` + queue_free) → subsequent is_connected returns `false`

**AC-2 — F-3 DoT 3-tick cumulative**:
- Given: Infantry max_hp=232, current_hp=232; POISON applied via `apply_status(1, &"poison", 3, 99)`
- When: `_apply_turn_start_tick(1)` called 3 times
- Then: `current_hp == 232 - (12 * 3) == 196` after 3 ticks (12 = `clamp(int(floor(232 * 0.04)) + 3, 1, 20)`)
- Edge case: POISON expires after 3rd tick (TURN_BASED decrement to 0); 4th tick fires no DoT

**AC-3 — F-3 bypasses F-1 intake**:
- Given: Infantry with passive_shield_wall + DEFEND_STANCE active + POISON; current_hp=232
- When: `_apply_turn_start_tick(1)` (DoT path)
- Then: HP decreases by F-3 result (12) directly; SHIELD_WALL_FLAT not subtracted; DEFEND_STANCE -50% not applied; MIN_DAMAGE floor not enforced (DoT-side MIN is DOT_MIN, not MIN_DAMAGE)

**AC-4 — POISON tick to 0 emits unit_died (EC-06)**:
- Given: current_hp=5, POISON DoT=12
- When: `_apply_turn_start_tick(1)` fires
- Then: current_hp 5 → 0; GameBus.unit_died emitted with unit_id=1; subscriber sees current_hp=0; loop returns early (no further effects processed)

**AC-5 — TURN_BASED reverse-index decrement**:
- Given: 3 effects [POISON(remaining=3), INSPIRED(remaining=2), EXHAUSTED(remaining=1)]
- When: tick fires once
- Then: status_effects.size() == 2; remaining contents [POISON(remaining=2), INSPIRED(remaining=1)]; EXHAUSTED removed (remaining=0 → expired)
- Edge case: forward iteration would skip POISON (post-EXHAUSTED-removal index shift); reverse-index correctly decrements all 3 then removes one

**AC-6 — DEFEND_STANCE ACTION_LOCKED expiry at unit_turn_started**:
- Given: DEFEND_STANCE applied via apply_status (remaining_turns=1 per template)
- When: `_apply_turn_start_tick(1)` fires
- Then: DEFEND_STANCE removed regardless of remaining_turns counter (ACTION_LOCKED branch hits `remove_at(i)` directly per ADR-0010 §8 line 358-360)

**AC-7 — DEMORALIZED CONDITION_BASED recovery (GDD AC-19)**:
- Given: unit with DEMORALIZED active; ally hero stub at coord within `DEMORALIZED_RECOVERY_RADIUS=2`
- When: tick fires
- Then: DEMORALIZED removed via `_force_remove_status`; status_effects no longer contains DEMORALIZED
- Edge case (no ally in radius): DEMORALIZED retained; status_effects still contains it

**AC-8 — F-4 DEMORALIZED + INSPIRED stacking (GDD AC-13)**:
- Given: unit with DEMORALIZED(-25) + INSPIRED(+20) active; base_atk=82 (UnitRole-derived)
- When: `get_modified_stat(1, &"atk")`
- Then: returns 77 (`int(floor(82 * 0.95)) = 77`)

**AC-9 — F-4 cap clamp at floor (GDD AC-14 / EC-11)**:
- Given: DEMORALIZED(-25) + DEFEND_STANCE(-40 INERT pre-fold); base_atk=100
- When: `get_modified_stat(1, &"atk")`
- Then: returns 50 (`clamp(-65, -50, +50) = -50`; `int(floor(100 * 0.5)) = 50`)

**AC-10 — F-4 dominance INSPIRED + DEFEND_STANCE (EC-12)**:
- Given: INSPIRED(+20) + DEFEND_STANCE(-40); base_atk=100
- When: `get_modified_stat(1, &"atk")`
- Then: returns 80 (`clamp(-20, -50, +50) = -20`; `int(floor(100 * 0.8)) = 80`)

**AC-11 — EXHAUSTED move-range special-case**:
- Given: EXHAUSTED active; base_effective_move_range = 4 (UnitRole-derived for hero+class combo)
- When: `get_modified_stat(1, &"effective_move_range")`
- Then: returns 3 (4 - 1 = 3 after F-4 + special branch); EXHAUSTED's modifier_targets does NOT contain `&"effective_move_range"` (verifies special-case branch is the source of the -1)
- Edge case: base_effective_move_range = 1 + EXHAUSTED → `max(1, 1 - 1) = max(1, 0) = 1` (floor protection)

**AC-12 — Unknown stat_name push_error**:
- Given: any unit
- When: `get_modified_stat(1, &"foo_bar")`
- Then: push_error visible in stderr; return value == 0

**AC-13 — DI seam direct call**:
- Given: test injects `_controller._map_grid = MapGridStub.new()` in `before_test()`
- When: `_controller._apply_turn_start_tick(1)` called directly (NOT via GameBus.unit_turn_started.emit)
- Then: tick logic executes synchronously; test deterministic; no signal infrastructure entanglement

**AC-14 — POISON tick on current_hp=1 (EC-07)**:
- Given: current_hp=1, POISON dot_damage=1 (clamped to DOT_MIN)
- When: tick fires
- Then: current_hp 1 → 0; unit_died emitted

**AC-15 — Regression baseline**:
- Given: full GdUnit4 suite post-implementation
- When: full-suite headless run
- Then: ≥715 cases / 0 errors / 0 failures / 0 orphans / Exit 0

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/core/hp_status_turn_start_tick_test.gd` — new file (18-22 tests covering AC-1..AC-14; AC-15 verified via full-suite regression)
- `tests/helpers/map_grid_stub.gd` — new helper file for DI seam (or reuse existing helper if shipped via map-grid epic)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001 + 002 + 005 (apply_status pathway needed to set up DEMORALIZED/POISON/DEFEND_STANCE/INSPIRED/EXHAUSTED states for tests); ADR-0001 ✅ Accepted (`unit_turn_started` signal contract); ADR-0004 ✅ Accepted (MapGrid + TileData.occupant_id); ADR-0006 ✅ Accepted (BalanceConstants); ADR-0009 ✅ Accepted (UnitRole accessors); ADR-0010 ✅ Accepted; ADR-0011 ✅ Accepted (`unit_turn_started` Turn Order Domain emitter); turn-order + map-grid + unit-role + balance-data + hero-database epics ✅ Complete
- Unlocks: Story 007 (R-6 DoT-kill branch wires to `_propagate_demoralized_radius`; story-006 ships the call site stub comment); story 008 (perf baseline + signal-emission lint + R-5 consumer-mutation regression)

---

## Completion Notes
**Completed**: 2026-05-02
**Criteria**: 15/15 passing (all auto-verified via 21 integration tests + full-suite regression baseline 702→723/0/0/0/Exit 0; 6th consecutive failure-free baseline)
**Deviations** (2 ADVISORY, no BLOCKING):
- MapGridStub `extends MapGrid` (not `Node` as story note #8 implied) — required for typed-field DI compat with `_map_grid: MapGrid`; LSP-compliant override of `get_tile` + `get_map_dimensions`
- `_is_hero` uses `state.hero.name_ko` (story note #5 said `name`) — actual HeroData uses Korean field naming
**Test Evidence**: Integration — `tests/integration/core/hp_status_turn_start_tick_test.gd` (629 LoC, 21 tests) + helper `tests/helpers/map_grid_stub.gd` (34 LoC)
**Code Review**: Complete — orchestrator-direct lean-mode review (11th occurrence): APPROVED WITH SUGGESTIONS (4 advisory items: S-1 _make_hero factory hoisting carryover, S-2 doc-path nit, S-3 AC-5 internal-state coupling, S-4 _is_ally MVP placeholder pending OQ-2)
