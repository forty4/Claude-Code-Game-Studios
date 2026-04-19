# Destiny Branch GDD — Review Log

Revision history and review findings for `design/gdd/destiny-branch.md`.

---

## Review — 2026-04-19 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, narrative-director, ux-designer, godot-gdscript-specialist, accessibility-specialist; creative-director (senior synthesis)
Blocking items: 7 Tier-1 | Recommended: 10 Tier-2 | Verdict: NEEDS REVISION → REVISED in session
Summary: First formal review of v1.0 (675 lines, 32 ACs). Six specialists returned NEEDS REVISION; accessibility-specialist returned MAJOR REVISION (stricter gate); creative-director synthesized at NEEDS REVISION across collective gate. Strong convergence on: Reduce Motion gap (ux + a11y), PC triad degradation (ux + a11y), Ch1 always-default tutorial anti-pattern (game-designer + narrative-director), fabricated GdUnit4 APIs (qa-lead + godot-gdscript), test helpers missing (qa-lead + systems-designer + godot-gdscript), StringName cross-platform unverified (3 specialists), 15% opacity unvalidated (game-designer + ux). No direct specialist contradictions. Architecture sound; experiential and spec-hygiene layers revised.
Prior verdict resolved: First review (no prior).

### Tier-1 Blocking Issues (7) — All Resolved in Same Session

| # | Source | Blocker | Fix (rev 1.1) |
|---|---|---|---|
| T1-1 | game-designer B-3 + narrative-director Issue 2 + CD senior | Ch1 always-default means player's first Beat 7 is always null (no reserved-color reveal); Pillar 2 visual contrast has no baseline for V-DB-2 to register against | Section B subsection "Ch1 tutorial shape — priming-null by design"; accepts tutorial shape; OQ-DB-10 flags playtest observation |
| T1-2a | ux BLOCK-UX-3 + accessibility BLOCKING-2 | No Reduce Motion variant for V-DB-1 (600ms+800ms) or V-DB-2 (1500ms); doesn't cite damage-calc rev 2.5 motion policy | V-DB-1 + V-DB-2 Reduce Motion subsections added; cite `max(baseline_hold, 1200ms)` WCAG SC 2.2.1 policy; dwell-lockout survives per R-3 carve-out |
| T1-2b | ux BLOCK-UX-1 + accessibility BLOCKING-1 | PC triad collapses to 2 channels; deaf+colorblind+PC+no-gamepad = 0–1 unambiguous channels | A-DB-2 extended with PC gamepad rumble (when connected); UI-DB-4 accessibility channel matrix added; UI-DB-5 PC degradation rationale with escalation to art-director + a11y-specialist; PC+no-gamepad accepted gap |
| T1-3 | narrative-director Issue 1 | 8-field payload cannot distinguish canonical-upheld from canonical-rewritten; Pillar 4 enforcement has no payload-level invariant | F-DB-4 added 9th field `is_canonical_history: bool`; F-DB-1 algorithm step 5 passthrough; worked examples E1–E6 updated; ADR-0001 minor amendment expanded to 9-field ratification; scenario-progression F-SP-1 contract expansion flagged in Bidirectional Updates |
| T1-4 | systems-designer BLK-1/2/4 | F-DB-1 algorithm payload guard holes (chapter_id empty unguarded; f_sp_1["is_draw_fallback"] unchecked key access; branch_table null/non-Dictionary not guarded) | 3 new F-DB-1 guards added + F-DB-2 local fallback override (enforces reserved_color_treatment=false on is_draw_fallback=true regardless of branch_key); F-DB-3 vocabulary expanded 5→8 entries |
| T1-5 | narrative-director Issue 3 | DRAW fallback creates ludonarrative dissonance (player draws → WIN-canonical Beat 8 text → Pillar 2 damage) if Story Event #10 doesn't differentiate | Bidirectional Updates row for Story Event #10 upgraded to BLOCKING with 4-item constraint set: is_invalid gate; `is_canonical_history` keying; BLOCKING fallback-DRAW text acknowledgment; STRONGLY RECOMMENDED echo-gated DRAW differentiation |
| T1-6 | godot-gdscript B-1/2/3/4 | Engine API + test correctness: Performance.OBJECT_COUNT wrong path; raw int export bypasses enum; ResourceSaver.save() return not asserted; StringName preservation presented as guarantee | AC-DB-32 → `Performance.Monitor.OBJECT_COUNT`; F-DB-4 `outcome: BattleOutcome.Result` typed export; AC-DB-24 asserts save_err==OK pre-reload; F-DB-4 StringName language weakened to hypothesis per OQ-DB-6 |
| T1-7 | qa-lead BLOCK-1/2/3/4/5/6 | GdUnit4 not installed; MockChapterResource missing; fabricated APIs (full-bus spy, get_value_count unverified, property-test); CI lint framework unconfirmed | AC-DB-11 enumerated specific 11-signal set (no more full-bus spy); AC-DB-22 rewritten as parameterized 12-row fixture matrix (no property-test); AC-DB-12 version-tolerant with await_signal_on fallback pattern; AC-DB-07 CI grep lint step in tests.yml with forbidden-API regex; implementation story prerequisites flagged (GdUnit4 install + helpers scaffolding) |

### Tier-2 Recommended Revisions (10) — All Applied

