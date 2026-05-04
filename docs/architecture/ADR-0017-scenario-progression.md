# ADR-0017: Scenario Progression — ScenarioRunner Autoload, 13-State Machine, 9-Beat Per-Chapter Rhythm, Chapter JSON Schema, and 5-Signal GameBus Contract

## Status
Accepted (2026-05-04 via /architecture-review delta #12)

## Date
2026-05-04 (Proposed) → 2026-05-04 (Accepted; same-day fresh-session escalation per project precedent ADR-0015 + ADR-0016)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (state machine + autoload + JSON resource loading + GameBus signal emission) |
| **Knowledge Risk** | LOW (uses only stable Godot APIs: `Node` autoload, `Resource` `@export`, `JSON.parse`, `FileAccess.get_file_as_string`, `signal` declarations, `class_name`. No post-cutoff API surface introduced.) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `design/gdd/scenario-progression.md` (CR-1..CR-16, F-SP-1..F-SP-5, EC-SP-1..EC-SP-9, AC-SP-1..AC-SP-19), `design/gdd/destiny-branch.md`, `docs/architecture/ADR-0001-gamebus-autoload.md` (Scenario domain §1), `docs/architecture/ADR-0002-scene-manager.md` (Overworld↔BattleScene transition lifecycle), `docs/architecture/ADR-0003-save-load.md` (SaveContext + 3-CP policy), `docs/architecture/ADR-0014-grid-battle-controller.md` (battle_outcome_resolved emission), `docs/architecture/ADR-0016-battle-scene-wiring.md` (sprint-6 mock encoder Migration Plan §1) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | (1) Confirm autoload boot order: GameBus → SceneManager → SaveManager → ScenarioRunner (ScenarioRunner depends on first 3). (2) Verify `JSON.parse_string` performance on 5-chapter `scenarios/mvp_shu.json` (expected <50ms cold load on Snapdragon 7-gen reference). (3) Confirm `Resource.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)` semantics on `ChapterDefinition` for sprint-7+ retry-loop snapshot pattern (used to preserve original branch_table across runtime). Note: Godot 4.5+ deprecates `duplicate(true)` for nested-Resource cases in favor of `duplicate_deep` per `docs/engine-reference/godot/deprecated-apis.md`; same precedent already shipped at `src/core/map_grid.gd:233`. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted 2026-04-18) — Scenario domain owner of 5 confirmed signals + 2 PROVISIONAL signals; this ADR ratifies the PROVISIONAL signals (`scenario_beat_retried` + `save_checkpoint_requested`) as Accepted. ADR-0002 (Accepted 2026-04-18) — Overworld↔BattleScene transition lifecycle; ScenarioRunner emits `battle_launch_requested` consumed by SceneManager. ADR-0003 (Accepted 2026-04-19) — `SaveContext` Resource shape + 3-CP timing (CP-1 Beat 1 / CP-2 post-Beat 7 / CP-3 Beat 9); ScenarioRunner is sole emitter of `save_checkpoint_requested`. ADR-0014 (Accepted 2026-05-03) — GridBattleController emits `battle_outcome_resolved(BattleOutcome)`; ScenarioRunner subscribes for outcome → BEAT_6_RESULT entry. ADR-0007 (Accepted) — HeroDatabase consumed transitively via BattlePayload `unit_roster` (no direct read). |
| **Enables** | ADR-0018 (Destiny Branch — currently Backlog/blocked-on-this) — F-SP-1 / F-SP-2 formula spec ownership confirmed in this ADR (executed by DestinyBranchJudge per scenario-progression.md §D 2026-04-19 patch); chapter Resource schema locked here for DestinyBranchJudge consumption. **Critical-path unblock**: Beat 7 reveal cannot ship without this ADR. **Battle-scene Migration Plan §1** completion: at this ADR's acceptance, ADR-0016 sprint-6 mock encoder block in `src/feature/battle_scene/battle_scene.gd` deletes (~50 LoC) + `project.godot` `run/main_scene` reverts + lint `lint_battle_scene_sprint6_mock_marker.sh` semantic flips to "MUST NOT exist" — same patch as ADR-0017 implementation. |
| **Blocks** | Story Event GDD #10 — Beat 8 revelation content keyed on `(chapter_id, branch_key)` requires this ADR's chapter Resource schema. Save Slot UI — requires `chapter_index` + `branch_taken` lookup API on ScenarioRunner. Battle Preparation epic (sprint-7+) — currently NOT MVP per scenario-progression.md interaction §Battle Preparation; this ADR establishes the `battle_prepare_requested` emission point that Battle Prep epic will subscribe to when authored. |
| **Ordering Note** | Must be Accepted before sprint-6 mock encoder deletion patch (ADR-0016 Migration Plan §1) AND before ADR-0018 Destiny Branch authoring. May be authored before ADR-0018 because ADR-0017 owns F-SP-1/F-SP-2 *formula spec* (callable signature + behavior); ADR-0018 owns the `DestinyBranchJudge` *executor class* and `DestinyBranchChoice` *payload shape*. The dependency goes ADR-0017 → ADR-0018, not bidirectional. |

## Context

### Problem Statement

The game's chapter-level progression — sequencing the player through 3-5 MVP chapters with the canonical 9-beat per-chapter ceremony rhythm (역사의 닻 → 과거의 메아리 → 상황 브리핑 → 전투 준비 → 전투 → 결과 → 운명 판정 → 드러냄 → 다음 장 전환) — has been thoroughly designed in `design/gdd/scenario-progression.md` (CR-1..CR-16 + F-SP-1..F-SP-5 + 19 acceptance criteria) and partially ratified in 5 upstream ADRs (ADR-0001 5-signal contract, ADR-0002 transition lifecycle, ADR-0003 SaveContext + 3-CP policy, ADR-0014 outcome emission, ADR-0016 mock encoder Migration Plan §1). What does NOT yet exist:

1. **No `ScenarioRunner` autoload class shipped** — ADR-0001 §1 "Scenario domain" identifies ScenarioRunner as sole emitter of 5+2 PROVISIONAL signals, but no source file exists at `src/core/scenario_runner.gd`. ADR-0002 references "ScenarioRunner" but only at the consumer-of-`battle_outcome_resolved` boundary.
2. **No `ChapterDefinition` Resource form shipped** — scenario-progression.md §CR-5/CR-7/CR-14/CR-16 lock the per-chapter data fields (chapter_id, map_id, author_draw_branch, echo_threshold, branch_table, beat_1/3/8/9 texts, victory/defeat conditions), but the Godot Resource codification (typed `@export` fields vs runtime Dictionary) is undefined.
3. **No 13-state machine implementation form chosen** — scenario-progression.md §States and Transitions locks the 13 states + transition table, but the Godot codification (enum + match-statement vs StateMachine class vs node-tree state-pattern) is undefined.
4. **No `BattleConfig` Resource shape** — ADR-0016 §Migration Plan §1 references `var battle_config = ScenarioRunner.get_active_battle_config()` as the post-mock-encoder replacement, but the shape is not yet locked. Whether BattleConfig is identical to ADR-0001 `BattlePayload` (DRY) or a distinct shape is undefined.
5. **No retry-loop guard discipline shipped** — scenario-progression.md §CR-7 + CR-8 + F-SP-3 lock retry semantics (Beat 6 LOSS/DRAW → Beat 4 with prior deployment preserved; Beats 1/2/3 do NOT re-fire; echo_count++; first_attempt_resolved sealed at Beat 7 entry), but the codification (enum-state guard vs runtime invariant assertion vs both) is undefined.
6. **No JSON loader for `assets/data/scenarios/{scenario_id}.json`** — scenario-progression.md §Balance/Data §27 locks the JSON path + per-chapter schema but the loader is unimplemented. Path precedent exists from `assets/data/heroes/heroes.json` + `HeroDatabase._load_heroes()` (per ADR-0007).

