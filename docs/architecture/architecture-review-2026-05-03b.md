# Architecture Review Report — 2026-05-03b (delta #11)

| Field | Value |
|-------|-------|
| **Date** | 2026-05-03 |
| **Engine** | Godot 4.6 (pinned 2026-04-16; LLM cutoff May 2025) |
| **GDDs Reviewed** | 17 (10 MVP + 7 supporting) |
| **ADRs Reviewed** | **16 (all Accepted)** — ADR-0001..ADR-0012 (12 prior) + ADR-0013 BattleCamera + ADR-0014 GridBattleController + ADR-0015 BattleHUD + ADR-0016 BattleSceneWiring |
| **Mode** | full (combined session: ADR-0016 escalation + structural backfill) |
| **Invocation** | 11th /architecture-review |
| **Lean mode** | Active per `production/review-mode.txt` |
| **Source** | this report supersedes/extends `architecture-review-2026-05-03.md` (delta #10) |
| **Sprint context** | sprint-6 S6-02 (combined session per sprint-6 plan critical path) |

---

## Verdict: **PASS WITH 1 STATUS FLIP** + **0 BLOCKING CONFLICTS** + **0 GDD REVISION FLAGS**

**ADR-0016 Battle Scene Wiring**: Proposed → **Accepted** 2026-05-03 same-day via this delta.

This delta combines two outputs into one fresh session per sprint-6 plan S6-02 (sprint-5 retrospective AI #2 carry):
1. **ADR-0016 escalation** — Status header flip + Related cross-references updated
2. **Structural backfill** — ~50 net-new TR-IDs across ADR-0013/0014/0015/0016 (closes the sprint-5 retro AI #2 deferral) + 1 net-new state_ownership + 1 net-new interface + 1 net-new api_decision + 3 net-new forbidden_patterns in `docs/registry/architecture.yaml` v9 → v10

---

## Traceability Summary

| Status | Count | Δ from delta #10 |
|--------|-------|-------------------|
| Total registered TR-IDs (active) | **212** | +50 |
| ✅ Covered (full chain GDD → ADR) | 212 | +50 |
| ⚠️ Partial (Alpha-deferred per §7) | 15 (TR-balance-data-001..015 — pre-existing) | 0 |
| ❌ Gaps (no ADR exists) | 0 mandatory | 0 |

### TRs registered this delta (50)

**ADR-0013 BattleCamera (8 TRs):**

| TR-ID | Coverage |
|-------|----------|
| TR-camera-001 | §1 Module Form — battle-scoped Camera2D, 3rd invocation pattern |
| TR-camera-002 | F-1 zoom floor CAMERA_ZOOM_MIN=0.70 (44/64 derivation) |
| TR-camera-003 | screen_to_grid SOLE implementation (cross-system contract) |
| TR-camera-004 | OQ-2 drag-state ownership (Camera owns; not InputRouter) |
| TR-camera-005 | 4 camera-domain action handlers + CONNECT_DEFERRED |
| TR-camera-006 | Mandatory _exit_tree() autoload-disconnect (TD-057 4-precedent) |
| TR-camera-007 | 4 BalanceConstants (CAMERA_ZOOM_MIN/MAX/DEFAULT/STEP) |
| TR-camera-008 | Cursor-stable zoom recipe (2 affine_inverse) |

**ADR-0014 GridBattleController (14 TRs):**

| TR-ID | Coverage |
|-------|----------|
| TR-grid-battle-controller-001 | §1 Module Form — battle-scoped Node, 4th invocation; DamageCalc NOT in DI |
| TR-grid-battle-controller-002 | 2-state FSM MVP simplification |
| TR-grid-battle-controller-003 | 8-param setup() DI seam |
| TR-grid-battle-controller-004 | 5 controller-LOCAL signals (NOT GameBus) |
| TR-grid-battle-controller-005 | 2 callback API (is_tile_in_*_range) per ADR-0005 §9 |
| TR-grid-battle-controller-006 | 2 query API (get_selected_unit_id / get_battle_state_snapshot) |
| TR-grid-battle-controller-007 | 4 GameBus subscriptions w/ CONNECT_DEFERRED + _exit_tree |
| TR-grid-battle-controller-008 | Inline combat math + grid_battle_controller_external_combat_math forbidden_pattern |
| TR-grid-battle-controller-009 | 5 hidden fate counters + Pillar 2 lock |
| TR-grid-battle-controller-010 | 5-turn limit + battle_outcome_resolved |
| TR-grid-battle-controller-011 | Single action token MVP simplification |
| TR-grid-battle-controller-012 | 6 BalanceConstants (MAX_TURNS + 5 fate thresholds) |
| TR-grid-battle-controller-013 | 3 forbidden_patterns + lints |
| TR-grid-battle-controller-014 | Performance budget (per-event <0.05ms / per-attack <0.5ms) |

**ADR-0015 BattleHUD (17 TRs):**

| TR-ID | Coverage |
|-------|----------|
| TR-battle-hud-001 | §1 Module Form — 5th invocation Control under CanvasLayer (first Presentation) |
| TR-battle-hud-002 | 9-param setup() DI seam + _handle_signal test seam |
| TR-battle-hud-003 | 11 GameBus subscriptions across 4 domains w/ CONNECT_DEFERRED |
| TR-battle-hud-004 | **Pillar 2 lock 3-layer enforcement** (test + lint + registry forbidden_pattern) |
| TR-battle-hud-005 | 14 UI-GB-* element render contract + grid-layer overlays |
| TR-battle-hud-006 | 2 public methods (show_unit_info / show_tile_info) per Tap Preview Protocol |
| TR-battle-hud-007 | Non-emitter discipline (zero GameBus.emit) |
| TR-battle-hud-008 | AC-UX-HUD-02 forecast dismiss <80ms (Time.get_ticks_usec() instrumentation) |
| TR-battle-hud-009 | FORECAST_RENDER_BUDGET_MS=120 BalanceConstants |
| TR-battle-hud-010 | Recursive Control disable on S5 INPUT_BLOCKED (4.5+ MOUSE_FILTER_IGNORE) |
| TR-battle-hud-011 | 44pt touch target lint enforcement (first accessibility lint) |
| TR-battle-hud-012 | i18n via tr() lint enforcement (first i18n lint) |
| TR-battle-hud-013 | 5 forbidden_patterns |
| TR-battle-hud-014 | Performance budget (1.0ms steady / 120ms forecast / 200ms results) |
| TR-battle-hud-015 | UI-GB-12/13/14 grid-layer overlays via NodePath (cross-tree) |
| TR-battle-hud-016 | AccessKit screen reader exposure (auto-enabled on Control) |
| TR-battle-hud-017 | Two-tap timer ownership (HUD owns; injects synthetic InputRouter event) |

**ADR-0016 BattleSceneWiring (11 TRs — NEW):**

| TR-ID | Coverage |
|-------|----------|
| TR-battle-scene-wiring-001 | NEW pattern: scene-root-as-orchestrator (6th invocation lineage but distinct) |
| TR-battle-scene-wiring-002 | 3-node .tscn skeleton (BattleScene + GridLayer + HUDLayer) |
| TR-battle-scene-wiring-003 | 6-step _ready() mount sequence (DI-DAG forced order) |
| TR-battle-scene-wiring-004 | Sprint-6 inline mock encounter loader (4 units + 6×6 grass) — explicit deletion site |
| TR-battle-scene-wiring-005 | project.godot main_scene flip — sprint-6 only — revert at ADR-0017 |
| TR-battle-scene-wiring-006 | NO _exit_tree() body (auto-tree-free + per-child _exit_tree delegation) |
| TR-battle-scene-wiring-007 | NO GameBus subscriptions (non-emitter + non-subscriber discipline) |
| TR-battle-scene-wiring-008 | Idempotent _ready() under 3 launch sources |
| TR-battle-scene-wiring-009 | <50ms perf budget on Snapdragon 7-gen |
| TR-battle-scene-wiring-010 | Forbidden pattern compliance (no static / no autoload / no parameter-on-instantiate) |
| TR-battle-scene-wiring-011 | 3 lint scripts at S6-07 epic-terminal |

---

## Coverage Gaps

**0 mandatory gaps.** All 16 ADRs covered with full TR registration.

**Strongly recommended (Vertical Slice candidates — not mandatory):**

| Gap | Suggested ADR | Domain | Engine Risk | Sprint |
|-----|---------------|--------|-------------|--------|
| Scenario Progression chapter loader + ScenarioRunner | `/architecture-decision scenario-progression` | Feature | LOW | sprint-6 should-have S6-10 |
| Destiny Branch sole consumer of hidden_fate_condition_progressed | `/architecture-decision destiny-branch` | Feature | LOW | sprint-6 nice-to-have S6-11 |
| AI System threat eval + decision | `/architecture-decision ai-system` | Feature | LOW | sprint-7+ |
| Battle Preparation hero loadout + formation pick | `/architecture-decision battle-preparation` | Feature | LOW | sprint-7+ |
| Formation Bonus orchestration (replaces inline math per CR-FB-6) | `/architecture-decision formation-bonus` | Feature | LOW | post-MVP |

---

## Cross-ADR Conflicts

**0 BLOCKING.**

5 same-patch wording flips applied this delta (stale-ref backfill discipline per delta #9 lesson — keep close-out bills linear):

| ADR | Line(s) | Stale wording | Flipped to |
|-----|---------|---------------|------------|
| ADR-0013 | line 33 | "Battle Scene wiring (sprint-6) — first scene that includes..." | "ADR-0016 Battle Scene Wiring (Accepted 2026-05-03 via delta #11) — RATIFIED parameter-stable: BattleCamera mounted at step 2 of 6-step _ready() mount sequence" |
| ADR-0014 | line 33 | "Battle Scene wiring (sprint-6 — first scene that mounts...)" | "ADR-0016 Battle Scene Wiring (Accepted 2026-05-03 via delta #11) — RATIFIED parameter-stable: GridBattleController mounted at step 5 of 6-step _ready() mount sequence" |
| ADR-0015 | line 34 | "Battle Scene wiring (sprint-6 — Battle Scene mounts BattleHUD as CanvasLayer/BattleHUD...)" | "ADR-0016 Battle Scene Wiring (Accepted 2026-05-03 via delta #11) — RATIFIED parameter-stable: BattleHUD mounted at step 6 of 6-step _ready() mount sequence under HUDLayer" |
| ADR-0015 | line 644 | "Future: Battle Scene wiring ADR (NOT YET WRITTEN — sprint-6) — mounts BattleHUD as CanvasLayer/BattleHUD child" | "ADR-0016 Battle Scene Wiring (Accepted 2026-05-03 via delta #11) — mounts BattleHUD as HUDLayer/BattleHUD child via 6-step _ready() mount sequence" |
| `docs/registry/architecture.yaml` | various | placeholder reference line 825 (battle-scene-wiring placeholder) | ratified as `battle_scene_wiring_module_form` api_decision (see registry v9 → v10) |

Total: 4 ADR file edits + 1 registry consolidation = **5 same-patch wording flips** within delta-pattern range (delta #6 6-correction HIGH-risk anomaly was higher; this delta is clean).

---

## ADR Dependency Order (topologically sorted)

**Foundation (no dependencies):**
1. ADR-0001 GameBus
2. ADR-0006 BalanceConstants

**Depends on Foundation:**
3. ADR-0002 SceneManager (requires ADR-0001)
4. ADR-0003 SaveManager (requires ADR-0001 + ADR-0002)
5. ADR-0004 MapGrid (requires ADR-0001 + ADR-0003)
6. ADR-0007 HeroDatabase (requires ADR-0001 + ADR-0006)
7. ADR-0008 TerrainEffect (requires ADR-0001 + ADR-0006)
8. ADR-0009 UnitRole (requires ADR-0001 + ADR-0006 + ADR-0007 + ADR-0008)
9. ADR-0005 InputRouter (requires ADR-0001 + ADR-0002)

**Core (depends on Foundation):**
10. ADR-0010 HPStatusController (requires ADR-0001 + ADR-0006 + ADR-0007 + ADR-0009 + ADR-0011 provisional)
11. ADR-0011 TurnOrderRunner (requires ADR-0001 + ADR-0006 + ADR-0007 + ADR-0009 + ADR-0010)
12. ADR-0012 DamageCalc (requires ADR-0001 + ADR-0006 + ADR-0007 + ADR-0008 + ADR-0009 + ADR-0010 + ADR-0011)

**Feature (depends on Core):**
13. ADR-0013 BattleCamera (requires ADR-0001 + ADR-0004 + ADR-0005 + ADR-0006)
14. ADR-0014 GridBattleController (requires ADR-0001 + ADR-0004 + ADR-0005 + ADR-0007 + ADR-0008 + ADR-0009 + ADR-0010 + ADR-0011 + ADR-0012 + ADR-0013)

**Presentation (depends on Feature):**
15. ADR-0015 BattleHUD (requires ADR-0001 + ADR-0004 + ADR-0005 + ADR-0006 + ADR-0007 + ADR-0008 + ADR-0009 + ADR-0010 + ADR-0011 + ADR-0013 + ADR-0014)

**Scene-root orchestrator (depends on all Feature + Presentation + Foundation autoloads):**
16. **ADR-0016 BattleSceneWiring** (requires ADR-0001 + ADR-0002 + ADR-0004 + ADR-0005 + ADR-0010 + ADR-0011 + ADR-0013 + ADR-0014 + ADR-0015 — all Accepted; mounts the 6 systems via 6-step _ready() mount sequence)

**No dependency cycles.** No unresolved Proposed dependencies. ADR-0016 is the natural terminal node — all 9 required ADR dependencies are Accepted.

---

## Engine Compatibility Audit

**Engine**: Godot 4.6 (pinned 2026-04-16; LLM cutoff May 2025)
**ADRs with Engine Compatibility section**: 16 / 16 (100%)
**Deprecated API references**: 0
**Stale version references**: 0

### ADR-0016 Engine Risk: **LOW**

ADR-0016 introduces zero new post-cutoff API surface. APIs used:
- `Node` lifecycle (`_ready`, `_exit_tree`) — stable from 4.0
- `Node.add_child(child, force_readable_name)` — stable from 4.0
- `PackedScene.instantiate()` — stable from 4.0 (replaced 4.0-era `instance()`)
- `Node.queue_free()` — stable from 4.0
- `CanvasLayer.layer: int` property — stable from 4.0
- `[application] run/main_scene` project.godot key — stable from 4.0
- `class_name X extends Node2D` declaration — stable from 4.0

**HIGH-risk surface inherited transitively** through BattleHUD child but NOT re-asserted at BattleScene level:
- 4.6 dual-focus split (owned by ADR-0015 §Engine Compatibility)
- 4.5 AccessKit auto-exposure (owned by ADR-0015)
- 4.5 recursive `MOUSE_FILTER_IGNORE` (owned by ADR-0015 §5 + ADR-0002 §3)

ADR-0015's verification items remain authoritative for that subtree.

### Post-Cutoff API Consistency

All ADRs that reference 4.4/4.5/4.6 features cite `docs/engine-reference/godot/breaking-changes.md` consistently. No conflicting assumptions detected.

### godot-specialist Consultation

**Skipped this delta.** Rationale:
1. **12th invocation already done at S6-01 authoring time** (2026-05-03; recorded in ADR-0016 Implementation Notes): PASS WITH 2 REVISIONS RESOLVED + 5 advisories IN-1..IN-5 carried for first-story (S6-07) implementation
2. **Zero new engine API surface introduced** — ADR-0016 is structural plumbing using only stable ≤4.0 APIs; HIGH-risk surface remains transitively owned by ADR-0015
3. **Status flip + structural backfill have no engine semantic content** — all backfill TRs reference engine APIs already verified by prior 12 godot-specialist invocations (delta #10 covered the HIGH-risk Presentation-layer surface for ADR-0015; deltas #6/#7/#8/#9 covered Foundation+Core)

Future godot-specialist 13th invocation will fire at S6-07 first-story implementation when the actual `battle_scene.gd` lands — verifies all 5 IN-1..IN-5 advisories (BattleUnit field rename + `Node` typing for InputRouter stub + `Array[StringName]` typed return for mock helper + V-4 child count off-by-one correction + Steps 3+4 swap wording polish).

---

## GDD Revision Flags

**None.** All GDD assumptions are consistent with verified engine behaviour.

ADR-0016 inherits Pillar 2 lock from ADR-0014/0015 — discipline preserved. game-concept.md Pillar 2 (운명은 바꿀 수 있다 — Destiny Can Be Rewritten) hidden semantic: BattleScene root does NOT subscribe to `hidden_fate_condition_progressed` (TR-battle-scene-wiring-007 + new forbidden_pattern `battle_scene_root_signal_subscription`); 3-layer enforcement intact (test + lint + registry).

---

## Architecture Document Coverage

`docs/architecture/architecture.md` v0.7 → v0.8 refresh required (handled this same-patch in next file write):
- **Layer Map** — add ADR-0013/0014/0015/0016 to Accepted enumeration; flip Camera #22 row to Accepted; add Battle Scene Wiring as Feature-layer scene-root entry
- **Coverage summary** — Foundation 5/5 (unchanged) + Core 3/3 (unchanged) + Feature 1/3 → **3/4** (Damage Calc + BattleCamera + GridBattleController; remaining = AI/Battle Prep/Scenario Progression/Destiny Branch chain) + Presentation 0/6 → **1/6** (BattleHUD)
- **Completeness tracker** — Phase 5 row updated (16 Accepted ADRs)
- **Document Status** — bump version + reference this delta #11

`docs/architecture/architecture-traceability.md` v0.10 → v0.11 refresh required (handled this same-patch):
- TR rows 162 → 212 (50 new TR rows for ADR-0013/0014/0015/0016)
- Source line for tr-registry version bumped v11 → v12
- Source line for /architecture-review appends `architecture-review-2026-05-03b.md` as PASS WITH 1 STATUS FLIP delta #11
- ADR coverage line bumped 12 → 16 ADRs (all Accepted)

---

## Top ADR Gaps (Next-Session Candidates)

Prioritized by sprint-6 critical-path order:

1. **`/create-epics battle-scene`** (sprint-6 S6-03 — UNBLOCKED by ADR-0016 Acceptance) — preview ~3-5 stories per sprint-6 plan
2. **`/create-stories battle-hud`** (sprint-6 S6-04 — UNBLOCKED by ADR-0015 + ADR-0016 Acceptance) — sprint-6 first 2 impl stories scheduled S6-05/S6-06
3. **ADR-0017 Scenario Progression** authoring (sprint-6 should-have S6-10 / sprint-7 critical) — chapter loader replaces sprint-6 mock per ADR-0016 §Migration Plan
4. **`/qa-plan battle-hud`** (sprint-6 S6-08) — should-have for first Presentation-layer epic
5. **ADR-0018 Destiny Branch** authoring (sprint-6 nice-to-have S6-11 / sprint-7) — sole consumer of `hidden_fate_condition_progressed` per Pillar 2 lock

---

## Verdict Summary

**PASS WITH 1 STATUS FLIP**

- ✅ All 212 registered TR-IDs covered
- ✅ 0 BLOCKING cross-ADR conflicts
- ✅ 0 GDD revision flags
- ✅ 0 deprecated API references
- ✅ 0 dependency cycles or unresolved Proposed dependencies
- ✅ Engine compatibility consistent across all 16 ADRs
- ✅ ADR-0016 escalated Proposed → Accepted same-day
- ✅ 5 same-patch wording flips applied (stale-ref backfill discipline per delta #9 lesson)
- ✅ Structural backfill: ~50 net-new TRs + 1 state_ownership + 1 interface + 1 api_decision + 3 forbidden_patterns
- ✅ Sprint-5 retrospective AI #2 (`/architecture-review structural backfill ~45 candidate TRs`) **CLOSED**

**Files written this delta (10):**
1. `docs/architecture/ADR-0016-battle-scene-wiring.md` — Status flip Proposed → Accepted
2. `docs/architecture/tr-registry.yaml` — append 50 TRs across 4 ADRs; v11 → v12
3. `docs/registry/architecture.yaml` — v9 → v10 (1 state_ownership + 1 interface + 1 api_decision + 3 forbidden_patterns)
4. `docs/architecture/ADR-0013-camera.md` — same-patch wording flip
5. `docs/architecture/ADR-0014-grid-battle-controller.md` — same-patch wording flip
6. `docs/architecture/ADR-0015-battle-hud.md` — 2 same-patch wording flips
7. `docs/architecture/architecture-traceability.md` — v0.10 → v0.11 refresh + 50 new TR rows
8. `docs/architecture/architecture-review-2026-05-03b.md` — THIS report (NEW)
9. `docs/architecture/architecture.md` — v0.7 → v0.8 refresh (Layer Map + Coverage)
10. `production/session-state/active.md` — append Session Extract — /architecture-review delta #11

**Pattern stable at 11 invocations of /architecture-review.** Combined-session pattern (escalation + structural backfill in single fresh session per sprint-6 S6-02) — first invocation; future deltas may or may not combine depending on TR backfill size + same-session ban applicability.

---

## Handoff

### Immediate actions (sprint-6 critical path)

1. **`/create-epics battle-scene`** (S6-03) — UNBLOCKED by ADR-0016 Acceptance. Preview ~3-5 stories per sprint-6 plan.
2. **`/create-stories battle-hud`** (S6-04) — UNBLOCKED by ADR-0015 + ADR-0016 Acceptance. Sprint-6 first 2 impl stories scheduled S6-05/S6-06.
3. **`/qa-plan battle-hud`** (S6-08) — should-have for first Presentation-layer epic.

### Gate guidance

When all sprint-6 must-haves close (S6-01..S6-07), run `/gate-check pre-production` to advance.

### Rerun trigger

Re-run `/architecture-review` after each new ADR is authored (ADR-0017 Scenario Progression S6-10; ADR-0018 Destiny Branch S6-11) to verify coverage improves + stale-ref backfill is applied.
