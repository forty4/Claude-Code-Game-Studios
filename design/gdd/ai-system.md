# AI System (적 AI)

*Created: 2026-05-04*
*Status: Designed (MVP scope — solo-dev focused)*
*Authored to close `/gate-check pre-production` 2026-05-04 path-to-PASS item #4 (cross-director convergent blocker per CD Pillar 3 + TD no-ADR + PR no-epic).*

> The AI integration **signal protocol** is already locked by `design/gdd/grid-battle.md` CR-3 + CR-3a (`ai_action_requested` request → `ai_action_ready` response, 500ms timeout, action vocabulary {MOVE, ATTACK, USE_SKILL, DEFEND, WAIT}). This GDD specifies the **decision logic** — what action the AI chooses given the snapshot — not the surrounding plumbing.

## 1. Overview

The AI System is the per-unit decision layer that produces battle actions for non-player-controlled units. For MVP, it is **rule-based with utility scoring**: each enemy unit is tagged with one of 4 archetypes; on its turn the AI enumerates candidate actions, scores each via the archetype's utility function, and submits the highest-scored action via the `ai_action_ready(unit_id, action_command)` signal. No learning, no look-ahead, no behavior trees, no MCTS. Decisions are deterministic given identical battle-state snapshots (no RNG, or seeded RNG keyed on `unit_id + round_number` for tie-breaks). Solo-dev scope: 4 archetypes × ~3 utility rules each = ~12 hand-tuned rules covering chapter-1 (장판파) enemy roster (하후돈 / 장요 / 우금 / 허저).

## 2. Player Fantasy

The player must feel that **the enemy is reading the same battle they are**.

- When the player overextends a low-HP unit, an enemy archetype that targets weakness will pursue it. The player learns: "exposed = punished."
- When the player stacks formation in a chokepoint, an enemy holder will not march into the meat grinder; it will wait at range or reposition. The player learns: "good formation deters."
- When the player commits cavalry into the open, an aggressor will counter-charge, forcing the player to either commit harder or pull back. The player learns: "the opening I left is the opening they'll take."
- When the boss (허저-class coordinator) is on the field, its passive aura makes nearby enemies harder. The player learns: "kill the head, the body weakens."

**What the AI is NOT**: it is NOT a perfect adversary. It is NOT an opponent that out-thinks the player. It is the **embodiment of the battle's spatial logic** — when the player makes a mistake, the AI exploits it; when the player plays well, the AI struggles. Pillar 3 (모든 무장에게 자리가 있다) requires AI that pressures roles asymmetrically: a single dominant strategy must be punished by enemy archetype variety.

## 3. Detailed Rules

### CR-AI-1. AI is a battle-scoped subsystem

