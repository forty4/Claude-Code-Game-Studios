# Grid Battle System (그리드 전투)

> **Status**: v5.0 — Pillar-alignment pass (12 adjudicated design decisions applied across RC-1 registry drift, RC-2 cross-doc contradictions, RC-3 class identity, RC-5 AC testability)
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-19
> **Implements Pillar**: 형세의 전술 (Tactics of Momentum), 모든 무장에게 자리가 있다 (Every class has a role)
> **UI spec**: `design/ux/battle-hud.md` (owns Visual/Audio, UI-GB-01..13, forecast contract)
>
> **v5.0 revision log (2026-04-19)**:
> - **RC-1 drift**: `F-GB-PROV` deleted; `damage_resolve()` in `design/gdd/damage-calc.md` is the sole damage-resolution formula. `BASE_CEILING`/`DAMAGE_CEILING`/`COUNTER_ATTACK_MODIFIER` are now consumed from the registry, not restated. Render-driver language replaced with per-platform (Windows D3D12, Linux+Android Vulkan, macOS+iOS Metal) per `.claude/docs/technical-preferences.md`.
> - **RC-2 cross-doc**: `DEFEND_STANCE` reduction ratified at 50% (owned by `design/gdd/hp-status.md`, registry `defend_stance_reduction`); local `DEFEND_DAMAGE_REDUCTION` tuning knob deleted. CR-13 rule 4 (DEFEND_STANCE unit does not counter-attack) ratified; `design/gdd/hp-status.md` EC-14/AC-20 rewritten to match. `battle-hud.md` scope set to strict UI-only; rule-restatement migrated back here with bidirectional refs. Mobile DEFEND confirm rewritten to two-tap same-target (EC-GB-42).
> - **RC-3 class identity**: `WAIT` kept per-unit but reframed as Scout Ambush setup tool (hidden from non-Scout action menu by default; Settings toggle reveals it). DEFEND sets `acted_this_turn = true` (CR-13 rule 5 added). `TacticalRead` UI affordance becomes Strategist-only (CR-14 rewritten); Commander retains its pre-existing `passive_rally` combat mechanic per `design/gdd/unit-role.md` CR-2 (no upgrade to Rally values — specific balance edit deferred to future unit-role revision). `EC-GB-44` (dual-TR case) deleted. `battle-hud.md` adds `UI-GB-12` TacticalRead extended-range visual.
> - **RC-5 ACs/fixtures**: 10 flagged ACs rewritten inline with Given/When/Then + closed signal sets + `tests/fixtures/grid_battle/` fixture refs. 6–8 seed fixtures authored in this revision; full set deferred to implementation sprint.

## Overview

The Grid Battle System is the central combat orchestrator of 천명역전 — the
single system that binds the grid, terrain, units, turn order, and player input
into a unified tactical battle experience. When a battle begins, this system
initializes the map, deploys units to their starting positions, and manages the
battle lifecycle from the first initiative roll through victory, defeat, or
draw. On each unit's turn, it coordinates movement validation (consulting
Map/Grid for pathfinding and Terrain for movement costs), attack resolution
(pulling class stats from Unit Roles, applying terrain and directional
modifiers, and routing damage through HP/Status), and status effect processing.
The player interacts with it directly and constantly — every tap to select a
unit, every movement preview, every attack confirmation flows through Grid
Battle as the authoritative arbiter of what is legal and what happens next.
It is both the referee enforcing the rules and the stage on which the player's
tactical fantasy of reading the battlefield, exploiting positioning, and turning
disadvantage into victory plays out.

## Player Fantasy

### 형세를 읽는 자 — The Reader of Momentum

The Grid Battle System serves the fantasy of the brilliant strategist who reads
the battlefield like a GO board — seeing not pieces, but currents. Where the
enemy sees a static formation, the player sees pressure building on the left
flank, a gap about to open in the center, and cavalry arriving in three turns
to seal an encirclement that was planned five turns ago.

**The core emotion is the intellectual thrill of pattern recognition rewarded.**
The player who repositions an archer to an overlooked hilltop, who holds a
scout in reserve while the enemy overextends, who refuses to commit cavalry
until the exact moment a flank collapses — that player feels the satisfaction
of reading the 형세 (momentum/flow) correctly. The payoff is not immediate
power but delayed vindication: a decision that looked insignificant two turns
ago now becomes the pivot point of the entire battle.

**The anchor moment**: The player moves their last unit into position. The
enemy's line is intact, but the player knows — because they've been reading
terrain, facing, and initiative order for three turns — that the trap is
already sprung. Next turn, the flank opens. The turn after, the rear is
exposed. The battle was won not in the moment of attack, but in the quiet
turns of preparation that preceded it.

**What this means for design**: Every mechanic in this system must serve the
readability of momentum. Movement previews must clearly show threat zones.
Attack direction indicators must telegraph flanking opportunities. The
initiative queue must be visible so the player can plan sequences across
multiple units. Terrain modifiers must be surfaced, not hidden. The system
rewards foresight, not reflexes — and punishes the player who moves without
thinking, not the player who thinks without moving.

The pre-commit forecast (`design/ux/battle-hud.md` UI-GB-04) carries this
fantasy — it must NEVER under-warn. A player who commits to an attack the
forecast said was safe and dies anyway has been betrayed by the system.

## Detailed Rules

### Core Rules

**CR-1: Battle Initialization**

When a battle begins, Grid Battle executes this sequence:

1. Load scenario data: `map_id`, `unit_roster[]`, `deployment_positions{}`, `victory_conditions{}`.
2. Instantiate map via Map/Grid (load tile data, terrain types, elevation).
3. Place all units at scenario-defined positions — call `Map/Grid.place_unit(unit_id, col, row, facing)` for each.
4. Initialize HP for all units (HP/Status CR-1a: `current_hp = max_hp`).
5. Apply battle-start status effects if scenario defines them.
6. Compute initiative for all units (Unit Role F-4).
7. Build Turn Order queue (Turn Order BI-1 through BI-6).
8. Initialize `cooldown_map`: all skill cooldowns = 0 (ready).
9. Initialize `movement_budget_map`: all units = 0 (for Cavalry Charge tracking).
10. Initialize `ai_soft_lock_counter = 0` (CR-3b round-level AI escalation; guarantees clean state if Grid Battle node is reused across battles).
11. Emit `battle_initialized` → transition to DEPLOYMENT.

**CR-2: Deployment Phase (MVP)**

For MVP, deployment is fully scripted:

1. All unit positions are determined by scenario data (`deployment_positions{}`).
2. No player interaction during deployment.
3. Camera pans to show the battlefield layout (animation — Input blocked via S5).
4. Transition to COMBAT_ACTIVE when deployment animation completes.

*Future: Player-configurable deployment will use designated deployment tiles
per faction. Grid Battle will present a deployment UI, validate placement
constraints, and confirm before transitioning.*

**CR-3: Combat Flow (Per-Turn Orchestration)**

Grid Battle drives Turn Order and responds to its signals:

1. On `round_started(round_number)`: reset per-round tracking, apply round-start effects.
2. On `unit_turn_started(unit_id, is_player_controlled)`:
   - If `is_player_controlled = true`: emit `input_unblock_requested` (S5 → S0), enter **PLAYER_TURN_ACTIVE** substate, present action options.
   - If `is_player_controlled = false`: emit `input_block_requested` (S0 → S5), enter **AI_WAITING** substate, connect `ai_action_ready` with `CONNECT_ONE_SHOT`, emit `ai_action_requested(unit_id, get_battle_state_snapshot())`, start the `AI_DECISION_TIMEOUT_MS` timer (500ms default, owned by a dedicated `Timer` node — never `SceneTreeTimer` — so it can be stopped/reset). **While in AI_WAITING**, Grid Battle drops all incoming signals EXCEPT `ai_action_ready`, the timer's `timeout`, AND `battle_ended` (the abort signal must never be filtered). This prevents reentrance from `animation_complete` or stray `unit_died` callbacks during AI deliberation without losing battle-termination events. AI returns a decision via `ai_action_ready(unit_id, action_command)`. On receipt, Grid Battle stops the timeout timer, transitions AI_WAITING → AI_TURN_ACTIVE, and validates the action (CR-3a). On timer `timeout` without `ai_action_ready`, Grid Battle **explicitly** calls `disconnect("ai_action_ready", <bound_callable>)` to break the CONNECT_ONE_SHOT binding (CONNECT_ONE_SHOT auto-disconnects on successful fire ONLY, NOT on timeout — omitting this disconnect leaves a stale listener that would misroute a late AI response into the wrong substate). Then Grid Battle substitutes WAIT for the active unit, increments `ai_soft_lock_counter`, and proceeds to step 5. No retry is attempted. **Log-suppression rule**: the per-unit timeout log (`"AI_TIMEOUT: unit=<id>, substituting WAIT"` via `push_error`) fires UNLESS this increment raises `ai_soft_lock_counter` to `AI_SOFTLOCK_THRESHOLD` exactly — in that case the per-unit log is suppressed and CR-3b step 1 owns the detection log instead. This guarantees that for the threshold-crossing timeout, exactly one `push_error` fires (the `"AI_SOFTLOCK"`-prefixed detection log). Below threshold, only the per-unit log fires (no AI_SOFTLOCK). Above threshold (during flush), neither log fires per bypassed unit (CR-3b step 3 is silent per-unit — a single completion log closes the escalation).
3. Decrement all cooldowns for the active unit by 1 (floor at 0).
4. Reset `movement_budget_map[unit_id] = 0` for the active unit (per F-GB-1 per-turn reset).
5. Unit executes actions (MOVE and/or ACTION in any order, or WAIT). For AI turns, the action_command from `ai_action_ready` is executed; if invalid, substitute WAIT (CR-3a).
6. On turn completion: emit `unit_turn_ended(unit_id)` to Turn Order.
7. On `battle_ended(result)`: transition to RESOLUTION.

**CR-3a: AI Action Validation and END_TURN vs WAIT Semantics**

On receipt of `ai_action_ready(unit_id, action_command)`, Grid Battle validates
the action before execution:

- **Acting unit match**: `action_command.acting_unit_id` must equal the current `active_unit_id`. A command for a non-active unit fails validation.
- **MOVE**: target tile must be in unit's movement range (`is_tile_in_move_range`), unoccupied, reachable path exists.
- **ATTACK**: target must be alive, in attack range, facing-agnostic (FRONT/FLANK/REAR is computed, not AI-specified).
- **USE_SKILL**: skill slot index valid, cooldown == 0, target matches skill's target_type, in range, LoS satisfied if required.
- **DEFEND**: always valid. Applies DEFEND_STANCE per CR-13. Terminates the unit's turn.
- **WAIT**: always valid. Terminates the unit's turn with zero damage/modifier effects.

**WAIT vs END_TURN (P0 — DC-2 resolution)**:

- **WAIT** is a **per-unit** action. It terminates the active unit's turn immediately, forfeits both MOVE and ACTION tokens, and is the only path by which an individual unit ends its turn without acting. Signal: `unit_waited(unit_id)`.
- **END_TURN** is a **player-level command** that forces all remaining *unacted* player units to auto-WAIT in initiative order, closing the current round's player phase. It is a convenience for the player and exists in the action menu (`design/ux/battle-hud.md` UI-GB-02). Under the hood, END_TURN iterates remaining player units and emits `unit_waited` for each, identical to individual WAITs.
- **END_TURN is NOT an AI-submittable command.** Grid Battle auto-emits `unit_turn_ended(unit_id)` after the AI's action completes (or after WAIT substitution on timeout / invalid). AI may submit MOVE, ATTACK, USE_SKILL, DEFEND, or WAIT only. Any other action type fails validation.
- The `ai_soft_lock_counter` is incremented only on **CR-3 AI timeout** (an AI turn that never produced `ai_action_ready`). It is NOT incremented by any WAIT path (volitional, END_TURN batch, or CR-3b flush).
- **`acted_this_turn` on AI-failure substitution** (v5.0 pass-9b): CR-3 timeout, CR-3a invalid-action, and CR-3b flush all substitute WAIT but mark the unit `acted_this_turn = true` (Ambush-immune). Volitional WAIT (player-submitted, AI-submitted, OR END_TURN-batch-substituted) marks `acted_this_turn = false` (Ambush-bait). See CR-10 for the full bookkeeping rule and rationale.

If any validation fails, Grid Battle substitutes WAIT (no error to the player;
an error is logged for AI diagnostics with the validation rule that failed).
AI is NOT re-invoked — the invalid response has already consumed the turn's
deliberation budget.

**CR-3b: AI Soft-Lock Round-Level Escalation**

A per-turn AI timeout (CR-3) substitutes WAIT for one unit and continues the
round. A *systemic* AI failure — where multiple AI units in the same round hit
`AI_DECISION_TIMEOUT_MS` consecutively — is a soft-lock requiring round-level
escalation.

Grid Battle maintains `ai_soft_lock_counter` (int, initialized to 0 at CR-1
step 10, reset to 0 on `round_started` and in CLEANUP, incremented on every AI
timeout in CR-3). When `ai_soft_lock_counter` reaches `AI_SOFTLOCK_THRESHOLD`
(default 2) within a single round, Grid Battle executes the escalation sequence
below. Steps 1 and 2 fire synchronously on the threshold-crossing CR-3 timeout
(before the next `unit_turn_ended`); steps 3 and 4 fire after that unit's CR-3
WAIT substitution completes.

1. **Detection log**: emit exactly one `push_error("AI_SOFTLOCK_DETECTED: round=<R> trigger_unit=<id>")` at the moment `ai_soft_lock_counter` reaches threshold. This log has no `bypassed_units` field — the flush list is not yet computed. The per-unit CR-3 timeout log for this same unit is suppressed (see CR-3 step 2 log-suppression rule) so exactly one `push_error` fires for the threshold crossing.
2. Substitute WAIT for the currently-timed-out unit via the normal CR-3 path (preserves atomicity for the triggering turn; this unit is NOT counted in `bypassed_units` since it received standard CR-3 WAIT treatment).
3. After that WAIT resolves (`unit_turn_ended` emitted), flush the remainder of the initiative queue. **Flush-path contract**: for each pending AI unit, Grid Battle emits `unit_turn_started(unit_id, is_player_controlled=false)` followed immediately by `unit_waited(unit_id)` and `unit_turn_ended(unit_id)`. **The flush path MUST bypass CR-3 step 2's AI_WAITING setup entirely** — no `ai_action_requested` is emitted, no `ai_action_ready` CONNECT_ONE_SHOT listener is connected, no `AI_DECISION_TIMEOUT_MS` Timer is started, AI_WAITING substate is never entered. Implementers must guard the CR-3 step 2 branch with a soft-lock check (`if ai_soft_lock_counter >= AI_SOFTLOCK_THRESHOLD and is_player_controlled == false: synthesize_auto_wait(); return`). The `unit_waited` emission is mandatory (the auto-WAIT path) so the initiative strip registers the bypass and the per-unit WAIT contract is not silently broken. **Additionally, the flushed unit's `movement_budget_map[unit_id]` is reset to 0 and its cooldowns are decremented identically to a normal CR-3 step 3/4** — the unit would have had those side effects on a normal turn, and skipping them leaves stale budget state that triggers spurious Charge in a later round if the node is reused. Player units in the remaining queue are NOT bypassed and play normally via the standard CR-3 PLAYER_TURN_ACTIVE branch. No per-unit log fires during flush.
4. **Completion log**: after the flush loop finishes (all pending AI units auto-WAITed), emit exactly one `push_error("AI_SOFTLOCK: round=<R> bypassed_units=<comma_separated_ids>")` where `<comma_separated_ids>` is the ordered list of AI unit ids processed in step 3 (the triggering unit from step 2 is NOT included). This is the log asserted by AC-GB-25 assertion 6.
5. On `round_ended`, `ai_soft_lock_counter` resets to 0 and AI is re-engaged for the next round. Soft-lock is not a terminal failure — the battle continues. If `battle_ended` fires mid-round during soft-lock resolution, CLEANUP explicitly resets `ai_soft_lock_counter = 0` alongside releasing map and clearing unit instances — this prevents cross-battle contamination if the Grid Battle node is reused rather than freed and re-instantiated.

No user-facing error message is shown; see `design/ux/battle-hud.md` §2.13
for the silent-WAIT treatment. `AI_SOFTLOCK_THRESHOLD` is a tuning knob (default
2, safe range 1–5). The escalation is a last-resort defensive mechanism — a
healthy AI pipeline never hits it.

**CR-4: Movement Resolution**

1. Player selects unit → Input enters S1 (UnitSelected).
2. Grid Battle queries `Map/Grid.get_movement_range(unit_id, effective_move_range, terrain_costs)` using Unit Role's class terrain cost multipliers.
3. Highlight reachable tiles (UI-GB-04 / UX spec §2.1).
4. Player selects destination → Input enters S2 (MovementPreview).
5. Grid Battle queries `Map/Grid.get_path(unit_id, destination)` for optimal path.
6. Display path preview with movement cost per tile.
7. Player confirms (Beat 2):
   - Grid Battle calls `Map/Grid.move_unit(unit_id, destination_col, destination_row)`.
   - Facing updates to direction of final path step (CR-11).
   - Accumulate movement budget: `movement_budget_map[unit_id] += path_cost`.
   - If `movement_budget_map[unit_id] >= CHARGE_THRESHOLD (40)` and unit is CAVALRY: activate Charge passive (+20% ATK for next attack this turn).
   - Spend MOVE token.
