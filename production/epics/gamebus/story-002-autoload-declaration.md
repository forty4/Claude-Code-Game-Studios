# Story 002: GameBus autoload declaration + registration

> **Epic**: gamebus
> **Status**: Ready
> **Layer**: Platform
> **Type**: Logic
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; spec from ADR-0001 §Key Interfaces)
**Requirement**: `TR-gamebus-001`

**ADR Governing Implementation**: ADR-0001 — GameBus Autoload — Cross-System Signal Relay
**ADR Decision Summary**: Single Godot autoload singleton at `/root/GameBus` declaring 27 signals across 10 domains (scenario, battle, turn, unit, destiny, beat, input, ui, save, environment). Holds ZERO game state. Banner comments organize signals by domain.

**Engine**: Godot 4.6 | **Risk**: LOW (autoload + signal API stable since 4.0)
**Engine Notes**: Autoload order is boot-sensitive — GameBus MUST be first. Typed signal payloads with Resource types use the 4.2+ typed-signal feature (strictness tightened 4.5, verified compatible).

**Control Manifest Rules (Platform layer)**:
- Required: GameBus autoload at `/root/GameBus`, load order 1 in `project.godot`
- Required: Zero state — only `signal` declarations + doc comments + banner comments
- Required: Signal naming `{domain}_{event}_{past_tense}`
- Forbidden: `var` or `func` declarations in `game_bus.gd` (CI-lint-enforced)
- Forbidden: Per-frame emits from `_process`/`_physics_process` (verified by Story 008 lint)

## Acceptance Criteria

*Derived from ADR-0001 §Key Interfaces + §Implementation Guidelines §1 + §2 + §Signal Contract Schema:*

- [ ] `src/core/game_bus.gd` — `extends Node`, no `class_name` (autoload singletons are named by autoload registration, not class_name — avoids global class pollution); header docstring per ADR-0001 §Key Interfaces example (RULES section + "DO NOT add fields/methods" warning)
- [ ] 10 banner comments in file (Scenario Progression, Grid Battle, Turn Order, HP/Status, Destiny, Story Event / Beat, Input, UI / Flow, Persistence, Environment) — per ADR-0001 §Key Interfaces code block
- [ ] All 27 signals declared with correct typed signatures per ADR-0001 §Signal Contract Schema:
  - Domain 1 (Scenario, 6 signals): `chapter_started(String, int)`, `battle_prepare_requested(BattlePayload)`, `battle_launch_requested(BattlePayload)`, `chapter_completed(ChapterResult)`, `scenario_complete(String)`, `scenario_beat_retried(EchoMark)` *(PROVISIONAL — payload class not yet required at file-parse time; declared with EchoMark from save-manager epic OR as placeholder Resource; resolve at implementation time)*
  - Domain 2 (Grid Battle, 1 signal): `battle_outcome_resolved(BattleOutcome)`
  - Domain 3 (Turn Order, 3 signals): `round_started(int)`, `unit_turn_started(int)`, `unit_turn_ended(int, bool)`
  - Domain 4 (HP/Status, 1 signal): `unit_died(int)`
  - Domain 5 (Destiny, 3 signals): `destiny_branch_chosen(DestinyBranchChoice)` *(PROVISIONAL)*, `destiny_state_flag_set(String, bool)`, `destiny_state_echo_added(EchoMark)` *(PROVISIONAL)*
  - Domain 6 (Beat, 3 signals): `beat_visual_cue_fired(BeatCue)` *(PROVISIONAL)*, `beat_audio_cue_fired(BeatCue)` *(PROVISIONAL)*, `beat_sequence_complete(int)`
  - Domain 7 (Input, 3 signals): `input_action_fired(String, InputContext)`, `input_state_changed(int, int)`, `input_mode_changed(int)`
  - Domain 8 (UI/Flow, 3 signals): `ui_input_block_requested(String)`, `ui_input_unblock_requested(String)`, `scene_transition_failed(String, String)`
  - Domain 9 (Persistence, 3 signals): `save_checkpoint_requested(SaveContext)` *(SaveContext from save-manager epic — this file parses OK once save-manager Story 001 lands)*, `save_persisted(int, int)`, `save_load_failed(String, String)`
  - Domain 10 (Environment, 1 signal): `tile_destroyed(Vector2i)`
- [ ] `project.godot` `[autoload]` section: `GameBus="*res://src/core/game_bus.gd"` — the `*` prefix is mandatory (autoloads the script as a singleton Node); must be the first entry before SceneManager/SaveManager autoloads
- [ ] Order-sensitive comment in `project.godot` above the autoload line: `; ORDER-SENSITIVE: GameBus must be first — all other autoloads may reference it in _ready`
- [ ] Minimal Godot project loads without error: `/root/GameBus` is accessible from an empty scene (V-1)
- [ ] File contains ONLY: `extends Node`, docstring, banner comments, signal declarations, domain-separator empty lines — NO `var`, NO `func`, NO other keywords (V-9 CI lint)

## Implementation Notes

*From ADR-0001 §Implementation Guidelines §1 + §2 + §Key Interfaces code example:*