`AISystem` is instantiated per battle by `BattleScene` root mount sequence at **step 5.5** (between GridBattleController step 5 and BattleHUD step 6 per ADR-0019 §Mount Order + ADR-0016 §3 R-3 amended via /architecture-review delta #14 2026-05-05; Path A insert preserves existing 1-6 numbering, full 1-7 renumber deferred to sprint-7+ S7-02). Freed at battle end with the rest of BattleScene. Zero cross-battle state; archetype assignment loaded from chapter data per encounter.

### CR-AI-2. Archetype assignment is data-driven

Every enemy unit's `archetype: StringName` field is set at chapter-load time from `ChapterDefinition` enemy roster entries (one of the 4 archetype StringNames defined in CR-AI-3). NOT inferred from `unit_class`; archetype is a **separate** authorial axis from class. Two Cavalry units can have different archetypes; one Infantry can be a Holder while another is a Skirmisher (rare, but allowed for narrative encounters). Default archetype if missing: `&"aggressor"` (loud-fail with `push_warning`).

### CR-AI-3. The 4 MVP archetypes (StringName vocabulary)

| StringName | Korean | Behavior thesis | Example chapter-1 unit |
|---|---|---|---|
| `&"aggressor"` | 돌격형 | Close distance + finish low-HP targets; trades favorably | 하후돈 (Cavalry) |
| `&"skirmisher"` | 견제형 | Kite at range advantage; targets player ranged units first | 장요 (Cavalry, ranged variant) |
| `&"holder"` | 수비형 | Holds chokepoints + defends teammates; reluctant to overextend | 우금 (Infantry) |
| `&"coordinator"` | 통솔형 | Uses passive auras + targets player commanders; bosses primarily | 허저 (boss, Special class) |

The vocabulary is closed at MVP. Adding a 5th archetype requires either GDD revision + new utility function + balance pass, or emergent combination via passive interaction (NOT a new archetype slot).

### CR-AI-4. Decision pipeline (per AI turn)

When `ai_action_requested(unit_id, snapshot)` fires, `AISystem._on_ai_action_requested()` runs:

1. **Read snapshot** — receive `BattleStateSnapshot` Resource from GridBattleController (units / map / queue / hp / formation tags). Snapshot is read-only (per ADR-0014 + ADR-0011 consumer mutation contracts).
2. **Enumerate candidates** — compute the set of legal actions. For each tile reachable within move budget (via MapGrid Dijkstra), pair with each attack target in range OR a `WAIT` action OR a `DEFEND` action OR a `USE_SKILL` if the unit has a skill ready (post-MVP). Cap: max 200 candidates (move_budget × attack_targets bounded by map size + range).
3. **Score candidates** — for each candidate, evaluate `score = utility(unit, archetype, candidate, snapshot)` per the archetype's utility function (see §F-AI-1..F-AI-4).
4. **Tie-break deterministically** — sort by `(score DESC, target_unit_id ASC, target_coord.y ASC, target_coord.x ASC)`. Highest-scored action wins; ties resolved by hashable secondary keys.
5. **Submit** — emit `ai_action_ready(unit_id, action_command)` where `action_command` is a typed `AIActionCommand` Resource matching grid-battle.md CR-3a vocabulary (`MOVE` + optional `ATTACK` / `DEFEND` / `WAIT` / `USE_SKILL`). Submission MUST happen within 500ms or GridBattleController substitutes WAIT (grid-battle.md CR-3 timeout).

**Time budget**: full pipeline target <50ms typical, <200ms worst-case (200 candidates × ~1ms scoring), well under the 500ms timeout. If a future archetype's utility function blows the budget, profile + simplify before raising the timeout.

### CR-AI-5. Determinism contract

Identical `BattleStateSnapshot` + identical archetype assignment + identical `unit_id` + identical `round_number` MUST produce identical `AIActionCommand` output. No `randf()`, no `Time.get_ticks_msec()`, no static var caching, no external state read. If RNG is needed for tie-breaks beyond the deterministic cascade in §CR-AI-4 step 4, use a seeded `RandomNumberGenerator` keyed `seed = (round_number * 100000) + unit_id` (deferred to post-MVP — MVP relies on hashable tie-breaks). This contract enables save/load replay (a saved battle reloaded mid-AI-turn produces the same action) + unit testability.

### CR-AI-6. AI does not read GameBus state directly

AI accesses inputs ONLY via the `BattleStateSnapshot` parameter passed in `ai_action_requested`. Reading `MapGrid.get_X()` / `HPStatusController.get_X()` / `TurnOrderRunner.get_X()` directly during scoring is **forbidden** (mirrors `destiny_branch_judge_reads_scenario_runner_state` pattern from ADR-0018 — pure function takes snapshot, doesn't reach back). Snapshot construction is GridBattleController's responsibility per `ai_action_requested` emission contract.

### CR-AI-7. Soft-lock and timeout escalation

`ai_soft_lock_counter` is the GridBattleController's defense per grid-battle.md CR-3b. AISystem itself does NOT track or escalate; if its scoring fails (e.g., zero candidates due to a bug), it MUST submit `WAIT` rather than fail to emit. The 500ms timeout is GridBattleController's safety net, not AI's deadline target.

### CR-AI-8. AI does not introspect Pillar 2 hidden-fate state

AI MUST NOT reference `hidden_fate_condition_progressed` signal, `DestinyBranchChoice` payload, or any destiny-branch-domain state. AI plays the mechanical battle; fate progress is invisible to it (mirrors `battle_hud_subscribes_to_hidden_fate_signal` Pillar 2 architectural lock from ADR-0015). If a future designer wants AI to "know" about fate (e.g., "the enemy plays harder when the player is one condition away from REWRITTEN"), it requires Pillar 2 game-design-pillar revision + ADR amendment — three coordinated revisions.

## 4. Formulas

All four utility functions return a scalar `score: float`. Higher = more preferred. Negative scores mean "actively bad" (e.g., suicidal moves). All damage estimates use `DamageCalc.preview()` (read-only path, doesn't mutate state).

### F-AI-1. Aggressor utility

```
score(candidate) :=
    expected_damage_dealt
  + 50.0 * P(kill)                         # finishing bonus
  + 20.0 * (1.0 - target_hp_pct)           # weakness magnet (more weight as HP drops)
  - 0.7 * expected_counter_damage_taken    # counter-attack risk discount
  - 0.5 * distance_from_nearest_player     # prefer closing distance
  + bonus_for_charge(unit, candidate)      # exploits CHARGE passive if available

WAIT score := -100.0    # aggressor never voluntarily waits unless forced
DEFEND score := -50.0   # aggressor avoids defensive stance
```

### F-AI-2. Skirmisher utility

```
score(candidate) :=
    expected_damage_dealt
  + 30.0 * (target_is_ranged ? 1.0 : 0.0)  # priority on enemy ranged units
  - 0.4 * expected_counter_damage_taken
  + 25.0 * IF(distance_post_action >= self.range + 1, 1.0, 0.0)  # safe-distance bonus
  - 40.0 * IF(distance_post_action <= 1, 1.0, 0.0)               # melee-proximity penalty

WAIT score := -50.0     # skirmisher waits if no safe attack exists
DEFEND score := -30.0   # rarely defends; prefers movement
```

### F-AI-3. Holder utility

```
score(candidate) :=
    expected_damage_dealt
  + 40.0 * IF(candidate.target_tile == chokepoint, 1.0, 0.0)     # chokepoint preference
  + 30.0 * IF(adjacent_ally_count(candidate.target_tile) >= 1, 1.0, 0.0)  # stay near allies
  - 60.0 * IF(distance_from_formation_center > 3, 1.0, 0.0)      # don't overextend
  - 0.3 * expected_counter_damage_taken

WAIT score := 10.0 IF (no_player_in_range AND already_at_chokepoint) ELSE -30.0
DEFEND score := 20.0 IF (player_attack_inbound_predicted) ELSE 0.0
```

`chokepoint` is a per-map-tagged tile set (data-driven, in `ChapterDefinition.chokepoints: Array[Vector2i]`). Chapter-1 (장판파): the bridge tile (3,3) and adjacent (3,2)/(3,4) are chokepoints. `formation_center` = centroid of allied unit positions, refreshed per round.

### F-AI-4. Coordinator utility

```
score(candidate) :=
    expected_damage_dealt
  + 60.0 * IF(target_has_command_aura, 1.0, 0.0)  # priority on player commanders
  + 35.0 * IF(adjacent_ally_count(unit.position) >= 2, 1.0, 0.0)  # stay where aura helps
  + RALLY_USAGE_BONUS                              # see rally rule below
  - 0.5 * expected_counter_damage_taken

USE_SKILL (rally) score := 80.0 IF (adjacent_allies_alive >= 2 AND rally_off_cooldown) ELSE -100.0
WAIT score := -10.0
DEFEND score := 30.0 IF (self_hp_pct < 0.4) ELSE 0.0
```

`target_has_command_aura` — true if target unit's `passive_id == &"command_aura"` (matches 유비). For chapter-1, only 유비 has this; the coordinator (허저) prioritizes 유비 over other heroes for the duration of the encounter.

### Constants summary

| Constant | Default | Bounds | Tuning effect |
|---|---|---|---|
| `AGGRESSOR_KILL_BONUS` | 50.0 | 30-80 | Higher = chases low-HP targets harder |
| `AGGRESSOR_WEAKNESS_WEIGHT` | 20.0 | 10-40 | Higher = focuses fire on weakened units |
| `SKIRMISHER_RANGED_TARGET_BONUS` | 30.0 | 15-50 | Higher = priority on player archers |
| `SKIRMISHER_SAFE_DISTANCE_BONUS` | 25.0 | 15-40 | Higher = stays kited |
| `SKIRMISHER_MELEE_PENALTY` | 40.0 | 25-60 | Higher = panics out of melee |
| `HOLDER_CHOKEPOINT_BONUS` | 40.0 | 25-60 | Higher = anchors at choke |
| `HOLDER_OVEREXTEND_PENALTY` | 60.0 | 40-80 | Higher = stays close to formation |
| `COORDINATOR_COMMANDER_TARGET_BONUS` | 60.0 | 40-90 | Higher = ignores everything but commander |
| `COORDINATOR_RALLY_BONUS` | 80.0 | 60-100 | Higher = rallies more often |
| `AI_DECISION_TIMEOUT_MS` | 500 | 250-1000 | Lower = harsher, more WAIT substitutions; per grid-battle.md CR-3 |

All constants live in `BalanceConstants` per ADR-0006 (forbidden_pattern: `hardcoded_ai_constants` analogous to `hardcoded_damage_constants` from ADR-0012).

## 5. Edge Cases

### EC-AI-1. Zero candidates

If candidate enumeration returns empty (unit completely surrounded + no skills + paralyzed): submit `WAIT`. Log via `push_warning("AI_ZERO_CANDIDATES: unit=%d archetype=%s — submitting WAIT" % [unit_id, archetype])` for tuning visibility.

### EC-AI-2. All scores ≤ -100 (suicidal options only)

Example: a Holder surrounded by 4 player units in open ground, no chokepoint reachable. Submit `WAIT` even if WAIT score is also negative. Better to forfeit the turn than make a worse-than-WAIT move.

### EC-AI-3. Target dies between snapshot capture and action submission

GridBattleController validates per CR-3a — if attack target is dead, controller substitutes WAIT. AI does not need to re-verify target liveness; the snapshot is its truth at decision time.

### EC-AI-4. Archetype StringName not in vocabulary

`push_warning` + fallback to `&"aggressor"` (CR-AI-2 default). Production data MUST validate archetype on chapter-load (ChapterDefinition validation responsibility per ADR-0017). Fallback exists only for development-time forgiveness.

### EC-AI-5. Mid-turn save (CP-1 / CP-2 / CP-3 anchors)

Saves never fire mid-AI-turn per ADR-0017 + ADR-0003 (CP anchors are between-turns or post-Beat 7). If a future engine quirk introduces mid-turn save, AI MUST be re-entrant safe — its only state is the in-flight pipeline locals on the call stack, which serialize naturally. No `static var` and no instance-var caching makes this trivially correct.

### EC-AI-6. Bridge_blocker passive interaction (장비)

장비's `bridge_blocker` reduces adjacent enemy move budget by 1 (per chapter-prototype + grid-battle CR-N). AI's candidate enumeration MUST query `effective_move_budget` from the snapshot (which has bridge_blocker already applied), not raw `unit.move`. Snapshot construction in GridBattleController is responsible.

### EC-AI-7. Command_aura interaction (유비)

유비's `command_aura` adds +15% ATK to adjacent allies. The AI's `expected_damage_dealt` calc MUST use `DamageCalc.preview()` which already accounts for aura. AI does NOT replicate the aura math itself.

### EC-AI-8. Boss (Coordinator) without commander target

Chapter-1: if 유비 is not in the player party (player chose 황충 over 유비), Coordinator falls back to standard utility + `target_has_command_aura == false` for all candidates. Bonus path is silently zero. No fallback rule needed.

### EC-AI-9. Tie at top score

§CR-AI-4 step 4 cascade always produces a unique winner due to integer secondary keys (`unit_id`, `coord.y`, `coord.x`). True ties impossible by construction (provided unit_ids are unique within a battle).

### EC-AI-10. AI unit has DEFEND_STANCE active

Per turn-order CR-13, a unit with DEFEND_STANCE has `acted_this_turn = true` already at turn start (or was DEFEND-locked). AI is not invoked for such units (TurnOrderRunner skips them). No special handling needed in AISystem.

### EC-AI-11. Unit list contains 0 player units (impossible at AI turn)

Defensive: if `player_units_alive == 0`, AI submits WAIT; battle should be terminated by victory_condition_detected in the same frame (turn-order CR-N). AI is not the authority for victory.

### EC-AI-12. WorkerThreadPool offloading (deferred to post-MVP)

For MVP, scoring runs on the main thread. If the 500ms budget becomes a problem on low-end Android hardware (push_warning frequency in profiling), defer scoring to `WorkerThreadPool` per ADR-0019 §Threading. Determinism contract (CR-AI-5) makes thread-safe execution trivial — no shared state.

## 6. Dependencies

This system DEPENDS on:

- **Grid Battle (ADR-0014)** — owns `ai_action_requested` emission + `ai_action_ready` consumption + 500ms timeout enforcement + WAIT substitution + soft-lock counter. AI System is a pure consumer + responder.
- **Turn Order (ADR-0011 / turn-order.md)** — emits `unit_turn_started(unit_id)` consumed transitively (Grid Battle proxies as `ai_action_requested`). AI does not subscribe directly per CR-AI-6.
- **HP/Status (ADR-0010 / hp-status.md)** — provides current_hp + status_effects via snapshot. AI reads only.
- **Damage Calc (ADR-0012)** — `DamageCalc.preview(attacker, defender, modifiers) → DamagePreview` is the read-only damage estimator. AI relies on this for utility scoring; no parallel damage math in AI.
- **Map/Grid (ADR-0004)** — `MapGrid.get_movement_range(unit, budget)` + `get_attack_range(unit, target)` provide the candidate set. AI calls these via the snapshot facade, not directly.
- **Unit Role (ADR-0009 / unit-role.md)** — provides class info read-only. Archetype is orthogonal to class (CR-AI-2).
- **Balance/Data (ADR-0006)** — owns the 10 tuning constants in §F-AI-Constants table. AI reads via `BalanceConstants.get_const(key)`.
- **Scenario Progression (ADR-0017 / scenario-progression.md)** — provides `ChapterDefinition` containing enemy roster + archetype assignments + chokepoint tiles. AI reads only at chapter-load.
- **Formation Bonus (post-MVP)** — when this lands, snapshot includes `formation_state` field; AI's holder/coordinator utility benefits from it. MVP utility falls back to manual `adjacent_ally_count` query.

This system is DEPENDED ON BY:

- **Grid Battle (ADR-0014)** — calls AI System via signal protocol; without AI, enemy units would have no behavior. Sprint-7+ implementation order: AI ships in same sprint as ScenarioRunner impl OR ScenarioRunner impl uses inline mock AI (deferred).
- **Battle HUD (ADR-0015)** — displays "AI thinking..." indicator during AI turn (UI-GB-N to be added by battle-hud GDD revision). Indicator visible iff `ai_action_ready` not received within 100ms after `ai_action_requested`.
- **Chapter authoring** — chapter definitions assign archetypes to enemy units; without GDD-defined vocabulary (CR-AI-3), authoring is blocked.

## 7. Tuning Knobs

| Knob | Default | Tuning effect | Where to change |
|---|---|---|---|
| `AGGRESSOR_KILL_BONUS` | 50.0 | Increase → aggressor more aggressively chases finishers | `BalanceConstants` (post-MVP) / inline default for MVP |
| `AGGRESSOR_WEAKNESS_WEIGHT` | 20.0 | Increase → aggressor focuses fire harder | same |
| `AGGRESSOR_COUNTER_DISCOUNT` | 0.7 | Increase → aggressor more reckless | same |
| `SKIRMISHER_RANGED_TARGET_BONUS` | 30.0 | Increase → priority on player archers | same |
| `SKIRMISHER_SAFE_DISTANCE_BONUS` | 25.0 | Increase → kites harder | same |
| `SKIRMISHER_MELEE_PENALTY` | 40.0 | Increase → panics out of melee earlier | same |
| `HOLDER_CHOKEPOINT_BONUS` | 40.0 | Increase → anchors at choke even when player out of range | same |
| `HOLDER_OVEREXTEND_PENALTY` | 60.0 | Increase → never leaves formation | same |
| `COORDINATOR_COMMANDER_TARGET_BONUS` | 60.0 | Increase → tunnel-vision on commander | same |
| `COORDINATOR_RALLY_BONUS` | 80.0 | Increase → rallies more often | same |
| `AI_DECISION_TIMEOUT_MS` | 500 | Lower → harsher (more WAIT substitutions) | grid-battle.md CR-3 (cross-system) |
| Per-archetype "willingness to die" curve | derived from counter_discount × counter_damage_estimate | Tunable via counter_discount constants | F-AI-1..4 |
| `MAX_CANDIDATES` cap | 200 | Lower → faster but might miss long-range plays | inline constant for MVP |

**Tuning workflow**: change one constant, run chapter-1 simulation, observe ending distribution (HISTORICAL / PARTIAL / REWRITTEN / DEFEAT) shift. Target: chapter-1 produces ~30% REWRITTEN + ~40% PARTIAL + ~25% HISTORICAL + ~5% DEFEAT in skilled-but-not-perfect play (matches game-concept §MVP "어렵지만 가능"). If REWRITTEN is too easy (>50%), raise `AGGRESSOR_KILL_BONUS` + `HOLDER_CHOKEPOINT_BONUS`. If DEFEAT too common (>20%), lower `COORDINATOR_RALLY_BONUS` + raise `SKIRMISHER_MELEE_PENALTY` (so they don't lock down player melee too hard).

## 8. Acceptance Criteria

### AC-AI-1. Signal protocol compliance

Given a fresh battle with 4 enemy units of mixed archetypes, when `ai_action_requested(unit_id, snapshot)` fires for each, then `ai_action_ready(unit_id, command)` MUST be emitted within 500ms for each, in arbitrary order. Test: `tests/integration/ai/ai_signal_protocol_test.gd`.

### AC-AI-2. Determinism

Given identical `BattleStateSnapshot` + identical archetype assignment + identical `unit_id` + identical `round_number`, `AISystem.decide(...)` MUST return field-identical `AIActionCommand`. Test: `tests/unit/ai/ai_determinism_test.gd` runs 100 invocations of each archetype with cloned snapshots, asserts all 100 return same `action_type`, `move_target`, `attack_target`.

### AC-AI-3. Archetype differentiation

Given identical battle state + 4 different archetype assignments to the SAME unit, the 4 resulting `AIActionCommand` outputs MUST differ in at least 1 field for at least 50% of synthetic test scenarios (proves archetypes actually behave differently, not converging to same action under standard conditions). Test: `tests/unit/ai/ai_archetype_differentiation_test.gd`.

### AC-AI-4. Aggressor finishing behavior

Given Aggressor adjacent to a player unit at HP_pct ≤ 0.30 + that attack would kill, AI MUST submit ATTACK (not MOVE / not WAIT / not DEFEND). Tested across 5 scenarios with different counter-attack risks; 5/5 must return ATTACK on the kill target. Test: `tests/unit/ai/ai_aggressor_finishing_test.gd`.

### AC-AI-5. Skirmisher kiting

Given Skirmisher with range 2 + player melee unit at distance 1, AI MUST submit MOVE to a tile at distance ≥ 3 (kite away) and ATTACK only if the kite leaves a valid attack target in range. Test: `tests/unit/ai/ai_skirmisher_kiting_test.gd`.

### AC-AI-6. Holder chokepoint anchoring

Given Holder at distance 1 from designated chokepoint + 0 player units in attack range, AI MUST submit MOVE-to-chokepoint OR WAIT (if already at chokepoint), NOT advance toward the player. Test: `tests/unit/ai/ai_holder_chokepoint_test.gd`.

### AC-AI-7. Coordinator commander targeting

Given Coordinator with 유비 (`passive_id == &"command_aura"`) in attack range AND another non-commander player unit also in attack range with HIGHER expected damage, AI MUST submit ATTACK on 유비 (commander priority overrides expected-damage maximization). Test: `tests/unit/ai/ai_coordinator_commander_priority_test.gd`.

### AC-AI-8. Coordinator rally usage

Given Coordinator with ≥2 adjacent allies + rally skill off-cooldown, AI MUST submit USE_SKILL(rally) on its first available turn. Test: `tests/unit/ai/ai_coordinator_rally_test.gd`.

### AC-AI-9. Pillar 2 isolation

Static lint asserts `grep -rE "hidden_fate_condition_progressed|DestinyBranchChoice|destiny_branch_chosen" src/feature/ai/*.gd` returns 0 matches. Test: `tools/ci/lint_ai_no_destiny_branch_reference.sh`. Codifies CR-AI-8 Pillar 2 architectural lock.

### AC-AI-10. No GameBus state read

Static lint asserts `grep -rE "MapGrid\\.|HPStatusController\\.|TurnOrderRunner\\." src/feature/ai/ai_system.gd` returns 0 matches outside `_on_ai_action_requested` snapshot parameter usage. Test: `tools/ci/lint_ai_no_direct_state_read.sh`. Codifies CR-AI-6.

### AC-AI-11. Decision time budget

P99 decision time across 100 randomized snapshots MUST be < 200ms on mid-tier Android reference hardware (Pixel 7-class Adreno 610). Test: `tests/performance/ai/ai_decision_p99_test.gd`. If P99 exceeds, profile + simplify before deferring to WorkerThreadPool (post-MVP).

### AC-AI-12. Chapter-1 ending distribution sanity

Run automated chapter-1 simulation with a "skilled scripted player" (predefined optimal action sequence) 100 times. Distribution MUST roughly match: REWRITTEN 25-40% / PARTIAL 30-50% / HISTORICAL 15-30% / DEFEAT 0-10%. If outside this range, AI tuning is broken — see §Tuning Knobs workflow. Test: `tests/integration/ai/chapter_1_distribution_test.gd` (deferred until ScenarioRunner ships).

### AC-AI-13. Soft-lock recovery

Given an AISystem with deliberate fault injection (force `decide()` to throw or never return), GridBattleController's CR-3 timeout MUST fire at 500ms + WAIT substitution MUST occur + `ai_soft_lock_counter` MUST increment. Test: `tests/integration/ai/ai_softlock_recovery_test.gd`.

### AC-AI-14. Save/Load reproduces AI behavior

Given a save mid-battle (CP-1 anchor) + same chapter restored, AI's NEXT decision for the same unit MUST be identical to the original session's pre-save decision. Test: `tests/integration/ai/ai_save_load_determinism_test.gd` (deferred until Save/Load #17 VS GDD lands).

---

## Open Questions

1. **OQ-AI-1**: Does the 4-archetype vocabulary cover chapter-2..N enemy variety? — DEFERRED. MVP scope is chapter-1 (장판파); chapter-2 enemy roster is part of a future scenario authoring pass. If a 5th archetype emerges, ratify via GDD revision + ADR-0019 amendment.
2. **OQ-AI-2**: Should AI introspect HP-status effects (POISON tick prediction, DEMORALIZED radius)? — MVP NO. Status effect awareness adds 2-3 more terms to each utility function. Defer until post-MVP if AI feels too dumb in status-heavy fights.
3. **OQ-AI-3**: Should boss (Coordinator) AI know about its OWN passive aura's value, weighting "stay near allies" stronger? — Currently CR-AI-3 says yes (`+ 35.0 * IF(adjacent_ally_count(unit.position) >= 2, 1.0, 0.0)`). Tuning may show this is too strong (boss never repositions). Confirm via chapter-1 simulation.
4. **OQ-AI-4**: WorkerThreadPool offload threshold — at what hardware tier does it become required? — DEFERRED to perf profiling on reference Android.
5. **OQ-AI-5**: AI difficulty levels (easy / normal / hard)? — POST-MVP. MVP ships single difficulty tuned to "어렵지만 가능". Post-MVP would scale archetype constants per difficulty (e.g., easy = aggressor with reduced kill bonus = doesn't finish).

---

## Cross-References

- `design/gdd/game-concept.md` §Pillar 3 — "모든 무장에게 자리가 있다" (the player-fantasy AI must serve)
- `design/gdd/grid-battle.md` CR-3 + CR-3a — `ai_action_requested` / `ai_action_ready` signal protocol + 500ms timeout + action vocabulary
- `design/gdd/turn-order.md` — `unit_turn_started` signal lifecycle (consumed transitively via Grid Battle)
- `design/gdd/unit-role.md` — 5 unit classes (Scout / Cavalry / Infantry / Normal / Special); archetype is ORTHOGONAL to class per CR-AI-2
- `design/gdd/damage-calc.md` — `DamageCalc.preview()` read-only path used in utility scoring
- `design/gdd/map-grid.md` — Dijkstra movement-range queries used in candidate enumeration
- `design/gdd/scenario-progression.md` — `ChapterDefinition` carries archetype assignments + chokepoint tiles
- `prototypes/chapter-prototype/battle_v2.gd:596-678` — naive prototype AI (greedy step + nearest target); served as design reference for Aggressor archetype but DOES NOT match this GDD's MVP scope (single archetype only, no utility scoring)
- `docs/architecture/ADR-0019-ai-system.md` — to be authored next session per same-session-ban discipline
- `production/gate-checks/pre-prod-to-prod-2026-05-04.md` — gate-check that requested this GDD (path-to-PASS item #4)
