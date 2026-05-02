# Architecture Review — 2026-05-03 (delta #10, ADR-0015 Battle HUD escalation)

> **Mode**: lean delta-mode (single-ADR Proposed → Accepted escalation + cross-ADR stale-ref backfill)
> **Date**: 2026-05-03 (1st /architecture-review of the day; 10th overall invocation)
> **Pattern stability**: 10 invocations of fresh-session /architecture-review skill
> **Significance**: First **Presentation-layer ADR Accepted** + first project precedent of **pillar-anchored source-grep lint pattern** (Pillar 2 hidden semantic 3-layer enforcement) + delta-#9 stale-ref-backfill discipline extended to ADR-0013/0014 era

---

## Verdict: **PASS — APPROVED WITH SAME-PATCH CORRECTION + 2 IMPLEMENTATION ADVISORIES**

| Metric | Value |
|---|---|
| Cross-ADR conflicts (BLOCKING) | 0 |
| Same-patch wording corrections | 11 (across 5 ADRs + 1 registry) |
| Same-patch godot-specialist correction | 1 (Item A-4 typed Dictionary wording) |
| Advisories carried as Implementation Notes | 2 (B-4 forecast instrumentation + D Camera2D world_to_screen) |
| GDD revision flags | 0 |
| New TR-IDs registered | 0 (deferred to future structural backfill — see "Next-Session Candidates" §1) |
| TR registry version bump | none (v11 unchanged this delta) |
| Traceability version bump | none (v0.10 unchanged this delta — backfill deferred) |
| Architecture.md version bump | none (v0.7 unchanged this delta — backfill deferred) |
| Registry/architecture.yaml version bump | v8 → v9 (prose-only refresh; 0 net-new entries — entries already added at ADR-0015 Proposed-time) |
| Files written | 8 (1 status flip + 5 cross-ADR wording flips + 1 registry refresh + 1 NEW review report) |

---

## Phase 1 — Inputs Loaded

- **Target ADR**: `docs/architecture/ADR-0015-battle-hud.md` (Proposed 2026-05-03 lean mode authoring; ratifies 5 prior provisional contracts: ADR-0005 + ADR-0010 + ADR-0011 + ADR-0013 + ADR-0014)
- **Target UX spec**: `design/ux/battle-hud.md` v1.1 (744 lines; 14 UI-GB-* element specs + 13 visual/audio specs + forecast contract + two-tap ATTACK/DEFEND mobile flows + palette/accessibility + 6 acceptance criteria + 5 Open Questions) — NOT modified this delta (UX spec is authoring source-of-truth; ADR ratifies architectural form, not visual content)
- **Cross-ADR scan**: 5 ADRs whose provisional contracts ADR-0015 closes (ADR-0005, ADR-0010, ADR-0011, ADR-0013, ADR-0014)
- **Engine reference**: Godot 4.6 (pinned 2026-04-16); `breaking-changes.md` 4.4/4.5/4.6 entries + `deprecated-apis.md` + `modules/ui.md` (dual-focus, AccessKit, FoldableContainer, MOUSE_FILTER_IGNORE) + `modules/input.md`
- **Registries**: `docs/registry/architecture.yaml` v8 (already contains ADR-0015 entries from Proposed-time write — 1 state_ownership + 1 interface + 1 api_decision + 1 performance_budget + 5 forbidden_patterns)
- **Reference rules**: `.claude/rules/godot-4x-gotchas.md` G-15 + `.claude/rules/tooling-gotchas.md` TG-2 (TG-2 not triggered this session — handoff was clean per active.md)
- **Mode**: `production/review-mode.txt = lean` (TD-ADR PHASE-GATE skipped)

---

## Phase 2 — Technical Requirements (deferred to future structural backfill)

ADR-0015 codifies ~15-20 candidate TRs across 7 sections (§1 Module Form, §3 DI Setup, §4 Public API, §5 Signal Handlers, §6 Scale-with-Camera, §7 Tuning Knobs, §8 Pillar 2 Lock). **Per lean review-mode**, formal TR-battle-hud-001..N registration in `tr-registry.yaml` is **DEFERRED to a future explicit structural backfill** (see Next-Session Candidates §1). Same deferral applies to ADR-0013 BattleCamera (~10 candidate TRs) + ADR-0014 GridBattleController (~15-20 candidate TRs) — both shipped 2026-05-02 without TR registration; backfill bill compounds at ~45 net-new TRs.