8. Player may undo movement before using ACTION token (Input Handling undo rules: 1-move depth, closed by attack/end-turn). Pre-move snapshot is a `Dictionary.duplicate_deep()` (Godot 4.5+; `duplicate(true)` is deprecated).

**CR-5: Attack Resolution Pipeline**

When a player confirms an attack (Beat 2) or AI executes an attack:

| Step | Action | System |
|------|--------|--------|
| 1 | Validate: target in attack range, attacker has ACTION token, target alive | Grid Battle |
| 2 | Query attack direction (FRONT/FLANK/REAR) from attacker-to-target facing | Map/Grid (`get_attack_direction`) |
| 3 | Get direction damage multiplier (base × class-specific) | Unit Role |
| 4 | Check class passives that modify the attack (Charge, Ambush, TacticalRead) | Unit Role / CR-14 |
| 5 | Query terrain defense/evasion modifiers for defender's tile, including elevation | Terrain Effect (`get_combat_modifiers`) |
| 6 | Resolve evasion per F-GB-2 (2RN): if `miss == true`, attack deals no damage → skip directly to step 12 (counter-attack eligibility in step 11 is gated by CR-6 cond. 4 "primary dealt damage" which is false on a miss — bypassing step 11 avoids redundant evaluation; ACTION token is still spent per EC-GB-14) | Grid Battle |
| 7 | Invoke `damage_resolve(attacker, defender, modifiers)` from `design/gdd/damage-calc.md` (F-DC-1..7 pipeline). Returns `ResolveResult.HIT(resolved_damage ∈ [1, DAMAGE_CEILING], source_flags, vfx_tags)` or `ResolveResult.MISS(source_flags)` (latter only on `invariant_violation:*` guard failure since evasion was already resolved in step 6). Grid Battle is a consumer; it does not restate the formula. `BASE_CEILING=83`, `DAMAGE_CEILING=180`, `COUNTER_ATTACK_MODIFIER=0.5`, `CHARGE_BONUS=1.20`, `AMBUSH_BONUS=1.15` are all owned by `damage-calc.md` + registry. | Damage Calc |
| 8 | Route `ResolveResult.HIT.resolved_damage` through HP/Status intake pipeline (`apply_damage`): Shield Wall passive flat → DEFEND_STANCE -50% (hp-status.md `defend_stance_reduction=50`) → VULNERABLE/other status modifiers → MIN_DAMAGE=1 floor → HP reduction. Grid Battle never subtracts HP directly. | HP/Status |
| 9 | Check defender death: if `current_hp <= 0`, Grid Battle invokes `HP/Status.apply_death_consequences(unit_id)` EXPLICITLY before proceeding. This method handles DEMORALIZED propagation (morale_anchor check + application to allies in radius 4) and returns synchronously. After the explicit call returns, HP/Status emits `unit_died(unit_id)` for any other listeners (UI, analytics). Grid Battle then proceeds to step 10 (victory evaluation). **Order is enforced by explicit method call, not by signal connection order** — Godot does not guarantee signal-handler invocation order as an API contract. | Grid Battle / HP/Status |
| 10 | Evaluate victory/defeat conditions (CR-7) | Grid Battle |
| 11 | If defender survived AND counter-attack eligible (CR-6): execute counter-attack | Grid Battle |
| 12 | Spend attacker's ACTION token | Grid Battle |

**Pipeline abort rule**: If step 10 emits `battle_ended` (any VICTORY or
DEFEAT), steps 11 and 12 do NOT execute. The pipeline returns immediately after
`battle_ended` is emitted, regardless of surviving units or action token state.
This applies to primary attacks and to the counter-attack pipeline in CR-6
(which reuses steps 2-9; if a counter-attack's step 10 equivalent emits
`battle_ended`, no further steps execute).

*(v5.0) `F-GB-PROV` has been deleted from this document. `damage_resolve` in
`design/gdd/damage-calc.md` is the sole damage-resolution formula. Grid Battle
is a consumer only; registry-owned constants (`BASE_CEILING`, `DAMAGE_CEILING`,
`COUNTER_ATTACK_MODIFIER`, `CHARGE_BONUS`, `AMBUSH_BONUS`, `MIN_DAMAGE`,
`MAX_EVASION`, `MAX_DEFENSE_REDUCTION`) are read from
`design/registry/entities.yaml`.*

**CR-6: Counter-Attack Rules**

A counter-attack triggers when ALL of the following are true:

| Condition | Detail |
|-----------|--------|
| Defender survived | `current_hp > 0` after primary attack |
| In natural range | Attacker is within defender's **natural class attack range** — not within any extended/conditional range. See CR-6a for the Archer-specific rule. |
| Not suppressed — Ambush | Attacker does not have Scout Ambush active. Ambush is active ONLY when ALL of: (a) target `acted_this_turn = false`, (b) `current_round >= 2`, AND (c) **no enemy unit occupies any tile adjacent (Manhattan distance 1) to the Scout**. |
| Not suppressed — DEFEND_STANCE (v5.0) | Defender does NOT have `DEFEND_STANCE` status active. Per CR-13 rule 4, a DEFEND_STANCE unit is in pure-defensive commitment and cannot counter-attack. Forecast reason localization key when suppressed: `"forecast.no_counter.defend_stance"` (default KO: "반격 없음 — 방어 중"; default EN: "No counter — defending"). Rendered via `tr()` at UI-GB-04 §4.1 Section 3 muted reason; `design/ux/battle-hud.md` mirrors the key (not the literal string). |
| Primary dealt damage | Action was ATTACK or a damage-dealing USE_SKILL (effect_type = damage). Status-only and heal-only skills do NOT trigger counter-attacks. |
| Not a counter-attack | Counter-attacks do not trigger counter-counter-attacks. |

Counter-attack resolution:

- Follows the same pipeline as CR-5 steps 2-9, with the defender as attacker and vice versa.
- Counter-attack is modeled as a **second `damage_resolve()` call** with `modifiers.is_counter = true`; `damage-calc.md` applies `COUNTER_ATTACK_MODIFIER = 0.5` internally (F-DC-7). Grid Battle MUST NOT halve the damage a second time.
- Does NOT cost the defender an ACTION token.
- Suppressed by: Scout Ambush (above) OR DEFEND_STANCE on defender (above) OR any other condition in this table evaluating false.
- (v5.0 — removed) The prior clause "DEFEND_STANCE reduces incoming damage AND reduces the DEFEND_STANCE unit's counter-attack ATK by 40%" is **retired**. Under CR-13 rule 4, DEFEND_STANCE units do not counter at all; the `DEFEND_STANCE_ATK_PENALTY = 40%` constant still applies to the unit's *own* primary attacks during the stance (e.g., if the unit exits stance and attacks on its own turn). Since DEFEND_STANCE duration is 1 turn and the unit's own turn has ended when the stance was applied, this penalty is effectively decorative for the stance's own lifetime — it exists to keep the constant meaningful for any future skill that grants DEFEND_STANCE mid-turn.

**CR-6a: Archer Counter-Attack Range Rule (P0 — DC-3 resolution)**

Archers have natural attack range 2. Melee classes (Infantry, Cavalry, Scout,
Commander, Strategist in their melee mode) have natural attack range 1. When
a melee unit attacks an Archer from adjacency (range 1):

- The Archer's natural attack range is 2, **not** 1.
- Adjacency is NOT within the Archer's natural attack range.
- Therefore: **the Archer does NOT counter-attack** adjacent melee attackers.

When an Archer attacks another Archer at range 2: natural range is satisfied
for both, counter proceeds normally. When an Archer attacks a melee unit at
range 2: natural range is satisfied for the Archer's primary, but the melee
defender's natural range (1) does not reach the attacker at range 2 — no
counter. When a Cavalry attacks an Archer at range 1: Archer's natural range 2
does not include range 1 — no counter.

**Rationale (Pillar 3)**: Archers project threat at range 2 but are vulnerable
in adjacency. Closing distance is their counter-play. A melee unit that reaches
adjacency trades the turn cost to close for a safe attack window. Archers
retain dominance at range by counter-striking ranged attackers who move into
range 2.

**CR-7: Victory/Defeat Conditions**

Grid Battle evaluates conditions on every `unit_died` signal and at round end:

| Condition | Type | Trigger | Evaluation |
|-----------|------|---------|------------|
| VICTORY_ANNIHILATION | Default | `unit_died` | `all_enemies_dead()` returns true |
| DEFEAT_ANNIHILATION | Default | `unit_died` | `all_allies_dead()` returns true |
| VICTORY_COMMANDER_KILL | Scenario | `unit_died` | `died_unit.unit_id == scenario.target_commander_id` |
| DRAW | Default | `round_ended` | `current_round > ROUND_CAP (30)` |

Evaluation order on `unit_died`: VICTORY_ANNIHILATION → DEFEAT_ANNIHILATION → VICTORY_COMMANDER_KILL.

**Simultaneous last-unit deaths**: Primary + counter-attack cannot produce
simultaneous deaths — if the defender dies from the primary, CR-5 step 11
skips the counter-attack. The only simultaneous-kill path is `AOE_ALL` skills
(CR-8) iterating in array order. **VICTORY_ANNIHILATION takes priority** over
DEFEAT_ANNIHILATION on simultaneous resolution.

Scenario data specifies `victory_type`:

- `"ANNIHILATION"` (default): standard annihilation rules only.
- `"COMMANDER_KILL"`: annihilation rules + commander kill as alternate victory. Scenario must specify `target_commander_id`.

**CR-8: Skill Execution**