This ADR resolves these 6 codification gaps. Sprint-6 ships the placeholder (mock encoder in BattleScene); sprint-7+ ships the real ScenarioRunner per this ADR.

### Constraints

**Technical:**
- Must integrate with ADR-0001 GameBus signal contract (5 confirmed + 2 PROVISIONAL signals; Scenario domain ownership LOCKED). No new signals beyond those 7. **Note**: at /architecture-review delta #12 acceptance (2026-05-04), the `scenario_complete` payload was widened String → ScenarioResult (4-field typed Resource per §CR-16 + F-SP-4 GDD intent) via same-patch ADR-0001 amendment; `scenario_beat_retried` was ratified PROVISIONAL → Accepted with the shipped 3-field EchoMark schema per ADR-0003 §Schema Stability. These are payload ratifications/widenings within the existing 7-signal contract — NOT new signals.
- Must integrate with ADR-0003 SaveContext Resource shape (LOCKED: `chapter_id`, `outcome`, `branch_key`, `echo_count`, `echo_marks_archive`, `flags_to_set`). No SaveContext field additions in this ADR; ADR-0017 only emits `save_checkpoint_requested` with the locked shape at the 3 timing points.
- Must integrate with ADR-0014 BattleOutcome shape (LOCKED). ScenarioRunner consumes `battle_outcome_resolved(BattleOutcome)` but does NOT mutate or override.
- Must satisfy ADR-0016 Migration Plan §1: at this ADR's implementation acceptance, the sprint-6 mock encoder block + `project.godot` `run/main_scene` flip + sprint-6 lint marker discipline all revert in a single coordinated patch.
- Must respect Godot 4.6 autoload single-instance constraint (one instance per scene tree, persistent across Overworld↔BattleScene transitions, lifecycle owned by SceneTree, NOT by SceneManager).

**Timeline:**
- Sprint-6 close 2026-05-30: this ADR Proposed (this turn). Acceptance escalation deferred to fresh-session `/architecture-review` per same-session-ban discipline.
- Sprint-7 (2026-05-31..2026-06-06): implementation + same-patch ADR-0016 Migration Plan §1 reverts.

**Resource:**
- ScenarioRunner state machine + JSON loader + 7 signal emission paths + retry-loop guard + 3-CP save integration: estimated 0.5-1.0d implementation effort across ~3 stories (state machine + chapter loader + signal emissions / save integration / retry-loop hardening).

**Compatibility:**
- Must coexist with sprint-6 mock encoder during the transition window (sprint-7 implementation patch is mechanically atomic; no period where both code paths are simultaneously live).
- Must support both 3-chapter MVP and future 5+ chapter expansion via `assets/data/scenarios/{scenario_id}.json` data file additions (zero source-line changes per chapter add).

### Requirements

- **Must own** the 13-state ScenarioRunner state machine per scenario-progression.md §States and Transitions table (LOADING / CHAPTER_START / BEAT_1_ANCHOR / BEAT_2_ECHO / BEAT_3_BRIEF / BEAT_4_PREP / BATTLE_LOADING / BEAT_5_BATTLE / BEAT_6_RESULT / BEAT_7_JUDGMENT / BEAT_8_REVEAL / BEAT_9_TRANSITION / SCENARIO_END).
- **Must emit** all 5 confirmed Scenario-domain signals (chapter_started / battle_prepare_requested / battle_launch_requested / chapter_completed / scenario_complete) AND ratify the 2 PROVISIONAL signals (scenario_beat_retried + save_checkpoint_requested) as Accepted with the payload shapes locked in scenario-progression.md §Interactions.
- **Must subscribe** to `battle_outcome_resolved(BattleOutcome)` from ADR-0014 GridBattleController via GameBus (CONNECT_DEFERRED per ADR-0001).
- **Must support** the retry loop (BEAT_6_RESULT LOSS/DRAW → "Retry" → BEAT_4_PREP) with prior deployment preserved + echo_count increment + scenario_beat_retried emission.
- **Must enforce** F-SP-3 echo state seal discipline: `state.first_attempt_resolved` set at BEAT_7_JUDGMENT entry SYNCHRONOUSLY (no `call_deferred`; no GameBus relay) per scenario-progression.md §F-SP-3 v2.2 systems-designer B-1 invariant.
- **Must execute** F-SP-1 (resolve_branch) and F-SP-2 (is_echo_gate_open) at BEAT_7_JUDGMENT entry per scenario-progression.md §F-SP-1 owner = scenario-progression / executor = DestinyBranchJudge (rev v2.0-patch 2026-04-19); the formulas are pure functions delegated to `DestinyBranchJudge.resolve(...)` from ADR-0018.
- **Must perform** within ADR-0001's <50 emits/frame budget (Scenario domain emits at most 1 signal per beat boundary; well within budget).
- **Must NOT** synthesize DRAW or override outcome (CR-3); MUST NOT mutate scenario data at runtime (CR-15 + AC-SP-12); MUST NOT carry echo across chapters (CR-7 + AC-SP-13); MUST NOT bypass ADR-0001 GameBus for cross-scene signal emission.

## Decision

### Class Form: `ScenarioRunner` Autoload Node

`extends Node` registered as autoload at `*res://src/core/scenario_runner.gd` in `project.godot`'s `[autoload]` section. **NO `class_name` declaration** per godot-4x-gotchas G-3: autoload scripts must NOT declare a matching `class_name` (it collides with the autoload-registered global identifier and produces parse error "Class X hides an autoload singleton"). The autoload name `ScenarioRunner` registered in `project.godot` IS the global identifier — call sites use `ScenarioRunner.get_active_battle_config()` directly. Same precedent as shipped autoloads `GameBus` (no `class_name`), `SceneManager` (no `class_name` per source line 17 explicit comment), `SaveManager`, `GameBusDiagnostics`, `BuildModeSentinel`. Single instance, persistent across Overworld↔BattleScene transitions, lifecycle owned by SceneTree.

**Why autoload Node** (not RefCounted, not scene-mounted):

1. **Cross-scene state continuity** — ScenarioRunner state survives the BattleScene mount/unmount cycle (per ADR-0002). The 13-state machine cannot reset when SceneManager swaps Overworld → BattleScene at BEAT_4_PREP exit. Scene-mounted Nodes would lose state across scene transitions; RefCounted has no Node lifecycle hooks; autoload Node is the only correct form.
2. **GameBus subscription discipline** — autoloads boot in declared order; ScenarioRunner subscribes to `battle_outcome_resolved` in `_ready()` once and persists. Scene-mounted Nodes would re-subscribe per scene mount, violating ADR-0001 single-subscription-per-instance contract.
3. **5-precedent project pattern** — GameBus (ADR-0001), SceneManager (ADR-0002), SaveManager (ADR-0003), HeroDatabase (ADR-0007 transitively via static-method class), GameBusDiagnostics, BuildModeSentinel are all autoloads. ScenarioRunner is the 6th (5 actual Node autoloads after this lands).
4. **Cross-scene signal flow** — ScenarioRunner emits 5 cross-scene signals (chapter_started / battle_prepare_requested / battle_launch_requested / chapter_completed / scenario_complete). Per ADR-0001 §Cross-Scene routing, cross-scene emitters MUST be autoloads or routed through GameBus. Direct emission requires autoload form.

**Boot order**: GameBus → SceneManager → SaveManager → GameBusDiagnostics → BuildModeSentinel → **ScenarioRunner**. ScenarioRunner depends on first 3 (GameBus for signal emission; SceneManager for `battle_launch_requested` consumer; SaveManager for `save_checkpoint_requested` consumer). Diagnostics + BuildModeSentinel are independent.