Rationale: ADR-0015's GDD Requirements Addressed table (15 row entries mapping `design/ux/battle-hud.md` ACs + `design/gdd/grid-battle.md` CR-12 + `design/gdd/game-concept.md` Pillar 2 + `design/gdd/destiny-branch.md` Section B + `design/gdd/hp-status.md` UI-GB-11 + `design/gdd/turn-order.md` initiative queue + `design/gdd/input-handling.md` CR-4a + `design/gdd/formation-bonus.md` CR-FB-* + `design/ux/accessibility-requirements.md` R-2 + technical-preferences.md 44pt + i18n `tr()`) provides sufficient traceability for sprint-6 first-story implementation. The TR-ID layer is bookkeeping that can be backfilled atomically when the structural pass runs.

---

## Phase 4 — Cross-ADR Conflict Detection

**0 BLOCKING conflicts found.**

ADR-0015 ratifies 5 prior provisional contracts **verbatim parameter-stable** — every signature lock matches the upstream ADR's commit:

| Closure | Upstream ADR clause | ADR-0015 ratification | Match |
|---|---|---|---|
| 1 | ADR-0005 line 235-236 (Cross-System Provisional Table — Battle HUD `show_unit_info(int)` + `show_tile_info(Vector2i)`) | ADR-0015 §4 Public API | ✅ verbatim |
| 2 | ADR-0010 lines 207 + 737 + 780 (HP/Status query API for HUD) | ADR-0015 §3 DI'd backend + §5 signal handler reads | ✅ verbatim — chose POLL path per OQ-3 deferral |
| 3 | ADR-0011 §Decision Public API (`get_turn_order_snapshot()` pull-based for HUD + AI) | ADR-0015 §3 DI'd backend + §5 `_on_round_started` / `_on_unit_turn_ended` / `_on_unit_died` handlers call snapshot | ✅ verbatim — pull-based on signal receipts |
| 4 | ADR-0013 line 33(3) (HUD consumer of `get_zoom_value() -> float`) + ADR-0013 §Read-only state queries | ADR-0015 §6 `_process` zoom-poll gated on `_has_active_grid_overlay()` | ✅ verbatim |
| 5 | ADR-0014 §8 GameBus signal emission (5 controller-LOCAL signals; HUD primary consumer of 4 of 5) + line 335 (Pillar 2 lock) | ADR-0015 §3 R-3 + R-4 (4 of 5 subscribed; 5th explicitly forbidden) + §8 3-layer enforcement | ✅ verbatim — adds source-grep lint as 2nd enforcement layer |

### 11 same-patch wording corrections required (mechanical; stale-reference cleanup)

#### Group A — Battle HUD provisional contract closure (per ADR-0015 §Enables — MANDATORY)

| File | Lines | Pattern | Resolution |
|---|---|---|---|
| ADR-0005 | 43 (3) + 235-236 + 449 + 481-483 (5 ranges) | "Battle HUD ADR (NOT YET WRITTEN — soft / provisional downstream)" + "Battle HUD (NOT YET WRITTEN)" + "When Battle HUD ADR lands" + "Future: Battle HUD ADR" | Flip to "ADR-0015 Battle HUD (Accepted 2026-05-03 via /architecture-review delta #10) — RATIFIED parameter-stable" |
| ADR-0010 | 737 + 780 | "When Battle HUD ADR lands" + "Future Battle HUD ADR" | Same flip; clarify HUD chose POLL path per OQ-3 deferral; future `hp_status_changed` signal carried as advisory for next ADR-0010 amendment |
| ADR-0013 | 33 (Enables 3) + 35 (Ordering Note) + 71-72 (R-7) + 371 (Related Decisions) | "Battle HUD ADR (NOT YET WRITTEN — sprint-5)" + "When Battle HUD ADR ships (sprint-5)" + "Future Battle HUD subscriptions" | Same flip; clarify HUD §6 grid-overlay zoom-poll pattern |
| ADR-0014 | 33 (Enables 3) + 35 (Ordering Note) + 76 (R-9) + 323 (§8 heading) + 589 (Related Decisions) | "Battle HUD ADR (NOT YET WRITTEN — sprint-5)" + "exact set TBD per Battle HUD ADR sprint-5" + "MVP set; Battle HUD ADR may extend" | Same flip; emphasize Pillar 2 lock 3-layer enforcement (4-of-5 subscription with hidden_fate_condition_progressed EXPLICITLY excluded) |

