# Architecture Review Report — Delta #15

**Date**: 2026-05-06
**Mode**: Lean (per `production/review-mode.txt`); fresh-session escalation per same-session-ban discipline
**Engine**: Godot 4.6 (project pinned 2026-04-16)
**Sprint**: S8-01 (sprint-8 Must-Have critical-path unblock — escalates ADR-0020 InputRouter Proposed → Accepted to unblock the 7-story input-handling chain S8-02..S8-07)
**Session**: combined ADR-0020 escalation Proposed → Accepted + structural append (4 net-new TR-input-handling-018..021 entries + 1 amended TR-input-handling-002) + ADR-0001 minor amendment (3 net-new Story Event #10 GameBus signals registered formally; **already declared in source `src/core/game_bus.gd:62-69` per S8-09 sprint-8 implementation commit `6dbf494` 2026-05-05** — this delta closes the post-source-of-truth ratification loop per Evolution Rule #4) + 2 amended forbidden_pattern descriptions (`hardcoded_input_bindings` + `input_router_signal_emission_outside_input_domain`) — **5th consecutive /architecture-review delta to combine escalation + structural append in single fresh session** (pattern stable at 5 invocations after deltas #11/#12/#13/#14). **First cross-calendar-day fresh-session escalation** in the project: ADR-0020 Proposed 2026-05-05 → Accepted 2026-05-06 via this delta. Deltas #11/#12/#13/#14 were all same-day fresh-session escalations; this delta crosses the calendar boundary while still satisfying the same-session-ban discipline (the Proposed-authoring session was a separate session preceded by a /clear before this delta's session began).

---

## Verdict

**PASS — 0 BLOCKING + 0 ADVISORY**.

ADR-0020 InputRouter `_handle_event` Dispatch Contract Status: **Accepted (2026-05-06)**. Total accepted ADR count: 19 → **20**. Foundation layer 5/5 → 5/5 (ADR-0020 narrows ADR-0005 §9 SOFT/PROVISIONAL contracts at Foundation/Input boundary; does NOT add a new Foundation-layer system). Sprint-8 Must-Have critical-path UNBLOCKED — S8-02..S8-06 input-handling stories 1-5 + S8-07 battle-hud story-005 (S7-10 carryover) can now proceed against the locked `_handle_event` 4-phase dispatch contract.

**Mandatory ADR list**: 0 → 0 (unchanged since delta #8). **Pre-Production → Production gate eligibility unchanged at CONCERNS** (CD only — sole remaining blocker S7-11/S8-15 user attestation USER-OWNED per gate-check 2026-05-05); ADR-0020 acceptance does NOT change gate verdict but DOES unblock all sprint-8 Must-Have implementation work.

**Pattern stability declarations achieved this delta**:
- **Combined-session escalation pattern** stable at **5 invocations** (deltas #11/#12/#13/#14/#15). Pattern declaration target met.
- **Integration-narrowing pattern** stable at **6 invocations** (ADR-0014 ratifying ADR-0010/11/12 → ADR-0015 ratifying ADR-0005/10/11 → ADR-0017 ratifying ADR-0001/0003 → ADR-0018 ratifying ADR-0017 widening → ADR-0019 ratifying ADR-0014 widening → **ADR-0020 ratifying ADR-0005 §9 + ADR-0014 + ADR-0015**). Pattern stability target (6+) MET.
- **In-patch sprint-status hygiene close** at **9-streak** (S7-05/06/07/09 + S8-01/08/09/10/11). Pattern stability target (6+) MET.
- **Autoload Node form** stable at **8 production autoloads** (GameBus + SceneManager + SaveManager + GameBusDiagnostics + BuildModeSentinel + ScenarioRunner + DestinyState + StoryEvent — InputRouter PLACEHOLDER pre-implementation; Acceptance of ADR-0020 readies position 9 for S8-02 graduation). 8th invocation of the pattern.

---

## Phase 1: Inputs Loaded

- ADR-0020 InputRouter `_handle_event` Dispatch Contract (406 lines — Proposed authoring 2026-05-05 commit `d3c1d78`; this delta target)
- ADR-0001 GameBus (signal contract source-of-truth — verified 27 signals across 10 domains pre-delta; this delta amends to **30 signals across 11 domains** with new "Story Event #10" domain — Evolution Rule #1 + #4 minor amendment, NOT supersession)
- ADR-0002 SceneManager (consumed by ADR-0020 §Decision §3 caller allow-list — `ui_input_block/unblock_requested` consumer pair; no amendment this delta)
- ADR-0005 Input Handling (form-level authoritative; ADR-0020 narrows §9 provisional contracts; this delta amends ADR-0005 changelog with one entry documenting field count 6 → 8 + 4 net-new forbidden_patterns; ADR-0005 status remains Accepted — additive amendment per Evolution Rule)
- ADR-0014 GridBattleController (`is_tile_in_move_range` + `is_tile_in_attack_range` — ratified by ADR-0020 §Decision §6 Ratification 1; this delta amends ADR-0014 changelog with one entry; ADR-0014 status remains Accepted)
- ADR-0015 BattleHUD (4 InputRouter integration surfaces ratified by ADR-0020 §Decision §6 Ratification 2; this delta amends ADR-0015 changelog with one entry; ADR-0015 status remains Accepted)
- ADR-0017 ScenarioProgression / ADR-0018 DestinyBranch / ADR-0019 AISystem (precedent ADRs for combined-session escalation pattern — read for verdict-format consistency only; no amendment this delta)
- design/gdd/input-handling.md (CR-1..CR-5 + ST-1..ST-4 + AC-1..AC-18 + F-1..F-3 — verified ADR-0020 §Context constraint set traces back to GDD)
- design/gdd/grid-battle.md (CR-EC-7 out-of-range tap rejection rule — verified consumer site for ADR-0020 Phase 3 state-transition gates)
- design/ux/battle-hud.md (UI-GB-N consumer surfaces — verified Ratification 2 surfaces against authoritative GDD)
- docs/registry/architecture.yaml v13 (this delta updates v13 → v14 with 4 net-new forbidden_patterns + 2 amended descriptions)
- docs/architecture/tr-registry.yaml v15 (this delta updates v15 → v16 with 4 net-new TR-input-handling-018..021 + 1 amended TR-input-handling-002)
- src/core/game_bus.gd (verified 3 net-new Story Event signals declared lines 62-69 + verified Domain banner "Story Event #10 (emitter: StoryEvent)" already in place per S8-09 commit `6dbf494`; ADR-0001 amendment closes the post-source-of-truth ratification loop)
- src/foundation/input_router.gd (verified 33-line PLACEHOLDER state pre-implementation per ADR-0020 Migration Plan §1; ADR-0020 §Migration Plan §2 commits to graduation at story-001 S8-02)
- src/feature/grid_battle/grid_battle_controller.gd (verified `is_tile_in_move_range` + `is_tile_in_attack_range` public methods exist per ADR-0014 §6; ADR-0020 Ratification 1 contract surface confirmed)
- src/feature/battle_hud/battle_hud.gd (verified `_input_router._handle_event` undo dispatch doc-comment at line 19 + 2 GameBus subscribers + TPP callees per ADR-0015 §5; ADR-0020 Ratification 2 contract surface confirmed)
- godot-4x-gotchas.md (G-3 autoload + G-15 test-isolation reset — verified ADR-0020 inherits ADR-0005 6-mandatory-verification-items unchanged; no new gotcha discovery)
- engine-reference/godot/{VERSION.md, breaking-changes.md, deprecated-apis.md} (verified ADR-0020 LOW Knowledge Risk claim — uses pre-4.4 stable APIs only; HIGH-risk surface owned by ADR-0005)

**Total inputs**: 12 ADRs (read in full or in scope) + 6 GDD/source files + 3 registries + 2 rule files + 3 engine-reference files.

---

## Phase 2-3: Traceability Matrix Update

4 net-new TR-input-handling-018..021 entries appended to tr-registry.yaml v15 → v16 + 1 amended TR-input-handling-002 (8-field count documented per ADR-0020 §Decision §6 Ratification 1+2 instance-field additions):

| TR-ID | Coverage | ADR |
|-------|----------|-----|
| TR-input-handling-002 (amended) | 6 base fields per ADR-0005 + 2 DI'd Node references per ADR-0020 (`_grid_battle_controller` + `_battle_hud`) = **8 fields total** | ADR-0005 + ADR-0020 |
| TR-input-handling-018 | `_handle_event` 4-phase dispatch sequence (mode-determine → action-resolve → state-transition → signal-emit) — load-bearing for ADR-0015 BattleHUD subscriber correctness | ADR-0020 |
| TR-input-handling-019 | `_handle_event` sole-state-mutating-method invariant for 4 of 6 fields (`_state` / `_active_mode` / `_pre_menu_state` / `_undo_windows`) — `_input_blocked_reasons` + `_bindings` retain external write entry points per ADR-0005 | ADR-0020 |
| TR-input-handling-020 | `_handle_event` caller allow-list: engine `_unhandled_input` + BattleHUD undo dispatch + tests; sole production exception to `_`-prefix discipline codified | ADR-0020 |
| TR-input-handling-021 | Phase 4 signal emit ordering invariant (`input_state_changed` FIRST, `input_action_fired` SECOND) — prevents BattleHUD MOUSE_FILTER_IGNORE recursive disable race condition on S5 INPUT_BLOCKED entry | ADR-0020 |

Total TR count: 254 → **258**. tr-registry.yaml v15 → v16.

**Pattern observation**: ADR-0020 introduces 4 net-new TRs against an existing 17-TR system (TR-input-handling-001..017 from ADR-0005 delta #6). 4 / (17+4) = ~19% net-add ratio — sits within the project's "narrowing-ADR" TR-add range (delta #14 ADR-0019 added 15 net-new for a 0-baseline new system; delta #11 ADR-0014 added 14 net-new for 0-baseline; delta #11 ADR-0015 added 17 net-new for 0-baseline; delta #11 ADR-0016 added 11 net-new for 0-baseline; delta #11 ADR-0013 added 8 net-new for 0-baseline). This delta is the first since delta #6 + #11 to NARROW an existing ADR rather than ratify a new system — establishing **delta #15 as the precedent for narrowing-ADR TR-add ratio** at sprint-8+ scale.

---

## Phase 4: Cross-ADR Conflict Detection

### Conflict scan summary

ADR-0020's dependency surface checked against all 19 prior Accepted ADRs (ADR-0001..0019 + the in-progress ADR-0020). Specifically:

- **ADR-0001 GameBus**: ADR-0020 commits no new GameBus signals (3 Input-domain signals from ADR-0005 §7 unchanged; ADR-0020 ratifies the emit ordering inside `_handle_event` Phase 4 only). NO conflict. **However**, ADR-0001 ITSELF requires a minor amendment this delta to register the 3 Story Event #10 signals already shipped in source via S8-09 commit `6dbf494` — this is a **separate ADR-0001 bookkeeping amendment**, not an ADR-0020 conflict. See §Phase 4b below.
- **ADR-0002 SceneManager**: ADR-0020 §Decision §3 caller allow-list explicitly accommodates SceneManager's `set_process_input(false) + set_process_unhandled_input(false)` overworld-retain pattern (engine drops events before `_unhandled_input` fires; `_handle_event` is unreachable when both callbacks are disabled). NO conflict.
- **ADR-0005 Input Handling**: ADR-0020 explicitly NARROWS §9 SOFT/PROVISIONAL contracts (lines 174-178). ADR-0005 form-level decisions (Autoload Node + 6 fields + 7-state FSM + 22-action vocab + InputMode enum + 17 TRs + 4 base forbidden_patterns) REMAIN authoritative. ADR-0020 is **additive narrowing**, not supersession (per ADR-0020 §Status line 21). Field count 6 → 8 (2 net-new DI'd Node references `_grid_battle_controller` + `_battle_hud`) is documented in ADR-0020 §Consequences §Negative + §Migration Plan §6 + tr-registry TR-input-handling-002 amendment. NO conflict — this is the textbook "downstream narrowing at upstream-ADR Acceptance time" pattern (5-precedent strategy + 6th invocation now stable).
- **ADR-0014 GridBattleController**: ADR-0020 §Decision §6 Ratification 1 ratifies `is_tile_in_move_range` + `is_tile_in_attack_range` as InputRouter consumer surfaces. Verified `src/feature/grid_battle/grid_battle_controller.gd` declares both methods publicly. **Crucially**, ADR-0020 explicitly states "InputRouter does NOT subscribe to GridBattleController's 6 LOCAL signals — calls are method-level only, not signal-level (CR-AI-6 + ADR-0014 §8 LOCAL signal channel reserved for AI dispatch)" — this preserves ADR-0014's signal-channel discipline that delta #14 ratified at 6 LOCAL signals. NO conflict.
- **ADR-0015 BattleHUD**: ADR-0020 §Decision §6 Ratification 2 ratifies 4 BattleHUD integration surfaces (TPP callee + 2 GameBus subscribers + undo `_handle_event` caller exception). Verified all 4 against ADR-0015 §5 + `battle_hud.gd:19` doc-comment. **Crucially**, the undo `_handle_event` exception is the ONLY production caller exception to `_`-prefix discipline (Decision §3); no second exception is introduced. NO conflict.
- **ADR-0017/0018/0019**: no integration surface with ADR-0020. Not affected.
- **ADR-0001..0013 (Foundation/Core/non-Input ADRs)**: no integration surface with ADR-0020. Not affected.

### Phase 4b: ADR-0001 minor amendment audit (separate from ADR-0020 escalation)

This delta also closes the post-source-of-truth ratification loop for the 3 Story Event #10 GameBus signals already declared in `src/core/game_bus.gd:62-69` per S8-09 commit `6dbf494` (2026-05-05). Per ADR-0001 §Evolution Rule #1 (add a new signal = minor amendment) + #4 (lock a PROVISIONAL signal = minor amendment), this is documented in the ADR-0001 changelog as one entry registering all 3 signals + adding new "Story Event #10" sub-domain Schema row.

**Signals registered** (already shipped in source per S8-09 + S8-11 chapter-1 e2e integration commit `5283ccd`):

| Signal | Payload | Emitter | Subscribers (current) | Frequency | Source line |
|---|---|---|---|---|---|
| `story_event_resolved` | `int, StringName, String, StringName` | StoryEvent | (test-only at this commit; downstream UI subscribes post-S8-11 chapter-1 e2e validates handler-fires path) | discrete | `src/core/game_bus.gd:67` |
| `story_event_invalid_path_detected` | `StringName, String` | StoryEvent | (test-only at this commit; invalid-path UI carve-out per CR-SE-12 D1 BLOCKING contract) | discrete | `src/core/game_bus.gd:68` |
| `story_event_revelation_committed` | `String, String, StringName` | StoryEvent | (test-only at this commit; downstream telemetry subscribes per CR-SE-12 register=solemn / register=marked tagging) | discrete | `src/core/game_bus.gd:69` |

**Domain count**: 10 → 11 (Story Event #10 distinct from the existing Domain 6 "Story Event / Beat presentation (emitter: BeatConductor)"). The two domains are intentionally separate per source banner discipline:
- Domain 6 "Story Event / Beat presentation" = the 3 PROVISIONAL `beat_*_cue_fired` + `beat_sequence_complete` signals from BeatConductor (still PROVISIONAL — payload shape locked by sprint-9+ Story Event #10 cinematic layer authoring; these signals are NOT this delta's amendment target)
- Domain 11 "Story Event #10" = the 3 NEW signals from StoryEvent autoload (Beat 8 revelation lookup + Beat 9 outro + invalid-path UI carve-out per S7-06 GDD CR-SE-2/3/19 + S8-09 implementation)

ADR-0001 signal count: 27 → **30**. PROVISIONAL count remains at **2** (Domain 6 unchanged; Domain 11 ratified-at-source).

NO conflict — this is Evolution Rule #1 + #4 minor amendment, NOT supersession.

### ADR Dependency Order

ADR-0020 declared `Depends On` (per ADR-0020 §ADR Dependencies):
- ADR-0001 (Accepted 2026-04-18) ✅
- ADR-0002 (Accepted 2026-04-18) ✅
- ADR-0005 (Accepted 2026-04-30) ✅
- ADR-0014 (Accepted 2026-05-03) ✅
- ADR-0015 (Accepted 2026-05-03) ✅

All 5 dependencies Accepted. NO unresolved dependencies. NO cycle (ADR-0020 has no ADR depending on it; it is sprint-8 critical-path leaf).

---

## Phase 5: Engine Compatibility

### Version Consistency

ADR-0020 declares Godot 4.6 + last-verified date 2026-05-05 against `docs/engine-reference/godot/VERSION.md` (project pinned 2026-04-16). Consistent with ADR-0001..0019.

### Post-Cutoff API Consistency

ADR-0020 §Engine Compatibility table line 31 declares: "**NONE** in this ADR's incremental decision surface. The dispatch-loop sequence uses pre-4.4 stable APIs only: `InputEvent` subclass `is`-narrowing (4.0+), `match` dispatch on `StringName` (1.0+), typed `signal` declarations (4.2+), `Object.CONNECT_DEFERRED` (4.0+). The 6 mandatory verification items in ADR-0005 (dual-focus + SDL3 + emulate_mouse_from_touch + recursive disable + screen_get_size + safe-area + touch event index) are inherited unchanged."

Verified against `engine-reference/godot/{breaking-changes.md, deprecated-apis.md}`:
- `InputEvent` subclass hierarchy (`InputEventMouseButton` / `InputEventMouseMotion` / `InputEventKey` / `InputEventScreenTouch` / `InputEventScreenDrag` / `InputEventJoypadButton` / `InputEventJoypadMotion` / `InputEventAction`) — **stable across 4.0..4.6**, no breaking changes flagged.
- `InputMap.action_get_events` / `InputMap.add_action` / `InputMap.action_add_event` — **stable across 4.0..4.6**, no breaking changes flagged. (These are the Phase 2 action-resolve APIs from ADR-0020 Decision §1 — pre-cutoff stable.)
- `Object.CONNECT_DEFERRED` — **stable since 4.0**, semantic identical across 4.0..4.6.
- Typed `signal` declarations — **stable since 4.2**, strictness tightened in 4.5 (per ADR-0001 Engine Compatibility line 31). ADR-0020 emits to 3 already-declared Input-domain signals; no new signal declarations in ADR-0020 itself.

NO post-cutoff API conflicts.

### Deprecated API Check

Greppable check — ADR-0020 references no APIs from `deprecated-apis.md`:
- `Engine.has_class()` — NOT used (ADR-0020 uses no class-existence checks; G-17 mirror — `ClassDB.class_exists()` is the canonical check anyway, but ADR-0020 needs neither).
- `is_not_equal_approx()` — NOT used (no float assertions; G-23 mirror).
- `before_each()` / `after_each()` — NOT applicable to ADR text (test-author concern; G-15 mirror).

NO deprecated API references.

### Engine Compatibility section presence

ADR-0020 §Engine Compatibility table is fully populated (Engine + Domain + Knowledge Risk + References Consulted + Post-Cutoff APIs Used + Verification Required all present). PASS.

### Engine Specialist Consultation

**Skipped this delta** (no new engine API surface introduced; ADR-0020 uses only pre-4.4 stable APIs documented in `engine-reference/godot/modules/input.md`; HIGH-risk surface owned by ADR-0005 — not re-asserted at narrowing-ADR level). Specialist invocation count remains at 16 (last invocation delta #13). This mirrors delta #14's same-skip rationale: narrowing ADRs that introduce no new engine API surface do not trigger specialist consultation.

---

## Phase 5b: Design Revision Flags (Architecture → GDD Feedback)

NO design revision flags. ADR-0020 ratifies design/gdd/input-handling.md CR-1..CR-5 + ST-1..ST-4 + AC-1..AC-18 + F-1..F-3 verbatim; no GDD assumptions conflict with verified engine behaviour.

---

## Phase 6: Architecture Document Coverage

`docs/architecture/architecture.md` — verified ADR-0020 fits the existing layer taxonomy (Foundation / Input dispatch + cross-system integration narrowing). No orphaned-architecture flag. No missing-system flag.

---

## Phase 7: Output

### Architecture-registry mutations

`docs/registry/architecture.yaml` v13 → **v14**:

**4 net-new forbidden_patterns** (appended to existing `input_router_*` block at lines 1825..1860):
1. `input_router_state_mutation_outside_handle_event` — enforces ADR-0020 §Decision §2 (sole state-mutating method invariant). Lint script `tools/ci/lint_input_router_state_mutation_outside_handle_event.sh` deferred to story-010 epic-terminal S9 carryover per ADR-0020 Migration Plan §3.
2. `input_router_handle_event_external_caller_outside_battle_hud` — enforces ADR-0020 §Decision §3 (caller allow-list with sole BattleHUD production exception). Lint script `tools/ci/lint_input_router_handle_event_caller_allowlist.sh` deferred to story-010 epic-terminal S9 carryover per ADR-0020 Migration Plan §3.
3. `input_router_per_frame_state_polling_api` — forbids per-frame state read API beyond the 2 ADR-0005 §1 getters; enforces signal-subscriber discipline per ADR-0020 §Decision §5 forbidden_pattern #7.
4. `input_router_hover_only_action_in_bindings` — extends CR-1a hover-only ban to action vocabulary; enforces PC-binding-AND-touch-binding requirement per action with G-2 grid_hover whitelisted exception. Lint script `tools/ci/lint_input_bindings_pc_touch_parity.sh` already in EPIC.md story-010 9-CI-lint-scripts target.

**2 amended forbidden_pattern descriptions** (existing entries at lines 1825 + 1846):
1. `hardcoded_input_bindings` (line 1825) — description amended to reference ADR-0020 §Context constraint set ("REMAINS authoritative; this ADR's dispatch loop reads `_bindings` populated from `default_bindings.json` at autoload `_ready()`") + explicit cross-ref to ADR-0020 Ratification 1 + 2.
2. `input_router_signal_emission_outside_input_domain` (line 1846) — description amended to widen ratification footnote: "InputRouter is sole-emitter of 3 Input-domain GameBus signals; non-emitter for OTHER 24 signals across 9 OTHER domains [27 total minus 3 Input domain = 24] — recount post-delta-#15: 27 → 30 signals across 11 domains, so non-emitter for OTHER 27 signals across 10 OTHER domains. Per ADR-0020 §Decision §6 Ratification 1 + 2, InputRouter additionally CALLS GridBattleController range-validation methods (NOT signal subscriber) and CALLS BattleHUD TPP show methods (NOT signal subscriber)."

**Total architecture.yaml changes**: 4 NEW entries + 2 amended descriptions. Version 13 → 14.

### TR registry mutations

`docs/architecture/tr-registry.yaml` v15 → **v16**:

- 4 net-new entries TR-input-handling-018..021 (per Phase 2-3 table above).
- 1 amended entry TR-input-handling-002 — `requirement` field amended to reference 8-field count (6 base per ADR-0005 + 2 DI'd Node refs per ADR-0020 = 8 fields total) + `revised: 2026-05-05` field added.
- Total registered TRs 254 → **258**.

### Source-of-truth reference

This delta closes the **post-source-of-truth ratification loop** for ADR-0001's 3 Story Event #10 signal additions: source-of-truth `src/core/game_bus.gd:62-69` shipped at S8-09 commit `6dbf494` 2026-05-05; ADR-0001 minor amendment ratifies post-source per Evolution Rule #4. This is the **3rd-precedent post-source ratification pattern** after delta #12 (`scenario_complete` + `scenario_beat_retried` shipped first, ratified delta #12) + delta #13 (`destiny_branch_chosen` 9-field shape shipped first, ratified delta #13).

---

## Conflicts (BLOCKING/ADVISORY)

NONE. Pure escalation + structural append + minor amendment delta.

---

## ADR Dependency Order (post-delta)

ADR Implementation Order (topologically sorted; * = updated this delta):

**Foundation (no dependencies)**:
1. ADR-0001 GameBus* (signal contract — 30 signals across 11 domains post-delta-#15)

**Foundation — depends on ADR-0001**:
2. ADR-0002 SceneManager
3. ADR-0003 Save/Load
4. ADR-0004 MapGrid Data Model
5. ADR-0005 Input Handling*
6. ADR-0006 Balance Data
7. ADR-0007 Hero Database
8. ADR-0008 Terrain Effect (depends on ADR-0006)
9. **ADR-0020 InputRouter Dispatch* (NEW — Accepted 2026-05-05; depends on ADR-0001/0002/0005/0014/0015 — narrows ADR-0005 §9)**

**Core**:
10. ADR-0009 Unit Role (depends on ADR-0007)
11. ADR-0010 HP/Status
12. ADR-0011 Turn Order
13. ADR-0012 Damage Calc (depends on ADR-0009/0010/0011)
14. ADR-0013 BattleCamera

**Feature**:
15. ADR-0014 GridBattleController*
16. ADR-0015 BattleHUD*
17. ADR-0016 BattleSceneWiring
18. ADR-0017 ScenarioProgression
19. ADR-0018 DestinyBranch
20. ADR-0019 AISystem

**No cycles. No unresolved dependencies.**

---

## Validation: Sprint-8 critical-path unblock

Per ADR-0020 §ADR Dependencies §Enables (1)..(4):

1. **Sprint-8 S8-02..S8-06 input-handling stories 1-5** — NOW UNBLOCKED. InputRouter graduates from 33-line PLACEHOLDER (per `src/foundation/input_router.gd:1` doc-comment "TYPE PLACEHOLDER") to functional FSM per the ADR-0020 locked dispatch contract. Story-001 (S8-02) module-skeleton implementation can begin immediately post-delta (next session OK; same-session-ban discipline does NOT apply to story implementation post-ADR-acceptance, only to /architecture-review post-/architecture-decision).
2. **Sprint-8 S8-07 S7-10 unblock + ship** — NOW UNBLOCKED. Battle-hud story-005 (UI-GB-02/05/10 + two-tap timer) can validate AC-UX-HUD-08/09 against the locked `_handle_event` undo dispatch path (Ratification 2 sub-point d).
3. **Resolution of S7-10 BLOCKED root cause** — STRUCTURALLY ENFORCED. ADR-0020 §Decision §3 caller allow-list lint (deferred to S9 story-010 epic-terminal) makes the PLACEHOLDER → production transition lint-enforceable instead of trust-based. Sprint-7 retro improvement #1 (pre-flight check policy) is now lint-greppable: `grep -n 'func _handle_event' src/foundation/input_router.gd` either returns the body or fails fast at sprint-plan time.
4. **Resolution of OQ-1 partial (gamepad routing) + OQ-2 partial (camera pan ownership)** — confirmed unchanged from ADR-0005 §6 + §9 (gamepad → KEYBOARD_MOUSE; camera owns drag state + InputRouter pass-through). ADR-0020 commits no further narrowing on these axes.

---

## Sprint-status hygiene close-in-same-patch

Per sprint-7 retro AI #1 enforcement target (6+ consecutive in-patch closes for stability declaration; achieved at delta-pre-status of 8-streak; this delta extends to **9-streak** S7-05/06/07/09 + S8-01/08/09/10/11): S8-01 sprint-status row `status: ready-for-dev` flips to `done` in same patch as this delta's commit per ADR-0020 Migration Plan §10. Pattern stability target (6+ consecutive in-patch closes) MET; **extending the streak to 9 invocations stabilizes the pattern at production-phase scale**.

---

## Source-of-truth check

Verified post-delta source-of-truth alignment:
- `docs/architecture/ADR-0020-input-router-dispatch.md` Status field flips Proposed → Accepted (this delta)
- `docs/architecture/ADR-0001-gamebus-autoload.md` — Domain 11 "Story Event #10" added to Schema + 3 NEW signal rows + signal count 27 → 30 + provisional count unchanged (2) + Changelog entry appended (this delta)
- `docs/architecture/ADR-0005-input-handling.md` — Changelog entry appended ratifying ADR-0020 narrowing + 8-field count + 4 net-new forbidden_patterns + 2 amended (this delta)
- `docs/architecture/ADR-0014-grid-battle-controller.md` — Changelog entry appended ratifying ADR-0020 §Ratification 1 (this delta)
- `docs/architecture/ADR-0015-battle-hud.md` — Changelog entry appended ratifying ADR-0020 §Ratification 2 (this delta)
- `docs/architecture/tr-registry.yaml` — version 15 → 16 + 4 net-new entries + 1 amended (this delta)
- `docs/registry/architecture.yaml` — version 13 → 14 + 4 net-new forbidden_patterns + 2 amended descriptions (this delta)
- `production/sprint-status.yaml` — S8-01 row `status: ready-for-dev` → `done`; same-patch close per sprint-7 retro AI #1 (this delta)
- `production/session-state/active.md` — session extract appended (this delta)

---

## Recommendation

**ADR-0020 InputRouter `_handle_event` Dispatch Contract**: ACCEPT 2026-05-06.

**Next critical-path actions** (per sprint-8 plan):
1. Sprint-8 S8-02 input-handling story-001 (module skeleton + autoload registration `/root/InputRouter` boot pos 4) — can start NEXT SESSION. Routes through `/dev-story production/epics/input-handling/story-001-module-skeleton-and-autoload-registration.md`.
2. After S8-02 ships, S8-03 (action vocabulary + bindings.json) → S8-04 (FSM core S0/S1/S2 move flow + GridBattleController dispatch) → S8-05 (FSM attack S3/S4 + ST2 demotion) → S8-06 (mode determination CR-2 + input_mode_changed emit + BattleHUD Tap Preview Protocol) → S8-07 (battle-hud story-005 S7-10 unblock + ship two-tap timer).
3. Sprint-8 Should/Nice tasks all SHIPPED day-one (S8-08..S8-11). Remaining sprint-8 work is Must-Have S8-02..S8-07 chain (now unblocked) + S8-15 USER-OWNED.

**Gate-check upgrade-path**: post-S8-15 user attestation → re-run `/gate-check pre-production` for expected verdict upgrade CONCERNS → PASS + `production/stage.txt` written = "Production". ADR-0020 acceptance does NOT directly upgrade the gate-check verdict (which is gated on user attestation only) but DOES close the sprint-8 critical-path unblock for all Must-Have implementation work.

---

**End of Delta #15 report.**