### State Machine Form: Enum + Match-Statement (Single Authoritative `_state` Field)

```gdscript
enum State {
    LOADING,
    CHAPTER_START,
    BEAT_1_ANCHOR,
    BEAT_2_ECHO,
    BEAT_3_BRIEF,
    BEAT_4_PREP,
    BATTLE_LOADING,        # Sub-state of BEAT_4_PREP exit / BEAT_5_BATTLE entry
    BEAT_5_BATTLE,
    BEAT_6_RESULT,
    BEAT_7_JUDGMENT,
    BEAT_8_REVEAL,
    BEAT_9_TRANSITION,
    SCENARIO_END,
}

var _state: State = State.LOADING
var _state_entered_at_msec: int = 0  # for min-dwell-time enforcement (CR-2 1s/2s/1.5s gates)
```

Single `_state` field; transitions are method-driven (`_transition_to(target: State)`) with explicit enum-driven guards. Pre-emptive guards check the current state at every entry point (e.g., `_advance_from_beat_1()` asserts `_state == State.BEAT_1_ANCHOR` and pushes scenario_fault if not).

**Why enum + match-statement** (not StateMachine class, not state-pattern with sub-Nodes):

1. **Match scenario-progression.md §States and Transitions table 1:1** — the GDD lists 13 states + transition trigger + target; enum-match codifies this directly without indirection. Non-trivial state machines benefit from class-per-state, but ScenarioRunner has only 13 states + 1 backward edge (BEAT_6 → BEAT_4 retry); class-per-state would over-engineer.
2. **Project precedent** — SceneManager (ADR-0002) uses the same enum + state field + transition method pattern. Pattern stable at 1 invocation; ScenarioRunner is the 2nd.
3. **Static analysis** — GDScript's enum types are typed; compile-time errors catch invalid state assignments. Match-statement coverage is verifiable by lint (future: `lint_scenario_runner_state_match_exhaustive.sh`).
4. **No call_deferred between state transitions** — F-SP-3 v2.2 systems-designer B-1 requires SYNCHRONOUS state transitions (Beat 6 accept → Beat 7 entry → first_attempt_resolved seal → resolve_branch — all in one synchronous path). Class-per-state with virtual method dispatch would not violate this but adds indirection complexity for no benefit.

### Chapter Data Form: Typed `ChapterDefinition` Resource (`.tres`-or-runtime) Hydrated From JSON

```gdscript
class_name ChapterDefinition extends Resource

@export var chapter_id: String = ""              # Stable id, e.g., "ch01_yellow_turban_uprising"
@export var chapter_number: int = 0              # 1-indexed; 1 = Ch1 silent-visual variant
@export var map_id: String = ""                  # Resolved to assets/data/maps/{map_id}.tres at BEAT_4_PREP
@export var author_draw_branch: bool = false     # CR-14: if true, DRAW branch MUST be authored
@export var echo_threshold: int = 1              # CR-6 + F-SP-2; in [1, ∞); 0 design-invalid
# branch_table: untyped Dictionary at @export boundary (typed Dictionary[K,V] @export
# is NOT supported in GDScript 4.6 — see terrain_effect.gd lines 16-20 for the project's
# authoritative no-typed-Dict-export rule). Internal access casts values to String.
# Expected runtime shape: Dictionary[StringName lookup_key, String branch_path_id].
@export var branch_table: Dictionary = {}

# Authored beat-text payloads (Story Event GDD #10 will own asset registry; this is the in-data text per GDD CR-5)
@export var beat_1_text_key: String = ""         # i18n key for Beat 1 anchor narrative
@export var beat_2_fragment: Dictionary = {}     # Multi-modal: visual_cue_id + audio_cue_id (Ch1: visual only)
@export var beat_3_text_key: String = ""
@export var beat_8_revelations: Array[Dictionary] = []  # Per-branch-key revelation: {branch_key, text_key, cue_tag}
@export var beat_9_text_key: String = ""

# Battle config payload (consumed at BEAT_4_PREP exit to construct BattlePayload)
@export var player_unit_ids: PackedInt64Array = []
@export var player_commander_id: int = -1
@export var enemy_unit_ids: PackedInt64Array = []
@export var deployment_positions_default: Dictionary = {}  # int (unit_id) → Vector2i (grid_coord)
@export var victory_conditions: VictoryConditions = null    # Typed Resource per BattlePayload spec
@export var defeat_conditions: VictoryConditions = null
@export var battle_start_effects: Array[BattleStartEffect] = []  # Typed Resource per BattlePayload spec

# Pillar 4 metadata for `is_canonical_history` payload-level enforcement (destiny-branch rev 1.1)
@export var canonical_branch_key: String = ""    # Per-chapter "official" branch id; F-SP-1 reads to set DestinyBranchChoice.is_canonical_history
```

**Hydration pipeline**: at LOADING state entry, ScenarioRunner reads `assets/data/scenarios/{scenario_id}.json`, parses with `JSON.parse_string()`, validates per scenario-progression.md §EC-SP-8 authoring validator (DRAW branch presence per author_draw_branch flag, echo_threshold ≥ 1 for Ch2+, branch_path_id regex `^[A-Za-z0-9_]+$`), and populates `Array[ChapterDefinition]` via per-record `ChapterDefinition.new()` + field assignment. The `.tres` form is reserved for future authored data files OR test fixtures; MVP uses pure JSON-to-Resource hydration.

**Why typed Resource** (not Dictionary, not pure runtime struct):

1. **Static-typing benefits** — F-SP-1 reads `chapter.author_draw_branch`, `chapter.branch_table`, `chapter.echo_threshold` — typed field access catches typos at parse time. Dictionary would defer to runtime KeyError.
2. **Precedent** — `MapResource` (ADR-0004), `HeroData` (ADR-0007), `BalanceConstants` (ADR-0007) all use `@export`-decorated typed Resources hydrated from JSON. ChapterDefinition follows the 3-precedent project pattern.
3. **Test fixture form** — typed Resource enables `.tres` test fixtures for unit tests of F-SP-1/F-SP-2/F-SP-3 (per scenario-progression.md §Acceptance Criteria AC-SP-9..AC-SP-15).
4. **Future expansion** — typed Resource supports adding fields without schema migration (Resource serialization is forward-compatible; unknown fields are dropped per ADR-0003 §Constraints).

### `BattleConfig` = Reuse `BattlePayload` Resource

ADR-0001 line 524 already locks `BattlePayload` Resource shape (`map_id`, `unit_roster`, `deployment_positions`, `victory_conditions`, `battle_start_effects`). `ScenarioRunner.get_active_battle_config(): BattlePayload` returns the same Resource constructed by `_build_battle_payload(chapter, deployment_positions)`.

**Why reuse `BattlePayload`** (not introduce new `BattleConfig` Resource):

1. **DRY** — the data ScenarioRunner emits via `battle_launch_requested(BattlePayload)` IS the data ADR-0016 `_ready()` consumes via `get_active_battle_config()`. Two names for the same shape would invite drift.
2. **ADR-0016 §Migration Plan §1 doesn't require a new type** — the line `var battle_config = ScenarioRunner.get_active_battle_config()` was a placeholder name; ADR-0017 ratifies it as `BattlePayload`. The variable name `battle_config` in BattleScene `_ready()` is fine; the type is `BattlePayload`.
3. **No additional fields needed** — beyond BattlePayload's 5 fields, BattleScene needs nothing else from ScenarioRunner at mount time. Beat 7 chapter context (chapter_id, branch resolution) flows through `chapter_completed(ChapterResult)` after battle, not into BattleScene at mount.

