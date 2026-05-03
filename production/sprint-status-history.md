# Sprint Status History

> **Purpose**: Archive of long-form completion notes from `production/sprint-status.yaml` per sprint-3 retro AI #3.
>
> **Policy** (S3-05 amendment to `/story-done` skill, 2026-05-02):
> - Top-level `updated:` field in sprint-status.yaml capped at **200 chars**.
> - Per-story `#` changelog comments in sprint-status.yaml capped at **200 chars**.
> - When a /story-done update would exceed either cap, the FULL prior text is appended here under the matching sprint section before the YAML is truncated.
> - Most recent entry first within each sprint section.
> - Canonical "is it done?" state lives in sprint-status.yaml; this file is the long-form audit trail.
>
> **Cross-references**:
> - Source: `production/sprint-status.yaml`
> - Skill: `.claude/skills/story-done/SKILL.md` Phase 7 step 4
> - Origin: `production/retrospectives/retro-sprint-2-2026-05-02.md` Action Item #3

---

## Sprint 6

### S6-08 — /qa-plan battle-hud — per-epic QA plan covering 8 stories (2026-05-03)

**Date**: 2026-05-03 (sprint-6 day 1; per-story rotation)
**Files (1 NEW)**: `production/qa/qa-plan-battle-hud-2026-05-03.md` (402 lines)

**Story classification** (8 stories, 5 distinct type combos):
| Story | Type | Status |
|---|---|---|
| 001 — Class skeleton + DI | Logic | ✅ Complete (S6-05) |
| 002 — 11 GameBus subs + S5 filter | Logic + Integration | ✅ Complete (S6-06) |
| 003 — UI-GB-03 + UI-GB-11 | UI + Integration | Ready |
| 004 — UI-GB-01/07/08 | UI + Integration | Ready |
| 005 — UI-GB-02/05/10 + Two-Tap | UI + Integration | Ready |
| 006 — UI-GB-04 Combat Forecast | UI + Performance | Ready |
| 007 — UI-GB-06/09/12-14 | UI + Integration + Performance | Ready |
| 008 — Epic terminal lints | Config/Data + Audit | Ready |

**Plan coverage**:
- Per-story automated test specs (paths + AC mapping + edge cases) for all 8 stories
- Per-story manual QA checklists (AccessKit, dual-focus, palette, 44pt, Pillar 2 audit) for stories 002-007
- Smoke test scope (10 critical paths)
- Playtest matrix (3 stories require sessions: 005 two-tap feel, 006 forecast readability, 007 Pillar 2 audit by new player)
- Definition of Done at story level + epic level (with 7 Engine Verification items + Pillar 2 lint KEEP-forever)

**Performance gates surfaced** (binding even in Lean mode per TR-battle-hud-014):
- Story-006 forecast: p99 < 120 ms (FORECAST_RENDER_BUDGET_MS) + dismiss < 80 ms (AC-UX-HUD-02 + AC-UX-HUD-03)
- Story-007 UI-GB-09 results: p99 < 200 ms; zoom-poll ≤ 0.05 ms/frame
- Story-002: 21st failure-free baseline preserved + recursive Control disable cross-platform manual gate (TD-062 KEEP through Polish)

**Outstanding manual evidence from already-shipped stories**:
- TD-062: Engine Verification Item 5 — recursive MOUSE_FILTER_IGNORE cross-platform video capture (macOS Metal + Linux Vulkan + Windows D3D12); KEEP through Polish

**Side-findings (non-blocking)**:
1. `production/sprint-status.yaml` shows S6-02/S6-03/S6-04 as `backlog` but commits (`6c4bd08`, `29a7ca1`) and active.md "6/12 done" indicate completion — yaml drift exists; outside /qa-plan scope to fix
2. GDD AC-UX-HUD-09 references `tests/fixtures/battle_hud/defend_two_tap.yaml` — verify fixture exists at story-005 author time
3. TR registry backfill (TR-battle-hud-001..017) is a DoD prerequisite for epic-complete; track via separate `/architecture-review` delta in fresh session

**Sprint-6 progress (post-S6-08)**: 7/12 done = 58% (per yaml `done` count; reality is higher per active.md). S6-09 (battle-hud story-003) UNBLOCKED. S6-03/S6-07 still pending (depend on /create-epics battle-scene).

**Cross-references**: `production/epics/battle-hud/EPIC.md` / `docs/architecture/ADR-0015-battle-hud.md` §"Same-Patch Obligations" / TD-062 (`docs/tech-debt-register.md`)

---

### S6-06 — battle-hud story-002: 11 GameBus signal subscriptions + DI test seam + S5 mouse_filter toggle (2026-05-03)