#### Group B — Camera/Grid Battle "NOT YET WRITTEN" backfill (delta #9 lesson — extended to interim ADRs)

| File | Lines | Pattern | Resolution |
|---|---|---|---|
| ADR-0005 | 231-232 (Camera) + 233-234 (Grid Battle) | "Camera (NOT YET WRITTEN)" × 2 + "Grid Battle (NOT YET WRITTEN)" × 2 | Flip to "Camera (ADR-0013 Accepted 2026-05-02)" / "Grid Battle (ADR-0014 Accepted 2026-05-02) — RATIFIED parameter-stable per delta #10 backfill" |

#### Group C — Same-patch primary

- **ADR-0015** itself: Status `Proposed` → `Accepted` 2026-05-03; Last Verified updated; A-4 godot-specialist correction applied to §Engine Compatibility Post-Cutoff item 4 (`(4.4+ stable in 4.6)` → `(4.4+ — syntax verified at first-story implementation per Implementation Notes)`); §Implementation Notes amended with 2 advisories (B-4 forecast instrumentation + D Camera2D world_to_screen)

#### Group D — Registry refresh

- **`docs/registry/architecture.yaml`** v8 → v9: 3 line-level wording flips (lines 741-742 `battle_camera_public_api` consumers; line 757 `grid_battle_controller_signal_emission` consumers; line 774 `grid_battle_controller_query_api` consumers) + new top-of-file delta #10 changelog comment block. **0 net-new state/interface/api_decision/forbidden_pattern entries this delta** — entries were already added at ADR-0015 Proposed-time write (registry v7 → v8 commit 080dce8).

### ADR Dependency Ordering — no changes

