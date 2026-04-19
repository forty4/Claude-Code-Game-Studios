# Damage/Combat Calculation — Review Log

> System: #11 Damage/Combat Calculation (데미지/전투 계산)
> GDD: `design/gdd/damage-calc.md`
> Layer: Feature (MVP)
> Created: 2026-04-18

---

## Review — 2026-04-18 — Verdict: MAJOR REVISION NEEDED → Revised in-session

Scope signal: L (multi-system integration; 7 formulas; 4 dependencies; revision touched ADR-0001 consumer surface)
Specialists: game-designer, systems-designer, qa-lead, ux-designer, audio-director, performance-analyst, godot-specialist + creative-director (senior synthesis)
Blocking items: 12 | Recommended: 14
Prior verdict resolved: First review

### Summary
First-pass review surfaced 12 blocking issues across formula correctness (sign convention on `terrain_def`, DEFEND_STANCE double-application risk, Charge/Ambush firing on counter, ceiling saturation at 150), Godot/GDScript implementation realities (`source_flags` typed as Set when GDScript has no Set type; `ResolveResult` underspecified; ADR-0001 consumer-only contract violated), pillar alignment (Infantry direction multipliers were uniform — broke Pillar 3 "Every Hero Has a Role"), tactical weight (counter damage of 8 was cosmetic, not meaningful), and validation rigor (unverifiable cross-platform "bit-exact" claim; unconfirmed `Engine.get_error_count()` API; CI cost-explosion if 3-OS-per-push). Creative-director synthesis adjudicated specialist disagreement on DEFEND_STANCE double-fire (game-designer CONCERN vs systems-designer BUG) in favor of systems-designer (source-text contradiction = correctness defect, not design tension). All 12 blockers resolved in-session via Edit pass: sign convention inverted, exactly-once semantics locked, class guards added (CAVALRY/SCOUT/ARCHER) + counter exclusion, DAMAGE_CEILING raised 150→180 (per user decision) to differentiate REAR-Charge peak from REAR-only, `ResolveResult` redesigned as RefCounted+factory with `Array[StringName]` source_flags, Infantry asymmetry FRONT=0.90/FLANK=1.00/REAR=1.10 (per user decision) restoring Pillar 3 expression, counter retuned to 12-18 range (per user decision, D-8 ATK=120→counter_final=16), determinism softened to "known-good baseline" via canonical macOS-Metal CI snapshot (per user decision) with cross-platform drift as WARN annotation rather than build break. 10 of 14 recommended revisions also addressed in same pass (CombatAudioPool ownership clarification, AC-DC-25 weekly matrix, AC-DC-27 class-mutex test, AC-DC-46 Reduce Motion lifecycle math, GdUnit4 `assert_error_log()` matchers replacing `Engine.get_error_count()`, AoE coverage expansion). Cross-system patches queued for Phase 5 (registry registration of `damage_resolve` + CHARGE_BONUS + AMBUSH_BONUS, citation back-references on grid-battle / unit-role / turn-order / hp-status / terrain-effect / balance-data).

### Outstanding
- **Fresh re-review required**: 22+ Edit operations applied in-session; user opted to re-review in a clean session before treating revisions as final-approved.
- **Phase 5 cross-system patches not yet executed**: entities.yaml registry, 6 GDD back-references, plus the DAMAGE_CEILING value update 150→180 in registry.
- **Open questions persist**: OQ-DC-1..10 + OQ-VIS-01/02 + OQ-AUD-01/02/03 — none are blocking, all owned by Balance/Data, Audio Director, or Art Director for resolution at implementation-time.

---

## Review — 2026-04-18 (second pass, same day) — Verdict: NEEDS REVISION (minor) → Revised in-session (rev 2.1)