**Date**: 2026-05-03 (sprint-6 day 1; per-story rotation)
**Files (10)**: 4 production + 3 contract-test cascade + 2 NEW test files + 1 NEW test helper:
- `src/feature/battle_hud/battle_hud.gd` (M) — 11 single-line CONNECT_DEFERRED subscriptions + 11 is_connected-guarded disconnects + 11 _on_* forwarding handlers + S5 mouse_filter toggle inside _on_input_state_changed
- `src/foundation/input_router.gd` (M) — InputState enum per ADR-0005 §1 (cross-epic forward-prep #1; replaces story-001 placeholder doc-comment-only state)
- `src/core/game_bus.gd` (M) — formation_bonuses_updated(snapshot: Dictionary) signal (cross-epic forward-prep #2 per ADR-0015 §3 R-3 + ADR-0014 CR-12)
- `src/core/game_bus_diagnostics.gd` (M) — explicit name guard for formation_bonuses_updated → "battle" routing (G-5 explicit-name-precedes-prefix; cross-epic forward-prep #3)
- `tests/unit/core/signal_contract_test.gd` + `game_bus_declaration_test.gd` + `game_bus_diagnostics_test.gd` (M) — EXPECTED_SIGNALS / routing-map +1 entry each, count 28→29
- `tests/unit/feature/battle_hud/battle_hud_signals_test.gd` (NEW, ~430 LoC, 10 tests) — AC-1..AC-5 incl. AC-1 typo regression + AC-2 Pillar 2 runtime + AC-3 capture subclass + AC-4 disconnect/re-add via request_ready + AC-5 three-branch S5 toggle
- `tests/integration/feature/battle_hud/battle_hud_recursive_filter_test.gd` (NEW, ~150 LoC, 3 tests) — AC-6 chain + chain inverse + structural descendant property (synthetic-click variant DROPPED — both Input.parse_input_event + Viewport.push_input bypass Control mouse_filter chain in headless GdUnit4 → behavioral verification = manual cross-platform gate per ADR-0015 Verification Item 5 → TD-062)
- `tests/helpers/battle_hud_capture_subclass.gd` (NEW, ~40 LoC) — AC-3 capture seam (Array[Dictionary] received log + super delegation for production side-effects)

**Test result**: 865/865 PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans (Exit 0). Delta = +13 vs S6-05 baseline 852. **21st consecutive failure-free regression baseline.**

**ACs**: 8/8 covered (5 by automated tests, 3 by code-review verification + automated cross-checks).

**Code review** (lean mode — done in same /code-review skill invocation): APPROVED WITH SUGGESTIONS
- godot-gdscript-specialist: COMPLIANT on ADR-0015 + ADR-0001 + ADR-0005; 6/6 standards; 0 G-N gotcha violations; CLEAN architecture; SOLID compliant; 5 non-blocking suggestions
- qa-tester: 8/8 ACs COVERED; no blocking gaps; 4 suggested test additions (non-blocking); 3 ADVISORY items → TD-061 + TD-062

**Tech debt logged (3 items)**:
- TD-060: formation_bonuses_updated GameBus signal placeholder + ADR-0001 §Signal Contract Schema text update deferred (paperwork — next /architecture-review delta) + future Grid Battle epic emission story
- TD-061: story-002 file documentation defects (AC-3 lists `was_selected: bool` but production is `int` per ADR-0014 + AC-4 re-add wording omits `request_ready()` test-only constraint)
- TD-062: Engine Verification Item 5 (recursive MOUSE_FILTER_IGNORE) needs formal `production/qa/evidence/` checklist entry — manual cross-platform gate (macOS Metal + Linux Vulkan + Windows D3D12)

**Mid-stream findings**:
1. Specialist signal-signature drift halt (PASS — caught 4 mismatches: was_selected bool→int, battle_outcome_resolved int→StringName, unit_turn_ended 1→2 args, formation_bonuses_updated absent → cross-epic add)
2. Initial agent timeout at ~125min after 4-file write but before tests; resumed via direct authoring + post-test fix of invented State enum names (TOUCH_DOWN/DRAG/etc → ADR-0005 §1 canonical OBSERVATION/UNIT_SELECTED/MOVEMENT_PREVIEW/ATTACK_TARGET_SELECT/ATTACK_CONFIRM/INPUT_BLOCKED/MENU_OPEN); enum renamed `State` → `InputState` per ADR
3. AC-4 re-add edge required `request_ready()` (Godot fires _ready once per Node lifetime)
4. AC-6 synthetic-click test infeasible headless → dropped variant; retained chain + structural tests
5. AC-9 source-content lint regression caught mid-stream — literal `hidden_fate_condition_progressed` re-introduced in subscription comment; replaced with ADR-coordinate reference (story-001 fix precedent)
6. GameBus signal-contract regression chain — adding formation_bonuses_updated to game_bus.gd cascaded into 4 file updates; contract gate worked exactly as designed

**Sprint-6 progress (post-S6-06)**: 6/12 done = 50%. Critical-path advances: S6-09 (battle-hud story-003) blocked only by S6-08; S6-08 was UNBLOCKED at S6-04; S6-07 (battle-scene story-001) gains HUD prerequisite via S6-06.

**Cross-references**: ADR-0015 / ADR-0014 §8 line 85 / ADR-0005 §1 / TD-060 / TD-061 / TD-062 (`docs/tech-debt-register.md`)

---

## Sprint 5

### Sprint-5 close summary (2026-05-03 — 13/13 done)

**Completed**: 2026-05-03 (single-day rotation; sprint window 2026-05-17 → 2026-05-23 nominal; 14-21 calendar days ahead of deadline)
**Total stories**: 13 (Must-have 11/11 + Should-have 2/2 + Nice-to-have 0/0)
**Test baseline**: 757 → 841 (+84) / 0 errors / 0 failures / 0 orphans / Exit 0 (**19th consecutive failure-free baseline**)
**Commits**: 13 (all pushed to origin/main; per-story commit cadence held)

**What shipped** (per-story status preserved in story files at `production/epics/grid-battle-controller/story-{001..010}-*.md` + `docs/architecture/ADR-0015-battle-hud.md` + `production/epics/battle-hud/EPIC.md`):

| ID | Story | Files |
|---|---|---|
| S5-01 | qa-plan grid-battle-controller (per-epic discipline) | production/qa/qa-plan-grid-battle-controller-2026-05-02.md (~290 LoC) |
| S5-02 | story-001: skeleton + 8-param DI + 4 GameBus subs + _exit_tree | grid_battle_controller.gd ~280 LoC + 6 backend stubs + MAX_TURNS_PER_BATTLE BalanceConstants |
| S5-03 | story-002: BattleUnit Resource +7 fields + tag-based fate detection | src/core/battle_unit.gd RefCounted→Resource +7 fields + 5 registry tests |
| S5-04 | story-003: 2-state FSM + 10-grid-action filter + click dispatch | 12 fsm tests; G-7 silent-skip caught + recovered |
| S5-05 | story-004: MOVE action + is_tile_in_move_range + unit_moved | 11 move tests; Manhattan range + occupancy + passability + facing update |
| S5-06 | story-005: ATTACK chain + DamageCalc integration + damage_applied (LARGEST story) | 17 attack tests; 6 multiplier helpers; BattleUnit + ResolveModifiers extensions |
| S5-07 | story-006: per-turn action consumption + auto-handoff (drift #9/#10) | 9 turn-consumption tests; declare_action/end_player_turn drift documented in ADR-0014 Implementation Notes |
| S5-08 | story-007: 5-turn limit + battle_outcome_resolved + terminal state | 10 turn-limit tests; G-4 lambda primitive-capture trap caught + recovered |
| S5-09 | story-008: hidden fate counters + boss/assassin attribution + tank_hp_pct | 12 fate tests; AC-8 hidden-semantic-preservation structural test (zero connections enforcement) |
| S5-10 | story-009: cross-ADR _exit_tree audit + TurnOrderRunner Path B retrofit + TD-057 RESOLVED | 0 new tests (audit story); 4 systems audited; pattern stable at 4 invocations |
| S5-11 | story-010: epic terminal — 4 perf + 4 lints + 5 BalanceConstants + verification summary + epic Complete | 4 perf tests under permissive CI gates (×3-200 over headlines); EPIC 10/10 COMPLETE |
| S5-12 | ADR-0015 Battle HUD authoring (should-have) | ~620 LoC at Proposed status; 5th invocation of battle-scoped Node pattern; first Presentation-layer ADR |
| S5-13 | battle-hud Presentation epic + 5-8 stories scaffold preview (should-have) | ~530 LoC EPIC.md; first Presentation-layer epic; Pillar 2 hidden-semantic lock at 3 layers |

**Patterns established** (codified in `production/retrospectives/retro-sprint-5-2026-05-03.md`):

1. **5th invocation of battle-scoped Node pattern** stable (HPStatus + TurnOrder + Camera + GridBattleController + BattleHUD)
2. **First Pillar 2 hidden semantic lock** — `battle_hud_subscribes_to_hidden_fate_signal` forbidden_pattern (CRITICAL, KEEP forever) — first project precedent of pillar-anchored lint
3. **10 architectural drifts** surfaced + fixed in-line via ADR-0014 Implementation Notes amendment pattern (zero carry-forward debt)
4. **Audit-then-retrofit Path B** validated as canonical cross-ADR audit pattern (story-009 caught actual latent leak in TurnOrderRunner; TD-057 RESOLVED same patch)
5. **Per-story commit cadence** held all 13 stories (mirrors sprint-4 camera epic pattern)
6. **godot-specialist 3-pass review as TD-ADR substitute** (sprint-4 retro AI #3) used in production for first UI-domain ADR; pattern stable at 3 invocations (ADR-0013 + ADR-0014 + ADR-0015)
7. **`/clear` + active.md resume** pattern stable at 3 invocations within sprint-5 alone

**Sprint-5 retro action items carrying to sprint-6** (`production/sprints/sprint-6.md` AI #1-5):

- AI #1: Continue tightening estimation (3rd consecutive ratchet — sprint-6 plans 2.4d Must nominal, down from sprint-5's 3.55d)
- AI #2: Schedule explicit `/architecture-review` structural-backfill session (~45 TRs + ~15 file edits) — bundled into sprint-6 S6-02
- AI #3: Sprint-6 primary work = Battle Scene wiring (the +1 playable-surface delta target)
- AI #4: battle-hud `/create-stories` + `/qa-plan` early in sprint-6 (S6-04 + S6-08)
- AI #5: Procedural fix for G-class gotcha re-hits (skim-reference at start of each /dev-story)

**Architecture-review delta #10** (2026-05-03; same-day with S5-12 + S5-13 ship): ADR-0015 Proposed → Accepted; PASS WITH 1 SAME-PATCH CORRECTION + 2 IMPLEMENTATION ADVISORIES; 11 same-patch wording flips applied across ADR-0005/0010/0013/0014 + registry/architecture.yaml v8 → v9; structural backfill (~45 TRs + 15 file edits) explicitly DEFERRED to sprint-6 S6-02. Report: `docs/architecture/architecture-review-2026-05-03.md`.

---

## Sprint 4

### S4-04 — Grid Battle Controller epic + 10 stories scaffold (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.75d
**Priority**: must-have

> 2026-05-02: grid-battle-controller Feature epic + 10 stories scaffolded (~26h sprint-5 implementation estimate). Pattern follows input-handling S3-04 epic-scaffold structure. **MVP-scoped per ADR-0014 §0** with 4 explicit deferral slots reserved for future ADRs (Battle AI / Formation Bonus / Rally / Skill). EPIC.md ~250 LoC referencing ADR-0014 + 10 governing ADRs (largest cross-system integration in project — 6 backends DI'd + DamageCalc static-call + BattleCamera DI'd + GameBus). 10 story breakdown: 001 GridBattleController class skeleton + 8-param DI + 6-backend assertion + _exit_tree cleanup with explicit CONNECT_DEFERRED-load-bearing comment per godot-specialist revision #1 (2h); 002 BattleUnit typed Resource ~10 fields + Dictionary[int, BattleUnit] registry + tag-based fate-counter unit detection (2h); 003 2-state FSM (OBSERVATION/UNIT_SELECTED) + 10-grid-action filter + click hit-test routing via BattleCamera.screen_to_grid (3h); 004 is_tile_in_move_range callback + _handle_move + _do_move + facing update + unit_moved signal (3h); 005 LARGEST story (4h) — attack chain: is_tile_in_attack_range + _resolve_attack (formation/angle/aura math inline) + DamageCalc.resolve(...) STATIC call per godot-specialist revision #2 + HPStatusController.apply_damage 4-PARAM signature per shipped + apply_death_consequences EXPLICIT call per grid-battle.md line 198 + damage_applied signal + ResolveModifiers extension 3 fields; 006 _acted_this_turn Dictionary + _consume_unit_action + auto-end-turn-when-all-acted + TurnOrderRunner.spend_action_token simplified single-token MVP (3h); 007 5-turn limit + _on_round_started + battle_outcome_resolved emission + victory check (CR-7 evaluation order: VICTORY_ANNIHILATION → DEFEAT_ANNIHILATION; commander-kill deferred to Scenario Progression sprint-6) (2h); 008 5 hidden fate counters (rear_attacks + formation_turns + assassin_kills + boss_killed + tank_alive_hp_pct on-demand) + hidden_fate_condition_progressed signal + HIDDEN SEMANTIC PRESERVATION TEST (Battle HUD MUST NOT subscribe — preserves Pillar 2 "어렵지만 가능하게" UX) (3h); 009 cross-ADR _exit_tree audit (TD-057 final close — HPStatusController already verified clean; story-009 verifies TurnOrderRunner) (1h); 010 epic terminal (3h) — 4 perf tests (per-event < 0.05ms / per-attack < 0.5ms / 100 actions < 100ms / setup < 0.01ms) + 4 lint scripts (signal_emission_outside_battle_domain + static_state + external_combat_math + balance_entities key-presence) + 6 BalanceConstants additions (MAX_TURNS_PER_BATTLE + 5 fate thresholds — placement may shift to Destiny Branch ADR sprint-6) + ResolveModifiers extension verified + epic-terminal commit. Implementation order: 001 → 002 → 003 → {004, 005, 006, 008 parallel} → 007 → 009 → 010. Impl entirely deferred to sprint-5; sprint-4 S4-04 ships scaffold only. epics/index.md updated: header date refresh + grid-battle-controller row added (Feature 2/13 + 1 Ready). Cap discipline maintained (all sprint-status.yaml lines ≤200 bytes verified).

**Files touched** (single scaffold commit):
- production/epics/grid-battle-controller/EPIC.md (NEW, ~250 LoC referencing ADR-0014 + 10 governing ADRs + cross-system stub strategy)
- production/epics/grid-battle-controller/story-{001..010}-*.md (NEW, 10 stories ~80-200 LoC each)
- production/epics/index.md (header timestamp + grid-battle-controller row added; Foundation 4/5+1Ready + Core 3/4 + Feature 2/13+1Ready)
- production/sprint-status.yaml (S4-04 done; top-level updated rotated)
- production/sprint-status-history.md (this entry + S4-04 history rotation)

**Sprint-4 progress: 5/7 done** (S4-00 retro + S4-01 ADR-0013 + S4-02 camera Complete + S4-03 ADR-0014 + S4-04 grid-battle scaffold). 2 remaining: S4-05 hero portraits gather (should-have, 0.5d) + S4-06 BGM candidates (nice-to-have, 0.25d).

**Note**: This is a SCAFFOLD-only epic — no code shipped. Implementation deferred to sprint-5 per sprint-4 plan. Pattern mirrors sprint-3 S3-04 input-handling scaffold (10 stories scaffolded; 0/10 implemented).

---

### S4-02 — Camera epic Complete: BattleCamera implementation (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 1.5d (actual: ~6h equivalent in single session)
**Priority**: must-have

> 2026-05-02: Camera Feature epic shipped in single epic-terminal commit — **first Feature-layer Node-based system + 3rd invocation of battle-scoped Node pattern** (after ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner). (1) Implementation: `src/feature/camera/battle_camera.gd` ~140 LoC implementing `class_name BattleCamera extends Camera2D` (NOT `Camera` per G-12 ClassDB collision verified at ADR-0013 godot-specialist review); 4 instance fields (_map_grid + _drag_active + _drag_start_screen_pos + _drag_start_camera_pos); `setup(map_grid)` DI seam called BEFORE add_child; `_ready()` with assertion + `make_current()` + zoom from BalanceConstants + GameBus subscribe via Object.CONNECT_DEFERRED + initial pan_clamp; MANDATORY `_exit_tree()` body explicitly disconnecting `GameBus.input_action_fired` (per ADR-0013 R-6 + godot-specialist concern #2 — without this, autoload retains callable on freed Node = leak); `screen_to_grid(Vector2) -> Vector2i` with `Vector2i(-1,-1)` sentinel for off-grid; `_apply_zoom_delta()` with cursor-stable recipe + range clamp [0.70, 2.00] + early-return at floor/ceiling (R-4 mitigation); `_handle_camera_pan()` with Camera-owns-drag-state per ADR-0005 OQ-2 resolution (`&"camera_pan"` is TRIGGER not delta source; Camera reads viewport mouse position itself); `_apply_pan_clamp()` keeps map visible (centers if smaller than viewport, clamps if larger). (2) Implementation contracts honored: GameBus signal signature uses `String` (not `StringName`) per shipped ADR-0001 line 49; InputContext fields are `target_coord`/`target_unit_id`/`source_device` per shipped src/core/payloads/input_context.gd (NOT `coord`/`unit_id` per ADR sketches — implementation uses shipped names). (3) Tests: 3 test files at tests/unit/feature/camera/ — `battle_camera_screen_to_grid_test.gd` (4 tests: sentinel + valid coord + 3-zoom invariance), `battle_camera_zoom_test.gd` (6 tests: default + step + floor/ceiling clamp + no-op-at-floor), `battle_camera_lifecycle_test.gd` (4 tests: setup field + _ready guard + _exit_tree subscription verification + zoom-from-BalanceConstants). 14/14 tests PASS / 0 errors / 0 orphans. Reuses existing tests/helpers/map_grid_stub.gd (from hp-status epic). (4) Same-patch BalanceConstants additions to assets/data/balance/balance_entities.json: 6 new keys (TILE_WORLD_SIZE=64 + TOUCH_TARGET_MIN_PX=44 + CAMERA_ZOOM_MIN=0.70 + CAMERA_ZOOM_MAX=2.00 + CAMERA_ZOOM_DEFAULT=1.00 + CAMERA_ZOOM_STEP=0.10) — TILE_WORLD_SIZE + TOUCH_TARGET_MIN_PX bundled per camera epic (also input-handling F-1 prerequisites — input-handling epic does NOT need to re-add). (5) Lints: 5 scripts at tools/ci/lint_camera_signal_emission.sh + lint_camera_exit_tree_disconnect.sh + lint_camera_no_hardcoded_zoom.sh + lint_camera_external_screen_to_grid.sh + lint_balance_entities_camera.sh — all chmod +x, all PASS against shipped code. (6) CI wiring: 5 new lint steps in .github/workflows/tests.yml after lint_damage_calc_no_stub_copy.sh. (7) 7 story files at production/epics/camera/story-{001..007}-*.md (concise stubs per single-session epic-terminal pattern). EPIC.md authored ~150 LoC. (8) production/epics/index.md updated: Feature layer 1/13 → 2/13 (camera Complete); header timestamp + camera row added. (9) Cross-ADR R-7 + TD-057 partial resolution: HPStatusController._exit_tree ALREADY EXISTS at src/core/hp_status_controller.gd:45 with GameBus.unit_turn_started.disconnect — partial false alarm (no retrofit needed for ADR-0010); TurnOrderRunner audit DEFERRED to grid-battle-controller epic story-009 (sprint-5+). (10) Final regression: **757 testcases / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0** (was 743 → +14 from camera tests = **9th consecutive failure-free baseline**).

**Files touched** (single epic-terminal commit):
- src/feature/camera/battle_camera.gd (NEW, ~140 LoC)
- tests/unit/feature/camera/battle_camera_{screen_to_grid,zoom,lifecycle}_test.gd (NEW, 3 files / 14 tests)
- assets/data/balance/balance_entities.json (+6 keys)
- tools/ci/lint_camera_*.sh + lint_balance_entities_camera.sh (NEW, 5 scripts chmod +x)
- .github/workflows/tests.yml (+5 lint steps)
- production/epics/camera/EPIC.md (NEW, ~150 LoC) + 7 story stubs
- production/epics/index.md (Feature 1/13 → 2/13; header date + camera row)
- production/sprint-status.yaml (S4-02 done; top-level updated rotated)
- production/sprint-status-history.md (this entry + S4-02 history rotation)

**Key precedent established**: First Feature-layer Node-based system. 3rd invocation of battle-scoped Node pattern stable. Pattern boundary: future battle-scoped Node systems (Battle HUD ADR sprint-5; GridBattleController ADR-0014 implementation sprint-5) follow same DI + _exit_tree() + 200-byte cap discipline. Cap discipline maintained throughout: all sprint-status.yaml lines ≤200 bytes verified.

---

### S4-03 — ADR-0014 Grid Battle Controller /architecture-decision (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.75d
**Priority**: must-have

> 2026-05-02: ADR-0014 Grid Battle Controller Accepted in lean mode. **Critical scope decision in §0**: MVP-scoped explicitly because grid-battle.md GDD is 1259 lines with full Alpha-tier scope (AI substate machine + FormationBonusSystem orchestration + Rally + USE_SKILL counter + AOE_ALL + closed-signal-set assertions). Faithful full-scope ADR would be 800+ LoC and 4-6h beyond sprint-4 capacity. **4 explicit deferral slots** reserved: Battle AI ADR (sprint-7+) + Formation Bonus ADR (post-MVP) + Rally ADR (post-MVP) + Skill ADR (post-MVP). Each gets its own ADR when gameplay needs land. (1) godot-specialist (Pass 1+2+3 review) returned **PASS WITH 2 REVISIONS**: revision #1 (CONNECT_DEFERRED on `unit_died` is load-bearing reentrance prevention — without it, `_on_unit_died` fires synchronously inside `HPStatusController.apply_damage()` from `_resolve_attack`, causing reentrant `_check_battle_end`; added explicit comment in §3 + R-8) + revision #2 (DamageCalc methods are `static func` — confirmed by reading shipped code at `src/feature/damage_calc/damage_calc.gd:69 static func resolve(...)`; dropped DamageCalc from DI signature, drop instance field, change to `DamageCalc.resolve(...)` direct static-call site; updated §3/§5/§10/§Diagram/§ADR-Dependencies + R-3 8-param). (2) Implementation Notes section added to ADR for 3 fresh-from-shipped-code findings: `apply_damage` is 4-param not 2-param; `is_alive` not `is_dead` is canonical query; HPStatusController._exit_tree() ALREADY EXISTS (good news — TD-057 partial false alarm, only TurnOrderRunner audit remains). (3) Registry update: 10 entries appended to `docs/registry/architecture.yaml` (1353→1472 lines): 1 state_ownership (`battle_runtime_state` — 11+ fields incl 5 hidden fate counters), 2 interfaces (`grid_battle_controller_signal_emission` 5 controller-local signals + `grid_battle_controller_query_api` 4 public methods), 1 performance_budget (0.5ms peak per battle action), 3 api_decisions (`grid_battle_controller_module_form` 4th battle-scoped Node + `damage_calc_static_call_not_DI` revision #2 + `unit_died_connect_deferred_load_bearing` revision #1), 3 forbidden_patterns (`grid_battle_controller_signal_emission_outside_battle_domain` + `grid_battle_controller_static_state` + `grid_battle_controller_external_combat_math` migration safety rail). (4) Cross-ADR follow-up partially resolved: ADR-0013 R-7 + TD-057 candidate verified — HPStatusController already has `_exit_tree()` cleanup (line 45 of shipped code); only TurnOrderRunner audit remains for grid-battle-controller epic story-009. ADR ~510 lines after revisions; covers 13 GDD requirements addressed; LOW engine risk confirmed.

**Files touched**:
- `docs/architecture/ADR-0014-grid-battle-controller.md` (NEW, ~510 lines after godot-specialist revisions)
- `docs/registry/architecture.yaml` (1353→1472 lines, +10 entries all referencing ADR-0014; 28 ADR-0014 references total)

**Note**: Status set to Accepted in-file per lean mode. godot-specialist Pass 1+2+3 was the substitute review — found 2 revisions both resolved before commit. Pattern stable at 2 invocations (ADR-0013 + ADR-0014); engine specialist as substitute for TD-ADR PHASE-GATE in lean mode is the discipline going forward.

---

### S4-01 — ADR-0013 Camera /architecture-decision (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.5d
**Priority**: must-have

> 2026-05-02: ADR-0013 Camera Accepted in lean mode. (1) godot-specialist (Pass 1+2+3 review) returned CONCERNS: 2 BLOCKING + 1 ADVISORY. Required revisions applied: §1 `class_name Camera` → `BattleCamera` (G-12 ClassDB collision with built-in Camera base class — parent of Camera2D + Camera3D); §5 added `_exit_tree()` body explicitly disconnecting `GameBus.input_action_fired` callback (Godot 4.x signal mechanic: when SOURCE outlives TARGET, no auto-disconnect; without explicit cleanup, autoload retains callable pointing at freed Node = leak + potential crash). Advisory R-7 added: `process_mode` ambiguity for pause-menu (deferred resolution to camera epic story-001 once pause-menu pattern decided). Lint shape correction in §Validation Criteria item 2: `\.emit` suffix anchor distinguishes emit calls from subscribe/disconnect/is_connected. (2) Registry update: 11 entries appended to `docs/registry/architecture.yaml` (1252→1353 lines): 1 state_ownership (`battle_camera_view_state`), 1 interface (`battle_camera_public_api`), 1 performance_budget (camera 0.05ms), 3 api_decisions (`camera_module_form` 3rd battle-scoped Node invocation + `camera_owns_drag_state` ADR-0005 OQ-2 resolution + `camera_zoom_constants` 4 BalanceConstants), 4 forbidden_patterns (`camera_signal_emission` + `camera_missing_exit_tree_disconnect` + `hardcoded_zoom_literals` + `external_screen_to_grid_implementation`). (3) Cross-ADR follow-up logged: ADR-0010 + ADR-0011 (battle-scoped Nodes also subscribing to autoloads) need same `_exit_tree()` audit; carried as TD-057 candidate by camera epic story-006. ADR ~280 lines after revisions; covers 7 GDD requirements addressed (input-handling F-1 + §9 + OQ-2 + CR-1 + EC-9 + map-grid get_map_dimensions); LOW engine risk confirmed (no post-cutoff Camera2D APIs).

**Files touched**:
- `docs/architecture/ADR-0013-camera.md` (NEW, ~280 lines)
- `docs/registry/architecture.yaml` (1252→1353 lines, +11 entries all referencing ADR-0013)

**Note**: Status set to Accepted in-file per lean mode (no PHASE-GATE TD-ADR per `production/review-mode.txt`). godot-specialist review (Pass 1+2+3) was the substitute review — found 2 blocking issues, both resolved before commit. Pattern: spawn engine specialist for Pass 1 API correctness, accept their concerns as blocking pre-write fixes.

---

## Sprint 3

### Top-level `updated:` field — rolling history

#### 2026-05-02 (current after Sprint-4 close-out)

> Sprint-4 CLOSED: 5/7 done (must-have 4/4 + should 1/2 + nice 0/1). 2 asset items DEFERRED to user. Retro: retro-sprint-4-2026-05-02.md.

#### 2026-05-02 (rotated when Sprint-4 closed)

> S4-04 DONE: grid-battle-controller epic + 10 stories scaffolded (MVP-scoped, 4 deferrals; impl carries to sprint-5; ~26h estimate). See history S4-04.

#### 2026-05-02 (rotated when S4-04 landed)

> S4-02 DONE: camera epic Complete — BattleCamera + 14 tests + 5 lints + 6 BalanceConstants + 7 stories. 757/757 PASS (9th failure-free baseline). See history S4-02.

#### 2026-05-02 (rotated when S4-02 landed)

> S4-03 DONE: ADR-0014 Grid Battle Controller Accepted (MVP-scoped, 4 deferrals; 10 registry entries; 2 godot-specialist revisions). See sprint-status-history.md S4-03.

#### 2026-05-02 (rotated when S4-03 landed)

> S4-01 DONE: ADR-0013 Camera Accepted (BattleCamera + _exit_tree disconnect mandatory; 11 registry entries). See sprint-status-history.md S4-01.

#### 2026-05-02 (rotated when S4-01 landed)

> Sprint-4 kickoff: post-prototype pivot. See sprint-status-history.md (Sprint 3 close-out + Top-level updated history).

#### 2026-05-02 (rotated when Sprint-4 started)

> S3-06 DONE: TD-042 RESOLVED. data-files.md §Entity Data File Exception +~75 LoC. Sprint-3 7/7 closed. See sprint-status-history.md (Top-level updated).

#### 2026-05-02 (rotated when S3-06 landed)

> S3-05 DONE: 200-byte cap active, sprint-status-history.md created, /story-done Phase 7 amended. See sprint-status-history.md (Top-level updated).

#### 2026-05-02 (rotated when S3-05 landed)

> S3-04 + /qa-plan input-handling DONE; pre-impl discipline closed. Full notes → sprint-status-history.md (Sprint 3 → Top-level updated history).

#### 2026-05-02 (rotated when /qa-plan input-handling landed)

> S3-04 DONE + /qa-plan input-handling DONE: 462-line plan covering 10 stories (6 Logic + 3 Integration + 1 Config/Data) + 6 verification items (4 mandatory headless + 2 Polish-defer) + smoke + DoD. Pre-implementation discipline closed; ready for /dev-story story-001 (sprint-4).

#### Earlier sprint-3 `updated:` values

(Not retained — were overwritten in-place during S3-00..S3-04 work before this hygiene refactor landed. Future updates rotate through this section.)

---

### S3-06 — TD-042 close-out: data-files.md Entity Data File Exception amendment (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.5d
**Priority**: nice-to-have

> 2026-05-02: TD-042 (LOW severity, doc drift) RESOLVED. (1) Amended `.claude/rules/data-files.md` with new §Entity Data File Exception section (~75 LoC, parallel structure to existing §Constants Registry Exception): exhaustive affected-files list (heroes.json + terrain_config.json + unit_roles.json), 4-point rationale (cross-doc grep-ability + @export discipline + domain shape + project-wide naming coherence), limited-scope clause (4 explicit non-targets), entity file format example with heroes.json excerpt, review-on-Alpha-DataRegistry trigger, origin trace. (2) Cross-linked from each of the 3 affected ADRs (ADR-0007 §3 + ADR-0008 §2 + ADR-0009 §4) — single-line "Key naming: snake_case per data-files.md §Entity Data File Exception (added 2026-05-02 per TD-042 close-out)" placed at the JSON-schema decision spot in each. (3) Marked TD-042 RESOLVED in `docs/tech-debt-register.md` with resolution-summary line at top. Cited by future entity-data ADRs as the canonical exception authority. Sprint-3 nice-to-have 1/1 done.

**Files touched**:
- `.claude/rules/data-files.md` — +~75 LoC (new §Entity Data File Exception section after existing §Constants Registry Exception)
- `docs/architecture/ADR-0007-hero-database.md` — +1 paragraph at §3 (heroes.json schema decision)
- `docs/architecture/ADR-0008-terrain-effect.md` — +1 paragraph at §2 (terrain_config.json schema decision)
- `docs/architecture/ADR-0009-unit-role.md` — +1 paragraph at §4 (unit_roles.json schema decision)
- `docs/tech-debt-register.md` — TD-042 marked RESOLVED with summary line

**Note**: `unit_roles.json` doesn't yet exist on disk (ADR-0009 unit-role epic implementation pending). Listed in affected files exhaustively so the rule applies the moment the file lands.

---

### S3-05 — sprint-status.yaml hygiene refactor + /story-done amendment (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.5d
**Priority**: should-have

> 2026-05-02: Retro AI #3 closed. (1) Created `production/sprint-status-history.md` (this file) with Sprint 3 archive section + top-level `updated:` rolling history + 5 archived per-story changelogs (S3-00..S3-04). (2) Truncated 6 over-cap lines in `production/sprint-status.yaml` from 240-1280 bytes down to ≤200 bytes each (line 10 updated + lines 26/37/48/59/70 per-story). (3) Amended `.claude/skills/story-done/SKILL.md` Phase 7 step 4 with explicit 200-byte cap discipline + archive instructions + UTF-8 multi-byte budget note (`→`/`≥`/`↔` = 3 bytes each). (4) Replaced sprint-status.yaml header comment with active-policy version (was: "capped at 200 chars per sprint-3 retro AI #3 (older context archived...after S3-05 ships)" → now: 6-line policy block including verification awk command + skill cross-reference). Verified all 91 lines of sprint-status.yaml ≤200 bytes via awk gate. Sprint-3 should-have 2/2 done.

**Files touched**:
- `production/sprint-status.yaml` — header rewrite + 6 line truncations + S3-05 status done + top-level `updated:` rotation
- `production/sprint-status-history.md` — created (~120 lines after S3-05 entry added)
- `.claude/skills/story-done/SKILL.md` — Phase 7 step 4 expanded with cap discipline (~25 new lines)

---

### S3-04 — input-handling /create-epics + /create-stories + /qa-plan (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.75d
**Priority**: should-have

> 2026-05-02: /create-epics + /create-stories input-handling DONE + /qa-plan input-handling DONE. EPIC.md (~310 LoC) + 10 stories scaffolded (6 Logic + 3 Integration + 1 Config/Data) + qa-plan-input-handling-2026-05-02.md (462 lines / 41 KB — largest plan in project; precedent: hp-status 38 KB). Plan covers 10 automated test paths (9 unit/integration at tests/unit/foundation/input_router_*_test.gd + 1 perf at tests/performance/foundation/) + 6 mandatory verification items (4 headless: #3 emulate_mouse_from_touch / #4 recursive Control disable / #5a screen_get_size macOS / #5b safe-area API; 2 Polish-defer: #1 dual-focus / #2 SDL3 gamepad / #6 touch event index — and #5a Android Polish-defer split) + 8 smoke critical paths + 16-item DoD. Test growth trajectory: 743 → ≥837 (+94). 5 cross-system stubs schedule: grid_battle (story-003) + battle_hud + camera (story-008) + map_grid extension (story-008). 9 CI lint scripts schedule (story-010): no_input_override / input_blocked_drop / signal_emission_outside_input / hardcoded_bindings / emulate_mouse_from_touch / balance_entities_input_handling / g15_reset / 2 carried. Pre-implementation discipline closed; ready for /dev-story story-001 (sprint-4 work — implementation NOT in sprint-3 scope per EPIC.md).

**Original char count**: 1280 (over 200-char cap).

---

### S3-03 — Admin: refresh production/epics/index.md post-sprint-3 (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.25d
**Priority**: must-have

> 2026-05-02: minimal admin pass — header + layer coverage line + Note line + hp-status row (Status Ready→Complete + Stories 8/8) + Core-pending heading + new changelog entry for S3-02 close-out. Deeper rewrite (Implementation Order historical list, Outstanding ADRs section, Next Steps Sprint-1→Sprint-3, Gate Readiness re-check) deferred per S2-04 close-out note (still scoped as dedicated follow-up story).

**Original char count**: 419 (over 200-char cap).

---

### S3-02 — Implement hp-status epic to Complete (8 stories, greenfield) (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 2.0d
**Priority**: must-have

> 2026-05-02: story-008 Complete (epic terminal Config/Data; +44KB bundle: 4 test files at tests/unit/core/hp_status_*_test.gd [perf=8412B + consumer_mutation=5364B + determinism=9204B + no_counter_attack=5782B; 8 tests total]; 5 lint scripts at tools/ci/lint_hp_status_*.sh chmod +x; 3 doc edits [architecture.yaml lint_script field appends + 1 new entry / tests.yml 5 lint steps inserted lines 84-92 / tech-debt-register.md TD-050/051/052]; 735→743/0/0/0/0 Exit 0; 8th consecutive failure-free baseline; 13th lean-mode review APPROVED WITH SUGGESTIONS 0 required changes; 1 MINOR scope-strengthening deviation verified benign in external_current_hp_write lint). EPIC TERMINAL CLOSED — hp-status 8/8 Complete; sprint-3 S3-02 must-have done.

**Inline-comment supplement** (line 47 of YAML): `# ALL 8/8 stories Complete (001-008 + epic-terminal closed)`

**Original char count**: 749 (over 200-char cap).

---

### S3-01 — /create-epics + /create-stories hp-status + /qa-plan hp-status (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.5d
**Priority**: must-have

> 2026-05-02: hp-status Core epic created (18/18 TRs traced, 0 untraced); 8 stories decomposed (4 Logic + 2 Integration + 1 borderline-skeleton + 1 Config/Data; ~22-30h total est); qa-plan-hp-status-2026-05-02.md authored covering all 8 stories.

**Original char count**: 249 (over 200-char cap by 49 chars).

---

### S3-00 — Carry-fix turn-order test_round_lifecycle_emit_order_two_units (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.25d
**Priority**: must-have

> 2026-05-02: test adapted to story-006 RE3 chain reality (size==5 → ≥5; round_state==ROUND_ENDING assertion dropped — chain auto-loops to ROUND_CAP=30 DRAW). Test-side only; production unchanged. Full regression 648/0/0/0/0 PASS.

**Original char count**: 240 (over 200-char cap by 40 chars).

---

## Sprint 2 and earlier

Pre-S3-05 sprint changelogs were not retroactively imported here. The full audit trail for sprints 1 and 2 lives in:

- `production/retrospectives/retro-sprint-2-2026-05-02.md`
- `production/sprints/sprint-1.md` and `production/sprints/sprint-2.md`
- Git history (commits `66144d9` for sprint-2 close-out + earlier)

Future sprint sections will be appended above the "Sprint 2 and earlier" header as each new sprint runs through this hygiene policy.
