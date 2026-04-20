# Story 001: Non-provisional payload Resource classes

> **Epic**: gamebus
> **Status**: Ready
> **Layer**: Platform
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 2.5 hours (S)

## Context

**GDD**: — (infrastructure; spec from ADR-0001 §Signal Contract Schema)
**Requirement**: `TR-gamebus-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 — GameBus Autoload — Cross-System Signal Relay
**ADR Decision Summary**: All cross-system signals declared on `/root/GameBus` autoload with typed Resource payloads for ≥2-field signals; typed primitives for ≤1-field signals; untyped `Dictionary`/`Array`/`Variant` payloads forbidden.

**Engine**: Godot 4.6 | **Risk**: LOW (typed Resource + `@export` API stable since 4.0)
**Engine Notes**: `Resource.duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` (4.5+) used by downstream consumers (SaveManager, MapGrid). Payload classes themselves do not invoke duplicate_deep here — they just declare the schema.

**Control Manifest Rules (Platform layer)**:
- Required: Payloads ≥2 fields = typed `Resource` class in `src/core/payloads/`; 1 primitive field = typed primitive directly in signal; untyped `Dictionary`/`Array`/`Variant` forbidden
- Required: Every payload Resource round-trips via `ResourceSaver.save` → `ResourceLoader.load` with identical data (verified in Story 004)
- Forbidden: Untyped payload fields — breaks IDE autocomplete + Save/Load round-tripping
- Guardrail: Payload construction cost owned by emitter, not bus; bus itself zero-alloc relay

## Acceptance Criteria

*Derived from ADR-0001 §Signal Contract Schema (Domains 1, 2, 6, 8 — non-provisional payloads) + §Implementation Guidelines §3 (payload typing rule):*

- [ ] `src/core/payloads/battle_outcome.gd` — `class_name BattleOutcome extends Resource`, `Result` enum `{WIN, DRAW, LOSS}` (append-only per TR-save-load-005), fields: `result: Result`, `chapter_id: String`, `final_round: int`, `surviving_units: PackedInt64Array`, `defeated_units: PackedInt64Array`, `is_abandon: bool` — all `@export`
- [ ] `src/core/payloads/battle_payload.gd` — `class_name BattlePayload extends Resource`, fields: `map_id: String`, `unit_roster: PackedInt64Array`, `deployment_positions: Dictionary`, `victory_conditions: VictoryConditions`, `battle_start_effects: Array[BattleStartEffect]` — all `@export`
- [ ] `src/core/payloads/chapter_result.gd` — `class_name ChapterResult extends Resource`, fields: `chapter_id: String`, `outcome: BattleOutcome.Result`, `branch_triggered: String`, `flags_to_set: Array[String]` — all `@export`
- [ ] `src/core/payloads/input_context.gd` — `class_name InputContext extends Resource`, fields: `target_coord: Vector2i`, `target_unit_id: int`, `source_device: int` — all `@export`
- [ ] `src/core/payloads/victory_conditions.gd` — `class_name VictoryConditions extends Resource`, nested type for `BattlePayload.victory_conditions` (shape locked later by Grid Battle ADR; placeholder fields acceptable at this point — minimum `primary_condition_type: int`, `target_unit_ids: PackedInt64Array` all `@export`)
- [ ] `src/core/payloads/battle_start_effect.gd` — `class_name BattleStartEffect extends Resource`, nested type for `BattlePayload.battle_start_effects` (placeholder: `effect_id: String`, `target_faction: int`, `value: int` all `@export`)
- [ ] All class files contain a docstring describing (1) which GameBus signal uses this payload, (2) the owning emitter system, (3) the downstream consumer list — per ADR-0001 §Key Interfaces example for BattleOutcome
- [ ] No field uses untyped `Dictionary`, untyped `Array`, or `Variant` — verified by lint in Story 003

## Implementation Notes

*From ADR-0001 §Implementation Guidelines §3 — Payload typing rule:*

1. Every payload class `extends Resource`, declares `class_name X`, and annotates every persistent field with `@export`. Non-`@export` fields are silently dropped by `ResourceSaver` (ADR-0003 TR-save-load-002 invariant — same applies here).
2. File path convention: `src/core/payloads/[snake_case_name].gd` matching `class_name` in PascalCase.
3. `BattleOutcome.Result` enum ordering is FROZEN as a persistence contract (TR-save-load-005). Current ordering: `WIN = 0, DRAW = 1, LOSS = 2`. Append-only — never insert or reorder without migration.
4. `Array[Type]` strongly typed — never bare `Array`. `Dictionary` is acceptable where keys/values are dynamic (e.g. `deployment_positions: Dictionary` maps unit_id → coord) — document the key/value types in the class docstring.
5. `PackedInt64Array` for unit_id lists (not `Array[int]`) — tighter memory, faster iteration per ADR-0001 §Key Interfaces example.
6. **Do not** emit any signals from these classes — they are data shape only. Emission happens at the caller site (GameBus).
7. **Do not** load other payload classes at static-initialization time in constructors — avoid cross-payload dependencies that would complicate Story 004's serialization tests.

**SaveContext and EchoMark are NOT implemented here** — they live in the `save-manager` epic's Story 001 (per epic scope). Story 004 serialization test for SaveContext/EchoMark activates when that epic lands.

**4 PROVISIONAL payloads are NOT implemented here** — `scenario_beat_retried`, `destiny_branch_chosen`, `destiny_state_echo_added`, `beat_visual_cue_fired` / `beat_audio_cue_fired`. Their payload shapes are locked by downstream GDDs/ADRs (Destiny State, Destiny Branch, Story Event). They land in those epics.

## Out of Scope

- **Story 002**: GameBus autoload `game_bus.gd` with signal declarations that reference these classes
- **Story 004**: Payload serialization round-trip test against these classes
- **save-manager epic**: SaveContext + EchoMark payloads (mirror pattern applies)
- **Future epics**: 4 PROVISIONAL payloads

## QA Test Cases

*Inline QA specification (lean mode — qa-lead agent not spawned).*

**Test file**: `tests/unit/core/payload_classes_test.gd`

- **AC-1** (BattleOutcome existence + field schema):
  - Given: `BattleOutcome` class loaded
  - When: instantiate `var bo = BattleOutcome.new()`
  - Then: `bo.result == BattleOutcome.Result.LOSS` (default); `bo.chapter_id == ""`; `bo.final_round == 0`; `bo.surviving_units is PackedInt64Array`; `bo.defeated_units is PackedInt64Array`; `bo.is_abandon == false`
  - Edge: assert `BattleOutcome.Result` enum values are exactly `{WIN: 0, DRAW: 1, LOSS: 2}` — ordering frozen

- **AC-2** (BattlePayload type safety):
  - Given: `BattlePayload` class loaded
  - When: instantiate and assign `bp.unit_roster = PackedInt64Array([1, 2, 3])`
  - Then: `bp.unit_roster is PackedInt64Array`; `bp.deployment_positions is Dictionary`; `bp.battle_start_effects is Array` and element type is `BattleStartEffect`

- **AC-3** (ChapterResult referential integrity):
  - Given: both `BattleOutcome` and `ChapterResult` loaded
  - When: `var cr = ChapterResult.new(); cr.outcome = BattleOutcome.Result.WIN`
  - Then: `cr.outcome == 0` (`WIN` enum value)
  - Edge: reassign `cr.outcome = BattleOutcome.Result.DRAW`, verify `cr.outcome == 1`

- **AC-4** (InputContext field set):
  - Given: `InputContext` class loaded
  - When: instantiate and assign `ic.target_coord = Vector2i(3, 4)`; `ic.target_unit_id = 42`; `ic.source_device = 0`
  - Then: all fields read back identical; types assertable

- **AC-5** (VictoryConditions + BattleStartEffect nested types):
  - Given: both nested types loaded
  - When: `var bp = BattlePayload.new(); bp.victory_conditions = VictoryConditions.new()`
  - Then: assignment succeeds; `bp.victory_conditions is VictoryConditions`
  - Edge: `bp.battle_start_effects = [BattleStartEffect.new(), BattleStartEffect.new()]` succeeds; length 2; each element `is BattleStartEffect`

- **AC-6** (Lint — no untyped Array/Dictionary/Variant):
  - Given: grep scans `src/core/payloads/*.gd`
  - When: search for `: Array\s*[^\[]` (untyped Array), `: Variant`, or bare field declarations without type hint
  - Then: zero matches (except `Dictionary` which is permitted where dynamic keys are intentional — document in docstring)
  - Tool: ripgrep integration in CI

- **AC-7** (Docstring presence):
  - Given: each payload file
  - When: grep for class-level `##` docstring mentioning (1) signal name, (2) emitter, (3) consumers
  - Then: every file has at least 3 lines of `##` documentation before `class_name`

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/payload_classes_test.gd` — must exist and pass
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 000 (project.godot + addons/gdUnit4/ prerequisite — first code authored in this project)
- **Unlocks**: Story 002 (game_bus.gd signal declarations reference these classes), Story 004 (payload_serialization_test uses these classes), all downstream epics' signal-consumer stories
