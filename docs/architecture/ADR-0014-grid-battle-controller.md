# ADR-0014: Grid Battle Controller — `GridBattleController` (MVP-scoped Battle Orchestrator)

## Status
Accepted (2026-05-02 — lean mode authoring + godot-specialist PASS WITH 2 REVISIONS resolved: revision #1 CONNECT_DEFERRED-on-unit_died as load-bearing reentrance prevention added to §3 + R-8; revision #2 DamageCalc dropped from DI signature [methods are static; call DamageCalc.resolve(...) directly] applied across §3/§5/§10/§Diagram/§ADR-Dependencies; TD-ADR PHASE-GATE skipped per `production/review-mode.txt`)

## Date
2026-05-02

## Last Verified
2026-05-02

## Decision Makers
- claude (lean mode authoring; no PHASE-GATE TD-ADR per `production/review-mode.txt`)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (orchestration Node) + Input (consumes GameBus.input_action_fired) + Rendering (mounted in BattleScene Node2D tree) |
| **Knowledge Risk** | **LOW** — uses only stable APIs: `class_name X extends Node`, `Dictionary[K, V]` typed (4.4+ stable in 4.6), `Array[Resource]`, signal emit / connect / disconnect / `Object.CONNECT_DEFERRED`, `_exit_tree()` lifecycle hook, `is_equal_approx`, `match` dispatch. No post-cutoff APIs. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` (4.6 pin), `docs/engine-reference/godot/breaking-changes.md` (no Node lifecycle changes), `docs/engine-reference/godot/deprecated-apis.md` (no relevant entries), `design/gdd/grid-battle.md` (1259 lines — MVP subset of CR-1..CR-7 + AC-GB-01..15 simple cases consumed), `design/gdd/damage-calc.md` (compute interface), `design/gdd/hp-status.md` (DEFEND_STANCE ownership per AC-GB-10b), `design/gdd/turn-order.md` (Contract 4 token API), `design/gdd/hero-database.md` (roster lookup), `design/gdd/map-grid.md` (terrain dimensions + tile data), `design/gdd/unit-role.md` (class-based stats), `design/gdd/terrain-effect.md` (modifier query), `design/gdd/input-handling.md` (§9 Bidirectional Contract: provides `is_tile_in_move_range/attack_range`), `design/gdd/formation-bonus.md` (formation math; **MVP uses inline subset** per §Decision §5 — full FormationBonusSystem orchestration deferred), `docs/architecture/ADR-0013-camera.md` (BattleCamera screen_to_grid contract), `docs/architecture/ADR-0010-hp-status.md` + `ADR-0011-turn-order.md` (battle-scoped Node precedents), `docs/architecture/ADR-0001-gamebus-autoload.md` (signal contract), `prototypes/chapter-prototype/battle_v2.gd` (~720 LoC — MVP-scope design brief, NOT refactoring source). |
| **Post-Cutoff APIs Used** | None. Same stable-API surface as ADR-0010/0011/0013 battle-scoped Node precedents. |
| **Verification Required** | (1) DI sequence — `setup(units, map_grid, camera, ...)` callable BEFORE `add_child()`; `_ready()` asserts non-null on all 7 backend deps (mirrors ADR-0013 pattern). KEEP through implementation. (2) Signal subscription auto-disconnect on `queue_free()` — same Godot 4.x SOURCE-outlives-TARGET pattern as ADR-0013 R-6: explicit `_exit_tree()` disconnect MANDATORY for all 9 GameBus subscriptions. (3) `Dictionary[int, BattleUnit]` for unit registry — verify Godot 4.6 typed Dictionary supports `Resource` value type at runtime (4.4+ stable per breaking-changes; 4.6 maintains). (4) `Object.CONNECT_DEFERRED` for input_action_fired subscription per ADR-0001 §5 mandate (re-entrancy mitigation). |

> **Knowledge Risk Note**: Domain is **LOW** risk. No post-cutoff API surface. The `grid-battle.md` GDD's full scope (1259 lines including AI substate machine, FormationBonusSystem orchestration, Rally, USE_SKILL, AOE_ALL) is **explicitly NOT covered** by this ADR — see §Decision §0 MVP scope statement. Future Godot 4.7+ that touches `Node._exit_tree()` semantics or typed Dictionary at runtime would trigger Superseded-by review of this ADR's lifecycle assumptions.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0013 BattleCamera** (Accepted 2026-05-02) — primary consumer of `screen_to_grid` for click-to-grid hit-testing. **ADR-0001 GameBus** (Accepted 2026-04-18) — subscribes to `input_action_fired(action: StringName, ctx: InputContext)` filtered for `ACTIONS_BY_CATEGORY[&"grid"]` 10 actions; emits 4-6 Battle-domain signals (TBD per Battle HUD ADR). **ADR-0010 HPStatusController** (Accepted 2026-05-02) — DI dependency; sole writer of unit HP per ownership contract. **ADR-0011 TurnOrderRunner** (Accepted 2026-05-02) — DI dependency; consumes initiative queue + token API per Contract 4. **ADR-0012 DamageCalc** (Accepted 2026-04-30) — direct static-method consumption (`DamageCalc.resolve(attacker, defender, modifiers)` — NOT DI'd because all methods are `static func`); sole-caller contract per `damage-calc.md` line 260 still honored. **ADR-0007 HeroDatabase** (Accepted 2026-04-30) — DI dependency; roster lookup at battle init. **ADR-0004 MapGrid** (Accepted 2026-04-20) — DI dependency; terrain queries + dimensions for clamp. **ADR-0008 TerrainEffect** (Accepted 2026-04-25) — DI dependency; per-tile modifier query for combat. **ADR-0009 UnitRole** (Accepted 2026-04-30) — DI dependency; class-based derived-stat queries. **ADR-0006 BalanceConstants** (Accepted 2026-04-30) — 6 new entries: formation/angle multipliers + MAX_TURNS_PER_BATTLE + hidden-fate-condition thresholds. |
| **Enables** | (1) **grid-battle-controller epic** (sprint-5 epic 10/10 Complete 2026-05-03 — closed); (2) **Battle Scene wiring** (sprint-6 — first scene that mounts Camera + GridBattleController + 7 backends); (3) **ADR-0015 Battle HUD** (Accepted 2026-05-03 via /architecture-review delta #10) — RATIFIED parameter-stable; subscribes to 4 of 5 controller-LOCAL signals (`unit_selected_changed` / `unit_moved` / `damage_applied` / `battle_outcome_resolved`) + queries `get_selected_unit_id` per ADR-0015 §3 + §5; **EXPLICITLY does NOT subscribe** to `hidden_fate_condition_progressed` per Pillar 2 lock 3-layer enforcement (test layer story-008 connection-count + source-grep lint per ADR-0015 §8 + architecture-layer registry forbidden_pattern `battle_hud_subscribes_to_hidden_fate_signal`); (4) **Scenario Progression ADR** (NOT YET WRITTEN — sprint-6 — consumes battle_outcome_resolved signal from this ADR for chapter advancement); (5) **Destiny Branch ADR** (NOT YET WRITTEN — sprint-6 — sole consumer of hidden_fate_condition_progressed signal per Pillar 2 lock; ADR-0015 §8 codifies the source-grep lint enforcing HUD non-subscription). |
| **Blocks** | grid-battle-controller Feature epic implementation (sprint-5 epic 10/10 Complete 2026-05-03 — unblocked); BattleScene mount in `scenes/battle/battle_scene.tscn`; sprint-5 + sprint-6 gameplay scope. |
| **Ordering Note** | **4th invocation** of battle-scoped Node pattern after ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner + ADR-0013 BattleCamera. **Largest** Feature-layer Node-based system in the project — central orchestrator for the 7-backend integration. Pattern stable at 4 invocations at authoring time; **extended to 5 invocations** by ADR-0015 Battle HUD (Accepted 2026-05-03 via /architecture-review delta #10 — first Presentation-layer ADR following the same DI + `_exit_tree()` discipline). |

## Context

### Problem Statement

After ADR-0013 BattleCamera Accepted, the MVP First Chapter (sprint-4..6 arc) needs a **central orchestrator** that:

1. Owns the **unit list + selection state + per-turn action tracking** for the battle.
2. Routes **click input** (via BattleCamera.screen_to_grid) to game actions (move / attack).
3. Integrates the **6 shipped backend systems** as DI dependencies (TurnOrderRunner + HPStatusController + HeroDatabase + MapGrid + TerrainEffect + UnitRole) + **DamageCalc** consumed via direct static-method call (`DamageCalc.resolve(...)` — NOT DI'd because it's all-static; sole-caller contract still honored).
4. Computes **formation + side/rear attack multipliers** (chapter-prototype's proven shape: +5%/adjacent ally cap +20%, side ×1.25, rear ×1.50 with rear_specialist passive ×1.75).
5. Honors the **input-handling §9 Bidirectional Contract**: provides `is_tile_in_move_range(tile)` + `is_tile_in_attack_range(tile, unit)` callbacks.
6. Emits **Battle-domain GameBus signals** consumed by Battle HUD (sprint-5) for unit-selection / damage-applied / battle-outcome events.
7. Tracks **hidden fate-condition counters** silently (chapter-prototype's 5-condition pattern) — the data Destiny Branch ADR (sprint-6) will judge for chapter advancement.

### Why MVP-scoped (the explicit deferral)

`grid-battle.md` GDD is **1259 lines** with full Alpha-tier scope: AI substate machine (CR-3 AI_WAITING + ai_action_ready CONNECT_ONE_SHOT + AI_DECISION_TIMEOUT_MS timer + soft-lock counter), FormationBonusSystem orchestration (CR-16 + formation_bonuses_updated signal + per-round snapshot), Rally orchestration (CR-15), USE_SKILL counter eligibility (AC-GB-15 — 3 fixture cases), AOE_ALL handling (EC-GB-02), multiple victory conditions (CR-7), closed-signal-set assertions with AI mocks (AC-GB-16). A faithful ADR covering all this would be 800+ LoC and 4-6h of work — beyond sprint-4 S4-03 capacity.

**Decision: MVP-scope this ADR explicitly**. The chapter-prototype's `battle_v2.gd` (~720 LoC) demonstrated the simple subset works for the 장판파 first-chapter use case. The full GDD scope is architecture for the Vertical Slice / Alpha milestone; this MVP ADR will be **amended or superseded** as each deferred concern lands its own ADR.

### Constraints

- **Engine pin**: Godot 4.6. No 4.7+ APIs.
- **Battle-scoped lifecycle**: Lives inside BattleScene; freed when battle ends. No autoload survival.
- **Single-source DI for 7 backends**: BattleScene wires all 7 dependencies; tests inject stubs (mirrors `tests/helpers/grid_battle_stub.gd` precedent — but this ADR's class is the REAL controller, not a stub).
- **Sprint-4 capacity**: 0.75d = 6h budgeted for this ADR; MVP-scoping is the path to fit.
- **MVP gameplay scope**: MOVE + ATTACK only (no skills); player-only turns (no AI integration); single chapter (장판파); 5-turn limit; melee-adjacency only (sole exception: 황충 range 2 ranged attack honored).
- **Performance budget**: per-frame controller update < 0.1ms (negligible — only signal handlers run); per-click event handling < 0.5ms (formation/angle calc + DamageCalc invocation + HPStatusController.apply_damage call).

### Requirements

- **R-1**: Provide `GridBattleController` battle-scoped Node mounted at `BattleScene/GridBattleController`.
- **R-2**: DI all 6 backends + BattleCamera via `setup(units, map_grid, camera, hero_db, turn_runner, hp_controller, terrain_effect, unit_role) -> void` callable BEFORE `add_child()`. (DamageCalc NOT DI'd — static-method call site uses `DamageCalc.resolve(...)` directly per godot-specialist 2026-05-02 ADR-0014 review revision #2.)
- **R-3**: Subscribe to `GameBus.input_action_fired` via `Object.CONNECT_DEFERRED`, filter for the 10 grid-domain actions; route via 2-state FSM (observation / unit_selected).
- **R-4**: Subscribe to BattleCamera click events: when click hits-tested via `camera.screen_to_grid(mouse_pos)` returns valid grid coord, dispatch to `_handle_grid_click(coord)`.
- **R-5**: Implement `is_tile_in_move_range(tile, unit) -> bool` + `is_tile_in_attack_range(tile, unit) -> bool` callbacks per input-handling §9 contract.
- **R-6**: Combat resolution per chapter-prototype's proven shape: formation +5%/adj-ally (cap +20%), angle 1.25/1.50/1.75-for-rear-specialist, command_aura +15% (유비 adjacent), then DamageCalc.resolve() then HPStatusController.apply_damage().
- **R-7**: 5-turn limit per BalanceConstants.MAX_TURNS_PER_BATTLE; on turn-out, emit battle_outcome_resolved with outcome=TURN_LIMIT_REACHED.
- **R-8**: Track 5 hidden fate-condition counters silently per chapter-prototype pattern: tank_alive_hp_pct (장비-tagged unit), assassin_kills (조운-tagged), rear_attacks (any), formation_turns (any player ≥1 adj-ally), boss_killed (boss-tagged enemy).
- **R-9**: Emit Battle-domain controller-LOCAL signals (5 total — set ratified by ADR-0015 Battle HUD Accepted 2026-05-03 via /architecture-review delta #10; subscribes to 4 of 5: unit_selected_changed / unit_moved / damage_applied / battle_outcome_resolved + EXPLICITLY NOT hidden_fate_condition_progressed per Pillar 2 lock).
- **R-10**: MANDATORY `_exit_tree()` body explicitly disconnecting ALL GameBus subscriptions (per ADR-0013 R-6 godot-specialist mandate; same Godot 4.x SOURCE-outlives-TARGET leak pattern).
- **R-11**: Forbidden-pattern compliance — sole emitter of Battle-domain signals; no static state; no external combat math (formation/angle/aura math lives here + DamageCalc only).

## Decision

### 0. MVP Scope Statement (read this first)

This ADR scopes `GridBattleController` to the **MVP First Chapter (장판파) playable surface**. The full `grid-battle.md` GDD scope (1259 lines) is **explicitly NOT covered**. Four deferral slots are reserved for future ADRs:

| Deferred concern | GDD reference | Future ADR (placeholder) |
|---|---|---|
| AI substate machine + soft-lock + AI_WAITING | grid-battle.md CR-3, AC-GB-16 | **Battle AI ADR** (sprint-7+; AI epic) |
| FormationBonusSystem orchestration | formation-bonus.md CR-FB-6 + grid-battle.md CR-16 | **Formation Bonus ADR** (post-MVP) |
| Rally orchestration | grid-battle.md CR-15 | **Rally ADR** (post-MVP) |
| USE_SKILL counter + AOE_ALL | grid-battle.md AC-GB-15 + EC-GB-02 | **Skill ADR** (post-MVP) |

When each future ADR ships, this ADR is **amended** (additive — new signal subscriptions, new helper methods) or **superseded by** a successor ADR (for fundamental architecture changes like AI substate machine becoming the dominant control flow).

MVP gameplay surface: **MOVE + ATTACK only**, **player-vs-script-bot** (greedy melee per chapter-prototype pattern — NOT real AI), **5-turn limit**, **single chapter (장판파)**, **melee adjacency** (sole exception: 황충 range-2 ranged attack).

### 1. Module Form — Battle-scoped Node

```gdscript
class_name GridBattleController extends Node
```

**4th invocation** of the battle-scoped Node pattern after ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner + ADR-0013 BattleCamera. Lives at `BattleScene/GridBattleController`. Freed with BattleScene exit. Not autoloaded.

**Class name `GridBattleController`** — mirrors `GridBattleStub` precedent from chapter-prototype + `grid-battle` registry partner-name + GDD §612 convention. Verified no Godot 4.6 ClassDB collision (Battle / Grid / Controller are not built-in).

### 2. State Model

**FSM** (2 states for MVP — full `grid-battle.md` GDD has more substates; deferred):

```gdscript
enum BattleState {
    OBSERVATION,    # No unit selected; click selects own unit
    UNIT_SELECTED,  # A unit is selected; click moves / attacks / deselects
}
var _state: BattleState = BattleState.OBSERVATION
var _selected_unit_id: int = -1
```

**Per-turn action tracking** (mirrors chapter-prototype):

```gdscript
var _acted_this_turn: Dictionary[int, bool] = {}  # unit_id → already-acted flag
```

A player unit consumes its turn-action by either MOVE or ATTACK (chapter-prototype rule). When all alive player units have acted, auto-end-turn (or manual end-turn button). TurnOrderRunner integration (R-13 below) supersedes this in cleaner future ADR; MVP keeps the simple Dictionary-based tracking.

**Hidden fate-condition counters** (chapter-prototype's 5-condition pattern):

```gdscript
var _fate_tank_unit_id: int = -1     # populated at setup() — the 장비-tagged unit
var _fate_assassin_unit_id: int = -1 # populated at setup() — the 조운-tagged unit
var _fate_boss_unit_id: int = -1     # populated at setup() — the boss-tagged enemy
var _fate_rear_attacks: int = 0
var _fate_formation_turns: int = 0
var _fate_assassin_kills: int = 0
var _fate_boss_killed: bool = false
# tank_alive_hp_pct computed on-demand from HPStatusController query
```

These are **never displayed in HUD**; surfaced only via `hidden_fate_condition_progressed(condition_id, value)` signal that Destiny Branch ADR (sprint-6) consumes.

### 3. DI Setup

```gdscript
var _units: Dictionary[int, BattleUnit] = {}  # unit_id → unit Resource
var _map_grid: MapGrid = null
var _camera: BattleCamera = null
var _hero_db: HeroDatabase = null
var _turn_runner: TurnOrderRunner = null
var _hp_controller: HPStatusController = null
# NOTE: DamageCalc is NOT a DI dependency — its methods are `static func` (per
# src/feature/damage_calc/damage_calc.gd line 69 `static func resolve(...)`).
# Call as `DamageCalc.resolve(...)` directly. The "stateless" quality means no
# mutable fields; methods are declared `static`, NOT instance methods.
# Tests that need to mock DamageCalc behavior use the existing damage-calc test
# fixture pattern (see tests/unit/feature/damage_calc/) — not DI through this controller.
var _terrain_effect: TerrainEffect = null
var _unit_role: UnitRole = null
var _max_turns: int = 0  # derived from BalanceConstants at _ready

func setup(
    units: Array[BattleUnit],
    map_grid: MapGrid,
    camera: BattleCamera,
    hero_db: HeroDatabase,
    turn_runner: TurnOrderRunner,
    hp_controller: HPStatusController,
    terrain_effect: TerrainEffect,
    unit_role: UnitRole,
) -> void:
    # 8 DI parameters (DamageCalc dropped — see _damage_calc comment above)
    for u in units:
        _units[u.unit_id] = u
    _map_grid = map_grid
    _camera = camera
    _hero_db = hero_db
    _turn_runner = turn_runner
    _hp_controller = hp_controller
    _terrain_effect = terrain_effect
    _unit_role = unit_role
    # Tag-based fate-counter unit detection (per chapter-prototype pattern)
    _fate_tank_unit_id = _find_unit_by_tag("tank")
    _fate_assassin_unit_id = _find_unit_by_tag("assassin")
    _fate_boss_unit_id = _find_unit_by_tag("boss")

func _ready() -> void:
    assert(_units.size() > 0, "GridBattleController.setup() must be called before adding to scene tree")
    assert(_map_grid != null and _camera != null and _hero_db != null and _turn_runner != null \
           and _hp_controller != null and _terrain_effect != null and _unit_role != null, \
           "All 6 backends + BattleCamera must be DI'd before _ready()")
    _max_turns = int(BalanceConstants.get_const(&"MAX_TURNS_PER_BATTLE"))
    # CRITICAL: CONNECT_DEFERRED on unit_died is NOT merely advisory — it is
    # load-bearing reentrance prevention. Without it, _on_unit_died could fire
    # synchronously inside HPStatusController.apply_damage() called from
    # _resolve_attack(), producing reentrant _check_battle_end() invocation
    # mid-resolve. Future maintainers MUST NOT remove the DEFERRED flag here.
    # (Per godot-specialist 2026-05-02 ADR-0014 review revision #1.)
    GameBus.input_action_fired.connect(_on_input_action_fired, Object.CONNECT_DEFERRED)
    _hp_controller.unit_died.connect(_on_unit_died, Object.CONNECT_DEFERRED)
    _turn_runner.unit_turn_started.connect(_on_unit_turn_started, Object.CONNECT_DEFERRED)
    _turn_runner.round_started.connect(_on_round_started, Object.CONNECT_DEFERRED)

func _exit_tree() -> void:
    # MANDATORY autoload-disconnect cleanup (per ADR-0013 R-6 + camera_missing_exit_tree_disconnect
    # forbidden_pattern precedent extended to this ADR).
    if GameBus.input_action_fired.is_connected(_on_input_action_fired):
        GameBus.input_action_fired.disconnect(_on_input_action_fired)
    # NOTE: HPStatusController + TurnOrderRunner are battle-scoped Nodes (NOT autoloads) —
    # if they're freed before us we'd auto-disconnect via SOURCE-freed pathway. But to be safe
    # under any free-order, explicitly disconnect:
    if _hp_controller != null and _hp_controller.unit_died.is_connected(_on_unit_died):
        _hp_controller.unit_died.disconnect(_on_unit_died)
    if _turn_runner != null:
        if _turn_runner.unit_turn_started.is_connected(_on_unit_turn_started):
            _turn_runner.unit_turn_started.disconnect(_on_unit_turn_started)
        if _turn_runner.round_started.is_connected(_on_round_started):
            _turn_runner.round_started.disconnect(_on_round_started)
```

### 4. Click hit-test routing

```gdscript
# Subscriber for unit_select / move_target_select / attack_target_select / etc.
# Chapter-prototype pattern: ctx.coord may be Vector2i.ZERO if InputRouter
# couldn't resolve from the raw event; we re-resolve via BattleCamera.
func _on_input_action_fired(action: StringName, ctx: InputContext) -> void:
    if not _is_grid_action(action): return  # filter; camera/menu/meta actions ignored
    var click_coord: Vector2i = ctx.coord
    if click_coord == Vector2i.ZERO and _camera != null:
        # Re-resolve via Camera if InputRouter passed a sentinel
        click_coord = _camera.screen_to_grid(get_viewport().get_mouse_position())
    if click_coord == Vector2i(-1, -1): return  # off-grid
    _handle_grid_click(action, click_coord, ctx.unit_id)
```

`_handle_grid_click` dispatches via 2-state FSM match (observation → unit-select check; unit_selected → attack/move/deselect check).

### 5. Combat Resolution (inline formation/angle math; MVP scope)

```gdscript
func _resolve_attack(attacker: BattleUnit, defender: BattleUnit) -> int:
    var formation_count: int = _count_adjacent_allies(attacker)
    var formation_mult: float = 1.0 + 0.05 * float(formation_count)  # cap at +0.20 by max 4 adj
    formation_mult = minf(formation_mult, 1.20)

    var angle: String = _attack_angle(attacker, defender)  # "front" / "side" / "rear"
    var angle_mult: float = 1.0
    match angle:
        "side": angle_mult = 1.25
        "rear":
            angle_mult = 1.50
            if attacker.passive == "rear_specialist":  # 황충
                angle_mult = 1.75

    var aura_mult: float = 1.0
    if _has_adjacent_command_aura(attacker):  # 유비 adjacent
        aura_mult = 1.15

    # Defer to DamageCalc for the actual base damage (sole-caller contract).
    # DamageCalc.resolve() is `static func` — call directly, NOT via instance reference.
    var resolve_modifiers: ResolveModifiers = ResolveModifiers.new()
    resolve_modifiers.formation_atk_bonus = formation_mult - 1.0  # additive contribution
    resolve_modifiers.angle_mult = angle_mult
    resolve_modifiers.aura_mult = aura_mult
    var resolved_damage: int = DamageCalc.resolve(attacker, defender, resolve_modifiers)

    # Apply via HPStatusController (sole writer of unit HP per ADR-0010 ownership)
    _hp_controller.apply_damage(defender.unit_id, resolved_damage)

    # Fate counter
    if angle == "rear":
        _fate_rear_attacks += 1
        hidden_fate_condition_progressed.emit(&"rear_attacks", _fate_rear_attacks)

    damage_applied.emit(attacker.unit_id, defender.unit_id, resolved_damage)
    return resolved_damage
```

**Note**: `ResolveModifiers` is a typed Resource owned by `damage-calc.md` rev 2.9.3. The `formation_atk_bonus + angle_mult + aura_mult` fields are **MVP additions** to ResolveModifiers — small same-patch obligation in the camera+grid-battle epic stories.

**Future migration** (when Formation Bonus ADR ships): `formation_atk_bonus` is replaced by reading the snapshot from `set_formation_bonuses()` per CR-16 — no GridBattleController API change, only internal compute path.

### 6. Per-turn action consumption (TurnOrderRunner integration — simplified)

```gdscript
func _consume_unit_action(unit_id: int) -> void:
    _acted_this_turn[unit_id] = true
    _turn_runner.spend_action_token(unit_id)  # honor Contract 4
    _deselect()
    if not _any_player_unit_can_act():
        end_player_turn()
```

Full `grid-battle.md` Contract 4 also requires `spend_move_token()` separation; **MVP simplifies to single action token** (matches chapter-prototype's "one action per turn" rule). When the AI ADR or Token ADR refines this, GridBattleController's API stays stable — only the internal token-spend pattern changes.

### 7. Hidden fate condition tracking

```gdscript
# Called from _on_round_started to update formation_turns counter
func _on_round_started(round_num: int) -> void:
    var formation_active: bool = false
    for u in _units.values():
        if u.side != 0 or _hp_controller.is_dead(u.unit_id): continue
        if _count_adjacent_allies(u) >= 1:
            formation_active = true; break
    if formation_active:
        _fate_formation_turns += 1
        hidden_fate_condition_progressed.emit(&"formation_turns", _fate_formation_turns)
    if round_num > _max_turns:
        _emit_battle_outcome("TURN_LIMIT_REACHED")

func _on_unit_died(unit_id: int) -> void:
    if unit_id == _fate_boss_unit_id:
        _fate_boss_killed = true
        hidden_fate_condition_progressed.emit(&"boss_killed", 1)
    if _last_attacker_id == _fate_assassin_unit_id and _is_enemy(unit_id):
        _fate_assassin_kills += 1
        hidden_fate_condition_progressed.emit(&"assassin_kills", _fate_assassin_kills)
    _check_battle_end()
```

### 8. GameBus signal emission (MVP set ratified by ADR-0015 Battle HUD Accepted 2026-05-03 via /architecture-review delta #10)

This ADR pre-commits 4 Battle-domain signals to ADR-0001 §7 Signal Contract Schema (additive amendment per ADR-0001 §445 future-extension provision):

```gdscript
signal unit_selected_changed(unit_id: int, was_selected: int)  # was_selected = -1 for deselect
signal unit_moved(unit_id: int, from: Vector2i, to: Vector2i)
signal damage_applied(attacker_id: int, defender_id: int, damage: int)
signal battle_outcome_resolved(outcome: StringName, fate_data: Dictionary)
signal hidden_fate_condition_progressed(condition_id: StringName, value: int)
```

`hidden_fate_condition_progressed` is consumed ONLY by Destiny Branch ADR (sprint-6); Battle HUD does NOT subscribe (preserves the "hidden" semantic).

### 9. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│ BattleScene                                                          │
│                                                                      │
│  ┌──────────────┐   ┌──────────────┐                                 │
│  │   MapGrid    │   │ BattleCamera │ (ADR-0013)                      │
│  └──────┬───────┘   └──────┬───────┘                                 │
│         │ DI                │ DI                                     │
│         └────────┬──────────┘                                        │
│                  ▼                                                    │
│         ┌───────────────────────┐  ┌──────────────────┐              │
│         │ GridBattleController  │◄─┤ HPStatusController│ (ADR-0010)  │
│         │  (this ADR — Node)    │  └──────────────────┘              │
│         │                       │  ┌──────────────────┐              │
│         │  ─ unit_list (Dict)   │◄─┤ TurnOrderRunner  │ (ADR-0011)  │
│         │  ─ FSM 2-state        │  └──────────────────┘              │
│         │  ─ fate counters (5)  │  ┌──────────────────┐              │
│         │  ─ formation/angle    │  │   DamageCalc     │ (ADR-0012;   │
│         │     math (inline MVP) │  │ static — called  │  NOT DI'd —  │
│         │                       │  │  via DamageCalc. │  static call)│
│         │                       │  │  resolve(...) )  │              │
│         │                       │  └──────────────────┘              │
│         │  ─ click→action       │  ┌──────────────────┐              │
│         │     dispatch via      │──►   HeroDatabase   │ (ADR-0007)  │
│         │     BattleCamera      │  └──────────────────┘              │
│         └───────┬───────────────┘  ┌──────────────────┐              │
│                 │                  │  TerrainEffect   │ (ADR-0008)  │
│                 │                  └──────────────────┘              │
│                 │                  ┌──────────────────┐              │
│                 │                  │     UnitRole     │ (ADR-0009)  │
│                 │                  └──────────────────┘              │
└─────────────────┼──────────────────────────────────────────────────────┘
                  │ subscribes (CONNECT_DEFERRED)
                  ▼
            GameBus.input_action_fired
                  ▲ emits
            ┌─────┴─────┐
            │InputRouter│ (ADR-0005)
            └───────────┘

GridBattleController emits to GameBus (additive to ADR-0001 §7):
  unit_selected_changed → Battle HUD (sprint-5)
  unit_moved             → Battle HUD
  damage_applied         → Battle HUD + (post-MVP) damage-floats VFX
  battle_outcome_resolved → Scenario Progression (sprint-6) + Destiny Branch (sprint-6)
  hidden_fate_condition_progressed → Destiny Branch ONLY (HUD does NOT subscribe)
```

### 10. Key Interfaces

```gdscript
# Public API surface (GridBattleController class)
class_name GridBattleController extends Node

# DI setup (BattleScene calls before _ready())
func setup(units: Array[BattleUnit], map_grid: MapGrid, camera: BattleCamera,
           hero_db: HeroDatabase, turn_runner: TurnOrderRunner,
           hp_controller: HPStatusController, terrain_effect: TerrainEffect,
           unit_role: UnitRole) -> void
# DamageCalc is NOT a parameter — static-call site uses DamageCalc.resolve(...)

# Cross-system contract callbacks (input-handling §9 partner)
func is_tile_in_move_range(tile: Vector2i, unit_id: int) -> bool
func is_tile_in_attack_range(tile: Vector2i, unit_id: int) -> bool

# Player-input layer (called by InputRouter via GameBus filter — but also direct callable for tests)
func handle_grid_click(action: StringName, coord: Vector2i, unit_id: int) -> void

# Read-only state queries (Battle HUD consumes)
func get_selected_unit_id() -> int  # -1 if none selected
func get_battle_state_snapshot() -> Dictionary  # for AI consumer (Battle AI ADR; opaque shape)

# Turn flow
func end_player_turn() -> void  # ends player turn early; auto-called when all alive units acted

# Internal — not for external call
func _on_input_action_fired(action: StringName, ctx: InputContext) -> void
func _on_unit_died(unit_id: int) -> void
func _on_unit_turn_started(unit_id: int) -> void
func _on_round_started(round_num: int) -> void
func _resolve_attack(attacker: BattleUnit, defender: BattleUnit) -> int
func _count_adjacent_allies(unit: BattleUnit) -> int
func _attack_angle(attacker: BattleUnit, defender: BattleUnit) -> String
```

## Alternatives Considered

### Alternative 1: Stateless-static utility class

- **Description**: `class_name GridBattleController extends RefCounted` with all-static methods; per-battle state held externally in BattleScene.
- **Pros**: Mirrors 5-precedent stateless pattern (ADR-0006/0007/0008/0009/0012). No instance lifecycle.
- **Cons**: (a) Cannot subscribe to GameBus signals (RefCounted has no node lifecycle). (b) BattleScene would need to hold all 11+ state fields and manage them — defeats the purpose of "controller". (c) Same justification as ADR-0005 InputRouter Alternative 4 + ADR-0013 BattleCamera Alternative 1 rejection.
- **Rejection Reason**: GridBattleController is a state-holder + signal-listener, not a calculator. The stateless pattern is for systems CALLED, not systems that LISTEN.

### Alternative 2: Autoload Controller

- **Description**: Mount as `/root/GridBattleController` autoload Node like InputRouter (ADR-0005).
- **Pros**: Single reference; no per-battle setup ceremony.
- **Cons**: (a) Battle state is fundamentally battle-scoped (overworld scene + main menu have no Controller consumer). (b) Autoload + DI = ugly: `controller.setup(...)` called per-battle on a "global" object inverts the autoload mental model. (c) State leak risk if reset is forgotten between battles. (d) Mirrors HPStatusController + TurnOrderRunner + BattleCamera battle-scoped Node precedent — autoload here would break the pattern boundary.
- **Rejection Reason**: Battle-scoped lifecycle fits better. 4th invocation of established pattern.

### Alternative 3: Full GDD-scope ADR (no MVP scoping)

- **Description**: Author the ADR covering all 1259 lines of grid-battle.md in one go: AI substate machine + FormationBonusSystem orchestration + Rally + USE_SKILL counter + AOE_ALL + closed-signal-set + AC-GB-01..25.
- **Pros**: One ADR for the whole system. No future amendments needed for those 4 deferred concerns.
- **Cons**: (a) 800+ LoC ADR; sprint-4 S4-03 budget is 0.75d ≈ 6h; full scope is 4-6h MORE than MVP scope. (b) Premature commitment — Battle AI ADR (sprint-7+) may discover constraints requiring substate-machine restructure. (c) "Big design up front" anti-pattern; the MVP path lets us validate the simple shape first. (d) Chapter-prototype already proved the MVP shape; production version of THAT is the priority, not a paper-architecture exercise on AI integration.
- **Rejection Reason**: MVP scope is the right scope for sprint-4. Defer the 4 concerns to their own ADRs as gameplay needs them.

### Alternative 4: Split into two ADRs — Controller + Combat Resolver

- **Description**: ADR-0014 owns FSM + click routing + signal subscription. ADR-0015 owns combat resolution (formation/angle/aura math + DamageCalc/HPStatusController integration).
- **Pros**: Each ADR is smaller; combat math is more obviously the "math system" concern.
- **Cons**: (a) Combat resolution is tightly coupled to controller state (which unit is selected, who's adjacent, etc.) — splitting creates coupling without isolation benefit. (b) DamageCalc already owns the *base* damage formula; the controller-side multipliers (formation/angle/aura) are POSITIONAL queries that need controller state. (c) Two ADRs = more cross-doc bookkeeping for marginal clarity gain.
- **Rejection Reason**: Combat math fits naturally INSIDE the controller; splitting is over-decomposition. Future Formation Bonus ADR will extract the formation math piece — at THAT point a 2-ADR split becomes natural; today, single-ADR is right.

## Consequences

### Positive
- Establishes GridBattleController as the **central battle orchestrator** with clean DI of 7 backends — single-source integration site.
- 4th invocation of battle-scoped Node pattern cements the pattern boundary precedent (ADR-0010 + ADR-0011 + ADR-0013 + this ADR).
- Combat math (formation/angle/aura) lives in ONE place — no duplication risk.
- Hidden fate-condition tracking surfaces via dedicated signal channel (Destiny Branch consumer) without polluting Battle HUD signal namespace.
- Explicit MVP scope statement protects against premature commitment to AI / Formation Bonus / Rally / USE_SKILL architecture before those gameplay concerns are validated.
- 4 GameBus signal additions are minimal (single domain extension); ADR-0001 §445 future-extension provision absorbs them cleanly.
- LOW engine risk — every API used is stable since Godot 4.0.

### Negative
- Largest single ADR in project so far (~470 LoC); large attention-budget cost for any reader.
- 4 deferred concerns mean 4 future ADR amendments — bookkeeping cost over time. Mitigated by explicit deferral list in §0.
- Combat math living in controller (not DamageCalc) means Formation Bonus ADR amendment will move this code; currently a TD-tier carry.
- DI signature has 9 parameters — `setup()` call in BattleScene will be verbose. Mitigated by typed parameters + clear required order.
- `_acted_this_turn` Dictionary duplicates state TurnOrderRunner already tracks via tokens. Resolved by full Token ADR refactoring later; carries minor redundancy in MVP.

### Risks
- **R-1: GameBus signal namespace explosion** — adding 5 signals from one ADR pushes ADR-0001 §445 cap (50 emits/frame) closer. **Mitigation**: 4 of 5 signals fire on player action only (1-3 events per turn); hidden_fate_condition_progressed fires at most ~5x per battle. Total emit budget consumption < 10/frame even at peak — well under cap.
- **R-2: Combat math drift between this ADR and Formation Bonus ADR** — when Formation Bonus ADR ships, formation calc moves to FormationBonusSystem; if migration is sloppy, two implementations could coexist. **Mitigation**: forbidden_pattern `grid_battle_controller_external_combat_math` lint will fire when FormationBonusSystem code lands AND this controller still has inline math; forces clean cutover.
- **R-3: DI parameter-order regression** — 8 typed parameters (post-godot-specialist revision #2 — DamageCalc dropped from DI); reordering on amendment could silently rebind wrong arg → wrong field if types accidentally match. **Mitigation**: each parameter has distinct typed Resource type (BattleUnit / MapGrid / BattleCamera / HeroDatabase / TurnOrderRunner / HPStatusController / TerrainEffect / UnitRole — all 8 distinct class names); type system catches reorder errors at parse time.
- **R-4: `_exit_tree()` disconnect leak parity with ADR-0013** — same Godot 4.x SOURCE-outlives-TARGET pattern; this ADR has 4 separate signal subscriptions to disconnect (vs. ADR-0013's 1). Mitigated by `_exit_tree()` body explicitly handling all 4 (see §3 code).
- **R-5: TurnOrderRunner Contract 4 token API simplification** — MVP collapses move + action tokens to single "action token" check. When full Contract 4 lands (post-MVP), this ADR amendment must restore the move/action split. **Mitigation**: token query is encapsulated in `_consume_unit_action` helper — single point of change.
- **R-6: chapter-prototype refactoring temptation** — chapter-prototype's `battle_v2.gd` (~720 LoC) is structurally similar to what this ADR specifies; a programmer might be tempted to copy-paste rather than rewrite. **Mitigation**: prototype skill rules forbid imports between `prototypes/` and `src/`; CI check (existing project pattern) enforces; ADR Migration Plan §13 explicitly states rewrite-from-scratch.
- **R-7: Cross-ADR `_exit_tree()` audit follow-up** — ADR-0013 R-6 noted ADR-0010 + ADR-0011 may also lack `_exit_tree()` cleanup; this ADR is the **3rd** battle-scoped Node subscribing to autoloads. **RESOLVED 2026-05-03 via grid-battle-controller story-009 audit**: HPStatusController + BattleCamera + GridBattleController already had `_exit_tree()` autoload-disconnect (false-alarm portion); TurnOrderRunner was missing and got retrofitted in same patch. TD-057 closed; pattern stable at 4 invocations. See `docs/tech-debt-register.md` TD-057 for full audit findings table + verification report.
- **R-8: `CONNECT_DEFERRED` on `unit_died` is load-bearing** (per godot-specialist 2026-05-02 ADR-0014 review revision #1) — without the DEFERRED flag, `_on_unit_died` would fire synchronously inside `HPStatusController.apply_damage()` called from `_resolve_attack()`, producing reentrant `_check_battle_end()` invocation mid-resolve. The DEFERRED flag queues the callback to end-of-frame, breaking the reentrance chain. **Mitigation**: explicit comment in `_ready()` body marking CONNECT_DEFERRED as load-bearing (NOT removable for "perceived perf"); regression test asserts behavior — repeatedly trigger lethal damage and assert no reentrance crash + correct event ordering. Future maintainers MUST NOT remove the DEFERRED flag without superseding ADR amendment.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| `grid-battle.md` | CR-1..CR-7 simple cases (no AI / FormationBonusSystem / Rally / USE_SKILL / AOE_ALL); AC-GB-01..15 for MVP-relevant subset | §Decision §0 explicit MVP scope statement; §Decision §2-§8 implement the simple subset; deferred concerns documented per-row in §0 |
| `grid-battle.md` | §612 Input Handling partnership: `is_tile_in_move_range(tile)` + `is_tile_in_attack_range(tile, unit)` callbacks | §10 Key Interfaces public API; §Decision §4 click routing |
| `grid-battle.md` | §612 Turn Order partnership: Honor Contract 4 (check has_move_token / has_action_token; call spend_*_token after) | §6 simplified to single action token in MVP; full Contract 4 deferred to amendment |
| `damage-calc.md` | line 260 sole-caller contract: only Grid Battle calls DamageCalc.resolve() | §5 controller is the sole caller; lint enforces no other class invokes |
| `hp-status.md` | AC-GB-10b DEFEND_STANCE damage owned by hp-status (not Grid Battle) | §5 controller computes resolved_damage via DamageCalc; HPStatusController.apply_damage() applies the DEFEND_STANCE reduction internally |
| `turn-order.md` | Contract 4 token API: spend_action_token + initiative queue advance | §6 simplified consumption pattern; full token model deferred |
| `hero-database.md` | DI'd at battle init for roster lookup; BattleUnit Resource carries hero_id reference | §3 DI; controller does not duplicate HeroData |
| `map-grid.md` | get_map_dimensions + tile data queries via DI | §3 DI; consumed for is_tile_in_move_range bounds |
| `terrain-effect.md` | Per-tile modifier query (defense bonus, evasion bonus) | §5 ResolveModifiers populated from terrain query at attack-resolve time |
| `unit-role.md` | Class-based derived stats (effective_atk / effective_def / effective_hp / effective_initiative / move_range / class_cost_table) | §3 DI; consumed for combat math + range computation |
| `input-handling.md` | §9 Bidirectional Contract: provide is_tile_in_move_range + is_tile_in_attack_range; consume input_action_fired filtered for grid-domain | §10 Key Interfaces (callbacks); §4 click routing (input subscription) |
| `formation-bonus.md` | **MVP uses inline subset only**; full FormationBonusSystem orchestration deferred | §0 deferral row #2; §5 inline +5%/adj-ally cap +20% (chapter-prototype pattern) |
| `destiny-branch.md` (NOT YET WRITTEN — sprint-6) | Provide hidden_fate_condition_progressed signal channel for chapter-advancement judging | §8 signal pre-committed; Destiny Branch ADR consumes |

## Implementation Notes (story-001 reads fresh from shipped code)

The §3 + §5 GDScript snippets are **architectural sketches** — story-001 must read fresh signatures from the shipped backend code. Verified at ADR-authoring time (2026-05-02):

- **`HPStatusController.apply_damage`** has 4 params: `(unit_id: int, resolved_damage: int, attack_type: int, source_flags: Array)` — NOT the 2-param shape sketched in §5. Story-005 must pass `attack_type` (likely an enum int from damage-calc) + `source_flags` (Array of StringName for passive flags). The architectural decision (sole writer of HP via HPStatusController) stands; only the call-site arity differs.
- **`HPStatusController.is_alive(unit_id)`** is the canonical query (line 219 of `src/core/hp_status_controller.gd`). The ADR's sketches use `is_dead(...)` — invert to `not _hp_controller.is_alive(...)` at implementation time.
- **`HPStatusController._exit_tree()` ALREADY EXISTS** (line 45 of shipped code) with explicit `GameBus.unit_turn_started.disconnect(...)`. **Good news for R-7 + TD-057**: ADR-0010 retrofit is partially false alarm — already has the disconnect pattern. **Story-009 audit outcome (2026-05-03)**: HPStatusController + BattleCamera + GridBattleController all clean (3 of 4 systems false-alarm); TurnOrderRunner was MISSING `_exit_tree` despite the `initialize_battle` line 188 `GameBus.unit_died.connect(...)` subscription — retrofitted in same patch as story-009 (Path B per story AC-3). TD-057 RESOLVED. Pattern now stable at **4 invocations** (HPStatusController + BattleCamera + GridBattleController + TurnOrderRunner).
- **`apply_death_consequences(unit_id)`** per grid-battle.md GDD line 198: Grid Battle invokes EXPLICITLY before victory check (DEMORALIZED propagation owned by HPStatusController). MVP scope **carries this** — story-005 attack flow must call it after lethal damage. ADR §5 sketch does not show it for brevity; story-005 ACs will require it.
- **Signal routing — GameBus autoload, NOT instance signals** (added 2026-05-02 at story-001 implementation): §3 architectural sketch shows `_hp_controller.unit_died.connect(...)`, `_turn_runner.unit_turn_started.connect(...)`, `_turn_runner.round_started.connect(...)` as INSTANCE signal subscriptions on the DI'd backends. **Production-shipped HPStatusController + TurnOrderRunner emit these via the GameBus autoload, NOT as instance signals** — verified at story-001 against `src/core/game_bus.gd` (lines 30/31/36 declare the signals on GameBus) + `src/core/hp_status_controller.gd:113` (`GameBus.unit_died.emit(unit_id)`) + `src/core/turn_order_runner.gd:486+509` (`GameBus.round_started.emit(...)` + `GameBus.unit_turn_started.emit(...)`). The shipped controller therefore subscribes to `GameBus.unit_died` / `GameBus.unit_turn_started` / `GameBus.round_started` (uniform autoload subscription pattern; mirrors HPStatusController's own pattern of subscribing to GameBus.unit_turn_started). `_exit_tree()` correspondingly disconnects from GameBus, not from instance signals — all 4 disconnects unconditional (autoload always alive). The architectural decisions (CONNECT_DEFERRED reentrance prevention, DI of backend deps for stateful queries, `_exit_tree()` cleanup discipline) all stand; only the signal SOURCE differs from the §3 sketch.
- **BattleUnit class location** (added 2026-05-02 at story-001 implementation): `class_name BattleUnit` already exists at `src/core/battle_unit.gd` (ratified by ADR-0011 §Decision §Public mutator API + §Migration Plan §3 — turn-order epic story-002). Story-001 uses the existing 4-field BattleUnit (unit_id / hero_id / unit_class / is_player_controlled) for typed-Array binding. Story-002's "BattleUnit Resource (~10 fields)" requirement either (a) extends src/core/battle_unit.gd additively (subject to its "MUST NOT add fields without Battle Preparation ADR amendment" boundary), OR (b) introduces a sibling class (e.g., `GridBattleUnit`) at `src/feature/grid_battle/`, OR (c) amends the existing class via a Battle Preparation ADR. Decision deferred to story-002 author.
- **DamageCalc-style DI cleanup candidate**: HeroDatabase + UnitRole + TerrainEffect are all-static `@abstract` (or all-static concrete for TerrainEffect) RefCounted utility classes with no instance state. By the same godot-specialist 2026-05-02 ADR-0014 review revision #2 logic that dropped DamageCalc from DI, these three could also be dropped from `setup()` and consumed via direct static-method calls (`HeroDatabase.get_hero(...)`, `UnitRole.get_class_cost_table(...)`, `TerrainEffect.get_modifiers(...)`). Deferred — story-001 honors the current 8-param DI signature; future ADR-0014 amendment may simplify to 5-param DI (units + map_grid + camera + turn_runner + hp_controller).
- **`apply_death_consequences` does NOT exist on shipped HPStatusController** (added 2026-05-03 at story-005 implementation): §5 step 9 sketches `_hp_controller.apply_death_consequences(defender.unit_id)` as an explicit Grid-Battle-driven invocation. Verified at story-005 against `src/core/hp_status_controller.gd` — no such method. DEMORALIZED propagation is INTERNAL to `HPStatusController.apply_damage` via `_propagate_demoralized_radius` (private method called inside the apply_damage flow). Story-005 does NOT call externally; the design intent (DEMORALIZED propagation before victory check) is preserved by DamageCalc → apply_damage → internal propagation. If a future ADR-0014 amendment requires explicit Grid-Battle ordering of DEMORALIZED propagation (vs. implicit-via-apply_damage), an `apply_death_consequences` public method on HPStatusController would need to ship first.
- **`ResolveModifiers.formation_atk_bonus` already exists with documented range [0.0, 0.05]** (added 2026-05-03 at story-005 implementation): §5 step 6 sketches `formation_atk_bonus = formation_mult - 1.0` (range [0.0, 0.20] under chapter-prototype shape with cap 1.20). Existing field's documented range was set by ADR-0012 + Formation Bonus F-FB-3 upstream-cap convention. Story-005 passes the wider range; documentation comment updated to "[0.0, 0.20] under ADR-0014 §5 controller-MVP usage". DamageCalc's P_MULT_COMBINED_CAP (1.31) provides the actual safety bound — wider formation_atk_bonus is mathematically safe. Future Formation Bonus ADR may either tighten the range (forcing controller to clamp to 0.05 + post-multiply the rest) or expand it formally.
- **`ResolveModifiers.angle_mult` + `aura_mult` are NOT consumed by DamageCalc** (added 2026-05-03 at story-005 implementation): §5 step 6 stores them on ResolveModifiers, but DamageCalc's P_mult formula consumes only `formation_atk_bonus` + `rally_bonus`. Story-005 ships angle_mult + aura_mult as @export fields on ResolveModifiers for forward-compat documentation, but applies them as CONTROLLER-side post-multipliers (after DamageCalc.resolve returns). Future Formation Bonus ADR may migrate consumption into DamageCalc via a new P_mult stage.
- **`BattleUnit` extended with `raw_atk` + `raw_def` @export fields** (added 2026-05-03 at story-005 implementation): AttackerContext + DefenderContext require pre-DamageCalc-clamp ATK/DEF stats. Story-005 ships these as 2 new BattleUnit fields (defaults: raw_atk=10, raw_def=5; per-fixture override at battle init). Per ADR-0011 boundary cite + ADR-0014 §3 Battle Preparation contract, additive extension is allowed. Future Battle Preparation ADR may move these into a separate stat-derivation Resource (HeroDatabase + UnitRole derived stats); today they live on BattleUnit as the simplest fixture-author surface.
- **`TurnOrderRunner.spend_action_token` does NOT exist on shipped TurnOrderRunner** (added 2026-05-03 at story-006 implementation): §6 sketch + grid-battle.md Contract 4 + story-006 AC-2 reference `_turn_runner.spend_action_token(unit_id)` as the controller-side action consumption hook. Verified at story-006 against `src/core/turn_order_runner.gd` — no such method. The shipped public API is `declare_action(unit_id: int, action: int, target: ActionTarget) -> ActionResult` per ADR-0011 §Key Interfaces, with action ∈ TurnOrderRunner.ActionType {MOVE=0, ATTACK=1, USE_SKILL=2, DEFEND=3, WAIT=4}. Story-006 maps the MVP single-token simplification to `declare_action(unit_id, ActionType.ATTACK, null)` — ATTACK token represents "this unit acted this turn" regardless of whether the underlying action was MOVE or ATTACK. The ADR-0014 §6 §Decision (single-token MVP simplification, encapsulated at one call site) is preserved; only the call signature differs from the sketch. Future Token ADR (post-MVP move/action token split) only changes this single call site. Story-006 anticipated this drift: AC-2 Implementation Note #2 explicitly says "If shipped name differs (e.g., `spend_token` or `consume_action`), use shipped name; story comment should note the discrepancy."
- **No `_turn_runner.end_player_turn()` method** (added 2026-05-03 at story-006 implementation): §6 sketch + story-006 AC-5 reference `_turn_runner.end_player_turn()` as the round-handoff trigger. Verified at story-006 against shipped TurnOrderRunner — no such method. The runner advances rounds via the internal queue + `_begin_round` → `GameBus.round_started.emit(...)` cycle (per `src/core/turn_order_runner.gd:486`); there is no caller-driven "end this player turn" handle. Story-006 ships `GridBattleController.end_player_turn()` as **controller-side bookkeeping ONLY**: clears `_acted_this_turn` + deselects current unit. Round advance remains signal-driven (GameBus.round_started → `_on_round_started` handler — story-007 fills body). AC-5's "or equivalent" hedge anticipated this. Full Battle Scene wiring (sprint-6+) will replace this with the synchronous Callable injection per ADR-0011 §Decision Contract 5 (`controller.call(unit_id, queue_snapshot)` form) — at that point the controller's `end_player_turn` will likely become unnecessary or refocus to "early-end via player skip-turn".

These do NOT alter the architectural decisions in this ADR — they refine the MVP-implementation bookkeeping that story authoring will codify.

## Performance Implications

- **CPU**: Per-frame controller update = 0 (no `_process` body in MVP). Per-event (signal handler) cost: `_on_input_action_fired` < 0.05ms (FSM dispatch + 1-2 backend queries); `_resolve_attack` < 0.5ms (formation count + angle calc + DamageCalc.compute + HPStatusController.apply_damage chain). Per-round overhead `_on_round_started` < 0.1ms (formation_turns counter update + TURN_LIMIT_REACHED check). Total budget consumption ≈ 0.5ms peak per battle action; well under 16.6ms frame budget.
- **Memory**: 11 instance fields + Dictionary[int, BattleUnit] (e.g., 8 units × ~200 bytes = ~1.6 KB) + 7 backend pointers. Total controller state < 5 KB per battle. Single instance per battle. Negligible against 512 MB mobile ceiling.
- **Load Time**: `setup()` is O(N) on unit count (fate-counter unit detection); for N=8 units < 0.01ms. `_ready()` runs 4 `connect()` calls + 1 BalanceConstants read; < 0.5ms total.
- **Network**: N/A (singleplayer).
- **Cross-platform**: Pure orchestration logic — no platform-specific APIs. Deterministic by construction (all RNG owned by DamageCalc per ADR-0012).

## Migration Plan

From `[no current implementation — chapter-prototype's battle_v2.gd is the throwaway design brief]`:

1. Author grid-battle-controller epic via `/create-epics grid-battle-controller` (sprint-4 S4-04 next task)
2. `/create-stories grid-battle-controller` produces ~8-12 stories:
   - story-001: GridBattleController class skeleton + DI `setup()` pattern (8 typed params; DamageCalc NOT in DI per godot-specialist revision #2 — it's static-call) + 6-backend assertion + `_exit_tree()` cleanup with explicit CONNECT_DEFERRED-load-bearing comment (per ADR-0013 R-6 + godot-specialist revision #1)
   - story-002: BattleUnit Resource + unit registry (`Dictionary[int, BattleUnit]`) + `_units` initialization from setup()
   - story-003: FSM 2-state + `_on_input_action_fired` dispatch + 10-grid-action filter
   - story-004: Move action — `is_tile_in_move_range` + `_handle_move` + `unit_moved` signal emission
   - story-005: Attack action — `_resolve_attack` (formation count + angle calc + aura check) + DamageCalc integration + HPStatusController.apply_damage + `damage_applied` signal
   - story-006: Per-turn action consumption + `end_player_turn` + `_acted_this_turn` Dictionary + auto-end-turn-when-all-acted
   - story-007: 5-turn limit + `_on_round_started` + `battle_outcome_resolved` emission
   - story-008: Hidden fate-condition tracking (5 counters) + `hidden_fate_condition_progressed` signal
   - story-009: Cross-ADR audit — verify ADR-0010 + ADR-0011 also have `_exit_tree()` autoload-disconnect; log TD-057 if missing (carries from ADR-0013 R-7 follow-up)
   - story-010 (epic-terminal): perf baseline (per-event < 0.5ms) + 3 forbidden_pattern lints (signal_emission_outside_battle_domain + static_state + external_combat_math) + 6 BalanceConstants additions (MAX_TURNS_PER_BATTLE + 5 fate-condition thresholds — though thresholds belong to Destiny Branch ADR, may shift) + epic-terminal commit
3. Same-patch obligations:
   - 6 new BalanceConstants in `assets/data/balance/balance_entities.json` (`MAX_TURNS_PER_BATTLE` + others TBD per Destiny Branch ADR)
   - ResolveModifiers Resource gains 3 fields: `formation_atk_bonus: float`, `angle_mult: float`, `aura_mult: float` (additive — back-compat per ADR-0012 schema-evolution rules)
   - 1 lint script `tools/ci/lint_grid_battle_controller_no_external_combat_math.sh` greps `src/feature/` (excluding `grid_battle_controller.gd` + `damage_calc.gd`) for formation/angle/aura keyword pattern
4. Production code path: `src/feature/grid_battle/grid_battle_controller.gd` (mirrors `src/feature/camera/battle_camera.gd` Feature-layer location)
5. Test stub: `tests/helpers/grid_battle_controller_stub.gd` for tests that need to mock controller behavior (mirrors existing `tests/helpers/grid_battle_stub.gd` from hp-status epic — but that stub is the SHIM the controller will REPLACE; verify naming non-collision)

## Validation Criteria

This ADR is correct when (validation in grid-battle-controller epic story-010 epic-terminal):

1. **Functional**:
   - DI assertion: instantiating GridBattleController WITHOUT calling setup() before add_child triggers assert in `_ready()`
   - 2-state FSM dispatch: `_handle_grid_click` in OBSERVATION + click on own unit → state UNIT_SELECTED + `unit_selected_changed` emitted; click on selected unit again → state OBSERVATION
   - Combat resolution: 황충 (rear_specialist) attacking from rear → `angle_mult == 1.75`; same attacker from side → 1.25; from front → 1.0
   - Formation bonus: attacker with 2 adjacent allies → `formation_mult == 1.10`; with 4 adj → cap at 1.20
   - Aura: 유비 adjacent to attacker → `aura_mult == 1.15`; not adjacent → 1.0
   - 5-turn limit: round 6 begins → `battle_outcome_resolved("TURN_LIMIT_REACHED", fate_data)` emitted
   - Fate counters: rear attack → `_fate_rear_attacks += 1` + signal emitted; boss kill → `_fate_boss_killed = true` + signal
2. **Signal contract**:
   - All 4 GameBus signal subscriptions use `Object.CONNECT_DEFERRED`
   - `_exit_tree()` body explicitly disconnects all 4 (assert via grep test)
   - GridBattleController emits ONLY 5 declared Battle-domain signals (assert via lint `grep 'GameBus\..*\.emit' src/feature/grid_battle/grid_battle_controller.gd` returns count = 0; signals are defined LOCALLY on the class, not via GameBus)
3. **Performance**:
   - Per-event `_on_input_action_fired` < 0.05ms p99 over 1000 synthetic events
   - Per-attack `_resolve_attack` full chain (controller → DamageCalc → HPStatusController) < 0.5ms p99
   - `setup()` < 0.01ms for 8-unit roster
4. **Engine compatibility**:
   - `Dictionary[int, BattleUnit]` typed Dictionary loads + iterates correctly on Godot 4.6
   - All 9 typed DI parameters bind without runtime type error
   - `_exit_tree()` fires on `queue_free()` AND on scene change

## Related Decisions

- **ADR-0001** (GameBus) — signal contract source-of-truth; CONNECT_DEFERRED mandate
- **ADR-0004** (Map/Grid) — DI dependency
- **ADR-0005** (Input Handling) — §9 Bidirectional Contract partner; provides callbacks
- **ADR-0006** (Balance/Data) — 6 new BalanceConstants entries
- **ADR-0007** (Hero Database) — DI dependency
- **ADR-0008** (Terrain Effect) — DI dependency
- **ADR-0009** (Unit Role) — DI dependency
- **ADR-0010** (HP Status) — DI dependency + sole writer of unit HP
- **ADR-0011** (Turn Order) — DI dependency + Contract 4 token API
- **ADR-0012** (Damage Calc) — DI dependency + sole-caller contract honored
- **ADR-0013** (BattleCamera) — DI dependency + screen_to_grid hit-test partner
- **ADR-0015 Battle HUD** (Accepted 2026-05-03 via /architecture-review delta #10) — primary consumer of 4 of 5 controller-LOCAL signals (5th explicitly NOT subscribed per Pillar 2 lock 3-layer enforcement; ADR-0015 §8 codifies the source-grep lint)
- **Scenario Progression ADR** (NOT YET WRITTEN — sprint-6) — consumer of `battle_outcome_resolved`
- **Destiny Branch ADR** (NOT YET WRITTEN — sprint-6) — sole consumer of `hidden_fate_condition_progressed`
- **Battle AI ADR** (NOT YET WRITTEN — sprint-7+) — supersedes player-only-turns assumption; consumes `get_battle_state_snapshot()` opaque API
- **Formation Bonus ADR** (NOT YET WRITTEN — post-MVP) — supersedes inline formation math; FormationBonusSystem orchestration per CR-FB-6
- **Rally ADR** (NOT YET WRITTEN — post-MVP) — adds Rally orchestration per grid-battle.md CR-15
- **Skill ADR** (NOT YET WRITTEN — post-MVP) — adds USE_SKILL counter eligibility per AC-GB-15 + AOE_ALL handling