- R1 15% panel-wash opacity unvalidated → V-DB-1 playtest-and-tune band 10–25%
- R2 AC-DB-31 missing payload-side clamp assertion → extended with negative-input + payload clamp
- R3 Tap-ready affordance at 1500ms unowned → V-DB-5 cross-GDD reference + OQ-DB-11 BLOCKING for VS
- R4 OQ-DB-6 should be BLOCKING → upgraded with Android CI lane prerequisite
- R5 OQ-DB-7 milestone error → corrected to Full Vision; 해금 Intermediate proxy; loc key `beat_7.reserved_color.sr_label`
- R6 A-DB-2 OS haptic preference → opt-out check + degraded-channel acknowledgment
- R7 V-DB-4 error dialog a11y → baseline requirement with scenario-progression cross-ref
- R8 File layout scattered → explicit paths in F-DB-4 note
- R9 Dwell-lockout tap-swallow → delegated via OQ-DB-11 cross-ref
- R10 Missed edge cases → EC-DB-15 (GameBus autoload-freed); EC-DB-16 (F-SP-1 wrong-typed); EC-DB-17 (concurrent resolve + static-var lint)

### Key Design Decisions (locked with user approval at blocker-resolution widget)

- **D1 Ch1 tutorial**: Acknowledge priming-null, no mitigation (Section B note + OQ-DB-10 playtest observation)
- **D2 PC 3rd channel**: Gamepad rumble when connected; keyboard/mouse-only PC accepted as 2-channel gap
- **D3 Payload field**: Add `is_canonical_history: bool` → 9 fields total (vs defer to #10 content lookup)
- **D4 #10 VS constraint**: BLOCKING on #10 VS design start for fallback-DRAW text + canonical-history keying

### Cross-system follow-ups flagged (BLOCKING implementation)

- **ADR-0001 minor amendment expanded**: 5-field PROVISIONAL → 9-field ratified (was 8 before narrative-director Issue 1 surfaced `is_canonical_history`)
- **Scenario-progression revisions required**: (1) §Interactions line 186–188 wording clarification (T-1); (2) F-SP-1 §D output contract adds `is_canonical_history` required key; (3) AC-SP-18 payload field-set expands to 9; (4) AC-SP-17 invalid-path clarification; (5) chapter authoring schema `branch_table` rows gain `is_canonical_history: bool`
- **OQ-DB-6 BLOCKING**: StringName cross-platform serialization — Android + Windows CI lanes required before AC-DB-24 passes
- **OQ-DB-11 BLOCKING VS**: Beat 7 tap-ready affordance at 1500ms — scenario-progression v2.1 or interim UI-DB-6 addition
- **Story Event #10 VS BLOCKING**: cannot be marked Designed until fallback-DRAW text commitment + is_canonical_history keying locked

### File changes this session (rev 1.1 sweep)

- `design/gdd/destiny-branch.md` — 679 → 811 lines; header updated rev 1.0 → rev 1.1; ~17 edit clusters
- `design/gdd/systems-index.md` — row 4 status updated; header Last Updated bumped
- `design/gdd/reviews/destiny-branch-review-log.md` — CREATED (this file)
- `production/session-state/active.md` — session-state update pending (review summary)

### Positive signals (what held up under adversarial scrutiny)

- CR-DB-9 derivation elegance (derived, not authored) — 7/7 specialists validated
- CR-DB-11 determinism invariant — airtight per godot-gdscript + systems-designer
- Invalid-result pattern (CR-DB-10 + F-DB-3) — defensive and correct; AC-SP-17 emission ordering preserved under error
- CR-DB-12 scope rejection list — 7/7 appropriate for MVP per creative-director senior
- KOEI 영걸전 lineage + Dark Souls post-boss pause reference — narrative-director validated
- 8-field (now 9-field) payload correctly expands from 5-field PROVISIONAL per Evolution Rule #4

### Re-review expectations

Next pass (eighth-pass style per damage-calc precedent): fresh /clear session; full-mode /design-review to spawn 7 specialists cleanly. Particular attention for re-reviewer:
1. Does `is_canonical_history` cleanly survive boundary-value analysis + all EC paths?
2. Do Reduce Motion V-DB-1/V-DB-2 variants preserve R-1 channel count in all matrix cells?
3. Is the PC accessibility rationale (UI-DB-5) sufficient for a11y-specialist acceptance, or does it require further mitigation?
4. Does ScenarioRunner ownership of V-DB-5 tap-ready affordance correctly cross-reference without duplicating?
5. Compute-don't-read discipline on E1–E6 worked examples under 9-field payload arithmetic (per damage-calc rev 2.6 creative-director insight).

---

## Review — 2026-04-19 (eighth-pass clean-session) — Verdict: NEEDS REVISION → REVISED in same session (rev 1.2)
Scope signal: M (senior synthesis: mostly mechanical + 4 genuine adjudications)
Specialists: game-designer, systems-designer, qa-lead, narrative-director, ux-designer, godot-gdscript-specialist, accessibility-specialist; creative-director (senior synthesis)
Blocking items: 12 Tier-1 | Recommended: ~18 Tier-2 | Verdict: NEEDS REVISION → REVISED in session (rev 1.2)
Summary: Eighth-pass clean-session review. 6 specialists returned NEEDS REVISION; qa-lead returned MAJOR REVISION NEEDED (stricter gate driven by cross-document contract gaps — GdUnit4 API, IP-006, engine APIs, test helpers). Creative-director synthesized at NEEDS REVISION (not MAJOR). Rev 1.1 CLOSED every prior blocker cleanly (no regressions; math + enum + AC verified). Pass-8 SURFACED a new class of defects: cross-document contract gaps newly-visible because specialists cross-checked sibling docs (IP-006, scenario-progression, Godot 4.6 APIs). Expected maturity behavior: internal consistency locks → external consistency becomes next visible layer. 8 of 12 Tier-1 items are mechanical <30min fixes; 4 required genuine adjudication, collected as user design decisions D1-D4.
Prior verdict resolved: rev 1.1 resolved all 7 pass-7 Tier-1 + 10 Tier-2 cleanly (confirmed by all 7 specialists).

### Tier-1 Blocking Issues (12) — All Resolved in Same Session (rev 1.2)

| # | Source | Blocker | Fix (rev 1.2) |
|---|---|---|---|
| T1-1 | systems B-1/B-2 + qa-lead + narrative N-2 + game REC-3 | Stale "8-field" references in 9 locations (lines 114, 125, 203, 446, 654, 659, 696-697, 705 Bucket 3 header, 801 OQ-DB-1) — factual contradictions inside same doc after rev 1.1 8→9 expansion | Mechanical sweep across all 9 locations to "9-field" or explicit numeric updates; Bucket 3 header count 5→10; Coverage summary 37→40 |
| T1-2 | game BLOCK-1 + systems B-3 + godot-gdscript B-6 | `is bool` type guards missing at F-DB-1 lines 186, 196 — GDScript silent coercion allows String "false" → true (is_draw_fallback) or int → bool (is_canonical_history) corruption | F-DB-1 step 3b two new type guards; F-DB-3 vocabulary +2 entries (is_draw_fallback_type_invalid, is_canonical_history_type_invalid); AC-DB-20d + AC-DB-20e new; F-DB-1 pseudocode also mandates parentheses `not (X is Y)` per godot-gdscript B-5 |
| T1-3 | game BLOCK-2 + narrative BLOCK-1 | `BattleOutcome.invalid()` default `outcome=LOSS` is valid enum; downstream may process corrupt path as genuine LOSS without surface — Pillar 2 + Pillar 4 correctness risk. **D1 DECISION**: B (no UNKNOWN sentinel) | Bidirectional Updates new BLOCKING row: every #10/#16/#17 VS GDD must add CI grep rule rejecting `choice.outcome` read before `if not choice.is_invalid:` guard |
| T1-4 | ux BLOCK-UX-4 | IP-006 mandates color+icon+text-prefix redundancy triad; V-DB-1 suppresses icon+text for wordless ceremonial. Direct spec conflict. **D2 DECISION**: A (amend IP-006 with Beat-7 carve-out) | `design/ux/interaction-patterns.md` IP-006 rewritten with default-triad + Beat-7 carve-out (audio+haptic substitutes for icon+text); destiny-branch line 646 UI-DB-5 cross-reference updated with carve-out language |
| T1-5 | qa-lead BLOCK-1/2/3 | AC-DB-09/11 `GdUnitSignalCollector` API hallucinated; AC-DB-11 lint "enforced via code review" not CI-executable; AC-DB-20c `_apply_f_sp_1` stub seam undocumented (non-virtual). **D3 DECISION**: A (declare virtual + TestDestinyBranchJudgeWithSp1Stub) | AC-DB-09 rewritten to `monitor_signals(GameBus, false)` + `assert_signal_not_emitted()`; AC-DB-11 rewritten with executable CI grep lint; F-DB-1 test-seam contract + `TestDestinyBranchJudgeWithSp1Stub` pattern added; AC-DB-20c uses the seam (no monkey-patching); AC-DB-20d/20e parameterized on same pattern |
| T1-6 | accessibility BLOCKING-B | A-DB-2 cites `Input.get_haptic_feedback_enabled()` not in Godot 4.6. **D4 DECISION**: A (downgrade + OQ verification) | A-DB-2 rewritten SHOULD+best-effort; in-game Settings `reduce_haptics` opt-out is the MVP enforcement path; OQ-DB-12 flagged for engine-reference verification pass |
| T1-7 | godot-gdscript B-7 | `BattleOutcome` class_name scope unspecified — inner class breaks AC-DB-24 ResourceLoader.load() silently | F-DB-4 subsection "BattleOutcome class_name constraint" added; Bidirectional Updates BLOCKING row on grid-battle v5.0 to declare `class_name BattleOutcome` top-level |
| T1-8 | narrative BLOCK-1 | `is_canonical_history` authoring invariant NOT enforced at system boundary — Issue 3 dissonance reproduces via scenario-authoring error | Bidirectional Updates CARRYOVER row to scenario-progression v2.1: schema validator must enforce exactly-one-canonical-per-chapter invariant |
| T1-9 | accessibility BLOCKING-A | V-DB-4 conditional "if" hedge means gap may never fire | V-DB-4 rewritten with hard "MUST"; AC-DB-38 new (Bucket 8); OQ-DB-13 BLOCKING VS |
| T1-10 | ux BLOCK-UX-5 | UI-DB-5 justification #3 factually wrong re: AccessKit closing deaf-channel | UI-DB-5 rewritten correctly (AccessKit closes screen-reader for visually-impaired; deaf+colorblind+PC-no-gamepad reversal trigger spec'd separately) |
| T1-11 | qa-lead BLOCK-5 | AC-DB-33 parameterized matrix depends on un-authored scenario JSON — unexecutable at MVP | AC-DB-33 rescoped: MVP = 3-row mini-matrix via stub; ADVISORY full-chapter-matrix pending scenario-progression v2.1 authoring |
| T1-12 | qa-lead BLOCK-4 | AC-DB-20 `error_log_capture.gd` helper path cited but API undefined | AC-DB-20 evidence extended with minimum helper API contract (`begin()`, `end() -> Array[String]`, `assert_error_contains(substring)`) + 3 implementation options; flagged as implementation-story prerequisite |

### Tier-2 Recommended Revisions (~18) — All Applied

- EC-DB-16 expansion: is_draw_fallback + is_canonical_history wrong-types explicit; single flag `branch_table_missing_outcome` for any missing key [systems R-1]
- V-DB-1 15% panel-wash declared TK-DB-1 Tuning Knob (rev 1.1 "None at MVP" correction) [systems R-2]
- V-DB-1 SC 2.3.1 flash-safety audit flag + OQ-DB-15 [ux REC-1, a11y REC-2]
- UI-DB-4 matrix +5 rows: Settings-reduce_haptics (replacing OS-haptics), mobile+deaf+colorblind+reduce_haptics accepted-gap, RM+mobile+haptic, RM+deaf+PC-no-gamepad, cognitive accessibility deferred [a11y REC-1, ux REC-4]
- OQ-DB-10 measurable threshold: ≥30% first-reveal-delay → escalate to Ch2 authoring constraint [game REC-5, narrative REC-3]
- AC-DB-07 forbidden-pattern list expansion: Time.get_unix_time*, OS.get_*, RandomNumberGenerator instance methods [godot-gdscript R-4]
- AC-DB-24 Android ADVISORY carve-out explicit: macOS MVP gate; Android/Windows VS gate [qa-lead BLOCK-6]
- Worked example E4 `cue_tag:"draw_fallback"` stripped (misleading per EC-DB-12 forward-compatibility contract) [game REC-4]
- V-DB-2 subtitle divergence semantics + 3 loc keys (default/reserved/fallback) + braille flag [ux REC-3, a11y REC-5]
- Dwell-lockout early-tap UX ownership: OQ-DB-16 (ux-designer + creative-director, not scenario-progression plumbing-only) [ux REC-2]
- CR-DB-12 #5 photosensitivity rationale (SC 2.3.3 snap as mitigation; SC 2.3.1 audit deferred) [game REC-2]
- V-DB-2 먹선 RM wording: "static from Beat 7 onset, no onset animation" (not "snap at 0ms") [a11y REC-3]
- CR-DB-4 + AC-DB-25 emit-order vs receive-order clarification (synchronous emit, deferred handler) [godot-gdscript R-3]
- AC-DB-14/15 explicit GIVEN-WHEN-THEN with TestDestinyBranchJudgeWithSp1Stub fixtures (no more "implicit in AC-DB-03") [qa-lead REC-1]
- AC-DB-22 fixture file implementation-story prerequisite tag [qa-lead REC-3]
- AC-DB-32 median+p99 timing variance (not "every call under 1000us") [qa-lead REC-4]
- AC-DB-30 process-only → CI grep regex [qa-lead REC-5]
- AC-DB-13 allowlist equality (stricter than regex exclusion) [godot-gdscript N-1]
- `Performance.Monitor.OBJECT_COUNT` engine-reference verification flagged OQ-DB-14 [godot-gdscript R-1]

### 4 Design Decisions Locked (user-approved at blocker-resolution widget)

- **D1 invalid-gate**: Option B (Bidirectional Updates BLOCKING on #10/#16/#17 VS rows) — not UNKNOWN sentinel. Rationale: keeps MVP scope tight; matches existing CARRYOVER-TO-SP pattern; enforcement sits at authoring gate not runtime.
- **D2 IP-006 conflict**: Option A (amend IP-006 with Beat-7 ceremonial carve-out). Rationale: preserves Section B wordless Pillar 2 fantasy; substitutes audio+haptic for icon+text while keeping 3+ channel redundancy auditable; +25 lines to IP-006.
- **D3 test seam**: Option A (declare `_apply_f_sp_1` virtual + `TestDestinyBranchJudgeWithSp1Stub` RefCounted subclass pattern). Rationale: follows damage-calc rev 2.6 bypass-seam precedent; no monkey-patching; no GdUnit4-version-fragile assumptions.
- **D4 haptic API**: Option A (downgrade MUST→SHOULD best-effort + OQ-DB-12 verification). Rationale: rev 1.1 "MUST" cited non-existent API; in-game Settings `reduce_haptics` toggle is enforceable MVP path; OS-level query deferred to engine-reference verification.

### Cross-system follow-ups flagged (rev 1.2 new + rev 1.1 carryover)

**NEW rev 1.2**:
- **ADR-0001 minor amendment scope expanded**: 9-field payload + BattleOutcome top-level class_name + invalid-path emission contract + 10-entry F-DB-3 vocabulary
- **`design/ux/interaction-patterns.md` IP-006 amended**: default triad + Beat-7 ceremonial carve-out (landed atomic with this rev 1.2 sweep)
- **Grid Battle v5.0 GDD BLOCKING**: `class_name BattleOutcome` top-level declaration
- **Scenario-progression v2.1 CARRYOVER additions**: is_canonical_history per-chapter authoring invariant (exactly-one-canonical)
- **OQ-DB-12 BLOCKING verification VS**: Godot 4.6 haptic API engine-reference pass
- **OQ-DB-13 BLOCKING VS**: scenario-progression error-dialog R-1..R-5 spec (AC-DB-38 dependency)
- **OQ-DB-14**: Performance.Monitor.OBJECT_COUNT engine-reference verification (advisory)
- **OQ-DB-15**: V-DB-1 RM snap SC 2.3.1 photosensitive-safety audit (Pre-Production)
- **OQ-DB-16**: dwell-lockout early-tap ownership (ux-designer + creative-director)

**Carried from rev 1.1 (unchanged)**: ADR-0001 9-field ratification (expanded scope); scenario-progression v2.1 F-SP-1 contract expansion; OQ-DB-6 StringName cross-platform BLOCKING; OQ-DB-11 BLOCKING VS tap-ready affordance; Story Event #10 VS BLOCKING (fallback-DRAW text + is_canonical_history keying).

### File changes this session (rev 1.2 sweep)

- `design/gdd/destiny-branch.md` — 811 → ~1080 lines; header rev 1.1 → rev 1.2; ~31 edit clusters
- `design/ux/interaction-patterns.md` — IP-006 section rewritten with Beat-7 ceremonial carve-out (rev 2026-04-19 marker)
- `design/gdd/systems-index.md` — row 4 status updated to rev 1.2; header Last Updated bumped
- `design/gdd/reviews/destiny-branch-review-log.md` — this entry appended

### Positive signals (what held up in rev 1.1 under eighth-pass adversarial scrutiny)

- **Rev 1.1 closed every prior blocker cleanly** — all 7 specialists independently confirmed: E1-E6 math, BattleOutcome typed enum export, AC-DB-31 caller-immutability, ResourceSaver save_err==OK, CR-DB-9 derivation, CR-DB-11 determinism, worked-example compute discipline.
- No specialist contradictions; all 7 verdict reports converged architecturally.
- qa-lead stricter MAJOR gate was traced to cross-document contract gaps (GdUnit4 API, IP-006, engine API), NOT internal destiny-branch decay.
- narrative-director Korean register consistency + Pillar 4 payload-level enforcement held under Issue 1/3 re-test.
- accessibility-specialist prior 3 blockers (BLOCKING-1/BLOCKING-2/HIGH-3) fully resolved in rev 1.1.

### Re-review expectations for pass-9

Per creative-director senior synthesis: **revise-in-session rev 1.2 should approve cleanly at pass-9 IF**:
- Zero grep hits for "8-field" / "8 fields" / "all 8" in destiny-branch.md
- AC-DB-20d + AC-DB-20e + AC-DB-38 present with TestDestinyBranchJudgeWithSp1Stub seam
- Bidirectional Updates has the 4 new rev 1.2 BLOCKING rows (#10/#16/#17 invalid-gate; Grid Battle class_name; ADR-0001 expansion; scenario-progression authoring invariant)
- IP-006 in interaction-patterns.md has both default-triad + Beat-7 carve-out authored
- OQ-DB-12/13/14/15/16 present in Open Questions
- CI grep lint lifecycle clear (ADVISORY until merged)

Diminishing returns on pass-9 per senior synthesis — user may opt to accept rev 1.2 as approved without re-review given mechanical nature of most fixes + creative-director explicit recommendation.

---

## Review — 2026-04-19 (ninth-pass clean-session) — Verdict: NEEDS REVISION → REVISED in same session (rev 1.3)
Scope signal: L (senior synthesis consolidated 19 raw specialist blockers to 11 genuine + 9 Tier-2; 3 cross-doc convergence clusters + 3 over-reach rejections)
Specialists: game-designer, systems-designer, qa-lead, narrative-director, ux-designer, godot-gdscript-specialist, accessibility-specialist; creative-director (senior synthesis)
Blocking items: 11 Tier-1 (consolidated) | Recommended: 9 Tier-2 | Verdict: NEEDS REVISION → REVISED in session (rev 1.3)
Summary: Ninth-pass clean-session re-review. 6 specialists returned NEEDS REVISION; qa-lead returned MAJOR REVISION (stricter AC-lifecycle gate). Creative-director synthesized at NEEDS REVISION (rejecting MAJOR as over-scoped). Contrary to pass-8 senior-synthesis prediction ("approve-as-revised at pass-9"), rev 1.2 did NOT approve cleanly — pass-9 surfaced genuine new blockers at three layers: (1) cross-document contract decay accelerated by rev-1.2's D1-D4 fixes that imported new sibling-doc obligations (accessibility-requirements §2, scenario-progression §Interactions, Settings #28) not updated in lockstep; (2) new class of defect pass-8 didn't probe (ADVISORY-AC lifecycle with no trigger mechanism, invariant-declaration-without-enforcer, invented-API contract bindings); (3) load-bearing questions (OQ-DB-10 threshold, OQ-DB-16 swallow/queue) that were incorrectly left as Open Questions when they are Pillar-2 adjudications requiring decision. Pass-9 did NOT find regressions in rev 1.1/1.2 fixes — those held. User selected [A] in-session rev 1.3 over fresh /clear; 4 new design decisions locked up-front, 11 blockers applied atomically across 3 files.
Prior verdict resolved: rev 1.2 resolved all 12 pass-8 Tier-1 + 18 Tier-2 cleanly (no regressions confirmed at pass-9).

### Tier-1 Blocking Issues (11 consolidated from 19 raw) — All Resolved in Same Session (rev 1.3)

| # | Source convergence | Blocker | Fix (rev 1.3) |
|---|---|---|---|
| T1-1 | game B-1 + ux B-UX-9-2 + a11y B-1 (3-way cross-doc) | `reduce_haptics` toggle unhoused — cited by A-DB-2 + UI-DB-4 ACCEPTED GAP but not in accessibility-requirements.md §2 (6 enumerated toggles); Settings/Options #28 had no build commitment | **D1 decision**: Option A — add 7th Intermediate toggle `reduce_haptics` to a-req.md §2/§7/§9; Settings #28 scope 6→7 toggles; A-DB-2 + UI-DB-4 matrix rationale updated to cite rev 1.1 a-req landing |
| T1-2 | systems B-3 + narrative B-ND-1 + ux B-UX-9-1 (3-way cross-doc) | scenario-progression §Interactions line 189 6-field payload is silent-incompatibility risk (not just doc lag) — authoring tools built against 6-field collapse is_canonical_history + is_invalid + invalid_reason to defaults | Bidirectional Updates new BLOCKING row: co-merge gate on #10/#16/#17 VS implementation-story open; scenario-progression.md line 189 synced to 9-field rev v2.0-patch 2026-04-19 (atomic this session); Pre-Implementation Gate Checklist consolidates all BLOCKING carryovers |
| T1-3 | systems B-1 | `chapter.branch_table = {}` empty-Dictionary passes F-DB-1 step-1 guard; falls through to `_apply_f_sp_1` with undefined behavior | F-DB-1 step 1a new `branch_table.is_empty()` guard → `branch_table_empty` new invalid-reason vocabulary entry; AC-DB-20f new |
| T1-4 | systems B-2 | F-DB-4 invariant `is_draw_fallback=true ⟹ outcome==DRAW` declared but NOT enforced at F-DB-1 assembly time | F-DB-1 step 3c new cross-field invariant check → `is_draw_fallback_outcome_mismatch` new invalid-reason vocabulary entry; AC-DB-20g new parameterized on WIN + LOSS outcomes |
| T1-5 | narrative B-ND-2 | F-DB-4 permits zero-canonical-row chapter; Pillar 4 exactly-one invariant delegated entirely to unimplemented sp v2.1 validator | F-DB-1 step 1b new runtime warning path — zero-canonical or multi-canonical chapters trigger `push_warning` + telemetry flag (not is_invalid; ship proceeds); authoring drift observable in development |
| T1-6 | qa-lead B-1 | ADVISORY AC lifecycle has no trigger mechanism — 10 ACs could remain ADVISORY in perpetuity | Every ADVISORY AC now carries explicit owner + gate + promotion condition; multiple BLOCKING-from-MVP-open promotions (AC-DB-07/09/11/20/22/29/30 lifted from ADVISORY to BLOCKING); AC-DB-33 full-matrix promotion gated to Full Vision close |
| T1-7 | qa-lead B-2 | AC-DB-09 `await_signal_on(..., 100)` fallback NOT proof-of-absence equivalent to `assert_signal_not_emitted()` | Fallback path REMOVED from AC-DB-09; committed to single API (monitor_signals + assert_signal_not_emitted); GdUnit4 version pin as implementation-story prerequisite |
| T1-8 | qa-lead B-3 | AC-DB-20 `error_log_capture.gd` helper had 3 unresolved implementation options | **D2 decision**: Option A — stdout/stderr redirect + grep captured buffer; API contract locked; GDExtension + GdUnit4-built-in options explicitly rejected |
| T1-9 | gdscript B-1 | `BattleOutcome.is_valid_result()` invented static method at F-DB-1 line 162; not specced in grid-battle.md | F-DB-1 step 1c rewritten as `not int(outcome) in BattleOutcome.Result.values()` — GDScript-native, type-safe, survives enum reordering |
| T1-10 | gdscript B-2 | Latent signature mismatch — `resolve(outcome: int)` vs `@export var outcome: BattleOutcome.Result` schema | Signature changed to `resolve(chapter, outcome: BattleOutcome.Result, echo_count)`; all `%d` format calls now use `int(outcome)` cast per Godot 4.6 typed-enum rules |
| T1-11 | gdscript B-3 | `_apply_f_sp_1` "declared virtual" per doc but no `@virtual` / `@abstract` annotation | `@abstract` annotation added to base class `_apply_f_sp_1` per Godot 4.5+ feature; base has no body (`pass`); concrete subclasses must override; TestDestinyBranchJudgeWithSp1Stub pattern is a concrete override |

### 4 Design Decisions Locked (rev 1.3 D1-D4, user-approved at batched AskUserQuestion)

- **D1 `reduce_haptics` toggle housing**: Option A — add 7th Intermediate toggle to accessibility-requirements.md §2/§7/§9. Settings/Options #28 implementation-story scope expanded by one toggle. Clean scope separation from reduced-motion.
- **D2 AC-DB-20 log-capture implementation**: Option A — Godot stdout/stderr redirect + grep captured buffer. Simplest, zero dependencies, headless-CI friendly. Platform line-ending normalization is helper responsibility.
- **D3 OQ-DB-10 threshold framing**: Option A — flip to max-miss-rate ≤10% by Ch2 end (failure threshold, not escalation trigger). Pillar 2 FAILS MVP acceptance if >10%. Pairs with advisory qualitative probe per session.
- **D4 OQ-DB-16 early-tap**: Option A — SWALLOW early taps. Ceremony preserved. Queue-to-fire rejected as anti-fantasy. OQ-DB-16 closed + promoted to BLOCKING VS constraint for scenario-progression input handler.

### Tier-2 Recommended Revisions (9) — All Applied

- AC-DB-07 forbidden-pattern list extended: `Engine.get_process_frames`, `Engine.get_physics_frames`, `DisplayServer.window_*`, `OS.get_processor_count`, `ClassDB.get_class_list` [systems R-1]
- TK-DB-1 safe range bounds given measurable protocol: perceptibility floor = <80% identification in 5sec on 300-nit reference display; ceiling = WCAG 4.5:1 text contrast violation or Beat 8 signal bleed [systems R-2]
- V-DB-2 Korean subtitle copy marked as first-pass authoring; register revision flagged to narrative-director (observational/participial construction preferred over declarative-expository) [narrative N-ND-1]
- Story Event #10 BLOCKING constraint reframed: register constraint (same solemn-witness register, no causal framing) replaces example-copy mandate ("the canonical record stood because no clear victor emerged" was rev 1.1 illustrative, rev 1.3 removes the illustrative example and locks register + writer license) [narrative N-ND-3]
- AC-DB-24 fixture matrix expanded to 4 rows — adds `invalid_reason = &""` (empty-StringName) rows to catch silent demotion to String on round-trip [qa-lead R-2]
- AC-DB-31 extended to chapter-Object-by-reference + outcome-enum-by-value immutability assertions (rev 1.2 only tested echo_count int immutability) [qa-lead R-5]
- UI-DB-5 reversal-trigger condition (b) marked LOGICAL DEAD END — project-wide on-screen indicator necessarily appears at Beat 7 which contradicts carve-out; only condition (a) viable; alternative (c) dedicated out-of-band indicator unspec'd [ux R-UX-9-4]
- Section B Marked Hand standalone-absence risk note added — if #10 VS cut, Marked Hand disappears with no destiny-branch fallback [narrative N-ND-4]
- AC-DB-24 historical claim corrected — ResourceSaver.save() returned Error since Godot 4.0 not 4.4 [gdscript R-2]

### Cross-system follow-ups flagged (rev 1.3 new + carried from rev 1.1/1.2)

**NEW rev 1.3 (landed this session across 3 files)**:
- accessibility-requirements.md §2: 7th Intermediate toggle `reduce_haptics` added (D1 atomic landing); §7: Settings #28 scope 6→7 + new Destiny Branch (#4) cross-reference row; §9 revision log updated.
- scenario-progression.md §Interactions line 189: 6-field → 9-field payload minimum list; wording "Destiny Branch owns the branch-table lookup" → "Destiny Branch EXECUTES F-SP-1" (T-1 closed); invalid-path emission contract note added.
- destiny-branch.md: Pre-Implementation Gate Checklist consolidating 6 BLOCKING MVP + 4 BLOCKING VS + 1 MVP-exit gates.

**NEW rev 1.3 carryovers (not yet landed — future work)**:
- scenario-progression.md UX.2 (ux B-UX-9-1): add Beat-7 carve-out acknowledgment paragraph referencing IP-006 + destiny-branch UI-DB-5 — BLOCKS VS implementation-story open
- scenario-progression.md v2.1 authoring-schema validator: exactly-one-canonical-per-chapter enforcement (rev 1.2 CARRYOVER + rev 1.3 runtime warning as safety net)
- OQ-DB-17 (new a11y B-2): Korean braille adequacy for beat_7.subtitle.* keys — accessibility-specialist + localization-lead
- AC-DB-33 full-chapter-matrix: BLOCKING for Full Vision close (rev 1.3 sharpened from "ADVISORY until sp v2.1 lands")
- OQ-DB-10 ≤10% miss-rate threshold: BLOCKS MVP exit on first mobile playtest

**Carried from rev 1.1/1.2 (unchanged)**: ADR-0001 9-field payload ratification + BattleOutcome class_name + invalid-path emission contract + 12-entry vocabulary; scenario-progression v2.1 F-SP-1 contract expansion + is_canonical_history authoring invariant; OQ-DB-6 StringName cross-platform BLOCKING; Story Event #10 VS BLOCKING (rev 1.3 reframed constraint); OQ-DB-11 closed citing sp UX.2.

### Positive signals (what held up in rev 1.2 under ninth-pass adversarial scrutiny)

- **Rev 1.2 closed every pass-8 blocker cleanly** — no regressions. All 7 specialists confirmed: 8-field sweep complete, AC-DB-20d/20e/38 + test-seam present, 4 BLOCKING Bidirectional rows, OQ-DB-12..16 authored, IP-006 Beat-7 carve-out authored in interaction-patterns.md.
- D1-D4 rev 1.2 decisions survived adversarial pass-9 scrutiny architecturally.
- New class of defects surfaced at pass-9 (ADVISORY-AC lifecycle, cross-doc contract decay, Pillar-2-adjudication-as-OQ) was NOT present in rev 1.2 content — they were latent structural concerns that rev 1.2's content fixes made visible.
- Pass-9 specialists found zero internal contradictions between rev 1.2 sections. All blockers were either cross-doc contract gaps (3 convergence clusters), formula-correctness (3 systems + 1 narrative), or test-evidence (3 qa-lead) — each isolated to its domain.

### Re-review expectations for pass-10

Per creative-director senior synthesis: **revise-in-session rev 1.3 should approve cleanly at pass-10 IF**:
- Zero `BattleOutcome.is_valid_result(` hits in destiny-branch.md
- Zero `outcome: int` hits in F-DB-1 `resolve()` signature
- `@abstract` annotation present on `_apply_f_sp_1` base
- AC-DB-20f + AC-DB-20g + AC-DB-39 present
- F-DB-3 vocabulary count exactly 12 entries
- Every ADVISORY AC carries owner + gate + promotion condition
- Pre-Implementation Gate Checklist section present
- accessibility-requirements.md §2 enumerates 7 Intermediate toggles (not 6)
- scenario-progression.md §Interactions line 189 lists 9 fields (not 6)
- OQ-DB-11 + OQ-DB-16 closed; OQ-DB-17 present

Verdict candidates for pass-10: APPROVED (likely per creative-director senior synthesis — rev 1.3 consolidates every pass-9 finding + adjudicates 4 outstanding design calls; scope does not warrant further adversarial passes). User may opt to accept rev 1.3 as approved without pass-10 given diminishing returns + atomic cross-doc landing this session.

---

## Review — 2026-04-19 — Verdict: APPROVED (pass-10)
Scope signal: S–M
Specialists: none (lean mode; project `production/review-mode.txt = lean`, consistent with pass-9)
Blocking items: 0 | Recommended: 2 Tier-2 + 1 Tier-3 (all fixed in-session as rev 1.3.1 patch)
Summary: Tenth-pass clean-session re-review against the pass-10 precondition checklist established at end of pass-9. All 10 preconditions verified: `@abstract` annotation present, AC-DB-20f/20g/39 present, F-DB-3 = 12 entries, Pre-Implementation Gate Checklist present, ADVISORY ACs carry owner+gate+promotion, `outcome: int` absent from `resolve()` signature, accessibility-requirements.md §2 has 7 Intermediate toggles, scenario-progression.md §Interactions line 189 lists 9 fields, OQ-DB-11/16 closed, OQ-DB-17 present. Single precondition residual (1 `BattleOutcome.is_valid_result(` hit at F-DB-1 step 1c comment) resolved by stripping the rejected-API breadcrumb. Two stale vocabulary counts (AC-DB-21 "all 5", AC-DB-34 "all 10") bumped to 12 per rev 1.3 F-DB-3. Creative-director pass-9 prediction of APPROVED-at-pass-10 confirmed.
Prior verdict resolved: Yes — pass-9 NEEDS REVISION (rev 1.3 11 T1 + 9 T2 landed atomically) resolved to pass-10 APPROVED.

### Rev 1.3.1 in-session patches (3)

| # | Finding | Severity | Fix |
|---|---|---|---|
| P1 | AC-DB-21 line 889 "all 5 vocabulary paths" stale (rev 1.2→1.3 count-bump missed this AC) | Tier-2 | → "all 12 vocabulary paths per F-DB-3 rev 1.3" + evidence-line count updated |
| P2 | AC-DB-34 lines 934–935 "all 10 invalid_reason vocabulary values per F-DB-3 rev 1.2" + "all 10 invalid-path fixtures" stale | Tier-2 | → "all 12" + rev 1.3 cite + 2 rev 1.3 entries (branch_table_empty, is_draw_fallback_outcome_mismatch) enumerated in parenthetical; fixture-seam AC-DB-20f/20g referenced |
| P3 | F-DB-1 step 1c comment still named the rejected `BattleOutcome.is_valid_result(outcome)` API | Tier-3 cosmetic / pass-10 precondition #1 residual | Comment rewritten to describe the GDScript-native membership pattern without naming the rejected API; pass-10 precondition #1 now PASSES cleanly |

### Pass-10 precondition verification (10/10 PASS)

| # | Precondition | Evidence |
|---|---|---|
| 1 | Zero `BattleOutcome.is_valid_result(` hits | After P3 patch: grep returns no matches |
| 2 | Zero `outcome: int` in `resolve()` signature | grep `outcome: int` returns no matches |
| 3 | `@abstract` on `_apply_f_sp_1` base | Line 279 (Godot 4.5+ annotation) |
| 4 | AC-DB-20f + AC-DB-20g + AC-DB-39 present | Lines 881, 884, 915 |
| 5 | F-DB-3 vocabulary exactly 12 entries | Table 318–331 = 12 rows; AC-DB-23 asserts exact 12-element set |
| 6 | Every ADVISORY AC carries owner+gate+promotion | AC-DB-07, AC-DB-23, AC-DB-24, AC-DB-33 all formatted `[Owner: X. Gate: Y. Promotion: Z.]` |
| 7 | Pre-Implementation Gate Checklist present | Line 515 — consolidates 6 MVP + 4 VS + 1 MVP-exit gates |
| 8 | accessibility-requirements.md §2 = 7 Intermediate toggles | rev 1.1 landed: text-scaling, subtitles, input-remapping, colorblind, reduced-motion, high-contrast, reduce_haptics |
| 9 | scenario-progression.md §Interactions line 189 = 9 fields | rev v2.0-patch 2026-04-19: chapter_id, branch_key, outcome, echo_count, is_draw_fallback, is_canonical_history, reserved_color_treatment, is_invalid, invalid_reason |
| 10 | OQ-DB-11 + OQ-DB-16 closed; OQ-DB-17 present | Line 975 (OQ-DB-11 RESOLVED), 981 (OQ-DB-17), 982 (OQ-DB-16 RESOLVED) |

### Dependency graph (all present)

| Dep | Status |
|---|---|
| design/gdd/scenario-progression.md | ✓ exists (v2.0-patch 2026-04-19; §Interactions line 189 synced to 9-field) |
| design/gdd/grid-battle.md | ✓ exists (v5.0 revision pending — BattleOutcome class_name still BLOCKING in Pre-Implementation Gate Checklist) |
| design/accessibility-requirements.md | ✓ exists (rev 1.1; 7 toggles) |
| design/ux/interaction-patterns.md | ✓ exists (IP-006 Beat-7 carve-out landed) |
| docs/architecture/ADR-0001-gamebus-autoload.md | ✓ exists (minor amendment still BLOCKING) |
| docs/architecture/ADR-0002-scene-manager.md | ✓ exists |
| docs/architecture/ADR-0003-save-load.md | ✓ exists |

### Review pass history

- 2026-04-19 pass-7: NEEDS REVISION → rev 1.1 (7 T1 + 10 T2 resolved)
- 2026-04-19 pass-8: NEEDS REVISION → rev 1.2 (12 T1 + ~18 T2 resolved; 4 D1-D4 rev 1.2 decisions)
- 2026-04-19 pass-9: NEEDS REVISION → rev 1.3 (11 T1 + 9 T2 resolved; 4 D1-D4 rev 1.3 decisions)
- 2026-04-19 pass-10: **APPROVED** → rev 1.3.1 (0 blocking; 2 Tier-2 + 1 Tier-3 doc-hygiene patches in-session)

### Implementation-open gates still outstanding (other docs)

destiny-branch GDD is APPROVED, but implementation story is GATED until the Pre-Implementation Gate Checklist items land in other docs:
- [ ] ADR-0001 amendment (9-field payload + BattleOutcome class_name + invalid-path emission + 12-entry vocabulary)
- [ ] scenario-progression v2.1 F-SP-1 output contract + `is_canonical_history` authoring schema + exactly-one-canonical validator
- [ ] scenario-progression v2.1 UX.2 Beat-7 carve-out acknowledgment referencing IP-006 + UI-DB-5
- [ ] Grid Battle v5.0 `class_name BattleOutcome` top-level declaration
- [x] reduce_haptics toggle in accessibility-requirements.md §2 (LANDED rev 1.3)
- [x] scenario-progression §Interactions line 189 synced (LANDED rev 1.3)
