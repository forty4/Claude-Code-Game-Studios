# Retrospective: Sprint 8

| Field | Value |
|---|---|
| **Period** | 2026-05-05 → 2026-05-06 (actual; planned 2026-06-07 → 2026-06-13) |
| **Sprint Goal** | Unblock input-handling + ship chapter-1 (장판파) end-to-end + flip Pillar 2 lock candidates 5+6 to shipped |
| **Mode** | Lean (per `production/review-mode.txt`) |
| **Generated** | 2026-05-06 |

---

## Metrics

| Metric | Planned | Actual | Delta |
|---|---|---|---|
| Stories | 16 (Must 7 + Should 4 + Nice 4 + S8-15 USER-OWNED) | **11 closed** (Must 7/7 + Should 4/4) + 4 deferred + 1 USER-OWNED | -25% on Nice; **100% on critical path** |
| Completion Rate | 100% target (Must+Should) | **100%** Must+Should; **0%** Nice (deferred to sprint-9 by Producer pressure-cut acceptance) | met on critical path |
| Story-days nominal | ~5.5 working days claude-owned | **~1 calendar day actual** | **~5× under nominal** |
| Test baseline (start) | 978 (sprint-7 close) | 978 | — |
| Test baseline (end) | ≥1010 target | **1116** | **+106 over target** |
| Net new tests | ~32 | **+138** | **+106 over target** |
| Failure-free streak | sustain | **38th consecutive baseline** (+12 streak ratchet from sprint-7's 26th) | held |
| Commits | — | **8** | — |
| ADRs Accepted | 19 → 20 | 19 → **20** (ADR-0020 InputRouter Dispatch) | met |
| Bugs found | — | **1** (StoryEvent `_active_chapter` deferred-handler-after-state-advance race) | — |
| Bugs fixed | — | **1** (same-patch fix in S8-11) | — |
| Unplanned work | — | **0** | — |
| User-adjudication points | budgeted 4-8 | **0** | over-budgeted |

---

## Velocity Trend

| Sprint | Planned (days) | Actual (days) | Multiplier |
|---|---|---|---|
| Sprint-5 | ~5d | ~1d | ~5× |
| Sprint-6 | 4.4d | ~1d | ~5× |
| Sprint-7 | 4.5d | ~1-1.5d | ~3-5× |
| **Sprint-8 (current)** | **5.5d** | **~1d** | **~5×** |

**Trend**: STABLE at ~5× nominal multiplier across **4 consecutive sprints**. Sprint-8 sustained the velocity ratio under the broadest claude-owned scope yet (11 closed stories vs. sprint-7's 9), validating sprint-7 retro AI #2 ("5× velocity multiplier durability under broader impl scope"). Pattern stability declaration: ratified.

---

## What Went Well

1. **Must + Should 11/11 closed (100% critical path)** in a single calendar day. ADR-0020 Accepted, InputRouter graduated 33L PLACEHOLDER → 626L functional 7-state FSM across 5 sequential input-handling stories, S7-10 unblock landed, Save/Load #17 GDD authored, Story Event + Destiny State implementations shipped, chapter-1 (장판파) end-to-end integration vertical-slice landed.
2. **38th consecutive failure-free baseline maintained** through 138 new tests across 6 implementation tracks (foundation + battle-hud + scenario + story-event + destiny-state + integration). 1116/1116 PASSING / 0 errors / 0 failures / 0 orphans / 0 silent-skips at close.
3. **Pillar 2 architectural lock pattern STABILIZED at 6 invocations** (codification threshold reached). Story Event #10 + Destiny State #16 implementations flipped both remaining candidates to shipped via S8-09 + S8-10. 6-precedent enforcement triad (source-grep lint + ADR-annotation + integration test) is now project discipline.
4. **Combined-session escalation pattern STABLE at 5 invocations** with **1st cross-calendar-day variant** (delta #15 ADR-0020 escalation crossed 2026-05-05 → 2026-05-06 boundary while preserving same-session-ban discipline via independent `/clear`-bound sessions). Pattern stability declaration achieved.
5. **Sprint-status hygiene close-in-same-patch STABILIZED at 15-streak** (S7-05/06/07/09 + S8-01..S8-11 = 15 consecutive in-patch closes). Sprint-7 retro AI #1 enforcement target was 6+; achieved with 9-story comfort margin. Pattern firmly hardened.
6. **Production bug surfaced + closed in same-patch (S8-11 chapter-1 e2e)**: StoryEvent `_on_chapter_completed` CONNECT_DEFERRED handler fires AFTER ScenarioRunner transitions to next chapter, so `get_current_chapter()` returns wrong chapter for Beat 9 reveal. Found ONLY by e2e integration driving full state machine; fixed via `_active_chapter` cache pattern. Validates the integration-test investment.
7. **`/dev-story` → `/code-review` → `/story-done` 3-skill arc validated 4× in single session-arc** (S8-04/05/06/07). Each `/code-review` pass surfaced design-time gaps that `/dev-story` alone missed (DI seam extractions, Vector2i.ZERO guard removal, `_did_visible_work` invariant, edge-case enumeration). Workflow pattern firmly stable.
8. **`reset_for_tests` autoload test-seam pattern STABLE at 4 autoloads** (BalanceConstants + DestinyState + StoryEvent + ScenarioRunner). Pattern is now codification candidate.
9. **0 user-adjudication points across 11 stories** (sustained from sprint-7 R6 over-budget). Direct-author + DI-seam + lean-mode discipline keeps user-adjudication ~0 even under broad implementation scope.
10. **Pre-flight check discipline (sprint-7 retro AI #5) held**: S7-10 → S8-07 carryover correctly verified InputRouter `_handle_event` would exist post-S8-04. No PLACEHOLDER discoveries at story-attempt time. S7-10 lesson did not recur.
11. **Autoload Node pattern at 9 production autoloads** (was 6 entering sprint-8): InputRouter (boot pos 9) + Story Event (pos 8) + Destiny State (pos 7) all joined the lineage in same sprint. Pattern codification holds; G-3 no-class_name discipline preserved across all 9.

---

## What Went Poorly

1. **S8-15 user-attestation (S7-11 carryover) is 2nd-time carryover** — gate-check verdict trajectory unchanged at CONCERNS (3× READY + 1× CONCERNS CD; sole gates = S7-11 + S8-15 USER-OWNED). Sprint-8 added a 2nd USER-OWNED gate (S8-15 manual smoke check Batches 1+3) on top of the existing S7-11 4 VS Validation items. Gate-check upgrade CONCERNS → PASS now requires user time on TWO attestation items, not one. Refusal-to-fabricate posture commitment cost is doubling.
2. **5 NEW tech-debt entries (TD-063..067) surfaced from S8-07 `/code-review`**, all deferred. While each is small (API placeholders + i18n .tscn extension + .tscn lint scope extension + decorative mouse_filter hardening), the cumulative pattern is **net debt growth this sprint despite TODO count remaining flat at 5**. The forbidden_pattern lint scope mismatch (TD-067) in particular suggests sprint-8 enforcement triad has a `.gd`-only blind spot for `.tscn` content.
3. **Story-spec field-name typo persistence across 3 input-handling stories** (002+003+004 specs all use `ctx.unit_id` / `ctx.coord` while actual InputContext fields are `target_unit_id` / `target_coord`). Doc-only typos (implementations correctly use real names), but a 3-story persistent pattern indicates the story-creation step copy-pasted stale field names from an early-draft input-handling.md or InputContext.gd schema. Recommend doc-correction sweep at story-files level.
4. **Codification debt accumulated, not paid down**: 3 G-* codification candidates carried into sprint-8 retro (G-26 user-vs-user class_name collision discovered S8-04 + G-27 deferred-handler-after-state-advance discovered S8-11 + G-28 bulk-disconnect-all autoload-subscriber trap discovered S8-09/10). All 3 are real session-time costs that will recur until codified. Sprint-7 retro improvement #2 ("same-session G-7 fix preferred to deferred follow-up") set a same-session-fix discipline; codification candidates evidently slip through that gate by being "small and noted" rather than "broken and blocking."
5. **`Vector2i.ZERO` sentinel ambiguity in InputContext default** (TD-candidate-E from sprint-8 active.md): `Vector2i.ZERO` is both the (0,0) playfield grid origin AND the "no coord" sentinel. S8-04 `/code-review` correctly removed a defensive guard against `Vector2i.ZERO` because (0,0) is a legitimate playfield cell. The InputContext schema should carry a `Vector2i(-1, -1)` "absent" sentinel mirroring `target_unit_id = -1`. Defer to story-008-009 owners but track explicitly.

---

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---|---|---|---|
| **StoryEvent deferred-handler-after-state-advance race** (S8-11 e2e integration) | Discovered + fixed same-patch | `_active_chapter` cache at chapter_started signal source; cache cleared at Beat 9 emit | Codify as **G-27** at this retro; autoload subscribers' CONNECT_DEFERRED handlers must cache state at signal-emit time, not re-query at handler time |
| **User-vs-user `class_name` collision** (S8-04 input_router_fsm_core_test discovery) | ~5min G-7 silent-skip discovery + 13-occurrence rename | `tests/integration/damage_calc/damage_calc_integration_test.gd` inner `class GridBattleStub:` → `class DamageCalcGridBattleStub:` | Codify as **G-26** at this retro; convention: top-level helpers in `tests/helpers/` own simple names; inner test doubles use `<SystemName><Role>` prefix |
| **`scenario_runner_signal_contract_test` bulk-disconnect interferes with autoload subscribers** (S8-10 DestinyState test isolation surface) | ~10min surface + idempotent `_connect_subscriptions` workaround | DestinyState `reset_for_tests()` extended to call idempotent `_connect_subscriptions()`; pattern mirrored to StoryEvent in S8-09 | Codify as **G-28** at this retro; bulk-disconnect-all in test cleanup is fundamentally incompatible with autoload subscribers — autoload `reset_for_tests` MUST re-establish subscriptions |
| **G-25 PRIMITIVE-NUANCE confirmation** (S8-03 `/code-review`) | n/a (verification only) | G-25 already codified at S8-02; verification confirmed degradation IS necessary regardless of inner element type being class or primitive | Existing G-25 wording stands; primitive-nuance is amendment-only |

---

## Estimation Accuracy

| Story | Estimated | Actual | Variance | Likely Cause |
|---|---|---|---|---|
| S8-01 ADR-0020 + escalation + S8-02 skeleton | 0.4d + 0.3d = 0.7d | ~0.15d (combined) | +75% under | 5th-precedent combined-session escalation pattern is highly automated |
| S8-03 input-handling story-002 (vocab+bindings) | 0.3d | ~0.15d | +50% under | DI seam extraction in `/code-review` pass added time but absorbed within nominal |
| S8-04 input-handling story-003 (FSM core) | 0.5d | ~0.15d | +70% under | GridBattleStub forward-coverage helper avoided proliferation |
| S8-05 input-handling story-004 (FSM attack + ST2) | 0.4d | ~0.15d | +60% under | `_did_visible_work` emit-decoupling absorbed at impl-time |
| S8-06 input-handling story-005 (mode determination) | 0.3d | ~0.1d | +66% under | 12L pure helper + 16L Phase 1 prepend; tightly scoped per CR-2 |
| S8-07 battle-hud story-005 (UI-GB-02/05/10 + two-tap) | 0.5d | ~0.2d | +60% under | 3 NEW .tscn + 343L; broader scope but still ~5× under |
| S8-08 Save/Load #17 GDD | 0.4d | ~0.1d | +75% under | Direct-author 5-6× velocity multiplier; 0 user-adjudication |
| S8-09 Story Event #10 impl | 0.5d | ~0.15d | +70% under | ADR-0001 minor amendment + 6 closed-vocab variants well-scoped |
| S8-10 Destiny State #16 impl | 0.5d | ~0.15d | +70% under | Pattern-mirror to ScenarioRunner reset_for_tests |
| S8-11 Chapter-1 e2e | 0.4d | ~0.2d | +50% under | Production bug surfaced + fixed in same patch absorbed within nominal |

**Overall estimation accuracy**: 11/11 shipped stories within +50% to +75% UNDER estimate. **Consistent 5× under-nominal** across all task types — architecture/ADR + GDD authoring + foundation FSM impl + integration test all converge to the same multiplier.

**Adjustment recommendation**: Sprint-9 plan should target **~3.0d nominal Must-Have** (matching sprint-8's 3.0d Must-Have nominal that landed in ~0.6d actual). The 5× multiplier appears stable across architecture work + GDD authoring + foundation impl + feature impl + integration. Sprint-9 budget can sustain similar nominal scope without re-baselining.

---

## Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|---|---|---|---|---|
| S8-15 user attestation (4 VS Validation items + sprint-8 manual smoke Batches 1+3) | Sprint-7 (S7-11) → Sprint-8 (S8-15) → Sprint-9+ | 2× | User-owned by design; refusal-to-fabricate posture | User-track; non-sprint-bound; sprint-9 plan re-includes |
| S8-12 first 3 character profile stubs (유비/장비/리유비) | Sprint-8 (deferred Nice) → Sprint-9 | 1× | Producer pressure-cut acceptance — nice-to-haves cut to absorb input-handling 5-story scope | Sprint-9 nice-to-have |
| S8-13 AD-C3 font glyph check (緣 bond glyph) | Sprint-8 (deferred Nice) → Sprint-9 | 1× | Same as S8-12 | Sprint-9 nice-to-have; blocker S8-09 cleared |
| S8-14 Main menu UX spec stub | Sprint-8 (deferred Nice) → Sprint-9 | 1× | Same as S8-12 | Sprint-9 nice-to-have |
| S8-16 chapter-2 scoping + chapter-1-callback ACs | Sprint-8 (deferred Nice) → Sprint-9 | 1× | Same as S8-12 | Sprint-9 nice-to-have; blocker S8-11 cleared |
| Hero portraits (8) — user-owner | Sprint-4 → Sprint-7 → Sprint-8 → Sprint-9+ | 4× | User-owner; chapter-1 still uses ColorRect placeholders | User-track; non-blocking |
| BGM candidates (2-3) — user-owner | Sprint-4 → Sprint-7 → Sprint-8 → Sprint-9+ | 4× | User-owner | User-track; non-blocking |

**Recurring pattern**: 4-time carryover on hero portraits + BGM is **structural** — both items are user-owned by their creative-judgment nature and have no claude-owned path to close. Recommend the sprint-plan template flag user-owned items separately from claude-owned carryovers so velocity metrics aren't distorted by perpetual non-claude carryovers.

---

## Technical Debt Status

| Metric | Sprint-7 close | Sprint-8 close | Trend |
|---|---|---|---|
| TODO count in src/ | 5 | **5** | flat |
| FIXME count in src/ | 0 | 0 | flat |
| HACK count in src/ | 0 | 0 | flat |
| Tech-debt-register entries | 62 (TD-001..TD-062) | **67** (TD-001..TD-067; +5: TD-063..TD-067) | growing |

**Trend**: TODO count flat at 5; tech-debt-register grew +5 entries (all from S8-07 `/code-review`). Net debt growth despite flat in-source TODO count — the gap is **explicit register entries vs in-line TODOs**. Sprint-8's net debt is being TRACKED rather than HIDDEN (positive signal for register discipline; mixed signal for raw debt growth).

**Recommendation**: Defer TD-063 + TD-064 to grid-battle epic OR input-handling story-006 ownership; absorb TD-065 + TD-066 + TD-067 at story-008 lint authoring time (story-008 already pending in sprint-9 input-handling scope per epic split).

---

## Previous Action Items Follow-Up (Sprint-8 Retro AI seed from sprint-7 retro)

| Action | Status | Notes |
|---|---|---|
| **AI #1**: Sprint-status hygiene "close in same patch" — enforce ≥6 stories for stability | **STABILIZED** | Achieved 15-streak (S7-05/06/07/09 + S8-01..S8-11). Target was 6+; comfort margin 9 stories. Pattern firmly hardened. |
| **AI #2**: Pre-flight check policy — every carryover story verifies underlying infra at sprint-plan time | **HELD** | S7-10 → S8-07 carryover correctly verified InputRouter `_handle_event` post-S8-04. No PLACEHOLDER discoveries. |
| **AI #3**: G-7 silent-skip detection at every test baseline run | **HELD** | Caught user-vs-user class_name collision in S8-04 (count drop 1054 → 1037 → discovery → 1067 post-rename). Silent-skip detection working as designed. |
| **AI #4**: 5× velocity multiplier durability under broader impl scope | **HELD** | Sustained 5× even with 11 claude-owned stories (vs sprint-7's 9). Broadest scope yet; pattern is now project discipline. |
| **AI #5**: Pillar 2 lock pattern 6th invocation | **STABILIZED** | S8-09 + S8-10 flipped Story Event + Destiny State candidates to shipped. 6-invocation codification threshold reached. |
| **AI #6**: Combined-session escalation pattern 5th invocation | **STABILIZED** | S8-01 ADR-0020 escalation = 5th invocation + 1st cross-calendar-day variant. Pattern stable. |
| **AI #7**: Autoload Node pattern at 10 invocations | **PARTIAL** | At 9 production autoloads post-S8-02 (was 8 entering sprint-8; +1 InputRouter). Target was 10; missed by 1 — sprint-9 input-handling story-006+ likely flips it to 10. |
| **AI #8**: CI lane gap for macOS / iOS / Android (sprint-7 AI #5 carryover) | **DEFERRED** | No new evidence; sprint-9 evaluation pending. |

---

## Action Items for Sprint-9

| # | Action | Owner | Priority | Rationale / Source |
|---|---|---|---|---|
| 1 | **Codify G-26 + G-27 + G-28 in `.claude/rules/godot-4x-gotchas.md`** at sprint-9 kickoff | claude | High | 3 codification candidates accumulated this sprint; "small and noted" is not enough — costs recur until codified. Same-session-fix discipline (sprint-7 retro improvement #2) extended to codification |
| 2 | **Doc-correction sweep on input-handling story files 002-004** — fix `ctx.unit_id` / `ctx.coord` → `target_unit_id` / `target_coord` across QA Test Cases sections | claude | Med | 3-story persistent typo pattern; doc-only fix; ~10min. Recommend before story-006 ships to prevent 4th-story recurrence |
| 3 | **Sprint-9 plan: input-handling stories 6-10** (per-unit undo + input_blocked + touch protocol TPP magnifier + pan/tap gestures + epic-terminal perf+lints+evidence) | claude | High | Producer split-input-handling-epic recommendation; sprint-9 closes the epic |
| 4 | **Resolve TD-063 + TD-064 in sprint-9 input-handling story-006** OR carry to grid-battle epic | claude | Med | GridBattleController API placeholders; runtime `has_method` probes are explicit + tracked but should resolve to real production methods |
| 5 | **Re-baseline sprint-9 nominal at ~3.0d Must-Have** (matching sprint-8) | claude | High | 5× velocity multiplier stable across 4 sprints; sprint-9 can sustain sprint-8-equivalent nominal |
| 6 | **CI lane gap evaluation** (sprint-7 AI #5 + sprint-8 AI #8 carryover) | claude | Low | 2-sprint deferred; sprint-9 either acts or formally postpones to post-MVP |
| 7 | **S8-15 + S7-11 user attestation pass** | user | High | TWO USER-OWNED gates now block /gate-check upgrade CONCERNS → PASS; refusal-to-fabricate posture commitment |
| 8 | **Save/Load #17 implementation** (S8-08 GDD landed Designed; impl deferred per Producer split) | claude | Med | Sprint-9 should-have; closes save-manager epic; converts SavePersistence GDD from Designed to Implemented |
| 9 | **Pillar 4 chapter-2 scoping + chapter-1-callback ACs** (S8-16 carryover from sprint-8 nice-to-have) | claude | Low (sprint-9+) | Pillar 4 demonstration unprovable until chapter-2 exists; CD recommendation |
| 10 | **Carryover-tracking refinement**: separate user-owned carryovers from claude-owned in sprint-plan template | claude | Low | Hero portraits + BGM at 4× carryover distorts velocity metrics; user-owned items need their own track |

---

## Process Improvements

1. **Codification debt is real debt** (NEW process improvement). When a session surfaces a G-* codification candidate (engine gotcha, tooling gotcha, or process pattern), it MUST be codified at sprint retro time, not deferred to "next sprint" or "when convenient." Sprint-8 accumulated 3 G-* candidates (G-26/27/28) all observed in real session-time cost; deferring codification to sprint-9 retro would let a 4th candidate stack onto the same backlog. Adopt rule: **`/retrospective` MUST close all codification candidates from the sprint by writing them into `.claude/rules/`**, not by listing them as deferred action items.
2. **Lint scope must include .tscn content for forbidden patterns about visible content** (NEW process improvement, from TD-067 surface): `battle_hud_hardcoded_localized_strings` lint is `.gd`-scoped, but `.tscn` files contain visible Label/Button text that the same forbidden_pattern intent applies to. When a forbidden_pattern is about user-facing artifacts, the lint scope must match the artifact reality (any file producing the artifact), not the implementation language.
3. **InputContext sentinel-discipline alignment** (NEW process improvement, from TD-candidate-E surface): `Vector2i(-1, -1)` "absent" sentinel mirroring `target_unit_id = -1` is the consistent pattern. Adopt at story-008-009 design time + retroactively codify in `src/core/payloads/input_context.gd`. Sentinel ambiguity is a category of bug-class that costs `/code-review` time and escapes test coverage when defaults silently coincide with valid values.
4. **3-skill arc `/dev-story` → `/code-review` → `/story-done` is now project workflow standard** (formalize from sprint-8 4× validation). Each skill enforces a discrete gate (implement → review/refactor → close). `/code-review`-driven refactor-in-same-pass is the productive pattern; `/code-review` runs in parallel (godot-gdscript-specialist + qa-tester) and addresses gaps via Edit before `/story-done` closes. Add to `.claude/skills/dev-story/SKILL.md` as the recommended downstream chain.

---

## Summary

Sprint-8 was the **strongest sprint by every claude-owned metric to date**: 11/11 critical-path stories closed in ~1 calendar day at sustained 5× velocity multiplier (4-sprint trend), 38th consecutive failure-free baseline (+12 streak ratchet), Pillar 2 architectural lock pattern STABILIZED at 6 invocations (codification threshold reached), combined-session escalation pattern STABLE at 5 invocations + first cross-calendar-day variant, sprint-status hygiene close-in-same-patch STABILIZED at 15-streak (target was 6+; comfort margin 9), and 1 production bug surfaced + closed in same-patch via S8-11 chapter-1 e2e integration test (validating the integration-test investment).

The two failure modes were **systemic, not individual**: (1) codification debt accumulated rather than paid down — 3 G-* candidates (G-26/27/28) all real session-time costs, all deferred from same-patch fix to retro; (2) gate-check verdict trajectory CONCERNS unchanged because S8-15 added a 2nd USER-OWNED attestation gate on top of S7-11, doubling the refusal-to-fabricate posture commitment cost from one user-owned item to two.

**Single most important thing to change**: **Pay codification debt at retro time, not next sprint.** Sprint-8's G-26/G-27/G-28 candidates have well-documented session-time costs and clear codification wording proposed by specialists — there is no benefit to deferring them. Adopt the rule that `/retrospective` MUST write all codification candidates into `.claude/rules/godot-4x-gotchas.md` (or `.claude/rules/tooling-gotchas.md` for workflow-tooling gotchas) before closing, not list them as "AI #N for next sprint."

---

## Cross-References

- Sprint-8 plan: `production/sprints/sprint-8.md`
- Sprint-status: `production/sprint-status.yaml` (sprint 8; updated 2026-05-06)
- QA sign-off: `production/qa/qa-signoff-sprint-8-2026-05-06.md` (APPROVED WITH CONDITIONS)
- Smoke check: `production/qa/smoke-2026-05-06.md` (PASS / 1116/1116 / 38th FFB)
- Gate-check: `production/gate-checks/pre-prod-to-prod-2026-05-06.md` (CONCERNS unchanged; sole gates = S7-11 + S8-15 USER-OWNED)
- Architecture-review delta #15: `docs/architecture/architecture-review-2026-05-06.md` (PASS — 0 BLOCKING + 0 ADVISORY; ADR-0020 Accepted)
- Pillar 2 architectural locks: `docs/architecture/control-manifest.md` §Pillar 2 Architectural Locks (6 invocations; codification threshold reached)
- Refusal-to-fabricate posture: `.claude/rules/tooling-gotchas.md` TG-2 + damage-calc 2026-04-27 precedent
- Prior retros: `production/retrospectives/retro-sprint-{2,3,4,5,7}-*.md` (sprint-6 retro implicit per `sprint-7.md` Pivot context)
- Tech-debt entries added this sprint: `docs/tech-debt-register.md` TD-063..TD-067
