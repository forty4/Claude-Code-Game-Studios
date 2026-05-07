# Sprint 10 — 2026-06-21 to 2026-06-27

> **Review mode**: lean (per `production/review-mode.txt`) — PR-SPRINT director gate skipped
> **Manifest Version**: 2026-05-05 (`docs/architecture/control-manifest.md` — refreshed via S7-08; sprint-10 doesn't refresh)
> **Generated**: 2026-05-07
> **Carries**: Sprint-9 retro AI seeds (8 carried forward — see §Sprint-10 Retro AI seed) + 7 sprint-9 deferred items (S9-06..S9-12 → S10-06..S10-12) + 2 USER-OWNED gates (S9-13 + S9-14 → S10-13 + S10-14)
> **Generated to close**: battle-hud epic 8/8 (3 remaining stories — first Presentation-layer epic graduates to Complete; 5/8 shipped sprint-6/7/8 — drift correction applied 2026-05-07 per retro AI #3) + scenario-progression Core epic (1 epic-terminal story shipped per ADR-0017 §Migration Plan §1..§11 single coordinated patch atomicity) + S9-11 CI lane gap forced decision (3-sprint deferral termination per retro AI #5) + sprint-9 Should/Nice carryover absorption + InputContext sentinel-discipline migration (PI #3 not validated in sprint-9)
>
> **Drift correction applied 2026-05-07** (per retro AI #3 story-spec doc-correction at /story-readiness time): /story-readiness on initial S10-01 (battle-hud story-004) discovered story-004 SHIPPED in sprint-7 S7-09 (commit `c5237c8` 2026-05-05; 6 tests passing in `battle_hud_initiative_queue_test.gd`) + story-005 SHIPPED in sprint-8 S8-07 (commit `ad3c378` 2026-05-06). Documentation lagged: index.md said "3/8 Complete"; actual is 5/8. Sprint-10 plan revised — 2 already-shipped stories removed; remaining battle-hud work is 3 stories (006/007/008). Story-004 close-out backfilled in same correction sweep + EPIC.md table updated + index.md updated.

## Sprint Goal

**Close the battle-hud epic 8/8** (Presentation-layer epic graduates to Complete; **3 stories remaining**: 006 combat forecast + 007 tile tooltip/results/grid overlays + 008 epic-terminal lints — per drift-correction sweep 2026-05-07) **+ ship scenario-progression Core epic** (1 epic-terminal story; sprint-6 mock encoder DELETION + phase-flipping lint flip + main_scene revert per ADR-0017 §Migration Plan §1..§11 single coordinated patch atomicity) **+ force S9-11 CI lane gap binding decision** (3-sprint deferral termination per retro AI #5 — either ship at least 1 new lane workflow OR write formal post-MVP postponement rationale doc; no further deferral allowed) **+ absorb sprint-9 carryover backlog** (4 Should + 3 Nice + 1 PI #3 hardening). Sprint-10 is a **mixed-scope sprint** — 3 closure-mode stories (battle-hud) + 1 greenfield story (scenario-progression) + 1 admin force-decision (CI lane gap); velocity-multiplier model split per retro AI #6 (closure 3× / greenfield 5×).

## Pivot context (carried from sprint-9 retro 2026-05-07)

Sprint-9 was the **first sprint in 4-sprint streak where Should-Have did not close** (Must 5/5 closed at 100%; Should/Nice 0/7 deferred via Producer pressure-cut discipline). Closure-mode velocity multiplier dropped from 5× (sprint-8 mixed-scope) to ~3× (sprint-9 pure closure) — R6 risk realized but R6 pre-mitigation absorbed it without missing Must-Have. Sprint-9 deferred 7 claude-owned items to sprint-10 + carried 2 user-owned attestation gates (S7-11 + S8-15 = S10-13 + S10-14). Codification debt was paid AT retro time per Process Improvement #1 (G-29 + TG-3 codified inline before retro close). Gate-check trajectory **CONCERNS unchanged for 3rd consecutive sprint** (sole blockers: S7-11 + S8-15 user-owned attestation).

Sprint-10 is the **battle-hud closure + scenario-progression ship + sprint-9 carryover absorption sprint**. Per retro AI #4: "Sprint-10 plan must absorb 7 carryover items as opening backlog; do NOT pretend they're new scope" — see §Carryover from Previous Sprint section ahead of new scope. S9-11 CI lane gap is **escalated to Must-Have** per retro AI #5 (3-sprint deferral termination obligation); all other carryovers retain their sprint-9 priority tier.

## Capacity (mixed-scope multiplier model per sprint-9 retro AI #6)

- Total days: **7 calendar → 5 working**
- Buffer (15%): **0.75 day** for unplanned work (battle-hud closure verification surface; scenario-progression mock encoder deletion + lint flip atomicity risk)
- Available: **4.25 working days**

> **Velocity model adjustment** (NEW per sprint-9 retro AI #6 ratchet correction): split estimates by mode — **closure-mode = 3× multiplier**; **greenfield/mixed = 5× multiplier**. Sprint-10 mix (post drift-correction):
> - Battle-hud 3 stories closure-mode (~1.3d nominal × 1/3) → projected actual ~0.4d
> - Scenario-progression 1 story greenfield (~0.6d nominal × 1/5) → projected actual ~0.12d
> - S10-05 CI lane decision admin (~0.2d × 1/3) → projected actual ~0.07d
> - **Sprint-10 Must total projected actual: ~0.6d** (down from sprint-9's 1.5d due to drift-correction trimming 2 already-shipped stories from Must scope)

> **AI #4 ratchet (6th consecutive)**: sprint-9 was 4.7d nominal / ~1.5d actual = ~3× under pure closure. Sprint-10 plan targets **~2.1d Must-Have nominal** (mixed-mode; post drift-correction) + ~1.0d Should + ~0.7d Nice = **~3.8d total nominal** — UNDER 4.25 capacity by 0.45d (~10% slack). Per Producer pressure-cut discipline, S10-10 (chapter-2 scoping) and S10-12 (InputContext sentinel migration) remain designated cut candidates if velocity drops below 3× under mixed-mode.

## Context

Project state as of 2026-05-07 (post-sprint-9 close + retro + 2 codifications):

- **20 ADRs Accepted**. ADR-0020 (InputRouter Dispatch) Accepted 2026-05-06 most recent. Sprint-10 governing ADRs: ADR-0015 (battle-hud) + ADR-0017 (scenario-progression) + ADR-0018 (destiny-branch — referenced by ADR-0017). No new ADRs pending for sprint-10.
- **Pre-Production → Production verdict**: CONCERNS (gate-check 2026-05-06 unchanged after sprint-9 ship). Sole gating blockers remain S7-11 + S8-15 USER-OWNED attestation. Path-to-PASS unchanged.
- **input-handling epic 10/10 Complete** 2026-05-07 (sprint-9 closure). **Foundation layer 5/5 Complete** on this graduation. Foundation autoload lineage at 9 production autoloads (no new autoloads expected from sprint-10 unless S10-06 Save/Load #17 ratification creates one — ratification path is design-only, not impl-adding-autoload).
- **Battle-scoped Node pattern at 6 invocations** (HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD + AISystem). No 7th invocation expected from sprint-10 (battle-hud is 5th invocation, already in flight; scenario-progression is autoload pattern, not battle-scoped).
- **Pillar 2 architectural lock pattern at 6 invocations** (codified in control-manifest.md). Battle-hud story-005 (action menu) involves the Pillar 2 lock (`battle_hud_subscribes_to_hidden_fate_signal` CRITICAL forbidden_pattern); validate enforcement landed at story-001 holds through story-005-008.
- **In-patch sprint-status hygiene STABILIZED at 21-streak** (sprint-9 ratcheted from sprint-8's 15-streak). Sprint-10 enforcement target: maintain streak (target 25+ for further pattern stability).
- **5 cross-system provisional contracts locked** (Camera + Grid Battle + Battle HUD + Settings + Tutorial per TD-069; widen-not-narrow). Sprint-10 battle-hud closure validates Battle HUD contract surface holds; downstream ADRs for Settings + Tutorial don't ship in sprint-10 (post-MVP).
- **G-29 + TG-3 codified** in `.claude/rules/godot-4x-gotchas.md` + `.claude/rules/tooling-gotchas.md` (sprint-9 retro 2026-05-07; codification debt paid at retro time per Process Improvement #1).
- **Story-spec doc-correction at /create-stories time discipline** (NEW from sprint-9 retro Process Improvement #3): when /create-stories runs, validate field names + TD sequence + AC baselines against current state, not against author-time state. Apply at sprint-10 /create-stories invocations if any (battle-hud 004-008 + scenario-progression 001 already authored).
- **1203/1203 PASSING** (46th consecutive failure-free baseline). Sprint-10 target: **≥1280 cases** (+~80 from battle-hud closure stories + scenario-progression).
- **Tech debt register at 70 entries** (TD-068/069/070 added by sprint-9 S9-05). TD-063 + TD-065 + TD-066 + TD-067 carry to grid-battle / future epic ownership; sprint-10 may close TD-067 via battle-hud story-008 lint scope extension if lint authoring fits in budget.
- **Sprint-9 carryover backlog** (7 claude-owned + 2 user-owned + 1 PI #3 hardening): full enumeration in §Carryover from Previous Sprint section.
- **CI lane gap 3-sprint deferred** (sprint-7 AI #5 → sprint-8 AI #8 → sprint-9 AI #10 → sprint-10 S10-05): retro AI #5 mandates binding decision in sprint-10. Promoted to Must-Have.

## Tasks

### Must Have (Critical Path) — battle-hud closure 3 stories + scenario-progression ship + S9-11 CI lane forced decision

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S10-01 | battle-hud story-006 — combat forecast (UI-GB-06 forecast panel; FORECAST_RENDER_BUDGET_MS = 120 BalanceConstants gate) | claude | 0.4 | battle-hud story-005 done (S8-07; ad3c378) | story-006 file: `production/epics/battle-hud/story-006-combat-forecast.md` AC satisfied; calls DamageCalc.resolve(...) for forecast preview; renders attacker/defender HP delta + hit% + crit% per damage-calc GDD §F-2; render budget enforced (`set_process(false)` gating per godot-specialist Pass 1 review #6); ≥6 tests |
| S10-02 | battle-hud story-007 — tile tooltip + results + grid overlays (UI-GB-02 tile info + UI-GB-09 results + UI-GB-12 movement range + UI-GB-14 attack range) | claude | 0.5 | S10-01 | story-007 file: `production/epics/battle-hud/story-007-tile-tooltip-results-grid-overlays.md` AC satisfied; tile tooltip on hover/touch via show_tile_info(Vector2i) public method; results screen on `battle_outcome_resolved` GameBus signal; movement range + attack range grid overlays with terrain-effect color coding per `design/gdd/terrain-effect.md`; ≥8 tests |
| S10-03 | battle-hud story-008 — epic-terminal lints + verification + perf baseline + 5 forbidden_patterns enforcement | claude | 0.4 | S10-02 | story-008 file: `production/epics/battle-hud/story-008-epic-terminal-lints-and-verification.md` AC satisfied; **5 forbidden_pattern lints** wired in `.github/workflows/tests.yml`: `battle_hud_signal_emission` + `battle_hud_subscribes_to_hidden_fate_signal` (CRITICAL Pillar 2) + `battle_hud_missing_exit_tree_disconnect` + `battle_hud_touch_target_below_44pt` + `battle_hud_hardcoded_localized_strings`; perf baseline (FORECAST_RENDER_BUDGET_MS gate); verification summary doc at `production/qa/evidence/battle_hud_verification_summary.md`; full GdUnit4 regression: ≥1230 cases / 0 errors / 0 failures / 0 orphans / Exit 0; **battle-hud epic 8/8 Complete** flip in `production/epics/index.md` |
| S10-04 | scenario-progression story-001 — ScenarioRunner Core epic single coordinated patch atomicity (ADR-0017 §Migration Plan §1..§11) | claude | 0.6 | sprint-7+8 mock encoder shipped | story-001 file: `production/epics/scenario-progression/story-001-scenario-runner-implementation-and-mock-encoder-deletion.md` AC satisfied; **single coordinated patch** ships: ScenarioRunner autoload (boot order 6) + 13-state machine + 9-beat per-chapter rhythm + ChapterDefinition typed Resource + 7-signal contract (5 confirmed + 2 ratified delta #12) + F-SP-3 v2.2 SYNCHRONOUS seal at BEAT_7 entry (Pillar 2 architectural lock 2nd precedent invocation) + F-SP-1/F-SP-2 delegation to DestinyBranchJudge + retry-loop guard + 3-CP save + 5 forbidden_patterns; **DELETE sprint-6 inline mock encoder** + **flip phase-flipping lint semantic** (1st-precedent semantic switch in project) + **main_scene revert** per ADR-0016 §Migration Plan §1; ≥25 tests; verification summary doc; `production/epics/scenario-progression/EPIC.md` Status: Ready → Complete |
| S10-05 | **CI lane gap formal decision** (S9-11 escalated; sprint-7 AI #5 → sprint-8 AI #8 → sprint-9 AI #10 → 3-sprint deferral termination per sprint-9 retro AI #5) | claude | 0.2 | — | **BINDING decision recorded** at `production/decisions/ci-lane-gap-decision-2026-05-XX.md`: EITHER author at least 1 new lane workflow file in `.github/workflows/` (macOS / iOS / Android candidates per ADR-0018 OQ-DB-6) OR write formal post-MVP postponement rationale doc with explicit reactivation triggers + dependency on user actions if any. **No further deferral allowed** — sprint-10 retro will validate decision shipped + binding |

**Must-have subtotal: ~2.1 working days nominal** (~17h; post drift-correction sweep). Per mixed-mode multiplier (3 closure × 1/3 + 1 greenfield × 1/5 + 1 admin × 1/3), projected actual: ~0.6d. If multiplier holds, sprint-10 ships in ~1 calendar day actual.

### Should Have — sprint-9 carryover backlog absorption

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S10-06 | **Save/Load #17 Core epic creation OR design-only ratification** (S9-06 1st carryover) — verify against existing save-manager Platform epic (8/8 Complete since 2026-04-24); if Save/Load #17 GDD adds NEW schema/contract not yet implemented, run `/create-epics save-load` + author 1-3 first stories; if GDD purely ratifies existing impl, flip systems-index row 17 Designed → Implemented (no-op) | claude | 0.3 | S8-08 GDD landed sprint-8 | Either: NEW save-load Core epic created at `production/epics/save-load/EPIC.md` with 1-3 stories ready for sprint-11; OR systems-index row 17 confirmed ratified-by-existing-impl with no impl gap |
| S10-07 | **First 3 character visual profile stubs** (유비/장비/리유비 — chapter-1 player roster) — closes AD-C5 ADVISORY (S9-07 2nd carryover; **2-carryover visibility threshold breached** per retro AI #2 — escalate or descope) | claude (or art-director) | 0.3 | — | 3 profile files at `design/art/characters/{liu-bei,zhang-fei,guan-yu}.md` (or 유비/장비 etc) with Section 1-3 minimum (silhouette + costume + role-anchor); AD-C5 ADVISORY closed in next gate-check |
| S10-08 | **AD-C3 font glyph check (緣 bond glyph rendering verification)** across chapter-1 text (S9-08 2nd carryover) — gates Story Event #10 text rendering tasks | claude | 0.2 | — | Test renders 緣 + verifies glyph fidelity in default font set (Pretendard or pinned chapter-1 font); result documented at `production/qa/evidence/font_glyph_check_緣.md`; AD-C3 OPEN closed in next gate-check |
| S10-09 | **Main menu UX spec stub** at `design/ux/main-menu.md` (S9-09 2nd carryover) — minimal section structure (information architecture + key states + accessibility tier compliance per `accessibility-requirements.md` Intermediate tier); closes AD-C6 ADVISORY | claude (or ux-designer) | 0.2 | — | UX spec created with 8-section template; references `accessibility-requirements.md` Intermediate tier; AD-C6 ADVISORY closed in next gate-check |

**Should-have subtotal: ~1.0 working day nominal** (~8h).

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S10-10 | **Pillar 4 chapter-2 scoping + chapter-1-callback ACs** (CD recommendation; S9-10 2nd carryover) — defines mechanical-narrative ripple-validation criteria for chapter-2; produces chapter-2 enemy roster + branch_table outline draft | claude | 0.3 | sprint-8 S8-11 chapter-1 e2e validated ScenarioRunner chain | chapter-2 outline draft at `design/scenarios/chapter-2-outline.md` (PROVISIONAL); chapter-1-callback ACs codify how ripple-narrative is validated; Pillar 4 demonstration gate criteria for sprint-11+ playtest |
| S10-11 | **Sprint-plan template refinement** (S9-12 1st carryover) — separate user-owned carryovers from claude-owned in `production/sprints/` template per sprint-8 retro carryover-tracking refinement note (already invocation-applied this sprint plan §Carryover from Previous Sprint section; codify as template) | claude | 0.1 | — | Future sprint plans use distinct sections for user-owned (hero portraits + BGM + attestations) vs. claude-owned carryovers via codified template at `.claude/skills/sprint-plan/templates/` (path TBD); velocity metrics not distorted by perpetual non-claude carryovers |
| S10-12 | **InputContext sentinel-discipline migration** (sprint-8 retro Process Improvement #3 carryover, NOT VALIDATED in sprint-9) — open hardening story to migrate `Vector2i.ZERO` → `Vector2i(-1, -1)` defaults across `_make_context_from_event` + downstream consumers | claude | 0.3 | — | InputContext defaults migrated to `Vector2i(-1, -1)` matching `target_unit_id = -1` pattern (3rd-precedent for sentinel-discipline alignment); existing consumers updated; tests refactored to use new sentinel; full suite green |
| S10-13 | **S7-11 user attestation pass** on 4 VS Validation items in `prototypes/chapter-prototype/REPORT.md` — **USER-OWNED** carryover (4th time; S7-11 → S8-15 → S9-13 → S10-13 = 3-sprint streak) | user | n/a | — | 3-5 captured run notes appended; triggers /gate-check pre-production re-run with PASS upgrade path |
| S10-14 | **S8-15 user attestation pass** on sprint-8 manual smoke check Batches 1+3 — **USER-OWNED** carryover (2nd time; S8-15 → S9-14 → S10-14) | user | n/a | — | Manual smoke check Batches 1+3 walked through + signed off in `production/qa/qa-signoff-sprint-8-2026-05-06.md` USER ATTESTATION section; triggers /gate-check pre-production re-run |

**Nice-to-have subtotal: ~0.7 working day nominal claude-owned** (~6h) + user-owned attestations (S10-13 + S10-14).

**Sprint-10 total nominal**: ~3.8 working days claude-owned (Must 2.1d + Should 1.0d + Nice 0.7d; **UNDER 4.25 capacity by ~0.45d** post drift-correction sweep). **Producer pressure-cut candidates** (per Producer pressure-cut discipline + carryover-tracking refinement): S10-10 (chapter-2 scoping; 2nd-carryover) and S10-12 (InputContext sentinel migration; PI #3 hardening). If velocity drops below 3× under mixed-mode, defer both to sprint-11.

## Carryover from Previous Sprint

> **Per sprint-9 retro AI #2 carryover-tracking refinement**: 7 claude-owned items deferred to sprint-10 are listed here AS OPENING BACKLOG, not as if they're equivalent priority to new sprint-10 scope. **Do NOT pretend they're new.**

### Claude-owned carryovers (active sprint scope; absorbed into S10-05..S10-12 above)

| Task | Original Sprint | Times Carried | New ID | Reason | New Estimate |
|------|----------------|---------------|--------|--------|-------------|
| **S9-11 CI lane gap formal decision** (sprint-7 AI #5 → sprint-8 AI #8 → sprint-9 AI #10) | sprint-7 | **3rd carryover — escalated to Must-Have per retro AI #5** (sprint-10 termination obligation; no further deferral allowed) | **S10-05** (Must) | Recurring deferral despite "force decision" framing in 3 consecutive sprints; sprint-10 retro AI #5 mandates binding outcome | 0.2d |
| Save/Load #17 Core epic ratification | sprint-9 (S9-06; originated this sprint) | 1st carryover | S10-06 (Should) | Closure-mode Must-Have consumed sprint-9 window | 0.3d |
| First 3 character profile stubs | sprint-8 (S8-12 deferred → S9-07) | **2nd carryover — visibility threshold breached** | S10-07 (Should) | Closure-mode pressure-cut sprint-9; Producer recommendation: escalate to Must in sprint-11 if not closed sprint-10 | 0.3d |
| AD-C3 font glyph check | sprint-8 (S8-13 deferred → S9-08) | **2nd carryover** | S10-08 (Should) | Closure-mode pressure-cut sprint-9 | 0.2d |
| Main menu UX spec stub | sprint-8 (S8-14 deferred → S9-09) | **2nd carryover** | S10-09 (Should) | Closure-mode pressure-cut sprint-9 | 0.2d |
| Pillar 4 chapter-2 scoping | sprint-8 (S8-16 deferred → S9-10) | **2nd carryover** | S10-10 (Nice; **cut candidate**) | Closure-mode pressure-cut sprint-9 | 0.3d |
| Sprint-plan template refinement | sprint-8 (retro AI #10 → S9-12) | 1st carryover | S10-11 (Nice) | Already invocation-applied this sprint plan §Carryover from Previous Sprint; codification cost only | 0.1d |
| **InputContext sentinel-discipline migration** (PI #3 NOT VALIDATED in sprint-9) | sprint-8 (Process Improvement #3 → sprint-9 stories 008-009 owners) | 1st carryover (NEW; PI #3 carry) | S10-12 (Nice; **cut candidate**) | Stories 008-009 shipped using existing `Vector2i.ZERO` defaults; migration deferred to dedicated hardening story | 0.3d |

### User-owned carryovers (track separately; do not count against velocity)

| Task | Times Carried | Reason | Status |
|------|---------------|--------|--------|
| S10-13 user attestation (S7-11 4 VS Validation items) | **4th time** (S7-11 → S8-15 → S9-13 → S10-13) | User-owned by design; refusal-to-fabricate posture commitment cost | Pending user time; ~30-60min |
| S10-14 user attestation (sprint-8 manual smoke Batches 1+3) | **2nd time** (S8-15 → S9-14 → S10-14) | User-owned by design; sprint-8 added | Pending user time; ~30-60min |
| Hero portraits (8) | **7th time** (Sprint-4 → 7 → 8 → 9 → 10) | User-owner | ColorRect placeholders functional; non-blocking |
| BGM candidates (2-3) | **7th time** (Sprint-4 → 7 → 8 → 9 → 10) | User-owner | Non-blocking for critical path |

## Cut from Sprint-10 (Producer pressure-cut candidates if velocity drops below 3× under mixed-mode)

| Task | Reason for cut | Deferred to |
|------|---------------|-------------|
| S10-10 Pillar 4 chapter-2 scoping | Defer if battle-hud closure + scenario-progression atomicity consume >2.5d nominal actual | sprint-11 |
| S10-12 InputContext sentinel-discipline migration | Hardening pass; not gating Production work | sprint-11 hardening |
| S10-06 Save/Load #17 implementation stories (if S10-06 surfaces a real gap) | Producer split-strategy: don't bundle Save/Load impl with battle-hud closure; ship Save/Load impl in sprint-11 | sprint-11 |
| S10-11 sprint-plan template refinement | Low-impact tooling cleanup; can absorb at sprint-11 plan-time directly | sprint-11 |
| Pause menu UX spec | Deferrable to menu implementation sprint per gate-check 2026-05-04 §AD-C6 | sprint-11+ menu sprint |
| ADR Engine Compatibility / Depends-on / Depended-by header backfill across 20 ADRs (TD ADVISORY) | Hardening pass; not gating Production work | sprint-11+ hardening sprint |

## Risks

- **R1 — Battle-hud story-005 action menu Pillar 2 lock validation may regress** if action-menu state interacts with hidden_fate_condition_progressed via indirect coupling. **Mitigation**: story-005 ACs MUST include explicit Pillar 2 lint validation; lint script `battle_hud_subscribes_to_hidden_fate_signal` (CRITICAL) already enforces structurally. Surface any indirect coupling at /code-review.
- **R2 — Battle-hud story-006 combat forecast render budget (FORECAST_RENDER_BUDGET_MS = 120) may be exceeded** under repeated forecast preview hover patterns on lower-end devices. **Mitigation**: enforce `set_process(false)` gating per godot-specialist Pass 1 review #6 (already specified); perf test under SKIP_PERF_BUDGETS=1 gate matches sprint-9 pattern; on-device verification Polish-deferred per Foundation-layer epic-terminal precedent.
- **R3 — Scenario-progression story-001 single coordinated patch atomicity is high-risk** (mock encoder DELETION + phase-flipping lint flip + main_scene revert + 5 forbidden_patterns + ~25 tests + 3 typed Resources + JSON data + autoload reg + verification summary all in one patch per ADR-0017 §Migration Plan §1..§11). **Mitigation**: 0.6d budget reflects atomicity overhead; Migration Plan provides ordered §1..§11 sequence; if atomicity exceeds budget, defer mock encoder deletion + lint flip to sprint-11 (story-001 ships ScenarioRunner-only) with Migration Plan §1 explicitly bisected.
- **R4 — Battle-hud closure may surface new G-* candidates** (UI domain Godot 4.6 has dual-focus + AccessKit + recursive Control disable + typed Dictionary post-cutoff API surface; sprint-9 surfaced G-29 from input-handling closure). **Mitigation**: per Process Improvement #1, codify any G-* candidate at sprint-10 retro time, not defer. Pre-allocate ~30min in retro for codification work.
- **R5 — Mixed-mode velocity multiplier may not settle cleanly** (sprint-10 mix is 5 closure + 1 greenfield + 1 admin; multiplier model is split per retro AI #6 but not yet validated empirically in mixed-mode-with-greenfield). **Mitigation**: sprint-10 retro validates whether the split multiplier produces accurate projection; if observed multiplier deviates >20% from projection, refine model at sprint-10 retro AI.
- **R6 — User-owned carryovers stack to 4 items** (S10-13 + S10-14 + portraits + BGM) — gate-check trajectory CONCERNS chain remains regardless of claude-owned work. **Mitigation**: communicate the user-owned backlog explicitly at sprint-10 retro; do NOT confuse refusal-to-fabricate posture with sprint failure. Sprint-10 retro should call out cumulative user-owned debt as project-state fact, not sprint blocker.
- **R7 — S10-07 character profile stubs hit 2-carryover visibility threshold** (per retro AI #2 carryover-tracking refinement). If sprint-10 also defers S10-07, sprint-11 plan must escalate to Must-Have OR formally descope. **Mitigation**: sprint-10 retro Producer reassessment of S10-07 priority tier; default escalation in sprint-11 if not closed.
- **R8 — S10-05 CI lane gap binding decision may surface implicit precondition** (3-sprint deferral pattern indicates the decision is awaiting some implicit precondition — likely post-MVP Production-stage hardening pass). **Mitigation**: post-MVP postponement rationale doc is the path-of-least-resistance binding outcome; this satisfies retro AI #5 without forcing impl that may not be appropriate at this stage. Use rationale doc unless macOS/iOS/Android lane authoring fits in 0.2d budget.
- **R9 — TD-067 may not close in sprint-10** (story-008 epic-terminal lints + verification could absorb i18n .tscn lint scope extension if budget permits, but PI #2 carryover from sprint-8 has been "carried" 3 sprints already). **Mitigation**: explicitly include TD-067 lint scope extension as story-008 acceptance criterion candidate; if exceeds 30min authoring cost, defer per story-008 deferred follow-up pattern.
- **R10 — Sprint-10 retro AI #4 risk** (carryover-tracking refinement adoption): if sprint-10 retro doesn't validate that S10-11 sprint-plan template codification landed, the next sprint cycle will repeat the manual sprint-plan §Carryover section authoring. **Mitigation**: S10-11 is Nice-to-Have but high-leverage; if sprint-10 ships under capacity, prioritize S10-11 over S10-10 (chapter-2 scoping has lower urgency since chapter-2 impl isn't sprint-11 critical path).

## Dependencies on External Factors

- None at the system level. All 20 ADRs Accepted; sprint-10 battle-hud closure governed by ADR-0015 (Accepted 2026-05-03); scenario-progression governed by ADR-0017 (Accepted 2026-05-04); ADR-0018 (destiny-branch) referenced by ADR-0017 also Accepted 2026-05-04. Engine pinned at Godot 4.6 (3+ months stable runway). GdUnit4 v6.1.2 pinned per `tests/README.md`.
- **User-owner deferred items** (hero portraits + BGM + 2 attestation gates) remain optional for sprint-10 critical path. Critical path uses ColorRect placeholders + text-based scenes per chapter-prototype precedent.
- **CI infrastructure**: Linux Editor + Windows D3D12 lanes active. macOS / iOS / Android lanes manual-fallback per ADR-0018 OQ-DB-6 partial closure. **S10-05 forces formal binding decision** (ship lanes OR postpone to post-MVP with rationale).

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (S10-01..S10-05 = 5 stories — post drift-correction sweep 2026-05-07)
- [ ] All tasks pass acceptance criteria
- [ ] **battle-hud epic 8/8 Complete** — flips in `production/epics/index.md` post-S10-03
- [ ] **scenario-progression epic 1/1 Complete** — flips in `production/epics/index.md` post-S10-04; Status: Ready → Complete in EPIC.md
- [ ] **Sprint-6 inline mock encoder DELETED** + **phase-flipping lint flipped** + **main_scene reverted** per ADR-0016 §Migration Plan §1 (S10-04 atomicity)
- [ ] **5 battle-hud forbidden_patterns enforced via lint scripts** in `tools/ci/` (S10-03)
- [ ] **5 scenario-progression forbidden_patterns enforced via lint scripts** in `tools/ci/` (S10-04)
- [ ] **CI lane gap binding decision recorded** at `production/decisions/ci-lane-gap-decision-2026-05-XX.md` (S10-05)
- [ ] Save/Load #17 Core epic decision recorded (S10-06 — either NEW epic created OR ratification noted in systems-index)
- [ ] First 3 character visual profile stubs at `design/art/characters/` (S10-07 — closes AD-C5 ADVISORY)
- [ ] AD-C3 font glyph check evidence at `production/qa/evidence/font_glyph_check_緣.md` (S10-08 — closes AD-C3)
- [ ] Main menu UX spec stub at `design/ux/main-menu.md` (S10-09 — closes AD-C6 ADVISORY)
- [ ] Full GdUnit4 regression: ≥1230 cases / 0 errors / 0 failures / 0 orphans / Exit 0 (target 1230-1280 depending on Should + Nice ship; up from sprint-9's 1203)
- [ ] `production/epics/index.md` updated: battle-hud 8/8 Complete + scenario-progression 1/1 Complete + (Save/Load Core epic NEW row if S10-06 creates epic)
- [ ] `production/sprint-status.yaml` updated **per-story-row at completion** (21-streak in-patch close discipline; sprint-10 enforcement target: maintain streak — target 25+ for further pattern-stability ratchet declaration)
- [ ] `tests/regression-suite.md` updated with battle-hud + scenario-progression epic-terminal critical path coverage
- [ ] Sprint-10 retrospective written before sprint-11 kickoff
- [ ] **Re-run `/gate-check pre-production`** if S10-13 + S10-14 user attestation captured during sprint-10 → expect upgrade CONCERNS → PASS + `production/stage.txt` written = "Production"
- [ ] **Codification debt at retro time discipline maintained** — if any G-* candidate surfaces in sprint-10, codify in `.claude/rules/godot-4x-gotchas.md` at retro time per Process Improvement #1
- [ ] **S10-11 sprint-plan template refinement codified** if Nice-to-Have ships (else explicit deferral note in retro)

## Sprint-10 Retro AI seed (carried from sprint-9 retrospective)

These will be evaluated at sprint-10 close + carried to sprint-11 plan:

1. **Codification debt MUST be paid at retro time** (sprint-8 PI #1 → sprint-9 honored). Any G-* / TD-* / pattern candidate surfaced during sprint-10 must be codified at sprint-10 retro time, not deferred. Pre-allocate ~30min in retro for codification work.
2. **Carryover concentration threshold** (NEW from sprint-9 retro Process Improvement #2): when ≥4 claude-owned items defer to next sprint, the sprint-plan must list them in a dedicated "Carryover Backlog" section ahead of new scope. Sprint-10 plan applies this discipline (§Carryover from Previous Sprint section above S10-NN tables); validate at retro that S10-13 codifies the template.
3. **Story-spec doc-correction at /create-stories time** (NEW from sprint-9 retro Process Improvement #3): /create-stories should not pre-author stories more than 2 sprints ahead of expected implementation; if a story is implemented from a 2+ sprint-old spec, run `/story-readiness [path]` with strict mode and surface drift before /dev-story starts. Sprint-10 battle-hud 004-008 + scenario-progression 001 stories were authored sprint-5/6/7 — apply discipline at /story-readiness invocation per story.
4. **Mixed-mode velocity multiplier model validation** (NEW from sprint-9 retro AI #6): sprint-10 is the first sprint applying the 3× closure / 5× greenfield split. Validate at retro whether observed multiplier matches projection within 20%; if not, refine model at sprint-10 retro AI.
5. **CI lane gap formal decision** (sprint-7 AI #5 → sprint-8 AI #8 → sprint-9 AI #10 → sprint-10 S10-07 escalated to Must). Validate at retro that decision shipped + binding outcome recorded + dependency on user is or isn't created.
6. **Sprint-status hygiene 21-streak** sustained from sprint-9. Sprint-10 enforcement: maintain streak (target: 25+ for further pattern-stability ratchet declaration).
7. **2-carryover visibility threshold** (S10-09 character profile stubs at 2nd carryover): validate at retro whether sprint-10 closed S10-09 OR escalated to sprint-11 Must-Have.
8. **Pillar 2 architectural lock validation** (battle-hud story-005 action menu): validate at retro that lint enforcement landed at story-001 holds through story-005-008 (no indirect coupling regressions surfaced).

## Cross-References

- **Sprint-9 retrospective**: `production/retrospectives/retro-sprint-9-2026-05-07.md`
- **Sprint-9 plan**: `production/sprints/sprint-9.md`
- **Gate-check that informed this sprint plan**: `production/gate-checks/pre-prod-to-prod-2026-05-06.md` (CONCERNS verdict 3rd consecutive; sole gates = S7-11 + S8-15 USER-OWNED → S10-15 + S10-16)
- **Architecture-review delta #15 report** (most recent): `docs/architecture/architecture-review-2026-05-06.md` (PASS — 0 BLOCKING + 0 ADVISORY; ADR-0020 Accepted)
- **Governing ADRs (Accepted)**: ADR-0001..0020 (20 ADRs); battle-hud governed by ADR-0015 (Accepted 2026-05-03); scenario-progression governed by ADR-0017 (Accepted 2026-05-04); ADR-0018 (destiny-branch) referenced by ADR-0017 Accepted 2026-05-04
- **Governing GDDs**: `design/ux/battle-hud.md` v1.1 (744 lines — UX spec) + `design/gdd/scenario-progression.md` rev 2.2 + `design/gdd/destiny-branch.md` rev 1.3.2 + `design/gdd/save-load.md` (NEW rev 1.0 from S8-08 — sprint-10 S10-08 verifies impl gap) + `design/gdd/game-concept.md` (Pillars 1-4)
- **Governing art-bible sections**: `design/art/art-bible.md` §4.7 reserved_color_treatment + §5 Character Design Direction (S10-09 first 3 character profile stubs target)
- **Control manifest**: `docs/architecture/control-manifest.md` v2026-05-05 + Pillar 2 Architectural Locks section (codifies 6 invocations stable; battle-hud story-005 invokes 2nd-precedent at action menu)
- **Tech debt register active items**: `docs/tech-debt-register.md` TD-063..TD-070 (sprint-8/9 surfaced; sprint-10 closes TD-067 candidate via S10-05 if budget allows; TD-068/069/070 are Polish-tier forward-commitments; TD-063 carries to grid-battle epic)
- **Engine gotchas codified**: `.claude/rules/godot-4x-gotchas.md` G-1..G-29 (G-29 codified at sprint-9 retro 2026-05-07) + `.claude/rules/tooling-gotchas.md` TG-1..TG-3 (TG-3 codified at sprint-9 retro 2026-05-07)
- **Prior sprints**: `production/sprints/sprint-{1,2,3,4,5,6,7,8,9}.md`
- **Chapter-prototype**: `prototypes/chapter-prototype/` (chapter.gd + battle_v2.gd + REPORT.md PROVISIONAL PROCEED — S10-15 user-attestation gate target)
- **Battle-hud epic**: `production/epics/battle-hud/EPIC.md` + 8 stories authored (story-001..story-008); 3/8 Complete (sprint-6 S6-05/S6-06/S6-09); sprint-10 ships stories 4-8 closing 8/8
- **Scenario-progression epic**: `production/epics/scenario-progression/EPIC.md` + 1 story authored (story-001 single coordinated patch); sprint-10 ships epic-terminal 1/1
- **Save-manager Platform epic** (already 8/8 Complete): `production/epics/save-manager/EPIC.md` (sprint-10 S10-08 verifies whether Save/Load #17 GDD requires NEW Core epic OR ratifies existing)

> **Scope check**: Sprint-10 stories all derive from sprint-9 retrospective action items + battle-hud epic in-flight closure + scenario-progression Core epic ship from previously-deferred Migration Plan + sprint-9 carryover absorption per retro AI #4. Run `/scope-check battle-hud` after S10-03 if cumulative battle-hud 4-8 scope diverges from ADR-0015 ratchet ~2.0d budget.

> **Pre-flight check applied** (sprint-7 retro improvement #1, now 4-sprint-stable discipline): S10-01..S10-05 verified — all battle-hud stories 004-008 are Status: [ ] Not yet created in their respective story files (not blocking; sprint-6 used same pattern); S10-06 verified — scenario-progression story-001 Status: [ ] Not yet created (also non-blocking per epic-terminal coordinated patch precedent); ADR-0015 + ADR-0017 + ADR-0018 all Accepted; battle-hud story-001/002/003 already shipped (sprint-6) provide DI scaffolding + 11 GameBus subscriptions + Pillar 2 lint enforcement foundation; ScenarioRunner autoload position 6 reserved per ADR-0017; mock encoder still ships at sprint-6 inline form (S10-06 deletes it).

> **No Sprint-Level QA Plan Yet** — see Phase 5 follow-up. Per project pattern (locked sprint-2 Phase 5), QA discipline is per-epic. Sprint-10 implementation stories require:
> - **battle-hud epic** (CLOSURE): existing `production/qa/qa-plan-battle-hud-2026-05-03.md` already authored; sprint-10 stories 4-8 absorbed under existing plan. Promote to sprint-level QA plan if integration test count target >40 cases lands at S10-05 epic-terminal.
> - **scenario-progression Core epic** (NEW): `/qa-plan scenario-progression` should be authored Should-Have AFTER S10-06 if epic-terminal close lands; cross-reference with existing damage-calc/grid-battle/turn-order epic patterns for QA-plan structure.
> - **save-load Core epic** (NEW if S10-08 creates): `/qa-plan save-load` should be authored Should-Have AFTER S10-08 if epic creation lands.

> **Reminder**: re-run `/gate-check pre-production` AFTER S10-15 + S10-16 user attestation captured (any time during sprint-10). Expected verdict upgrade: CONCERNS → PASS + `production/stage.txt` written = "Production". This sprint's secondary success criterion IS the gate-check upgrade (primary success criterion is the battle-hud + scenario-progression dual-epic closure).