### Retry-Loop Guard: Enum-State Guard + Runtime Assertion

```gdscript
# At BEAT_6_RESULT "Retry" handler:
func _on_retry_confirmed() -> void:
    assert(_state == State.BEAT_6_RESULT, "EC-SP-7: retry requested from non-BEAT_6_RESULT state %s" % State.keys()[_state])
    var outcome: BattleOutcome.Result = _last_battle_outcome.result
    assert(outcome == BattleOutcome.Result.LOSS or outcome == BattleOutcome.Result.DRAW,
           "EC-SP-7: retry requested on WIN outcome (CR-8 violation)")
    if _scenario_state.echo_count >= ECHO_COUNT_HARD_CAP:
        push_warning("ScenarioRunner: echo_count cap reached at %d; suppressing retry UI per F-SP-3 overflow fence" % ECHO_COUNT_HARD_CAP)
        return  # Force player to accept outcome
    _scenario_state.echo_count += 1
    GameBus.scenario_beat_retried.emit(_make_echo_mark())
    _transition_to(State.BEAT_4_PREP)  # Beats 1/2/3 do NOT re-fire (CR-8)
```

**Two-layer defense**: (1) enum guard ensures retry can only be invoked from BEAT_6_RESULT state (prevents arbitrary-beat jumps per AC-SP-12 invariant); (2) `BattleOutcome.Result` assertion ensures retry only on LOSS/DRAW (prevents WIN→retry violation per CR-8).

`ECHO_COUNT_HARD_CAP = 100` — sourced from `BalanceConstants.scenario_progression_echo_cap` (matches `damage_calc_no_hardcoded_constants` precedent; configurable via balance-data.json without source change). Engine-side overflow fence per F-SP-3 v2.2 systems clarification — NOT a design target.

### F-SP-1 / F-SP-2 Execution: Delegated to `DestinyBranchJudge` (ADR-0018)

ScenarioRunner does NOT inline F-SP-1 (resolve_branch) or F-SP-2 (is_echo_gate_open). Per scenario-progression.md §F-SP-1 owner = scenario-progression / executor = DestinyBranchJudge (2026-04-19 patch), the formulas are pure functions delegated to `DestinyBranchJudge.resolve(chapter, outcome, echo_count, first_attempt_resolved) -> DestinyBranchChoice`.

```gdscript
# At BEAT_7_JUDGMENT entry (synchronous; per F-SP-3 v2.2 B-1 invariant):
func _enter_beat_7_judgment() -> void:
    # Seal first_attempt_resolved BEFORE resolve_branch reads it
    if _scenario_state.echo_count == 0:
        _scenario_state.first_attempt_resolved = true
    # Construct transient RefCounted judge per ADR-0018 §Class Form (DefaultDestinyBranchJudge
    # extends DestinyBranchJudge; @abstract _apply_f_sp_1 overridden to delegate to
    # ScenarioFormulas.resolve_branch). Static-utility-module form is REJECTED per ADR-0018
    # Alternative §2 (EC-DB-17 thread-safety: `static var` would be required for test
    # injection state and is forbidden in the judge class hierarchy). Judge is discarded
    # via RefCounted scope drop after resolve() returns. (Call site form widened per
    # /architecture-review delta #13, 2026-05-04 — was static-method call, now instance form
    # matching ADR-0018 ratification.)
    var judge: DestinyBranchJudge = DefaultDestinyBranchJudge.new()
    var choice: DestinyBranchChoice = judge.resolve(
        _scenario_state.current_chapter,
        _last_battle_outcome.result,
        _scenario_state.echo_count,
        _scenario_state.first_attempt_resolved,
    )
    # Display branch with min-dwell lockout; emit destiny_branch_chosen on player tap-advance
    _last_branch_choice = choice
    # ... (UI dwell + tap handling lives in BEAT_7_JUDGMENT exit)
    # `judge` goes out of scope at function end → RefCounted scope drop → memory reclaimed
```

**Why delegate to DestinyBranchJudge** (not inline in ScenarioRunner):

1. **Single Responsibility** — F-SP-1 / F-SP-2 are pure formulas; their logic is testable in isolation without ScenarioRunner state. Class-level separation enables targeted unit tests per AC-SP-9..AC-SP-13.
2. **ADR-0017 / ADR-0018 boundary** — ADR-0017 owns the formula *spec* (callable signature, behavior, edge cases). ADR-0018 owns the formula *executor class* (DestinyBranchJudge) AND the typed payload (DestinyBranchChoice). Separation prevents ADR sprawl.
3. **Substitutability** — future Ch4+ may introduce alternative branch resolution logic (e.g., echo-gated ALL outcomes); replacing DestinyBranchJudge does not touch ScenarioRunner.

### Architecture Diagram

```
                        ┌─────────────────────────────────────────────────┐
                        │              GameBus (autoload, ADR-0001)        │
                        │       Scenario Domain (5+2 signals)              │
                        └────────────┬────────────────────┬───────────────┘
                                     │ emits              │ subscribes
                                     │                    │ battle_outcome_resolved
        ┌────────────────────────────▼────────────────────▼───────────────┐
        │                        ScenarioRunner (autoload, this ADR)       │
        │                                                                  │
        │   ┌─────────────────┐    13-state machine (enum + match)         │
        │   │ ScenarioState   │       LOADING → CHAPTER_START → BEAT_1     │
        │   │ ─────────────── │           → BEAT_2 → BEAT_3 → BEAT_4       │
        │   │ chapter_index   │           → BATTLE_LOADING → BEAT_5        │
        │   │ current_chapter │           → BEAT_6 ⇄ (retry) BEAT_4        │
        │   │ echo_count      │           → BEAT_7 → BEAT_8 → BEAT_9       │
        │   │ first_attempt_  │           → SCENARIO_END                   │
        │   │   resolved      │                                            │
        │   │ chapters[]      │   ┌──────────────────────────────┐         │
        │   │ scenario_id     │   │ DestinyBranchJudge (ADR-0018) │         │
        │   └─────────────────┘   │ ──────────────────────────── │         │
        │                          │ resolve(...)                 │         │
        │   ┌─────────────────┐   │   → DestinyBranchChoice       │         │
        │   │ ChapterLoader   │   └──────────────────────────────┘         │
        │   │ ─────────────── │           ▲ called at BEAT_7 entry          │
        │   │ load(scenario_  │           │                                 │
        │   │   id)           │           │                                 │
        │   │   → JSON.parse  │           │                                 │
        │   │   → validate    │           │                                 │
        │   │   → Array[      │           │                                 │
        │   │     ChapterDef] │           │                                 │
        │   └─────────────────┘           │                                 │
        └─────────┬────────────────────────────────────────────────────────┘
                  │ emits (5 confirmed + 2 ratified)
                  │
                  │ chapter_started(ChapterContext)
                  │ battle_prepare_requested(BattlePayload)
                  │ battle_launch_requested(BattlePayload)  ──────► SceneManager (ADR-0002)
                  │ chapter_completed(ChapterResult)        ──────► Destiny State, Save/Load
                  │ scenario_complete(ScenarioResult)
                  │ scenario_beat_retried(EchoMark)         ──────► Destiny State
                  │ save_checkpoint_requested(SaveContext)  ──────► SaveManager (ADR-0003)
                  ▼
        ┌─────────────────────────────────────────────────────────────────┐
        │              assets/data/scenarios/{scenario_id}.json            │
        │   3-5 chapter records per scenario; loaded at LOADING entry      │
        └─────────────────────────────────────────────────────────────────┘
```

### Key Interfaces

