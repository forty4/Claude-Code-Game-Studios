# ADR-0011: Turn Order / Action Management

## Status

Accepted (2026-04-30, via `/architecture-review` delta #8)

## Date

2026-04-30

## Last Verified

2026-04-30 (via /architecture-review delta #8 — Proposed → Accepted; 0 substantive corrections; 21 net-new TR-turn-order-002..022 registered in tr-registry.yaml v9 → v10; cross-doc obligations applied same-patch — ADR-0010 §Soft/Provisional clause (1) Soft → Ratified; ADR-0012 §Dependencies line 42 ADR-0010 + ADR-0011 clauses Soft → Ratified; ADR-0012 unit_id type batch lines 91/109/340/343 `StringName` → `int` per ADR-0001 line 153 signal-contract source-of-truth; design/gdd/turn-order.md Status flipped Designed → Accepted; design/gdd/hp-status.md + design/gdd/balance-data.md §Dependencies 하위 의존성 backfilled with Turn Order rows)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (gameplay orchestration) |
| **Knowledge Risk** | LOW — Core gameplay logic only. No physics / rendering / UI / SDL3 / D3D12 / accessibility surface touched. The single post-cutoff API surface is typed `Dictionary[int, K]` (4.4+), already validated in production by ADR-0010 HPStatusController; same precedent extension here. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md`, `design/gdd/turn-order.md`, `design/gdd/hp-status.md`, `design/gdd/damage-calc.md`, `design/gdd/grid-battle.md`, `design/gdd/unit-role.md`, `design/gdd/hero-database.md`, `design/gdd/balance-data.md`, ADRs 0001 / 0002 / 0006 / 0007 / 0009 / 0010 / 0012, `docs/registry/architecture.yaml`, `docs/architecture/architecture.md`, `docs/architecture/control-manifest.md` |
| **Post-Cutoff APIs Used** | Typed `Dictionary[int, UnitTurnState]` (Godot 4.4+, established by ADR-0010); `Object.CONNECT_DEFERRED = 1` (stable through 4.6, per breaking-changes scan); `Callable.call_deferred()` method-reference form (preferred 4.x idiom over string-based `call_deferred("method")` per project pattern). |
| **Verification Required** | None additional. ADR-0010 + ADR-0001 precedents cover all engine-level concerns; godot-specialist 2026-04-30 lean validation returned APPROVED WITH SUGGESTIONS (3 same-patch corrections all incorporated below: §UnitTurnState `snapshot()` field-by-field copy clarification + §Decision deferred-call Callable form + §Migration Plan ADR-0001 same-patch amendment for `victory_condition_detected` signal declaration). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (GameBus, Accepted 2026-04-18) — declares 3 Turn Order Domain signals + `unit_died` consumer pattern; **THIS ADR adds a 4th signal `victory_condition_detected(result: int)` via same-patch amendment** (see §Migration Plan §0). ADR-0002 (SceneManager, Accepted) — battle-scoped lifecycle teardown. ADR-0006 (Balance/Data, Accepted 2026-04-30 via /architecture-review delta #9) — `BalanceConstants.get_const(key) -> Variant` for ROUND_CAP + CHARGE_THRESHOLD. ADR-0007 (Hero DB, Accepted 2026-04-30) — `stat_agility` read for tie-break Step 1. ADR-0009 (Unit Role, Accepted 2026-04-28) — `UnitRole.get_initiative(hero, unit_class) -> int` for BI-2 + `passive_charge` / `passive_ambush` tag reads via `UnitRole.PASSIVE_TAG_BY_CLASS` const. ADR-0010 (HP/Status, Accepted 2026-04-30 delta #7) — `unit_died(unit_id: int)` consumed for queue removal (CR-7a); `unit_turn_started(unit_id: int)` provisional consumer contract that this ADR ratifies. |
| **Enables** | (1) **Ratifies ADR-0010's provisional `unit_turn_started(unit_id: int)` consumer contract** verbatim — no parameter renegotiation; ADR-0010 §Soft / Provisional clause (1) flips Soft → Ratified upon Acceptance. (2) **Ratifies ADR-0012's provisional `turn_order.get_acted_this_turn(unit_id) -> bool` query interface** AND adds `turn_order.get_current_round_number() -> int` query — closes ADR-0012's last upstream Core-layer soft-dep. **Type advisory**: ADR-0012 line 343 declares `unit_id: StringName` but ADR-0011 LOCKS `int` (matches ADR-0001 line 153 + ADR-0010 lock); queues as 4th cross-doc advisory for next ADR-0012 amendment alongside 3 prior advisories (ADR-0001 line 168 String→StringName + line 372 prose drift + ADR-0010 unit_id type from delta #7). (3) **Unblocks `turn-order` Core epic** — `/create-epics turn-order` after Acceptance via /architecture-review delta. (4) **Unblocks Grid Battle ADR + Vertical Slice readiness** — Grid Battle consumes 3 Turn Order signals + `victory_condition_detected` + emits authoritative `battle_outcome_resolved` per ADR-0001 single-owner rule. (5) **Unblocks Battle HUD ADR / Presentation epic** — HUD consumes `TurnOrderSnapshot` (Contract 3). (6) **Unblocks AI System ADR / Feature epic** — AI consumes `unit_turn_started` + `TurnOrderSnapshot` + `acted_this_turn` query for target prioritization. (7) **Resolves `architecture.md` Blocker §1** — Turn Order ↔ AI signal-inversion contract codified: AI is invoked at T4 via direct delegation (Contract 5 `request_action(unit_id, queue_snapshot)`), NOT via signal inversion. Interleaved queue (CR-1) makes player/AI ownership invisible to Turn Order logic. |
| **Blocks** | turn-order Core epic implementation (cannot start any story until this ADR is Accepted); `assets/data/balance/balance_entities.json` 2-key BalanceConstants append + lint validation (story-level same-patch obligation per ADR-0006 §6); Grid Battle Vertical Slice readiness; Battle HUD ADR ratification; AI System ADR. |
| **Ordering Note** | Last Core-layer ADR. Brings Foundation 5/5 + Core 2/2 → 3/3 + Feature 1/3 layer counts to first all-Foundation+Core-Complete state for the project. Mandatory ADR list pruned 1 → 0 (per `architecture.md` v0.5 Phase 6) before Pre-Production → Production gate post-Acceptance. |

## Context

### Problem Statement

Turn Order is the temporal orchestration core of combat. Six downstream systems — Grid Battle, Damage Calc, HP/Status, AI, Battle HUD, Formation Bonus — all read its order/state and consume its signals. Without an Accepted ADR locking module form, signal payloads, state ownership, and the query API surface, the following architectural risks compound:

1. **Module-form drift across listening + emitting + state-holding systems.** ADR-0010 established the battle-scoped Node form for stateful + listening systems (HPStatusController); ADR-0005 established the Node form for listening systems (InputRouter autoload). ADR-0011 must extend this pattern boundary (NOT the 5-precedent stateless-static pattern) without ambiguity. A misclassification would force a costly mid-implementation rewrite when story-level signal subscription and queue mutation collide.
2. **`unit_id` type drift.** ADR-0001 line 153 locks `int`; ADR-0010 locks `Dictionary[int, UnitHPState]`; ADR-0012 line 343 still declares `StringName` (stale documentation artifact). ADR-0011 must LOCK `int` and queue the cross-doc advisory for next ADR-0012 amendment, otherwise stories that consume both ADR-0011 + ADR-0012 will inherit a contradictory parameter type signature.
3. **`battle_ended` vs `victory_condition_detected` ownership ambiguity.** Turn Order GDD originally declared `battle_ended` (now updated to `victory_condition_detected` per Contract 4); ADR-0001 line 301 already mandates Grid Battle as sole emitter of `battle_outcome_resolved`. ADR-0011 must ratify the corrected contract: Turn Order detects → Turn Order emits `victory_condition_detected(result: int)` → Grid Battle consumes + emits authoritative `battle_outcome_resolved` (typed `BattleOutcome` Resource with chapter_id / final_round / surviving_units that Turn Order does not have).
4. **`unit_turn_started` consumer-side proliferation.** ADR-0010 commits HPStatusController as consumer; future Battle HUD + AI ADRs will subscribe; an unratified payload would force ADR-0010 amendment if shape changes. ADR-0011 must lock the payload (`unit_id: int`) verbatim per ADR-0010 §Soft / Provisional clause (1).
5. **Action budget state ownership.** `acted_this_turn` flag, MOVE / ACTION token states, and charge accumulation `accumulated_move_cost` could plausibly live in HP/Status (status-effect-adjacent), Unit Role (per-unit), or Hero DB (persistent). ADR-0011 must lock these as Turn-Order-scoped per-unit RUNTIME state, freed at battle teardown.

### Constraints

- **GameBus signal contract immutability** (ADR-0001): the 3 already-declared Turn Order Domain signals (`round_started`, `unit_turn_started`, `unit_turn_ended`) are emitted verbatim. The 4th signal `victory_condition_detected(result: int)` is added via this ADR's same-patch ADR-0001 amendment (§Migration Plan §0).
- **Battle-scoped lifecycle** (ADR-0002): TurnOrderRunner is created at battle-init by Battle Preparation, freed automatically with BattleScene; no autoload form (state must not persist across battles).
- **Single-emitter rule** (ADR-0001): Turn Order is the sole emitter of `round_started` / `unit_turn_started` / `unit_turn_ended` / `victory_condition_detected`. Must NOT emit non-Turn-Order-domain signals.
- **Stateless-static pattern boundary** (ADR-0005 §Alt 4 + ADR-0010 §Alt 3): pattern applies to systems that are CALLED, not to systems that LISTEN AND/OR hold mutable state. Turn Order LISTENS to `unit_died` (ADR-0010) and holds queue + per-unit token state — pattern explicitly does NOT apply.
- **Tuning-constant centralization** (ADR-0006): all 2 net-new tuning constants (ROUND_CAP, CHARGE_THRESHOLD) MUST flow through `BalanceConstants.get_const(key)`, NOT direct file reads.
- **Static initiative MVP rule** (GDD CR-6): initiative computed once at BI-2; queue rebuilt each round from same values; no dynamic re-queuing in MVP.

### Requirements

- Maintain ALIVE-units initiative-ordered queue with deterministic tie-breaking cascade (initiative DESC, stat_agility DESC, is_player_controlled DESC, unit_id ASC).
- Process per-unit T1–T7 sequence (DoT tick → death check → duration expiry → activate turn → execute action budget → mark acted → victory check) in strict order per GDD §CR-2.
- Track per-unit MOVE token + ACTION token (both binary; reset to FRESH at T4) + accumulated_move_cost (reset to 0 at T4 per F-2) + acted_this_turn flag.
- Emit 4 GameBus signals (3 Turn Order Domain + 1 victory_condition_detected) at the precise lifecycle points specified by GDD §CR-2.
- Provide synchronous read-only query API to Damage Calc (`get_acted_this_turn(unit_id: int) -> bool`, `get_current_round_number() -> int`).
- Provide pull-based snapshot to Battle HUD + AI (`get_turn_order_snapshot() -> TurnOrderSnapshot`).
- Subscribe to `GameBus.unit_died(unit_id: int)` and remove the unit from queue immediately (CR-7a) — including the case where the unit is currently ACTING (counter-attack interruption — CR-7d).
- Comply with ADR-0006 — all tuning constants via `BalanceConstants.get_const(key)`.
- Test seam: `_advance_turn(unit_id: int)` callable directly without GameBus subscription (mirrors ADR-0005 + ADR-0010 + ADR-0012 DI seam pattern; 4-precedent extension).

## Decision

**Lock `TurnOrderRunner` as a Battle-scoped Node child of BattleScene** (created on battle-init via Battle Preparation, freed automatically with BattleScene per ADR-0002). It owns:

- `_queue: Array[int]` — ordered list of ALIVE unit_ids for current round, rebuilt at R3
- `_queue_index: int` — pointer to currently ACTING unit (advances at T7)
- `_round_number: int` — initialized to 0 at BI-4, incremented at R1
- `_unit_states: Dictionary[int, UnitTurnState]` — keyed by `unit_id` matching ADR-0001 + ADR-0010 lock; per-unit MOVE / ACTION token state + accumulated_move_cost + turn_state enum + acted_this_turn
- `_round_state: RoundState` — typed enum (BATTLE_NOT_STARTED, BATTLE_INITIALIZING, ROUND_STARTING, ROUND_ACTIVE, ROUND_ENDING, BATTLE_ENDED)

It exposes 8 public methods (3 mutator + 5 read-only query), emits exactly 4 GameBus signals (3 declared in Turn Order Domain per ADR-0001 lines 152–154 + 1 `victory_condition_detected` added by §Migration Plan §0 same-patch amendment), consumes 1 GameBus signal (`unit_died` per ADR-0001 line 155), and routes ALL 2 tuning knob reads through `BalanceConstants.get_const(key)` per ADR-0006.

**Why this form**

- **Holds mutable state** (queue + per-unit token state + round counter) — disqualifies the 5-precedent stateless-static pattern.
- **Subscribes to GameBus** (`unit_died`) — disqualifies stateless-static (Callable subscription identity for static methods is undefined per GDScript 4.x; ADR-0005 §Alt 4 precedent).
- **State must reset at battle teardown** — disqualifies autoload Node (state would persist across battles unless manually cleared; battle-scoped child of BattleScene gets free teardown via ADR-0002 SceneManager).
- **Mirrors ADR-0010 HPStatusController exactly** — identical concerns (state + listen + emit), identical resolution. Pattern-boundary precedent extension (Core-layer Node form) is the project's now-established discipline for this combination.

### Architecture Diagram

```
                          ┌────────────────────────────────────────┐
                          │  /root/GameBus  (autoload, ADR-0001)   │
                          │  signals declared in Turn Order Domain │
                          │   • round_started(int)                 │
                          │   • unit_turn_started(int)             │
                          │   • unit_turn_ended(int, bool)         │
                          │   • victory_condition_detected(int)    │
                          │     [added by §Migration Plan §0       │
                          │      same-patch ADR-0001 amendment]    │
                          │  consumed signals (subscribed-from):   │
                          │   • unit_died(int) [HP/Status emits]   │
                          └────────────────────────────────────────┘
                                  ▲ emit                   │ subscribe
                                  │                        ▼
              ┌───────────────────────────────────────────────────────────┐
              │  BattleScene (per-battle root, ADR-0002)                  │
              │   ├─ HPStatusController (ADR-0010, battle-scoped Node)    │
              │   │     └─ Subscribes: GameBus.unit_turn_started          │
              │   │     └─ Emits:     GameBus.unit_died                   │
              │   │                                                       │
              │   └─ TurnOrderRunner (THIS ADR, battle-scoped Node)       │
              │         _queue: Array[int]                                │
              │         _queue_index: int                                 │
              │         _round_number: int                                │
              │         _unit_states: Dictionary[int, UnitTurnState]      │
              │         _round_state: RoundState (typed enum)             │
              │         Subscribes: GameBus.unit_died (queue removal)    │
              │         Emits: round_started + unit_turn_started +        │
              │                 unit_turn_ended + victory_condition_      │
              │                 detected                                  │
              └───────────────────────────────────────────────────────────┘
                          │                                  ▲
                          │ direct call (read-only query)    │ direct call
                          ▼                                  │ (Contract 5)
              ┌───────────────────────────────────┐  ┌────────────────────┐
              │ Damage Calc (ADR-0012)            │  │ AI System          │
              │ • turn_order.get_acted_this_turn  │  │ • request_action   │
              │   (unit_id: int) -> bool          │  │   delegated by     │
              │ • turn_order.get_current_round    │  │   TurnOrderRunner  │
              │   _number() -> int                │  │   at T4 for AI     │
              └───────────────────────────────────┘  └────────────────────┘

Note: victory_condition_detected is owned by Turn Order (Turn Order Domain),
      but Grid Battle is the sole emitter of authoritative battle_outcome_resolved
      per ADR-0001 line 301 single-owner rule. Turn Order detects + emits the
      victory_condition_detected signal; Grid Battle consumes + transitions to
      RESOLUTION + emits the terminal battle_outcome_resolved (typed BattleOutcome
      Resource with chapter_id / final_round / surviving_units that Turn Order
      does not have).
```

### Key Interfaces

**Public mutator API (3 methods)**

```gdscript
class_name TurnOrderRunner extends Node

# Inline typed enums (file-local; no @export — ADR-0009 cross-script @export risk does not apply)
enum RoundState { BATTLE_NOT_STARTED, BATTLE_INITIALIZING, ROUND_STARTING, ROUND_ACTIVE, ROUND_ENDING, BATTLE_ENDED }
enum TurnState { IDLE, ACTING, DONE, DEAD }
enum ActionType { MOVE, ATTACK, USE_SKILL, DEFEND, WAIT }
enum VictoryResult { PLAYER_WIN, PLAYER_LOSE, DRAW }   # values 0, 1, 2 — passed via victory_condition_detected(result: int)

func initialize_battle(unit_roster: Array[BattleUnit]) -> void:
    """Called once by Battle Preparation at battle-init. Executes BI-1 through BI-5
    (collect units, compute initiative via UnitRole.get_initiative, initialize per-unit
    flags, initialize counters, apply battle-start effects). BI-6 transitions
    _round_state to ROUND_STARTING and triggers _begin_round() asynchronously via
    Callable method-reference deferred form (per godot-specialist 2026-04-30 Item 6;
    NOT string-based call_deferred per project deprecated-apis pattern):
        _begin_round.call_deferred()
    Subscribes to GameBus.unit_died on first call only (idempotent connect; G-15
    test isolation reset must disconnect)."""

func declare_action(unit_id: int, action: ActionType, target: ActionTarget) -> ActionResult:
    """Called by player input layer (via Grid Battle BattleController) OR AI System (via
    request_action delegation at T4). Validates token availability + DEFEND_STANCE locks
    + range / cooldown gates per CR-3 + CR-4. On success: spends appropriate token(s),
    updates _unit_states[unit_id], may emit unit_turn_ended at T6 if turn-completing.
    Returns ActionResult with {success: bool, error_code: ActionError, side_effects: Array}."""

func _advance_turn(unit_id: int) -> void:
    """[TEST SEAM] Direct invocation of T1–T7 sequence for the specified unit_id.
    Production: called via internal queue advancement in _on_unit_turn_completed.
    Tests: called directly to bypass GameBus signal infrastructure + per-unit timing.
    Prefixed with _ but PUBLIC for tests-namespace per ADR-0005 + ADR-0010 + ADR-0012
    DI seam pattern (4-precedent extension). GDScript 4.x does NOT enforce leading-
    underscore as private at the language level — convention only; GdUnit4 v6.1.2
    can call this directly with no reflection workaround."""
```

**Public read-only query API (5 methods)**

```gdscript
func get_acted_this_turn(unit_id: int) -> bool:
    """Damage Calc consumes per attack for Scout Ambush gate (ADR-0012 line 343 —
    ratified here with unit_id type LOCKED to int). Returns
    _unit_states[unit_id].acted_this_turn. Returns false for unknown unit_id (e.g.,
    dead unit removed from _unit_states); R-2 defensive `_unit_states.has()` check."""

func get_current_round_number() -> int:
    """Damage Calc consumes per attack for Scout Ambush round-2+ gate (ADR-0012).
    Returns _round_number. Returns 0 before BI-4 / R1 (battle not started)."""

func get_turn_order_snapshot() -> TurnOrderSnapshot:
    """Battle HUD + AI consume for queue display + target prioritization. Returns
    deep snapshot (TurnOrderSnapshot is RefCounted typed wrapper; pure value
    semantics; consumer cannot mutate _queue or _unit_states via the snapshot).
    Pull-based — Battle HUD calls on round_started / unit_turn_ended / unit_died
    receipts."""

func get_charge_ready(unit_id: int) -> bool:
    """Damage Calc consumes for Cavalry Charge passive (ADR-0009 passive_charge).
    Returns _unit_states[unit_id].accumulated_move_cost >=
    BalanceConstants.get_const("CHARGE_THRESHOLD"). Reset to 0 at T4 per F-2."""

func get_unit_turn_state(unit_id: int) -> UnitTurnState:
    """AI System consumes for action selection context. Returns the per-unit
    RefCounted typed wrapper via UnitTurnState.snapshot() defensive copy (NOT
    _unit_states[unit_id] directly). Used at T4 for AI decision context."""
```

**Emitted signals (4 — per ADR-0001 + same-patch amendment §Migration Plan §0)**

```
GameBus.round_started(round_number: int)
  Emitted at R4 (after queue construction).
  Consumers: Grid Battle, Formation Bonus, Battle HUD.

GameBus.unit_turn_started(unit_id: int)
  Emitted at T4 (after _activate_unit_turn).
  Consumers: HP/Status (DoT tick + duration decrement + DEFEND_STANCE expiry +
             DEMORALIZED recovery — already locked by ADR-0010 §Soft/Provisional
             clause (1) → ratified upon this ADR's Acceptance), AI (action
             delegation), Battle HUD (active unit highlight).

GameBus.unit_turn_ended(unit_id: int, acted: bool)
  Emitted at T6 (after _mark_acted).
  Consumers: Grid Battle, AI, Battle HUD (queue advance + token state refresh).

GameBus.victory_condition_detected(result: int)  # int enum {PLAYER_WIN=0, PLAYER_LOSE=1, DRAW=2}
  Emitted at T7 (decisive outcome) OR RE2 (round cap DRAW).
  Sole consumer: Grid Battle. Grid Battle evaluates + emits authoritative
  battle_outcome_resolved (typed BattleOutcome Resource per ADR-0001 line 151)
  per ADR-0001 line 301 single-owner rule.
```

**Consumed signals (1 — per ADR-0001)**

```
GameBus.unit_died(unit_id: int)
  Emitted by HPStatusController per ADR-0010.
  Handler: _on_unit_died(unit_id) — removes from _queue immediately (CR-7a);
  removes from _unit_states; advances _queue_index appropriately. If the dead
  unit is currently ACTING (counter-attack scenario CR-7d), interrupts T5 — no
  further T5 actions, T6 skipped, T7 executes with the dead unit omitted.

  R-1 mitigation: subscribed with CONNECT_DEFERRED flag per ADR-0001 §5
  deferred-connect mandate (Object.CONNECT_DEFERRED = 1, stable through 4.6
  per godot-specialist 2026-04-30 Item 4). Defers queue removal to next idle
  frame after apply_damage call stack unwinds; T7 victory check still fires
  synchronously via the unwound stack reaching the original T5 caller.

  Code: GameBus.unit_died.connect(_on_unit_died, Object.CONNECT_DEFERRED)
```

**Typed Resource / wrapper definitions**

```gdscript
class_name UnitTurnState extends RefCounted
# Per-unit token state + acted_this_turn + accumulated_move_cost. RefCounted (NOT
# Resource) — battle-scoped non-persistent per CR-1b lifecycle alignment (matches
# ADR-0010 UnitHPState pattern; same rationale).

var unit_id: int
var move_token_spent: bool = false       # FRESH → spent at MOVE confirmation
var action_token_spent: bool = false     # FRESH → spent at ATTACK / SKILL / DEFEND declaration
var accumulated_move_cost: int = 0       # F-2 charge budget; reset to 0 at T4
var acted_this_turn: bool = false        # CR-3f: true iff at least one token spent during T5
var turn_state: TurnOrderRunner.TurnState = TurnOrderRunner.TurnState.IDLE

func snapshot() -> UnitTurnState:
    """Defensive deep copy for query API consumers. Returns a NEW UnitTurnState
    constructed via explicit field-by-field copy (NOT duplicate() / duplicate_deep()
    — those are Resource methods; UnitTurnState is RefCounted, NOT Resource).
    Per godot-specialist 2026-04-30 Item 3: idiomatic RefCounted pattern.
    Consumer cannot mutate the original UnitTurnState via the snapshot."""
    var copy := UnitTurnState.new()
    copy.unit_id = unit_id
    copy.move_token_spent = move_token_spent
    copy.action_token_spent = action_token_spent
    copy.accumulated_move_cost = accumulated_move_cost
    copy.acted_this_turn = acted_this_turn
    copy.turn_state = turn_state
    return copy
```

```gdscript
class_name TurnOrderSnapshot extends RefCounted
# Pull-based snapshot per Contract 3. Battle HUD + AI consume. Pure value semantics.

var round_number: int
var queue: Array[TurnOrderEntry]   # typed array, ordered by initiative cascade
```

```gdscript
class_name TurnOrderEntry extends RefCounted

var unit_id: int
var is_player_controlled: bool
var initiative: int
var acted_this_turn: bool
var turn_state: int   # TurnOrderRunner.TurnState enum value
```

**Forbidden patterns (registered same-patch — see §6 Architecture Registry)**

- `turn_order_consumer_mutation` — consumers MUST NOT mutate `UnitTurnState` / `TurnOrderSnapshot` returned by query API; defensive snapshot pattern enforced.
- `turn_order_external_queue_write` — `_queue` + `_unit_states` MUST NOT be modified outside `TurnOrderRunner` (no public setter; static lint asserts no .gd file outside `src/core/turn_order_runner.gd` assigns to `TurnOrderRunner._queue` or `TurnOrderRunner._unit_states`).
- `turn_order_signal_emission_outside_domain` — `TurnOrderRunner` MUST emit ONLY 4 signals (`round_started` + `unit_turn_started` + `unit_turn_ended` + `victory_condition_detected`); MUST NOT emit any other GameBus signal per ADR-0001 single-emitter rule (mirrors ADR-0010 / ADR-0005 / ADR-0009 non-emitter discipline).
- `turn_order_static_var_state_addition` — must not add static class-level state (use `_unit_states` Dictionary instead); battle-scoped lifecycle would be violated by class-level static variables persisting across battles.
- `turn_order_typed_array_reassignment` — `_queue` MUST be mutated in-place (`_queue.clear()` + `_queue.append_array(new_list)`); MUST NOT be reassigned (`_queue = new_list`) per godot-specialist 2026-04-30 Item 8 + G-2 prevention pattern. Reassignment risks typed-array reference replacement hazards under G-15 test resets.

## Alternatives Considered

### Alternative 1: Autoload Node `/root/TurnOrderRunner`

- **Description**: Register as autoload load order 5 (after GameBus → SceneManager → SaveManager → InputRouter); state lives across battles with manual reset at BI-1.
- **Pros**: Familiar pattern from ADR-0005 InputRouter. Easy to access from any scene via `/root/TurnOrderRunner`.
- **Cons**: State persists across battles unless explicitly cleared — failure mode if a battle ends abnormally (forfeit, app suspend) leaves stale queue + per-unit states; first turn of next battle would inherit ghost data. Battle-scoped lifecycle better aligned with combat mechanic (queue is meaningful only during a battle).
- **Rejection Reason**: ADR-0010 made the same choice (battle-scoped Node over autoload) for HPStatusController — ADR-0011 is structurally analogous (state + listen + emit), so consistent with the established Core-layer pattern. Battle-scoped form gets free teardown via ADR-0002 SceneManager.

### Alternative 2: Stateless-static utility class (`class_name TurnOrderRunner extends RefCounted + @abstract + all-static`)

- **Description**: Mirror the 5-precedent pattern (ADR-0008 → 0006 → 0012 → 0009 → 0007). All static methods; queue stored externally (passed by reference into each call).
- **Pros**: Pattern stable at 5 invocations; minimal new mental model.
- **Cons**: Breaks at the listening + state-holding requirements — Turn Order subscribes to `GameBus.unit_died`, but Callable subscription identity for static methods has undefined semantics in GDScript 4.x (matches ADR-0005 §Alt 4 rejection rationale). Queue mutation across multiple call sites without explicit owner instance creates implicit shared-state coupling. `_queue_index` advancement requires per-call mutation of caller-side state — stateless-static pattern decomposes into static methods with mandatory mutable-Array-passing-by-reference, which is the WORSE form of state ownership (state ownership becomes invisible at call sites).
- **Rejection Reason**: ADR-0005 §Alt 4 + ADR-0010 §Alt 3 boundary — pattern is for systems CALLED, not systems that LISTEN AND/OR hold mutable state. Turn Order does both. Pattern boundary now formally codified across 3 ADRs (ADR-0005 InputRouter, ADR-0010 HPStatusController, ADR-0011 TurnOrderRunner — all Node-based for the same reason).

### Alternative 3: Hybrid — query API as static methods + Node for state / signals

- **Description**: Static class for `get_acted_this_turn` / `get_current_round_number` (read-only queries), separate Node for state ownership + signal emission.
- **Pros**: Damage Calc could call `TurnOrderRunner.get_acted_this_turn(unit_id)` without holding a Node reference.
- **Cons**: Bifurcates state ownership — static methods need to read `_unit_states` somehow. Either (a) static methods get a Node reference at call time (defeats the static API) OR (b) state is duplicated into class-level static variables (forbidden_pattern: `turn_order_static_var_state_addition`; battle teardown leak risk). Both options force a worse architecture than the simple Node form.
- **Rejection Reason**: ADR-0005 + ADR-0010 already faced and rejected this — bifurcation creates two failure modes (stale static cache + Node not yet ready) where the unified Node form has zero. Damage Calc gets a `TurnOrderRunner` reference at construction time (via Grid Battle's dependency injection) — same as how it gets `HPStatusController` per ADR-0012.

### Alternative 4: Per-unit Resource (`UnitTurnState extends Resource` with `@export` fields, .tres-authored)

- **Description**: `UnitTurnState` is a typed Resource with `@export` fields, authored as .tres template per unit class.
- **Pros**: Designer can tune per-class default token states from inspector.
- **Cons**: All `UnitTurnState` data is BATTLE-SCOPED RUNTIME state (token spent flags, accumulated_move_cost, acted_this_turn) — there is no design-time content here to author. .tres authoring is misuse of the Resource system. Mirrors ADR-0010 UnitHPState rationale (battle-scoped non-persistent → RefCounted, NOT Resource).
- **Rejection Reason**: Same as ADR-0010 §Alt 1 — RefCounted is the correct base class for battle-scoped non-persistent runtime state.

## Consequences

### Positive

- **Pattern boundary now formally codified at 3 ADRs** (ADR-0005 InputRouter, ADR-0010 HPStatusController, ADR-0011 TurnOrderRunner) — Foundation/Core Node-based form for state-holders + signal-listeners is now project discipline. Stateless-static 5-precedent (ADR-0008→0006→0012→0009→0007) remains the canonical form for systems CALLED.
- **All ADR-0010 + ADR-0012 soft-deps closed** — `unit_turn_started` provisional → ratified; `get_acted_this_turn` provisional → ratified (with unit_id type advisory). Architecture-traceability ADR-0010 / ADR-0012 dependency entries flip Soft → Locked upon Acceptance.
- **`architecture.md` Blocker §1 resolved** — Turn Order ↔ AI signal-inversion contract codified: AI is invoked at T4 via direct delegation (Contract 5 `request_action(unit_id, queue_snapshot)`), NOT via signal inversion. Interleaved queue (CR-1) makes player / AI ownership invisible to Turn Order logic.
- **Test seam pattern stable at 4 invocations** — ADR-0005 `_handle_event` + ADR-0010 `_apply_turn_start_tick` + ADR-0012 `_resolve_with_rng` + ADR-0011 `_advance_turn`. DI seam discipline at 4-precedent extension.
- **Foundation 5/5 + Core 2/2 → 3/3 upon Acceptance** — first all-Foundation+Core-Complete state. Drops the mandatory ADR list to ZERO before Pre-Production → Production gate (post-Acceptance).
- **2 net-new BalanceConstants only** — minimal balance-data ABI surface expansion. ROUND_CAP + CHARGE_THRESHOLD register cleanly per ADR-0006 pattern. INIT_SCALE + INIT_CAP already owned by ADR-0009 (no duplicate registration).

### Negative

- **`unit_turn_started` payload locked at `(unit_id: int)`** — if future Turn Order or HP/Status work needs to add a `phase: int` parameter (e.g., distinguishing T0 vs T4), this ADR + ADR-0001 + ADR-0010 must be amended together. Mitigation: GDD §CR-2 already documents T0–T7 sequence; phase distinction handled internally by Turn Order via `_round_state` enum, not exposed via the signal.
- **Queue is a snapshot, not re-sorted mid-round** (CR-6a) — DEMORALIZED ally hero arriving mid-round does NOT recover the unit until T3 of its own next-round turn. Player Fantasy reinforces this (the initiative bar is a promise, not a suggestion), but non-obvious to first-time players.
- **One more Battle-scoped Node** added to BattleScene — minor memory overhead (~few hundred bytes per battle for queue + per-unit state Dictionary at 16–20 units). Acceptable against 512 MB mobile ceiling.
- **`get_acted_this_turn` unit_id type lock at `int`** — creates 4th cross-doc advisory carry for next ADR-0012 amendment. Process risk: if ADR-0012 amendment is delayed indefinitely, story-level confusion possible (Damage Calc story author reads ADR-0012 line 343 `StringName` + ADR-0011 `int` → unclear which is authoritative). Mitigation: ADR-0011 §GDD Requirements explicitly notes this is the canonical type; ADR-0012 amendment queued as same-patch obligation when next ADR-0012 substantive edit occurs.
- **Same-patch ADR-0001 amendment required** — adds `signal victory_condition_detected(result: int)` declaration + Turn Order Domain table row + Last Verified date refresh. Surgical (~10 LoC across 2 sections); justified because the GDD prescribes this signal as a BRIDGE between Turn Order's detection and Grid Battle's authoritative `battle_outcome_resolved` emission, and without ADR-0001 declaring the signal, Turn Order code cannot compile against GameBus.

### Risks

- **R-1 — Acting unit dies from counter-attack (CR-7d) during T5**: re-entrancy hazard if `_on_unit_died` runs synchronously inside `apply_damage` chain.
  - **Mitigation**: subscribe to `GameBus.unit_died` with `Object.CONNECT_DEFERRED` flag per ADR-0001 §5 deferred-connect mandate (matches ADR-0010 Implementation Notes Advisory D). The defer pushes the queue removal to next idle frame, after the `apply_damage` call stack unwinds. T7 victory check still fires synchronously via the unwound stack reaching the original T5 caller. Dedicated regression test in §Validation Criteria §15.
- **R-2 — `_unit_states` Dictionary state desync if `unit_died` fires for an unknown unit_id**:
  - **Mitigation**: `_on_unit_died` checks `_unit_states.has(unit_id)` and short-circuits with no-op if absent (defensive — covers double-death edge case if both DoT and counter-attack mark the same unit dead). Test in §Validation Criteria §16.
- **R-3 — `accumulated_move_cost` not reset between turns** if a unit's turn is interrupted mid-T5 by death:
  - **Mitigation**: reset to 0 at T4 (turn START), not T6 — even if T5 is interrupted, the next turn's T4 cleanly resets. Documented in §Decision §_unit_states reset pattern parallel to ADR-0010 G-15 reset discipline. Test in §Validation Criteria §17.
- **R-4 — Queue rebuild at R3 picks up units killed AFTER R3**: minimal — R3 fires once per round; deaths between R3 and the unit's T1 are handled by T1 death check (T2 step) + `_on_unit_died` queue removal. Queue is allowed to contain references to recently-dead units briefly; the T1–T2 sequence cleans them.
- **R-5 — Test isolation: GameBus.unit_died subscription leaks across tests** if `before_test()` doesn't disconnect:
  - **Mitigation**: G-15 reset discipline — `before_test()` MUST call `_unit_states.clear()` + `_queue.clear()` + `_round_number = 0` + `_queue_index = 0` + `_round_state = RoundState.BATTLE_NOT_STARTED` + `if GameBus.unit_died.is_connected(_on_unit_died): GameBus.unit_died.disconnect(_on_unit_died)`; mirrors ADR-0010 + ADR-0005 G-15 reset list patterns.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| `turn-order.md` §CR-1 (interleaved queue) | All units in single queue ordered by initiative; no player / AI phase | Queue rebuilt at R3 from ALIVE units sorted via F-1 cascade; `is_player_controlled` invisible to queue logic |
| `turn-order.md` §CR-2 (round / turn lifecycle) | R1–R4 → T1–T7 → RE1–RE3 strict ordering | TurnOrderRunner state machine `_round_state` enum + internal `_advance_turn` driver enforces sequence |
| `turn-order.md` §CR-3 (action budget) | MOVE + ACTION token, binary, no carry-over | `UnitTurnState.move_token_spent` + `action_token_spent` fields; reset to FRESH at T4 |
| `turn-order.md` §CR-4 (action types) | MOVE / ATTACK / USE_SKILL / DEFEND / WAIT | `declare_action()` validates `ActionType` enum with token availability + DEFEND_STANCE locks per CR-4c |
| `turn-order.md` §CR-5 / F-1 (tie-breaking cascade) | initiative DESC, stat_agility DESC, is_player_controlled DESC, unit_id ASC | Queue sort at R3 reads `stat_agility` from HeroDatabase + `is_player_controlled` flag + unit_id; deterministic total order |
| `turn-order.md` §CR-6 (static initiative) | Initiative computed once at BI-2; queue rebuilt each round from same values | `UnitRole.get_initiative` called once per unit in `initialize_battle`; cached per-unit (NOT recomputed at R3) |
| `turn-order.md` §CR-7 (death mid-round) | Immediate queue removal on `unit_died` | `_on_unit_died` handler with `Object.CONNECT_DEFERRED` for re-entrancy safety (R-1 mitigation) |
| `turn-order.md` §CR-8 (no delay mechanic) | WAIT does not reposition; tokens forfeited | `declare_action(WAIT)` sets `acted_this_turn = false` + `turn_state = DONE`; no queue manipulation |
| `turn-order.md` §CR-9 (battle initialization) | BI-1 through BI-6 sequence | `initialize_battle()` executes sequence; BI-6 transitions to ROUND_STARTING via `_begin_round.call_deferred()` |
| `turn-order.md` §F-2 (charge budget) | `accumulated_move_cost`; `charge_ready` threshold check | `UnitTurnState.accumulated_move_cost` field; `get_charge_ready` query reads `BalanceConstants.get_const("CHARGE_THRESHOLD")` per ADR-0006 |
| `turn-order.md` §F-3 (round cap) | `ROUND_CAP=30` → DRAW | RE2 reads `BalanceConstants.get_const("ROUND_CAP")` per ADR-0006; emits `victory_condition_detected(VictoryResult.DRAW)` |
| `damage-calc.md` §Dependencies (Scout Ambush gate) | `get_acted_this_turn` + `get_current_round_number` queries | Public read-only query API; ADR-0011 LOCKS `unit_id` type to `int` (advisory carried for ADR-0012 line 343 amendment) |
| `hp-status.md` §SE-3 + §F-3 (DoT tick + DEFEND_STANCE expiry timing) | `unit_turn_started` signal subscription at T4 | Emit `unit_turn_started(unit_id: int)` at T4 after `_activate_unit_turn`; ratifies ADR-0010 provisional consumer contract |
| `grid-battle.md` §Dependencies (3 turn signals + victory_condition) | `round_started` + `unit_turn_started` + `unit_turn_ended` + `victory_condition_detected` emits | All 4 signals declared in §Key Interfaces; emitted at R4 / T4 / T6 / T7+RE2 lifecycle points |
| `unit-role.md` §F-4 (initiative formula) | Read `base_initiative_seed` + `class_init_mult`; compute initiative | `initialize_battle` calls `UnitRole.get_initiative(hero, unit_class)` per ADR-0009; one-time per-unit per-battle |
| `hero-database.md` §stat_agility | Tie-breaking secondary sort key | Queue sort at R3 reads `HeroDatabase.get_hero(hero_id).stat_agility` per ADR-0007. Note `hero_id: StringName` (ADR-0007) vs `unit_id: int` (ADR-0001/0010/0011) are distinct identifiers — Battle Preparation provides the mapping at BI-1 |
| `balance-data.md` §BalanceConstants | ROUND_CAP, CHARGE_THRESHOLD via `get_const` | All 2 net-new tuning constants append to `assets/data/balance/balance_entities.json` + `BalanceConstants.get_const(key)` per ADR-0006. INIT_SCALE + INIT_CAP already owned by ADR-0009 (no duplicate registration) |

## Performance Implications

- **CPU**: Queue sort at R3 — `O(N log N)` with `N ≤ 20` units. Negligible. AC-23 budget: < 1 ms on minimum target hardware (mobile). Per-attack queries (`get_acted_this_turn`, `get_current_round_number`) — `O(1)` Dictionary lookup + scalar return. Negligible.
- **Memory**: Per-battle: `_queue` (~80 bytes for 20 ints), `_unit_states` Dictionary (~400 bytes for 20 entries × ~20 bytes each), `_round_number` (4 bytes). Total ~500 bytes per battle. Trivial against 512 MB mobile ceiling. Freed at battle teardown via SceneManager (ADR-0002).
- **Load Time**: None — TurnOrderRunner is created at battle-init, not at app boot.
- **Network**: N/A (single-player MVP).

## Migration Plan

This ADR introduces a new Core module — no existing code changes. Migration is forward-only.

### §0. Same-patch ADR-0001 amendment (REQUIRED — applied at this ADR's Write step)

ADR-0001 currently declares 3 Turn Order Domain signals (lines 152–154 + table rows 297–299). The GDD (turn-order.md Contract 4) prescribes a 4th signal `victory_condition_detected(result)` as the bridge between Turn Order's detection and Grid Battle's authoritative `battle_outcome_resolved` emission. Without ADR-0001 declaring the signal, Turn Order code cannot compile against GameBus.

**Surgical edit (~10 LoC across 2 sections of `docs/architecture/ADR-0001-gamebus-autoload.md`):**

1. **Code block insertion** — after line 154 (`signal unit_turn_ended(unit_id: int, acted: bool)`):
   ```gdscript
   signal victory_condition_detected(result: int)  # int enum {PLAYER_WIN=0, PLAYER_LOSE=1, DRAW=2} — Turn Order detects, Grid Battle consumes + emits authoritative battle_outcome_resolved per single-owner rule
   ```
2. **§3 Turn Order domain table row** — append after line 299:
   ```
   | `victory_condition_detected` | `int` | `result: int` (enum {PLAYER_WIN=0, PLAYER_LOSE=1, DRAW=2}) | TurnOrderRunner (T7 decisive outcome OR RE2 round cap DRAW) | Grid Battle (sole consumer; transitions to RESOLUTION + emits authoritative battle_outcome_resolved) | discrete |
   ```
3. **Last Verified refresh** — line 13:
   ```
   2026-04-30 (via ADR-0011 same-patch amendment — added Turn Order Domain signal victory_condition_detected)
   ```

### §1. New module files (Story 1)

Create `src/core/turn_order_runner.gd` with `TurnOrderRunner` class declaration + 8 public method skeletons + 4 emit + 1 subscribe stubs. Create `src/core/unit_turn_state.gd` + `src/core/turn_order_snapshot.gd` + `src/core/turn_order_entry.gd` (RefCounted typed wrappers).

### §2. BalanceConstants append (Story 1, same-patch with §1 per ADR-0006 §6)

Append 2 new keys to `assets/data/balance/balance_entities.json` — `ROUND_CAP=30` + `CHARGE_THRESHOLD=40` (single-line append per ADR-0006 §6 same-patch story-level obligation). Lint validates presence.

### §3. Initiative + queue construction (Story 2)

Implement `initialize_battle()` + tie-break F-1 cascade + queue construction at R3 with unit test for AC-13 (deterministic total order; same input → same output 100×).

### §4. T1–T7 sequence (Stories 3–7)

Implement T1–T7 sequence via `_advance_turn(unit_id)` with 23 unit / integration tests covering AC-01 through AC-22.

### §5. Signal subscriptions + emissions (Story 8)

Implement signal subscriptions + emissions with test seam mock (`Object.CONNECT_DEFERRED` for `unit_died` per R-1 mitigation).

### §6. Charge accumulation F-2 (Story 9)

Implement Charge accumulation F-2 with 2 unit tests (AC-14 + AC-15).

### §7. G-15 test isolation (Story 10)

`before_test()` clears `_unit_states` + `_queue` + `_round_number` + `_queue_index` + `_round_state` + disconnects `unit_died` subscription.

### Cross-doc obligations on Acceptance

- **ADR-0010 §Soft / Provisional clause (1)** — flip `(1) ADR-0011 Turn Order (NOT YET WRITTEN — soft / provisional downstream)` to `(1) ADR-0011 Turn Order (RATIFIED 2026-MM-DD via /architecture-review delta #N)` (parameter-stable; no code change to ADR-0010).
- **ADR-0012 §Dependencies line 42** — flip `ADR-0011 Turn Order (NOT YET WRITTEN — soft / provisional)` to `ADR-0011 Turn Order (RATIFIED 2026-MM-DD via /architecture-review delta #N)`. **Same-patch obligation**: also flip `unit_id: StringName` at line 343 → `unit_id: int` (4th cross-doc advisory now batched alongside ADR-0001 line 168 + line 372 + ADR-0010 unit_id type for next ADR-0012 amendment cycle).
- **`design/gdd/turn-order.md`** Status header — flip `Designed` → `Accepted via ADR-0011 (Proposed 2026-04-30 → Accepted 2026-MM-DD via /architecture-review delta #N)`.
- **`design/gdd/hp-status.md` §Dependencies** table — backfill Turn Order row in 하위 의존성 (per `turn-order.md` line 714 GAP).
- **`design/gdd/balance-data.md` §Dependencies** table — backfill Turn Order row in 하위 의존성 (per `turn-order.md` line 715 GAP).

### Acceptance prerequisites

- `/architecture-review` delta #8 (fresh session) validates module form, signal contracts, query API, registry candidates, GDD sync, ADR-0001 amendment correctness.
- TR-turn-order-001..NNN registered in `tr-registry.yaml` v9 → v10.
- `architecture-traceability.md` v0.8 → v0.9 (Core 2/2 → 3/3 — last Core gap closed).
- `architecture.md` v0.5 → v0.6 (Required ADRs mandatory list pruned 1 → 0; Layer status update).

## Validation Criteria

This ADR is correct iff all of the following hold (each maps to one or more GDD acceptance criteria; see §GDD Requirements Addressed for the full mapping):

1. **AC-01 through AC-22 GDD ACs all pass as automated tests** (Logic + Integration; AC-23 ADVISORY for performance).
2. **Queue determinism** (AC-13): same 20-unit input produces identical queue 100 times.
3. **Token budget order flexibility** (AC-03 / AC-04 / AC-05 / AC-06): all 6 `declare_action` permutations produce correct `acted_this_turn` flag at T6.
4. **Tie-breaking cascade** (AC-07 / AC-08): `stat_agility` resolves Step 1; `is_player_controlled` resolves Step 2.
5. **Static initiative** (AC-09): mid-battle status effect application does NOT reorder queue.
6. **Death mid-round** (AC-10): `_on_unit_died` removes acting unit; T6 skipped; T7 fires.
7. **Round cap DRAW** (AC-16): RE2 emits `victory_condition_detected(DRAW)`; Grid Battle emits authoritative `battle_outcome_resolved(DRAW)`.
8. **Mutual kill PLAYER_WIN precedence** (AC-18): T7 evaluates PLAYER_WIN before PLAYER_LOSE.
9. **DoT death at T1 skips T2–T7** (AC-17 Integration; cross-validates with ADR-0010 `unit_turn_started` consumer).
10. **Battle-end via DoT death signal** (AC-19 Integration): Grid Battle's `all_enemies_dead()` evaluation on `unit_died`; T2–T7 never execute.
11. **Scout Ambush round-1 gate** (AC-20 Integration): `get_current_round_number()` returns 1; Damage Calc gate evaluates first.
12. **Scout Ambush WAIT target round-2+** (AC-21 Integration): WAIT unit's `acted_this_turn = false`; Ambush fires; counter-attack suppressed.
13. **T7 PLAYER_WIN beats RE2 DRAW in Round 30** (AC-22): T7 `victory_condition_detected(PLAYER_WIN)` emit precedes RE2 evaluation.
14. **G-15 test isolation** (R-5 mitigation): `before_test()` reset list completeness — `_unit_states.clear()` + `_queue.clear()` + `_round_number = 0` + `_queue_index = 0` + `_round_state = BATTLE_NOT_STARTED` + `unit_died` disconnect.
15. **R-1 re-entrancy mitigation**: `_on_unit_died` subscribed with `Object.CONNECT_DEFERRED`; counter-attack-during-T5 case has dedicated regression test.
16. **R-2 unknown unit_id defensive**: `_on_unit_died(unknown_id)` is no-op; double-death scenario test.
17. **R-3 `accumulated_move_cost` reset at T4 (not T6)**: turn-interrupted-by-death scenario test verifies clean reset on next turn.
18. **forbidden_pattern static lint**: 5 patterns (`turn_order_consumer_mutation` + `turn_order_external_queue_write` + `turn_order_signal_emission_outside_domain` + `turn_order_static_var_state_addition` + `turn_order_typed_array_reassignment`) all enforce zero violations on `src/` tree.
19. **`UnitTurnState.snapshot()` field-by-field copy correctness**: per godot-specialist 2026-04-30 Item 3 — snapshot returns NEW UnitTurnState with all 6 fields explicitly copied; consumer mutation of the snapshot does NOT affect the original; unit test asserts identity-distinct objects + value-equal field set.
20. **`Callable.call_deferred()` form for BI-6 transition**: per godot-specialist 2026-04-30 Item 6 — `_begin_round.call_deferred()` (method-reference form), NOT string-based `call_deferred("_begin_round")`. Static lint asserts no string-based `call_deferred(` occurrences in `src/core/turn_order_runner.gd`.

## Implementation Notes (advisories carried forward)

- **Advisory A — Typed Dictionary fallback** (godot-specialist 2026-04-30 Item 2): if Godot 4.6 parse warnings surface for `Dictionary[int, UnitTurnState]` on first story, fall back to untyped `Dictionary` + `assert(state is UnitTurnState)` — same workaround as ADR-0010.
- **Advisory B — Typed array mutation** (godot-specialist 2026-04-30 Item 8): `_queue` MUST be mutated in-place (`.clear()` + `.append_array()`), never reassigned. Codified as forbidden_pattern `turn_order_typed_array_reassignment` (§Decision §Forbidden patterns); mirrors G-2 prevention pattern (`var result: Array[T] = []` + `.append()` + `return result` discipline established by ADR-0007 + ADR-0009 godot-specialist reviews).
- **Advisory C — `_advance_turn` is PUBLIC for tests** (godot-specialist 2026-04-30 Item 5): GDScript 4.x does NOT enforce leading-underscore as private; the underscore is documentation convention only. GdUnit4 v6.1.2 calls `_advance_turn` directly without reflection workaround. 4-precedent extension of ADR-0005 / ADR-0010 / ADR-0012 DI seam patterns.

## Related Decisions

- **ADR-0001** (GameBus, Accepted 2026-04-18) — declares 3 Turn Order Domain signals + `unit_died` consumer pattern. **THIS ADR adds a 4th signal `victory_condition_detected(result: int)` via §Migration Plan §0 same-patch amendment.** Carried advisories from prior deltas (line 168 `action: String` → `StringName` from delta #6 Item 10a + line 372 prose drift from delta #5 ADR-0007) — both batch with ADR-0001 NEXT amendment after this one. ADR-0011 does NOT itself add to this advisory carry (no new ADR-0001 wording drift this delta beyond the surgical signal addition).
- **ADR-0002** (SceneManager, Accepted) — `TurnOrderRunner` is battle-scoped child of BattleScene; battle teardown frees it automatically via SceneManager teardown.
- **ADR-0005** (Input Handling, Accepted 2026-04-30 delta #6) — pattern boundary precedent for Node-based form (system that LISTENS); ADR-0011 extends to systems that LISTEN AND/OR hold mutable state (combined with ADR-0010 precedent).
- **ADR-0006** (Balance / Data, Accepted) — 2 net-new BalanceConstants (ROUND_CAP, CHARGE_THRESHOLD) flow through `BalanceConstants.get_const(key)` per established discipline.
- **ADR-0007** (Hero DB, Accepted 2026-04-30) — `stat_agility` tie-break read via `HeroDatabase.get_hero(hero_id: StringName).stat_agility`. Note that `hero_id` is `StringName` (per ADR-0007) but `unit_id` is `int` (per ADR-0001 + ADR-0010 + ADR-0011) — these are distinct identifiers; mapping handled by Battle Preparation at BI-1.
- **ADR-0009** (Unit Role, Accepted 2026-04-28) — initiative read via `UnitRole.get_initiative(hero, unit_class) -> int`; passive_charge / passive_ambush tag reads via `UnitRole.PASSIVE_TAG_BY_CLASS` const Dictionary. INIT_SCALE + INIT_CAP global caps already owned (no duplicate registration in ADR-0011).
- **ADR-0010** (HP / Status, Accepted 2026-04-30 delta #7) — RATIFIES ADR-0010's `unit_turn_started(unit_id: int)` provisional consumer contract; no parameter renegotiation; ADR-0010 §Soft / Provisional clause (1) flips upon Acceptance.
- **ADR-0012** (Damage Calc, Accepted) — RATIFIES ADR-0012's `get_acted_this_turn(unit_id) -> bool` query interface AND adds `get_current_round_number() -> int` query. **Type advisory carried**: ADR-0012 line 343 declares `unit_id: StringName` but ADR-0011 LOCKS `int`; queues as 4th cross-doc advisory for next ADR-0012 amendment alongside ADR-0001 line 168 + ADR-0001 line 372 + ADR-0010 unit_id type carries.