Scope signal: L (same systems touched as first pass; only delta consistency issues)
Specialists: skill ran in `lean` mode per `production/review-mode.txt` — no sub-agents spawned, single-session structural + cross-registry pass
Blocking items: 3 | Recommended: 10
Prior verdict resolved: Yes (first review's 12 blockers all closed; this pass found derived consistency gaps the rev 2 sweep missed)

### Summary
Re-review of rev 2 (post-first-pass sweep) found that rev 2's changes were individually correct but had not fully propagated. Three residual blockers: (B1) AC-DC-08 acceptance criteria still used the pre-retune counter-damage value of 8 instead of the rev 2 target of 16; (B2) `design/registry/entities.yaml` still listed `DAMAGE_CEILING: 150` and the `damage_resolve` formula's `output_range: [1, 150]` — contradicting the GDD's rev 2 raise to 180; (B3) F-DC-5 pseudocode referenced an undeclared `ResolveResult.AttackerClass` enum — ownership ambiguous. Adjudication: user confirmed Unit Role owns the Class enum (per `unit-role.md` §EC-7), so F-DC-5 repointed to `UnitRole.Class.CAVALRY/SCOUT/ARCHER` without introducing a duplicate enum on ResolveResult. Ten recommended revisions also applied in same sweep: (R1-R2) registry CHARGE_BONUS + AMBUSH_BONUS notes rewritten — old notes claimed 1.38 stacking was production-reachable, contradicting rev 2's class-guard mutex; (R3) OQ-DC-10 citation repointed from non-existent `CR-13/CR-14` to real `CR-8/CR-11/CR-12/EC-DC-12/13/15/16/AC-DC-19/21/22/28`; (R4, R5) stale meta-commentary in D-6 and D-8 worked examples removed; (R6) AC-DC-40 "Pixel 4a" single-device target converted to a device-class spec (ARMv8, ≥4GB RAM, Adreno 610 / Mali-G57+, Android 12+ / iOS 15+); (R7) AC-DC-25 weekly full-matrix cadence augmented with `rc/*` tag trigger so release candidates always get full-matrix verification; (R8) Coverage Matrix VS-blocker count corrected from 30 to 32 (arithmetic: 10+15+3+2+2); (R9) UI-2 tooltip example purged the "(DAMAGE_CEILING 180 not reached)" line that violated the rule it set two lines below ("shown only when ceiling fired"); (R10) A-2 audio tier bands flagged with `OQ-AUD-05` for Alpha re-audition since the absolute thresholds {30, 74, 130} were calibrated against the pre-rev-2 ceiling=150. An additional cleanup: EC-DC-14 replay-determinism language received the "on the same platform" qualifier and AC-DC-37 was split into a baseline-platform per-push gate (macOS Metal, ship-blocker) vs weekly+rc-tag full matrix (WARN, escalates to blocking at Release-candidate gate) — bringing those two ACs into line with the softened determinism contract from rev 2's §Formulas language and the registry notes rewrite. Files touched: `design/gdd/damage-calc.md` (12 edits) and `design/registry/entities.yaml` (6 edits). No new formulas, no new ACs, no new OQs except OQ-AUD-05.

### Outstanding
- **Fresh re-review still required**: user opted for clean-session re-review of rev 2.1 to verify both sweeps holistically.
- **Phase 5 cross-system patches still pending** (carried over from first review, not part of this skill's scope): `damage_resolve` formula registration in `entities.yaml` already partially done (DAMAGE_CEILING value, output_range, CHARGE/AMBUSH notes, determinism notes); remaining: `referenced_by` updates on 9 consumed constants, `grid-battle.md` F-GB-PROV removal + CombatAudioPool ownership amendment, back-references on `unit-role.md` (Infantry asymmetry), `turn-order.md` (`get_acted_this_turn` O(1)), `hp-status.md`, `terrain-effect.md`, `balance-data.md`.

---

## Review — 2026-04-18 (third pass, clean-session full review) — Verdict: NEEDS REVISION (minor) → Revised in-session (rev 2.2)

Scope signal: L (unchanged — same systems touched; rev 2.2 fix scope itself is S, ~1 day)
Specialists: game-designer, systems-designer, qa-lead, ux-designer, audio-director, performance-analyst, godot-specialist + creative-director (senior synthesis) — full mode per skill default, overriding the `lean` production/review-mode.txt setting for this clean-session verification
Blocking items: 5 clusters (~17 raw findings) | Recommended: 10
Prior verdict resolved: Yes — rev 2.1's 3 blockers all verified closed; this pass found new defects that rev 2.1 did not surface (engine contracts, StringName boundary, ceiling-opacity pillar gap)

### Summary
Clean-session full review of rev 2.1 spawned 7 specialists in parallel + creative-director synthesis. Three convergent findings strengthened confidence (no direct disagreements): (a) `assert_error_log()` flagged independently by godot-specialist and qa-lead as a fabricated GdUnit4 API — AC-DC-20/21/22 unenforceable as written; (b) ceiling opacity flagged independently by game-designer (Pillar 1 violation — Cavalry REAR+Charge 216→180 silently clamped is indistinguishable from uncapped 180), ux-designer (modality gap), and audio-director (A-2 tier identical for clamped vs uncapped PEAK); (c) UI-6 850ms vs AC-DC-46 700ms lifecycle mismatch flagged by both ux-designer and qa-lead. Additional blocking findings: AC-DC-50 negative-tie expected value `-0.005 → 0.00` was wrong — Godot's `snappedf` delegates to `round()` which is half-AWAY-from-zero (so `-0.005 → -0.01`, not 0.00); AC-DC-49/50 lacked engine-reference citations; F-DC-5 `"passive_charge" in attacker.passives` silently returns false if Grid Battle passes `Array[String]` instead of `Array[StringName]` — no error, no log, just quietly wrong (silent-wrong-answer correctness hole); UI-3 24×24 chip violated project-level 44px touch-target mandate; `.github/workflows/tests.yml` missing multi-platform matrix for AC-DC-25/37/50's weekly+rc-tag contract. Creative-director synthesis compressed findings into 5 clusters and rejected 5 non-blockers (Ambush-denial perverse incentive — Grid Battle scope; voice-cap tiebreak — recommended-tier; cross-citations — Phase 5 tracked; 50µs budget aspirational; edge-case count off-by-one editorial). Priority order: Cluster 1 (engine contracts) → Cluster 4 (StringName boundary) → Cluster 2 (ceiling disclosure) → Cluster 3 (UI contradictions) → Cluster 5 (CI one-liner). 11 fixes applied in-session via targeted Edit pass: AC-DC-20/21/22 rewritten to cite project helper `tests/helpers/error_log_capture.gd`; AC-DC-49/50 gained engine-reference citations; AC-DC-50 negative-tie expected value corrected -0.005→-0.01 AND "round-half-up" renamed to "round-half-away-from-zero" across all 6 occurrences (AC-DC-32, AC-DC-38, AC-DC-50, EC-DC-6, §Verify-against-engine, Coverage Matrix); F-DC-5 pseudocode gained entry-point `assert(attacker.passives is Array[StringName])` + `PASSIVE_CHARGE: StringName = &"passive_charge"` + `PASSIVE_AMBUSH: StringName = &"passive_ambush"` constants + `StringName` literal comparisons in the body (belt-and-suspenders); CR-8 description bullets updated to reference StringName literals; EC-DC-25 (StringName type-contract violation, BLOCKER) and AC-DC-51 (CONTRACT — Vertical Slice gate) added; UI-2 rewritten with `▲ CAPPED (raw 216)` tri-modal disclosure spec; V-4 table gained `"ceiling_clamped"` visual overlay row; A-4 table gained `"ceiling_clamped"` metallic-sting audio overlay row; A-1 (c) amended to clarify ceiling sting is an **outcome-disclosure overlay** (layer c') that stacks on top of provenance overlays; AC-DC-52 (DISCLOSURE — Beta gate, tri-modal integration test across visual/audio/screen-reader) added; AC-DC-53 + EC-DC-26 (Scout REAR+Ambush boundary 189→180) added; UI-3 chip hit-area 24×24 → 44×44 (visible glyph may stay small with transparent padding ring); UI-6 Reduce Motion lifecycle 850ms → 700ms; one-line DevOps prerequisite note added under Coverage Matrix for `.github/workflows/tests.yml` multi-platform matrix + cron + `rc/*` tag trigger. Coverage Matrix total AC count 50 → 53. Files touched: `design/gdd/damage-calc.md` (15 edits this pass).

### Outstanding
- **Fresh re-review required**: clean-session re-review of rev 2.2 still pending. Per creative-director: a lean 4-specialist pass (qa-lead + godot-specialist + ux-designer + game-designer) is sufficient — do NOT run another full 7-specialist pass. Expected verdict: APPROVED if no new defects surface.
- **Phase 5 cross-system patches still pending**: unchanged from rev 2.1 carry-over — entities.yaml `referenced_by` updates on 9 consumed constants; `grid-battle.md` F-GB-PROV removal + CombatAudioPool ownership amendment; back-references on `unit-role.md` / `turn-order.md` / `hp-status.md` / `terrain-effect.md` / `balance-data.md`. Rev 2.2 adds one new Phase-5 item: `.github/workflows/tests.yml` multi-platform matrix wiring (documented in the GDD's Coverage Matrix footer but owned by DevOps).
- **OQ-AUD-05** (logged rev 2.1): still deferred to Alpha audition — audio tier bands recalibration against DAMAGE_CEILING=180.

---

## Review — 2026-04-18 (fourth pass, same day) — Verdict: NEEDS REVISION → Revised in-session (rev 2.3)

Scope signal: L (same systems touched as prior passes; delta is typed-wrapper introduction + accessibility-hold policy change + class identity fix)
Specialists: qa-lead, godot-specialist, ux-designer, game-designer (lean 4-specialist pass per creative-director rev-2.2 guidance; creative-director senior synthesis skipped per lean mode)
Blocking items: 8 | Recommended: 7
Prior verdict resolved: Yes — the rev 2.2 sweep fabricated a non-existent `tests/helpers/error_log_capture.gd` helper (same class of defect rev 2.2 thought it was fixing); rev 2.3 replaces with GdUnit4 built-ins.

### Summary
Clean-session lean review of rev 2.2 spawned 4 specialists in parallel. Two convergent findings strengthened confidence: (a) `tests/helpers/error_log_capture.gd` flagged independently by qa-lead and godot-specialist as a fabricated dependency — the rev 2.2 "fix" to the original `assert_error_log()` defect invented a project helper that was never authored, leaving AC-DC-19/21/22 (3 Vertical Slice gates) unexecutable — the SAME class of defect the sweep thought it fixed; (b) class-identity issues flagged by game-designer: Archer CLASS_DIRECTION_MULT = 1.00/1.00/1.00 is flat (Pillar 3 structural failure), and Scout/Archer Ambush damage-space overlap (indistinguishable on FLANK 1.20 / REAR 1.65). Additional specialist-unique blockers: godot-specialist found F-DC-5 empty-Array[String] bypass (is_empty() short-circuits typeof check) + invalid `is Array[StringName]` GDScript syntax, plus untyped `modifiers.rng: RandomNumberGenerator` inside plain Dictionary (no static enforcement — returns Variant); ux-designer found Reduce Motion `min(baseline_hold, 400ms)` violates WCAG 2.2 SC 2.2.1 (accessibility population starved of reading time) and `skill_unresolved` TalkBack announcement gated behind `OS.is_debug_build()` (WCAG 2.1 SC 4.1.3 violation — blind users get no feedback in production); qa-lead found Beta blocker count off-by-one (10 listed → 11 actual). All 8 blockers resolved in-session via targeted Edit pass. Key structural changes: (1) introduced `ResolveModifiers` / `AttackerContext` / `DefenderContext` RefCounted wrappers (ADR-0005 queued in Phase 5) replacing Dictionary payload — GDScript 4.6 enforces `Array[StringName]` at parameter binding, eliminating both the empty-array bypass and the invalid `is` syntax; F-DC-5 hand-rolled assert removed; (2) Archer CLASS_DIRECTION_MULT changed to 1.00 / 1.10 / 0.90 (arcing-shot advantage + line-of-sight penalty) — derived D_mult grid: Archer peaks at FLANK 1.32, Scout peaks at REAR 1.65, so damage-space identities are now spatially disjoint; (3) AC-DC-19/21/22 rewritten to use GdUnit4's built-in `assert_error(...).is_push_error_message(...)` + `Engine.get_error_count()` rather than the fabricated helper; (4) Reduce Motion hold changed from `min(baseline_hold, 400ms)` to `max(baseline_hold, 1200ms)` with 350ms fade (total 1550ms lifecycle), aligned to WCAG 2.2 SC 2.2.1 reading-window requirements; UI-6 and AC-DC-46 updated; (5) `OS.is_debug_build()` gate removed from `skill_unresolved` TalkBack announcement — now fires in all builds per WCAG 2.1 SC 4.1.3; AC-DC-45 walkthrough requires release-config verification; (6) Beta blocker count corrected 10 → 11 (with 4+1+2+3+1 breakdown). Also updated: CR-1 signature, Grid Battle interaction table row, EC-DC-25 citation language, AC-DC-51 pass criteria (boundary + bypass-seam + positive cases), Cross-System Patches table (8 → 10 entries, ADR-0005 + grid-battle.md typed-signature migration added). Files touched: `design/gdd/damage-calc.md` (15+ edits this pass), `design/gdd/systems-index.md` (row #11 + header timestamp + progress tracker).

### Outstanding
- **Fresh re-review required**: user confirmed `/clear` + new session for re-review (current session at high context usage from 4 specialist subagents + 15+ edits). Expected verdict: APPROVED if no new defects surface.
- **Phase 5 cross-system patches expanded**: adds ADR-0005 (ResolveModifiers wrapper) authorship and grid-battle.md §CR-5 lines 807-816 typed-signature migration; unit-role.md Archer CLASS_DIRECTION_MULT amendment (1.00/1.00/1.00 → 1.00/1.10/0.90) must land in same commit window as damage-calc.md rev 2.3.
- **Recommended revisions not applied**: 7 non-blocking rec revs (AMBUSH_BONUS split test, CAPPED overlay contrast spec, UI-3 chip visual size, AC-DC-49/50 anchor rot risk, AC-DC-52 sub-AC split, DAMAGE_CEILING MVP-unreachability, counter deterrent floor) logged but not fixed this pass.
- **OQ-AUD-05** (logged rev 2.1): still deferred to Alpha audition.
- **OQ-VIS-03** (NEW rev 2.3): CAPPED overlay text-color contrast against damage-number backdrop — WCAG 1.4.11 3:1 non-text contrast — owned by art-director; resolve at Vertical Slice.

---

## Review — 2026-04-18 (fifth pass, fresh clean session) — Verdict: NEEDS REVISION

Scope signal: L (same systems touched; rev 2.4 sweep scope itself is M — ~15 edits across damage-calc.md + potentially unit-role.md)
Specialists: qa-lead, godot-specialist, ux-designer, game-designer (lean 4-specialist pass per creative-director rev-2.2 guidance; creative-director synthesis skipped per lean mode)
Blocking items: 10 | Recommended: 9 | Nice-to-have: 10
Prior verdict resolved: **Partially** — rev 2.3's 8 blockers largely closed, but 3 CRITICAL defects recursed the same class rev 2.2/2.3 thought they fixed (fabricated engine APIs survive into the "fix" text itself).

### Summary

Clean-session lean review of rev 2.3 spawned 4 specialists in parallel (qa-lead + godot-specialist + ux-designer + game-designer). Expected verdict was APPROVED; actual is NEEDS REVISION with three **CRITICAL** defects surfacing on primary-surface logic that survived four prior review rounds:

**CRITICAL-1 (convergent qa-lead + godot-specialist)** — `Engine.get_error_count()` cited in AC-DC-19/21/22 pass criteria is a **fabricated Godot 4.6 API** — does not exist on the `Engine` singleton. The rev 2.3 sweep replaced the rev 2.2 fabricated project helper (`tests/helpers/error_log_capture.gd`) but introduced a *different* fabricated engine API in its place. This is the exact class of defect BLK-1 was supposed to fix. Additionally, `assert_error(func(): ...).is_push_error_message(...)` is unverified against the installed GdUnit4 addon version — `addons/gdUnit4/` is not yet installed, so neither piece of the pass criteria is executable today.

**CRITICAL-2 (godot-specialist)** — `var class: UnitRole.Class` on `AttackerContext` (line 494) uses `class`, a GDScript 4.6 **reserved keyword**. The file will not load — parse error. Cascade: ~15-20 references throughout the doc (`attacker.class`, worked examples D-1..D-10, AC-DC-01 pass criteria, F-DC-5 pseudocode) must rename atomically to `unit_class` or `role_class`.

**CRITICAL-3 (game-designer)** — DAMAGE_CEILING=180 rationale (CR-9 lines 148-154, TK-DC-4 line 1073) is numerically false. At max-ATK Cavalry (ATK=200, eff_def=10, BASE_CEILING=100): REAR-no-Charge = `floori(100 × 1.80) = 180`; REAR+Charge = `floori(100 × 1.80 × 1.20) = 216 → clamped to 180`. Both produce 180. The ceiling completely erases the Charge bonus at max ATK — exactly the situation where "형세의 결산" should feel most decisive. Pillar-1 delivery claim that motivated the rev-2 150→180 raise is contradicted by the math.

**Remaining BLOCKERs** (7):
- Archer REAR=0.90 rationale cites LoS/cover mechanic Damage Calc does not model (Terrain Effect provides no arc-cover field) — false rationale creates design debt (game-designer).
- No OS Reduce Motion detection mechanism — only manual in-game toggle exists; AccessKit deferred to Full Vision tier; BLK-4's fix only helps players who already know to enable Settings (ux-designer).
- AC-DC-45 release-config walkthrough path not reproducible — release builds disable debugger; `OS.is_debug_build() == false` cannot be confirmed by a tester without a sentinel log line or build-mode overlay (ux-designer).
- AC-DC-37 full CI matrix is unenforceable — `.github/workflows/tests.yml` lacks multi-platform matrix + cron + rc/* trigger (per rev 2.2 note); AC is listed as Beta blocker but enforcement mechanism doesn't exist (qa-lead).
- AC-DC-51(a) `GdUnit4 assert_failure(...)` wrapping a GDScript type-error assignment is not a valid pattern — GDScript 4.6 type errors are not catchable by Callable wrappers (qa-lead).
- Headless runner integration coverage unverified — `tests/gdunit4_runner.gd` discovery config may not include `tests/integration/`; UI frame-count assertions in AC-DC-46 may not be valid in headless Godot without display (qa-lead).

**Convergent findings strengthened confidence**: qa-lead and godot-specialist both flagged the fabricated `Engine.get_error_count()` / unverified `assert_error(...).is_push_error_message(...)` independently; no disagreements surfaced between specialists where they overlapped.

**Recommended revisions (9)** include: Scout REAR = Infantry REAR = 1.65 Pillar-3 identity overlap; Archer FLANK (1.32) = Cavalry FLANK (1.32) overlap introduced by BLK-6 fix itself; Ambush `acted_this_turn == false` incentivizes rushing turn order (contradicts Pillar 1 patience); 16/300 = 5.3% counter damage not defended against HP_CAP TTK; Archer has zero worked examples as attacker; counter passive suppression invisible to player; WCAG SC 2.2.1 wrong criterion citation; Reduce Motion `max(...,1200ms)` erases tier distinction; UI-2 dual-number chip conflicts with "verdict" Pillar-1 framing.

### Outstanding
- **Rev 2.4 sweep required in clean session** per creative-director pattern guidance — do NOT apply in the review session that surfaced the defects. Same-session revision is now 0-for-3 on avoiding fabricated-API recursion (rev 2.2 invented helper, rev 2.3 invented Engine API, rev 2.4 must break the cycle by verifying every engine/API reference against installed artifacts BEFORE authoring).
- **Rev 2.4 priority ordering**: (1) install `addons/gdUnit4/` and pin minimum version; (2) rename `class` field atomically; (3) resolve DAMAGE_CEILING Pillar-1 math (options: raise to 216, reduce BASE_CEILING, or amend the rationale to concede equivalence); (4) rewrite Archer REAR rationale to drop false LoS mechanic; (5) address Reduce Motion OS detection; (6) add release-config AC-DC-45 sentinel; (7) reconcile body-vs-matrix label contradictions (AC-DC-29/30/45); (8) resolve AC-DC-51(a) `assert_failure` pattern; (9) verify headless runner coverage; (10) flag CI matrix dependency on DevOps story.
- **Phase 5 cross-system patches still pending**: entities.yaml `referenced_by` updates on 9 consumed constants; grid-battle.md F-GB-PROV removal + CombatAudioPool ownership; back-references on unit-role.md / turn-order.md / hp-status.md / terrain-effect.md / balance-data.md; ADR-0005 authoring; grid-battle.md §CR-5 lines 807-816 typed-signature migration.
- **OQ-AUD-05** (logged rev 2.1): still deferred to Alpha audition.
- **OQ-VIS-03** (logged rev 2.3): still deferred to Vertical Slice (WCAG 1.4.11 contrast for CAPPED overlay).

---

## Revision 2.4 Sweep Applied — 2026-04-19 — 10 blockers resolved, 1 derived design call

Scope: clean-session revision pass following the 2026-04-18 fifth-pass review's 10 blockers. Revision mode: collaborative with 4 design-decision questions answered up front (DAMAGE_CEILING math, `class` rename target, Archer REAR rationale, guard-test strategy) + 1 derived question (ceiling disclosure disposition given BASE_CEILING=83).

### Design decisions adopted (before editing)
- **DAMAGE_CEILING math (CRITICAL-3)**: Lower BASE_CEILING 100 → 83. New hardest primary-path hit = `floori(83 × 1.80 × 1.20) = 179` (one under DAMAGE_CEILING=180). REAR-only max = 149. Pillar-1 differentiation: 30-pt gap at max ATK.
- **`class` keyword rename (CRITICAL-2)**: `class` → `unit_class` (matches existing `unit_id` naming pattern).
- **Archer REAR rationale (Blocker 4)**: Keep 1.00/1.10/0.90 numbers; rewrite rationale to role-identity-only (drawn-bow weapon handling disadvantage at close-quarters rear), drop false LoS/cover claim that Terrain Effect doesn't expose.
- **Invariant-violation guard testing (CRITICAL-1 + Blocker 8)**: Redesign guards to flagged MISS — replace `push_error + MISS()` with `push_error + MISS(source_flags: [&"invariant_violation:<reason>"])`. Tests assert on the flag. Zero dependency on any engine error-count API or uninstalled addon matcher. Drops AC-DC-51(a) `assert_failure` on GDScript type-error assignment (not a catchable pattern).
- **Ceiling disclosure disposition (derived from CRITICAL-3)**: Strip V-4 "ceiling_clamped" row, A-4 metallic sting row, A-1(c) outcome-disclosure-overlay text, UI-2 ▲ CAPPED chip + tri-modal rationale, AC-DC-52, AC-DC-53, EC-DC-26, Coverage Matrix DISCLOSURE row. DAMAGE_CEILING=180 stays as silent defense-in-depth wall; disclosure infra revisits if future buffs push the peak into reach.

### Blocker → fix summary

| # | Fifth-pass blocker | Rev 2.4 fix applied | Files touched |
|---|---|---|---|
| CRITICAL-1 | `Engine.get_error_count()` fabricated Godot API; `assert_error(...).is_push_error_message(...)` depends on uninstalled gdUnit4 addon | Redesign guards to flagged MISS (see CR-11 vocabulary); AC-DC-19/21/22 rewritten to `result.source_flags.has(&"invariant_violation:<reason>")` assertions — no engine API or addon matcher dependency | damage-calc.md (CR-11 vocab table; CR-12; F-DC-1 pseudocode; EC-DC-11/13/15/16; AC-DC-18/19/21/22/28; OQ-DC-10) |
| CRITICAL-2 | `var class: UnitRole.Class` uses GDScript 4.6 reserved keyword | Atomic rename `class` → `unit_class` across AttackerContext spec, F-DC-4/F-DC-5 pseudocode, Variable Dictionary, Interactions table, D-9 worked example, AC-DC-01 pass criteria, AC-DC-21 pass criteria, EC-DC-15, CR-7/CR-8 text | damage-calc.md (~9 sites) |
| CRITICAL-3 | DAMAGE_CEILING=180 rationale numerically false — REAR-Charge peak 216→180 indistinguishable from REAR-only 180 at max ATK | Lower BASE_CEILING 100→83. Retune D-2 (was 100, now 83), D-4 (was 180 clamped from 216; now 179, no ceiling fire). Reframe CR-6 and CR-9 rationales — DAMAGE_CEILING=180 becomes silent defense-in-depth wall (only fires under synthetic class-guard bypass). Strip ceiling-disclosure infra across V-4 / A-4 / A-1(c) / A-8 / UI-2 / UI-7 / AC-DC-52 / AC-DC-53 / EC-DC-26 / Coverage Matrix. TK-DC-3 safe range [70,90]. TK-DC-4 rationale rewritten. F-DC-3/F-DC-6 expected ranges updated. | damage-calc.md (~18 sites); entities.yaml (base_ceiling value 100→83 + notes + last_updated) |
| BLK-4 | Archer REAR=0.90 rationale cites LoS/cover that Terrain Effect does not expose | Rewrite F-DC-4 Archer rationale to role-identity-only (weapon-handling disadvantage at close-quarters rear, drawn-bow footwork). Drop all terrain-shadow language. | damage-calc.md (F-DC-4 rationale block) |
| BLK-5 | No OS Reduce Motion detection; AccessKit deferred to Full Vision | UI-4 Motion Reduction bullet rewritten — activation source is in-game Settings toggle (Vertical Slice, per OQ-3 elevation of Settings #28); OS-flag bridging deferred to AccessKit/Full Vision with cross-ref to `design/accessibility-requirements.md`. Documented gap explicitly so a11y users know Settings is the MVP activation path. | damage-calc.md (UI-4 Motion reduction) |
| BLK-6 | AC-DC-45 release-config walkthrough not reproducible | New Phase-5 DevOps task #12: autoload emits `"[BUILD_MODE] release"` / `"[BUILD_MODE] debug"` boot log line + top-right accessibility-debug overlay chip. AC-DC-45 pass criteria now require the sentinel as evidence. | damage-calc.md (AC-DC-45; Cross-System Patches Queued #12) |
| BLK-7 | Body-vs-matrix label contradictions (AC-DC-29/30/45 etc.) | Re-examined all 50+ "Blocker for:" lines vs. Coverage Matrix Release-stage summary. Corrected VS sub-blocker count (33 → 35 — includes AC-DC-40(a) CI throughput + AC-DC-41 no-dict alloc, which were previously miscounted). Beta sub-blocker count corrected (11 → 7 — removed AC-DC-52 and re-categorized AC-DC-40(b)). TOTAL unique AC count corrected 50 → 51 (was 53 before rev 2.4 stripped AC-DC-52/53). Coverage Matrix + Release stage summary now consistent with body labels. | damage-calc.md (Coverage Matrix; Release stage summary) |
| BLK-8 | AC-DC-51(a) `assert_failure(...)` wrapping GDScript type-error assignment is not a catchable pattern | Drop sub-criterion (a) from AC-DC-51. Keep (b) bypass-seam + (c) positive case only. Type-boundary enforcement verified by developer manually (parse/bind error in editor) — not by automated Callable-wrapper assertion. | damage-calc.md (AC-DC-51 pass criteria rewrite) |
| BLK-9 | Headless runner integration coverage unverified — UI frame-count assertions in AC-DC-46 not valid headless | AC-DC-46 pass criteria now explicitly requires headed CI job via `xvfb-run`. Coverage Matrix footer adds a second `CI command` for the headed UI-integration job. Phase-5 DevOps task #11 expanded to include `tests/integration/` discovery wiring and the xvfb-run job. | damage-calc.md (AC-DC-46; Coverage Matrix footer; Cross-System Patches Queued #11) |
| BLK-10 | `.github/workflows/tests.yml` lacks multi-platform matrix + cron + `rc/*` trigger (AC-DC-37 un-enforceable) | Re-flag CI infrastructure prerequisite under Coverage Matrix footer with ⚠️ sigil + explicit "BLOCKED BY: DevOps story" label. Merge with BLK-9's headed UI-integration requirement into single DevOps Phase-5 task #11. Hard-blocker escalation language: "Without these, AC-DC-25/37/46/47/50 are un-enforceable at Beta gate." | damage-calc.md (Coverage Matrix footer; Cross-System Patches Queued #11) |

### Rev 2.4 additional updates
- **Edge Cases intro count**: 24 → 25 edge cases (real count after rev 2.2 added EC-DC-25 and rev 2.4 removed EC-DC-26). Severity: 15 BLOCKER, 7 IMPORTANT, 3 MINOR.
- **Coverage Matrix TOTAL**: 53 → **51 unique ACs** (removed AC-DC-52, AC-DC-53; AC-DC-51(a) dropped but AC-DC-51 remains as single AC with (b)+(c) criteria).
- **F-DC-1 pseudocode**: guards added at entry (null-rng, bad attack_type, unknown direction, unknown unit_class, skill_unresolved) — all return flagged MISS; evasion-MISS now emits `&"evasion"` informational flag for legitimate terrain dodges.
- **`ResolveResult.miss(flags: Array[StringName] = [])`** — factory signature expanded to accept source_flags (previously no-arg). Pseudocode + CR-11 updated.
- **MISS source_flags vocabulary table** added to CR-11 as authoritative reference.
- **Registry (entities.yaml)**: `base_ceiling` value 100 → 83; `last_updated` bumped to 2026-04-19; notes rewritten.
- **GDD header**: `Last Updated` bumped to 2026-04-19 with rev 2.4 summary line.

### Outstanding (post rev-2.4)
- **Sixth-pass re-review in clean session still recommended** per creative-director pattern guidance — rev 2.2/2.3 both introduced new defects in their own revision sweeps (recursive fabrication trap); rev 2.4 explicitly designed its fixes to not depend on any uninstalled addon or un-grounded engine API, but independent verification is still prudent.
- **Phase 5 cross-system patches still pending**: unit-role.md Archer amendment (new rationale text), ADR-0005 authoring, grid-battle.md typed-signature migration (with `unit_class` rename), entities.yaml `referenced_by` updates on 9 constants, grid-battle.md F-GB-PROV removal, back-references on turn-order.md / hp-status.md / terrain-effect.md / balance-data.md. Plus new rev 2.4 items: DevOps story (CI matrix + headed UI job), engine-programmer story (build-mode sentinel), user action (gdUnit4 addon commit).
- **OQ-AUD-05** (logged rev 2.1): still deferred to Alpha audition.
- **OQ-VIS-03** (logged rev 2.3): NOW MOOT — CAPPED overlay stripped by rev 2.4. Mark resolved in the next session: no WCAG 1.4.11 contrast question remains since the chip no longer exists.

Files touched this pass: `design/gdd/damage-calc.md` (~30 edits), `design/registry/entities.yaml` (2 edits), `design/gdd/reviews/damage-calc-review-log.md` (this entry), `design/gdd/systems-index.md` (row #11 status bump — next), `production/session-state/active.md` (state reconciliation — next).

---

## Review — 2026-04-19 (sixth pass, fresh clean session) — Verdict: NEEDS REVISION

Scope signal: **M** (creative-director synthesis) — Priority-1 fixes require 2 user design decisions before mechanical work; total edit volume is S once decisions made, bumps to M due to cross-file coordination across damage-calc.md + unit-role.md + entities.yaml.
Specialists: qa-lead, godot-gdscript-specialist, ux-designer, game-designer, systems-designer + creative-director (senior synthesis) — full mode per skill default, overriding the `lean` production/review-mode.txt for this sixth-pass clean-session re-review.
Blocking items: 10 (2 CRITICAL requiring user design decisions) | Recommended: 9 | Nice-to-have: 5
Prior verdict resolved: **Partially** — rev 2.4's 10 blocker fixes held (flagged-MISS redesign is clean, `Engine.get_error_count()` fabrication fully removed, AC-DC-51(a) correctly dropped, ceiling-disclosure strip arithmetically sound); but 5 NEW blockers surfaced (3 of which had been latent in the document since rev 2.3 but were missed by 3 prior review rounds), + convergent registry propagation gaps from the rev 2.4 "atomic rename" that was not atomic.

### Summary

Clean-session sixth-pass full-mode review spawned 5 specialists in parallel + creative-director senior synthesis. **Primary positive signal:** the recursive fabrication trap is BROKEN — rev 2.4's flagged-MISS guard pattern (`push_error + ResolveResult.miss([&"invariant_violation:<reason>"])` + tests assert on `result.source_flags.has(&"<reason>")`) has zero dependency on any engine error-count API, any uninstalled addon matcher, or any fabricated project helper. AC-DC-19/21/22/28 are executable today on Godot 4.6 built-ins alone. This is a genuine pattern success — the rev 2.2 (fabricated helper) → rev 2.3 (fabricated Engine API) → rev 2.4 (break the cycle by moving the testable surface into ResolveResult) arc is complete. However, the review also surfaced a NEW failure mode that 5 prior passes missed: **numerical invariants stated in prose that do not hold under arithmetic** (creative-director process insight).

**CRITICAL blockers (convergent — game-designer flagged both):**

- **BLK-6-1 (Archer D_mult grid prose-vs-math contradiction)**: Derived D_mult table (line 530) shows ARCHER `FLANK=1.32`, `REAR=1.35`. Prose (lines 519-521) claims: "Scout peaks at REAR (1.65), Archer peaks at FLANK (1.32). Peaks are spatially disjoint." 1.35 > 1.32 — Archer's actual numerical peak is REAR, not FLANK. The rev 2.3 asymmetric-row change was explicitly justified as fixing Pillar-3 failure via FLANK-favored / REAR-penalized gradient, but the 0.90 class penalty on REAR does not overcome the 1.50 base REAR multiplier. Net D_mult still peaks at REAR. Rev 2.4 rewrote the rationale (drop false LoS claim) but did not verify the math delivers the FLANK-peak the rationale asserts. **Survived rev 2.3, rev 2.4, fifth-pass, and five specialists' reviews undetected** — the creative-director calls this out as a numerical-verification blind spot: reviewers read adjacent cells without ranking the row.
  - **Fix options (user design decision required)**: (a) raise CLASS_DIRECTION_MULT[ARCHER][FLANK] from 1.10 to ≥1.15 (Archer FLANK D_mult = 1.20 × 1.15 = 1.38, exceeds REAR=1.35); (b) lower [REAR] from 0.90 to ≤0.88 (REAR D_mult = 1.50 × 0.88 = 1.32, equals FLANK and would need further lowering to disjoint); (c) rewrite prose to accept REAR-peak Archer with a different Pillar-3 rationale.

- **BLK-6-2 (unit-role.md §CR-6a / §EC-7 cross-GDD desync)**: Source-of-truth owner for CLASS_DIRECTION_MULT (per damage-calc.md F-DC-4 "Locked tables — owned by unit-role.md §EC-7 lines 180-193; Damage Calc is a consumer, NOT an owner") still has **flat Archer** ×1.0/×1.0/×1.0 at unit-role.md:190. Rev 2.3's amendment was listed as a Phase 5 cross-system patch but is not merely housekeeping — it is a live contradiction between consumer and owner. An implementer reading both documents has no way to know which table to ship.
  - **Fix (user ownership-direction decision)**: either (a) update unit-role.md §CR-6a to the rev 2.3 asymmetric row (1.00/1.10/0.90, contingent on BLK-6-1 resolution updating the final numbers), or (b) revert damage-calc.md F-DC-4 Archer row to flat 1.00/1.00/1.00 matching the owning document, accepting that rev 2.3's Pillar-3 asymmetry fix rolls back.

**Other blockers (Priority 1 remaining):**

- **BLK-6-3 (systems-designer)**: TK-DC-3 `BASE_CEILING` safe range `[70, 90]` is arithmetically wrong. At BASE_CEILING=84: `floori(84 × 1.80 × 1.20) = floori(181.44) = 181 → clamped to DAMAGE_CEILING=180`. Values 84-90 silently activate the ceiling that CR-9 and A-8 call "unreachable in MVP primary paths." True upper bound is **83** (the current value). The rationale text's "~85 threshold" hedge is also wrong (correct is 84). Fix: narrow safe range to `[70, 83]`.

- **BLK-6-4 (godot-gdscript + systems-designer convergent)**: Registry (`design/registry/entities.yaml`) three propagation gaps from rev 2.4 "atomic rename": line 223 comment `attacker # {unit_id, class, ...}` (should be `unit_class`); line 229 comment `- BASE_CEILING # 100` (should be `# 83`); line 239 expression references `CLASS_DIRECTION_MULT[class]` (should be `[unit_class]`). Rev 2.4's atomic-rename claim demonstrably false.

- **BLK-6-5 (game-designer)**: Player Fantasy 2.16× vs V-2 popup annotation ×1.80 mismatch. Fantasy lines 23/39/55 anchor the Pillar-1 "verdict" on player reading 2.16×. V-2 HIT_DEVASTATING annotation (line 1223) shows `× 1.80` — D_mult only, omits P_mult=1.20. The component that required player SKILL (Charge passive) is invisible on the legibility surface. Either change popup spec to show combined multiplier or change fantasy anchor to 1.80× (but then Charge becomes invisible as a design signal).

**Priority-2 mechanical fixes (rev 2.5 sweep):**

- **BLK-6-6 (godot-gdscript)**: Lingering `class` references in GDD body — line 600-601 "Class guards" prose; line 1037 Dependencies table "Owns `class`"; table column headers at lines 489 and 525 (`| class | FRONT | FLANK | REAR |`). Atomicity failure same as BLK-6-4.
- **BLK-6-7 (ux-designer)**: Wrong WCAG citation — UI-4/UI-6/AC-DC-46 cite SC 2.2.1 "Timing Adjustable" (applies to ≥20s limits); correct is SC 2.3.3 "Animation from Interactions." Fifth-pass flagged, rev 2.4 missed.
- **BLK-6-8 (ux-designer)**: Broken a11y cross-reference — UI-4 points to `design/accessibility-requirements.md §Reduce-Motion`, target section does NOT exist. Actual headings are `§Reduced motion` (table row) + `§R-3` (section). Also one-way: a11y doc has zero mentions of damage-calc.
- **BLK-6-9 (qa-lead)**: AC-DC-25 per-push platform is "Linux Vulkan" (line 1809) but AC-DC-37/38/50 canonical baseline is macOS Metal. IEEE-754 residue test runs on different platform than designated ship-blocker baseline.
- **BLK-6-10 (ux-designer)**: `skill_unresolved` TalkBack announcement "<attacker> skill not yet implemented" ships internal stub copy as production-exposed player text. Needs either CI-lint prevention or player-facing copy standard.

**Recommended revisions (9)**: AC-DC-21/28 bypass-seam spec-incomplete (qa-lead); `direction_rel` type inconsistency StringName vs enum (godot-gdscript); snappedf claim unverified against engine-reference (godot-gdscript); push_error release/headless behavior (godot-gdscript); OS-bridging deferral Intermediate-tier gap (ux-designer); Scout/Infantry REAR=1.65 overlap (game-designer); Cavalry/Archer FLANK=1.32 overlap (game-designer); F-DC-6 output range text "synthetic bypass only" inline qualifier (systems-designer); TK-DC-3 "~85 threshold" text correction to "84" (systems-designer).

**Convergence pattern**: registry staleness and `class` rename incompleteness independently flagged by godot-gdscript AND systems-designer — strong confidence. Archer math defect flagged only by game-designer (the numerical-verification blind spot the creative-director called out). No direct disagreements between specialists surfaced.

**Creative-director process insight**: "BL-GM-1 (Archer math) surviving three passes undetected is the tell. Reviewers read the GDD as prose, not as spec — they compared adjacent cells rather than ranking the row. The recursive fabrication trap is the same failure inverted: reviewers trusted symbols that didn't exist. Both failures: **read the words, don't test the claim.** The document is standard GDD complexity; the review process is under-instrumented for numerical invariants." Recommended process fix: add a "numeric invariant check" phase to `/design-review` for any GDD with formula tables — reviewers must COMPUTE, not read.

### Outstanding

- **Rev 2.5 sweep in clean session** per creative-director pattern guidance: do NOT apply in the session that surfaced the defects. Rev 2.2/2.3 precedent shows in-session patching under fatigue introduces new defects — this is now 0-for-3 on same-session sweeps avoiding regression.
- **Two user design decisions required before rev 2.5 sweep**: (CR-1) Archer D_mult resolution (raise FLANK / lower REAR / rewrite prose); (CR-2) unit-role.md ownership direction (update owner to match consumer / revert consumer to match owner).
- **Rev 2.5 priority ordering** once decisions made: (1) apply Archer decision to damage-calc.md F-DC-4 table + rationale text + unit-role.md §CR-6a/§EC-7 coordinated commit; (2) narrow TK-DC-3 safe range to [70, 83]; (3) fix registry propagation gaps (entities.yaml lines 223/229/239); (4) finish `class` → `unit_class` rename (GDD body lines 489/525/600-601/1037); (5) fix WCAG citation SC 2.2.1 → SC 2.3.3 and xref §Reduce-Motion → §R-3 + add back-reference in a11y doc; (6) reconcile AC-DC-25 platform with AC-DC-37/38/50 baseline; (7) address TalkBack stub-copy shipping concern; (8) resolve 2.16× fantasy vs 1.80× popup annotation mismatch; (9) apply 9 recommended revisions as bandwidth permits.
- **Expected rev 2.5 scope**: **S** (text + 3 number changes + cross-file coordination) once the 2 design decisions are made. **Do NOT run rev 2.5 without the design decisions** — author-resolved Archer/unit-role would likely regress on a future review.
- **Phase 5 cross-system patches still pending** (unchanged from prior passes): unit-role.md Archer amendment now CRITICAL (BLK-6-2); ADR-0005 authoring; grid-battle.md typed-signature migration; entities.yaml `referenced_by` updates on 9 constants; grid-battle.md F-GB-PROV removal; back-references on turn-order.md / hp-status.md / terrain-effect.md / balance-data.md. Plus rev 2.4 items still open: DevOps story (CI matrix + headed UI job), engine-programmer story (build-mode sentinel), user action (gdUnit4 addon commit).
- **OQ-AUD-05** (logged rev 2.1): still deferred to Alpha audition.
- **OQ-VIS-03** (logged rev 2.3, marked MOOT in rev 2.4): status unchanged — CAPPED chip strip confirmed arithmetically sound; the base 4-popup-state contrast question persists but is owned by UI-4/AC-DC-47, not OQ-VIS-03 specifically.

### Positive signals (sixth-pass confirmation)

- Recursive fabrication trap is confirmed **BROKEN**: flagged-MISS guard pattern is clean. No fabricated APIs introduced this pass. No uninstalled addon dependencies on primary test surface.
- BASE_CEILING=83 Pillar-1 math verified correct: max Cavalry REAR+Charge=179 (59.67% HP_CAP), REAR-only=149, 30-pt peak differentiation holds.
- Scout REAR+Ambush at max ATK=157 — DAMAGE_CEILING does NOT fire on primary path (EC-DC-26 removal arithmetically sound).
- All 3 classes' non-Archer primary paths verified: Cavalry REAR+Charge=179, Scout REAR+Ambush=157, Infantry REAR=136. No ceiling activation on any real primary path at BASE_CEILING=83.
- Coverage Matrix body-vs-matrix reconciliation (BLK-7 rev 2.4) audits clean: 51 unique ACs, VS=35 (10+15+3+2+1+1+2+1), MVP=10, Beta=7. All match.
- AC-DC-51 post-rev-2.4 structure (b bypass-seam + c positive case) is logically sound — GDScript `in` operator semantics for StringName vs String confirmed correct.
- `OS.is_debug_build()` gate correctly removed from `skill_unresolved` TalkBack path per WCAG 2.1 SC 4.1.3.
- `class` → `unit_class` rename successful where applied (~70% complete based on grep; remaining sites documented in BLK-6-4/BLK-6-6).

Files touched this pass: `design/gdd/systems-index.md` (row #11 + header Last Updated), `design/gdd/reviews/damage-calc-review-log.md` (this entry). No edits to damage-calc.md or entities.yaml — rev 2.5 sweep deferred to fresh session per creative-director directive.

---

## Revision 2.5 Sweep Applied — 2026-04-19 — 10 sixth-pass blockers resolved

Scope: clean-session revision pass following the 2026-04-19 sixth-pass review's 10 blockers. Revision mode: collaborative with 2 user design decisions answered up front (CR-1 Archer D_mult resolution, CR-2 unit-role.md ownership direction). State drift pattern resolved: the sixth-pass review had already run in a prior session but `production/session-state/active.md` was stale — same drift as before the fifth-pass sweep.

### Design decisions adopted (before editing)

- **CR-1 (BLK-6-1 Archer D_mult prose-vs-math)**: Raise `CLASS_DIRECTION_MULT[ARCHER][FLANK]` from 1.10 → 1.15. Derived grid: FLANK `D_mult = 1.20 × 1.15 = 1.38`, REAR `1.50 × 0.90 = 1.35`. FLANK > REAR by 3 points — numerical peak now sits where the role-identity rationale places it. Rev 2.3/2.4 row produced FLANK=1.32 / REAR=1.35 which contradicted the rationale; the fifth-pass review did not catch this because "reviewers read adjacent cells without ranking the row" (creative-director sixth-pass process insight).
- **CR-2 (BLK-6-2 source-of-truth direction)**: Update `unit-role.md` §CR-6a Archer row to match damage-calc.md (1.00 / 1.15 / 0.90). Also propagated latent Infantry desync (flat ×1.0/×1.0/×1.0 in unit-role vs 0.90/1.00/1.10 in damage-calc) which had not been caught in prior passes. Both rows now consistent across consumer + owner documents.

### Blocker → fix summary

| # | Sixth-pass blocker | Rev 2.5 fix applied | Files touched |
|---|---|---|---|
| BLK-6-1 | Archer D_mult grid: prose claims FLANK-peak (1.32) but derived REAR=1.35 exceeds FLANK — rationale arithmetically false (survived 3 passes) | Raise `CLASS_DIRECTION_MULT[ARCHER][FLANK]` 1.10 → 1.15. Updated F-DC-4 CLASS table, derived D_mult table (Archer row 1.00 / 1.32 / 1.35 → 1.00 / 1.38 / 1.35), Archer asymmetry rationale expanded with numerical FLANK-peak guarantee block + do-not-revert note | damage-calc.md (F-DC-4 section ~3 edits) |
| BLK-6-2 | `unit-role.md` §CR-6a still has flat Archer ×1.0/×1.0/×1.0 — live contradiction with damage-calc consumer | Update unit-role.md §CR-6a Archer row to ×1.0/×1.15/×0.9 with role-identity rationale inline; also corrected latent Infantry desync (flat → 0.9/1.0/1.1 matching damage-calc) | unit-role.md §CR-6a table |
| BLK-6-3 | TK-DC-3 safe range `[70, 90]` arithmetically wrong — values 84-90 silently activate DAMAGE_CEILING (floori(84×1.80×1.20)=181>180) | Narrow safe range `[70, 90]` → `[70, 83]`; replace "~85 threshold" hedge with explicit 84+ ceiling-activation math; add "Below 70 →" lower-bound language | damage-calc.md (TK-DC-3 row) |
| BLK-6-4 | entities.yaml registry 3-site propagation gaps from claimed "atomic rename" (line 223 `class`, line 229 `# 100`, line 239 `[class]` expression) | Line 223 comment `class` → `unit_class`; line 229 `# 100` → `# 83 (rev 2.4 lowered 100→83 for Pillar-1 math)`; line 239 expression `[class]` → `[unit_class]` with guard-failure rewrite `unknown class` → `unknown unit_class` + flagged-MISS source_flags note; revised field bumped to 2026-04-19; notes extended; file header last_updated rewritten to record rev 2.5 | entities.yaml (4 edits + header) |
| BLK-6-5 | Player Fantasy 2.16× (Section B lines 23/39/55) vs V-2 popup annotation `× 1.80` mismatch — Charge invisible on primary legibility surface | V-2 Multiplier annotation rewritten: show combined `snappedf(D_mult × P_mult, 0.01)` (e.g., `× 2.16` for Cavalry REAR+Charge), matching Fantasy anchor. Pure-REAR no-passive reads `× 1.80`; EC-DC-9 synthetic bypass reads `× 2.48`. UI-2 full decomposition tooltip still available on demand | damage-calc.md (V-2 annotation block) |
| BLK-6-6 | Lingering `class` references in GDD body (line 600-601 "Class guards" prose; line 1037/1051 Dependencies "Owns `class`"; table column headers) | Class guards prose `class == CAVALRY` / `class ∈ {SCOUT, ARCHER}` → `unit_class == CAVALRY` / `unit_class ∈ {SCOUT, ARCHER}`; Dependencies table row "Owns `class`," → "Owns `unit_class` (rev 2.5 — renamed from `class`, GDScript 4.6 reserved keyword),"; F-DC-4 CLASS table header `\| class \|` → `\| unit_class \|`; derived D_mult table header same | damage-calc.md (F-DC-4 headers, CR-8 prose, Dependencies table row) |
| BLK-6-7 | WCAG citation SC 2.2.1 "Timing Adjustable" wrong (applies to ≥20s session limits); correct criterion for ≤2s popup animation is SC 2.3.3 "Animation from Interactions" | UI-4 Reduce Motion block: SC 2.2.1 → SC 2.3.3 with rationale explaining the criterion scope mismatch; UI-6 lifecycle bullet updated (removes inline 2.2.1, points to UI-4 for full citation); AC-DC-46 pass criteria updated with "WCAG 2.1 SC 2.3.3 'Animation from Interactions'" | damage-calc.md (UI-4, UI-6, AC-DC-46) |
| BLK-6-8 | Broken a11y cross-reference `§Reduce-Motion` does not exist in accessibility-requirements.md (actual §4 R-3 is Beat-2-specific); also one-way citation | UI-4 Reduce Motion xref `§Reduce-Motion` → `§4 R-3 (Beat 2 reduced-motion alternative, closest authoritative motion-reduction spec) + §2 "Reduced motion" toggle row`; added back-reference row in accessibility-requirements.md §7 System Dependencies for Damage/Combat Calculation (#11) with in-game Settings toggle activation note; bumped a11y doc to v1.1 with Review & Revision entry | damage-calc.md (UI-4 xref) + accessibility-requirements.md (§7 + §9) |
| BLK-6-9 | AC-DC-25 per-push platform "Linux Vulkan" contradicts AC-DC-37/38/50 canonical baseline macOS Metal | AC-DC-25 Test + Pass criteria rewritten — per-push runner now macOS Metal (matches AC-DC-37/38/50); Linux Vulkan + Windows D3D12 move to weekly + `rc/*` tag matrix. Explicit note documenting the prior rev 2.4 platform contradiction so re-reviewers see the reconciliation history | damage-calc.md (AC-DC-25) |
| BLK-6-10 | `skill_unresolved` TalkBack announcement ships internal stub copy `"<attacker> skill not yet implemented"` as production-exposed player text | Rewrite announcement to player-safe `"Skill unavailable"` across UI-4 affordance block and AC-DC-45 spec + pass criteria. Added CI-lint guard: static grep for `"not yet implemented"`, `"TODO"`, `"placeholder"`, `"stub"` in user-facing string literals within `damage_calc.gd` must return 0 matches. Internal `StringName &"skill_unresolved"` source_flag identifier is retained (programmatic identifier only — never surfaced to player) | damage-calc.md (UI-4 affordance; AC-DC-45 + pass criteria) |

### Files touched this pass
- `design/gdd/damage-calc.md` — ~12 edits across F-DC-4 (3), TK-DC-3 (1), V-2 (1), UI-4 (2), UI-6 (1), AC-DC-25 (1), AC-DC-45 (2), AC-DC-46 (1), CR-8 prose (1), Dependencies table (1), header Last Updated (1)
- `design/gdd/unit-role.md` — §CR-6a Archer row + Infantry row updated with rationale + rev 2.5 ratification note
- `design/registry/entities.yaml` — 4 edits (line 223 `class`→`unit_class`, line 229 `# 100`→`# 83`, line 239 expression uses `unit_class`, notes extended, revised bumped to 2026-04-19, file header last_updated rewritten)
- `design/accessibility-requirements.md` — §7 System Dependencies gains Damage/Combat Calculation row; §9 Review & Revision v1.1 entry appended
- `design/gdd/reviews/damage-calc-review-log.md` — this entry
- `design/gdd/systems-index.md` — row #11 status bump (next)
- `production/session-state/active.md` — state drift resolved + rev 2.5 recorded (next)

### Arithmetic verification (rev 2.5 sanity check before close)
- Cavalry REAR+Charge max ATK: `floori(83 × 1.80 × 1.20) = 179` ✓ (Pillar-1 peak, no change from rev 2.4)
- Cavalry REAR no Charge max ATK: `floori(83 × 1.80) = 149` ✓ (REAR-only anchor, no change)
- Archer FLANK max D_mult: `snappedf(1.20 × 1.15, 0.01) = 1.38` ✓ NEW peak anchor
- Archer REAR max D_mult: `snappedf(1.50 × 0.90, 0.01) = 1.35` ✓ below FLANK as rationale claims
- Archer FLANK max ATK (ATK=200, DEF=10, no passive): `floori(83 × 1.38) = 114` — below Scout REAR+Ambush peak (`floori(83 × 1.65 × 1.15) = 157`), preserves Scout-as-assassin identity
- BASE_CEILING=84 would activate clamp: `floori(84 × 1.80 × 1.20) = 181 > 180` ✓ confirms TK-DC-3 upper bound of 83
- BASE_CEILING=83 clamp cleared: `179 < 180` ✓ DAMAGE_CEILING stays silent defense-in-depth wall

### Outstanding (post rev-2.5)
- **Seventh-pass re-review in clean session recommended** per creative-director pattern (same-session sweeps are 0-for-4 at avoiding regression). Rev 2.5 is deliberately conservative — 2 user design decisions made up front, 8 mechanical/textual fixes, no new API surface or formula restructuring; regression risk is the lowest of any sweep to date.
- **Phase 5 cross-system patches still pending** (unchanged from rev 2.4 carry-over): `unit-role.md` Archer amendment is now DONE by rev 2.5 (merged CR-2 resolution). Still open: ADR-0005 authoring; grid-battle.md typed-signature migration; entities.yaml `referenced_by` updates on 9 constants; grid-battle.md F-GB-PROV removal; back-references on turn-order.md / hp-status.md / terrain-effect.md / balance-data.md. Rev 2.4 items still open: DevOps story (CI matrix + headed UI job), engine-programmer story (build-mode sentinel), user action (gdUnit4 addon commit).
- **OQ-AUD-05** (logged rev 2.1): still deferred to Alpha audition.
- **OQ-VIS-03** (logged rev 2.3, marked MOOT in rev 2.4): unchanged.
- **Sixth-pass recommended revisions (9)** not addressed this sweep: direction_rel StringName vs enum inconsistency, snappedf claim unverified against engine-reference, push_error release/headless behavior, OS-bridging deferral Intermediate-tier gap, Scout/Infantry REAR=1.65 overlap (still present — acceptable since same-tier classes can share peak value as long as spatial constraints differ), AC-DC-21/28 bypass-seam spec-incomplete, F-DC-6 output range inline qualifier, TK-DC-3 "~85 threshold" text (FIXED by BLK-6-3 work), Cavalry/Archer FLANK overlap (FIXED — Cavalry FLANK=1.32, Archer FLANK=1.38).

### Positive signals (rev 2.5 sweep design)
- Two user design decisions made BEFORE any editing (per skill's "group all design-decision questions" guidance). Zero mid-sweep author-resolved design calls.
- Arithmetic verified before closing the sweep (creative-director's "compute, don't read" process insight from sixth-pass applied pre-emptively).
- Zero new formulas, zero new ADRs, zero new OQs introduced this pass.
- Cross-file coordination (damage-calc.md ↔ unit-role.md ↔ entities.yaml ↔ accessibility-requirements.md) landed in a single sweep to avoid partial-propagation pattern that caused BLK-6-2 and BLK-6-4 to begin with.

---

## Review — 2026-04-19 (seventh pass, fresh clean session) — Verdict: NEEDS REVISION

Scope signal: **M** (8 mechanical/textual fixes + 2 design decisions; ~15 edit sites across damage-calc.md + possibly unit-role.md Archer row again; no new formulas).
Specialists: qa-lead, godot-gdscript-specialist, ux-designer, game-designer (lean 4-specialist per creative-director post-rev-2.2 guidance). Creative-director senior synthesis skipped per lean-mode rule.
Blocking items: 10 (2 require user design decisions) | Recommended: 11 | Nice-to-have: 6
Prior verdict resolved: **Yes — rev 2.5's 10 sixth-pass fixes all verified clean** (fabricated-API recursion remains broken; all arithmetic holds; `class`→`unit_class` rename complete; entities.yaml registry atomic; a11y cross-file bidirectional citation landed). However, 10 NEW blockers surfaced, of which 4 were LATENT in the document since earlier revisions but survived prior passes — same numerical-verification blind-spot pattern as BL-GM-1 (sixth pass).

### Summary

Clean-session seventh-pass lean 4-specialist review confirmed rev 2.5 as arithmetically and mechanically clean: three specialists independently verified Archer FLANK (1.38) > REAR (1.35) claim holds; qa-lead computed AC-DC-03/08/09 worked examples from first principles (all pass); Coverage Matrix TOTAL=51 and Release stage summary VS=35 / MVP=10 / Beta=7 verified. `push_error + ResolveResult.miss([&"invariant_violation:<reason>"])` flagged-MISS pattern is executable on Godot 4.6 built-ins with zero fabricated-API dependency — the rev 2.2→2.3→2.4 recursive fabrication trap remains permanently broken. However the review surfaced a 10-blocker set spanning four categories (stale cross-file propagation, untestable ACs, UX spec self-contradictions, Pillar-3 game-design failure). **Creative-director's sixth-pass process insight — "reviewers read words, don't test claims" — applied rigorously this pass, which is how the Archer-vs-Infantry Pillar-3 defect surfaced despite surviving six earlier passes.**

**BLOCKERs (10)**:

| # | Category | Source | Description | Fix |
|---|---|---|---|---|
| BLK-7-1 | Stale cross-patch | qa-lead | Cross-System Patches Queued item #2 (line ~2157) still reads Archer `1.00 / 1.10 / 0.90` — rev 2.5 raised FLANK to 1.15. Implementer following #2 would silently re-introduce BLK-6-1 (FLANK=1.32 < REAR=1.35). Live implementer trap. | Update item #2 to `1.00 / 1.15 / 0.90`; remove rev 2.3/2.4 history from the instruction text. |
| BLK-7-2 | Type inconsistency | godot-gdscript | `direction_rel` declared as `StringName` at lines 238/245/370 but as `enum {FRONT,FLANK,REAR}` at Variable Dictionary line 414. Guard `not in [&"FRONT",…]` incompatible with enum. Six passes, no canonical decision. | User design decision: pick enum (compile-time safety, int Dictionary keys) or StringName (current pseudocode idiom); propagate to all 4 sites + ACs. |
| BLK-7-3 | Untestable AC | qa-lead | AC-DC-46 frame-count assertion (93-95 frames at 60fps) is non-deterministic under xvfb-run — Godot does not vsync-lock in virtual-display environments. Always-fail or trivially-pass. | Rewrite as wall-clock delta (`Time.get_ticks_msec()` ≥1517ms AND ≤1583ms) OR document `Engine.max_fps = 60` lock in test harness. |
| BLK-7-4 | Untestable AC | godot-gdscript | AC-DC-51(b) bypass-seam impossible — GDScript 4.6 enforces `Array[StringName]` inner type at field assignment; Variant coercion is not an available bypass path. | Redesign: call `passive_multiplier()` directly with untyped Array via test proxy, OR drop (b) with rationale that StringName literal is the sole runtime defense. |
| BLK-7-5 | Untestable AC | qa-lead | AC-DC-21/28 "bypass seam that lets test set an invalid enum int directly" under-specified. `Object.set()` typed-property bypass is engine-version-sensitive and unverified for Godot 4.6. | Cite exact mechanism + engine-reference, or use test-only RefCounted subclass. |
| BLK-7-6 | Spec self-fail | ux-designer | AC-DC-47 opacity delta: criterion requires `≥15%` between tiers, but HIT_NORMAL 55% → HIT_DIRECTIONAL 45% = 10%. Monochrome distinguishability test will fail on first run. | Raise DIRECTIONAL backing to ≥60% OR lower AC threshold to ≥10%. |
| BLK-7-7 | A11y regression | ux-designer | V-3 queue rule (second resolve cuts first to 80ms fade) vs UI-4 Reduce Motion 1200ms hold. AoE interrupts erase the mandated accessibility reading window — direct regression for the population the 1200ms is meant to serve. | Add Reduce-Motion exception to queue rule OR define replacement policy. |
| BLK-7-8 | Pillar-1 legibility | ux-designer | V-2 multiplier annotation restricted to HIT_DEVASTATING — HIT_DIRECTIONAL tier (which the Scout REAR+Ambush combined=1.90 and Archer FLANK=1.38 hits inhabit) receives no annotation. Charge/Ambush invisible on primary surface for sub-DEVASTATING hits. | Extend annotation to HIT_DIRECTIONAL or document the tier-gating rationale. |
| BLK-7-9 | Pillar-3 failure | game-designer | Archer max raw damage = 114 (FLANK); Infantry max raw damage = 136 (REAR, no passive). Dedicated damage role prints 22 points less than tank role. Section B guarantee "identical ATK on Scout vs Infantry produces visibly different outputs" also failed (both 136 at REAR-no-Ambush). Archer is only class locked out of HIT_DEVASTATING tier entirely (peak D_mult=1.38 < threshold 1.50). | User design decision: add third passive (Volley / Precision) gated on FLANK, OR raise ARCHER FLANK class-mod to ≥1.375 so D_mult ≥1.65. Also address Scout/Infantry REAR=1.65 overlap. |
| BLK-7-10 | Pillar-3 expression | game-designer | Archer FLANK (1.38) vs REAR (1.35) = 0.03 delta. At BASE=83: 114 vs 112 raw = 2 points = combat noise. Compare Cavalry REAR-vs-FLANK = 40 points, Scout = 37 points. FLANK-peak is arithmetically true but experientially inert. | Widen spread (e.g., FLANK 1.20+, REAR 0.85) so peak is felt, not just computed. Likely bundles with BLK-7-9 fix. |

**Recommended Revisions (11)** — convergent pair: `push_error` in export builds writes to `user://logs/godot.log` not editor log (qa-lead + godot-gdscript) affects AC-DC-19/21/22/28/45 pass-criteria text; WCAG SC 2.3.3 is AAA but project tier is Intermediate/AA — overstates contract; V-3 HIT_DEVASTATING baseline hold 600ms (V-3 table) vs 800ms (UI-4 text ghost value); TalkBack AoE throttle has no selection policy; `"Skill unavailable"` CJK width — Korean ~3-4s TTS exceeds 500ms throttle; text scaling 200% = 84sp no clamp; a11y §2 "Reduced motion" scope doesn't list popup drift; Player Fantasy "2.16× integer resolves" vs actual ratio 2.13 conflates annotation with damage ratio; D-3 commentary "2.13x from positioning alone" wrong (Charge isn't positioning); AC-DC-45 CI-lint scope limited to damage_calc.gd; Scout/Infantry REAR=1.65 contradicts Section B identical-ATK guarantee.

**Nice-to-have (6)**: Archer zero worked examples as attacker (add one for BL-GM-1 regression coverage); HIT_DEVASTATING display-tier lockout for Archer; AC-DC-38 + AC-DC-50 duplicate assertion could merge; TK-DC-1 blast-radius references D-9 (no-Charge) incorrectly; AttackerContext sketch missing top-of-file `class_name` declaration; UI-3 emoji 🛈 in spec (project style bans).

**Convergence signals**:
- qa-lead + godot-gdscript BOTH independently flagged `push_error` export-build log-location issue — strong confidence.
- qa-lead BLK-7-4 + godot-gdscript BLK-7-2 are the same finding (AC-DC-51 Variant coercion untestable) at different severity — taken BLOCKER severity per godot-gdscript.
- **New failure mode confirmed**: 4 of 10 new blockers (direction_rel type, AC-DC-47 opacity, V-3 queue conflict, Archer Pillar-3) were LATENT since rev 2.3 or earlier but survived six review passes. Same blind-spot pattern as BL-GM-1: reviewers read adjacent claims without cross-verifying against downstream consequence or numerical rank.

**Positive signals (what held)**:
- Rev 2.5's 10 fixes all verified clean by independent specialists.
- Arithmetic hold: Archer FLANK=1.38, REAR=1.35, FLANK > REAR confirmed; AC-DC-03/08/09 computed from first principles by qa-lead all match stated expected values; V-2 annotation × 2.16 = snappedf(1.80 × 1.20, 0.01) confirmed.
- Recursive fabrication trap remains BROKEN — no fabricated APIs introduced this pass; flagged-MISS pattern executes on Godot 4.6 built-ins alone.
- Coverage Matrix counts verified (TOTAL=51; VS=35; MVP=10; Beta=7).
- Cross-file bidirectional citations (damage-calc.md ↔ accessibility-requirements.md ↔ unit-role.md ↔ entities.yaml) audit clean — partial-propagation pattern that caused BLK-6-2/6-4 is genuinely resolved for the rev 2.5 fix set.

### Outstanding

- **Rev 2.6 sweep in clean session** per creative-director pattern guidance (same-session sweeps 0-for-4 at avoiding regression; rev 2.5 was the closest clean pass but still produced 10 new-latent findings). Do NOT revise in the session that surfaced the defects.
- **Two user design decisions required before rev 2.6 sweep**:
  - **CR-7-1 (BLK-7-2)**: `direction_rel` canonical type — StringName (matches F-DC-1/pseudocode) or enum (compile-time safety). If enum: `Direction.FRONT/FLANK/REAR`, Dictionary keys become int, guard becomes `modifiers.direction_rel not in Direction.values()`, AC-DC-22 invalid-sentinel updates. If StringName: update Variable Dictionary line 414 type annotation.
  - **CR-7-2 (BLK-7-9)**: Archer Pillar-3 fix — (a) add third passive (Volley: Archer+FLANK, 1.15-1.20× multiplier) OR (b) raise ARCHER FLANK class-mod to ≥1.375 (peaks class at ≥136 to match Infantry REAR) OR (c) rewrite Section B Player Fantasy to concede Archer's role is mobility/range not raw damage. Also determine Scout/Infantry REAR=1.65 resolution (keep or separate numerically).
- **Rev 2.6 priority ordering** once decisions made: (1) BLK-7-1 stale cross-patch update (1-line edit, prevents implementer trap); (2) BLK-7-2 direction_rel type propagation (~4 sites); (3) BLK-7-9 + BLK-7-10 Archer Pillar-3 resolution (F-DC-4 table + derived grid + rationale + unit-role.md §CR-6a; possibly entities.yaml CLASS_DIRECTION_MULT + passive registration); (4) BLK-7-3 AC-DC-46 wall-clock rewrite; (5) BLK-7-4/5 AC-DC-51/21/28 bypass-seam spec tightening; (6) BLK-7-6 AC-DC-47 opacity reconciliation; (7) BLK-7-7 V-3 Reduce-Motion exception clause; (8) BLK-7-8 V-2 annotation tier extension; (9) apply 11 recommended revisions as bandwidth allows.
- **Expected rev 2.6 scope**: **M** (text + number edits across ~15 sites + cross-file coordination if BLK-7-9 picks option (a) or changes unit-role.md numbers).
- **Phase 5 cross-system patches still pending** (unchanged from rev 2.5 carry-over): ADR-0005 authoring; grid-battle.md typed-signature migration; entities.yaml `referenced_by` updates on 9 constants; grid-battle.md F-GB-PROV removal; back-references on turn-order.md / hp-status.md / terrain-effect.md / balance-data.md. DevOps story (CI matrix + headed UI job). Engine-programmer story (build-mode sentinel). User action (gdUnit4 addon commit). **NEW rev 2.6 prerequisite**: Cross-System Patches Queued #2 must be corrected before it is actioned by implementer.
- **OQ-AUD-05** (logged rev 2.1): still deferred to Alpha audition.
- **OQ-VIS-03** (logged rev 2.3, moot since rev 2.4): unchanged.

### Process insight — same-session revision remains 0-for-4 at avoiding regression

Rev 2.5 was the cleanest sweep to date: 2 user design decisions up front, 10 targeted fixes, no new formulas/ADRs/OQs, cross-file coordination atomic, arithmetic verified pre-close. It still produced 10 new-latent blockers under a fresh lean 4-specialist re-review — because 4 of those blockers (direction_rel type, AC-DC-47 opacity, V-3 queue conflict, Archer Pillar-3) were already in the document when prior sweeps ran and none of the 5 prior full-mode reviews caught them. **This is not a revision-quality problem; it is a review-process instrumentation gap for numerical-invariants and cross-cell-consequence claims.** Creative-director's sixth-pass fix — "compute, don't read" — surfaced Pillar-3 Archer defect this pass because the reviewer computed 4-class raw-damage peaks from first principles rather than reading the derived grid. Similar discipline applied to UX spec self-consistency (AC-DC-47 delta computation) and cross-file implementer-trap detection (Cross-System Patches item #2) surfaced those defects too. Recommendation: keep the "compute every numerical claim" discipline as a persistent process rule for damage-calc re-reviews.

### Files touched this pass
- `design/gdd/systems-index.md` — row #11 status + header Last Updated
- `design/gdd/reviews/damage-calc-review-log.md` — this entry
- No edits to damage-calc.md, unit-role.md, entities.yaml, or accessibility-requirements.md — rev 2.6 sweep deferred to fresh session per creative-director directive.

---

## Revision 2.6 Sweep Applied — 2026-04-19 — 10 seventh-pass blockers resolved

Scope: clean-session revision pass following the 2026-04-19 seventh-pass review's 10 blockers. Session-state drift (third occurrence) detected at the top of this session: prior session ran the seventh-pass review and updated systems-index + review log but did NOT update `production/session-state/active.md`. State drift surfaced to user; 2 user design decisions collected up-front via `AskUserQuestion` before any edits per creative-director "group all design-decision questions into a single multi-tab widget" discipline.

### Design decisions adopted (before editing)

- **CR-7-1 (BLK-7-2 direction_rel canonical type)**: `StringName` (matches F-DC-1 pseudocode guard `not in [&"FRONT", &"FLANK", &"REAR"]` and the `ResolveModifiers.direction_rel: StringName` declaration at §CR-1; consistent with project pattern for `source_flags`, `passives`, `vfx_tags`). Variable Dictionary line 414 updated — zero formula change, zero AC change.
- **CR-7-2 (BLK-7-9/10 Archer Pillar-3 fix)**: Raise `CLASS_DIRECTION_MULT[ARCHER][FLANK]` from 1.15 → 1.375. Derived D_mult = `snappedf(1.20 × 1.375, 0.01) = 1.65`. REAR unchanged at 1.35. Spread = 30 pts (vs rev 2.5's 3 pts "arithmetically-true-but-experientially-inert"). FLANK peak enters HIT_DEVASTATING tier (D_mult > 1.50). Archer FLANK+Ambush at max ATK=200 = `floori(83 × 1.65 × 1.15) = 157` (matches Scout REAR+Ambush numerical anchor via distinct spatial position). Archer FLANK no-passive = `floori(83 × 1.65) = 136` (matches Infantry REAR no-passive — no longer *below* the tank role). Option (a) new Volley passive rejected as adding new formula/registry surface; option (c) Player-Fantasy rewrite rejected as contradicting Pillar-3 framing.

### Blocker → fix summary

| # | Seventh-pass blocker | Rev 2.6 fix applied | Files touched |
|---|---|---|---|
| BLK-7-1 | Cross-System Patches Queued #2 still cites stale `1.00 / 1.10 / 0.90` Archer row — rev 2.5 raised FLANK to 1.15, rev 2.6 now raises to 1.375; implementer following #2 would silently regress BLK-6-1 and BLK-7-9 both | Updated item #2 to canonical rev 2.6 endpoint `1.00 / 1.375 / 0.90`; removed rev 2.3/2.4 stale history; added explicit "do NOT regress to any prior row" list citing arithmetic defect for each (flat / 1.15 rev 2.5 / 1.10 rev 2.3/2.4). Also confirms Infantry row 0.90/1.00/1.10 must be verified against both docs. | damage-calc.md (Cross-System Patches #2) |
| BLK-7-2 | `direction_rel` declared `StringName` at §CR-1/F-DC-1/ResolveModifiers (4 sites) but `enum {FRONT, FLANK, REAR}` at Variable Dictionary line 414 — type inconsistency undetected through 6 passes | Variable Dictionary line 414 updated to `StringName` with allowed-literals callout + cross-reference to F-DC-1 guard logic + project-pattern rationale. Zero formula/AC change; pseudocode and guards were already correct. | damage-calc.md (Variable Dictionary line 414) |
| BLK-7-3 | AC-DC-46 frame-count assertion (93–95 frames at 60fps) non-deterministic under `xvfb-run` — Godot doesn't vsync-lock in virtual-display environments; test is always-fail or trivially-pass depending on runner load | Rewrote pass criteria to **wall-clock deltas** via `Time.get_ticks_msec()` snapshots: total lifecycle 1517–1583ms (1550ms ± 33ms), hold phase 1167–1233ms (1200ms ± 33ms). Added test-harness setup that forces `Engine.max_fps = 60` + `Engine.physics_ticks_per_second = 60` to bound scheduling jitter. Assertions are now Time-delta-based, not frame-count-based — vsync behavior irrelevant. | damage-calc.md (AC-DC-46 pass criteria) |
| BLK-7-4 | AC-DC-51(b) bypass-seam "factory that skips type-checking" is fictitious — GDScript 4.6 enforces `Array[StringName]` inner type at field assignment AND at Variant coercion paths | Redesigned (b) as **direct-call bypass-seam**: test exposes `_passive_multiplier_for_test` callable accepting an external `passives` Array parameter (bypasses AttackerContext construction entirely). Inside callable, the StringName-literal guard `&"passive_charge" in passives_arg` returns false for String-array input — proving the production defense is the literal, not the type system. (c) positive case unchanged. | damage-calc.md (AC-DC-51 pass criteria) |
| BLK-7-5 | AC-DC-21/28 "bypass seam that lets test set an invalid enum int directly" under-specified; `Object.set()` on typed property is Godot-4.6-version-sensitive and unverified | Cited concrete mechanism: **test-only RefCounted subclass** `TestAttackerContextBypass extends AttackerContext` that redeclares `unit_class` as `int` (shadows parent's typed field). For AC-DC-28: analogous `TestResolveModifiersBypass` subclass. Files live in `tests/helpers/`; CI grep-lint prevents production instantiation (0 matches under `src/`, 1+ matches under `tests/`). | damage-calc.md (AC-DC-21, AC-DC-28 pass criteria) |
| BLK-7-6 | AC-DC-47 opacity delta criterion `≥15%` self-fails at HIT_NORMAL 55% → HIT_DIRECTIONAL 45% = 10%; test always-fail on first run | Lowered threshold to **≥10%** with rationale: V-1 intentionally uses non-monotonic opacity (DIRECTIONAL 45% < NORMAL 55% because the 청회 blue number carries glyph-level contrast; DEVASTATING 80% inverse stresses weight, not hue); forcing monotonic would erase design semantics. Size remains the **primary** distinguishing channel (6/6/8px tier-to-tier deltas guarantee distinguishability even if opacity were identical). QA lead sign-off now explicitly confirms non-monotonic DIRECTIONAL reads as intentional. | damage-calc.md (AC-DC-47 pass criteria) |
| BLK-7-7 | V-3 queue rule (second resolve cuts prior to 80ms fade) nullifies UI-4 Reduce Motion 1200ms hold on AoE — direct accessibility regression for the population the hold is meant to serve | Added **Reduce Motion queue exception**: under Reduce Motion, subsequent resolves queue sequentially (max 3 pending), each waits for prior's full 1550ms lifecycle before spawning. Queue overflow drops the oldest pending popup silently (tier swell + screen-reader announcement still emit). Tradeoff: slower sequential damage numbers during AoE instead of blurred cuts — correct per WCAG 2.1 SC 2.3.3 ("non-essential motion must be controllable"). Hard ceiling updated to 1550ms per queued popup under Reduce Motion. | damage-calc.md (V-3 queue rule block) |
| BLK-7-8 | V-2 multiplier annotation restricted to HIT_DEVASTATING (D_mult > 1.50) hides Charge/Ambush contributions on HIT_DIRECTIONAL tier hits (Archer REAR combined 1.35; Cavalry FLANK combined 1.32) | Extended annotation to **HIT_DEVASTATING + HIT_DIRECTIONAL** (both tiers with non-trivial combined multiplier). Only HIT_NORMAL (combined ≤ 1.20) and MISS suppress the annotation. Added canonical examples across both tiers (pure 1.35/1.32 direction-only hits now show × annotation; Scout REAR+Ambush combined 1.90 DEVASTATING unchanged; Archer FLANK no-passive combined 1.65 now DEVASTATING post rev 2.6 — covered automatically). | damage-calc.md (V-2 multiplier annotation block) |
| BLK-7-9 | Pillar-3 failure: Archer max raw damage (114, FLANK rev 2.5) prints 22 points below Infantry max (136, REAR no-passive) — dedicated damage role < tank role | Raised ARCHER FLANK class-mod 1.15 → 1.375 (D_mult 1.20×1.375=1.65). Updated F-DC-4 CLASS table, derived D_mult grid (Archer row 1.00/1.38/1.35 → 1.00/1.65/1.35), rationale block (role-identity FLANK specialist framing; HIT_DEVASTATING tier reach; Pillar-3 peak hierarchy Cavalry 179 > Scout/Archer 157 > Infantry 136). Archer FLANK+Ambush max = 157 ≥ Infantry REAR no-passive max = 136 — dedicated damage role > tank role at optimal play. Also updated unit-role.md §CR-6a Archer row + rationale to match. | damage-calc.md (F-DC-4 3 sites), unit-role.md (§CR-6a Archer row) |
| BLK-7-10 | Archer FLANK vs REAR = 2 pts spread at base=83 (combat noise) — Pillar-3 role identity arithmetically true but experientially inert | Addressed by BLK-7-9 fix: FLANK (1.65) − REAR (1.35) = 0.30 spread → at base=83, raw diff is 24 pts (136 vs 112). Experiential threshold met. Prior 2-pt noise floor eliminated. | damage-calc.md (F-DC-4 derived grid text) |

### Arithmetic verification (rev 2.6 sanity check — computed pre-close per creative-director "compute, don't read" discipline)

- **Cavalry apex** REAR+Charge max ATK: `floori(83 × 1.80 × 1.20) = 179` ✓ (unchanged from rev 2.5 — Pillar-1 peak preserved)
- **Cavalry REAR no Charge** max ATK: `floori(83 × 1.80) = 149` ✓ (unchanged)
- **Archer FLANK no-passive** max ATK: `floori(83 × 1.65) = floori(136.95) = 136` ✓ (matches Infantry REAR anchor)
- **Archer FLANK + Ambush** max ATK: `floori(83 × 1.65 × 1.15) = floori(157.49) = 157` ✓ (matches Scout REAR+Ambush; Pillar-3 peak parity at optimal play)
- **Archer REAR** max ATK: `floori(83 × 1.35) = 112` ✓ (combat-noise floor; 24 pts below FLANK)
- **Archer FLANK D_mult > HIT_DEVASTATING threshold** (D_mult > 1.50): `1.65 > 1.50` ✓ (tier reach confirmed)
- **Scout REAR+Ambush** max ATK: `floori(83 × 1.65 × 1.15) = 157` ✓ (unchanged; numerical parity with Archer FLANK+Ambush intentional)
- **Infantry REAR no-passive** max ATK: `floori(83 × 1.65) = 136` ✓ (unchanged; Pillar-3 tank baseline)
- **DAMAGE_CEILING=180 stays silent** on all rev 2.6 primary paths: Archer FLANK+Ambush 157 < 180; Scout REAR+Ambush 157 < 180; Cavalry REAR+Charge 179 < 180 ✓
- **V-2 combined-multiplier annotation examples**: Cavalry REAR+Charge `snappedf(1.80×1.20, 0.01) = 2.16` ✓; pure Cavalry REAR = 1.80; Archer FLANK no-passive = 1.65; Cavalry FLANK no-passive = 1.32; Archer REAR = 1.35; dual-passive synthetic bypass (EC-DC-9) = `snappedf(1.80×1.38, 0.01) = 2.48` ✓
- **AC-DC-47 opacity deltas under new ≥10% threshold**: NORMAL 55% ↔ DIRECTIONAL 45% = 10% pass; DIRECTIONAL 45% ↔ DEVASTATING 80% = 35% pass; DEVASTATING 80% ↔ MISS 0% = 80% pass ✓
- **AC-DC-46 wall-clock tolerances**: 1550ms ± 33ms covers full 60fps frame (16.67ms × 2 = 33.3ms) ✓

### Files touched this pass

- `design/gdd/damage-calc.md` — ~12 edits: F-DC-4 CLASS table Archer row (1), F-DC-4 Archer rationale block (1 major rewrite across 3 paragraphs: role-identity framing + Numerical FLANK-peak guarantee + Pillar-3 peak hierarchy), F-DC-4 derived D_mult grid Archer row + anchor text (1), Variable Dictionary `direction_rel` type (1), V-2 multiplier annotation tier extension (1), V-3 queue rule Reduce Motion exception (1), AC-DC-46 wall-clock rewrite (1), AC-DC-47 opacity threshold + rationale (1), AC-DC-51 (b) direct-call bypass-seam (1), AC-DC-21 bypass-seam mechanism (1), AC-DC-28 bypass-seam mechanism (1), Cross-System Patches Queued #2 stale-row correction (1), header Last Updated (1).
- `design/gdd/unit-role.md` — §CR-6a Archer row (1.00 / 1.375 / 0.90) + rationale block expansion (role-identity framing; rev 2.5→2.6 history; max-ATK peak math 136/157; Pillar-3 promise satisfaction).
- `design/gdd/reviews/damage-calc-review-log.md` — this entry.
- `design/gdd/systems-index.md` — row #11 status bump (next) + header Last Updated.
- `production/session-state/active.md` — state drift resolved + rev 2.6 recorded (next).

### Outstanding (post rev-2.6)

- **Eighth-pass re-review in clean session recommended** per creative-director pattern (same-session sweeps remain 0-for-4 at avoiding regression; rev 2.5 was the cleanest yet and still produced 10 new/latent blockers under fresh lean 4-specialist re-review). Rev 2.6 is **S** scope (2 design decisions made up front, 10 targeted fixes, no new formulas/registry constants/ADRs/OQs, cross-file coordination atomic across damage-calc.md + unit-role.md, arithmetic verified pre-close). Regression risk is the lowest of any sweep to date.
- **Phase 5 cross-system patches unchanged** from prior passes: ADR-0005 authoring, grid-battle.md typed-signature migration + F-GB-PROV removal, entities.yaml `referenced_by` updates on 9 constants, back-references on turn-order.md / hp-status.md / terrain-effect.md / balance-data.md, DevOps story (CI matrix + headed UI job), engine-programmer story (build-mode sentinel), user action (gdUnit4 addon commit). **BLK-7-1 Cross-System Patches #2 update** means future implementer reading that list will now ship the correct Archer row — the stale-cross-patch trap is closed.
- **Seventh-pass recommended revisions (11)** not addressed this sweep (bandwidth-deferred per skill "blocker priority only" discipline): push_error export-build log-location text (convergent qa-lead + godot-gdscript), WCAG SC 2.3.3 AAA-vs-Intermediate-tier overstatement, V-3 HIT_DEVASTATING 600ms-vs-800ms ghost value, TalkBack AoE throttle selection policy, `"Skill unavailable"` CJK width TTS overflow, text scaling 200% clamp, a11y §2 "Reduced motion" scope, Player Fantasy 2.16× vs 2.13 ratio conflation, D-3 "2.13x from positioning alone" wrong (Charge isn't positioning), AC-DC-45 CI-lint scope, Scout/Infantry REAR=1.65 Section B overlap note. Eligible for rev 2.7 bandwidth if eighth-pass surfaces them as BLOCKER-tier.
- **Seventh-pass nice-to-have (6)** not addressed: Archer worked example addition (regression coverage for BL-GM-1 Archer math), HIT_DEVASTATING display-tier Archer lockout (auto-resolved by rev 2.6 FLANK=1.65 reaching DEVASTATING — verification required eighth-pass), AC-DC-38 + AC-DC-50 duplicate-assertion merge, TK-DC-1 blast-radius D-9 reference, AttackerContext top-of-file `class_name` declaration, UI-3 🛈 emoji project-style compliance.
- **OQ-AUD-05** (logged rev 2.1): still deferred to Alpha audition.
- **OQ-VIS-03** (logged rev 2.3, moot since rev 2.4): unchanged.

### Positive signals (rev 2.6 sweep design)

- Two user design decisions made BEFORE any editing per skill discipline — zero mid-sweep author-resolved design calls.
- Arithmetic verified with explicit computation before closing the sweep — not read off the page. Creative-director's sixth-pass "compute, don't read" process insight applied pre-emptively. 10 distinct arithmetic checks performed, all pass.
- Zero new formulas, zero new ADRs, zero new OQs, zero new registry constants introduced.
- Cross-file coordination (damage-calc.md ↔ unit-role.md) landed atomically to avoid the partial-propagation pattern that caused BLK-6-2 and BLK-7-1.
- Fabricated-API recursion trap remains confirmed BROKEN — rev 2.6 introduced only test-only RefCounted subclasses (AC-DC-21/28) and direct-call bypass seams (AC-DC-51), both of which are standard Godot 4.6 patterns, not fabricated surfaces.
- BLK-7-1 stale Cross-System-Patches entry closed proactively (was not caught by sixth-pass review even though it has been stale since rev 2.3) — future implementer-trap eliminated.

---

## Review — 2026-04-19 — Verdict: NEEDS REVISION (eighth pass) → Resolved in-session (rev 2.7 + rev 2.8)

Scope signal: M (rev 2.7 single-edit + rev 2.8 multi-doc Rally-ceiling fix sweep)
Specialists: qa-lead, godot-specialist, ux-designer, game-designer, systems-designer (5-spec lean + systems-designer added because rev 2.7 just landed)
Blocking items: 1 CRITICAL (game-designer + systems-designer convergent) + 4 supporting | Recommended: 5+ (carry from seventh-pass)
Prior verdict resolved: Yes — rev 2.7 named obligation closed (F-DC-5 rally_bonus extension); however rev 2.7 introduced new Pillar-1+3 regression that eighth-pass caught.

### Pass arc
Eighth-pass began as scheduled re-review of rev 2.6 + verification of rev 2.7 (F-DC-5 rally_bonus extension applied 2026-04-19 from Grid Battle pass-11c CR-15 named obligation). Five specialists in parallel returned: 1 APPROVED (godot-specialist — engine APIs all real), 3 CONCERNS (qa-lead header staleness + missing test; ux-designer V-3 ghost value 800ms vs 600ms; systems-designer convergent on Rally-ceiling regression), 1 NEEDS REVISION (game-designer convergent on Rally-ceiling regression).

**CRITICAL convergent finding (game-designer + systems-designer, computed independently):**
- Cavalry REAR+Charge+Rally(+15%) at max ATK: `floori(83 × 1.80 × 1.20 × 1.15) = 206` → DAMAGE_CEILING=180 fires
- Archer FLANK+Ambush+Rally(+15%): `floori(83 × 1.65 × 1.15 × 1.15) = 181` → ceiling fires
- Scout REAR+Ambush+Rally(+15%): identical 181 → ceiling fires
- All three apex damages collapse to 180 = ceiling under full Rally
- Pillar-1 Cavalry apex differentiation: 30pt (no Rally) → 9pt (Rally) — degraded
- Pillar-3 hierarchy collapse: Cavalry = Archer = Scout = 180
- Rev 2.4's claim "ceiling never fires in normal play" became false the moment rev 2.7 landed
- This re-introduced exactly the ceiling-opacity Pillar-1 violation that BLK-5-3/rev 2.2 was designed to eliminate

### User design adjudication (B-8-1)
User selected "cap Rally + reduce Cavalry REAR multiplier" path. Systems-designer derived precise tuple via constraint optimization:
- Binding constraint: Archer FLANK+Ambush at max Rally must stay <180 → Rally cap ≤ +14% (chose +10% for clean integer)
- Cavalry REAR+Charge at +10% Rally must stay <180 → CLASS_DIRECTION_MULT[CAVALRY][REAR] = 1.09 (D_mult=1.64)
- Verification: all 12 apex cells (4 classes × Rally 0/+5%/+10%) <180; Cavalry leads by ≥5pt at all states; Pillar-1 differentiation 27-30pt across all states

### Apex damage table (rev 2.8 — verified pre-close)

| Class + optimal combo | R=0% | R=+5% | R=+10% (cap) |
|---|---|---|---|
| **Cavalry REAR+Charge** | **163** | **171** | **179** |
| **Archer FLANK+Ambush** | **157** | **165** | **174** |
| **Scout REAR+Ambush** | **157** | **165** | **174** |
| **Infantry REAR (no passive)** | **136** | **143** | **150** |

All <180. Cavalry leads at all states. Pillar 1+3 preserved.

### Fixes applied (rev 2.8 — atomic cross-file sweep)

**damage-calc.md (~9 edits)**:
- F-DC-4 CLASS_DIRECTION_MULT table: CAVALRY REAR 1.20 → 1.09
- F-DC-4 derived D_mult grid: CAVALRY REAR 1.80 → 1.64
- F-DC-4 Pillar-3 peak hierarchy note rewritten with rev 2.8 12-cell table values
- CR-6 rationale sentence updated with rev 2.8 arithmetic
- CR-9 ceiling rationale updated (180 ceiling unreachable under +10% Rally cap)
- F-DC-6 expected-range stanza updated (raw ∈ [1, 179] holds under all Rally states)
- D-3 worked example updated (D_mult 1.80→1.64; result 64→59; "from positioning alone" replaced with explicit D_mult × P_mult breakdown — addresses seventh-pass deferred R-8-3)
- D-4 worked example updated (max ATK + Rally cap; result still 179)
- AC-DC-04 updated with rev 2.8 arithmetic
- Player Fantasy section: 2.16× references → 1.97× (no-Rally) with note that Rally cap restores 2.16× via D_mult × P_mult composition
- V-2 canonical examples: × 2.16 → × 1.97 (Cavalry REAR+Charge no-Rally), × 1.80 → × 1.64 (pure Cavalry REAR)
- Header bumped rev 2.6 → rev 2.8 with full eighth-pass + rev 2.8 summary

**grid-battle.md (~5 edits)**:
- CR-15 rule 4 stacking: cap +15% → +10%, formula min(0.15,…) → min(0.10,…), Two Commanders cap (was Three)
- CR-15 rule 7 AI awareness: rally_bonus_active range 0.0-0.15 → 0.0-0.10
- CR-15 Purpose (Pillar 3): 3-Commander cap (15%) → 2-Commander cap (10%)
- CR-14 strategist-affordance ref: ±15% cap → +10% cap
- AC-GB-27 sub-cases (b) and (c): 0.10/0.15 → 0.10/0.10 (cap reached at 2 commanders)

**unit-role.md (~3 edits)**:
- CR-2 Commander Rally row: min(0.15,…) → min(0.10,…); cap +15%/3 commanders → +10%/2 commanders
- EC-12 Rally Stacking Cap title + body: "3+ Commanders" → "2+ Commanders"; min(15,…) → min(10,…); cap 15 → 10
- Tuning Knobs Rally cap row: 15% → 10% (rev 2.8) with safe range adjustment 5%-15%
- §CR-2a (or equivalent) "Cavalry REAR + Charge = ×2.16" → "×1.97 (rev 2.8)"

### Verification

Specialist arithmetic (game-designer + systems-designer convergent, independently computed) verified pre-close per "compute, don't read" discipline established in sixth pass.

### Carry-forward

- **rev 2.8 narrow re-review still recommended** to verify cross-doc atomicity of grid-battle.md + unit-role.md cap reductions vs damage-calc.md D_mult reduction. Same-session-revision-after-CRITICAL pattern is high-risk per CD precedent (0-for-4 prior runs); this rev 2.8 sweep was authored by systems-designer specialist with explicit constraint-derivation arithmetic, NOT by synthesizer guessing — different risk profile.
- **Seventh-pass 11 recommended revisions** still mostly carry: push_error export-build log-location text, WCAG SC 2.3.3 AAA-vs-Intermediate-tier, V-3 600ms-vs-800ms (DEFERRED — convergent ux concern); TalkBack AoE throttle policy; "Skill unavailable" CJK width TTS overflow; text scaling 200% clamp; a11y §2 "Reduced motion" scope; AC-DC-45 CI-lint scope; Scout/Infantry REAR=1.65 Section B overlap note; Player Fantasy 2.16× vs 2.13 ratio conflation (PARTIALLY ADDRESSED in rev 2.8 via D-3 rewrite + Player Fantasy 2.16x→1.97x); D-3 "2.13x from positioning alone" wrong (CLOSED in rev 2.8 D-3 rewrite).
- **OQ-AUD-05** (logged rev 2.1): still deferred to Alpha audition; rev 2.8 cap reduction does not change urgency (max P_mult composition unchanged at 1.32 vs prior 1.38).
- **OQ-VIS-03** (logged rev 2.3, moot since rev 2.4): unchanged.

### Files touched (rev 2.8 sweep)

- `design/gdd/damage-calc.md` (~11 edits)
- `design/gdd/grid-battle.md` (~5 edits)
- `design/gdd/unit-role.md` (~3 edits)
- `design/gdd/reviews/damage-calc-review-log.md` (this entry)
- `design/gdd/systems-index.md` (row 11 + Last Updated header)

### Status transition

- Damage Calc #11: In Review (rev 2.7) → **Designed (APPROVED post-eighth-pass + rev 2.8 close-out)**

### Pass history (8 review passes)

- pass-1 → MAJOR REVISION → rev 2.0 (in-session)
- pass-2 → NEEDS REVISION (minor) → rev 2.1 (in-session)
- pass-3 (clean session) → NEEDS REVISION (minor) → rev 2.2 (in-session)
- pass-4 (clean session) → NEEDS REVISION → rev 2.3 (in-session)
- pass-5 (fresh clean session) → NEEDS REVISION (CRITICAL fabricated-API recursion) → rev 2.4
- pass-6 → 11 BLK resolved → rev 2.5
- pass-7 → 11 deferred recommendeds + 6 nice-to-haves
- **pass-8 (eighth-pass, fresh session)** → NEEDS REVISION (CRITICAL Rally-ceiling regression from rev 2.7) → rev 2.7 + **rev 2.8 close-out (in-session, systems-designer-derived constraint-optimized fix)**

---

## Rev 2.8.1 — Eighth-pass narrow re-review close-out (2026-04-19)

Scope signal: S (5 stale-value defects from 3-spec narrow verification)
Specialists: game-designer, systems-designer, qa-lead (narrow re-review of rev 2.8)
Blocking items: 4 stale-value defects | Arithmetic correction: 1 (off-by-one in claimed apex table)

### Findings

3-spec narrow re-review of rev 2.8 sweep (per CD precedent: same-session-after-CRITICAL is high-risk historically; rev 2.8 was specialist-authored with explicit constraint-derivation, but verification still warranted) returned:

- **game-designer**: CONCERNS — caught (1) Archer/Scout R=+10% off-by-one in apex table (174 claimed; correct 173), (2) AC-DC-03 expected_damage 64 should be 59, (3) AC-DC-04 pass criteria still cite stale D_mult=1.80
- **systems-designer**: CONCERNS — caught (1) unit-role.md AC-10 still "+15%", (2) damage-calc.md L1240 Tuning Governance "Cavalry REAR=1.20"
- **qa-lead**: NEEDS REVISION — convergent with game-designer on AC-DC-03 + AC-DC-04 (both BLOCKING for Logic-type test gates)

### Convergent items (caught by ≥2 specialists)

- AC-DC-03 expected_damage stale (game-designer + qa-lead)
- AC-DC-04 pass criteria stale (game-designer + qa-lead)

### Rev 2.8.1 fixes applied

| # | Defect | Fix | File |
|---|---|---|---|
| 1 | AC-DC-03 expected_damage 64 → 59 | Updated AC-DC-03 title + pass criteria with rev 2.8 arithmetic | damage-calc.md |
| 2 | AC-DC-04 pass criteria D_mult=1.80, P_mult=1.20 → D_mult=1.64, P_mult=1.32 | Updated pass criteria to rev 2.8 values; supplementary assertion documents both no-Rally (27pt) and max-Rally (30pt) differentiation | damage-calc.md |
| 3 | L1240 Tuning Governance "Cavalry REAR=1.20" → 1.09 | Updated stale CLASS_DIRECTION_MULT reference | damage-calc.md |
| 4 | Pillar-3 peak hierarchy table: Archer/Scout R=+10% 174 → 173 | Arithmetic correction `floori(83 × 1.65 × 1.27) = floori(173.9265) = 173`; Cavalry margin updated ≥5pt → ≥6pt | damage-calc.md |
| 5 | unit-role.md AC-10 "caps at 15%" → "caps at 10%" | Stale cap reference | unit-role.md |

### Verification

The rev 2.8 structural fix (CLASS_DIRECTION_MULT[CAVALRY][REAR] 1.20→1.09 + Rally cap 0.15→0.10) is preserved across all formula sites + cross-doc references. The 5 stale-value defects were all in narrative/AC text, not in formula bodies — game-designer's independent recomputation confirmed the structural fix is correct. The off-by-one apex table claim (174 vs 173) was a derivation error in systems-designer's original arithmetic (computed 174.03 then floored; actual 173.93 → 173), not a structural defect.

### Pillar verdict (re-confirmed)

- Pillar 1 (Tactics of Momentum): HOLDS at 27/28/30pt differentiation across Rally states (no-Rally / +5% / +10%)
- Pillar 3 (Every Hero Has a Role): HOLDS — Cavalry leads by 6pt at all 12 apex cells
- Apex damage table (rev 2.8.1 corrected):

| Class + optimal combo | R=0% | R=+5% | R=+10% (cap) |
|---|---|---|---|
| Cavalry REAR+Charge | 163 | 171 | 179 |
| Archer FLANK+Ambush | 157 | 165 | **173** (was claimed 174) |
| Scout REAR+Ambush | 157 | 165 | **173** (was claimed 174) |
| Infantry REAR (no passive) | 136 | 143 | 150 |

### Status transition (final)

Damage Calc #11: **Designed (APPROVED post-eighth-pass + rev 2.8 + rev 2.8.1 close-out)**.

### Carry-forward

- 10 of seventh-pass 11 deferred recommendeds remain (push_error export-build log, V-3 600ms-vs-800ms ghost, etc.) — eligible for rev 2.9 bandwidth.
- OQ-AUD-05 + OQ-VIS-03 unchanged.
- Implementation gate: Logic-type stories (D-3 / D-4 unit tests) now have correct rev 2.8.1 expected values; tests can be authored without false-failure risk.

### Process insight (rev 2.8.1)

The rev 2.8 systems-designer-derived sweep correctly fixed the structural Pillar-1+3 regression but missed 5 narrative/AC stale-value sites. The pattern is consistent with CD's "same-session-after-CRITICAL is high-risk historically" guidance: the specialist focused on the formula correctness (got it right) but didn't audit every narrative reference that quoted the old values. A 3-spec narrow verification was the correct next step to catch these residuals. Rev 2.8.1 closes the loop atomically.

---

## Rev 2.9.1 — Narrow re-review close-out (2026-04-19)

Scope signal: S (8 stale-value defects + 방진 DEF visibility fix + Pillar-3 inversion ratification)
Specialists: systems-designer, game-designer, qa-lead (3-spec narrow re-review of rev 2.9 + Formation Bonus integration)
Blocking items: 6 stale "179" sites + Player Fantasy 2.16x | New design call: Pillar-3 inversion (user-ratified)

### Findings

3-spec narrow re-review of rev 2.9 sweep (per CD precedent: same-session-after-modifier-addition warrants verification) returned:
- **systems-designer**: APPROVED (all rev 2.9 arithmetic correct; cap fires correctly; backwards compat preserved)
- **game-designer**: NEEDS REVISION (NEW Pillar-3 inversion Archer 179 > Cavalry 178; 방진 floori(20×0.02)=0 invisible; Player Fantasy 2.16x stale)
- **qa-lead**: NEEDS REVISION (8 stale-value defects: AC-DC-04 + D-4 + CR-6 + F-DC-6 expected range + Pillar-3 peak hierarchy + 2 invariant claims; 2 missing ACs for new Formation paths D-7/D-8)

### Convergent items

- AC-DC-04 / D-4 stale 179 (systems-designer noted minor inherited imprecision; qa-lead caught as BLOCKER)
- Player Fantasy 2.16x stale (game-designer + qa-lead implicit)

### User adjudications (binding)

**Pillar-3 inversion ratified as acceptable**: Archer FLANK+Ambush+Rally(+10%)+Formation cap = `floori(83 × 1.65 × 1.31) = 179` vs Cavalry REAR+Charge+Rally(+10%)+Formation cap = `floori(83 × 1.64 × 1.31) = 178`. Caused by P_MULT_COMBINED_CAP clamping both classes to identical P_mult; Archer's higher D_mult edges Cavalry by 1pt. Manifests ONLY at simultaneous max-everything (rare in typical play). User accepts: Pillar-3 hierarchy holds in 23 of 24 cells; strict apex ordering not required.

### Rev 2.9.1 fixes applied

| # | Defect | Fix | File |
|---|---|---|---|
| 1 | Player Fantasy 2.16x stale | → 2.15x with rev 2.9 P_MULT_COMBINED_CAP=1.31 attribution | damage-calc.md |
| 2 | CR-6 hardest-hit narrative `floori(83×1.64×1.32)=179` | → `floori(83×1.64×1.31)=178` post-cap; Pillar-1 differentiation 30pt → 29pt | damage-calc.md |
| 3 | CR-9 ceiling rationale `floori(83×1.64×1.32)=179` | → `floori(83×1.64×1.31)=178` post-cap | damage-calc.md |
| 4 | F-DC-4 Pillar-3 peak hierarchy table | rev 2.9 update with full inversion ratification note (Archer 179 > Cavalry 178 acceptable per user adjudication) | damage-calc.md |
| 5 | F-DC-6 expected range stanza `raw ∈ [1, 179]` | Updated to acknowledge Archer/Scout cap-pinned 179 as upper bound; Cavalry cap-pinned 178; both <180 | damage-calc.md |
| 6 | D-4 worked example result 179 | → 178 (P_MULT_COMBINED_CAP fires); supplementary differentiation 30pt → 29pt | damage-calc.md |
| 7 | Inline `floori(83×1.64×1.32)=179` in invariant clamp note | → `floori(83×1.64×1.31)=178` rev 2.9 | damage-calc.md |
| 8 | AC-DC-04 pass criteria + title 179 | → 178; pre-cap P_mult=1.39 → cap 1.31; 30pt → 29pt | damage-calc.md |
| 9 | 방진 DEF bonus 0.02 → 0.04 (game-designer floori issue) | CR-FB-10 + Tuning Knob row + Vignette 4 updated | formation-bonus.md |
| 10 | Pillar-3 inversion ratification note added | F-FB-5 apex table + Pillar-3 inversion paragraph | formation-bonus.md |

### Verification

- Cavalry apex damage: rev 2.8.1=179 → rev 2.9=178 (1pt regression — user-adjudicated trade-off for Formation visibility)
- Archer apex damage: rev 2.8.1=173 → rev 2.9 cap-pinned=179 (Formation pushes past cap; 1pt above Cavalry — user-ratified)
- Pillar-1 differentiation: 30pt → 29pt at max-everything (still well above ≥15pt threshold)
- Pillar-3: holds in 23 of 24 cells; 1 cell inversion ratified
- DAMAGE_CEILING never fires on any primary path (max 179 < 180)
- 방진 DEF visibility at typical Infantry DEF=50: `floori(50 × 0.04) = 2` (was 1 at 0.02; was 0 at typical low-DEF)

### Carry-forward (not addressed in rev 2.9.1)

- **D-7, D-8 missing ACs** (qa-lead): F-DC-5 Formation block consumer-side AC + F-DC-3 formation_def_bonus consumer-side AC. Both Logic-type BLOCKING per coding-standards. Defer to Formation Bonus implementation sprint when fixture authoring begins (`tests/fixtures/formation_bonus/*.yaml`). Coordinate with formation-bonus.md AC-FB-10/AC-FB-11 to avoid duplication.
- 10 of seventh-pass 11 deferred recommendeds remain (push_error export-build log, V-3 600ms-vs-800ms ghost, etc.).
- `design/gdd/balance-data.md` formations.json schema + `design/registry/entities.yaml` constant registration (P_MULT_COMBINED_CAP + FORMATION_ATK_BONUS_CAP + FORMATION_DEF_BONUS_CAP) — Phase 5 work.

### Status (final)

Damage Calc #11: **Designed (APPROVED post-rev-2.9.1 close-out)** — eighth pass + rev 2.7 + rev 2.8 + rev 2.8.1 + rev 2.9 + rev 2.9.1 all closed.