```gdscript
# ScenarioRunner public API
# G-3: NO `class_name ScenarioRunner` — the autoload-registered identifier is the global name
extends Node

## Returns the active BattlePayload constructed from the current chapter +
## current deployment positions. Called by BattleScene._ready() at sprint-7+
## post-mock-encoder-deletion patch (ADR-0016 Migration Plan §1).
func get_active_battle_config() -> BattlePayload

## Returns the current chapter index (0-based) for save/load + Story Event consumers.
## NOT a signal; a query method. Subscribers use chapter_started signal for boundary events.
func get_current_chapter_index() -> int

## Returns the active ChapterDefinition (read-only; do NOT mutate).
## Returns null if state is LOADING or SCENARIO_END.
func get_current_chapter() -> ChapterDefinition

## Returns the current echo_count for the current chapter (per F-SP-3).
## Reset to 0 at each Beat 9 transition.
func get_current_echo_count() -> int

## Returns the current state for diagnostics + lint enforcement.
## State enum is exported for test seam usage.
func get_state() -> State

## State enum exposed for test fixtures + lint.
enum State { LOADING, CHAPTER_START, BEAT_1_ANCHOR, BEAT_2_ECHO, BEAT_3_BRIEF, BEAT_4_PREP, BATTLE_LOADING, BEAT_5_BATTLE, BEAT_6_RESULT, BEAT_7_JUDGMENT, BEAT_8_REVEAL, BEAT_9_TRANSITION, SCENARIO_END }
```

```gdscript
# ChapterDefinition Resource — see Decision §Chapter Data Form above
class_name ChapterDefinition extends Resource
# 13 @export fields per scenario-progression.md §CR-5/CR-7/CR-14/CR-16 lock
```

```gdscript
# BattlePayload Resource — already defined in ADR-0001 + src/core/payloads/battle_payload.gd
# ScenarioRunner reuses this shape for both battle_prepare_requested and battle_launch_requested signal emissions
# AND for get_active_battle_config() return type. No new BattleConfig Resource needed.
```

```gdscript
# ChapterResult Resource — already defined in ADR-0001 §1
class_name ChapterResult extends Resource
@export var chapter_id: String = ""
@export var outcome: BattleOutcome.Result = BattleOutcome.Result.WIN  # tri-state
@export var branch_triggered: String = ""    # = DestinyBranchChoice.branch_key
@export var flags_to_set: PackedStringArray = []
```

```gdscript
# EchoMark Resource — ALREADY SHIPPED at src/core/payloads/echo_mark.gd per ADR-0003 §Schema Stability.
# 3-field MVP baseline schema (beat_index / outcome / tag); evolves via SaveMigrationRegistry per
# ADR-0003 + scenario-progression epic story-006 (future). ADR-0017 does NOT redefine EchoMark.
# scenario-progression.md GDD line 183 lists a provisional 4-field shape (chapter_id, beat_number,
# retry_count, timestamp_unix); the SHIPPED 3-field schema supersedes this provisional form per
# ADR-0003 §EchoMark Resource Contract (BLOCKING). Future schema evolution (e.g., adding chapter_id
# back) MUST go through SaveMigrationRegistry to preserve save-file backward compatibility.
class_name EchoMark extends Resource
@export var beat_index: int = 0       # 1..9, the beat at which this echo was accumulated
@export var outcome: StringName = &""  # narrative tag (StringName)
@export var tag: StringName = &""      # downstream-query tag
```

```gdscript
# ScenarioResult Resource — emitted at SCENARIO_END
class_name ScenarioResult extends Resource
@export var chapter_outcomes: Array[Dictionary] = []  # [{chapter_id, branch_path_id, echo_count_at_completion}, ...]
@export var canonical_delta: PackedStringArray = []   # Per-scenario authored list
@export var scenario_path_key: String = ""             # F-SP-4 composition: branch_path_ids joined by "::"
@export var total_echo: int = 0                        # Sum of echo_count_at_completion across all chapters
```

### JSON Schema (`assets/data/scenarios/{scenario_id}.json`)

```json
{
  "scenario_id": "mvp_shu",
  "scenario_title_key": "scenario.mvp_shu.title",
  "chapters": [
    {
      "chapter_id": "ch01_taoyuan_oath",
      "chapter_number": 1,
      "map_id": "map_taoyuan",
      "author_draw_branch": false,
      "echo_threshold": 0,
      "branch_table": {
        "WIN_default":  "WIN_taoyuan_default",
        "LOSS_default": "LOSS_taoyuan_default"
      },
      "canonical_branch_key": "WIN_taoyuan_default",
      "beat_1_text_key": "ch01.beat1.anchor",
      "beat_2_fragment": {
        "variant": "silent_visual",
        "visual_cue_id": "scenario.opening_glyph",
        "audio_cue_id": null
      },
      "beat_3_text_key": "ch01.beat3.brief",
      "beat_8_revelations": [
        {"branch_key": "WIN_taoyuan_default", "text_key": "ch01.beat8.win", "cue_tag": null},
        {"branch_key": "LOSS_taoyuan_default", "text_key": "ch01.beat8.loss", "cue_tag": null}
      ],
      "beat_9_text_key": "ch01.beat9.transition",
      "player_unit_ids": [1, 2, 3],
      "player_commander_id": 1,
      "enemy_unit_ids": [101, 102, 103],
      "deployment_positions_default": {"1": [3,5], "2": [4,5], "3": [5,5]},
      "victory_conditions": "victory_rout_all_enemies",
      "defeat_conditions": "defeat_commander_dead",
      "battle_start_effects": []
    }
    // ... ch02, ch03, ...
  ]
}
```

**Validation pipeline** (at LOADING entry; per scenario-progression.md §EC-SP-8):

1. Parse with `JSON.parse_string()`; on parse error → `push_error` + emit `scenario_fault(scenario_id, "json_parse_failed")`.
2. Validate top-level: `scenario_id` String + `chapters` Array.
3. Per-chapter validation (FATAL on any failure):
   - `chapter_id` String matches regex `^[a-z][a-z0-9_]*$`
   - `branch_table` Dictionary; each value matches regex `^[A-Za-z0-9_]+$` per F-SP-4 delimiter constraint
   - `author_draw_branch == true` IMPLIES at least one branch_key starts with `"DRAW_"`
   - `echo_threshold == 0` AND `chapter_number == 1` → OK; otherwise `echo_threshold ≥ 1`
   - All `beat_8_revelations` entries reference branch_keys in `branch_table.values()`
   - `canonical_branch_key` is in `branch_table.values()` (Pillar 4 enforcement per destiny-branch rev 1.1)
4. On any FATAL: `_load_scenario_failed = true`; emit `scenario_fault(scenario_id, fault: "validation_failed", details: ...)`; return early. ScenarioRunner remains in LOADING state.

**Note**: ChapterDefinition Resource is hydrated from validated JSON; if validation fails, no Resource is constructed, preventing partial-state hazards.

## Alternatives Considered

### Alternative 1: Scene-Mounted ScenarioRunner (Mounted Under Overworld + Re-Mounted Per Scene)

- **Description**: Make ScenarioRunner a child Node of the Overworld scene root; re-mount on each scene transition.
- **Pros**: No autoload registration needed; clearer scene-local scoping.
- **Cons**: Loses state across BattleScene mount cycle (per ADR-0002 RETURNING_FROM_BATTLE → IDLE); requires explicit state-restore-from-SaveContext after every scene transition; doubles the save/restore code; violates the "13-state machine is per-scenario, not per-scene" GDD intent.
- **Rejection Reason**: Cross-scene state continuity is the core value of ScenarioRunner; scene-mounted form would require state-restore at every transition which is the inverse of the autoload pattern.

### Alternative 2: Dictionary-Based Chapter Data (No Typed Resource)