1. Player selects USE_SKILL from action menu → Grid Battle presents available skills (unit's 2 slots).
2. Greyed-out skills with `cooldown_remaining > 0`.
3. Player selects skill → Grid Battle queries skill data for targeting rules:
   - `target_type`: SINGLE_ENEMY, SINGLE_ALLY, SELF, AOE_ENEMY, AOE_ALLY, AOE_ALL.
   - `range`: integer (tiles).
   - `requires_los`: boolean (checked via `Map/Grid.has_line_of_sight`).
4. Grid Battle highlights valid targets/tiles.
5. Player selects target → confirm (Beat 2).
6. Resolve skill effect per `effect_type` (damage / status / heal / mixed). Damage-dealing skills route through CR-5 steps 6-10; status and heal skills bypass evasion and counter.
7. Set `cooldown_map[unit_id][skill_slot] = skill.cooldown_duration`.
8. Spend ACTION token.
9. Counter-attack eligibility: damage-dealing skills trigger CR-6; status-only and heal-only do not.

**CR-9: Cooldown Tracking**

- Data structure: `cooldown_map: Dictionary` → `{unit_id: {skill_slot_index: remaining_turns}}`.
- On skill use: `cooldown_map[unit_id][slot] = skill.cooldown_duration`.
- On each unit's turn start (CR-3 step 3): decrement all that unit's cooldowns by 1, floor at 0.
- Skill usable when: `cooldown_map[unit_id][slot] == 0`.
- Cooldowns reset between battles (non-persistent, matching HP non-persistence from HP/Status).

**CR-10: WAIT Action** *(v5.0 — reframed as Scout Ambush setup tool)*

Per Turn Order CR-5:

- WAIT forfeits both MOVE and ACTION tokens immediately.
- **`acted_this_turn` bookkeeping (v5.0 pass-9b clarification)** — the mark depends on the *origin* of the WAIT, not the signal:
  - **Volitional WAIT** (player-submitted in action menu, AI-submitted via `ai_action_ready`, OR END_TURN-batch-substituted WAIT per CR-3a): `acted_this_turn = false`. This is the Ambush-bait case.
  - **AI-failure-substituted WAIT** (CR-3 timeout, CR-3a invalid-action, CR-3b flush): `acted_this_turn = true`. This **insulates AI failure from Scout Ambush exploitation** — Ambush is a skill-expression loop against opponents that chose to pass; an AI that failed to submit a valid action is not expressing tactical choice and should not be exploitable by Ambush.
  - This distinguishes volitional WAIT from DEFEND (CR-13 rule 5, `acted_this_turn = true`) and from ATTACK/MOVE (also `true`); AI-failure WAIT shares DEFEND's Ambush-immunity without DEFEND's damage reduction or token commitment semantics.
- Unit does not appear in the initiative queue again this round.
- No animations or effects triggered.
- **Primary purpose (Pillar 3)**: Scout Ambush setup. By preserving `acted_this_turn = false` on volitional WAIT, a Scout that WAITs remains Ambush-eligible when it acts next round (subject to CR-6 adjacent-ZoC clause) AND presents itself as an Ambush-bait target that an opposing Scout can exploit. The action exists for this tactical loop. *(AI-failure WAIT does not participate in this loop by design — see bookkeeping rule above.)*
- **Action menu visibility** (UI rule — `design/ux/battle-hud.md` UI-GB-02 mirror): for Scout class units, WAIT is shown by default. For the other 5 classes (Infantry, Cavalry, Archer, Strategist, Commander), WAIT is **hidden from the action menu by default** because no mechanical advantage exists for them over END_TURN. A project-level Settings toggle `show_wait_for_all_classes` (default `false`) reveals WAIT for every class — for accessibility and for player-authored tactics beyond the default differentiation. END_TURN (CR-3a) remains available to all player units at the player-level command bar.
- Volitional WAIT and CR-3 timeout/CR-3a invalid/CR-3b flush synthetic-WAIT all emit the identical `unit_waited(unit_id)` signal — AC-GB-21 consumers treat the signal as equivalent. The `acted_this_turn` mark, however, differs per the bookkeeping rule above: volitional → `false` (Ambush-bait), AI-failure substitution → `true` (Ambush-immune). **This divergence is now formally verified (pass-11a.1)** by AC-GB-25 assertion 9 (flushed AI units + volitional WAIT scout control case) and AC-GB-16 case (c) extension (CR-3a invalid-action branch).

**CR-11: Facing Rules**

- Facing updates ONLY on movement confirmation (Beat 2), never during preview.
- Destination facing = direction of the final step in the path (axis-aligned NORTH/EAST/SOUTH/WEST only).
- If unit does not move this turn, facing remains unchanged.
- Attack does not change the attacker's facing. Counter-attacks do not change either party's facing.
- Facing is the basis for attack direction calculation (Map/Grid `get_attack_direction`).

**CR-12: Input Blocking Protocol**

Grid Battle manages Input Handling's S5 (InputBlocked) state:

| Event | Grid Battle Action | Input State |
|-------|--------------------|-------------|
| AI unit's turn begins | Emit `input_block_requested` | → S5 |
| Player unit's turn begins | Emit `input_unblock_requested` | S5 → S0 |
| Movement animation playing | Emit `input_block_requested` | → S5 |
| Movement animation complete | Emit `input_unblock_requested` | S5 → S0/S1 |
| Attack animation playing | Emit `input_block_requested` | → S5 |
| Attack animation complete | Emit `input_unblock_requested` | S5 → S0 |
| Death animation playing | Emit `input_block_requested` | → S5 |
| Death animation complete | Emit `input_unblock_requested` | S5 → S0 |
| Battle resolution screen | Emit `input_block_requested` | → S5 |

Animations are non-interruptible. Input Handling listens to Grid Battle's
signals and manages its own state transitions.

**Animation watchdog**: For every `input_block_requested` tied to an animation
event, Grid Battle resets and starts a single owned `Timer` node
(`_animation_watchdog_timer`, child of the Grid Battle scene, `one_shot = true`)
with wait_time = `ANIMATION_TIMEOUT_S` (3.0s default). **The watchdog is a
node-owned `Timer`, NOT a `SceneTreeTimer`** — this allows `.stop()` on
animation completion, preventing leaked concurrent timers when rapid animation
sequences (move → attack → death) chain within one turn. On each new animation
block, Grid Battle calls `timer.stop()` then `timer.start(max(0.01, _animation_timeout_s))` idempotently — the `max()` guard prevents tests or misconfiguration from passing 0 or negative values (which would cause the watchdog to fire immediately and flake). If
`animation_complete` arrives before timeout, the handler calls `timer.stop()`.
If the timer's `timeout` signal fires first, Grid Battle emits
`input_unblock_requested` forcibly, logs an error identifying the missing
animation, and proceeds as if the animation had completed. **Tests must be
able to inject a shorter timeout** via an `@export var animation_timeout_override_s: float = -1.0` on the Grid Battle node (`-1.0` = use default `ANIMATION_TIMEOUT_S`; any positive value overrides). Tests set the property via direct assignment after instantiation and before `_ready`. This pattern avoids Godot 4.6 `_init()` signature constraints (scene-instantiated nodes cannot accept custom constructor args via PackedScene.instantiate()) and keeps the injection surface explicit in the editor inspector so it is also usable for debug playtests.

**Leading-edge input buffering**: Between the frame a user input is received
and the frame `input_block_requested` is emitted, the user may have already
queued a tap (mobile). Input Handling drops (does not buffer) any input received
while transitioning INTO S5. Only inputs received AFTER `input_unblock_requested`
+ `INPUT_BLOCK_GRACE_PERIOD` are processed. Ownership: Input Handling owns the
grace timer; Grid Battle emits the signal but does not track the grace period.

**CR-13: DEFEND Action (v5.0 — 12-decision ratification)**

DEFEND is a player/AI-submittable action that trades the unit's offensive turn
for a defensive posture. All values live in `design/gdd/hp-status.md`
(registry: `defend_stance_reduction`, `defend_stance_atk_penalty`); this GDD
specifies only the action's orchestration contract.

**Rules**:

1. DEFEND is always valid (no range, target, or token prerequisites beyond MOVE/ACTION unspent).
2. On DEFEND:
   - Grid Battle applies `DEFEND_STANCE` status to the acting unit via HP/Status (`apply_status(unit_id, DEFEND_STANCE, 1)`). Duration: 1 turn (clears at the unit's next `unit_turn_started`).
   - Both MOVE and ACTION tokens are forfeited (same token bookkeeping as WAIT).
   - Facing is unchanged.
   - No animation is triggered beyond the 守 seal overlay (`design/ux/battle-hud.md` §2.8, UI-GB-11).
   - Grid Battle emits `unit_defended(unit_id)` then `unit_turn_ended(unit_id)`.
3. **DEFEND_STANCE damage reduction** (applied in HP/Status pipeline, not in Grid Battle):
   - Value and formula are owned by `design/gdd/hp-status.md` F-4 + SE-3 (registry `defend_stance_reduction = 50`). Grid Battle does not restate the value.
   - Applies to ALL incoming damage while the stance is active (primary attacks, damage-dealing skills). Counter-attacks do not occur against DEFEND_STANCE units (see rule 4), so the reduction is effectively primary-only.
4. **Counter-attack suppression** (the v5.0 pure-defensive commitment rule): a DEFEND_STANCE unit does NOT counter-attack. CR-6 "Not suppressed — DEFEND_STANCE" row enforces. Forecast reason localization key: `"forecast.no_counter.defend_stance"` (default KO: "반격 없음 — 방어 중"; default EN: "No counter — defending"; rendered via `tr()`; see `design/ux/battle-hud.md` §4.1 Section 3 muted reason). The prior v3.2 / v4.0-early "counter at −40% ATK, stance consumed" model is retired; `hp-status.md` EC-14 and AC-20 have been rewritten to match.
5. **`acted_this_turn` bookkeeping (v5.0 new)**: DEFEND sets `acted_this_turn = true`. This distinguishes DEFEND from WAIT (`acted_this_turn = false`, CR-10): a DEFEND-er is NOT a valid Scout Ambush target (CR-6 suppression-Ambush condition (a)), whereas a WAIT-er IS. AC-GB-21c covers this bookkeeping.
6. **Stacking**: `DEFEND_STANCE` cannot stack. A unit already in `DEFEND_STANCE` that re-declares DEFEND refreshes duration but has no further effect.
7. **Mobile input flow**: mobile DEFEND confirmation uses the two-tap same-target model identical to ATTACK (`design/ux/battle-hud.md` §5.1 + §5.3). Beat 1 = tap DEFEND in UI-GB-02 → button pulses, `TWO_TAP_TIMEOUT_S` (15s, registry) starts; Beat 2 = tap DEFEND again within the window → commit. Cancel = tap anywhere else. No long-press. No modal dialog. The v4.0 "long-press-to-confirm on touch" text and the Korean modal ("정말 방어하시겠습니까?") are retired (see EC-GB-42 v5.0 rewrite).
8. **Consecutive-turn DEFEND lockout (v5.0 pass-11b — B-9)**: A unit cannot declare DEFEND on two consecutive turns. Implementation: Grid Battle maintains a per-unit boolean `defended_last_turn` (default `false`; stored in the unit's battle-state record alongside `acted_this_turn`). When a unit completes a DEFEND action (after `unit_defended(unit_id)` emits), Grid Battle sets `defended_last_turn[unit_id] = true`. At the start of that unit's NEXT turn (`unit_turn_started` fires for this unit), Grid Battle evaluates action-menu validity FIRST — if `defended_last_turn[unit_id] == true`, DEFEND is excluded from `get_valid_actions(unit_id)` for this turn — THEN clears `defended_last_turn[unit_id] = false` unconditionally. The flag is also reset to `false` at CLEANUP.
   - **UI affordance**: when `defended_last_turn[unit_id] == true` at DECISION beat entry, the DEFEND button in UI-GB-02 renders in the greyed-out disabled state (identical visual treatment to an exhausted ACTION token). A tooltip / accessibility label uses i18n key `"action.defend.locked_consecutive"` (default EN: "Cannot defend consecutively"; default KO: "연속 방어 불가").
   - **Edge case — AI-failure-substituted WAIT on the intervening turn**: if a unit's turn between two potential DEFEND declarations is resolved by CR-3 timeout, CR-3a invalid-action, or CR-3b flush (all substitute WAIT), that flushed WAIT **clears the lockout**. Rationale: `defended_last_turn` is cleared at `unit_turn_started` unconditionally — the clear does not inspect the nature of the prior turn. Since the unit's `unit_turn_started` fires normally for the AI-failure turn, the clear runs and the lockout is lifted. This is correct: the lockout is an opportunity-cost mechanism requiring the unit to spend a turn in a non-defending posture; an AI-failure-substituted WAIT constitutes exactly that exposure. Treating it as non-clearing would impose a double-penalty (lockout retained AND already forced into Ambush-immune WAIT territory) with no design justification.
   - **Cross-reference**: AC-GB-26.

**Rationale (Pillar 3)** *(v5.0 pass-9b rewrite — frames against END_TURN,
which is visible to all classes)*: DEFEND gives defensive-leaning classes
(Infantry, Commander) a tactical identity when the board doesn't favour
attacking. The 50% reduction (hp-status `defend_stance_reduction`) + no-counter
rule + Ambush-immunity (`acted_this_turn = true`) together make DEFEND a clear
"wait out the pressure, accept no-counter trade" choice distinct from
**END_TURN's** "pass this unit, spend no commitment, take full damage if
attacked" (the visible alternative for all 6 classes via UI-GB-02's player-
level command bar — see `design/ux/battle-hud.md`) and ATTACK's "commit."
*(Secondary, programmer-facing distinction: DEFEND also differs from the
Scout-only visible WAIT action — WAIT preserves `acted_this_turn = false`
for Ambush-bait positioning whereas DEFEND sets it `true` for immunity.
This contrast is NOT a player-facing UX promise for non-Scout classes, since
`show_wait_for_all_classes = false` by default hides WAIT for 5/6 classes;
see CR-10.)*

**CR-14: TacticalRead Passive (v5.0 — Strategist-only)**

TacticalRead is a class passive granted to **Strategist only** at unit creation
(defined in `design/gdd/unit-role.md`; this GDD specifies the UI-affordance
facet of the Strategist's class-level Tactical Read passive). (v5.0 —
Commander's TacticalRead UI affordance has been removed; Commander's
distinguishing passive is **Rally** (`passive_rally`) as already specified in
`design/gdd/unit-role.md` CR-2: adjacent allied units at Manhattan distance
≤ 1 receive +5% ATK (stacks additively from multiple Commanders, cap 15%).
Commander retains no TR-related affordance post-v5.0. `EC-GB-44` dual-TR case
is deleted in v5.0.)

*(Design note — v5.0)* In `unit-role.md` CR-2, Strategist's class passive is
also called "Tactical Read" but specifies a different mechanical effect:
skills used by a Strategist ignore the target's terrain evasion bonus
(`passive_tactical_read` — terrain-evasion-ignore). Both the combat mechanic
in unit-role.md and the UI affordance specified here in CR-14 are part of
the **Strategist's single class-level Tactical Read passive** — two facets
of the same design intent ("the Strategist reads the board"): combat-layer
reading (unit-role) and UI-layer reading (this GDD). Commander shares
neither facet post-v5.0.

**Rule**: A Strategist sees the combat-forecast fields (`counter_will_fire`,
`counter_would_kill_attacker`, and the Tier 1/Tier 2 chevron — see
`design/ux/battle-hud.md` §4.4) computed **from `tactical_read_extension_tiles`
grid tiles further out** than the unit's natural attack range (registry:
`tactical_read_extension_tiles = 1`). That is, the forecast is available for
targets the Strategist cannot currently attack but could attack after a 1-tile
movement.

**Visual affordance (v5.0 — new)**: `design/ux/battle-hud.md` UI-GB-12
"TacticalRead Extended Range" renders TR-extended tiles as the natural attack-
range overlay at 70% opacity (vs. 25% for natural range) with a 讀 (read)
micro-glyph 8px upper-left on each extended tile. Hovering a TR-extended
target shows the forecast panel with a `[TR]` chip adjacent to the direction
badge (§4.1 Section 5). The player must be able to tell which forecasts are
TR-sourced; natural-range forecasts have no chip.

**Purpose (Pillar 3)**: Strategist is the information-oriented class.
TacticalRead makes "read the board before you commit" into its mechanical
identity — the Strategist scouts counter-risk one tile ahead and plans
movements with counter-kill visibility other classes lack. This is the
Strategist's **distinguishing UI affordance** (vs. Commander's Rally combat mechanic; see unit-role.md CR-2 for Rally's +5% ATK / +10% cap values — rev 2.8).

**Mechanical scope**:

- TacticalRead is a **UI / AI-information affordance**, not a damage modifier. It does not alter damage, hit chance, counter conditions, attack range, or turn order.
- AI `get_battle_state_snapshot()` respects TacticalRead for Strategist AI units: their snapshots include a `tactical_read_forecasts` array with counter-forecast entries for one-grid-extended targets.
- Non-Strategist units see only forecast for natural-range targets.

**Forbidden use**: TacticalRead MUST NOT bypass Scout Ambush suppression,
extend attack range (EC-GB-43 still applies — post-move the target must be in
natural range to ATTACK), reveal hidden units, or modify damage calculation.
Any such effect belongs in a different passive.

**CR-15: Rally Aura — Commander Orchestration (v5.0 pass-11b — B-10)**

Rally is the Commander's defining class passive (`passive_rally`, declared in `design/gdd/unit-role.md` CR-2). This CR specifies the Grid Battle orchestration contract: when and how Rally ATK bonuses are computed, applied, and surfaced. unit-role.md CR-2 owns the passive tag and the base effect sentence; this CR owns the full mechanical specification.

**Rules**:

1. **Trigger and scope**: Rally is passive and always-on while a Commander unit is alive and present on the grid. It requires no action, no cost, and no activation. The bonus is re-evaluated at the start of each unit turn (see rule 3 timing) — it is not cached from round-start.
2. **Range**: Affects allied units at Manhattan distance ≤ 1 from the Commander (4-orthogonal adjacency: NORTH, EAST, SOUTH, WEST only; diagonal tiles do NOT contribute). A Commander does not Rally itself.
3. **Timing (v5.0 pass-11c — systems-designer B-1/B-2 correction)**: Grid Battle QUERIES `get_rally_bonus(attacker_id) → float` at CR-5 step 4 ("Check class passives that modify the attack") as a pre-resolve read — step 4 is a Grid Battle pre-query step, not the damage composition site. The returned float (0.0 to 0.15) is PASSED into `damage_resolve()` as an input modifier; `P_mult` then incorporates it INSIDE `damage-calc.md` F-DC-5 (`passive_multiplier`), which is called during CR-5 step 7 ("Invoke `damage_resolve()`"). The final application to `stage_2_raw_damage` happens in F-DC-6. *(See `design/gdd/damage-calc.md` F-DC-5 for `P_mult` assembly and F-DC-6 for `stage_2_raw_damage` application; F-DC-5 must be updated to accept `rally_bonus` as an input factor alongside CHARGE_BONUS and AMBUSH_BONUS. Integer pipeline: `floor()` applied at `resolved_damage` output per F-DC-6, not at each bonus accumulation step.)*
4. **Stacking (rev 2.8 — damage-calc Rally-ceiling fix)**: Multiple Commanders each contribute +5% per Commander adjacent to the AFFECTED unit (not relative to each other). The contributions are summed additively, then capped at **+10% total** regardless of how many Commanders are adjacent. Formula: `rally_bonus = min(0.10, N_adjacent_alive_commanders × 0.05)` where `N_adjacent_alive_commanders` is the count of alive Commander units within Manhattan distance ≤ 1 of the affected unit. **Two** Commanders adjacent = 10% (cap). Three+ Commanders = still 10%. A Commander at distance 2 does not contribute even if adjacent to another Commander. (Mirrors `design/gdd/unit-role.md` EC-12. Cap reduced from prior +15% per damage-calc.md eighth-pass review BLK-8-1: at +15% Rally, Cavalry REAR+Charge max ATK = `floori(83 × 1.64 × 1.38) = 187` → DAMAGE_CEILING fires, collapsing Pillar-1+3 hierarchies; +10% cap keeps `floori(83 × 1.64 × 1.32) = 179` under the ceiling.)
5. **Interaction with DEFEND_STANCE**: Rally ATK bonus is applied in CR-5 step 4 as part of the attacker's `P_mult`. DEFEND_STANCE damage reduction (`defend_stance_reduction = 50%`) is applied later in the HP/Status intake pipeline (hp-status.md F-4, CR-5 step 8). Rally therefore applies **before** DEFEND_STANCE reduction — Rally makes the incoming hit bigger before DEFEND halves it. This ordering is intentional: Rally is an offensive aura that rewards keeping a Commander near attacking units; it does not interact with whether the *defender* is in DEFEND_STANCE.
6. **Commander death**: When a Commander unit dies (`unit_died` fires), Grid Battle immediately recomputes `get_rally_bonus` for all allied units previously adjacent to that Commander. The bonus drops to zero for units that no longer have any adjacent Commander. No animation or special signal is emitted for the bonus change itself — the passive absence is implicit. The forecast panel (UI-GB-04) will reflect the updated lower ATK on the next hover.
7. **AI awareness**: AI `get_battle_state_snapshot()` includes the per-unit `rally_bonus_active: float` field (0.0 to 0.10 — rev 2.8 cap reduction) reflecting the current Rally contribution to that unit's effective ATK. AI positioning logic may consider Commander proximity as a formation incentive.
8. **UI affordance**: `design/ux/battle-hud.md` UI-GB-13 specifies the aura visual and forecast tooltip line. Grid Battle emits no dedicated Rally signal — the UI derives Rally state from the battle-state snapshot or from the forecast data path. AC-GB-27 covers this.

**Purpose (Pillar 3)**: Commander is the force-multiplier class. Rally makes the Commander a high-value assassination target — killing the Commander collapses the formation's damage output, creating a tactical imperative to protect or eliminate it. The **2-Commander cap (10% — rev 2.8)** prevents absurd stacking in hypothetical many-Commander compositions while preserving the incentive for intelligent Commander positioning. (Cap reduced from +15% per damage-calc rev 2.8 ceiling-collision fix.)

### States and Transitions

**Battle State Machine** (top-level, distinct from Turn Order's queue lifecycle
and Input's S0-S6):

```
┌─────────────────┐
│  BATTLE_LOADING  │
│  Load map, place │
│  units, init     │
└────────┬────────┘
         │ load complete
         v
┌─────────────────┐
│   DEPLOYMENT     │
│  (MVP: trivial — │
│   scripted only) │
└────────┬────────┘
         │ deployment complete
         v
┌─────────────────────────────────────────┐
│           COMBAT_ACTIVE                  │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │ Substates (per unit turn):       │   │
│  │                                  │   │
│  │  PLAYER_TURN_ACTIVE              │   │
│  │    Input live (S0-S4)            │   │
│  │    Player selects actions        │   │
│  │                                  │   │
│  │  AI_WAITING                      │   │
│  │    Input blocked (S5)            │   │
│  │    Signals filtered: only        │   │
│  │    ai_action_ready, timeout,     │   │
│  │    battle_ended                  │   │
│  │      ↓ (signal OR timeout)       │   │
│  │  AI_TURN_ACTIVE                  │   │
│  │    Input blocked (S5)            │   │
│  │    Action validated + executed   │   │
│  └──────────────────────────────────┘   │
│                                          │
│  Turn Order lifecycle (R1-R4, T1-T7,     │
│  RE1-RE3) runs inside this state         │
└────────┬────────────────────────────────┘
         │ battle_ended signal
         v
┌─────────────────┐
│   RESOLUTION     │
│  Determine WIN/  │
│  LOSE/DRAW,      │
│  show results    │
└────────┬────────┘
         │ result screen dismissed
         v
┌─────────────────┐
│    CLEANUP       │
│  Release map,    │
│  clear units,    │
│  emit complete   │
└─────────────────┘
```

**State Definitions:**

| State | Entry Condition | Actions | Exit Condition |
|-------|----------------|---------|----------------|
| BATTLE_LOADING | Scene transition with scenario data | CR-1 steps 1-11 | `battle_initialized` emitted |
| DEPLOYMENT | `battle_initialized` | CR-2 (MVP: camera pan, no interaction) | Deployment animation complete |
| COMBAT_ACTIVE | Deployment complete | Drive Turn Order, process turns (CR-3) | `battle_ended` from Turn Order |
| → PLAYER_TURN_ACTIVE | `unit_turn_started(player_unit)` | Release input, accept player commands | Player ends turn or all tokens spent |
| → AI_WAITING | `unit_turn_started(ai_unit)` | Block input, connect `ai_action_ready` one-shot, emit `ai_action_requested`, start owned Timer. Drop all signals except `ai_action_ready`, timer `timeout`, `battle_ended`. | `ai_action_ready` received OR timer `timeout` fires OR `battle_ended` received |
| → AI_TURN_ACTIVE | `ai_action_ready(unit_id, action_command)` received, OR timeout → WAIT substitution | Validate action (CR-3a), execute action pipeline | Action resolution complete, `unit_turn_ended` emitted |
| RESOLUTION | `battle_ended(result)` | Determine outcome (CR-7), calculate rewards, display result screen | Player dismisses result |
| CLEANUP | Result dismissed | Release map resources, clear unit instances, reset `cooldown_map`, reset `ai_soft_lock_counter = 0`, reset `movement_budget_map`, reset `defended_last_turn` (v5.0 pass-11c — godot B-2; `Dictionary[int, bool]` keyed by unit_id, consistent with `movement_budget_map` and `acted_this_turn`; clearing prevents cross-battle lockout-state leak when Grid Battle node is reused rather than freed) | Emit `battle_complete(outcome)` to caller |

**Invalid Transitions**:

- COMBAT_ACTIVE → BATTLE_LOADING (no restart mid-battle; restart = new battle).
- RESOLUTION → COMBAT_ACTIVE (battle cannot resume after ending).
- CLEANUP → any state (terminal — caller scene takes over).
- PLAYER_TURN_ACTIVE ↔ AI_WAITING (substates do not cross — next substate is entered via `unit_turn_started` after `unit_turn_ended` resolves).

**Implementation prescription**: The state machine is a hand-rolled
`enum BattleState` with a top-level `match` block in `_process` or
`_physics_process`, plus a separate enum `TurnSubstate` for COMBAT_ACTIVE's
three substates. **Do NOT use `AnimationTree` StateMachine for game logic** —
that node is intended for animation blending only.

### Interactions with Other Systems

**Upstream Dependencies (Grid Battle consumes):**

| System | Data Flow IN | Grid Battle's Obligation |
|--------|-------------|--------------------------|
| **Map/Grid** | Tile data, pathfinding results, attack direction, LoS, adjacency queries | State changes ONLY through explicit calls: `move_unit()`, `remove_unit()`, `place_unit()`. Never modify grid state directly. |
| **Terrain Effect** | Defense/evasion bonuses, elevation modifiers, terrain scores (AI) | Always query per-attack, never cache modifiers. Pass correct defender tile coordinates. |
| **Unit Roles** | Class stats (ATK, DEF, HP, initiative, move_range), passives (including TacticalRead ownership, see CR-14), direction multipliers, terrain cost tables, skill slot data | Read-only. Apply passives in correct pipeline order (CR-5). |
| **HP/Status** | Current HP, status effect state, damage intake pipeline (including DEFEND_STANCE reduction per CR-13), healing pipeline, death/alive state | Route ALL damage through HP/Status intake pipeline. Never subtract HP directly. Listen to `unit_died` signal for victory/defeat evaluation. |
| **Turn Order** | Initiative queue, turn signals, action token state | Honor all binding contracts (Turn Order Contract 4). Check `has_move_token()` / `has_action_token()` before allowing actions. Call `spend_move_token()` / `spend_action_token()` after confirmed actions. |
| **Input Handling** | Player action commands, state machine management (S5 blocking), two-beat confirmation flow, undo support | Provide validation callbacks: `is_tile_in_move_range(tile)`, `is_tile_in_attack_range(tile, unit)`. Manage S5 state via `input_block_requested` / `input_unblock_requested` signals. |
| **Battle HUD spec** (`design/ux/battle-hud.md`) | Forecast contract, visual/audio event list, chevron tiers, DEFEND_STANCE badge | Emit the UI events this spec consumes: `attack_target_hovered`, `status_applied`, `unit_died`, `hp_changed`. |

**Downstream Dependents (Grid Battle provides):**

| System | Data Flow OUT | Interface |
|--------|-------------|-----------|
| **Damage/Combat Calc** (not yet designed) | Attacker stats, defender stats, modifiers, direction multiplier → receives `resolved_damage` | Grid Battle calls damage calc with full context; receives a single damage number |
| **AI System** (not yet designed) | Current battle state (all unit positions, HP, status, terrain, turn order, TacticalRead forecasts for qualifying units) → receives AI decision (action type, target) | Grid Battle exposes read-only battle state snapshot; AI returns a structured action command |
| **Battle UI implementation** (not yet designed) | Battle state updates → consumes the contract defined in `design/ux/battle-hud.md` | Grid Battle emits UI update signals per CR-12 and the UX spec |
| **Animation System** (not yet designed) | Animation triggers (move, attack, skill, death, status apply) → receives `animation_complete` callback | Grid Battle triggers animation, blocks input (S5), resumes on completion |
| **Skill System** (not yet designed) | Skill execution requests → receives skill effect data | Grid Battle calls skill resolution; applies results through appropriate pipeline |
| **Formation Bonus** (not yet designed) | Unit positions snapshot → receives formation bonuses (stat modifiers) | Grid Battle queries on `round_started`; applies bonuses as temporary stat modifiers |
| **Battle Reward** (not yet designed) | Battle outcome, units participated, scenario data → receives nothing | Grid Battle emits `battle_complete(outcome_data)` on CLEANUP |
| **Scenario Progression** (`design/gdd/scenario-progression.md` — Approved pending review) | `battle_complete(outcome_data)` → receives battle payload (`map_id`, `unit_roster[]`, `deployment_positions{}`, `victory_conditions{}`, optional `battle_start_effects[]`) at BATTLE_LOADING | Grid Battle is instantiated by Scenario Progression with the battle payload; reports back via `battle_complete(outcome_data)` relayed through GameBus autoload (see Scenario Progression OQ-SP-01). |

## Formulas

Grid Battle owns a limited set of formulas — most combat math is delegated to
upstream systems (Unit Roles for stats, Terrain Effect for modifiers, HP/Status
for damage intake). The formulas below are what Grid Battle itself resolves.

### F-GB-1: Movement Budget Accumulation

```
movement_budget_accumulated = Σ terrain_cost(tile) for each tile in confirmed_path
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| terrain_cost(tile) | int | 3–60 (effective, post-multiplier; pass-11a correction) | Per-tile movement cost from Map/Grid. Base costs: ROAD=7, PLAINS=10, BRIDGE=10, FOREST=15, HILLS=15, MOUNTAIN=20. Effective cost = `floor(base_cost × class_multiplier)` where class_multiplier from Unit Role CR-4 is a float in range [0.5, 3.0]. The `floor()` guarantees integer output. Minimum reachable is `floor(7 × 0.5) = 3` (ROAD × Cavalry multiplier); maximum is `floor(20 × 3.0) = 60` (MOUNTAIN × slowest class). |
| movement_budget_accumulated | int | 0–unbounded | Running total for this unit this turn |

Cavalry Charge activates when `movement_budget_accumulated >= CHARGE_THRESHOLD
(40)`. The comparison is **inclusive**. Threshold is owned by Turn Order;
accumulation logic is owned by Grid Battle. Reset to 0 at start of each unit's
turn.

### F-GB-2: Evasion Check (2RN Hit-Semantics)

**Godot 4.6 API note** (P0 — was `random_int` in v3.2): Godot 4.6's random
integer API is `RandomNumberGenerator.randi_range(from, to)`. `random_int` is
not a Godot 4.6 function. Tests seed an owned `RandomNumberGenerator` instance
for determinism (global `seed()` is unreliable across parallel tests).

```gdscript
# Pseudocode (GDScript)
var rng := RandomNumberGenerator.new()
rng.seed = FIXED_SEED  # tests only
var r1: int = rng.randi_range(0, 99)
var r2: int = rng.randi_range(0, 99)
var roll: int = floori((r1 + r2) / 2.0)  # integer-floor average
# Defensive clamp — Terrain Effect caps evasion_bonus upstream, but tests
# feed raw inputs; re-clamp here guarantees hit_chance ≥ 70 (100 − MAX_EVASION).
evasion_bonus = clampi(evasion_bonus, 0, MAX_EVASION)
var hit_chance: int = 100 - evasion_bonus
var hit: bool = (roll < hit_chance)
var miss: bool = not hit
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| r1, r2 | int | 0–99 | Two independent uniform random integers from `randi_range(0, 99)`. Must be seeded for tests. |
| roll | int | 0–99 | Average of two rolls (Fire Emblem 2RN pattern). Distribution is triangular, concentrated around 49.5. |
| evasion_bonus | int | 0–30 | Terrain evasion from Terrain Effect `get_combat_modifiers()`, capped at MAX_EVASION=30. |
| hit_chance | int | 70–100 | Derived as `100 - evasion_bonus`. Displayed to player per UI-GB-04 as the actual hit %. |
| hit | bool | true/false | If true, attack proceeds through CR-5 steps 7-10. If false, miss branch fires. |
| miss | bool | true/false | Derived as `not hit`. |

**Why hit-semantics, not miss-semantics**: Fire Emblem's 2RN is applied to the
displayed *hit chance*, not to evasion. Applied to hit-chance, the triangular
distribution makes high hit percentages feel more reliable than pure uniform
(70% hit behaves like ~82% in practice) while leaving low hit percentages
roughly as displayed.

### F-GB-PROV: RETIRED (v5.0)

`F-GB-PROV` has been **deleted**. `damage_resolve()` in
`design/gdd/damage-calc.md` (registry formula `damage_resolve`) is the sole
damage-resolution primitive. Grid Battle is a consumer only.

Values previously restated here — `BASE_CEILING`, `DAMAGE_CEILING`,
`COUNTER_ATTACK_MODIFIER`, class `D_mult` tables, quantization contract,
IEEE 754 hazard protocol — now live in `damage-calc.md` §D (registry:
`base_ceiling = 83`, `damage_ceiling = 180`, `counter_attack_modifier = 0.5`).
The prior worked-example table in this document is superseded by
`damage-calc.md` §D worked examples (AC-DC-02..AC-DC-16) which reflect the
corrected `BASE_CEILING = 83` and `DAMAGE_CEILING = 180` values. If a value
in this document disagrees with the registry or with `damage-calc.md`, the
registry wins (drafting rule: *no value without registry source cite*).

Counter-attack damage is emitted by a second `damage_resolve()` call with
`modifiers.is_counter = true`; `damage-calc.md` F-DC-7 applies
`COUNTER_ATTACK_MODIFIER = 0.5` internally. Grid Battle MUST NOT apply it a
second time. DEFEND_STANCE handling lives in `hp-status.md` F-4 (applied at
the `apply_damage` boundary, not in Grid Battle or Damage Calc). Under CR-13
rule 4 (v5.0), a DEFEND_STANCE defender does not counter-attack at all — the
attacker-side DEFEND_STANCE counter branch from prior drafts is therefore
unreachable and has been removed from F-GB-3 (below).

### F-GB-3: Counter-Kill Forecast (UI contract — v5.0 rewrite)

This formula is consumed by `design/ux/battle-hud.md` §4.2 for the two-tier
chevron. It is defined here because the mechanics live in Grid Battle (the
forecast reflects a would-be CR-6 counter that has not yet fired).

```gdscript
# Use MAX-ROLL of the 2RN distribution to avoid under-warning at low HP.
# Max-roll = defender's evasion roll resolves to HIT (min possible
# evasion-based mitigation), AND damage_resolve's internal RNG is pinned to
# the favorable-to-defender extreme per damage-calc.md D-max-roll contract.
var hit_result := damage_calc.resolve(
    # Counter-attack: defender becomes attacker, original attacker becomes defender.
    attacker = defender.as_attacker(counter_context),
    defender = original_attacker.as_defender(),
    modifiers = {
        attack_type  = defender.primary_attack_type,
        direction_rel = reverse(primary_direction_rel),
        is_counter   = true,      # damage-calc applies COUNTER_ATTACK_MODIFIER=0.5 internally
        skill_id     = "",        # counters are plain attacks, never skill-sourced
        rng          = pinned_worst_case_rng,  # pass-11a rename (was `pinned_max_roll_rng` — shared name with primary-path was a copy-paste trap). Counter-path contract: RNG pinned so the defender's evasion roll resolves to HIT AND damage_resolve's internal quantization favours the defender (i.e., this produces the worst-case counter damage against the original attacker, per §"Why max-roll" below). Primary-attack forecast call sites instantiate a separate `pinned_best_case_rng` with the ATTACKER-favourable extreme (best-case damage dealt). Callers MUST instantiate the two pinnings separately — they are explicitly distinct symbols post-pass-11a to prevent silent copy-paste bugs.
    },
)

var counter_max: int = hit_result.resolved_damage if hit_result is ResolveResult.HIT else 0

var counter_will_fire: bool = all CR-6 conditions satisfied AND hit_chance > 0 AND NOT defender.has_status(DEFEND_STANCE)
var counter_would_kill_attacker: bool = counter_will_fire AND (original_attacker.current_hp - counter_max <= 0)
```

**Why max-roll, not expected value**: Using the expected value under-predicts
counter-kills in roughly 8% of marginal cases. Under-warning is a Pillar 1
violation; over-warning is tolerable.

**Why `defender.has_status(DEFEND_STANCE)` in `counter_will_fire`**: CR-13
rule 4 (v5.0) suppresses counters from DEFEND_STANCE defenders. The
`counter_will_fire` predicate must respect this or the forecast chevron will
show a counter that cannot fire, violating the Pillar 1 never-surprised
contract in the opposite direction (over-warning on a safe play).

## Edge Cases

### Category 1 — Simultaneous Death

**EC-GB-01** | Counter-attack mutual kill: Primary reduces defender to 0; counter then reduces original attacker to 0. Resolution: deaths process in sequence — defender dies first (CR-5 step 9), victory check runs; if no victory, original attacker dies from counter, second victory check may resolve DEFEAT. **CR: 5, 6, 7**

**EC-GB-02** | Both sides' last units die in same resolution pass (only reachable via `AOE_ALL` — primary + counter cannot produce this per CR-5 step 11). Per-target `unit_died` signals fire in array iteration order. Per CR-7 evaluation order, the first condition to resolve wins. VICTORY_ANNIHILATION takes priority. **CR: 7, 8**

**EC-GB-03** | AoE skill kills last units of both factions in same pass. Iterate in array order; evaluate after each death. Outcome deterministic given array ordering. **CR: 5, 7, 8**

**EC-GB-04** | DoT (poison) kills two units on the same turn start. Process DoT in Turn Order queue sequence; evaluate victory after each death. **CR: 3, 7**

### Category 2 — Movement

**EC-GB-05** | Unit's effective move range = 0 (terrain costs exceed budget for all adjacent tiles). Resolution: `get_movement_range()` returns empty. No blue highlight. MOVE token still exists. **CR: 4**

**EC-GB-06** | Destination tile occupied. Rejected pre-validation; occupied tiles excluded from reachable set. **CR: 4**

**EC-GB-07** | Path requires passing through occupied tile. `get_path()` treats occupied as impassable. Route around or destination unreachable. **CR: 4**

**EC-GB-08** | Movement after MOVE token spent. `has_move_token()` false → MOVE option absent from action menu. **CR: 4**

**EC-GB-09** | Player undoes movement; no interleaved effects apply mid-input (undo is safe during PLAYER_TURN_ACTIVE before ACTION token spent). **CR: 4**

**EC-GB-10** | Movement cost exactly equals CHARGE_THRESHOLD (40). `>= 40` is inclusive — Charge activates. **CR: 4, F-GB-1**

**EC-GB-11** | Cavalry Charge active from prior sub-path, then cancels and re-selects shorter path. Budget accumulates only on confirmed movement; undo reverts to pre-move value. **CR: 4**

### Category 3 — Attack

**EC-GB-12** | No valid attack targets. Highlights zero tiles. Action menu remains visible. **CR: 5**

**EC-GB-13** | Target dies between selection and confirm. Cannot occur — no unit acts during player input window. **CR: 5**

**EC-GB-14** | Evasion succeeds (miss). CR-5 steps 7-10 skipped. No HP change, no counter. ACTION token still spent. **CR: 5, F-GB-2**

**EC-GB-15** | Computed raw_damage negative before floor. `damage_resolve()` F-DC-3 enforces `max(MIN_DAMAGE, floor(...))` internally (guarantees ≥ 1). HP/Status pipeline enforces MIN_DAMAGE again at the `apply_damage` boundary — dual enforcement per registry `min_damage` notes. **CR: 5**

**EC-GB-16** | Counter-attack 0 damage after 0.5 multiplier. `counter_damage = max(1, floor(raw_damage × 0.5))`. MIN_DAMAGE=1 applies. **CR: 6**

**EC-GB-17** | DEFEND_STANCE unit is the counter-attacker. Under CR-13, a DEFEND_STANCE unit does NOT counter-attack at all. Counter-eligibility is suppressed by CR-13 rule 4. **CR: 6, 13**

**EC-GB-18** | Scout Ambush suppresses counter, but target has already acted (`acted_this_turn = true`). Ambush requires `acted_this_turn = false` AND round ≥ 2 AND no enemy adjacent to Scout — if any fails, Ambush is not active. **CR: 6**

**EC-GB-19** | USE_SKILL counter eligibility. Damage-dealing skills trigger counter; status-only and heal-only do not. **CR: 5, 6, 8**

**EC-GB-39 (new for CR-6a)** | Melee unit attacks Archer from adjacency. Primary attack resolves normally. Archer does NOT counter-attack (adjacency is not within Archer's natural range of 2). Forecast shows "No counter — Archer out of natural range". **CR: 5, 6, 6a**

### Category 4 — Victory Condition Conflicts

**EC-GB-20** | VICTORY_ANNIHILATION + VICTORY_COMMANDER_KILL trigger same event. Evaluation order resolves VICTORY_ANNIHILATION first; result VICTORY regardless. **CR: 7**

**EC-GB-21** | VICTORY_COMMANDER_KILL triggers with other enemies alive. Surviving enemies removed during CLEANUP. **CR: 7**

**EC-GB-22** | DEFEAT_ANNIHILATION + VICTORY_COMMANDER_KILL simultaneous. Commander dies first → VICTORY fires; counter-attack gated by commander surviving (false) → ally does not die. DEFEAT never evaluates. **CR: 5, 6, 7**

**EC-GB-23** | Round 30 ends + victory condition triggers same round. `unit_died` evaluates mid-turn; DRAW evaluates at `round_ended`. If victory resolves, `battle_ended` fires first. **CR: 7**

### Category 5 — Skill Edge Cases

**EC-GB-24** | USE_SKILL but cooldown > 0. Skill greyed, not selectable. **CR: 8, 9**

**EC-GB-25** | AOE_ENEMY hits tile with ally. Target_type filters to enemy faction only. Allies not hit. **CR: 8**

**EC-GB-26** | AOE_ALL hits both factions. By design. Process each in array order; victory evaluated after each. **CR: 8**

**EC-GB-27** | Skill requires LoS but all in-range targets blocked. Valid target set empty. USE_SKILL cannot proceed. **CR: 8**

**EC-GB-28** | Skill used, unit dies same turn. Cooldown_map never decremented further; cleared at CLEANUP. **CR: 8, 9**

**EC-GB-29** | Skill first, then MOVE second (free action order per CR-3). Tokens independent. **CR: 3, 8**

### Category 6 — Status Effect Interactions

**EC-GB-30** | 3 active statuses; 4th received. HP/Status evicts oldest. Grid Battle routes the application. **CR: 8**

**EC-GB-31** | Commander with morale_anchor dies mid-AoE. DEMORALIZED applies immediately on signal; any ally in-flight may receive it as 4th status — oldest evicted. **CR: 5, 8**

**EC-GB-32** | EXHAUSTED unit healed (halved). HP/Status handles internally. **CR: 8**

**EC-GB-33** | DEMORALIZED unit WAITs. WAIT forfeits tokens; DEMORALIZED affects ATK only, not action availability. **CR: 10**

**EC-GB-40 (new for CR-13)** | Unit in DEFEND_STANCE receives 4th status effect. DEFEND_STANCE is just another status slot — subject to 3-slot limit with oldest eviction. If DEFEND_STANCE is the oldest, it can be evicted by incoming status; the stance ends. Design consequence: stacking statuses on a defender can break their defensive commitment — this is a player-reading-the-board tactic. **CR: 8, 13**

### Category 7 — Round Cap and Ongoing Effects

**EC-GB-34** | DoT active when round 30 ends → DRAW. DRAW evaluated at `round_ended`; round 31 never begins. **CR: 7**

**EC-GB-35** | Cooldown > 0 on DRAW/DEFEAT. Cooldown_map cleared at CLEANUP. **CR: 9**

### Category 7b — Scout Ambush and WAIT Interactions

**EC-GB-37** | Scout WAITs for Ambush eligibility; enemy moves adjacent. On Scout's next turn, adjacent-ZoC suppresses Ambush regardless of unacted status. Counter-attacks against Scout proceed normally. **CR: 6, 10**

**EC-GB-38** | Scout has Ambush eligibility AND no enemy adjacent. All three conditions satisfied — Ambush fires, suppresses target's counter. Scout loses unacted after the attack. **CR: 6**

### Category 8 — Deployment

**EC-GB-36** | Scenario specifies more units than deployment tiles. Log error, place only units with assigned positions, exclude excess from Turn Order. Scenario authoring error. **CR: 1, 2**

### Category 9 — v4.0 / v5.0 (DEFEND, TacticalRead)

**EC-GB-41** | Unit DEFENDs, then is attacked. Per CR-13 rule 4, the DEFEND_STANCE unit does NOT counter. Incoming damage is reduced per `hp-status.md` F-4 using `defend_stance_reduction = 50`. Scout Ambush is also not a valid suppression trigger against the DEFEND-er: per CR-13 rule 5 (v5.0), DEFEND sets `acted_this_turn = true`, failing Ambush condition (a). **CR: 6, 13**

**EC-GB-42 (v5.0 rewrite)** | Player commits DEFEND during PLAYER_TURN_ACTIVE. DEFEND is irreversible once confirmed — no undo. Confirmation uses the **two-tap same-target model** (identical to ATTACK; see `design/ux/battle-hud.md` §5.1 + §5.3): Beat 1 = tap DEFEND in UI-GB-02 → the DEFEND button pulses and `TWO_TAP_TIMEOUT_S = 15s` (registry) starts; Beat 2 = tap DEFEND again within the window → commit. Cancel = tap anywhere else. On timeout, return to S1 with no commitment. PC: hover DEFEND button (Beat 1), click (Beat 2). **No long-press, no modal dialog** — the v4.0 "long-press-to-confirm on touch" and the Korean modal ("정말 방어하시겠습니까?") are both retired; the two-tap pattern reuses the attack-confirm vocabulary and respects `battle-hud.md` §1 rule 3 ("no long-press for primary actions"). **CR: 13, UI**

**EC-GB-43 (v5.0)** | Strategist with TacticalRead moves, then attempts to attack a target that was in TR-extended range at move-start but is now out of natural range after moving. TacticalRead is a forecast affordance only; attack range is the unit's natural range from current position. Post-move, the target is not in natural range → ATTACK is not available. **CR: 14**

*EC-GB-44 — DELETED in v5.0.* The dual-TR case (Strategist + Commander, each extending forecast by 1 from their own position) is no longer reachable because Commander's TR UI affordance has been removed in v5.0; Commander's passive is Rally (`passive_rally`) per `design/gdd/unit-role.md` CR-2. Only Strategist has the TR UI affordance (CR-14) in v5.0.

## Dependencies

### Upstream (Grid Battle depends on — must exist first)

| System | GDD Status | Dependency Type | Key Interface |
|--------|-----------|-----------------|---------------|
| Map/Grid System | Designed | Structural | Grid queries, state mutations |
| Terrain Effect System | Designed | Input/Output | Combat modifier queries |
| Unit Role System | Designed | Input/Output | Class stats, passives (Strategist `passive_tactical_read` — both terrain-evasion-ignore combat mechanic per unit-role.md CR-2 AND UI forecast-extension affordance per this GDD CR-14 v5.0; Commander `passive_rally` — +5% ATK adjacent, cap 15%), direction multipliers, `tactical_read_extension_tiles` registry constant (UI facet only) |
| HP/Status System | Designed | Input/Output | Damage intake, DEFEND_STANCE reduction pipeline (registry `defend_stance_reduction = 50` owned here — v5.0), status application, death detection, DEMORALIZED propagation |
| Damage Calc System | Designed — `design/gdd/damage-calc.md` (rev 2.5) | Input/Output | `damage_resolve(attacker, defender, modifiers) -> ResolveResult` — sole damage-resolution primitive since v5.0 F-GB-PROV retirement. Owns `BASE_CEILING`, `DAMAGE_CEILING`, `COUNTER_ATTACK_MODIFIER`, `CHARGE_BONUS`, `AMBUSH_BONUS`, class `D_mult` table. |
| Turn Order System | Designed | Structural | Initiative queue, turn signals, action tokens |
| Input Handling System | Designed | Input/Output | Player action commands, S5 blocking, two-beat flow, undo, DEFEND two-tap confirm (v5.0) |
| Settings UX spec | `design/ux/settings.md` — NOT YET AUTHORED (provisional) | Input | `show_wait_for_all_classes` toggle (registry-backed key `settings.show_wait_for_all_classes`, default `false`; surfaced under Player Settings → Accessibility → "Always show WAIT action"). Grid Battle CR-10 menu visibility is gated on this toggle for non-Scout classes. |
| Battle HUD UX spec | `design/ux/battle-hud.md` (v1.1, v5.0 refactor — strict UI-only) | Output/Contract | UI-GB-01..13 contract (UI-GB-12 TacticalRead Extended Range added v5.0; UI-GB-13 Rally Aura Visual added pass-11b), forecast contract, chevron tier formulas, mobile DEFEND two-tap flow. **Downstream obligation (pass-11a.1 — game-designer R-6)**: battle-hud.md forecast contract must surface the "why Ambush fired" reason when Ambush suppresses a counter — since `show_wait_for_all_classes = false` hides WAIT from 5/6 classes, players cannot observe the `acted_this_turn = false` state that gates Ambush. Without an in-forecast reason, Ambush reads as random for most players. Addressed in battle-hud.md UI-GB-04 §4.1 Section 3 (pass-11b). **Downstream obligation (pass-11b — game-designer B-10)**: battle-hud.md must specify the Rally aura visual and the forecast tooltip line "Rally +X% ATK from adjacent Cmdr" per CR-15. Specified in UI-GB-13 (battle-hud.md — pass-11b). |

### Downstream (depend on Grid Battle — designed after)

| System | GDD Status | Dependency Type | What Grid Battle Must Provide |
|--------|-----------|-----------------|-------------------------------|
| AI System | Not Started | Input/Output | Read-only battle state snapshot with TacticalRead forecasts (Strategist-only v5.0) → receives AI action command |
| Battle UI implementation | Not Started | Output | Consumes `design/ux/battle-hud.md` contract |
| Animation System | Not Started | Input/Output | Animation triggers → animation_complete callbacks |
| Skill System | Not Started | Input/Output | Skill execution → skill effect data |
| Formation Bonus | Not Started | Input/Output | Unit positions → stat modifier bonuses |
| Battle Reward | Not Started | Output | `battle_complete(outcome_data)` signal |
| Scenario Progression | Approved (pending /design-review) — `design/gdd/scenario-progression.md` | Input/Output | Battle payload (`map_id`, `unit_roster[]`, `deployment_positions{}`, `victory_conditions{}`, optional `battle_start_effects[]`) → `battle_complete(outcome_data)` signal relayed via GameBus autoload **at CLEANUP state only**. Grid Battle makes NO GameBus connections during BATTLE state — the autoload is wired exclusively when the state machine reaches CLEANUP. AC-GB-25 asserts this contract with a negative connection check at test start. |

### Provisional Contracts

- **Damage Calc**: *(v5.0 — no longer provisional)* `damage-calc.md` is
  **Designed** (rev 2.5). Grid Battle consumes `damage_resolve(attacker,
  defender, modifiers) -> ResolveResult` directly. F-GB-PROV is deleted.

- **AI System**: Grid Battle invokes AI via `ai_action_requested(unit_id, snapshot)` signal; AI responds via `ai_action_ready(unit_id, action_command)` within `AI_DECISION_TIMEOUT_MS` (500ms). AI does NOT decide counter-attacks, DEFEND_STANCE reductions, or TacticalRead forecasts — all are automatic.

  The battle state snapshot is a deep copy (`Dictionary.duplicate_deep()` —
  Godot 4.5+). Schema (extended v4.0):

  ```
  {
    "round": int,
    "active_unit_id": int,
    "units": [
      {
        "unit_id": int,
        "faction": String,
        "col": int, "row": int,
        "facing": String,
        "class_id": String,
        "is_commander": bool,
        "current_hp": int, "max_hp": int,
        "atk": int, "def": int,
        "is_alive": bool,
        "status_effects": [{type, remaining_turns, stacks}],   # includes DEFEND_STANCE (v4.0+)
        "dot_damage_next_tick": int,
        "active_passives": [
          {"name": String, "stacks": int, "remaining_turns": int}
        ],
        "has_tactical_read": bool,                              # v5.0 — Strategist only (Commander's TR UI affordance removed; see CR-14)
        "has_rally": bool,                                      # v5.0 — Commander `passive_rally` per unit-role.md CR-2 (+5% ATK adjacent, cap 15%)
        "charge_active": bool,
        "acted_this_turn": bool,                                # v5.0 — DEFEND sets true (CR-13 rule 5); WAIT sets false (CR-10)
      }
    ],
    "cooldown_map": {unit_id: {skill_slot: remaining_turns}},
    "movement_budget_map": {unit_id: accumulated_budget},
    "terrain_tiles": [{col, row, terrain_type, elevation, defense_bonus, evasion_bonus}],
    "initiative_queue": [unit_id, ...],
    "formation_bonuses": {unit_id: {stat: modifier}},
    "victory_conditions": {type, target_commander_id?},
    "tactical_read_forecasts": [                                # v4.0 — per qualifying AI unit
      {
        "viewer_unit_id": int,
        "target_unit_id": int,
        "counter_will_fire": bool,
        "counter_would_kill_attacker": bool
      }
    ]
  }
  ```

  **Authoritativity rule**: `charge_active` is computed from
  `movement_budget_map[unit_id] >= CHARGE_THRESHOLD AND class_id == "CAVALRY"`.
  AI reads it directly. **DEFEND_STANCE** is tracked in `status_effects` and AI
  must check it before planning attacks (targeting DEFEND_STANCE units reduces
  damage per hp-status `defend_stance_reduction = 50` and suppresses the
  counter entirely per CR-13 rule 4 / CR-6 — no counter-trade is possible).

  **TacticalRead population rule (v5.0)**: `tactical_read_forecasts` entries
  are populated ONLY for units where `has_tactical_read == true` (Strategist
  per CR-14). For Commander and other classes the array is empty — AI
  consumers must treat empty as "no TR affordance," not as missing data. This
  keeps the snapshot schema stable (array always present) while making the
  per-class gating explicit.

  **Non-Strategist counter-forecasts**: Non-Strategist AI that needs to
  evaluate counter-kill risk for its own decision-making calls
  `damage_calc.resolve(attacker, defender, modifiers={is_counter=true, ...})`
  directly off the snapshot during deliberation (cold-path, not on the turn-
  resolution hot path). Only Strategist gets pre-computed
  `tactical_read_forecasts` entries from Grid Battle.

  **Performance budget (mobile)**: `Dictionary.duplicate_deep()` of a full
  snapshot is measured at ~1-5ms on Pixel 7-class hardware in Godot 4.6.
  Implementation should exclude static `terrain_tiles` from per-turn snapshots
  after the first.

- **Skill System**: Grid Battle tracks cooldowns (CR-9) and validates targeting (CR-8). Skill System GDD defines data structures, effect types, cooldown values, AoE shapes.

- **Input Handling**: Grid Battle provides `is_tile_in_move_range`, `is_tile_in_attack_range`. Grid Battle signals via `input_block_requested` / `input_unblock_requested`; Input Handling owns `INPUT_BLOCK_GRACE_PERIOD` timer.

## Tuning Knobs

All values below are data-driven (loaded from `battle_constants.json`).

| Knob | Default | Safe Range | Affects | Notes |
|------|---------|------------|---------|-------|
| `ROUND_CAP` | 30 | 20–50 | Battle length, DRAW frequency | Owned by Turn Order (registry: `round_cap`); Grid Battle evaluates. |
| `CHARGE_THRESHOLD` | 40 | 30–60 | Cavalry power budget | Owned by Turn Order (registry: `charge_threshold`). |
| `DEPLOYMENT_CAMERA_PAN_DURATION` | 2.0s | 0.5–4.0s | Opening battle pacing | Cosmetic. |
| `EVASION_ROLL_RANGE` | 100 (0-99) | Fixed | Evasion probability resolution | Not tunable. |
| `VICTORY_TYPE` | "ANNIHILATION" | Enum | Scenario variety | Per-scenario. |
| `COOLDOWN_DECREMENT_PER_TURN` | 1 | 1–2 | Skill availability pacing | At 1: strategic; at 2: ability spam. |
| `ANIMATION_SPEED_MULTIPLIER` | 1.0 | 0.5–3.0 | Battle pacing | Player-facing. |
| `INPUT_BLOCK_GRACE_PERIOD` | 0.1s | 0.05–0.3s | Input responsiveness | Owned by Input Handling. |
| `TWO_TAP_TIMEOUT_S` | 15.0 | 8.0–30.0 | Beat 2 touch-confirm window for ATTACK AND DEFEND (v5.0) | Owned by this GDD (registry: `two_tap_timeout_s`); consumed by `design/ux/battle-hud.md` §5.1 (ATTACK) + §5.2 (DEFEND) (+ §5.3 gamepad mapping when that spec is authored). |
| `AI_DECISION_TIMEOUT_MS` | 500 | 300–2000 | AI deliberation budget | Registry: `ai_decision_timeout_ms`. Hard limit; expiry forces WAIT + error log. |
| `AI_SOFTLOCK_THRESHOLD` | 2 | 1–5 | CR-3b escalation trigger | Registry: `ai_softlock_threshold`. Consecutive AI timeouts before round flush. |
| `ANIMATION_TIMEOUT_S` | 3.0 | 1.0–10.0 | Watchdog for animation_complete | Registry: `animation_timeout_s`. Defensive. |
| `show_wait_for_all_classes` | `false` | bool | Action-menu visibility of WAIT for non-Scout classes (CR-10 v5.0) | Project-level Settings toggle. Discovery path: Player Settings → Accessibility → "Always show WAIT action" (registry-backed key `settings.show_wait_for_all_classes`; see `design/ux/settings.md` — NOT YET AUTHORED). Default hides WAIT for 5/6 classes since they gain no mechanical advantage over END_TURN; Scout always sees it. Setting to `true` restores WAIT universally. Accessibility / advanced-tactics escape valve. |

**Registry-owned constants consumed here but not tuned here** (single source of
truth lives elsewhere):

| Constant | Value | Registry owner | Consumed via |
|----------|-------|----------------|--------------|
| `COUNTER_ATTACK_MODIFIER` | 0.5 | `damage-calc.md` → registry `counter_attack_modifier` | CR-6, `damage_resolve(is_counter=true)` |
| `BASE_CEILING` | 83 | `damage-calc.md` → registry `base_ceiling` | CR-5 step 7 |
| `DAMAGE_CEILING` | 180 | `damage-calc.md` → registry `damage_ceiling` | CR-5 step 7 |
| `MIN_DAMAGE` | 1 | `hp-status.md` → registry `min_damage` | CR-5 step 8 |
| `MAX_EVASION` | 30 | `terrain-effect.md` → registry `max_evasion` | F-GB-2 evasion clamp |
| `MAX_DEFENSE_REDUCTION` | 30 | `terrain-effect.md` → registry `max_defense_reduction` | F-GB-2 / damage_resolve defense_mul |
| `CHARGE_BONUS` | 1.20 | `damage-calc.md` → registry `charge_bonus` | damage_resolve P_mult |
| `AMBUSH_BONUS` | 1.15 | `damage-calc.md` → registry `ambush_bonus` | damage_resolve P_mult |
| `DEFEND_STANCE_REDUCTION` | 50% | `hp-status.md` → registry `defend_stance_reduction` | CR-13 rule 3 (applied in HP/Status F-4) |
| `DEFEND_CONSECUTIVE_LOCKOUT` | `true` | Registry: `defend_consecutive_lockout` (bool). **Gate knob.** Enables/disables CR-13 rule 8. When `false`, `defended_last_turn` is still tracked but `get_valid_actions` never consults it — DEFEND is always available regardless of prior-turn history. Set `false` to disable lockout globally for playtesting whether consecutive DEFEND creates the attractor problem without the restriction, or for accessibility modes where uncapped DEFEND is intended. Safe range: bool (no intermediate value). Default `true`. | CR-13 rule 8 (v5.0 pass-11b — B-9) |
| `DEFEND_STANCE_ATK_PENALTY` | 40% | `hp-status.md` → registry `defend_stance_atk_penalty` | **Scope (v5.0 pass-9b)**: Applies only to damage-calc `is_counter=true` paths. In v5.0 the own-turn-primary path (DEFEND_STANCE attacker takes offensive action while stanced) is **UNREACHABLE** — CR-13 rule 4 suppresses counters from DEFEND_STANCE, no mid-turn DEFEND skill exists, and DEFEND itself terminates the unit's turn. Therefore this constant is **inert in v5.0**. Retained in the registry as a forward declaration for **speculative future mid-turn-DEFEND skills**; activating the own-turn-primary path would require a new gate in damage-calc.md plus a design decision on stance-break rules. Flagged for re-evaluation when (and if) a mid-turn DEFEND skill is designed. **Value provenance (pass-11a.1 — game-designer R-7)**: the 40% value is **provisional speculation** — it was sized for a prior v3.2/v4.0 model where DEFEND_STANCE defenders could counter at reduced ATK. The v5.0 model does not exercise this path at all, so 40% has no playtest evidence behind it. When the speculative future skill is designed, this value MUST be re-evaluated in that skill's context rather than carried forward as "known good". |
| `TACTICAL_READ_EXTENSION_TILES` | 1 | `unit-role.md` → registry `tactical_read_extension_tiles` | CR-14 extension rule |

*(v5.0 — removed: `DEFEND_DAMAGE_REDUCTION = 0.5`. Stale duplicate of
`defend_stance_reduction`, which is now 50% — owned by hp-status.md, consumed
here.)*

### Tuning Guidelines

- **Counter-attack balance**: Target ~55% attacker advantage. Adjust `counter_attack_modifier` (damage-calc.md) toward 0.3 if attackers win >70%; toward 0.7 if defenders too strong.
- **Battle length**: Target 8-15 turns (standard), 15-25 (boss/commander). If median exceeds target, check unit damage (upstream) before adjusting ROUND_CAP.
- **Battle-length sensitivity — v5.0 pass-9b playtest trigger**: v5.0 raised `defend_stance_reduction` from 30% → 50% AND hid WAIT for 5/6 classes (both via the CR-13 ratification). Empirical question: does this push standard battles past the 8-15 turn target? Playtest-driven check — target median 8-15 turns. **Trigger**: if playtest median exceeds 20 turns, re-tune in this order: (1) lower `defend_stance_reduction` toward 35% (hp-status.md F-4), (2) raise `defend_stance_atk_penalty` against the future mid-turn-DEFEND-skill path (currently inert — see Tuning Knobs note), (3) accept an extended target (update this section to 15-25 / 25-40) only as a last resort. No preemptive change in v5.0 — flag this as an empirical check and revisit after first playtest cohort.
- **Cooldown pacing**: If skills feel too rare, consider `COOLDOWN_DECREMENT_PER_TURN = 2` or reduce cooldown durations in Skill System data.
- **DEFEND balance**: Track DEFEND selection rate. If <5% of actions, DEFEND is dead; raise `defend_stance_reduction` (hp-status.md) or add a damage-reflection component in a future revision. If >40%, DEFEND is dominant; lower toward 35%. Current v5.0 value is 50% (was 30% in v4.0); tuning safe range is 30–70%.

## Acceptance Criteria

### Category A: Battle State Machine

**AC-GB-01**: "Given `tests/fixtures/test_map_2x2.tres` (2×2 grid with one ally at (0,0) facing EAST and one enemy at (1,0) facing WEST, victory_type = ANNIHILATION), when Grid Battle loads the scenario, the state machine emits events in this exact order with no spurious intermediate events: (1) enters BATTLE_LOADING, (2) emits `battle_initialized`, (3) enters DEPLOYMENT, (4) emits `deployment_complete`, (5) enters COMBAT_ACTIVE, (6) emits `round_started(1)`, (7) emits `unit_turn_started(active_unit_id, is_player_controlled)`. Any deviation fails."
— Type: Unit — Fixture: `tests/fixtures/test_map_2x2.tres` — File: `tests/unit/grid_battle/grid_battle_state_machine_test.gd` — Gate: BLOCKING

**AC-GB-02**: "When `battle_ended(result)` fires, state transitions to RESOLUTION. COMBAT_ACTIVE → BATTLE_LOADING and RESOLUTION → COMBAT_ACTIVE are both rejected."
— Type: Unit — Gate: BLOCKING

**AC-GB-03**: "When CLEANUP completes, `battle_complete(outcome_data)` is emitted and no further transitions occur."
— Type: Unit — Gate: BLOCKING

### Category B: Movement Resolution

**AC-GB-04**: "Given move_range 3 on mixed terrain, `get_movement_range()` returns only tiles within effective budget. Occupied tiles excluded."
— Type: Unit — Gate: BLOCKING

**AC-GB-05**: "Given CAVALRY (class_multiplier = 1.0 on PLAINS) with `move_range = 4` on PLAINS (terrain_cost = 10), path length 4 → `movement_budget_map[unit_id] == 40` AND next ATTACK applies Charge +20% ATK (assert `effective_atk == base_atk × 1.2`). Path length 3 → budget 30, NO Charge. Path length 5 → rejected (out-of-range); budget unchanged. Boundary is inclusive `budget >= 40`."
— Type: Unit — Gate: BLOCKING

**AC-GB-06**: "If `has_move_token()` is false, MOVE option absent from menu, no S1 movement reachable. ACTION token unaffected."
— Type: Unit — Gate: BLOCKING

### Category C: Attack Resolution Pipeline

**AC-GB-07**: "Given known ATK, DEF, D_mult, T_def, `raw_damage` matches `damage_resolve()` output (see `design/gdd/damage-calc.md` F-DC-3..F-DC-6) and is never < MIN_DAMAGE (1). When T_def = 30 and D_mult = 1.5, result is floored. **Precision boundary**: test with D_mult values that trigger IEEE 754 residue pre-quantization (e.g., 1.2 × 1.1 before snappedf) must produce identical output to the quantized-input path — confirming the `snappedf(base × class, 0.01)` pre-computation is applied."
— Type: Unit — Gate: BLOCKING

**AC-GB-07b (new v4.0; arithmetic corrected v5.0 pass-9a for BASE_CEILING=83)**: "Boundary-value damage tests: (a) ATK=30, DEF=99, D_mult=1.0, T_def=0 → MIN_DAMAGE floor fires (base = max(1, 30-99) = 1; result = 1). (b) ATK=200, DEF=15, D_mult=1.80, T_def=0 → BASE_CEILING clamp fires (base 185 → 83 via BASE_CEILING, then × 1.80 = 149.4 floored to 149; below DAMAGE_CEILING=180). (c) ATK=200, DEF=15, D_mult=1.0, T_def=0 → BASE_CEILING fires (base 185 → 83, then × 1.0 = 83). (d) [pass-11a replacement — prior case was incoherent per F-DC-3 ordering: terrain applies to `eff_def × defense_mul`, not to `base` post-clamp, so DEF=0 made terrain inert] ATK=200, DEF=10, D_mult=1.0, T_def=30 → BASE_CEILING + terrain interaction: defense_mul = `1 − 30/100 = 0.70`; `eff_def × defense_mul = 10 × 0.70 = 7`; base = `mini(BASE_CEILING=83, max(MIN_DAMAGE, floori(200 − 7))) = mini(83, 193) = 83` (BASE_CEILING fires WITH terrain active on the DEF side of the subtraction). All four pass the floor/ceiling contract; results deterministic across runs."
— Type: Unit — Gate: BLOCKING

**AC-GB-08**: "Evasion uses 2RN hit-semantics per F-GB-2 with `randi_range(0,99)` (NOT `random_int`). Three cases with RNG seam mocked: (a) **Hit** — evasion_bonus=10, roll=80, hit_chance=90: HP/Status intake called, counter eligibility evaluated, ACTION spent. (b) **Miss** — evasion_bonus=30 (MAX_EVASION), roll=80, hit_chance=70: HP/Status intake NOT called, no `unit_died`, no `counter_attack_triggered`, ACTION STILL spent. (c) **Boundary** — evasion_bonus=0, roll=0, hit_chance=100: always hits. All `evasion_bonus` ≤ MAX_EVASION=30 validated before formula."
— Type: Unit — Gate: BLOCKING

**AC-GB-09**: "Parameterised counter-eligibility table:

| Case | Defender survived | Attacker in natural range | Scout Ambush | DEFEND_STANCE | Primary action | Primary was counter | Counter fires? |
|------|-------------------|---------------------------|--------------|---------------|----------------|----------------------|----------------|
| a | true | true | false | false | ATTACK | false | **YES** |
| b | true | true | false | false | USE_SKILL (damage) | false | **YES** (deferred to Skill System) |
| c | true | true | false | false | USE_SKILL (status-only) | false | NO |
| d | false (HP ≤ 0) | true | false | false | ATTACK | false | NO |
| e | true | false (out of natural range) | false | false | ATTACK | false | NO |
| f | true | true | true (Ambush) | false | ATTACK | false | NO |
| g | true | true | false | false | ATTACK | true (is counter) | NO |
| h (v4.0) | true | true | false | true (DEFEND_STANCE) | ATTACK | false | NO |
| i (v4.0) | true (Archer at range 2 from melee attacker at range 1) | false (Archer natural range is 2, attacker at 1) | false | false | ATTACK by melee | false | NO |

All 9 cases must pass. Assert `counter_attack_triggered` presence/absence AND attacker HP delta (>0 only when counter fires)."
— Type: Unit — Gate: BLOCKING

**AC-GB-10 (v5.0 rewrite — damage_resolve contract)**: "Counter-attack damage is produced by invoking `damage_calc.resolve(attacker, defender, modifiers)` with `modifiers.is_counter = true`. Assertions: (1) `damage-calc.md` F-DC-7 applies `counter_attack_modifier = 0.5` internally — Grid Battle MUST NOT multiply a second time. (2) Given fixture `tests/fixtures/grid_battle/counter_small.yaml` (primary `resolved_damage = 1` → counter context, defender ATK 1 vs attacker DEF 1, T_def = 0), the returned `counter_result.resolved_damage == 1` (MIN_DAMAGE floor). (3) Counter does NOT spend the defender's ACTION token — assert `action_tokens.has(defender_id) == true` post-counter. (4) `counter_attack_triggered(defender_id, attacker_id, counter_damage)` fires exactly once per counter. All four assertions parameterised over the counter-result values from on-disk fixtures: `{small=1 (MIN_DAMAGE floor per counter_small.yaml), medium=7 (counter_medium.yaml), max=74 (counter_max.yaml — BASE_CEILING × D_mult × COUNTER_ATTACK_MODIFIER)}`."
— Type: Unit — Fixture: `tests/fixtures/grid_battle/counter_small.yaml`, `counter_medium.yaml`, `counter_max.yaml` — File: `tests/unit/grid_battle/grid_battle_attack_resolution_test.gd` — Gate: BLOCKING

**AC-GB-10b (v5.0 rewrite — hp-status ownership)**: "DEFEND_STANCE damage reduction is owned by `design/gdd/hp-status.md` F-4 (registry `defend_stance_reduction = 50`). Grid Battle asserts the **integration contract**, not the value. Given fixture `tests/fixtures/grid_battle/defend_stance_20.yaml` (attacker ATK 40, defender DEF 20, defender has `DEFEND_STANCE` active, T_def = 0): (1) `damage_resolve` returns `resolved_damage = R` (value is damage-calc.md's concern). (2) HP/Status `apply_damage(defender, R)` reduces HP by `max(MIN_DAMAGE, floor(R × 0.5))` — assert via HP delta. (3) For `R = 20` the delta is exactly 10; for `R = 1` the delta is 1 (MIN_DAMAGE floor). (4) **Counter suppression**: when the primary attack hits a DEFEND_STANCE defender, `counter_attack_triggered` is NOT emitted, even when all other CR-6 conditions hold — assert signal absence via GdUnit4 `monitor_signals()` + `assert_signal(counter_attack_triggered).is_not_emitted()`. (5) DEFEND_STANCE clears at the defender's next `unit_turn_started` — assert via `status_effects.size_before == 1, size_after == 0` bracketed around the turn advance."
— Type: Integration — Requires: mocked HP/Status `apply_damage` boundary for assertions (2)(3)(4) (AC asserts HP delta post-reduction, not `damage_resolve`'s internal output) — Fixture: `tests/fixtures/grid_battle/defend_stance_20.yaml`, `defend_stance_min.yaml` — File: `tests/integration/grid_battle/grid_battle_defend_stance_test.gd` — Gate: BLOCKING

### Category D: Victory and Defeat Conditions

**AC-GB-11**: "Evaluation order: VICTORY_ANNIHILATION → DEFEAT_ANNIHILATION → VICTORY_COMMANDER_KILL. VICTORY priority on simultaneous last-unit kills via AOE_ALL. Target ordering `[last_enemy, last_ally]`: (1) `unit_died(last_enemy)` first, (2) `all_enemies_dead()` true, (3) `battle_ended(VICTORY)` exactly once, (4) `unit_died(last_ally)` fires-but-ignored OR not fired."
— Type: Unit — Fixture: `tests/fixtures/test_map_2x2.tres` + mocked AoE — Gate: BLOCKING

**AC-GB-12**: "`victory_type = COMMANDER_KILL` with commander death + other enemies alive → `battle_ended(VICTORY)` without waiting for full annihilation."
— Type: Unit — Gate: BLOCKING

**AC-GB-13**: "DRAW evaluated at `round_ended` for round 30. If victory/defeat triggers mid-round 30, it takes priority; DRAW never fires."
— Type: Unit — Gate: BLOCKING

### Category E: Skills and Cooldowns

**AC-GB-14**: "After skill use, `cooldown_map[unit_id][slot] == cooldown_duration`. Each turn start: decrement by 1 (floor 0). Skill selectable only when 0. At CLEANUP: cooldown_map cleared."
— Type: Unit — Gate: BLOCKING

**AC-GB-15 (v5.0 rewrite — damage_resolve integration)**: "USE_SKILL counter eligibility per CR-6 condition 4. Three parameterised cases, each with its own fixture under `tests/fixtures/grid_battle/skill_counter_*.yaml`: (a) **damage-dealing skill** (`effect_type = damage`) — `counter_attack_triggered` fires exactly once after `unit_died` is NOT emitted; defender HP reduces by the value returned from the second `damage_resolve(is_counter=true)` call (value owned by damage-calc.md; test asserts the emission + exact HP delta from fixture). (b) **status-only skill** (`effect_type = status`) — `counter_attack_triggered` does NOT fire; assert via `monitor_signals()` + `assert_signal.is_not_emitted()`. (c) **heal-on-ally skill** (target is ally, any effect_type) — `counter_attack_triggered` does NOT fire; defender is ally, not enemy."
— Type: Unit — Fixture: `tests/fixtures/grid_battle/skill_counter_damage.yaml`, `skill_counter_status.yaml`, `skill_counter_heal.yaml` **(DEFERRED FIXTURE — authoring pending Skill System implementation sprint per v5.0 decision 13)** — **Sprint gate (pass-11a)**: This AC cannot be marked Done until the Skill System GDD is Designed AND all three `skill_counter_*.yaml` fixtures are authored. Implementation-sprint backlog must enforce this — picking up the CR-6 condition-4 story without fixtures would bypass the test gate under schedule pressure. — File: `tests/unit/grid_battle/grid_battle_skills_cooldowns_test.gd` — Gate: BLOCKING

### Category F: Input Blocking

**AC-GB-16 (v5.0 rewrite — closed signal set)**: "With mocked AI (`tests/fixtures/mocks/ai_module_stub.gd`), three parameterised cases. **The AI stub's action-space is constrained to `{WAIT}` only** across all three cases — this keeps the signal set closed (broader action-space emissions such as `attack_target_hovered` are excluded by construction, so the exact-ordered-signal-set assertions below are verifiable). Each asserts the **exact ordered signal set** emitted during the AI turn (closed set — extra signals fail): (a) **happy path** — AI responds within 100ms. Expected: `[input_block_requested, ai_action_requested, ai_action_ready, unit_turn_ended, input_unblock_requested]`. Assert `input_block_requested` precedes `ai_action_requested` by monitor ordering; `input_unblock_requested` fires before next player menu event. (b) **timeout** — AI silent until `AI_DECISION_TIMEOUT_MS` expires. Expected: `[input_block_requested, ai_action_requested, Timer.timeout, unit_waited, unit_turn_ended, input_unblock_requested]` plus exactly one `push_error('AI_TIMEOUT: ...')`. No retry. **AI-failure bookkeeping (pass-11b — qa-lead)**: case (b) MUST also assert `acted_this_turn[unit_id] == true` post-substitution — the CR-3 per-unit timeout branch is an AI-failure path and must be Ambush-immune per CR-10 bookkeeping rule (mirrors the case (c) pass-11a.1 addition). (c) **invalid action** — AI returns a malformed action command (CR-3a rejects). Expected: `[input_block_requested, ai_action_requested, ai_action_ready, unit_waited (substituted), unit_turn_ended, input_unblock_requested]` plus exactly one `push_error('AI_INVALID_ACTION: ...')`. **AI-failure bookkeeping (pass-11a.1 — ai-programmer B-2)**: case (c) MUST also assert `acted_this_turn[unit_id] == true` post-substitution — the CR-3a invalid-action branch is the third AI-failure-substitution code path (CR-3 timeout + CR-3b flush are the other two, covered by AC-GB-25 assertion 9) and must be Ambush-immune per CR-10 bookkeeping rule. All three advance the initiative queue — assert `initiative_queue.head_before != initiative_queue.head_after`."
— Type: Integration — Mock: `tests/fixtures/mocks/ai_module_stub.gd` — File: `tests/integration/grid_battle/grid_battle_ai_integration_test.gd` — Gate: BLOCKING

**AC-GB-17 (v5.0 rewrite — watchdog fixture)**: "With mocked animation (`tests/fixtures/mocks/animation_controller_stub.gd`) and `animation_timeout_override_s = 0.1s` injected via GridBattle constructor parameter. Two cases: (a) **normal** — `animation_complete` fires within 0.05s; `input_unblock_requested` emitted exactly once; all taps during the S5 window are consumed silently (assert zero menu events); next `unit_turn_started` fires after `input_unblock_requested + INPUT_BLOCK_GRACE_PERIOD`. (b) **watchdog trigger** — stub never emits `animation_complete`; the watchdog (owned `Timer` node, NOT `SceneTreeTimer`) fires its `timeout` signal at `animation_timeout_override_s`; Grid Battle emits a synthetic `animation_complete`; exactly one `push_error('ANIMATION_TIMEOUT: stalled_type=<type>')` is logged; `input_unblock_requested` fires exactly once. **Tests use `Time.get_ticks_msec()` + frame advance, not real-time `await`, to eliminate flake.** Total test duration < 1s."
— Type: Integration — Mock: `tests/fixtures/mocks/animation_controller_stub.gd` — Fixture: none (inject by setting `node.animation_timeout_override_s = 0.1` after `PackedScene.instantiate()` and before `add_child()`; `@export var` pattern per CR-12 prose, Godot 4.6 PackedScene-compatible) — File: `tests/integration/grid_battle/grid_battle_animation_watchdog_test.gd` — Gate: BLOCKING

### Category G: Edge Case Spot-Checks

**AC-GB-18**: "`unit_roster.size() > deployment_positions.size()` → log error, place units with positions, exclude excess from Turn Order. No crash."
— Type: Unit — Gate: BLOCKING

**AC-GB-19**: "Undo after MOVE — two assertions:

(a) **Behavior** — Pre-move: unit at A, `movement_budget_map[id] == 0`, `facing = NORTH`. After MOVE to B with budget 20, facing EAST, MOVE token spent. Undo restores: position A, `facing = NORTH`, `movement_budget_map[id] == 0`, MOVE token available. After ACTION token spent → Undo unavailable (returns error code, state unchanged).

(b) **Deep-copy** — Pre-move snapshot (CR-4 step 8) uses `Dictionary.duplicate_deep()`. Test: capture snapshot, mutate live `movement_budget_map` (add bogus key), call Undo, assert restored state excludes bogus key."
— Type: Unit — Gate: BLOCKING

### Category H: Round Lifecycle and Action Contracts

**AC-GB-20**: "On `round_started`: reset `movement_budget_map = {}`, clear `charge_active`, re-grant MOVE+ACTION tokens to alive units. Dead units: `move_tokens.has(id) == false` AND `action_tokens.has(id) == false` (KEY ABSENCE). All three clears fire before first `unit_turn_started`."
— Type: Unit — Gate: BLOCKING

**AC-GB-21 (v5.0 rewrite — closed signal set + acted_this_turn bookkeeping)**: "WAIT contract. Given fixture `tests/fixtures/grid_battle/wait_scout.yaml` (Scout at (1,1), one enemy at (3,3), CR-5 pre-conditions satisfied): (1) Emit sequence is EXACTLY `[unit_waited(scout_id), unit_turn_ended(scout_id)]` (no `ai_action_*`, no `unit_defended`). (2) Both tokens absent after: `move_tokens.has(scout_id) == false AND action_tokens.has(scout_id) == false`. (3) `acted_this_turn[scout_id] == false` post-WAIT — this is the distinguishing bookkeeping vs DEFEND (AC-GB-21c). (4) `facing[scout_id]` unchanged. (5) Initiative queue advances — `queue.head_before != queue.head_after`. **Binds CR-3b auto-WAIT**: synthetic WAIT emits the identical signal set — cross-reference AC-GB-25 assertion 3."
— Type: Unit — Fixture: `tests/fixtures/grid_battle/wait_scout.yaml` — File: `tests/unit/grid_battle/grid_battle_combat_flow_test.gd` — Gate: BLOCKING

**AC-GB-21b (v5.0 rewrite — END_TURN batch contract, prior sentence was garbled)**: "END_TURN contract (CR-3a / CR-10). Given fixture `tests/fixtures/grid_battle/end_turn_mixed.yaml` (3 player units with unacted tokens at start of player phase, 2 AI units already ended for the round): when player invokes END_TURN, assertions in order: (1) Grid Battle iterates the **player-unit subset** of the initiative queue in queue order, emitting `unit_waited(id)` per player unit that has any unspent token. (2) AI units are skipped entirely — no `ai_action_requested` fires during the batch. (3) `ai_soft_lock_counter` is NOT incremented; assert `counter_before == counter_after`. (4) After the batch completes, the player phase ends: Turn Order emits `round_ended` when the initiative queue is empty post-batch, or `unit_turn_started(next_ai_id)` when unacted AI units remain. (5) Emit sequence is EXACTLY one `unit_waited` per unacted player unit, in order, then `round_ended` (queue empty for this fixture's composition — all 2 AI are already ended; after the 3 `unit_waited`s the queue drains). **No `ai_soft_lock_counter` increment path is reachable through END_TURN** — explicit negative assertion."
— Type: Unit — Fixture: `tests/fixtures/grid_battle/end_turn_mixed.yaml` — File: `tests/unit/grid_battle/grid_battle_combat_flow_test.gd` — Gate: BLOCKING

**AC-GB-21c (v5.0 rewrite — two-tap confirm + acted_this_turn=TRUE + counter suppression)**: "DEFEND contract (CR-13). Given fixture `tests/fixtures/grid_battle/defend_basic.yaml` (Infantry unit on turn, no active status): (1) Emit sequence is EXACTLY `[unit_defended(unit_id), unit_turn_ended(unit_id)]` (no attack pipeline, no `counter_attack_triggered`). (2) Both tokens spent: `move_tokens.has(unit_id) == false AND action_tokens.has(unit_id) == false`. (3) **`acted_this_turn[unit_id] == true` post-DEFEND** — this is the v5.0 Scout-Ambush-immunity bookkeeping distinguishing DEFEND from WAIT. (4) `DEFEND_STANCE` status applied: assert `status_effects.contains(DEFEND_STANCE)` with `remaining_turns == 1`. (5) `unit_defended` precedes `status_applied(DEFEND_STANCE)` by ≤ 1 frame (HP/Status apply is synchronous within the action). (6) **Counter suppression**: in a follow-up scenario where the DEFEND-er is attacked next turn, assert `counter_attack_triggered` is NOT emitted (GdUnit4 `assert_signal.is_not_emitted()`). (7) **Undo unavailable**: calling Input Handling `undo_last_move` after DEFEND returns a REJECTED-DEFEND error code; state is unchanged. (8) **Mobile confirm flow is two-tap (CR-13 rule 7 / EC-GB-42 v5.0)** — covered by `design/ux/battle-hud.md` AC-UX-HUD-09 (cross-reference, not restated here)."
— Type: Integration — Requires: mocked HP/Status `apply_status` + `apply_damage` for assertions (4)(5)(6) (status-write + counter-suppression assertions need the HP/Status pipeline in the loop, not just Grid Battle state) — Fixture: `tests/fixtures/grid_battle/defend_basic.yaml` — File: `tests/integration/grid_battle/grid_battle_defend_stance_integration_test.gd` (renamed pass-11c — qa B-1; original `grid_battle_defend_test.gd` collided with the new Unit-level AC-GB-26 lockout file at the same base name. Split pass-9a from `grid_battle_combat_flow_test.gd` because the shared file hosts Unit-type ACs 09/21/21b/23; AC-GB-21c Integration setup warranted its own file) — Gate: BLOCKING

**AC-GB-22**: "Facing contract (CR-11): MOVE sets `facing` to last step direction (or unchanged if path length 0). ATTACK, counter-attack, and status apply do NOT change `facing`. Axis-aligned NORTH/EAST/SOUTH/WEST only."
— Type: Unit — Gate: BLOCKING

**AC-GB-23**: "CR-5 pipeline abort: attacker 1 ATK, defender 1 HP, counter conditions satisfied, defender is last enemy. (1) `battle_ended` fires exactly once with VICTORY. (2) `counter_attack_triggered` does NOT fire. (3) ACTION token not spent post-victory. (4) No state mutations after `battle_ended`."
— Type: Unit — Fixture: `tests/fixtures/test_map_2x2.tres` — Gate: BLOCKING

### Category I: Performance Budgets

**AC-GB-24 (v5.0 rewrite — per-platform, CI bypass)**: "UI-GB-04 render budget: when `attack_target_hovered` fires, the forecast panel renders all applicable sections within **120ms on Pixel 7-class reference hardware** (Android → Vulkan Forward+ per Godot 4.6 default). **Platform policy** (per `.claude/docs/technical-preferences.md` — Windows D3D12, Linux/Android Vulkan, macOS/iOS Metal): the 120ms budget applies uniformly across all platforms; divergence outside reference hardware is a `WARN` (investigate) not a hard-fail. **Timing seam**: start `Time.get_ticks_msec()` at signal emission; stop after TWO consecutive `await get_tree().process_frame` calls (first = layout pass complete, second = draw-call submission complete on CPU side). **Note (pass-11a correction)**: `process_frame` fires BEFORE rendering in Godot 4.6; two `await process_frame` calls measure CPU-side dispatch latency, NOT GPU pixel arrival. This is a CPU-side proxy — GPU presentation follows on next vsync. The assertion treats dispatch latency as the budget proxy for the 120ms target. `Control.resized` is NOT used (silent on same-size re-render); `is_layout_complete()` is NOT a Godot 4.6 API and MUST NOT appear. Assertion: `elapsed_ms <= 120` on reference hardware. **CI bypass**: headless CI runs on GitHub-Actions Linux runners without reference GPU; the test file respects the env var `SKIP_PERF_BUDGETS=1` which marks the assertion as SKIP with a visible log line. Reference-hardware perf runs are DEFERRED to a planned nightly job (`.github/workflows/perf-nightly.yml` — NOT YET AUTHORED; enforcement path is design-only pending DevOps implementation)."
— Type: Integration — Fixture: `tests/fixtures/mocks/attack_target_hovered_timing_probe.gd` — File: `tests/integration/grid_battle/grid_battle_forecast_budget_test.gd` — Gate: BLOCKING (CI-skippable via `SKIP_PERF_BUDGETS=1`)

### Category J: AI Soft-Lock Escalation

**AC-GB-25**: "Per CR-3b. Setup: mocked AI always times out; round with 4 AI (ids 1-4) and 1 player (id 5, last). Assertions:

(1) AI 1 and 2 time out → each substitutes WAIT via CR-3. Per-unit sequence: `unit_turn_started(is_player_controlled=false)` → `ai_action_requested` → timer `timeout` → `unit_waited(id)` → `unit_turn_ended`. Unit 1's per-unit `AI_TIMEOUT` log fires. Unit 2's per-unit log SUPPRESSED (raises counter to threshold — CR-3b detection log fires for unit 2).

(2) After unit 2's timeout, `ai_soft_lock_counter == AI_SOFTLOCK_THRESHOLD` → CR-3b step 1 fires `push_error(\"AI_SOFTLOCK_DETECTED: round=1 trigger_unit=2\")` exactly once BEFORE unit 2's WAIT resolves.

(3) AI 3 and 4 flushed per CR-3b step 3. Per unit: sequence EXACTLY `unit_turn_started(id, is_player_controlled=false)` → `unit_waited(id)` → `unit_turn_ended(id)` in that order. NONE of `ai_action_requested`, `ai_action_ready`, or `Timer.timeout` emitted for these units. **Listener verification (v5.0 rewrite — GdUnitArgumentCaptor usage corrected)**: use GdUnit4 `monitor_errors()` at test start and `assert_error_monitor()` for log assertions; use `get_signal_connection_list("ai_action_ready")` (signal name is a String per Godot 4.6 Node API) at the start and end of the flush window, assert `connections_after.size() == connections_before.size()` (listener-count delta = 0 — NO new mock subscribers were added). **Listener isolation**: the test spins up a dedicated test scene containing only the Grid Battle node under test plus the AI mock. Grid Battle emits `battle_complete` only at CLEANUP state (never during BATTLE state); no GameBus autoload connections are established before CLEANUP. **Negative assertion (autoload isolation gate)**: at test start, BEFORE any mid-battle assertions, assert `GameBus.get_signal_connection_list("battle_complete").is_empty() == true` (Godot 4.6: `Object.get_signal_connection_list(signal_name) -> Array[Dictionary]` is the correct API; `Signal.get_connections()` does not exist) — this confirms no GameBus listener has been registered while the scene is mid-battle. This assertion is test-start-only; since AC-GB-25 never advances into CLEANUP, the connection set remains empty for the test's full duration. This guarantees `get_signal_connection_list("ai_action_ready")` returns exactly the connections registered by the test fixture. `GdUnitArgumentCaptor` is NOT used for this assertion (it captures call arguments on a mocked method, not signal-listener registrations — prior v3.2/v4.0 usage was incorrect). Per unit: assert `movement_budget_map[flushed_id] == 0` post-flush (v4.0 addition — the flush path resets budget identically to normal CR-3).

(4) Player (id 5) receives normal PLAYER_TURN_ACTIVE. `input_unblock_requested` fires; action menu appears.

(5) On `round_started(round 2)`: `ai_soft_lock_counter == 0`; AI re-engaged (units 1-4 receive normal CR-3 AI_WAITING).

(6) After flush, CR-3b step 4 emits `push_error(\"AI_SOFTLOCK: round=1 bypassed_units=3,4\")` exactly once — completion log. `bypassed_units = [3, 4]` (triggering unit 2 NOT included). Total `AI_SOFTLOCK`-prefixed `push_error` in round 1 = exactly 2 (detection + completion). Test intercepts via GdUnit4 `monitor_errors()` / `assert_error_monitor`; `ErrorCapture` is NOT a GdUnit4 API.

(7) Battle does not end or hang; `round_ended` fires normally after unit 5's turn.

(8) **No user-facing error surface (v4.0)** — `design/ux/battle-hud.md` AC-UX-HUD-06 asserts no player-visible error text appears during flush. Cross-reference.

(9) **`acted_this_turn` bookkeeping verification (pass-11a.1 + pass-11b — qa-lead)**: Per the CR-10 volitional-vs-AI-failure bookkeeping rule, ALL AI-failure-substituted WAIT paths MUST set `acted_this_turn = true` (Ambush-immune — AI failure is not tactical choice). Three sub-assertions covering all three AI-failure branches present in this fixture: **(9a) CR-3 per-unit timeout** (units 1, 2 — normal timeout path, assertion 1): assert `acted_this_turn[1] == true AND acted_this_turn[2] == true` after each unit's `unit_turn_ended` fires. **(9b) CR-3b group flush** (units 3, 4 — flush path, assertion 3): assert `acted_this_turn[3] == true AND acted_this_turn[4] == true` after the flush loop completes. **(9c) Parameterised control case** — cross-reference AC-GB-21 fixture `wait_scout.yaml` (Scout volitional WAIT): in the same AC-GB-25 test scope, verify `acted_this_turn[scout_id] == false` post-volitional-WAIT to confirm the divergence between AI-failure and volitional code paths. CR-3a invalid-action branch is verified separately at AC-GB-16 case (c). Together (9a)+(9b)+(9c) cover all three AI-failure branches plus the volitional-WAIT control case in one parameterised assertion structure. This assertion formalises the CR-10 doc note (which is now removed in favour of this AC gate — prevents the invariant from drifting silent during implementation)."
— Type: Integration — Mocks: AI stub (timeout-always) — Fixture: `tests/fixtures/test_map_softlock_5unit.tres` (4 AI at ids 1-4, 1 player at id 5, victory_type=ANNIHILATION, deterministic initiative) — File: `tests/integration/grid_battle/grid_battle_ai_softlock_test.gd` — Gate: BLOCKING

### Category K: DEFEND Lockout (v5.0 pass-11b)

**AC-GB-26**: "Consecutive-turn DEFEND lockout (CR-13 rule 8). `DEFEND_CONSECUTIVE_LOCKOUT` registry knob must be `true` for sub-cases (a)–(c). Sub-cases:
(a) **Lockout fires**: Unit A DEFENDs on turn T. On turn T+1 for unit A: assert `defended_last_turn[A] == true` BEFORE `unit_turn_started` processing clears it AND assert `get_valid_actions(A)` does NOT contain DEFEND. Assert `defended_last_turn[A] == false` after turn-start processing completes. Assert MOVE, ATTACK, and WAIT are present in `get_valid_actions(A)` on turn T+1 (lockout affects DEFEND only).
(b) **Lockout releases**: Continuing from (a), unit A takes any non-DEFEND action on turn T+1 (e.g., WAIT). On turn T+2 for unit A: assert `defended_last_turn[A] == false` and DEFEND IS present in `get_valid_actions(A)`.
(c) **AI-failure-substituted WAIT clears lockout**: Unit B DEFENDs on turn T. On turn T+1, an AI-failure flush (CR-3b) substitutes WAIT for unit B (assert `acted_this_turn[B] == true` post-flush, per CR-3b / AC-GB-25 assertion 9). On turn T+2 for unit B: assert DEFEND IS present in `get_valid_actions(B)` — flushed WAIT on the intervening turn clears the lockout identically to a volitional action.
(d) **Knob-disabled path**: With `DEFEND_CONSECUTIVE_LOCKOUT = false`, repeat sub-case (a) setup. Assert DEFEND IS present in `get_valid_actions(A)` on turn T+1 (lockout disabled; `defended_last_turn` tracking irrelevant to action availability)."
— Type: Unit — Fixture: `tests/fixtures/grid_battle/defend_lockout.yaml` (new; two-unit setup with Unit A in post-DEFEND state `defended_last_turn=true`, Unit B for AI-failure sub-case) — File: `tests/unit/grid_battle/grid_battle_defend_test.gd` — Gate: BLOCKING

### Category L: Commander Rally Aura (v5.0 pass-11b)

**AC-GB-27**: "Rally aura (CR-15). Five parameterised sub-cases. **Float-comparison policy (pass-11c — qa B-3)**: all `get_rally_bonus()` assertions use `is_equal_approx(actual, expected)` (GDScript built-in, default epsilon 1e-5) rather than `==`. IEEE 754 cannot represent `0.05`/`0.10`/`0.15` exactly, and additive accumulation (`n × 0.05`) drifts. Implementor option: accumulate bonuses as integer basis points (e.g., `get_rally_bonus_bps() == 500`) and convert to float only at the `effective_atk` multiply site; in that case integer `==` is exact. Spec endorses either approach; tests must NOT use raw float `==` for nonzero values. Zero comparisons (`== 0.00`) are exact in IEEE 754 and may use raw `==`.
(a) **Single Commander adjacent**: Commander at (0,0), ally attacker at (1,0) (Manhattan distance 1). Assert `is_equal_approx(get_rally_bonus(attacker_id), 0.05)`. Damage resolve call receives `P_mult` that includes the 0.05 Rally contribution — verify `effective_atk == base_atk × 1.05` (floored at resolved_damage, not at bonus accumulation).
(b) **Two Commanders adjacent (cap reached — rev 2.8)**: Two Commanders at (0,0) and (2,0), ally attacker at (1,0) (distance 1 from both). Assert `is_equal_approx(get_rally_bonus(attacker_id), 0.10)`. This is the rev 2.8 +10% cap value (was +10% intermediate / +15% cap pre rev 2.8).
(c) **Cap enforcement (rev 2.8)**: Three or more Commanders all adjacent to same ally. Assert `is_equal_approx(get_rally_bonus(attacker_id), 0.10)` regardless of N (cap hard floor — rev 2.8 reduced from 0.15 per damage-calc.md ceiling-collision fix).
(d) **Commander out of range**: Commander at (0,0), ally attacker at (2,0) (Manhattan distance 2). Assert `get_rally_bonus(attacker_id) == 0.00` (zero — exact float compare safe).
(e) **Commander death drops bonus**: Setup with single Commander adjacent (sub-case a state). Trigger `unit_died(commander_id)`. Assert `get_rally_bonus(attacker_id) == 0.00` immediately post-death (before any subsequent turn). Verify forecast panel data path reflects 0.00 on next `attack_target_hovered` emission."
— Type: Unit — Fixture: `tests/fixtures/grid_battle/rally_aura.yaml` (new; Commander + ally unit grid positions seeded for sub-cases a/b/c/d/e) — File: `tests/unit/grid_battle/grid_battle_rally_test.gd` — Gate: BLOCKING

### Gate Summary

- **BLOCKING (31 criteria):** AC-GB-01 through AC-GB-27 (27 base = 01–27, plus 4 sub-variants AC-GB-07b/10b/21b/21c = 4 v4.0→v5.0 rewrites). Case-row additions (AC-GB-09 row h/i) counted under parent AC-GB-09.
  - **Sub-classification (pass-11c — qa B-2 correction)**: **24 fixture-authored or fixture-free** (runnable in current sprint) + **7 deferred-fixture** (cannot run until on-disk fixtures authored). Deferred list (7 unique ACs): AC-GB-01 (`test_map_2x2.tres`), AC-GB-11 (`.tres` dependency), AC-GB-15 (`skill_counter_damage.yaml` + `_status.yaml` + `_heal.yaml`), AC-GB-23 (`test_map_2x2.tres`), AC-GB-25 (`test_map_softlock_5unit.tres`), AC-GB-26 (`defend_lockout.yaml` — pass-11b new), AC-GB-27 (`rally_aura.yaml` — pass-11b new). Implementation sprint lead must prioritize fixture authoring before picking up these stories.
- **ADVISORY (0 criteria).**
- **v5.0 rewrites (10 ACs):** AC-GB-10, AC-GB-10b, AC-GB-15, AC-GB-16, AC-GB-17, AC-GB-21, AC-GB-21b, AC-GB-21c, AC-GB-24, AC-GB-25. All now reference on-disk fixtures under `tests/fixtures/grid_battle/` (minimal-set seed authored in v5.0 session; full set deferred to implementation sprint per active.md v5.0 brief).

### Test File Locations

| Test File | Criteria Covered |
|-----------|-----------------|
| `tests/unit/grid_battle/grid_battle_state_machine_test.gd` | AC-GB-01, AC-GB-02, AC-GB-03 |
| `tests/unit/grid_battle/grid_battle_movement_test.gd` | AC-GB-04, AC-GB-05, AC-GB-06, AC-GB-19, AC-GB-22 |
| `tests/unit/grid_battle/grid_battle_attack_resolution_test.gd` | AC-GB-07, AC-GB-07b, AC-GB-08, AC-GB-10 |
| `tests/integration/grid_battle/grid_battle_defend_stance_test.gd` | AC-GB-10b (v5.0 — split from attack_resolution; reclassified Integration pass-9a because assertions (2)(3)(4) need mocked HP/Status apply_damage in the loop) |
| `tests/unit/grid_battle/grid_battle_combat_flow_test.gd` | AC-GB-09, AC-GB-21, AC-GB-21b, AC-GB-23 |
| `tests/integration/grid_battle/grid_battle_defend_stance_integration_test.gd` | AC-GB-21c (v5.0 — reclassified Integration pass-9a; renamed pass-11c per qa B-1 to avoid base-name collision with new Unit-level `grid_battle_defend_test.gd`; assertions (4)(5)(6) need mocked HP/Status apply_status + apply_damage and counter-suppression scenario) |
| `tests/unit/grid_battle/grid_battle_defend_test.gd` | AC-GB-26 (pass-11b — consecutive-turn DEFEND lockout; 4 sub-cases including knob-disabled path) |
| `tests/unit/grid_battle/grid_battle_rally_test.gd` | AC-GB-27 (pass-11b — Commander Rally aura; 5 sub-cases including Commander-death drop) |
| `tests/unit/grid_battle/grid_battle_victory_conditions_test.gd` | AC-GB-11, AC-GB-12, AC-GB-13 |
| `tests/unit/grid_battle/grid_battle_skills_cooldowns_test.gd` | AC-GB-14, AC-GB-15 (deferred rows) |
| `tests/unit/grid_battle/grid_battle_round_lifecycle_test.gd` | AC-GB-20 |
| `tests/unit/grid_battle/grid_battle_edge_cases_test.gd` | AC-GB-18 |
| `tests/integration/grid_battle/grid_battle_ai_integration_test.gd` | AC-GB-16 |
| `tests/integration/grid_battle/grid_battle_animation_watchdog_test.gd` | AC-GB-17 |
| `tests/integration/grid_battle/grid_battle_forecast_budget_test.gd` | AC-GB-24 |
| `tests/integration/grid_battle/grid_battle_ai_softlock_test.gd` | AC-GB-25 |

**Fixtures (v5.0 minimal-set seed — authored in this revision; full set deferred to implementation sprint)**:

Scenario fixtures (`.tres`):

- `tests/fixtures/test_map_2x2.tres` — 2×2 with ally at (0,0) facing EAST and enemy at (1,0) facing WEST; `victory_type = ANNIHILATION`. Used by AC-GB-01, AC-GB-09 (cases a/d-h), AC-GB-23. **(DEFERRED FIXTURE — `.tres` authoring pending implementation sprint.)**
- `tests/fixtures/test_map_softlock_5unit.tres` — 5×5 with 4 AI at ids 1-4 and 1 player at id 5. Stats seeded for deterministic initiative [1,2,3,4,5]. Used by AC-GB-25. **(DEFERRED FIXTURE — `.tres` authoring pending implementation sprint.)**

Data fixtures (`.yaml` — v5.0 seed set):

- `tests/fixtures/grid_battle/counter_small.yaml` — primary `resolved_damage = 1` fixture for AC-GB-10 counter-MIN-DAMAGE case.
- `tests/fixtures/grid_battle/counter_medium.yaml` — primary raw 30 / counter `resolved_damage = 7` fixture for AC-GB-10 median case.
- `tests/fixtures/grid_battle/counter_max.yaml` — primary `resolved_damage = 180` (DAMAGE_CEILING) / counter `resolved_damage = 74` fixture for AC-GB-10 ceiling case.
- `tests/fixtures/grid_battle/defend_stance_20.yaml` — attacker ATK 40 / defender DEF 20 / DEFEND_STANCE active fixture for AC-GB-10b primary case.
- `tests/fixtures/grid_battle/defend_stance_min.yaml` — MIN_DAMAGE-floor fixture for AC-GB-10b floor case.
- `tests/fixtures/grid_battle/defend_basic.yaml` — Infantry DEFEND contract fixture for AC-GB-21c.
- `tests/fixtures/grid_battle/defend_lockout.yaml` — two-unit setup: Unit A with `defended_last_turn=true` (post-DEFEND state); Unit B for AI-failure sub-case. Used by AC-GB-26 sub-cases (a)–(d).
- `tests/fixtures/grid_battle/rally_aura.yaml` — Commander + ally unit grid positions seeded for AC-GB-27 multi-Commander and death sub-cases.
- `tests/fixtures/grid_battle/wait_scout.yaml` — Scout WAIT contract + Ambush eligibility fixture for AC-GB-21.
- `tests/fixtures/grid_battle/end_turn_mixed.yaml` — 3 player + 2 AI ended fixture for AC-GB-21b batch test.
- `tests/fixtures/grid_battle/skill_counter_damage.yaml` / `skill_counter_status.yaml` / `skill_counter_heal.yaml` — AC-GB-15 parameterised fixtures (deferred authoring; see v5.0 session follow-up).

Mocks (`.gd`):

- `tests/fixtures/mocks/ai_module_stub.gd` — AI mock (happy / timeout / invalid).
- `tests/fixtures/mocks/animation_controller_stub.gd` — animation mock with injectable timeout.
- `tests/fixtures/mocks/attack_target_hovered_timing_probe.gd` — timing probe for AC-GB-24.

*Fixtures marked "DEFERRED FIXTURE" above are authored during implementation
sprint as each story is picked up. ACs with deferred fixtures reference the
path anyway so that the fixture's absence is a concrete TODO, not a hidden
assumption.*

## Open Questions

1. ~~**Damage Calc GDD**: F-GB-PROV is provisional.~~ **RESOLVED 2026-04-18 (superseded)** → **CLOSED 2026-04-19 (v5.0)** — F-GB-PROV has been physically **deleted** from this document in the v5.0 revision. `damage_resolve()` is now the sole damage-resolution primitive. `BASE_CEILING = 83`, `DAMAGE_CEILING = 180`, `COUNTER_ATTACK_MODIFIER = 0.5` owned by `damage-calc.md` + registry. AC-DC-44 (CI grep asserting F-GB-PROV absence) is now satisfiable against this GDD.
2. **Deployment phase expansion**: MVP scripted only. VS or Alpha for player-configurable?
3. **Additional victory conditions**: "survive N rounds", "capture tile", "route past boundary" — pluggable objective framework needed?
4. **Formation Bonus integration point**: modify base stats or separate additive layer?
5. **Skill System scope**: data structures, effect types, cooldown values, AoE shapes, learn/unlock model.
6. **TacticalRead scope expansion (v4.0)**: should TacticalRead also reveal enemy cooldowns? Deferred pending AI System GDD.
7. **DEFEND with damage reflection (v4.0)**: should DEFEND optionally reflect a fraction of incoming damage at higher investment tiers (e.g., skill unlock)? Deferred pending Skill System GDD.
8. **Animation speed**: auto-battle / skip-animations mode for replays?
