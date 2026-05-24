# ADR-0022: Civilian System (Stranded Escort Tokens)

## Status
Proposed (2026-05-24 — sprint-15+ post-Build-mode; authoring under `WORKFLOW.md` Build-not-Ratify, gate-check dormant. Anchored at `design/narrative/branch-distribution-plan.md` §9 architecture gap analysis + `design/quick-specs/ch05-civilian-evacuation.md` Section 3.1 decision. Same-patch ADR-0017 minor amendment ratifies `civilian_config: Dictionary` `@export` field per Evolution Rule #4.)

## Date
2026-05-24

## Last Verified
2026-05-24 against `docs/engine-reference/godot/VERSION.md` (Godot 4.6, pinned 2026-04-16).

## Decision Makers
Solo dev — autonomous authoring per Build-mode discipline. ADR ratifies the `design/narrative/branch-distribution-plan.md` §4.1 ch05 ★ trigger's mechanical substrate into architecture binding suitable for sprint-15+ implementation.

## Summary

Define **CivilianToken** as a `class_name CivilianToken extends RefCounted` lightweight transient data object representing one *stranded civilian* on the battle grid. State machine has 3 states (`IDLE` / `ESCORTED` / `SAVED`). Token entities are **owned and managed by GridBattleController** (battle-scoped, instanced at chapter init from `ChapterDefinition.civilian_config`, discarded at battle end). No new GameBus signals; no new autoloads; no Node subclass. The fate counter `_fate_civilians_escorted: int` (already declared at `grid_battle_controller.gd:419` as a stub) becomes the single source-of-truth integration point — increment happens at the SAVED-transition site (`_civilian_commit_save(token_id)` private method). Pickup logic = end-of-turn 8-neighbor adjacency check; Save logic = carrier reaches `col <= civilian_config.evacuate_zone_max_col`; Carrier-death recovery = token returns to IDLE at carrier's last cell (LOST-counter rejected for narrative + UX reasons). 3 forbidden_patterns proposed: `civilian_token_node_subclass` (RefCounted-only discipline) + `civilian_token_static_var` (instance state only) + `civilian_escorted_counter_direct_mutation` (single source-of-truth lock on `_civilian_commit_save`).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Feature (battle-scoped subsystem, RefCounted entity owned by GridBattleController) |
| **Knowledge Risk** | LOW (Godot 4.6 pinned; no post-cutoff APIs required — RefCounted + enums + typed `@export` Dictionary are all pre-4.4 stable) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `design/narrative/branch-distribution-plan.md` §4.1 + §9, `design/quick-specs/ch05-civilian-evacuation.md`, `design/gdd/destiny-branch.md` (CR-13 hidden_branch_key + HiddenConditionEvaluator `fate_threshold`), `design/gdd/scenario-progression.md` (ChapterDefinition schema — ADR-0017 minor amendment), `docs/architecture/ADR-0014-grid-battle-controller.md` (battle-scoped Node 6th invocation precedent — GridBattleController owns CivilianToken collection), `docs/architecture/ADR-0017-scenario-progression.md` (ChapterDefinition typed Resource — same-patch amendment for `civilian_config` field), `docs/architecture/ADR-0018-destiny-branch.md` (DestinyBranchJudge consumes `civilians_escorted` field via HiddenConditionEvaluator). |
| **Post-Cutoff APIs Used** | NONE. CivilianToken uses `class_name X extends RefCounted` (1.0+ stable) + typed `enum State` (1.0+) + `static func make()` factory pattern (4.0+ stable) + typed `@export var civilian_config: Dictionary` on ChapterDefinition (4.0+ stable). No `@abstract`, no `WorkerThreadPool`, no `Resource.duplicate_deep()`. |
| **Verification Required** | (1) `CivilianToken.new()` allocation is RefCounted-cheap; ch05 spawns 5 tokens at chapter init — negligible memory footprint (~<200B per token). (2) GridBattleController `_civilian_commit_save(token_id)` mutates `_fate_civilians_escorted` exactly once per SAVED transition (no double-fire on edge cases — token already SAVED returns early). (3) Carrier-death recovery places token at last cell — falls back to nearest non-occupied non-FIRE 4-neighbor cell if last cell now occupied. (4) Static lint `tools/ci/lint_civilian_token_no_node_subclass.sh` rejects any `extends Node` / `extends Node2D` / `extends Control` in `src/feature/grid_battle/civilian_token.gd`. (5) Static lint `tools/ci/lint_civilian_token_no_static_var.sh` rejects any `static var` in CivilianToken or GridBattleController civilian-related fields. (6) Static lint `tools/ci/lint_fate_civilians_escorted_single_mutator.sh` rejects any `_fate_civilians_escorted = ` / `_fate_civilians_escorted +=` outside the `_civilian_commit_save` method body. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0014 Grid Battle Controller** (Accepted) — owns CivilianToken collection lifetime (battle-scoped); fate_data emission of `civilians_escorted` field is wired at line 3244. **ADR-0017 Scenario Progression** (Accepted) — `ChapterDefinition` typed Resource carries new `civilian_config: Dictionary` field (same-patch minor amendment, this ADR). **ADR-0018 Destiny Branch** (Accepted) — consumes `fate_data.civilians_escorted` via HiddenConditionEvaluator `fate_threshold` predicate; no protocol change required (the field is already in the 13+5 fate_data schema per ADR-0014). |
| **Enables** | **ch05 ★ trigger `WIN_xinye_civilians_saved`** — first newly-introduced ★ branch in the MVP per `design/narrative/branch-distribution-plan.md` §4.1, Pillar 2 mechanical proof point. Currently unreachable (counter stub); this ADR + companion quick-spec implementation make it reachable. **Future Vision ch06/ch20 reuse** — if `branch-distribution-plan.md` extends civilian evacuation mechanic to 장판파 (ch06, default-only currently but candidate) or 맥성 (ch20, Full Vision cluster), this ADR's RefCounted token pattern is the foundation; new ADR amendment NOT required unless behavior diverges. |
| **Blocks** | **`design/quick-specs/ch05-civilian-evacuation.md` Section 5 commits 3-5 (impl arc)** — schema extension + entity + visualization + tests cannot land until this ADR Proposed. |
| **Ordering Note** | This ADR is authored AFTER the quick-spec (`design/quick-specs/ch05-civilian-evacuation.md`) per Build-mode precedent (Spec → ADR → Impl). The spec specifies the WHAT (5 tokens, ★ at 3+, state machine semantics); this ADR specifies the HOW (class form RefCounted, single-source-of-truth `_civilian_commit_save`, lint patterns, ADR-0017 schema extension shape). |

## Context

### Problem Statement

`design/narrative/branch-distribution-plan.md` §4.1 declares ch05 신야 화공 as the MVP's **first newly-introduced ★** (Pillar 2 first mechanical proof). The chapter already has scaffold (`branch_table`, `hidden_branch_key`, `hidden_condition: civilians_escorted >= 3`, 3-variant Beat 8 prose) and the fate counter stub (`_fate_civilians_escorted: int = 0`). **What is missing** is the *increment site* — there is no civilian entity, no pickup logic, no SAVED-transition site. The counter is permanently 0; the ★ branch is mechanically unreachable.

`design/narrative/branch-distribution-plan.md` §9 flagged "Civilian NPC entity" as the heaviest architecture lift in the plan, listing a simpler alternative: "civilian = map terrain feature." The quick-spec (`ch05-civilian-evacuation.md`) decided neither extreme — instead a **Stranded Escort Token** model: passive data objects with a 3-state machine, owned by GridBattleController, with no autonomous behavior. This ADR ratifies that decision into architecture, answers 5 questions the spec did not bind:

1. **Class form** — `Node`? `RefCounted`? `Resource`? Battle-scoped vs scene-tree-mounted?
2. **Ownership** — owned by GridBattleController? By a new dedicated subsystem (CivilianSystem Node)? By BattleScene?
3. **State machine enforcement** — runtime asserts in setters? `@abstract` test seam (mirrors DestinyBranchJudge)? Free-form state property?
4. **Counter increment integrity** — single source-of-truth lock pattern (forbidden_pattern lint)? Or just discipline?
5. **Future reuse boundary** — ch05-only scope? Or pre-emptive ADR for Full Vision ch06/ch20?

### Constraints

**Technical:**

- `RefCounted` is the correct base — CivilianToken is a pure data object with a simple state machine. It does NOT need scene-tree presence (no `_ready` / `_exit_tree` lifecycle), does NOT emit signals (caller manages all transitions), and does NOT participate in physics or rendering (visualization is a separate sibling node spawned by GridBattleController). `Node` is wrong (overhead + lifecycle complexity for no benefit). `Resource` is wrong (no save/load requirement — battle is single-session, no mid-battle save).
- `static var` is FORBIDDEN in `civilian_token.gd` (battle-scoped 6+ invocation discipline carry-over — instance state only). Multiple battles must produce independent token populations.
- GridBattleController owns the token collection (`var _civilian_tokens: Array[CivilianToken] = []`) and the increment method (`_civilian_commit_save(token_id) -> void`). NO other module mutates `_fate_civilians_escorted` (single source-of-truth lock — forbidden_pattern `civilian_escorted_counter_direct_mutation`).
- Token IDs are int (assigned sequentially at spawn time = 0, 1, 2, ..., N-1) — no global uniqueness requirement beyond a single battle.

**Architecture-registry constraints (carried from prior ADRs):**

- **`grid_battle_controller_static_state` forbidden_pattern** — battle-scoped lifecycle. Mirrored as `civilian_token_static_var`.
- **Single-emitter rule** — CivilianToken emits NO signals. Increment + state transitions are private to GridBattleController (no GameBus traffic, no LOCAL signals). Caller-controlled.
- **Hot-path discipline** — pickup adjacency check fires on player turn-end (low frequency: ~5x per round × 5 rounds = 25 invocations in worst-case ch05). Allocation-free is NOT a hard requirement at this frequency, but the implementation SHOULD reuse arrays / iterate without temp dict allocations.

**Performance budget:**

- Token allocation: 5 × ~150B = ~750B per battle. Negligible.
- Pickup check: end-of-turn handler iterates IDLE tokens (max 5) × 8 neighbors × O(unit lookup) = ~40 checks per player turn end. Well under 0.1ms.
- Save check: carrier movement handler iterates ESCORTED tokens (max N where N = # active carriers, ≤5) × 1 col check = ~5 checks per movement. Sub-microsecond.

### Requirements

- **Must encapsulate** the 3-state machine `IDLE / ESCORTED / SAVED` in `CivilianToken` with state transitions only via internal methods (no direct `token.state = ...` from callers — runtime guard via `assert()`).
- **Must own** the token collection inside GridBattleController (battle-scoped lifetime, RAII via RefCounted).
- **Must implement** `_civilian_commit_save(token_id) -> void` as the SOLE mutator of `_fate_civilians_escorted` (lint-enforced).
- **Must recover** ESCORTED tokens to IDLE at the carrier's last cell on carrier death (HP <= 0 transition); fallback to nearest non-occupied non-FIRE 4-neighbor if last cell now occupied.
- **Must remain inert** under enemy adjacency (token does NOT flee, does NOT get LOST, does NOT take damage — passive).
- **Must spawn** tokens at chapter init from `ChapterDefinition.civilian_config.positions: Array[Array[int]]` (each `[col, row]`). Empty/missing `civilian_config` = no token spawn (default for all chapters except ch05).
- **Must update** `ChapterDefinition` schema same-patch (ADR-0017 minor amendment — Evolution Rule #4, NOT supersession).
- **Must NOT introduce** any new GameBus signal, autoload, or LOCAL signal (caller-controlled all transitions).

## Decision

Define **CivilianToken** as `class_name CivilianToken extends RefCounted` with a 3-state enum and a private state mutator pattern. Define **GridBattleController extensions** for ownership + pickup + save + death-recovery. Amend **ADR-0017 ChapterDefinition** with one new `@export var civilian_config: Dictionary = {}` field same-patch.

### Decision §1. `CivilianToken` Class Form

```gdscript
## CivilianToken — battle-scoped data object representing one stranded civilian.
## Owned by GridBattleController; lifetime = single battle. NO scene-tree
## presence (visualization is a separate sibling Node spawned by GridBattleController).
class_name CivilianToken
extends RefCounted

enum State { IDLE = 0, ESCORTED = 1, SAVED = 2 }

var token_id: int = -1
var state: State = State.IDLE
var grid_cell: Vector2i = Vector2i.ZERO     # IDLE: token's current cell; SAVED/ESCORTED: stale-write-OK
var carrier_unit_id: int = -1                # ESCORTED: bound carrier; IDLE/SAVED: -1

static func make(id: int, initial_cell: Vector2i) -> CivilianToken:
    var t := CivilianToken.new()
    t.token_id = id
    t.grid_cell = initial_cell
    return t

## Bind to a player unit (IDLE → ESCORTED). Caller must verify prior state.
func bind_to_carrier(unit_id: int) -> void:
    assert(state == State.IDLE, "CivilianToken.bind_to_carrier: not IDLE (token_id=%d)" % token_id)
    assert(unit_id >= 0, "CivilianToken.bind_to_carrier: invalid unit_id (%d)" % unit_id)
    state = State.ESCORTED
    carrier_unit_id = unit_id

## Commit save (ESCORTED → SAVED). Caller must verify prior state + carrier in evacuate-zone.
func commit_save() -> void:
    assert(state == State.ESCORTED, "CivilianToken.commit_save: not ESCORTED (token_id=%d)" % token_id)
    state = State.SAVED
    carrier_unit_id = -1

## Recover after carrier death (ESCORTED → IDLE). Caller provides recovery cell.
func recover_to_idle(recovery_cell: Vector2i) -> void:
    assert(state == State.ESCORTED, "CivilianToken.recover_to_idle: not ESCORTED (token_id=%d)" % token_id)
    state = State.IDLE
    grid_cell = recovery_cell
    carrier_unit_id = -1
```

Pure data class + 3 mutators with `assert()` guards. NO signals, NO autoload reference, NO Node subclassing. Allocation footprint per instance: ~150B (1 int + 1 enum + 1 Vector2i + 1 int + RefCounted overhead).

### Decision §2. GridBattleController Ownership + Methods

GridBattleController gains 4 new private members + 4 new private methods:

```gdscript
# In grid_battle_controller.gd:
var _civilian_tokens: Array[CivilianToken] = []
var _civilian_evacuate_zone_max_col: int = -1     # -1 = no civilian system active for this chapter

func _civilian_spawn_from_config(config: Dictionary) -> void:
    # Read civilian_config.positions + evacuate_zone_max_col, populate _civilian_tokens.
    ...

func _civilian_check_pickup_for_unit(player_unit_id: int) -> void:
    # End-of-player-turn 8-neighbor adjacency check; first IDLE token found = ESCORTED bind.
    # Skip if unit already has an ESCORTED token (capacity 1).
    ...

func _civilian_check_save_for_unit(carrier_unit_id: int) -> void:
    # Called after each player movement; if carrier has ESCORTED token AND carrier.col <= zone_max_col,
    # token.commit_save() + _civilian_commit_save(token_id) + visualization despawn signal.
    ...

func _civilian_commit_save(token_id: int) -> void:
    # SOLE mutator of _fate_civilians_escorted. lint-enforced.
    _fate_civilians_escorted += 1
    # ... visualization notification ...

func _civilian_recover_on_carrier_death(dead_unit_id: int) -> void:
    # When a player unit dies, search for ESCORTED token with carrier_unit_id == dead_unit_id;
    # token.recover_to_idle(last_cell or nearest_non_occupied_non_FIRE_4_neighbor).
    ...
```

`_civilian_evacuate_zone_max_col = -1` sentinel = chapter has no civilian system (no `civilian_config` in JSON). All civilian methods short-circuit when this sentinel is set.

### Decision §3. ChapterDefinition Schema (ADR-0017 Minor Amendment)

Add ONE new field same-patch:

```gdscript
# In src/core/payloads/chapter_definition.gd:

## Optional civilian token config for chapters with stranded-escort ★ trigger.
## Empty Dictionary = no civilian system active (default for all chapters except ch05).
## Runtime shape: {
##   "positions": Array[Array[int]] — each inner array is [col, row],
##   "evacuate_zone_max_col": int — carrier reaches col <= this → token SAVED
## }
## Authored chapters that omit this field get the empty-Dictionary default.
##
## Owned by ADR-0022 Civilian System. Read by GridBattleController._civilian_spawn_from_config
## at chapter init. Validated by ScenarioRunner EC-SP-8 validation pipeline (positions in-bounds,
## evacuate_zone_max_col in [0, map.width)).
@export var civilian_config: Dictionary = {}
```

ADR-0017 minor amendment block (Evolution Rule #4 — NOT supersession; field count grows by 1; no breaking change to existing chapters since default empty = current behavior preserved).

### Decision §4. Forbidden Patterns (3 net-new lint rules)

1. **`civilian_token_node_subclass`** — `civilian_token.gd` MUST extend `RefCounted` (NOT `Node` / `Node2D` / `Control`). Lint: grep `extends (Node|Node2D|Control|CanvasItem)` in `src/feature/grid_battle/civilian_token.gd`.
2. **`civilian_token_static_var`** — NO `static var` declarations in CivilianToken or in GridBattleController civilian-related fields (`_civilian_*`). Battle-scoped lifetime discipline.
3. **`civilian_escorted_counter_direct_mutation`** — `_fate_civilians_escorted = ` / `_fate_civilians_escorted +=` / `_fate_civilians_escorted -=` are ONLY allowed inside the body of `_civilian_commit_save` method. Lint: AST-style grep restricted by enclosing-function.

### Decision §5. No New GameBus Signals

CivilianToken emits NOTHING. State transitions are private to GridBattleController + visualization sibling node (visualization can read GridBattleController public `get_civilian_tokens()` snapshot for redraws; no signal-driven push). This honors the project's GameBus single-emitter discipline + reduces test surface (no signal subscriptions to verify in unit tests; state-machine tests are direct method assertions on CivilianToken).

## Alternatives Considered

### Alternative 1: Autonomous Civilian NPC (plan §4.1 original)
Civilians as self-moving NPCs with AI behavior (auto-walk west each turn, halt on enemy adjacency, evacuate-zone reach = SAVED). **Rejected** — this is plan §9's explicit "heaviest architecture lift" — requires `Side.CIVILIAN` enum addition + AISystem extension + new turn-order participants + collision rules. ROI low for single-chapter use; the felt experience of "I rescued them" is stronger when player is the active agent (escort verb in Beat 3 narrative is "함께 호송해 빠져나갈 수 있다면" — *active player verb*, not "they fled themselves").

### Alternative 2: Pure Map Terrain Feature (plan §9 minimal)
Civilians as special tile flags on MapGrid; player unit walks onto tile = +1, turn-end enemy adjacency = -1. **Rejected** — no "carrier" relationship; the "escort" narrative collapses to "step on tile" mechanic. Loses Pillar 2's emotional weight (the player's choice to FERRY rather than ENGAGE). Also requires MapGrid schema extension that's heavier than a CivilianToken collection on GridBattleController.

### Alternative 3: Token as `Resource` (savable)
Saves a CivilianToken state per battle via Save/Load. **Rejected** — battle is single-session; no mid-battle save in ADR-0003. RefCounted is sufficient; Resource overhead (ResourceLoader/Saver round-trip) is unused weight.

### Alternative 4: Token as `Node2D` (own scene-tree mounted entity)
Token spawns itself as a scene-tree-mounted Node2D with its own visualization. **Rejected** — couples entity state with visualization at the same node, harder to test (need full SceneTree for unit tests), violates separation of concerns. Spec Section 4.3 already separates visualization concerns; this ADR honors that.

### Alternative 5: New dedicated `CivilianSystem` Node subsystem (mirror AISystem)
A battle-scoped Node subsystem (7th invocation of pattern after AISystem) owning token collection + pickup/save logic, GridBattleController only emits signals it subscribes to. **Rejected** — over-engineered for single-chapter scope. AISystem (ADR-0019) handles every battle's AI; CivilianSystem would handle 1 of 16 chapters. Direct GridBattleController ownership is cheaper, simpler, and revisitable if a 2nd chapter adopts.

### Alternative 6: Single-token-cap = 2 (multi-civilian escort)
Carrier carries up to 2 ESCORTED tokens; SAVED commits both on zone reach. **Rejected** — UI complexity (overlay marker for 1 vs 2 tokens), narrative redundancy ("어깨에 하나 + 등에 둘" awkward), no tactical depth (player would always max out). Single-cap = 1 is KISS + felt.

## Consequences

### Positive

- ch05 ★ trigger reachable — Pillar 2 first mechanical proof unlocked.
- Lightweight footprint — ~750B per battle, sub-millisecond pickup/save checks.
- No new GameBus signals + no new autoloads — global namespace + signal contract preserved.
- Lint-enforced single source-of-truth for `_fate_civilians_escorted` — prevents future drift if more chapters adopt.
- Reusable foundation for Future Vision ch06/ch20 civilian scenarios — same RefCounted + state machine pattern, no architectural rework needed unless new behaviors (autonomous movement, multi-cap) emerge.

### Negative

- Adds 1 new typed `class_name` (CivilianToken) — class registry +1 entry; mitigated by G-12 collision-check (no project / engine collisions found for "CivilianToken").
- ChapterDefinition schema grows by 1 field (low-cost amendment, but a real schema change).
- ch05 chapter init path now has a new branch (read civilian_config, spawn tokens) — small additional test surface.
- Visualization is a separate sibling node (per spec Section 4.3) — extra wiring between data + render layers; mitigated by GridBattleController public `get_civilian_tokens()` snapshot accessor.

### Neutral

- No save/load impact (battle single-session, token collection discarded at battle end).
- No multiplayer impact (project is single-player MVP).
- No performance impact at chapter-1-15 (no civilian_config, all civilian methods short-circuit via `_civilian_evacuate_zone_max_col == -1`).

## Risks

| ID | Risk | Probability | Mitigation |
|----|------|-------------|------------|
| R-1 | Carrier-death-recovery falls back to nearest non-occupied non-FIRE 4-neighbor — edge case where ALL 4 neighbors are occupied/FIRE | Low | Token despawns silently (LOST in the implementation sense, but counter unaffected — design choice per OQ-2). Acceptable for ch05 narrow map; revisit if ch06+ has tighter spaces. |
| R-2 | `_civilian_check_pickup_for_unit` fires on player turn-end for ALL 5 player units in ch05 — pickup order = unit_id ascending; if multiple units adjacent to same token, deterministic but may feel arbitrary | Low | Spec OQ-6 documents this as deterministic; documented in CivilianToken doc-comments. |
| R-3 | Lint regex for `civilian_escorted_counter_direct_mutation` is AST-shaped (function-body scope) — bash regex insufficient; needs awk flag/next pattern (TG-3) | Medium | Use awk `func _civilian_commit_save` start-marker + `^func ` end-marker + flag/next pattern; cross-reference TG-3 in lint script comment. |
| R-4 | Token visualization (commit 5 separately) may need to reach into CivilianToken to read state — couples renderer with entity | Low | GridBattleController exposes `get_civilian_tokens() -> Array[CivilianToken]` (read-only snapshot accessor); visualization polls per redraw + does NOT mutate state. |

---

## ADR-0017 §Amendment 2026-05-24 (#1) — `civilian_config` Field Addition

**Type**: Minor amendment per Evolution Rule #4 (field addition, NOT supersession). ADR-0017 base remains Accepted; this amendment adds one optional field.

**Field**:
```gdscript
@export var civilian_config: Dictionary = {}
```

**Default**: empty Dictionary = no civilian system active. All existing chapters (ch01-ch04, ch06-ch16, Wei ch01-ch05, mvp_wei chapters) retain current behavior with no JSON change required.

**Runtime shape** (when non-empty):
```json
{
  "positions": [[col, row], ...],
  "evacuate_zone_max_col": int
}
```

**Validation**: ScenarioRunner EC-SP-8 pipeline asserts positions in-bounds of map AND `evacuate_zone_max_col in [0, map.width)` AND positions.length <= 16 (sanity cap).

**Cross-reference**: governed by **ADR-0022 Civilian System** (this ADR). Schema change rationale + alternatives consulted there.

**Migration impact**: 0 chapters require JSON update. Backwards-compatible.

---

> **Authoring note**: per Build-not-Ratify mode, this ADR is **Proposed** rather than going through `/architecture-review` immediate Acceptance. Build-mode ADRs accumulate Proposed→Accepted at next milestone gate-check resume. The spec (`design/quick-specs/ch05-civilian-evacuation.md`) + this ADR + impl commits 3-4 land in the same arc per session decision.