Topological sort of the 15 Accepted ADRs (Platform 3 + Foundation 5 + Core 3 + Feature 3 [ADR-0012, ADR-0013, ADR-0014] + Presentation 1 [ADR-0015]) is unchanged. ADR-0015 has the largest direct-dep count (10 ADRs: ADR-0001 + ADR-0004 + ADR-0005 + ADR-0006 + ADR-0007 + ADR-0008 + ADR-0009 + ADR-0010 + ADR-0011 + ADR-0013 + ADR-0014 = 11 actually; mirrors ADR-0014's 9-dep precedent). All 11 deps are Accepted at delta #10 acceptance time. No unresolved dependencies; no cycles.

---

## Phase 5 — Engine Compatibility Audit

**Verdict: HIGH engine risk** (matches ADR-0015 §Engine Compatibility self-assessment); audit confirms 4 post-cutoff items are correctly cited against engine reference + 7 Verification items are well-formed.

### Audit findings

- `Control` lifecycle (`_ready`, `_exit_tree`, `_gui_input`) — pre-cutoff stable; no behavioral change in 4.4/4.5/4.6
- `CanvasLayer.layer` int property — pre-cutoff stable
- `Object.CONNECT_DEFERRED` flag form — Godot 4.x callable-based `signal.connect(callable, flags)` is correct; deprecated-apis.md confirms string-based connect is the deprecated 3.x pattern (PASS)
- `tr()` for i18n strings — pre-cutoff stable
- `Tween` for fade animations — pre-cutoff stable (Godot 4.0 Tween API rewrite already in training data)
- `set_anchors_preset(Control.PRESET_FULL_RECT)` — pre-cutoff stable
- `Control.MOUSE_FILTER_IGNORE` recursive (4.5+) — confirmed in `modules/ui.md` §4.5 "Recursive Control behavior"
- AccessKit auto-enabled (4.5+) — confirmed in `breaking-changes.md` §4.4→4.5
- Dual-focus split (4.6) — confirmed in `breaking-changes.md` §4.5→4.6 + `modules/ui.md` §4.6 + Common Mistakes
- Typed Dictionary (4.4+) — first-class typed Array/Dictionary deprecation note in `deprecated-apis.md` covers untyped → typed migration; explicit `Dictionary[K, V]` syntax verification per first-story implementation noted (A-4 correction applied)
- `is_equal_approx` — pre-cutoff stable

### godot-specialist consultation (independent review-time validation, 10th invocation)

Spawned via Task with focused brief covering 4 post-cutoff APIs + 7 Verification items + 5 specific code patterns + knowledge-gap flags. Returned **PASS WITH 1 CORRECTION + 2 ADVISORIES**:

| Item | Topic | Verdict | Action |
|---|---|---|---|
| A-1 | MOUSE_FILTER_IGNORE recursive (4.5+) | PASS | NO ACTION |
| A-2 | AccessKit auto-enabled (4.5+) | PASS | NO ACTION |
| A-3 | Dual-focus split (4.6) | PASS | NO ACTION |
| A-4 | Typed Dictionary "stable in 4.6" wording | **CONCERN** | **SAME-PATCH FIX** (§Engine Compatibility Post-Cutoff item 4: "(4.4+ stable in 4.6)" → "(4.4+ — syntax verified at first-story implementation per Implementation Notes)") |
| B-1..B-3 | Dual-focus E2E + AccessKit + 44pt touch | PASS | NO ACTION |
| B-4 | Forecast dismiss latency instrumentation | **ADVISORY** | **CARRY TO FIRST STORY** (replace `Performance.TIME_PROCESS` with `Time.get_ticks_usec()` start/end delta; `TIME_PROCESS` returns last `_process` call time, NOT Tween elapsed time) |
| B-5..B-7 | Recursive Control disable + CONNECT_DEFERRED + Pillar 2 lint | PASS | NO ACTION |
| C-1 | `_exit_tree()` `Signal.disconnect()` safe-no-op claim | PASS | NO ACTION (4.x behavior verified; revision #1 from authoring time correctly applied) |
| C-2 | `Object.CONNECT_DEFERRED` form | PASS | NO ACTION |
| C-3 | `_handle_signal` untyped Array | PASS | NO ACTION (revision #2 rationale sound) |
| C-4 | `_process` zoom-poll gating | PASS | NO ACTION (both early-return + `set_process(false)` valid) |
| C-5 | `class_name BattleHUD extends Control` under CanvasLayer | PASS | NO ACTION (one minor clarification carried as Implementation Note: CanvasLayer ownership scope — first-story wiring resolves) |
| D | `_camera.world_to_screen()` probe | **ADVISORY** | **CARRY TO FIRST STORY** (Godot 4.6 Camera2D does NOT expose `world_to_screen()` directly; use `get_canvas_transform() * world_pos` directly — the original "fallback" IS the primary path) |

**Overall**: 1 same-patch correction (A-4) + 2 carried advisories (B-4 + D) + 1 minor clarification (C-5 ownership scope). Pattern fits delta-#10 mean for HIGH-risk UI domain (avg 2-3 corrections; this delta = 1 + 2 = 3 items, well within range).

---

## Advisories Carried as Implementation Notes (NOT same-patch — first story responsibility)

These 2 advisories are documented in `ADR-0015-battle-hud.md` §Implementation Notes "Review-time advisories carried for first story (delta #10 godot-specialist consultation)":

1. **(godot-specialist B-4)** Replace `Performance.get_monitor(Performance.TIME_PROCESS) * 1000 < 80` with `Time.get_ticks_usec()` start/end delta from `damage_applied` signal receipt → `Tween.finished` signal, converted to milliseconds. `Performance.TIME_PROCESS` returns the time the last `_process` call took for the main thread (in seconds) — it is NOT the elapsed time of a single Tween or dismiss animation. If the dismiss Tween spans multiple frames, single-frame `TIME_PROCESS` underreports; if the frame had other work, it overreports. The correct event-to-completion measurement is `Time.get_ticks_usec()` start/end delta. Implementation-time instrumentation detail; no architectural impact.

2. **(godot-specialist D)** Use `_camera.get_canvas_transform() * world_pos` directly for grid-overlay world-to-screen position computation (UI-GB-12/13/14). `Camera2D` in Godot 4.6 does NOT expose a method named `world_to_screen()` directly; the ADR's original "anticipated drift surfaces" listed it as a probe target with the canvas-transform expression as the fallback, but the **fallback IS the primary path**. First story should not waste time probing for the non-existent method.

3. **(godot-specialist C-5 minor clarification — also carried)** `scenes/battle/battle_hud.tscn` could either be self-contained (CanvasLayer parent inside the .tscn) OR mounted by `battle_scene.tscn` (CanvasLayer at the BattleScene level per §2 architecture diagram). Both architecturally valid; §2 shows the latter as the safer convention for battle-scoped lifecycle management. First-story wiring resolves; no OQ added unless it surfaces as a real ambiguity at implementation time.

---

## Phase 5b — GDD Revision Flags

**No GDD revision flags — all GDD assumptions are consistent with verified engine behaviour.**

ADR-0015 §GDD Requirements Addressed table (15 entries) maps cleanly to:
- `design/ux/battle-hud.md` v1.1 (UX spec — ADR ratifies architectural form, defers visual content authoring)
- `design/gdd/grid-battle.md` CR-12 (UI signal emission — ADR-0015 subscribes to `formation_bonuses_updated` per CR-12 + 4 of 5 controller-LOCAL signals)
- `design/gdd/game-concept.md` Pillar 2 (운명은 바꿀 수 있다 / hidden semantic) — **enforced** at 3 layers via §8 Pillar 2 Lock
- `design/gdd/destiny-branch.md` Section B (Wordless Beat 7 reveal) — preserved by Pillar 2 lock preventing HUD from spoiling at Beat 6 results screen
- `design/gdd/hp-status.md` UI-GB-11 DEFEND_STANCE 1-turn badge — rendered via `_on_unit_turn_started` checking `_hp_controller.get_status_effects()`
- `design/gdd/turn-order.md` initiative queue snapshot — rendered via `_turn_runner.get_turn_order_snapshot()` pull-based
- `design/gdd/input-handling.md` CR-4a Touch Tap Preview Protocol — ratified via §4 `show_unit_info` + `show_tile_info`
- `design/gdd/input-handling.md` §S5 INPUT_BLOCKED — handled via `_on_input_state_changed` setting `MOUSE_FILTER_IGNORE` (4.5 recursive)
- `design/gdd/formation-bonus.md` CR-FB-1..14 — Formation Aura visual surface via `_on_formation_bonuses_updated`
- `design/ux/accessibility-requirements.md` R-2 (Intermediate tier; AccessKit on Control auto-exposes) — first-story authoring sets `tooltip_text` + `accessibility_*` per element
- `.claude/docs/technical-preferences.md` 44pt + i18n — enforced via CI lints + non-emitter discipline

No GDD asserts a behaviour that contradicts the verified Godot 4.6 engine reference; ADR-0015's HIGH-risk verification items are forward-looking (first-story implementation gates), not retroactive design-revision triggers.

---

## Phase 6 — Architecture Document Coverage

**Layer Map and TR-baseline backfill DEFERRED to a future explicit structural backfill run** (Next-Session Candidates §1). This delta does NOT update `docs/architecture/architecture.md` or `docs/architecture/architecture-traceability.md` because:

1. The accumulated drift spans 3 ADRs (ADR-0013/0014/0015 — none registered TRs at acceptance time)
2. A clean structural pass should backfill all 3 atomically, not incrementally
3. Lean review-mode argues against scope-creep; the Battle HUD escalation is the focused ask

**Acknowledged stale references** (do NOT block sprint-6 readiness — flagged for backfill run):
- `architecture.md` v0.7 line 13 says "12 Accepted ADRs" — actual count is 15 (ADR-0001 + ADR-0002 + ADR-0003 + ADR-0004 + ADR-0005 + ADR-0006 + ADR-0007 + ADR-0008 + ADR-0009 + ADR-0010 + ADR-0011 + ADR-0012 + **ADR-0013 + ADR-0014 + ADR-0015**)
- `architecture.md` Layer Map line 174 says "Battle HUD (#18) Alpha (not yet authored)" — should flip to "design/ux/battle-hud.md (ADR-0015 Accepted 2026-05-03 via delta #10)"; Presentation row 0/6 → 1/6
- `architecture.md` Layer Map lines 161 + 173 same-class issue for Grid Battle System (#1) + Camera (#22) — should flip to ADR-0014 + ADR-0013 references
- `architecture-traceability.md` v0.10 last source row is delta #9 (2026-04-30e); missing #10 row
- `tr-registry.yaml` v11 has 0 TR-camera-* + 0 TR-grid-battle-controller-* + 0 TR-battle-hud-* entries (~45 candidates pending registration)

These are **DOCUMENTATION debt** (not architectural conflicts) and do not block any sprint-6 implementation work. The structural backfill should be invoked as `/architecture-review backfill` (or similar) when there's session capacity for ~15 file edits.

---

## Layer Status Post-Acceptance

| Layer | Before delta #10 | After delta #10 | Notes |
|---|---|---|---|
| Platform | 3/3 Complete (ADR-0001/0002/0003) | 3/3 Complete | unchanged |
| Foundation | 5/5 Complete | 5/5 Complete | unchanged |
| Core | 3/3 Complete | 3/3 Complete | unchanged |
| Feature | 3/13 (ADR-0012 + ADR-0013 + ADR-0014 Accepted; 2 Vertical-Slice candidates open: AI + Scenario Progression + Destiny Branch + Battle Prep + Formation Bonus + Character Growth + Story Event + Equipment + Destiny State + Class Conversion = 10 still-pending Feature ADRs) | 3/13 | unchanged |
| **Presentation** | **0/6** | **1/6** (ADR-0015 BattleHUD; 5 still-pending: Battle Prep UI + Story Event UI + Main Menu + Battle VFX + Sound/Music) | **+1 first Presentation-layer ADR** |
| Polish | 0/3 | 0/3 | unchanged |

**Significant project transitions**:

- **14 → 15 Accepted ADRs**
- **Presentation layer 0 → 1** — first invocation of Presentation-layer pattern
- **Battle-scoped Node form** — 4 → 5 invocations (HPStatus + TurnOrder + Camera + GridBattleController + BattleHUD); first time the pattern crosses from Core/Feature into Presentation
- **First project precedent of pillar-anchored source-grep lint pattern** — `lint_battle_hud_hidden_fate_non_subscription.sh` enforces game-concept.md Pillar 2 hidden semantic at the source-code level (not just test-layer or convention)
- **Mandatory ADR list before Pre-Prod gate: 0 → 0** (unchanged from delta #8)
- **Pre-Production → Production gate now strongly eligible** (mandatory ADR list = 0 + first Presentation-layer pattern proven). Recommended to land 1-2 Vertical-Slice Feature ADRs (AI + Scenario Progression + Destiny Branch + Battle Scene wiring) before invoking `/gate-check pre-production`.

---

## Pattern Observations from Delta #10

1. **Delta-#9 stale-ref-backfill discipline successfully extended** — ADR-0005 lines 231-234 "Camera (NOT YET WRITTEN)" + "Grid Battle (NOT YET WRITTEN)" had been stale since ADR-0013/0014 shipped 2026-05-02 (3 days). Delta #10 backfilled these alongside the mandatory ADR-0015 closures, applying the codification candidate from delta #9: "future projects should backfill stale-ref qualifiers each delta to keep close-out bills linear (~3 corrections per delta) rather than cumulative." This delta = 11 corrections (vs delta #9 = 24 corrections close-out anomaly), confirming the discipline works when extended each delta.

2. **godot-specialist 10-invocation correction count**: A-4 + B-4 + D = 1 same-patch + 2 advisories. Mean across 10 deltas: 2.7 corrections/delta. Delta #6 = 6 (HIGH-risk InputRouter anomaly); delta #9 = 1 same-patch + 2 advisories; **delta #10 = 1 same-patch + 2 advisories** (matches delta #9 pattern; HIGH-risk UI domain absorbed as expected).

3. **Pillar 2 3-layer enforcement is novel** — first project precedent of:
   - **Test layer** (story-008 connection-count assertion: `signal.get_connections().size() == 0`)
   - **Source layer** (this ADR §8 grep-based zero-occurrence assertion: `lint_battle_hud_hidden_fate_non_subscription.sh`)
   - **Architecture layer** (registry forbidden_pattern `battle_hud_subscribes_to_hidden_fate_signal`)
   
   Future Pillar-anchored design constraints (e.g., Pillar 1 reading-flow timing budgets, Pillar 3 destiny-branch decision discoverability) can adopt this pattern when they need source-code-level enforcement beyond convention.

4. **9-param DI signature precedent** — ADR-0015's `setup(camera, hp_controller, turn_runner, grid_controller, input_router, map_grid, terrain_effect, unit_role, hero_db)` is the **largest** in the project (extends ADR-0014's 8-param). Pattern proven workable; future Presentation-layer ADRs (Battle Prep UI + Story Event UI + Main Menu) likely have 5-8 param `setup(...)` calls following the same shape. Acceptable per ADR-0014 8-param + ADR-0010 §Migration precedent.

5. **First Presentation-layer ADR** — establishes the layer pattern. Per `architecture.md` invariant 8 ("All six Presentation-layer UI screens touch HIGH engine risk (dual-focus 4.6). The first UI ADR must establish a dual-focus pattern that applies to all subsequent screens, or accept that every screen gets its own ADR."), ADR-0015's 7 Verification items are the **template** for the 5 remaining Presentation-layer ADRs. Each subsequent UI ADR can either inherit ADR-0015's verification gates (cite back to `lint_battle_hud_*` precedents) or document why it diverges.

6. **Structural backfill deferral codification** — when 3+ ADRs ship without TR registration, the backfill should be a **separate explicit run** (not bundled with an acceptance delta). This delta scopes to 11 corrections + 1 status flip; bundling structural backfill would have ballooned to ~30 corrections matching the delta-#9 24-correction anomaly. **Codification candidate**: future ADRs that ship outside `/architecture-review` (e.g., authored mid-sprint via `/architecture-decision`) should either (a) register TRs same-patch via mini-traceability-update, or (b) flag a backfill run within 2 weeks.

---

## Carried Cross-Doc Advisories (DEFERRED to next ADR substantive edit)

Unchanged from delta #9 — no new ADR-0001 advisories surfaced this delta:

1. **ADR-0001 line 168** `action: String` → `action: StringName` (delta #6 carry; queues with next ADR-0001 substantive edit)
2. **ADR-0001 line 372** prose drift `hero_database.get(unit_id)` → `HeroDatabase.get_hero(hero_id: StringName)` (delta #5 carry; queues with next ADR-0001 substantive edit)
3. **ADR-0012 internal ContextResource unit_id type** (lines 186/192/197/201 + call sites 260/352-353) propagate `int` through AttackerContext/DefenderContext factory signatures (delta #8 carry; queues with next ADR-0012 substantive amendment)

NEW carried advisory from this delta:

4. **ADR-0010 future signal candidate** — `hp_status_changed(unit_id)` signal would close ADR-0015 §Soft/Provisional clause (2) OQ-3 polling deferral; HUD subscription would be a 1-line poll-path replacement (additive, non-breaking). Carried for next ADR-0010 amendment (post-MVP).

---

## Next-Session Candidates (priority order)

1. **`/architecture-review` structural backfill** (~15 file edits; ~45 net-new TR-IDs across ADR-0013/0014/0015). Highest-leverage next architecture move. Eligible when session capacity supports a 30-edit pass. Will register:
   - TR-camera-001..N (~10) for ADR-0013
   - TR-grid-battle-controller-001..N (~15-20) for ADR-0014
   - TR-battle-hud-001..N (~15) for ADR-0015
   - Refresh `architecture.md` v0.7 → v0.8 (12 → 15 ADRs Accepted; Presentation 0/6 → 1/6; Layer Map rows for Camera + Grid Battle + Battle HUD)
   - Refresh `architecture-traceability.md` v0.10 → v0.11 (deltas #9, #10 source rows; ADR-0013/0014/0015 in Registered TR-to-ADR map)

2. **`/create-stories battle-hud`** — break ADR-0015 into 5-8 implementable stories per `production/epics/battle-hud/EPIC.md` 8-story preview decomposition. Eligible IMMEDIATELY post-delta-#10 (ADR-0015 now Accepted). Sprint-6 implementation candidate.

3. **`/qa-plan battle-hud`** — per-epic QA plan (mandatory before first `/dev-story battle-hud/story-001`); can be authored sprint-6 or proactively now.

4. **Battle Scene wiring ADR** — sprint-6; mounts `BattleHUD` as `CanvasLayer/BattleHUD` child + calls `setup(...)` BEFORE `add_child()`; first scene that USES the controller-LOCAL signals shipped sprint-5 + the ratified HUD contract from delta #10. Soft-dep ratified by ADR-0015 §Soft/Provisional clause (1).

5. **Scenario Progression ADR** — sprint-6; consumes `battle_outcome_resolved` independently of HUD (no cross-coupling per ADR-0015 §Enables clause 8). Required for first-chapter end-to-end flow.

6. **Destiny Branch ADR** — sprint-6; sole consumer of `hidden_fate_condition_progressed` per Pillar 2 lock; ADR-0015 §8 source-grep lint enforces HUD non-subscription as Destiny Branch's exclusive access.

7. **`/gate-check pre-production`** — technically eligible since delta #8 (mandatory ADR list = 0); strongly recommended to land 1-2 Vertical-Slice Feature ADRs (Battle Scene wiring + Scenario Progression + Destiny Branch) BEFORE invoking the gate check. Pre-emptive invocation now would PASS but signal premature confidence.

8. **`/sprint-plan sprint-6`** — formalize scope: battle-hud impl + Battle Scene wiring + Scenario Progression ADR + Destiny Branch ADR + structural backfill all candidates; capacity ~10-15 stories per sprint based on sprint-5 13/13 velocity.

9. **`/retrospective sprint-5`** — sprint-5 closed 13/13 🎉; retro captures Grid Battle Controller epic 10/10 + ADR-0015 + ADR-0013 + ADR-0014 + 5 prior provisional contract closures + 19th consecutive failure-free regression baseline.

10. **Batched ADR-0001 amendment** — when next ADR-0001 substantive edit occurs (e.g., new signal addition for Scenario Progression / Destiny Branch ADRs sprint-6), batch the 2 carried advisories (line 168 + line 372 prose drift).

---

## Files Written (8 total)

| # | File | Action | LoC delta (est.) |
|---|---|---|---|
| 1 | `docs/architecture/ADR-0015-battle-hud.md` | Status flip Proposed → Accepted + Last Verified + A-4 wording correction + §Implementation Notes amended (3 review-time advisories) | ±25 |
| 2 | `docs/architecture/ADR-0005-input-handling.md` | 5 wording flips (1 Soft/Provisional clause + 4 cross-system contract table rows + 5 cross-system migration paths + 5 Related Decisions) | ±15 |
| 3 | `docs/architecture/ADR-0010-hp-status.md` | 2 wording flips (line 737 + line 780 future Battle HUD past-tense) | ±4 |
| 4 | `docs/architecture/ADR-0013-camera.md` | 4 wording flips (line 33 Enables 3 + line 35 Ordering Note + line 71-72 R-7 + line 371 Related Decisions) | ±8 |
| 5 | `docs/architecture/ADR-0014-grid-battle-controller.md` | 5 wording flips (line 33 Enables 3 + line 35 Ordering Note + line 76 R-9 + line 323 §8 heading + line 589 Related Decisions) | ±12 |
| 6 | `docs/registry/architecture.yaml` | v8 → v9 prose-only refresh (top-of-file changelog comment block + 3 line-level wording flips: 741-742 + 757 + 774) | +50 |
| 7 | `docs/architecture/architecture-review-2026-05-03.md` | NEW (this report) | +400 |
| 8 | `production/session-state/active.md` | Silent append (Session Extract block) | +15 |

**Total estimated diff: ~530 insertions / ~70 deletions** across 8 files.

---

**End of delta #10 verdict report.**