- **Description**: Store `Array[Dictionary]` in ScenarioRunner; access via `chapter["author_draw_branch"]`, `chapter["branch_table"]`, etc.
- **Pros**: Simpler hydration (just `JSON.parse_string()`); no Resource class to author.
- **Cons**: Loses static-typing benefits; F-SP-1 typo on `chapter["author_draw_branch"]` vs `chapter["author_draw_branch_"]` deferred to runtime KeyError; test fixtures harder to author; no `.tres` form for unit tests.
- **Rejection Reason**: ADR-0007 HeroData precedent shows the typed-Resource path is well-trodden; static-typing benefits + test-fixture form outweigh the small authoring overhead.

### Alternative 3: Inline F-SP-1 / F-SP-2 in ScenarioRunner (No DestinyBranchJudge Class)

- **Description**: ScenarioRunner directly evaluates `branch_key = chapter.branch_table[outcome][echo_count >= echo_threshold]`; no separate DestinyBranchJudge class.
- **Pros**: One fewer class; one fewer ADR (ADR-0018 collapses into ADR-0017).
- **Cons**: Couples branch resolution logic to ScenarioRunner state; pure-function unit tests of F-SP-1 / F-SP-2 require ScenarioRunner instantiation; substitutability lost; ADR sprawl prevention (a single 800-line ADR vs two 400-line ADRs) less maintainable.
- **Rejection Reason**: scenario-progression.md §F-SP-1 owner-vs-executor split (2026-04-19 patch) explicitly chose delegation. ADR-0017 ratifies this split; ADR-0018 owns DestinyBranchJudge + DestinyBranchChoice payload.

### Alternative 4: StateMachine Class with Class-Per-State

- **Description**: Each state (BEAT_1_ANCHOR, BEAT_2_ECHO, ...) is a separate class extending a StateMachineState base; ScenarioRunner has `_current_state: StateMachineState` and dispatches via virtual method.
- **Pros**: Encapsulates per-state logic; SOLID Single Responsibility; common in larger state machines.
- **Cons**: 13 state classes for 13 states; over-engineered for ScenarioRunner's complexity (most states are 5-10 LoC handlers); breaks SceneManager precedent; F-SP-3 v2.2 synchronous-seal-discipline becomes harder to verify across class boundaries.
- **Rejection Reason**: SceneManager (ADR-0002) precedent uses enum + match; ScenarioRunner is similar complexity. Class-per-state is right for 50+ states or fundamentally different per-state behavior; not for this case.

## Consequences

### Positive

- **Sprint-6 mock encoder unblocks for deletion** — at this ADR's implementation acceptance, ADR-0016 Migration Plan §1 mechanically reverts (project.godot + ~50 LoC + lint flip + smoke evidence re-author) in a single coordinated patch.
- **ADR-0018 Destiny Branch unblocks** — F-SP-1/F-SP-2 callable signatures locked here enable DestinyBranchJudge authoring without further ADR-0017 amendments.
- **Battle Preparation epic foundation laid** — sprint-7+ Battle Prep epic subscribes to `battle_prepare_requested` emission; ScenarioRunner provides the emission point + payload shape.
- **Save Slot UI unblocks** — save slots can enumerate via `ScenarioRunner.get_current_chapter_index()` + SaveContext lookups.
- **Pillar 4 (삼국지의 숨결) infrastructure** — chapter-to-chapter state continuity (`echo_marks_archive` flow + `scenario_path_key` composition) is the load-bearing infrastructure for the "지난 장의 선택이 합류 명단과 환경 라벨에 살아 있다" player fantasy.
- **Pillar 2 (운명은 바꿀 수 있다) infrastructure** — retry-loop + echo-gate + `first_attempt_resolved` seal discipline is the load-bearing infrastructure for the "어렵지만 가능하게 한다" player fantasy.

### Negative

- **Autoload-boot-order coupling** — ScenarioRunner depends on GameBus + SceneManager + SaveManager being booted first; project.godot autoload ordering is now 6 entries deep. Mitigation: explicit boot-order documentation in CLAUDE.md + project.godot inline comment.
- **Sprint-6 mock encoder lifetime** — ADR-0016 sprint-6 mock encoder must remain in source from sprint-6 close (2026-05-30) through sprint-7+ ScenarioRunner implementation. The 3 lint scripts (story-003) enforce marker-presence discipline during this window. Mitigation: ADR-0016 Migration Plan §1 + this ADR §Migration Plan codify the mechanical revert.
- **JSON validation runtime cost** — full per-record validation pipeline runs at LOADING entry; ~50ms cold load on Snapdragon 7-gen for 5-chapter scenario. Mitigation: validation is one-shot at scenario start; not in any per-frame budget.
- **No mid-battle save** — per scenario-progression.md CR-15 #10. App suspension on mobile resumes from most recent CP; player loses sub-CP progress. Mitigation: documented in player-facing UX; not a ScenarioRunner-level mitigation.

### Risks

