# Systems Index: 천명역전 (Defying Destiny)

> **Status**: Approved
> **Created**: 2026-04-16
> **Last Updated**: 2026-04-20 (formation-bonus.md row 3 — **/design-review pass-1 NEEDS REVISION**. 5-spec adversarial review returned 10+ blockers (3 convergent: `grid.get_unit_at()` fabricated, `set_formation_bonuses()` not formal CR, AC-FB-04 stale). Status: Designed (v1.0 pre-design-review) → **NEEDS REVISION**. Per CD precedent (Grid Battle pass-1=16; Scenario v1.0=30 → STOP), pass-1 → STOP for v1.1 fresh session (~6-10h: 5 design adjudications + specialist-authored fix language + narrow re-review). Prior: damage-calc.md row 11 — **rev 2.9.1 narrow re-review close-out**. 3-spec verification (systems-designer + game-designer + qa-lead) of rev 2.9 caught 8 stale "179" sites + Player Fantasy 2.16x stale + 방진 DEF floori-visibility issue + NEW Pillar-3 inversion (Archer 179 > Cavalry 178 at simultaneous max-everything). User-ratified inversion as acceptable; applied 10 mechanical fixes; status In Review (rev 2.9) → **Designed (APPROVED post-rev-2.9.1)**. Prior: formation-bonus.md row 3 — **NEW system Formation Bonus #3 v1.0 initial draft authored** via 4 user adjudications + 2-specialist parallel drafting (game-designer narrative + systems-designer formulas/caps) + synthesizer reconciliation. Status: Not Started → **Designed (v1.0 pre-design-review)**. Cross-doc obligations applied: damage-calc.md rev 2.9 (P_MULT_COMBINED_CAP=1.31 + formation_atk/def_bonus ResolveModifiers fields), grid-battle.md Dependencies row, turn-order.md OQ-3 RESOLVED. Apex arithmetic re-verified: Cavalry+Charge+Rally(+10%)+Formation(+5%) clamps to 178 (1pt regression from rev 2.8.1=179, user-adjudicated trade-off). Pillar 1+3 preserved. /design-review pass-1 pending. Prior: damage-calc.md row 11 — **eighth-pass full /design-review COMPLETE → Designed (APPROVED) via rev 2.8 Rally-ceiling fix**. 5-specialist eighth-pass caught Pillar-1+3 regression introduced by rev 2.7; user adjudicated cap-Rally-and-reduce-Cavalry-REAR path; systems-designer derived constraint-optimized rev 2.8 (CLASS_DIRECTION_MULT[CAVALRY][REAR] 1.20→1.09 + Rally cap +15%/3 commanders → +10%/2 commanders); cross-doc atomic sweep across damage-calc + grid-battle + unit-role; all 12 apex cells <180 with Pillar-1+3 hierarchy preserved. Status: In Review → **Designed (APPROVED)**. Prior: damage-calc.md row 11 + turn-order.md row 13 — **Cross-doc downstream propagation from Grid Battle pass-11c CR-15 + ADR-0001**. Damage Calc rev 2.7: F-DC-5 `passive_multiplier` extended to accept `rally_bonus` via ResolveModifiers; counter guard preserved. Turn Order: `battle_ended` ownership migrated to Grid Battle per ADR-0001 single-owner rule; renamed to `victory_condition_detected`; 13 edits across 6 sections; status Needs Revision → **Designed**. Prior: scenario-progression.md row 6 — **v2.1 + v2.2 COMPLETE → APPROVED 2026-04-19** via 4 user design adjudications + 5-specialist parallel drafting + 7-specialist re-review + narrow 3-specialist v2.2 close-out re-review. Status: MAJOR REVISION NEEDED → **Designed (APPROVED)**. 41 ACs, 14 ECs, 16 CRs, 6 Formulas. Prior: grid-battle.md row 1 — **pass-11b + pass-11c COMPLETE → APPROVED 2026-04-19**. Pass-11b: user adjudicated B-9 (DEFEND consecutive-turn lockout) + B-10 (Commander Rally CR-15 + UI-GB-13); 5 specialists authored fix language in parallel; 12 mechanical edits applied across grid-battle.md, battle-hud.md, unit-role.md, hp-status.md, tests.yml. Full 6-specialist re-review returned 2 APPROVED + 4 CONCERNS (8 mechanical blockers, all specialist-authored — improved from pass-10 MAJOR REVISION NEEDED). Pass-11c: 8 blockers applied (godot Signal API correction, CLEANUP defended_last_turn reset + type, CR-15 rule 3 step 4 vs step 7 + F-DC-3→F-DC-5/6 cross-ref, filename collision rename to grid_battle_defend_stance_integration_test.gd, deferred-fixture count math 5→7 unique, AC-GB-27 float `==`→`is_equal_approx()`, UI-GB-13 colorblind border 1px→2px logical with WCAG 2.1 SC 1.4.11 rationale). Narrow re-review (godot-specialist + qa-lead + systems-designer + ux-designer) **all APPROVED**. Status: MAJOR REVISION NEEDED → **Designed (APPROVED)**. Prior: **pass-10 full /design-review**: verdict **MAJOR REVISION NEEDED** (6 specialists unanimous NEEDS REVISION; CD synthesis elevates on Pillar-level exposure). 11 BLOCKING + 7 Recommended. Pass-9a stretch-fix introduced arithmetic regression (AC-GB-07b case d); `acted_this_turn` volitional-vs-AI-failure invariant absent from ACs; Pillar 1 DEFEND economy + Pillar 3 Commander Rally design-level holes; AC-GB-17/24 Godot-idiom errors; GameBus autoload breaks AC-GB-25 listener-isolation. CD root-cause: review-composition problem (pass-9a/9b narrow re-reviews missed 3 specialists → blind-spot accumulation). **CD recommends [B] STOP for pass-11 fresh session**; user selected [B]. Status: In Review → **MAJOR REVISION NEEDED**. Prior: **pass-9a + pass-9a.1 + pass-9b COMPLETE**; Status: MAJOR REVISION NEEDED → **In Review** (pass-10 full /design-review optional). 28 mechanical drafting fixes + 2 pass-9a.1 file-path cleanups + 6 pass-9b design-decision applications (Q1 Pillar 3 reframe vs END_TURN; Q2 DEFEND/timeout-WAIT Ambush-bookkeeping split; Q3 DEFEND_STANCE_ATK_PENALTY scope = counter-only + speculative future; Q4 battle-length = playtest trigger). qa-lead + systems-designer + ux-designer re-reviews all PASS. Prior: **pass-8 /design-review on v5.0 draft**: verdict **MAJOR REVISION NEEDED / REJECT**. 5 specialists + CD senior synthesis; 25 BLOCKING + 12+ Recommended. CD success criterion for v5.0 ('single pillar-alignment read returns APPROVED or CONCERNS on first pass') **not met**. Convergent root-cause pattern: RC-5 (ACs) 8/10 rewritten residual-defective + 2 ratified-unchanged broken (AC-GB-07, AC-GB-07b stale BASE/DAMAGE_CEILING arithmetic, AC-GB-01 missing .tres fixture); RC-3 class identity partially resolved (Scout win; Strategist/Commander residual; NEW Infantry/Commander undifferentiated from WAIT-hiding decision); RC-4 AI plumbing 3/5 resolved + 2 new (`_init` arg Godot-incompat, timeout-WAIT flag state); design composition gaps (CR-13 rationale invisible without WAIT, DEFEND_STANCE_ATK_PENALTY doubly-inert, hardcoded Korean i18n string); RC-1 registry-drift RESOLVED in-doc (1 residual damage-calc.md CR-10 −30% stale); RC-2 cross-doc PARTIAL (new drift from v5.0). CD recommends pass-9 split: **9a drafting-only (~2h mechanical fixes)** + **9b design composition (~1h user adjudication)**. Pillar 3 structural fix (Strategist/Commander Rally upgrade) deferred to v5.1. User selected STOP for fresh session. Pass history: 1→16, 2→18, 3→15, 4→3+3, 5→8+5, 6→22+13, 7→32+17 STOP, v5.0 drafting, **pass-8 → MAJOR REVISION / REJECT**. Prior same-day earlier today: **pass-7 full-mode re-review on unrevised v4.0** — Verdict: MAJOR REVISION NEEDED → **STOP for fresh v5.0 session** per creative-director. 0 of 6 pass-6 blockers closed; 32 BLOCKING + 17 Recommended collapse to 5 root causes (RC-1 registry drift / RC-2 cross-doc contradictions / RC-3 unresolved class-identity design question / RC-4 signal plumbing gaps / RC-5 untestable ACs). 5 specialists + CD senior synthesis. Pass-6 CD recommendation ("pause targeted edits, submit v5.0 not v4.1") was not executed; pass-7 is the evidence confirming that directive. No file modifications to grid-battle.md or battle-hud.md this pass — per CD directive. Review log appended at reviews/grid-battle-review-log.md with full specialist breakdown + v5.0 minimum brief. Prior same-day: destiny-branch.md row 4 — **rev 1.3.1 APPROVED pass-10** clean-session lean re-review; 10/10 pass-10 preconditions pass; 2 Tier-2 stale-count doc-hygiene + 1 Tier-3 pseudocode breadcrumb fixed in-session; 0 blocking. Status: In Review → Designed. Prior same-day: **rev 1.3 sweep** post ninth-pass /design-review. Clean-session full-mode re-review spawned 7 specialists + creative-director senior synthesis. Verdict NEEDS REVISION (pass-9); 11 consolidated Tier-1 blockers (raw 19 from specialists → 11 after creative-director merged 3 cross-doc convergence clusters + rejected 3 over-reach items) + 9 Tier-2 resolved atomically with 4 new user design decisions. Rev 1.3 D1-D4: D1 `reduce_haptics` committed as 7th Intermediate toggle in accessibility-requirements.md §2/§7/§9 (closes game-designer B-1 + ux B-UX-9-2 + a11y B-1 convergence); D2 AC-DB-20 `error_log_capture.gd` helper locked to Godot stdout/stderr redirect + grep buffer implementation; D3 OQ-DB-10 inverted to max-miss-rate ≤10% by Ch2 end as Pillar 2 MVP-exit failure threshold (replaces rev 1.2 escalation-trigger framing); D4 OQ-DB-16 resolved SWALLOW + closed + promoted to BLOCKING VS (queue-to-fire rejected as anti-fantasy per game-designer B-3). Fixes landing rev 1.3: F-DB-1 empty-Dictionary guard (systems B-1 → `branch_table_empty` new vocabulary); assembly-time is_draw_fallback⟹DRAW cross-field invariant check (systems B-2 → `is_draw_fallback_outcome_mismatch` new vocabulary); `BattleOutcome.is_valid_result` invented-API replaced with `outcome in BattleOutcome.Result.values()` (gdscript B-1); signature alignment `outcome: BattleOutcome.Result` throughout resolve() + `%d` cast (gdscript B-2); `@abstract` annotation on `_apply_f_sp_1` base (gdscript B-3); zero-canonical-row runtime warning path in F-DB-1 step 1b (narrative B-ND-2); AC-DB-09 fallback removed (qa-lead B-2); AC-DB-20 helper stdout-redirect locked (qa-lead B-3); ADVISORY AC lifecycle — every ADVISORY AC now carries owner + gate + promotion condition (qa-lead B-1); scenario-progression §Interactions line 189 6-field lag + IP-006 UX.2 ack → new BLOCKING Bidirectional rows + pre-implementation checklist (systems B-3 + ux B-UX-9-1 + narrative B-ND-1); OQ-DB-11 closed citing sp UX.2 lines 817-819 (ux B-UX-9-3); AC-DB-39 new for affordance-onset timing sync; OQ-DB-17 new for Korean braille adequacy (a11y B-2 cross-ref fix); AC-DB-07 forbidden-pattern list extended (systems R-1); TK-DB-1 safe range bounds measurable protocol (systems R-2); V-DB-2 Korean subtitle register note (narrative N-ND-1); Story Event #10 BLOCKING constraint reframed as register constraint (narrative N-ND-3); AC-DB-24 empty-StringName fixture row + 4-fixture matrix (qa-lead R-2 + gdscript R-2 historical correction); AC-DB-31 chapter-Object-by-ref + outcome-enum immutability (qa-lead R-5); UI-DB-5 reversal-trigger (b) marked dead-end (ux R-UX-9-4); Section B Marked Hand standalone absence risk note (narrative N-ND-4); Pre-Implementation Gate Checklist added (consolidates all BLOCKING carryovers into unified go/no-go). File ~1080→~1200 lines; 40→43 ACs; 10→12 F-DB-3 invalid-reason vocabulary entries. Creative-director synthesis confirmed revise-in-session viable with 4 user design adjudications; user selected [A] in-session; all 11 blockers landed atomically across destiny-branch.md + accessibility-requirements.md (D1 toggle) + scenario-progression.md (§Interactions 6→9 field + IP-006 ack). Prior same-day: rev 1.2 sweep (eighth-pass), rev 1.1 sweep (seventh-pass). Pending tenth-pass re-review in fresh session OR approve-as-revised per user discretion.
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

천명역전은 삼국지연의 기반의 그리드 턴제 전술 RPG로, 진형/지형 기반 전투와
운명 분기 시스템이 핵심이다. 총 31개 시스템이 전투 핵심, 캐릭터/데이터,
운명/시나리오, AI, UI, 프레젠테이션, 인프라, 메타의 9개 카테고리에 걸쳐
분포한다. 코어 루프(진형 전술 → 운명 판정 → 역사 변경)를 지탱하는 14개
MVP 시스템이 가장 먼저 설계되어야 하며, 맵/그리드와 무장 데이터베이스가
가장 많은 시스템의 기반이 되는 병목(bottleneck) 시스템이다.

---

## Systems Enumeration

| # | System Name | Category | Priority | Layer | Status | Design Doc | Depends On |
|---|-------------|----------|----------|-------|--------|------------|------------|
| 1 | Grid Battle System (그리드 전투) | Gameplay | MVP | Feature | **Designed (APPROVED pass-11c 2026-04-19)** — pass-11b + pass-11c clean closure of pass-10 MAJOR REVISION NEEDED. **Pass-11b**: 2 user design adjudications (B-9 DEFEND consecutive-turn lockout via new CR-13 rule 8 + B-10 Commander Rally specified as Grid Battle CR-15 + UI-GB-13); 5 specialists (qa-lead, ai-programmer, ux-designer, game-designer, devops-engineer) authored fix language in parallel; 12 mechanical edits applied. Full 6-specialist re-review (game-designer/systems-designer/ai-programmer/ux-designer/qa-lead/godot-specialist) returned 2 APPROVED + 4 CONCERNS (8 mechanical blockers — all specialist-authored within review). **Pass-11c**: 8 blockers fixed (godot B-1 `Signal.get_connections()` non-existent → `Object.get_signal_connection_list("battle_complete")`; godot B-2 `defended_last_turn` added to CLEANUP state row with `Dictionary[int, bool]` declaration; systems B-1 CR-15 rule 3 step ref query-vs-assembly distinction made explicit (step 4 query, step 7 F-DC-5 assembly); systems B-2 F-DC-3 attack_mul reference replaced with F-DC-5 passive_multiplier + F-DC-6 stage_2_raw_damage; qa B-1 filename collision resolved by renaming Integration test to grid_battle_defend_stance_integration_test.gd; qa B-2 deferred-fixture sub-classification corrected to 24 fixture-authored + 7 deferred (added AC-GB-26 + AC-GB-27 since defend_lockout.yaml + rally_aura.yaml not yet on disk; deduped AC-GB-15 double-listing); qa B-3 AC-GB-27 sub-cases (a)(b)(c) float equality switched to `is_equal_approx()` with zero-compare exception preserved for (d)(e); ux B-1 UI-GB-13 colorblind border 1px → 2px logical with WCAG 2.1 SC 1.4.11 rationale + advisory follow-up flagged for accessibility-requirements.md contrast ratio publication). Narrow pass-11c re-review (godot + qa + systems + ux) all APPROVED. Deferred to pass-12 / implementation sprint (advisory): godot C-1 (CR-13 rule 8 clearing-handler ordering note), godot C-2 (rally_bonus_active Resource wrapper), ux R-1 (AC-UX-HUD-01 inter-yield case), ux R-2 (Section 6 Rally line ordering rationale), ux R-3 (copy "had not yet acted" → "has not yet acted"), qa R-1 (AC-GB-26 sub-case (c) AI-failure trigger mechanism in fixture description), game R-2/systems R-2 (AC-GB-26 sub-case (d) tracking-when-disabled assertion), systems R-1 (AC-GB-27 sub-case (a) integer arithmetic precision), systems R-3 (concurrent edge case unit DEFENDs then dies), F-DC-5 must be updated to accept `rally_bonus` input. **Final state**: 31 BLOCKING ACs (24 fixture-authored, 7 deferred-fixture awaiting `.tres` or new yaml authoring); 15 CR rules including new CR-15 Rally orchestration; 13 UI-GB elements including new UI-GB-13 Rally aura visual. Pillar 1 (Tactics of Momentum) holds — DEFEND lockout closes spam attractor. Pillar 3 (Every class has a role) holds + strengthened — Commander now has differentiated tactical identity via Rally. Pass history: 1→16, 2→18, 3→15, 4→3+3, 5→8+5, 6→22+13, 7→32+17 STOP, v5.0 drafting (12 decisions), 8→25+12 REJECT, 9a/9a.1/9b PASS, 10→11 BLOCKERS MAJOR REVISION NEEDED, 11a→12 mechanical fixes, 11a.1→5 specialist fixes, **11b→12 specialist-authored edits + full 6-spec re-review CONCERNS**, **11c→8 mechanical blockers fixed + narrow re-review APPROVED**. Prior: **MAJOR REVISION NEEDED** (pass-10 full /design-review 2026-04-19 — 6 specialists unanimous NEEDS REVISION; CD senior synthesis elevates to MAJOR REVISION NEEDED citing Pillar-level exposure. **11 BLOCKING** + 7 Recommended + 5 Advisory. Critical blockers: (1) pass-9a stretch-fix introduced arithmetic regression in AC-GB-07b case (d) — F-DC-3 ordering means terrain with DEF=0 is inert, so "58" is wrong; should be 83 (BASE_CEILING), CD recommends REMOVE case + replace with purpose-built clamp fixture; (2) `acted_this_turn` volitional-vs-AI-failure divergence has ZERO formal AC across 3 AI-failure branches (CR-3 timeout, CR-3a invalid, CR-3b flush) — CR-10 prose note insufficient for a Logic-type invariant (qa-lead + ai-programmer convergent); (3) F-GB-1 variable table min 5 wrong (true min 3 = ROAD×0.5); (4) AC-GB-25 listener-isolation fails vs GameBus autoload dep; (5) battle-hud.md §4.5 render-abort rule untestable in frame-discrete system; (6) DEFEND Beat-1 tap-on-valid-move-tile hidden double-action; (7) AC-GB-17 fixture line still says "constructor override parameter" contradicting pass-9a E15 corrected prose; (8) AC-GB-24 "CanvasItem first-paint" timing claim factually wrong — process_frame fires before rendering in Godot 4.6; (9) DEFEND economic model unsound — 50% reduction + no-counter + no opportunity cost is Pillar-1 flattener (game-designer design-level fix required); (10) Commander undifferentiated — Rally has no Grid Battle CR, no HUD contract (Pillar 3 unverifiable); (11) Gate Summary 29 BLOCKING not sub-classified for 6 deferred-fixture ACs. **CD root-cause**: review-composition problem, not design-maturity. Pass-9a/9a.1/9b narrow re-reviews (3 specialists) missed ai-programmer, game-designer, godot-specialist drift. Pass-10 first full-6-specialist review since v5.0 — blind-spot accumulation. **CD recommends [B] STOP for pass-11 fresh session.** User selected [B]. Pass-11 hard rule: no synthesizer fixture edits without re-spawning originating specialist. Scope signal: L. Prior: **In Review** (pass-9a + pass-9a.1 + pass-9b COMPLETE 2026-04-19; 28 mechanical drafting fixes + 2 pass-9a.1 file-path cleanups + 6 pass-9b design-decision applications (Q1 rewrite Pillar 3 vs END_TURN, Q2 DEFEND=T/timeout-WAIT=T Ambush-bookkeeping, Q3 DEFEND_STANCE_ATK_PENALTY scope documented as counter-only + speculative future, Q4 battle-length deferred to playtest trigger). Specialist re-reviews: qa-lead PASS (0 residual post-9a.1), systems-designer PASS (4/4 formula guards), ux-designer PASS (7/7 cross-doc drift CLOSED). Known carryovers to next full review pass: hp-status.md line 175 "ATK -40% (trade-off)" phrasing may now drift vs v5.0 Q3 "inert" framing (minor; not addressed per user [A] choice); AC-GB-25 implementation-sprint follow-up to assert volitional-vs-failure `acted_this_turn` divergence. Pass-10 full /design-review optional. Deferred to v5.1: Pillar 3 Strategist/Commander Rally upgrade, TacticalRead two-facet rename, full fixture authoring (AC-GB-15 / test_map_2x2.tres / test_map_softlock_5unit.tres), `.github/workflows/perf-nightly.yml`, gamepad input spec, `design/ux/settings.md`. Prior: **MAJOR REVISION NEEDED** (pass-8 2026-04-19 — /design-review on v5.0 draft returned **REJECT**. 5 adversarial specialists (game-designer, systems-designer, ai-programmer, ux-designer, qa-lead) + creative-director senior synthesis. 25 BLOCKING + 12+ Recommended. qa-lead severity **MAJOR REVISION NEEDED** (8 of 10 rewritten ACs residual-defective; 2 ratified-unchanged broken: AC-GB-07 stale F-GB-PROV, AC-GB-07b stale BASE_CEILING=100/DAMAGE_CEILING=150 arithmetic, AC-GB-01 missing .tres fixture); 4 other specialists NEEDS REVISION. CD sided with qa-lead severity — RC-5 (ACs) was pass-7's explicit rewrite target and 80% remain defective. CD success criterion for v5.0 ('APPROVED or CONCERNS on first pass') **not met**. Root cause MIXED: pure drafting defects (RC-5 ACs, AC-GB-07b arithmetic, damage-calc.md CR-10 stale −30%, missing fixture files, `.github/workflows/perf-nightly.yml` missing) + design composition gaps (WAIT-DEFEND-acted_this_turn interaction makes CR-13 rationale invisible for Infantry/Commander since WAIT is hidden; `acted_this_turn=true` on DEFEND removes "bait Ambush by DEFENDing" loop undocumented; `DEFEND_STANCE_ATK_PENALTY` doubly-inert under CR-13 rule 4 + damage-calc CR-5 gate; timeout-substituted WAIT `acted_this_turn=false` creates AI exploitation vector; hardcoded Korean reason string has no i18n contract). RC-1 registry-drift resolved in-doc; RC-2 cross-doc PARTIAL (1 residual damage-calc.md CR-10); RC-3 class identity PARTIAL (Scout win; Strategist/Commander overlap residual; NEW Infantry/Commander overlap from WAIT-hiding); RC-4 AI plumbing 3/5 resolved + 2 new ("drop signals" mechanism still unspecified, `Timer.start(0)` footgun no guard, `_init()` arg Godot-incompat). Pillar 1 CONCERNS (battle-length impact from 50% DEFEND + no-WAIT unanalysed); Pillar 3 VIOLATED-but-improved. **CD recommends pass-9 split**: 9a drafting-only (~2h mechanical fixes; no design judgment) + 9b design composition (~1h AskUserQuestion adjudication of 3 design gaps). Pillar 3 structural fix (Strategist/Commander Rally upgrade) deferred to v5.1. User selected **STOP** for fresh session per CD recommendation. Pass history: 1→16, 2→18, 3→15, 4→3+3, 5→8+5, 6→22+13, 7→32+17 STOP, v5.0 drafting applied 12 decisions, **pass-8 → 25 BLOCKING REJECT**. Full review in `design/gdd/reviews/grid-battle-review-log.md` pass-8 entry. | design/gdd/grid-battle.md + design/ux/battle-hud.md | Map/Grid, Terrain, Unit Roles, HP/Status, Turn Order, Input, Damage Calc |
| 2 | Terrain Effect System (지형 효과) | Gameplay | MVP | Core | Designed | design/gdd/terrain-effect.md | Map/Grid |
| 3 | Formation Bonus System (진형 보너스) | Gameplay | MVP | Feature | **NEEDS REVISION (pass-1 /design-review 2026-04-20 — 10+ blockers, 3 convergent)**. 5-spec adversarial review (game-designer + systems-designer + ux-designer + qa-lead + godot-specialist) returned: 1 CONCERNS + 1 CONCERNS + 1 NEEDS REVISION + 1 NEEDS REVISION + 1 CONCERNS. Convergent BLOCKERS: (1) `grid.get_unit_at()` fabricated API (Map/Grid only has `get_adjacent_units`) — convergent systems+godot; (2) `set_formation_bonuses()` not formal CR in grid-battle.md — convergent systems+godot; (3) AC-FB-04 stale 0.02 (should be 0.04 per rev 2.9.1) — convergent game+systems. Specialist-unique BLOCKERS: F-FB-2 asymmetric record miss bug (systems); 6 EC coverage gaps (qa); formation_def_bonus consumer-side AC unattested cross-doc (qa); sub-apex formation_atk_bonus path unattested (qa); 4 UX/WCAG gaps incl forecast Passives line contract + pattern viz + bond icon + R-2 tile-info text alt (ux); PatternDef/BonusVal type gap (godot); Vignette 1 honesty at Cavalry+Rally apex (game). Per CD precedent (Grid Battle pass-1=16; Scenario v1.0=30 both → STOP for fresh session), Formation Bonus pass-1 → STOP for v1.1 fresh session. Cross-doc obligations to apply in v1.1: grid-battle.md new CR (set_formation_bonuses signature + CR-5 step 4 read path), battle-hud.md UI-GB-14 + UI-GB-04 §4.1 §6 + R-2 extension, map-grid.md adjudication on get_unit_at. Estimated v1.1 scope: M leaning L (~6-10h via specialist-authored fixes + 5 design adjudications + narrow re-review). See `design/gdd/reviews/formation-bonus-review-log.md` pass-1 entry. Prior status: Designed (v1.0 initial draft 2026-04-19; pre-`/design-review`) — 4 user-adjudicated design decisions (Pattern+Relationship hybrid scope; additive ResolveModifiers field application; round_started-only recalc; 4 patterns 어진형/학익진/마름진/방진 + 4 relationships SWORN_BROTHER/LORD_VASSAL/RIVAL/MENTOR_STUDENT). Two specialists in parallel: game-designer authored Player Fantasy + Detailed Rules (CR-FB-1..14) + Tuning Knobs; systems-designer authored Formulas (F-FB-1..5) + Edge Cases (EC-FB-1..12) + Dependencies + AC (16 total). Synthesizer reconciled per systems-designer's apex-safe caps (per-unit cap 0.05; new P_MULT_COMBINED_CAP=1.31 enforced in damage-calc F-DC-5). Cross-doc obligations applied: damage-calc.md rev 2.9 (ResolveModifiers fields + F-DC-5 Formation block + F-DC-3 eff_def addition + P_MULT_COMBINED_CAP constant); grid-battle.md Dependencies row updated; turn-order.md OQ-3 marked RESOLVED. **Apex arithmetic verified pre-close**: Cavalry REAR+Charge+Rally(+10%)+Formation(+5%) clamps to P_mult=1.31 → raw=178 (1pt regression from rev 2.8.1's 179 = user-adjudicated trade-off). Pillar 1+3 hold across all 4-class × 3-Rally × 2-Formation states. **Carry-forward**: `/design-review` pass-1 still pending (recommended next session); `tests/fixtures/formation_bonus/*.yaml` files all deferred (12 of 16 ACs deferred-fixture); 3 Open Questions logged (OQ-FB-01 facing direction, OQ-FB-02 per-faction restrictions, OQ-FB-03 dedicated battle-hud spec); damage-calc rev 2.9 narrow re-review recommended (apex regression 179→178 needs cross-spec verification). | design/gdd/formation-bonus.md | Map/Grid, Unit Roles, Grid Battle, Hero Database, Damage Calc rev 2.9, Turn Order, Balance/Data |
| 4 | Destiny Branch System (운명 분기) | Gameplay | MVP | Feature | **Designed** (rev 1.3.1 — **APPROVED pass-10 2026-04-19** clean-session lean re-review; 10/10 pass-10 preconditions pass; 0 blocking / 2 Tier-2 stale-count doc-hygiene + 1 Tier-3 pseudocode-breadcrumb fixed in-session rev 1.3.1 patch [AC-DB-21 5→12, AC-DB-34 10→12, F-DB-1 step 1c rejected-API breadcrumb stripped]; 43 ACs; 12 Core Rules; 4 formulas; 17 edge cases; 16 open questions; 12-entry F-DB-3 invalid-reason vocabulary; ratifies ADR-0001 DestinyBranchChoice 9-field payload. **Implementation-story open gated by Pre-Implementation Gate Checklist**: ADR-0001 minor amendment (9-field + BattleOutcome class_name + invalid-path emission + 12-entry vocab) + sp v2.1 F-SP-1 is_canonical_history + sp v2.1 UX.2 Beat-7 carve-out ack + Grid Battle v5.0 `class_name BattleOutcome`. MVP-exit gate: Ch1-priming-null miss-rate ≤10% by Ch2 end (OQ-DB-10 D3). VS-close gates: AC-DB-24 Android+Windows CI lanes (OQ-DB-6), OQ-DB-12 haptic-pref verification, OQ-DB-13 error-dialog a11y, AC-DB-39 affordance-onset sync. Prior pass history: pass-7→rev 1.1, pass-8→rev 1.2, pass-9→rev 1.3, pass-10→**APPROVED rev 1.3.1**. | design/gdd/destiny-branch.md | Grid Battle, Destiny State (PROVISIONAL), Scenario Progression |
| 5 | Unit Role System (무장 역할) | Gameplay | MVP | Core | Designed | design/gdd/unit-role.md | Hero DB, Balance/Data |
| 6 | Scenario Progression System (시나리오 진행) | Narrative | MVP | Feature | **Designed (APPROVED v2.2 close-out 2026-04-19)** — pass-1 (v1.0, 30 BLOCKING) + pass-2 (v2.0, 34 BLOCKING + Echo pillar-integrity regression) closed via v2.1 drafting (5 specialists in parallel + 4 user adjudications: Echo SELECTION + first_attempt_resolved anti-farm; WIN+echo cue_tag tinting; F-SP-6 hard-constraint wins → TK-SP-5 deleted; sub-threshold DRAW persistence acknowledgment via draw_after_persistence cue_tag) + v2.1 full 7-specialist re-review (3 APPROVED + 4 CONCERNS, 5 mechanical blockers) + v2.2 mechanical close-out (sub-threshold DRAW cue_tag added F-SP-1, CR-10 Beat 7→8 dramatic doctrine sentence, F-SP-3 seal timing prose, AC-SP-38(c)/39(c)/40 ADVISORY tags, AC-SP-41 NEW for draw_after_persistence rendering, UX.7 dual-cue_tag section, Gate Summary v2.2) + narrow v2.2 re-review (narrative + systems + qa) all APPROVED. **Final state**: 41 ACs (10 fixture-independent + 26 deferred-fixture + 8 ADVISORY); 14 Edge Cases (added EC-SP-13 toast, EC-SP-14 WIN+persistence); 16 CRs; 6 Formulas (all rewritten/extended). 3 pass-2 pillar defects all CLOSED (F-SP-1 echo-discarded-on-WIN → cue_tag tinting; F-SP-2 LOSS→DRAW farming → first_attempt_resolved; F-SP-6 vs TK-SP-5 → TK-SP-5 deleted). 3 pass-2 specialist disagreements all resolved (Beat 2 Ch1 variant → AC-SP-38; LUFS measurement → integrated R128 + short-term informal; EC-SP-1 empty-branch → EC-SP-13 toast). Pillar 1 holds; Pillar 2 architecturally expressible at 3-chapter MVP; Pillar 4 DRAW-as-distinct-outcome preserved. **Cross-doc downstream obligations**: damage-calc.md F-DC-5 rally_bonus update (named from Grid Battle pass-11c); save-load.md scenario_path_key delimiter `::` migration note (named from F-SP-4 v2.1). | design/gdd/scenario-progression.md | Save/Load (provisional), Balance/Data, Grid Battle, Hero Database, HP/Status, Destiny Branch (provisional), Destiny State (provisional), Story Event (provisional) |
| 7 | Battle Preparation System (전투 준비/편성) | Gameplay | Vertical Slice | Feature | Not Started | — | Unit Roles, Equipment, Map/Grid |
| 8 | AI System (적 AI) | Gameplay | MVP | Feature | Not Started | — | Grid Battle, Formation, Terrain, Unit Roles |
| 9 | Character Growth System (캐릭터 성장) | Progression | Vertical Slice | Feature | Not Started | — | Hero DB, HP/Status, Balance/Data |
| 10 | Story Event System (스토리 이벤트) | Narrative | Vertical Slice | Feature | Not Started | — | Scenario, Destiny State, Hero DB |
| 11 | Damage/Combat Calculation (데미지/전투 계산) | Gameplay | MVP | Feature | **Designed (APPROVED post-eighth-pass + rev 2.8 close-out 2026-04-19)** — eighth-pass review (5 specialists: qa-lead, godot-specialist, ux-designer, game-designer, systems-designer) caught Pillar-1+3 regression introduced by rev 2.7 (F-DC-5 rally_bonus extension): convergent game-designer + systems-designer arithmetic showed Cavalry REAR+Charge+Rally(+15%) at max ATK = floori(83×1.80×1.20×1.15) = 206 → DAMAGE_CEILING=180 fires; Archer FLANK+Ambush+Rally(+15%) = 181 → ceiling fires; Pillar-3 hierarchy collapses to Cavalry=Archer=Scout=180. User adjudicated B-8-1 path: cap Rally + reduce CAVALRY REAR multiplier. Rev 2.8 systems-designer-derived constraint-optimized fix: CLASS_DIRECTION_MULT[CAVALRY][REAR] 1.20→1.09 (D_mult 1.80→1.64) + Rally cap (Grid Battle CR-15 rule 4) +15%/3 commanders → +10%/2 commanders. All 12 apex cells (4 classes × Rally 0/+5%/+10%) preserved <180 with Cavalry leading by ≥5pt; Pillar-1 differentiation 27-30pt; ceiling never fires on primary path. Cross-doc atomic sweep: damage-calc.md (~11 edits incl Player Fantasy 2.16x→1.97x; D-3 worked example rewritten — closes seventh-pass R-8-3 deferred), grid-battle.md (~5 edits incl CR-15 rule 4 + 7 + Purpose + AC-GB-27 sub-cases b/c), unit-role.md (~3 edits incl CR-2 row + EC-12 + Tuning Knob row). Pass arc: 8 review passes; eighth-pass first formal review since rev 2.5 sixth-pass; rev 2.8 first sweep where convergent specialist arithmetic caught a regression introduced by the immediately-prior commit. Carry-forward: 10 of seventh-pass 11 deferred recommendeds remain (push_error export-build log, V-3 600ms-vs-800ms ghost, etc.) — eligible for rev 2.9 bandwidth. OQ-AUD-05 + OQ-VIS-03 unchanged. **Rev 2.8.1 close-out**: 3-spec narrow re-review (game-designer + systems-designer + qa-lead) caught 5 stale-value defects in narrative/AC text (AC-DC-03 expected_damage 64→59, AC-DC-04 pass criteria D_mult 1.80→1.64, L1240 Tuning Governance Cavalry REAR 1.20→1.09, Pillar-3 peak hierarchy table Archer/Scout R=+10% off-by-one 174→173, unit-role.md AC-10 cap 15%→10%). All 5 fixes applied; structural rev 2.8 fix preserved; arithmetic table corrected. CD precedent vindicated: "same-session-after-CRITICAL high-risk" — specialist focused on formula correctness (got it right) but didn't audit every narrative quote of old values. Final apex table: Cavalry 163/171/179, Archer/Scout 157/165/173 (corrected), Infantry 136/143/150 — all <180, Cavalry leads by ≥6pt across all 12 cells. | design/gdd/damage-calc.md | Unit Roles, HP/Status, Terrain, Balance/Data |
| 12 | HP/Status System (HP/상태) | Gameplay | MVP | Core | Designed | design/gdd/hp-status.md | Hero DB |
| 13 | Turn Order/Action Management (턴 순서/행동 관리) | Gameplay | MVP | Core | **Designed (2026-04-19 — ADR-0001 single-owner rule compliance)** — `battle_ended` ownership migrated to Grid Battle: Turn Order's owned signal renamed `battle_ended` → `victory_condition_detected(Result)`; T7 + RE2 emission sites updated (CR-2 Per-Unit Turn Sequence, CR-2 Round End Sequence); Contract 4 declaration block updated with ADR-0001 attribution; state-transition diagram labels updated (ROUND_ACTIVE/ROUND_ENDING → BATTLE_ENDED triggers); Dependencies table Grid Battle row updated; Cross-system contracts summary updated; ECs (EC-18, EC-19) and ACs (AC-16, AC-18, AC-19, AC-22) all updated to reflect two-step emit chain (Turn Order detects → Grid Battle re-emits). Total 13 edits across 6 unique sections. systems-designer authored the full edit spec; synthesizer applied verbatim. No new review log file created — change is a downstream propagation from Grid Battle ADR-0001 ownership decision, no new specialist review pass needed. | design/gdd/turn-order.md | Hero DB |
| 14 | Map/Grid System (맵/그리드) | Core | MVP | Foundation | Designed | design/gdd/map-grid.md | (none) |
| 15 | Equipment/Item System (장비/아이템) | Economy | Alpha | Feature | Not Started | — | Hero DB, Unit Roles, Balance/Data |
| 16 | Destiny State Tracking (운명 상태 추적) | Narrative | Vertical Slice | Feature | Not Started | — | Scenario, Save/Load |
| 17 | Save/Load System (세이브/로드) | Persistence | Vertical Slice | Core | Not Started | — | Balance/Data |
| 18 | Battle HUD (전투 HUD) | UI | Alpha | Presentation | Not Started | — | Grid Battle, HP/Status, Turn Order, Formation, Camera |
| 19 | Battle Preparation UI (전투 준비 UI) | UI | Alpha | Presentation | Not Started | — | Battle Preparation, Equipment |
| 20 | Story Event UI (스토리 이벤트 UI) | UI | Alpha | Presentation | Not Started | — | Story Event, Destiny Branch |
| 21 | Main Menu / Scenario Select UI (메인 메뉴) | UI | Alpha | Presentation | Not Started | — | Scenario, Save/Load |
| 22 | Camera System (카메라) | Core | Vertical Slice | Feature | Not Started | — | Map/Grid, Input |
| 23 | Battle Effects/VFX (전투 연출/이펙트) | Audio | Alpha | Presentation | Not Started | — | Grid Battle, Damage Calc, Camera |
| 24 | Sound/Music System (사운드/음악) | Audio | Full Vision | Presentation | Not Started | — | Grid Battle, Story Event, Destiny Branch |
| 25 | Hero Database (무장 데이터베이스) | Core | MVP | Foundation | Designed | design/gdd/hero-database.md | (none) |
| 26 | Balance/Data System (밸런스/데이터) | Core | MVP | Foundation | Designed | design/gdd/balance-data.md | (none) |
| 27 | Tutorial System (튜토리얼) | Meta | Full Vision | Polish | Not Started | — | Grid Battle, Battle HUD, Story Event UI |
| 28 | Settings/Options (설정/옵션) | Meta | Alpha | Polish | Not Started | — | Input, Sound/Music, Save/Load |
| 29 | Input Handling System (입력 처리) | Core | MVP | Foundation | Designed | design/gdd/input-handling.md | (none) |
| 30 | Localization / i18n (지역화) | Meta | Full Vision | Polish | Not Started | — | Balance/Data |
| 31 | Class Conversion System (병종 변환) | Gameplay | Vertical Slice | Feature | Not Started | — | Unit Roles, Grid Battle, Formation |

---

## Categories

| Category | Description | Systems |
|----------|-------------|---------|
| **Core** | 모든 시스템이 의존하는 기반 인프라 | Map/Grid, Hero DB, Balance/Data, Input, Camera |
| **Gameplay** | 전투와 전술의 재미를 만드는 핵심 | Grid Battle, Terrain, Formation, Damage Calc, Unit Roles, HP/Status, Turn Order, Battle Prep, Class Conversion, AI |
| **Narrative** | 삼국지 스토리와 운명 분기 전달 | Destiny Branch, Destiny State, Scenario, Story Event |
| **Progression** | 장기적 성장과 동기 부여 | Character Growth |
| **Economy** | 자원 관리와 장비 | Equipment/Item |
| **Persistence** | 게임 상태 영속화 | Save/Load |
| **UI** | 플레이어 대면 정보 표시 | Battle HUD, Battle Prep UI, Story Event UI, Main Menu |
| **Audio** | 사운드와 시각 연출 | Sound/Music, Battle Effects/VFX |
| **Meta** | 코어 루프 외부 시스템 | Tutorial, Settings, Localization |

---

## Priority Tiers

| Tier | Definition | Systems Count | Target Milestone |
|------|------------|---------------|------------------|
| **MVP** | 코어 루프 작동에 필수. "이게 재미있는가?" 검증 | 14 | 프로토타입 (3-4주) |
| **Vertical Slice** | 완전한 1장 체험. 전투 전후 경험 완성 | 7 | 버티컬 슬라이스 (2-3개월) |
| **Alpha** | 모든 기능 러프 구현, UI/연출 완성 | 7 | 알파 (6-9개월) |
| **Full Vision** | 폴리시, 접근성, 글로벌 확장 | 3 | 베타/출시 (12-18개월) |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Map/Grid System** — 전투의 공간적 기반. 타일 데이터 구조, 좌표계, 경로 탐색
2. **Hero Database** — 80-100명 무장의 스탯/스킬/소속/관계 데이터 정의
3. **Balance/Data System** — 외부 설정 파일 구조, 데이터 로딩 파이프라인 (하드코딩 금지)
4. **Input Handling System** — PC(마우스/키보드) + 모바일(터치) 통합 입력 추상화

### Core Layer (depends on Foundation)

1. **Terrain Effect System** — depends on: Map/Grid
2. **Unit Role System** — depends on: Hero DB, Balance/Data
3. **HP/Status System** — depends on: Hero DB
4. **Turn Order/Action Management** — depends on: Hero DB
5. **Save/Load System** — depends on: Balance/Data

### Feature Layer (depends on Core)

1. **Grid Battle System** — depends on: Map/Grid, Terrain, Unit Roles, HP/Status, Turn Order, Input
2. **Damage/Combat Calculation** — depends on: Unit Roles, HP/Status, Terrain, Balance/Data
3. **Formation Bonus System** — depends on: Map/Grid, Unit Roles, Grid Battle
4. **Class Conversion System** — depends on: Unit Roles, Grid Battle, Formation
5. **Scenario Progression** — depends on: Save/Load, Balance/Data
6. **Destiny State Tracking** — depends on: Scenario, Save/Load
7. **Destiny Branch System** — depends on: Grid Battle, Destiny State, Scenario
8. **Story Event System** — depends on: Scenario, Destiny State, Hero DB
9. **Battle Preparation** — depends on: Unit Roles, Equipment, Map/Grid
10. **Equipment/Item System** — depends on: Hero DB, Unit Roles, Balance/Data
11. **AI System** — depends on: Grid Battle, Formation, Terrain, Unit Roles
12. **Character Growth** — depends on: Hero DB, HP/Status, Balance/Data
13. **Camera System** — depends on: Map/Grid, Input

### Presentation Layer (depends on Features)

1. **Battle HUD** — depends on: Grid Battle, HP/Status, Turn Order, Formation, Camera
2. **Battle Preparation UI** — depends on: Battle Preparation, Equipment
3. **Story Event UI** — depends on: Story Event, Destiny Branch
4. **Main Menu / Scenario Select UI** — depends on: Scenario, Save/Load
5. **Battle Effects/VFX** — depends on: Grid Battle, Damage Calc, Camera
6. **Sound/Music System** — depends on: Grid Battle, Story Event, Destiny Branch

### Polish Layer (depends on everything)

1. **Tutorial System** — depends on: Grid Battle, Battle HUD, Story Event UI
2. **Settings/Options** — depends on: Input, Sound/Music, Save/Load
3. **Localization / i18n** — depends on: Balance/Data

---

## Recommended Design Order

| Order | System | Priority | Layer | Primary Agent | Est. Effort |
|-------|--------|----------|-------|---------------|-------------|
| 1 | Map/Grid System | MVP | Foundation | systems-designer | M |
| 2 | Hero Database | MVP | Foundation | systems-designer | M |
| 3 | Balance/Data System | MVP | Foundation | systems-designer | S |
| 4 | Input Handling System | MVP | Foundation | systems-designer | S |
| 5 | Terrain Effect System | MVP | Core | systems-designer | M |
| 6 | Unit Role System | MVP | Core | systems-designer | L |
| 7 | HP/Status System | MVP | Core | systems-designer | M |
| 8 | Turn Order/Action Management | MVP | Core | systems-designer | M |
| 9 | Grid Battle System | MVP | Feature | game-designer | L |
| 10 | Damage/Combat Calculation | MVP | Feature | systems-designer | M |
| 11 | Formation Bonus System | MVP | Feature | systems-designer | L |
| 12 | Scenario Progression | MVP | Feature | narrative-director | M |
| 13 | Destiny Branch System | MVP | Feature | game-designer | L |
| 14 | AI System | MVP | Feature | ai-programmer | L |
| 15 | Destiny State Tracking | Vertical Slice | Feature | systems-designer | M |
| 16 | Story Event System | Vertical Slice | Feature | narrative-director | M |
| 17 | Save/Load System | Vertical Slice | Core | systems-designer | M |
| 18 | Battle Preparation | Vertical Slice | Feature | game-designer | M |
| 19 | Class Conversion System | Vertical Slice | Feature | game-designer | M |
| 20 | Character Growth | Vertical Slice | Feature | systems-designer | M |
| 21 | Camera System | Vertical Slice | Feature | systems-designer | S |
| 22 | Equipment/Item System | Alpha | Feature | economy-designer | M |
| 23 | Battle HUD | Alpha | Presentation | ui-programmer | M |
| 24 | Battle Preparation UI | Alpha | Presentation | ui-programmer | M |
| 25 | Story Event UI | Alpha | Presentation | ui-programmer | M |
| 26 | Main Menu / Scenario Select UI | Alpha | Presentation | ui-programmer | S |
| 27 | Battle Effects/VFX | Alpha | Presentation | technical-artist | M |
| 28 | Sound/Music System | Full Vision | Presentation | audio-director | M |
| 29 | Tutorial System | Full Vision | Polish | game-designer | M |
| 30 | Settings/Options | Alpha | Polish | systems-designer | S |
| 31 | Localization / i18n | Full Vision | Polish | localization-lead | M |

**Effort key**: S = 1 session, M = 2-3 sessions, L = 4+ sessions

**병렬 설계 가능**: 같은 Layer의 독립 시스템은 병렬 진행 가능
- Foundation: #1-#4 모두 병렬 가능
- Core: #5-#8 모두 병렬 가능 (Foundation 완료 후)
- Feature MVP: #9(Grid Battle)는 Core 전체 의존, #10-#11은 #9 이후

---

## Circular Dependencies

순환 의존성 없음. 모든 의존 관계가 Foundation → Core → Feature → Presentation → Polish 방향으로 흐른다.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| **Map/Grid System** | Technical | 병목 — 9개 시스템이 의존. 설계 실수가 전체에 전파 | 프로토타입에서 가장 먼저 구현 후 검증 |
| **Hero Database** | Scope | 80-100명 무장 데이터. 밸런싱 공수 폭발 가능 | MVP는 8-10명으로 제한. 데이터 구조만 확장 가능하게 설계 |
| **Formation Bonus System** | Design | Pillar 1의 핵심이지만 "진형이 재미있는가?"는 미검증 | MVP에서 2-3개 기본 진형으로 프로토타입 테스트 |
| **Destiny Branch System** | Design | "숨겨진 조건"의 적정 난이도 미확정. 너무 어려우면 좌절, 너무 쉬우면 무의미 | MVP에서 1-2개 분기로 UX 테스트. 난이도 조절 가능한 구조 |
| **AI System** | Technical | AI가 진형 전술을 의미 있게 사용해야 Pillar 1이 작동 | 규칙 기반 AI부터 시작, 점진적 개선. AI가 약하면 전투가 무의미 |
| **Class Conversion System** | Design | 병종 변환의 전략적 깊이 vs. 복잡도 밸런스 미확정 | Vertical Slice에서 제한된 변환 옵션으로 테스트 |
| **Destiny State Tracking** | Technical | 분기 조합 폭발 — 15-20개 분기의 연쇄 영향 관리 | 비트 플래그 방식 + 연쇄 영향을 트리 구조로 제한 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 31 |
| Design docs started | 11 |
| Design docs reviewed | 3 (Grid Battle — 7 passes, MAJOR REVISION NEEDED, v5.0 pillar-alignment pending; Scenario Progression — 2 passes 2026-04-18, v2.0 MAJOR REVISION NEEDED — Echo-gate pillar-integrity regression + 34 blockers; Damage/Combat Calculation — 4 passes 2026-04-18, MAJOR REVISION → rev 2 → NEEDS REVISION → rev 2.1 → NEEDS REVISION → rev 2.2 → NEEDS REVISION (lean 4-specialist pass, 8 blockers) → rev 2.3 sweep applied (typed RefCounted wrappers + ADR-0005; Archer asymmetry; WCAG Reduce Motion; GdUnit4 built-in assertions), fresh new-session re-review pending — expected APPROVED) |
| Design docs approved | 0 |
| MVP systems designed | 11/14 |
| Vertical Slice systems designed | 0/7 |
| Alpha systems designed | 0/7 |
| Full Vision systems designed | 0/3 |

---

## Next Steps

- [ ] Design MVP-tier systems first (use `/design-system [system-name]`)
- [ ] Start with Map/Grid System (#1 in design order)
- [ ] Run `/design-review` on each completed GDD
- [ ] Prototype the highest-risk system early (`/prototype grid-battle`)
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Run `/review-all-gdds` after completing all MVP GDDs
