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
| **Enables** | (1) **grid-battle-controller epic** (sprint-5 epic 10/10 Complete 2026-05-03 — closed); (2) **ADR-0016 Battle Scene Wiring** (Accepted 2026-05-03 via /architecture-review delta #11 — RATIFIED parameter-stable per backfill: GridBattleController mounted at step 5 of 6-step _ready() mount sequence via 8-param `setup(units, map_grid, camera, hero_db, turn_runner, hp_controller, terrain_effect, unit_role) + add_child()` per ADR-0016 §3 — first scene that mounts Camera + GridBattleController + 7 backends; **same-patch amended via /architecture-review delta #14** to insert step 5.5 AISystem mount per ADR-0019 acceptance); (3) **ADR-0015 Battle HUD** (Accepted 2026-05-03 via /architecture-review delta #10) — RATIFIED parameter-stable; subscribes to 4 of 5 controller-LOCAL signals (`unit_selected_changed` / `unit_moved` / `damage_applied` / `battle_outcome_resolved`) + queries `get_selected_unit_id` per ADR-0015 §3 + §5; **EXPLICITLY does NOT subscribe** to `hidden_fate_condition_progressed` per Pillar 2 lock 3-layer enforcement (test layer story-008 connection-count + source-grep lint per ADR-0015 §8 + architecture-layer registry forbidden_pattern `battle_hud_subscribes_to_hidden_fate_signal`); (4) **ADR-0017 Scenario Progression** (Accepted 2026-05-04 via /architecture-review delta #12 — RATIFIED `battle_outcome_resolved(BattleOutcome)` consumer at BEAT_5_BATTLE → BEAT_6_RESULT transition per ADR-0017 §Decision §Architecture Diagram + §Requirements line 68; ScenarioRunner subscribes via `GameBus.battle_outcome_resolved.connect(_on_battle_outcome, CONNECT_DEFERRED)` per ADR-0001 cross-scene routing rule; never mutates or overrides outcome per ADR-0017 §CR-3 invariant); (5) **ADR-0018 Destiny Branch** (Accepted 2026-05-04 via /architecture-review delta #13 — RATIFIED sole consumer of hidden_fate_condition_progressed signal per Pillar 2 lock; ADR-0015 §8 codifies the source-grep lint enforcing HUD non-subscription); (6) **ADR-0019 AI System** (Accepted 2026-05-05 via /architecture-review delta #14 — RATIFIED 6th LOCAL signal `ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` consumer; AISystem battle-scoped Node 6th invocation subscribes with CONNECT_DEFERRED at AISystem `_ready()` per ADR-0019 §Decision body + emits its own LOCAL signal `ai_action_ready(unit_id: int, command: AIActionCommand)` back to GridBattleController within 500ms timeout per grid-battle.md CR-3 protocol; `_make_battle_state_snapshot() -> BattleStateSnapshot` private helper added at sprint-7+ S7-04 implementation patch per ADR-0019 §Migration Plan §6). |
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
- **R-9**: Emit Battle-domain controller-LOCAL signals (**6 total** — MVP set [5] ratified by ADR-0015 Battle HUD Accepted 2026-05-03 via /architecture-review delta #10; **6th signal `ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` ratified by ADR-0019 AI System Accepted 2026-05-05 via /architecture-review delta #14**). BattleHUD subscribes to 4 of 5 MVP signals (unit_selected_changed / unit_moved / damage_applied / battle_outcome_resolved + EXPLICITLY NOT hidden_fate_condition_progressed per Pillar 2 lock); Destiny Branch is sole consumer of hidden_fate_condition_progressed; AISystem (ADR-0019 battle-scoped Node 6th invocation) is sole consumer of ai_action_requested with CONNECT_DEFERRED + responds via its own LOCAL signal `ai_action_ready(unit_id: int, command: AIActionCommand)` within 500ms timeout per grid-battle.md CR-3. Per-frame budget consumption: ai_action_requested fires 1× per AI unit per turn = ~4 events per round (chapter-1 (장판파) enemy roster 하후돈/장요/우금/허저); 4 prior signals fire on player action only (1-3 events per turn); hidden_fate_condition_progressed fires at most ~5× per battle. Total emit budget consumption < 12/frame even at peak — well under ADR-0001 §445 50-emits/frame cap.
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

### 8. GridBattleController-LOCAL signal emission (MVP set [5] ratified by ADR-0015 Battle HUD Accepted 2026-05-03 via /architecture-review delta #10; **6th signal `ai_action_requested` ratified by ADR-0019 AI System Accepted 2026-05-05 via /architecture-review delta #14**)

This ADR commits 6 controller-LOCAL signals (NOT GameBus — battle-scoped Node-to-Node communication channel per `grid_battle_controller_signal_emission_outside_battle_domain` forbidden_pattern):

```gdscript
signal unit_selected_changed(unit_id: int, was_selected: int)  # was_selected = -1 for deselect
signal unit_moved(unit_id: int, from: Vector2i, to: Vector2i)
signal damage_applied(attacker_id: int, defender_id: int, damage: int)
signal battle_outcome_resolved(outcome: StringName, fate_data: Dictionary)
signal hidden_fate_condition_progressed(condition_id: StringName, value: int)
signal ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)  # ADDED via /architecture-review delta #14 (sprint-7 S7-01); consumed by AISystem battle-scoped Node 6th invocation per ADR-0019; emitted at AI-turn entry per grid-battle.md CR-3 + CR-3a; AISystem responds via its own LOCAL signal `ai_action_ready(unit_id, command)` within 500ms timeout. NOTE: shipped src/feature/grid_battle/grid_battle_controller.gd lines 85-99 currently declares 5; sprint-7+ S7-04 implementation patch adds the 6th declaration + `_make_battle_state_snapshot()` private helper per ADR-0019 §Migration Plan §6 + ai_action_requested.emit(unit_id, snapshot) call site at AI-turn entry.
```

`hidden_fate_condition_progressed` is consumed ONLY by Destiny Branch ADR (sprint-6); Battle HUD does NOT subscribe (preserves the "hidden" semantic per Pillar 2 architectural lock — first project precedent of pillar-anchored lint pattern via `battle_hud_subscribes_to_hidden_fate_signal` forbidden_pattern).

`ai_action_requested` is consumed ONLY by AISystem (ADR-0019 battle-scoped Node 6th invocation); BattleHUD MAY subscribe to a future "AI thinking" indicator signal pattern at sprint-7+ battle-hud GDD revision (UI-GB-N) per ADR-0019 §Migration Plan §7 — but that subscription targets AISystem.ai_action_ready, NOT GridBattleController.ai_action_requested.

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

GridBattleController emits 6 controller-LOCAL signals (NOT GameBus — battle-scoped Node-to-Node channel):
  unit_selected_changed   → Battle HUD (sprint-5)
  unit_moved              → Battle HUD
  damage_applied          → Battle HUD + (post-MVP) damage-floats VFX
  battle_outcome_resolved → Scenario Progression (delta #12) + Destiny Branch (delta #13)
  hidden_fate_condition_progressed → Destiny Branch ONLY (HUD does NOT subscribe — Pillar 2 lock)
  ai_action_requested     → AI System ONLY (delta #14 — battle-scoped Node 6th invocation;
                              AISystem responds via its own LOCAL signal ai_action_ready
                              within 500ms timeout per grid-battle.md CR-3)
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
- **ADR-0017 Scenario Progression** (Accepted 2026-05-04 via /architecture-review delta #12) — sole consumer of `battle_outcome_resolved` per ADR-0017 §Decision; ScenarioRunner subscribes via GameBus + CONNECT_DEFERRED at autoload `_ready()`
- **Destiny Branch ADR** (NOT YET WRITTEN — sprint-6) — sole consumer of `hidden_fate_condition_progressed`
- **Battle AI ADR** (NOT YET WRITTEN — sprint-7+) — supersedes player-only-turns assumption; consumes `get_battle_state_snapshot()` opaque API
- **Formation Bonus ADR** (NOT YET WRITTEN — post-MVP) — supersedes inline formation math; FormationBonusSystem orchestration per CR-FB-6
- **Rally ADR** (NOT YET WRITTEN — post-MVP) — adds Rally orchestration per grid-battle.md CR-15
- **Skill ADR** (NOT YET WRITTEN — post-MVP) — adds USE_SKILL counter eligibility per AC-GB-15 + AOE_ALL handling

---

## Amendment 2026-05-10 — S15-B: AISystem.ai_action_ready Subscriber + Handler Dispatch (Sprint-15 POLISH-011 Closure)

### Context

Sprint-15 story S15-B (story-011) addresses POLISH-011 root cause #2 of 3: shipped `GridBattleController` declares `signal ai_action_requested(unit_id, BattleStateSnapshot)` at line 105 and emits it from `_on_unit_turn_started` for non-player units — but does NOT subscribe to AISystem's response signal `ai_action_ready(unit_id, AIActionCommand)`. AI's command is computed by AISystem and emitted, but no consumer ever calls `_handle_*` or `_turn_runner.declare_action()` to release the S15-A T5 await. Symptom: AI turns drain across deferred slots → ROUND_CAP DRAW. Fix: add controller-side subscriber + 6-way handler dispatch table that maps `AIActionCommand.ActionType` (6 values) → `TurnOrderRunner.ActionType` (5 values) with `USE_SKILL` substituted by `WAIT` per §0 MVP scope.

### §8 Subscriber Contract — Implementation Amendment

Adds a 6th DI-injected reference field on `GridBattleController`:

```gdscript
var _ai_system: AISystem = null
```

Mirrors the S15-A `set_action_controller` Callable setter precedent on `TurnOrderRunner` (ADR-0011 §Amendment 2026-05-09) — DI surface (injection point), NOT runtime gameplay state. Set via public setter `set_ai_system(ai_system: AISystem) -> void` called by BattleScene mount sequence AFTER `add_child()` for both GridBattleController (step 5) and AISystem (step 5.5). Order does not matter — connection is established in the setter, not in `_ready()`, so callers can invoke `set_ai_system` at any point post-mount.

Subscription discipline (extends the 4-GameBus DEFERRED + `_exit_tree` disconnect pattern from TR-grid-battle-controller-007 to a 5th LOCAL subscription):

- `Object.CONNECT_DEFERRED` flag MANDATORY (LOAD-BEARING, not stylistic) — handler calls `_do_move` / `_resolve_attack` (NOT the `_handle_move` / `_handle_attack` wrappers — see §"Why `_do_move` / `_resolve_attack` Directly" below) which mutate `_units` / `_map_grid`; deferral prevents reentrance from synchronous AISystem emit paths (test seams may emit synchronously even though production path is itself deferred).
- Idempotent `is_connected(_on_ai_action_ready)` guard before `connect` — `set_ai_system` is safe to call twice with the same AISystem; second call is a no-op.
- `_exit_tree()` disconnect MANDATORY with `is_instance_valid(_ai_system)` guard per **G-11** (battle-scoped Node teardown order is undefined — AISystem may free before GridBattleController in edge orders).

### Handler Dispatch Table

`_on_ai_action_ready(unit_id: int, command: AIActionCommand)` dispatches via 6-way `match command.action_type` (5 mapped + 1 substituted):

| `AIActionCommand.ActionType` | Game-state mutation | `TurnOrderRunner.declare_action` call(s) |
|---|---|---|
| `WAIT` | none | `(unit_id, WAIT, null)` |
| `MOVE` | `_do_move(unit, command.move_target)` | `(unit_id, MOVE, _make_move_target(...))` |
| `ATTACK` | `_resolve_attack(attacker, defender)` | `(unit_id, ATTACK, _make_attack_target(...))` |
| `MOVE_AND_ATTACK` | `_do_move` then `_resolve_attack` | TWO calls: `(MOVE, ...)` then `(ATTACK, ...)` |
| `DEFEND` | none (TurnOrderRunner sets `defend_stance_active`) | `(unit_id, DEFEND, null)` |
| `USE_SKILL` | none + `push_warning` | `(unit_id, WAIT, null)` per §0 MVP scope deferral |

Pre-dispatch guards: early-return on `_battle_over`, on `command == null` (push_warning), and on `unit_id not in _units` (push_warning). Unknown / out-of-enum values fall through to `WAIT` substitution with `push_warning` (defense-in-depth catch-all).

### Order of Operations

For `MOVE` / `ATTACK` / `MOVE_AND_ATTACK` paths: **game-state mutation FIRST, `declare_action` SECOND**. This ordering is load-bearing because:

1. State changes (HP, position, MapGrid occupancy, `_acted_this_turn` flag) must commit before T6+T7 deferred path runs so LOCAL signal subscribers (HUD, animation systems) see consistent snapshot.
2. `declare_action` triggers the S15-A `_maybe_defer_turn_completion` predicate — after `action_token_spent == true`, `_complete_turn_t6_to_t7.call_deferred(unit_id)` fires on the NEXT deferred slot. Pre-mutation ensures the snapshot at T6 reflects the action's effects.
3. For `MOVE_AND_ATTACK`, the first `declare_action(MOVE)` does NOT satisfy the predicate (only `move_token_spent` is set per S15-A); the second `declare_action(ATTACK)` does (`action_token_spent == true`) and triggers the deferred completion. Validated in S15-A `test_t5_holds_for_move_does_not_complete_turn`.

### Why `_do_move` / `_resolve_attack` Directly (NOT `_handle_move` / `_handle_attack`)

The `_handle_move(unit, dest)` and `_handle_attack(attacker_id, defender_id)` wrappers each call `_consume_unit_action(unit_id)` internally, which calls `_turn_runner.declare_action(unit_id, ATTACK, null)` (story-006 MVP single-token simplification — single-token model for player path). If the AI handler invoked the wrapper, it would result in TWO `declare_action` calls per AI action: first `ATTACK` from `_consume_unit_action`, then the correctly-typed action from the AI handler. Bypassing the wrappers to call `_do_move` / `_resolve_attack` directly + manually setting `_acted_this_turn[unit_id] = true` keeps the AI path single-call-per-action and emits the correct `ActionType` to TurnOrderRunner's `_maybe_defer_turn_completion` predicate.

This is a clean separation of concerns:

- **Player input path**: uses `_handle_move` / `_handle_attack` wrappers (single-token MVP per story-006 §6).
- **AI path** (this amendment): uses the underlying `_do_move` / `_resolve_attack` primitives (typed-action MVP per S15-A `_maybe_defer_turn_completion`).

When the post-MVP move-token + action-token split lands (Token ADR — future), both paths converge on the same wrapper, and `_consume_unit_action` is removed in the same patch.

### `ActionTarget` Construction

Two new private factory helpers added in this amendment:

```gdscript
func _make_move_target(target_pos: Vector2i) -> ActionTarget:
    var t: ActionTarget = ActionTarget.new()
    t.target_position = target_pos
    t.target_unit_id = 0
    t.movement_cost = 0   # story-007+ refinement: populate from terrain cost matrix
    return t

func _make_attack_target(target_unit_id: int) -> ActionTarget:
    var t: ActionTarget = ActionTarget.new()
    t.target_unit_id = target_unit_id
    t.target_position = Vector2i.ZERO
    t.movement_cost = 0
    return t
```

`movement_cost: 0` is acceptable for this story's MVP scope because F-2 Cavalry Charge accumulation (per ADR-0011 line 318) is not yet exercised by AI MOVE actions. Story-007+ Grid Battle integration may extend `_make_move_target` to populate from `MapGrid.get_movement_cost(from, to)` or path-cost-summation.

### Backward Compatibility

The amendment is purely additive:

- Existing 6 LOCAL signals preserved (no signature changes).
- Existing 4 GameBus subscriptions preserved (CONNECT_DEFERRED + `_exit_tree` disconnect discipline per TR-grid-battle-controller-007).
- Story-001..010 controller tests continue to PASS without regression (validated via post-implementation full-suite run).
- 8-param `setup(...)` signature LOCKED per §10 — AISystem reference injected via separate `set_ai_system` setter, NOT added as 9th setup param. ADR-0019 mount-sequence step 5.5 unchanged.

### Out of Scope (Deferred)

Per story-011 Out of Scope clause:

- 500ms AI timeout + WAIT-substitution per CR-3b (CR-3b future story; AISystem currently synchronous)
- `ai_soft_lock_counter` escalation per CR-3 (future story)
- USE_SKILL execution (Skill ADR — Counter-eligibility AC-GB-15 + AOE_ALL EC-GB-02 per §0 MVP deferral list)
- Player declare_action plumbing in grid-click handlers (S15-C scope — POLISH-011 absorption #3 of 3)
- Full natural-loop integration test player-vs-AI to non-DRAW (S15-D scope — first natural-loop test in codebase, paired with G-30 windowed-smoke harness mitigation infrastructure)
- `tools/ci/smoke_grid_battle_windowed.sh` (S15-D pairing per G-30)

### Cross-References

- `docs/architecture/ADR-0011-turn-order.md` §Amendment 2026-05-09 — S15-A T5 await mechanism + `set_action_controller` Callable setter precedent
- `docs/architecture/ADR-0019-ai-system.md` §Decision §Payload Form — `AIActionCommand` consumer-side contract (6-ActionType append-only enum)
- `production/epics/grid-battle-controller/story-011-polish-011-ai-action-ready-subscriber.md` — story file with AC-1..AC-8 + Implementation Notes §1-§6 + Risks R1/R2/R3
- `tests/integration/feature/grid_battle/grid_battle_controller_ai_action_ready_test.gd` — 10 integration tests verifying handler dispatch table (NEW this story)
- `.claude/rules/godot-4x-gotchas.md` G-11 (`is_instance_valid` before `as Node` cast) + G-15 (`before_test` not `before_each`) + G-22 (`@abstract` requires concrete subclass for instantiation in tests) + G-26 (inner-class name prefix) — actively guarded in this story's implementation + test design

---

## Amendment 2026-05-10 (#2) — S15-C: Player Path declare_action Plumbing (Sprint-15 POLISH-011 Closure)

### Context

Sprint-15 story S15-C (story-012) addresses POLISH-011 root cause #3 of 3: the player path's grid-click action arms in `_handle_grid_click_unit_selected` dispatch via `_handle_move` / `_handle_attack` / `end_player_turn`, which either declare the wrong token type or skip the T5 declare entirely.

**Root cause breakdown:**

- `move_target_select` / `move_confirm` arm — calls `_handle_move(unit, dest)`, which internally calls `_consume_unit_action(unit_id)`, which calls `_turn_runner.declare_action(unit_id, ATTACK, null)`. A MOVE action mistakenly declares an **ATTACK** token. Under the S15-A `_maybe_defer_turn_completion` predicate, this may prematurely satisfy `action_token_spent == true` and advance the turn before a follow-up ATTACK can be declared.
- `attack_target_select` / `attack_confirm` arm — calls `_handle_attack(attacker_id, defender_id)`, which similarly calls `_consume_unit_action` → `declare_action(ATTACK, null)`. The token type is technically correct (ATTACK), but the `ActionTarget` is null per story-006 MVP stub, missing the `target_unit_id` payload that S15-A's `_maybe_defer_turn_completion` and the downstream T6/T7 path rely on.
- `end_unit_turn` arm — calls `end_player_turn()` directly, which clears `_acted_this_turn` + deselects. No `declare_action` call is made for unacted units, so the T5 await is never released for those units. The natural battle loop stalls.

This amendment introduces three **player-path mirror helpers** that replicate the AI-path bypass pattern from Amendment 2026-05-10 (S15-B): calling `_do_move` / `_resolve_attack` directly with explicit `declare_action` at the correct `ActionType`, bypassing `_consume_unit_action`'s hardcoded ATTACK token.

### Player-Path Mirror Helpers

Three new private helpers are added. The dispatch arm rewires in `_handle_grid_click_unit_selected` point to these helpers instead of the old wrappers.

**`_handle_player_move(unit: BattleUnit, dest: Vector2i) -> void`**
Mirrors the AI-path MOVE arm in `_on_ai_action_ready`. Calls `_do_move` directly (not `_handle_move`), sets `_acted_this_turn[unit.unit_id] = true`, then calls `_turn_runner.declare_action(unit.unit_id, TurnOrderRunner.ActionType.MOVE, _make_move_target(dest))`. Re-entrancy guard: early-return if `_acted_this_turn` already set. Validation guard: early-return if `is_tile_in_move_range` fails (internal check; dispatch arm also has this guard — redundant but harmless per story-004/005/006 behavioural guarantee preservation).

**`_handle_player_attack(attacker_id: int, defender_id: int) -> void`**
Mirrors the AI-path ATTACK arm. Calls `_resolve_attack` directly (not `_handle_attack`), sets `_acted_this_turn[attacker_id] = true`, then calls `_turn_runner.declare_action(attacker_id, TurnOrderRunner.ActionType.ATTACK, _make_attack_target(defender_id))`. Re-entrancy guard: early-return if `_acted_this_turn` already set. Validation guards: `_units.has` check + `is_tile_in_attack_range` check — match the existing `_handle_attack` wrapper's defensive guards.

**`_handle_player_end_turn() -> void`**
Declares WAIT for every alive player-side unit that has NOT yet acted this turn, releasing their T5 await slots. After iterating, calls `end_player_turn()` to preserve existing side effects (clear `_acted_this_turn`, deselect). Filter logic: `unit.side != 0` skip (enemy units excluded); `_hp_controller.is_alive` check (dead units excluded); `_acted_this_turn.get(unit.unit_id, false)` check (already-acted units excluded — avoids double-declare).

**Dispatch arm rewires in `_handle_grid_click_unit_selected`:**

| Arm | Before (S15-C) | After (S15-C) |
|-----|----------------|---------------|
| `move_target_select` / `move_confirm` | `_handle_move(_units[_selected_unit_id], coord)` | `_handle_player_move(_units[_selected_unit_id], coord)` |
| `attack_target_select` / `attack_confirm` | `_handle_attack(_selected_unit_id, unit_id)` | `_handle_player_attack(_selected_unit_id, unit_id)` |
| `end_unit_turn` | `end_player_turn()` | `_handle_player_end_turn()` |

Cross-reference: S15-B AI-path bypass precedent — Amendment 2026-05-10 §"Why `_do_move` / `_resolve_attack` Directly (NOT `_handle_move` / `_handle_attack`)".

### Order of Operations

Same as S15-B AI-path: **game-state mutation FIRST, `declare_action` SECOND**.

For `_handle_player_move`: `_do_move` (position + MapGrid occupancy mutation) → `_acted_this_turn` flag → `declare_action(MOVE)`.

For `_handle_player_attack`: `_resolve_attack` (HP mutation via `_hp_controller.apply_damage`) → `_acted_this_turn` flag → `declare_action(ATTACK)`.

For `_handle_player_end_turn`: `_acted_this_turn` flag per unit → `declare_action(WAIT)` per unit → `end_player_turn()` (clear + deselect side effects).

This ordering is load-bearing for the same reasons documented in S15-B §Order of Operations: state changes must commit before `declare_action` triggers the T6/T7 deferred completion path via S15-A `_maybe_defer_turn_completion`.

### Backward Compatibility

The amendment is backward-compatible with all story-004 through story-012 tests:

- **`_handle_move(unit, dest)` UNCHANGED** — body still calls `_do_move` + `_consume_unit_action`. Story-004 tests that call `_handle_move` directly (or tests that verify `_consume_unit_action` path via `_handle_move`) continue to pass. The backward-compatibility regression sentinel test (Test 7 in the new test file) pins this explicitly: `_handle_move` still declares `ATTACK` via `_consume_unit_action`.
- **`_handle_attack(attacker_id, defender_id)` UNCHANGED** — body still calls `_resolve_attack` + `_consume_unit_action`. Story-005 tests continue to pass.
- **`_consume_unit_action(unit_id)` UNCHANGED** — body still sets `_acted_this_turn` + calls `declare_action(ATTACK, null)` + deselects + auto-handoff. Story-006 tests continue to pass.
- **`end_player_turn()` UNCHANGED** — public method still clears `_acted_this_turn` + deselects. Called at the end of `_handle_player_end_turn()`; story-006 tests that call it directly continue to pass.
- **All 4 GameBus subscriptions UNCHANGED** — `_on_input_action_fired` still dispatches to `handle_grid_click`, which dispatches to `_handle_grid_click_unit_selected`. The only change is the call target inside three match arms.

### Out of Scope (Deferred)

Per story-012 Out of Scope clause:

- **Token ADR convergence** (post-MVP) — eventually `_consume_unit_action` will be retired and both player and AI paths will converge on a shared token-split wrapper. Until then the two paths remain separate: player path uses `_handle_player_*` helpers, AI path uses `_on_ai_action_ready` bypass.
- **DEFEND grid-click arm** — player UI has no DEFEND action button in MVP. Only the AI path emits `AIActionCommand.DEFEND` via `_on_ai_action_ready`. No player-side DEFEND helper is needed.
- **USE_SKILL deferral** — Skill ADR handles this. Player UI has no USE_SKILL action in MVP.
- **Full natural-loop integration test (player-vs-AI to non-DRAW)** — S15-D scope, paired with G-30 windowed-smoke harness per `_GRID_ACTIONS` note at ADR-0014 §0.
- **`tools/ci/smoke_grid_battle_windowed.sh`** — S15-D pairing per G-30 mitigation infrastructure.

### Cross-References

- `production/epics/grid-battle-controller/story-012-polish-011-player-declare-action-plumbing.md` — story file with AC-1..AC-9 + Out of Scope + Engine Notes
- `docs/architecture/ADR-0011-turn-order.md` §Amendment 2026-05-09 — S15-A T5 await mechanism (`_maybe_defer_turn_completion` predicate; this story's helpers feed the correct `ActionType` to release it)
- `tests/integration/feature/grid_battle/grid_battle_controller_player_declare_action_test.gd` — 7 integration tests verifying player-path dispatch arm rewiring (NEW this story)
- `.claude/rules/godot-4x-gotchas.md` G-15 (`before_test` not `before_each`) + G-22 (`@abstract` requires concrete subclass) + G-26 (inner-class prefixed GBCP*) + G-28 (never bulk-disconnect-all) + G-30 (headless test pass does not gate windowed-mode lifecycle — mitigation infrastructure for full-loop coverage deferred to S15-D windowed-smoke harness)

---

## Amendment 2026-05-10 (#3 — S15-J production-wiring residual closure: BattleScene mount-sequence integration site)

**Status**: Accepted (sprint-15 S15-J — POLISH-012 closure mid-sprint amendment)

### Context

S15-A (story-010) added the `set_action_controller` DI surface — a public setter on `TurnOrderRunner` that registers an arbitrary `Callable` as the T5 action dispatcher, enabling NATURAL-LOOP mode vs TEST-SEAM pass-through. S15-B (story-011) added the consumer path for AI: `_on_ai_action_ready` subscriber + `ai_action_requested` → AISystem chain. S15-C (story-012) added the consumer path for players: `_handle_player_*` mirror helpers + dispatch arm rewiring in `_handle_grid_click_unit_selected`.

**The production gap discovered at S15-D (story-013) Phase 4 investigation**: `grep -rn "set_action_controller" src/ tests/` returned 7 test sites (all in `tests/integration/core/turn_order_t5_await_test.gd`) and **0 production callers**. The `set_action_controller` setter was never called from production code. Without this call, T5's `_execute_action_budget` evaluates `_action_controller.is_null() == true` on every advance and falls through the `# TEST-SEAM mode no-op pass` return. The entire S15-A/B/C absorption arc — AI dispatch via AISystem, player declare_action plumbing via `_handle_player_*` — was inert in production.

At ROUND_CAP=30 with T5 as a no-op, the battle loop runs to completion in ~2-3 seconds across deferred call slots and emits `battle_outcome_resolved("TURN_LIMIT_REACHED")`. No visible errors. Headless tests passed throughout because they bypass the natural battle loop via direct seam calls (G-30 pattern: headless test pass does not gate windowed-mode lifecycle behavior).

This amendment (#3) closes the gap by wiring the production caller at the correct point in BattleScene's mount sequence.

### Decision

**BattleScene._ready STEP 5** calls `_turn_runner.set_action_controller(_grid_controller._on_turn_runner_action_request)` **AFTER** `_grid_controller.set_chokepoints(chapter.chokepoints)` and **BEFORE** `add_child(_grid_controller)`.

This insertion point is load-bearing:

- **After `setup()`** (STEP 5 start): `_grid_controller.setup(...)` must run before the Callable is registered — `_on_turn_runner_action_request` reads `_units`, `_hp_controller`, and calls `_make_battle_state_snapshot()`, all of which are populated only after `setup()` completes. Registering the Callable before `setup()` would bind a handler that can't yet resolve unit state.
- **After `set_chokepoints()`**: Ordering relative to chokepoints is not load-bearing for correctness, but sequential STEP 5 operations preserve code locality for readability.
- **Before `add_child(_grid_controller)`**: `_begin_round.call_deferred()` is triggered inside `TurnOrderRunner._ready()`, which fires after `add_child(_turn_runner)` (STEP 4). By the time STEP 5 runs, `_begin_round` has been queued but NOT yet fired — it fires during the deferred call flush after `add_child(_grid_controller)`. The Callable must be registered before that first deferred slot resolves to avoid a one-shot DRAW at the start of the first battle.

### Handler: `_on_turn_runner_action_request`

A new private handler added to `GridBattleController` at the end of file (after the last signal-callback section):

```gdscript
func _on_turn_runner_action_request(unit_id: int, snapshot: TurnOrderSnapshot) -> void:
    var unit: BattleUnit = _units.get(unit_id, null)
    if unit == null:
        push_warning("S15-J: ...")
        return
    match unit.side:
        0:  # player — returns immediately; T5 stays paused until grid-click fires declare_action
            return
        1:  # enemy — emits ai_action_requested → AISystem.decide → ai_action_ready chain
            var battle_snapshot: BattleStateSnapshot = _make_battle_state_snapshot()
            ai_action_requested.emit(unit_id, battle_snapshot)
        _:
            push_warning("S15-J: unknown unit.side ...")
```

**Side-routing logic:**

- **Player-side (`unit.side == 0`)**: Returns immediately. T5 stays suspended at `_action_controller.call(unit_id, snapshot)` — the caller (`_execute_action_budget`) returns without advancing T6/T7. T6/T7 are released when the player clicks a valid action target, which fires one of the `_handle_player_*` helpers (S15-C), which calls `declare_action(...)`, which triggers `_maybe_defer_turn_completion.call_deferred()`.
- **Enemy-side (`unit.side == 1`)**: Emits `ai_action_requested.emit(unit_id, battle_snapshot)`. AISystem's `CONNECT_DEFERRED` subscriber (S15-B) picks up the signal in the next deferred slot, calls `decide(unit_id, snapshot)`, determines the best `AIActionCommand`, and emits `ai_action_ready(unit_id, command)`. `_on_ai_action_ready` (S15-B) processes the command via the 6-way dispatch table and calls `declare_action(...)` to release T5.
- **Defensive unknown unit_id**: `push_warning + return` — no crash, no dispatch. Does not consume the T5 slot; battle loop gracefully advances to the next unit via the ROUND_CAP timeout.
- **Defensive unknown side**: `push_warning + return` — same safety guarantee.

**Key clarifications vs story-014 spec assumptions:**

1. **Snapshot type**: `TurnOrderSnapshot` — NOT `UnitTurnState`. Verified at `turn_order_runner.gd:614`: `var snapshot: TurnOrderSnapshot = get_turn_order_snapshot(); _action_controller.call(unit_id, snapshot)`. The handler parameter is typed `TurnOrderSnapshot` to satisfy the Callable contract. The handler does NOT read `snapshot` — it builds a fresh `BattleStateSnapshot` for AI dispatch via `_make_battle_state_snapshot()`.
2. **Enemy dispatch pattern**: emits existing `ai_action_requested` signal — NOT a direct `_ai_system.decide()` call. This reuses the full S15-B chain end-to-end (AISystem CONNECT_DEFERRED subscriber → `decide` → `ai_action_ready` emit → `_on_ai_action_ready` handler). Mirrors the `_on_unit_turn_started` precedent at lines 630-631 that also emits `ai_action_requested` for enemy-side turns. Direct coupling to AISystem would duplicate emit + executor logic and break the single-responsibility boundary between GridBattleController and AISystem.

### Backward Compatibility

The amendment is fully backward-compatible:

- **`set_action_controller` DI surface (S15-A) UNCHANGED** — the setter signature and semantics are identical. Only a NEW production caller is added in BattleScene. The existing 7 test sites in `tests/integration/core/turn_order_t5_await_test.gd` continue PASS without modification.
- **BattleScene._ready STEP 1-4 + STEP 5.5 + STEP 6 UNCHANGED** — only STEP 5 receives the ~3-line wire-up addition between `set_chokepoints` and `add_child`.
- **TEST-SEAM mode preserved** — any test that creates a `TurnOrderRunner` directly (without calling `set_action_controller`) still gets the `is_null()` no-op pass at `_execute_action_budget`. The seam is unaffected.

### Cross-References

- `docs/architecture/ADR-0011-turn-order.md` §Amendment 2026-05-09 (S15-A T5 await Callable contract — defines the DI surface that #3 satisfies at production scope)
- §Amendment 2026-05-10 (#1 — S15-B AI subscriber + 6-way dispatch chain)
- §Amendment 2026-05-10 (#2 — S15-C player path mirror helpers)
- `production/polish-backlog.md` — POLISH-012 entry (production-wiring gap)
- `production/epics/grid-battle-controller/story-014-set-action-controller-production-wiring.md` — story file with AC-1..AC-6
- `production/sprints/sprint-15.md` — Mid-Sprint Amendments section (S15-J)
- `tests/integration/feature/battle_scene/battle_scene_set_action_controller_wiring_test.gd` — 5 integration tests verifying AC-1..AC-6 (NEW this story)
- `.claude/rules/godot-4x-gotchas.md` G-4 (lambda primitive capture → Array captures) + G-15 (`before_test` not `before_each`) + G-30 (headless test pass does not gate windowed-mode lifecycle — root cause of POLISH-012 discovery gap)