- **Risk 1: Boot-order misconfiguration crashes startup** — if ScenarioRunner is registered before GameBus in project.godot, ScenarioRunner._ready() crashes on `GameBus.battle_outcome_resolved.connect(...)`. Mitigation: project.godot inline comment block explicitly listing boot order; future CI lint `lint_autoload_order.sh` (low priority).
- **Risk 2: F-SP-3 seal-timing violation by future refactor** — if a future developer wraps `_enter_beat_7_judgment()` in `call_deferred()` for "frame budget reasons", the seal occurs after subsequent frames have processed `on_player_retry()` increments, corrupting `first_attempt_resolved`. Mitigation: F-SP-3 v2.2 invariant inline comment in source + future CI lint `lint_scenario_runner_no_deferred_in_beat_7_seal.sh`.
- **Risk 3: branch_table runtime mutation** — if a future developer mutates `chapter.branch_table[key] = "..."` at runtime (e.g., for "dynamic difficulty" feature), CR-15 #4 + AC-SP-12 invariant breaks; replays diverge from save state. Mitigation: forbidden_pattern `scenario_runner_branch_table_runtime_mutation` registered in this ADR; future CI lint `lint_scenario_runner_branch_table_immutable.sh`.
- **Risk 4: SaveContext partial emit** — if `save_checkpoint_requested` is emitted with incomplete SaveContext (e.g., missing echo_count after retry), restore corrupts. Mitigation: SaveContext construction goes through single `_make_save_context(cp_kind: SaveCheckpoint)` helper; helper asserts all required fields populated before emission.
- **Risk 5: scenario_fault chain — silent failure** — if validation fails and `scenario_fault` is emitted but no UI listener is registered, the player sees a black screen with no recovery path. Mitigation: SceneManager subscribes to `scenario_fault` (per ADR-0002) and surfaces a retry/abort dialog; verified at sprint-7+ implementation.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `scenario-progression.md` §CR-1 (Chapter as atomic unit) | 1 chapter = 1 battle + 8 surrounding ceremony beats; chapters in linear order | 13-state machine encodes the 9 chapter beats + LOADING + CHAPTER_START + BATTLE_LOADING sub-state + SCENARIO_END; chapter advancement only via BEAT_9_TRANSITION → LOADING. |
| §CR-2 (9-beat canonical rhythm) | Every chapter follows 9 beats in fixed order | State enum + transition table 1:1 maps to GDD §States and Transitions. No skip-state API exposed. |
| §CR-3 (Tri-state outcome) | {WIN, DRAW, LOSS}; no synthesis or override | ScenarioRunner consumes BattleOutcome.result via `battle_outcome_resolved`; never assigns the field. |
| §CR-5 (Branch selection formula) | `branch_key = chapter.branch_table.lookup({outcome, echo_count, is_draw_fallback})` | F-SP-1 owned here; executed by `DestinyBranchJudge.resolve(...)` per ADR-0018. ScenarioRunner calls at BEAT_7_JUDGMENT entry (synchronous, post-seal). |
| §CR-6 (Echo-gated branch rule) | DRAW + echo_count ≥ threshold + NOT first_attempt_resolved | F-SP-2 callable signature locked here; `is_echo_gate_open(outcome, echo_count, echo_threshold, first_attempt_resolved) -> bool`. Reuses F-SP-1 evaluation pipeline. |
| §CR-7 (Echo accumulation per-chapter) | echo_count++ on retry; reset to 0 at Beat 9 | F-SP-3 codified in `_on_retry_confirmed()` + `_enter_beat_9_transition()`. echo_count is in-memory only (per CR-7); persisted via `EchoMark` archive in Destiny State (out of scope this ADR). |
| §CR-7 + F-SP-3 v2.2 (first_attempt_resolved seal) | Sealed at BEAT_7 entry SYNCHRONOUSLY | `_enter_beat_7_judgment()` is called synchronously from BEAT_6 accept-handler; no `call_deferred`; F-SP-3 v2.2 systems-designer B-1 invariant respected; future lint enforces. |
| §CR-8 (Retry semantics) | Retry only on LOSS/DRAW; re-enter Beat 4 with prior deployment; Beats 1/2/3 do NOT re-fire | `_on_retry_confirmed()` enum-state guard + outcome assertion + transition direct to BEAT_4_PREP. |
| §CR-15 (Hard constraints) | 10 player-cannot-do invariants | Enforced via state guards (no arbitrary jumps), assertion preconditions (no WIN→retry; no skip-Beat-2), CR-7 reset (no cross-chapter echo carry), forbidden_patterns registry entries (no runtime branch_table mutation; no save during BEAT_5). |
| §CR-16 (Scenario-end contract) | scenario_complete(ScenarioResult) at last chapter Beat 9 | BEAT_9_TRANSITION exit branches: more chapters → next LOADING; no more chapters → SCENARIO_END entry → emit `scenario_complete(ScenarioResult)`. F-SP-4 composes `scenario_path_key` from collected per-chapter `branch_path_id`s. |
| §F-SP-1..F-SP-5 | All 5 formulas | F-SP-1/F-SP-2 delegated to DestinyBranchJudge; F-SP-3 inline in `_on_retry_confirmed()` + `_enter_beat_9_transition()`; F-SP-4 inline in `_compose_scenario_path_key()`; F-SP-5 producer-side authoring tool (not runtime; out of ADR scope). |
| §EC-SP-1..EC-SP-9 | 9 edge cases | Validator pipeline at LOADING entry covers EC-SP-1/2/3/4/8 (data integrity); state guards cover EC-SP-5/6/7 (timing); EC-SP-9 covered via SceneManager `scenario_fault` subscription. |
| §AC-SP-1..AC-SP-19 | 19 acceptance criteria | Sprint-7+ implementation stories will trace 1:1 to AC-SP-N; this ADR provides the architectural foundation. |
| `destiny-branch.md` (related) | DestinyBranchJudge + DestinyBranchChoice | ADR-0018 owns the executor + payload; ADR-0017 owns the calling convention + signal emission of `destiny_branch_chosen` at BEAT_7 exit (post-tap-advance). |
| `save-load.md` (provisional) | SaveContext shape + 3-CP timing | Locked in ADR-0003; this ADR ratifies the 3 emission timing points (CP-1 BEAT_1 entry, CP-2 BEAT_7 entry post-seal, CP-3 BEAT_9 entry). |
| `game-concept.md` Pillar 4 | "지난 장의 선택이 살아 있다" | `scenario_path_key` composition (F-SP-4) + `chapter_outcomes` archive in ScenarioResult provide the substrate for environment-label / roster-availability conditioning. |
| `game-concept.md` Pillar 2 | "운명은 바꿀 수 있다" | retry-loop + echo-gate + first_attempt_resolved seal provide the mechanical substrate for "어렵지만 가능하게 한다." Hidden-fate signaling enforcement (no hidden_fate_condition_progressed subscriber on Battle HUD per Pillar 2 lock) preserved through ScenarioRunner non-emission of fate-progress to non-judgment subscribers. |

## Performance Implications

- **CPU**: <50ms one-shot at LOADING entry (JSON parse + 5-chapter validation). Per-frame cost in steady state: 0ms (event-driven; no `_process` body). Per-state-transition cost: <0.1ms (enum match + signal emit). Per-retry-loop cost: <0.5ms (enum reset + echo_count++ + signal emit + state transition).
- **Memory**: ~5-10 KB resident for `Array[ChapterDefinition]` (5 chapters × ~1-2 KB per ChapterDefinition Resource). `_scenario_state` struct: <1 KB. Total ScenarioRunner footprint: <20 KB. Well within ADR-0001 GameBus budget envelope.
- **Load Time**: One-shot ~50ms at scenario start (LOADING state); not in critical path of frame budget. No additional load time at scene transitions (ScenarioRunner persists; no re-load).
- **Network**: N/A — ScenarioRunner is single-player; no network surface.

## Migration Plan