1. **Autoload registration syntax**: `GameBus="*res://src/core/game_bus.gd"` in `[autoload]` block. The `*` prefix tells Godot to instantiate the script as a singleton Node attached at `/root/GameBus`. Without the `*`, Godot registers the script as a class but does not instantiate it at boot.
2. **Signal declaration format**: `signal {snake_case_name}({param_name}: {type}, ...)`. Every parameter typed. No `Variant`. No bare `Array` or `Dictionary` — use `Array[Type]` or document Dictionary key/value types in the banner docstring.
3. **Banner comment format** (per ADR §Key Interfaces code example):
   ```
   # ═══ DOMAIN: Scenario Progression (emitter: ScenarioRunner) ════════════════════
   ```
   Approximately 80 columns wide with `═` Unicode box-drawing character. Includes emitter name.
4. **Provisional payloads** (`EchoMark`, `DestinyBranchChoice`, `BeatCue`) — these class_names don't yet exist (owned by future epics). Two options:
   - (a) Declare the signals with placeholder typed-Resource parameters that will be replaced when the actual class lands (requires a forward declaration or commenting out the provisional signals until the class exists)
   - (b) Declare the signals against a stub `Resource` class in `src/core/payloads/` with TODO docstring, replaced by supersession when the real class lands
   - **Recommendation**: go with (b) — create stub `EchoMark.gd`, `DestinyBranchChoice.gd`, `BeatCue.gd` with no fields and a `## TODO: shape locked by ADR-NNNN` docstring. This keeps `game_bus.gd` parseable and all 27 signals declarable on day 1.
5. **SaveContext dependency**: `save_checkpoint_requested(SaveContext)` references a class that lives in save-manager epic. Two options:
   - (a) Declare this signal only when save-manager Story 001 lands (partial 26-signal gamebus until then)
   - (b) Create a stub `SaveContext.gd` at `src/core/payloads/` similar to (b) above, replaced when save-manager epic materializes it
   - **Recommendation**: (b) with stub — but coordinate with save-manager Story 001 to ensure class_name + file path match so the stub is seamlessly replaced.
6. **Code-block vs table asymmetry note (ADVISORY M-2 from architecture-review 2026-04-18)**: ADR-0001 code block has 7 banners while §Signal Contract Schema splits into 9 domains (Grid Battle / Turn Order / HP-Status lumped under one code-block banner). Implementer may either match the code-block 7-banner form OR split into 10 banners to match the schema. Prefer **10 banners matching the schema** (cleaner domain segmentation). Does not break signal contract.

## Out of Scope

- **Story 001**: Creation of non-provisional payload Resource classes (already done — referenced here)
- **Story 003**: signal_contract_test (validates this file against ADR table)
- **Story 005**: GameBusDiagnostics emit counter (separate class, separate file)
- **Story 008**: CI lint for per-frame emit ban (validates consumer files, not this file)
- **save-manager epic Story 001**: SaveContext + EchoMark authoritative definitions (this story uses stubs until then)

## QA Test Cases

*Inline QA specification (lean mode — qa-lead agent not spawned).*

**Test file**: `tests/unit/core/game_bus_declaration_test.gd`

- **AC-1** (V-1 autoload boot):
  - Given: minimal Godot 4.6 project with `GameBus` registered as autoload
  - When: scene launches
  - Then: `get_tree().get_root().get_node_or_null("GameBus")` returns a valid `Node`
  - Edge: verify `/root/GameBus` is accessible from `_ready()` of another autoload (if another autoload exists)

- **AC-2** (27 signals declared):
  - Given: GameBus loaded at `/root/GameBus`
  - When: iterate `GameBus.get_signal_list()` (Godot Node method returning Array[Dictionary])
  - Then: length == 27 user-declared signals (filter out inherited Node signals like `tree_entered` by comparing names)
  - Edge: every signal name matches one of the 27 enumerated in AC of this story

- **AC-3** (signal signature typing):
  - Given: each declared signal
  - When: inspect signal metadata (`get_signal_list()` returns arg types)
  - Then: every arg has a non-`Variant` type; no bare `Array` / `Dictionary` without specifier
  - Edge: `battle_outcome_resolved` signature arg is `BattleOutcome` (Resource subclass)

- **AC-4** (V-9 pure-relay lint):
  - Given: `src/core/game_bus.gd` as text
  - When: grep for `^var\s`, `^func\s`, `^const\s`, `^class\s`, `@onready`, `@export`
  - Then: zero matches (only `extends Node` + banner comments + `signal` declarations + doc comments permitted)
  - Tool: ripgrep in CI; FAIL build on any match

- **AC-5** (autoload order):
  - Given: `project.godot` `[autoload]` section
  - When: parse INI
  - Then: `GameBus` appears before any other autoload entry (SceneManager, SaveManager when they land)
  - Edge: comment line above it contains the ORDER-SENSITIVE warning

- **AC-6** (domain banner count):
  - Given: `src/core/game_bus.gd`
  - When: grep for `^# ═══ DOMAIN:`
  - Then: exactly 10 matches (per recommendation M-2; schema domain count)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/game_bus_declaration_test.gd` — must exist and pass
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 001 (payload Resource class_names must exist for signal signatures to parse)
- **Unlocks**: Stories 003, 004, 005, 006 (all other gamebus stories require the autoload to exist)