**Sprint-6 → Sprint-7+ transition (single coordinated patch when this ADR's implementation lands)**:

1. **Create `src/core/scenario_runner.gd`** — `extends Node` (NO `class_name` per G-3 autoload rule); full implementation per this ADR's §Decision section. Estimated 600-800 LoC including state machine + chapter loader + 7 signal emission paths + retry-loop guard + 3-CP save integration.
2. **Create `src/core/payloads/chapter_definition.gd`** — class_name ChapterDefinition extends Resource; 13 @export fields per §Decision.
3. **EchoMark already shipped at `src/core/payloads/echo_mark.gd`** — 3-field schema (beat_index / outcome / tag) ratified by ADR-0003 §Schema Stability. ADR-0017 does NOT redefine EchoMark; ScenarioRunner emits `scenario_beat_retried(EchoMark)` per the shipped schema. If sprint-7+ design surfaces a need for additional EchoMark fields (e.g., chapter_id, retry_count), the change goes through SaveMigrationRegistry per ADR-0003 — NOT inline schema rewrite. Coordinate with Save/Load epic owner.
4. **Create `src/core/payloads/scenario_result.gd`** — class_name ScenarioResult extends Resource.
5. **Create `assets/data/scenarios/mvp_shu.json`** — 3-5 chapter MVP authored content; coordinate with Balance/Data #27 author for schema lock + canonical_branch_key Pillar 4 enforcement.
6. **Register `ScenarioRunner` autoload** — add to `project.godot` `[autoload]` after `BuildModeSentinel`, before any future autoloads. Boot order: GameBus → SceneManager → SaveManager → GameBusDiagnostics → BuildModeSentinel → **ScenarioRunner**.
7. **Revert ADR-0016 sprint-6 mock encoder** — `src/feature/battle_scene/battle_scene.gd` lines between `# === SPRINT-6 MOCK ENCOUNTER ===` markers replaced with `var battle_config = ScenarioRunner.get_active_battle_config()`. Delete entire `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===` block (~50 LoC). Update doc-comment block IN-N entries.
8. **Revert `project.godot` `run/main_scene`** — change to title-screen / overworld entry per ADR-0017's chosen post-flip target (likely `scenes/main_menu/main_menu.tscn` or `scenes/overworld/overworld.tscn` — to be determined at implementation time per current Main Menu / Overworld epic state).
9. **Flip lint `lint_battle_scene_sprint6_mock_marker.sh`** — semantic flip from "marker MUST exist" to "marker MUST NOT exist"; mechanical edit to the loop body in the bash script (change `if ! grep ... ; FAILED=1` to `if grep ... ; FAILED=1`); update inline header comment block.
10. **Re-author smoke evidence doc** — `production/qa/evidence/battle_scene_smoke_2026-XX-XX.md` (sprint-7+ date) covering the new launch path (SceneManager-driven launch source (a) per ADR-0016 V-11; cross-launch-source matrix updated). Old `battle_scene_smoke_2026-05-04.md` archived (not deleted) for traceability.
11. **Update `production/qa/evidence/battle_scene_verification_summary.md` §E** — close the Migration Plan revert chapter with a note that Steps 7-10 completed at this commit.
12. **Add 3 ScenarioRunner-domain CI lints** (sprint-7+ scope; out-of-this-ADR but tracked):
    - `lint_scenario_runner_state_match_exhaustive.sh` (state-machine lint)
    - `lint_scenario_runner_no_deferred_in_beat_7_seal.sh` (F-SP-3 v2.2 invariant)
    - `lint_scenario_runner_branch_table_immutable.sh` (CR-15 #4 invariant)

**Patch atomicity**: Steps 1-11 ship in a single commit. Step 12 lints land in a follow-up "ScenarioRunner CI hardening" sprint-7+ story.

## Validation Criteria

- **Unit tests** (sprint-7+ scope per AC-SP-9..AC-SP-15): F-SP-1 / F-SP-2 / F-SP-3 callable contract tests via DestinyBranchJudge + ScenarioState fixtures. Coverage target: 100% of formula branches + EC-SP-1..EC-SP-9 edge cases.
- **Integration tests** (sprint-7+): full 13-state machine traversal with mocked GridBattleController + GameBus capture; assertion of 5+2 signal emissions at correct state boundaries; 3-CP `save_checkpoint_requested` emission timing; retry-loop integrity (deployment preserved + echo_count++ + Beats 1/2/3 not re-fired).
- **Smoke evidence** (sprint-7+): `production/qa/evidence/scenario_runner_3_chapter_mvp_2026-XX-XX.md` documenting full 3-chapter playthrough with Beat 7 reserved-color treatment + DRAW-branch reachability at anchor moment Ch3.
- **Performance** (sprint-7+): JSON-load-to-CHAPTER_START transition <100ms cold; per-state-transition <1ms steady-state.
- **Authoring validator** (build-time, separate sprint-7+ tooling): scans `assets/data/scenarios/*.json` and rejects malformed branch_tables, missing canonical_branch_key, echo_threshold violations per §EC-SP-8.

## Implementation Notes

(Note section reserved for implementation drift trail per project precedent — same shape as ADR-0016's IN-N entries appended during S6-07 implementation. To be populated when sprint-7+ implementation surfaces production-signature drifts.)

**IN-1 (godot-specialist /architecture-review delta #12 ADVISORY 2026-05-04 — test fixture State enum access)**: The `enum State { ... }` declared at line ~306 of the autoload script body IS accessible via the autoload global identifier (`ScenarioRunner.State.LOADING`) at runtime — this is the same pattern SceneManager uses per ADR-0002 precedent. **However**, GdUnit4 test fixtures that load the script directly via `load("res://src/core/scenario_runner.gd")` (without booting the full autoload stack — common in headless unit tests) MUST access the enum via the loaded GDScript's constant map: `(load("res://src/core/scenario_runner.gd") as GDScript).get_script_constant_map()` — direct `ScenarioRunner.State.X` will fail in that context. Sprint-7+ test author: prefer the autoload-syntax form for integration tests; use the constant-map form only for unit-level isolation. Same gotcha shape as G-3 §Test consequence in `.claude/rules/godot-4x-gotchas.md`.

**IN-2 (godot-specialist /architecture-review delta #12 ADVISORY 2026-05-04 — Time vs OS API)**: `_state_entered_at_msec: int = 0` field at line ~110 is populated for min-dwell-time enforcement (CR-2 1s/2s/1.5s gates). Sprint-7+ implementer MUST use `Time.get_ticks_msec()` — NOT the deprecated `OS.get_ticks_msec()` (deprecated since Godot 4.0 per `docs/engine-reference/godot/deprecated-apis.md`). Same precedent across the project (no `OS.get_ticks_msec()` calls in `src/`).

## Forbidden Patterns

(To be registered in `docs/registry/architecture.yaml` at registry-update step. Listed here for traceability.)

1. **`scenario_runner_arbitrary_state_jump`** — `ScenarioRunner._state` MUST only transition via the `_transition_to(target: State)` method which validates the transition is legal per the §States and Transitions table. Direct `_state = State.X` assignment outside `_transition_to` is forbidden. Lint: future `lint_scenario_runner_state_match_exhaustive.sh` enforces.
2. **`scenario_runner_branch_table_runtime_mutation`** — `ChapterDefinition.branch_table` MUST be treated as read-only after LOADING state exit. Runtime mutation (e.g., `chapter.branch_table[key] = "..."`) corrupts replay determinism + save-state integrity. Lint: future `lint_scenario_runner_branch_table_immutable.sh` enforces.
3. **`scenario_runner_save_context_partial_emit`** — `save_checkpoint_requested(SaveContext)` MUST emit a fully-populated SaveContext. Partial emits (e.g., missing `echo_count` after retry) corrupt restore. All emissions go through `_make_save_context(cp_kind)` helper which asserts completeness. Lint: future `lint_scenario_runner_save_context_complete.sh` enforces.
4. **`scenario_runner_deferred_seal_in_beat_7_entry`** — F-SP-3 v2.2 systems-designer B-1 invariant: `_enter_beat_7_judgment()` MUST be called synchronously from the BEAT_6_RESULT accept-handler before any deferred callbacks process. No `call_deferred("_enter_beat_7_judgment")`; no `CONNECT_DEFERRED` between BEAT_6 exit and BEAT_7 seal. Lint: future `lint_scenario_runner_no_deferred_in_beat_7_seal.sh` enforces.
5. **`scenario_runner_outcome_synthesis`** — ScenarioRunner MUST NOT assign or override `BattleOutcome.result`. Per CR-3, the tri-state is owned by GridBattleController exclusively. Lint: trivially enforced by zero `result =` writes in `scenario_runner.gd` (verifiable by grep).

## Related Decisions

- **ADR-0001** (Accepted) — GameBus signal contract; Scenario domain owner of 5+2 signals; ratifies provisional `scenario_beat_retried` + `save_checkpoint_requested` as Accepted via this ADR
- **ADR-0002** (Accepted) — SceneManager Overworld↔BattleScene transition lifecycle; subscribes to `battle_launch_requested`; emits `scenario_fault` consumer for player-facing retry/abort dialog
- **ADR-0003** (Accepted) — Save/Load SaveContext shape; ScenarioRunner is sole emitter of `save_checkpoint_requested` at 3 timing points
- **ADR-0014** (Accepted) — GridBattleController emits `battle_outcome_resolved`; consumed by ScenarioRunner at BEAT_5_BATTLE → BEAT_6_RESULT transition
- **ADR-0016** (Accepted) — BattleScene Wiring; sprint-6 mock encoder Migration Plan §1 reverts at this ADR's implementation
- **ADR-0018** (Backlog; this ADR enables) — Destiny Branch; owns DestinyBranchJudge executor + DestinyBranchChoice payload; F-SP-1/F-SP-2 spec ownership stays at scenario-progression.md per 2026-04-19 patch
- **`design/gdd/scenario-progression.md`** — primary design source; 16 CR + 5 F-SP + 9 EC-SP + 19 AC-SP all addressed in this ADR
- **`design/gdd/destiny-branch.md`** — peer GDD; F-SP-1/F-SP-2 executor + DestinyBranchChoice payload owned there
- **`design/gdd/game-concept.md`** Pillar 2 + Pillar 4 — narrative pillars this ADR provides the load-bearing infrastructure for
