# Grid Battle System — Review Log

## Review — 2026-04-17 — Verdict: NEEDS REVISION → Revised (pending re-review)
Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, ux-designer, qa-lead, economy-designer, creative-director (senior)
Blocking items: 16 | Recommended: 5 | Pillar-alignment design calls: 1
Summary: Grid Battle GDD was structurally complete (all 8 required sections + extensions)
but contained three pillar-level defects undermining "Tactics of Momentum" (Pillar 1):
USE_SKILL bypassed counter-attacks (removing skill-risk), pure RNG evasion punished
planning over reflex, and damage was unbounded (allowing one-shots). Specialists also
flagged 5 convergent defects: counter-attack ordering bug in CR-5, missing unit_died
signal ordering, AI snapshot deep-copy semantics, AI softlock on timeout, animation
deadlock if animation_complete never fires. User adjudicated all design calls
(skills-trigger-counters for damage skills only, 2RN Fire Emblem evasion, DAMAGE_CEILING=150,
AI_DECISION_TIMEOUT_MS=500 with WAIT fallback). Revision applied 21 edits covering
all 16 blockers + 5 consequential updates: CR-3/CR-3a/CR-5/CR-6/CR-8/CR-12 rewrites,
F-GB-2 2RN rewrite, F-GB-PROV damage ceiling, Provisional Contracts full schema,
UI-GB-04 6-part Combat Forecast, S3/S4 two-tap touch flow, 7 AC rewrites with
parameterised tables + fixtures + mocks, 3 new ACs (round reset / WAIT / Facing),
AC-GB-18 reclassified BLOCKING. Final gate: 22 BLOCKING, 0 ADVISORY.
Prior verdict resolved: First review

## Review — 2026-04-17 (2nd pass) — Verdict: MAJOR REVISION NEEDED → Revised v2 (pending 3rd re-review)
Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, ux-designer, qa-lead, economy-designer, creative-director (senior)
Blocking items: 18 | Recommended: 4 | Pillar-alignment design calls: 4 (all user-adjudicated)
Summary: Second review on the revised GDD uncovered 18 new blockers despite first-round fixes.
Core pillar defects remained: F-GB-2's evasion math silently inverted player-facing hit %
(UI lied to the player), DAMAGE_CEILING collapsed directional bonus at high ATK (undermining
the REAR/SIDE tactical payoff), and AC-GB-22 contradicted CR-11 on attack-facing semantics.
Convergent defects: CR-5 did not abort on last-kill (counters could fire after battle_ended),
CR-5 step 9 still relied on implicit signal connection ordering, CR-12 watchdog used
SceneTreeTimer (leaks on early exit), AI snapshot lacked authoritative charge_active + DoT
prediction + commander flag + typed Resource path, test fixtures referenced an undefined
test_map_1x1.tres with "virtual adjacent cell" hand-waving, and 7 ACs had subtle bugs
(strict equality instead of >=, conflated behavior + implementation, real-time dependency,
Skill System fixture gap, negative-assertion ambiguity, missing pipeline-abort AC).
User adjudicated 4 design calls: (1) invert F-GB-2 to hit-semantics so UI is truthful,
(2) two-stage cap (BASE_CEILING=100 pre-direction, DAMAGE_CEILING=150 post-direction) to
preserve directional tactics, (3) CR-11 wins — attack does NOT reorient facing, (4) approve
ink-wash palette kill indicator (묵 brush + 300% 斬 glyph), 15s TWO_TAP_TIMEOUT_S, and
mobile <480pt collapse rules. Revision v2 applied ~20 edits: F-GB-2 2RN hit-semantics,
F-GB-PROV two-stage cap, CR-5 abort gate + new AC-GB-23, CR-5 step 9 explicit orchestrator
call, CR-12 owned Timer + injectable timeout, AI_WAITING substate with CONNECT_ONE_SHOT,
AI snapshot hardened schema, F-GB-1 int/float correction, UI-GB-04 palette + mobile rules,
two-tap timeout + undo, test_map_2x2 fixture, AC-GB-05/08/09/17/19/20/22 rewrites,
new AC-GB-23 for CR-5 abort, gate count 22→23, test file table deduped, fixtures updated.
Final gate: 23 BLOCKING, 0 ADVISORY.
Prior verdict resolved: First review (2026-04-17 1st pass NEEDS REVISION addressed)

## Review — 2026-04-18 (3rd pass) — Verdict: NEEDS REVISION → Revised v3 (pending 4th re-review)
Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, ux-designer, qa-lead, godot-specialist, creative-director (senior)
Blocking items: 15 | Recommended: 5 | Pillar-alignment design calls: 4 (all user-adjudicated)
Summary: Third review surfaced a new tier of correctness bugs despite round-2 fixes — three
unanimous (≥3-reviewer) cross-domain defects (F-GB-PROV Row 3 37 vs actual 36, AC-GB-08(b)
evasion_bonus=50 exceeds MAX_EVASION=30 cap, AC-GB-11 mutual-kill scenario unreachable under
CR-5 step-11 pipeline), a Godot 4.5+ deprecation (`duplicate(true)` → `duplicate_deep()`) the
author couldn't have anticipated from pre-2025 training data, CR-5 step 6 off-by-one
("skip to step 11" should be "skip to step 12"), CR-3 AI_WAITING CONNECT_ONE_SHOT timeout
leak (no explicit disconnect), `battle_ended` accidentally filterable by AI_WAITING signal
whitelist, two Pillar 1 threats (Scout WAIT-loop unkillable-Scout via Ambush, AI pathological
soft-lock without round-level escalation), UI-GB-04 120ms render budget lacking a BLOCKING AC,
and 7+ Grid Battle constants missing from entities.yaml registry. User adjudicated 4 design
calls: (1) Scout WAIT-loop closed by adjacent-ZoC Ambush suppression (enemy in Manhattan-1
disables Ambush), (2) AI soft-lock escalation via CR-3b round reset to next player turn
(AI_SOFTLOCK_THRESHOLD=2 consecutive timeouts bypasses remaining AI units for that round),
(3) CR-7 contradiction resolved to VICTORY-takes-priority (aligns evaluation order table;
AoE-only simultaneous kill scenario), (4) qa-lead AC rewrites handled as light clarification
inline rather than structural rewrite. Revision v3 applied 18 edits: `duplicate_deep()`
migration (3 sites), CR-3 explicit disconnect + `battle_ended` whitelist, substate table
+ diagram updated, CR-5 step 6 rewritten, F-GB-PROV Row 3 fixed to 36, AC-GB-08(b) fixed
to evasion_bonus=30 roll=80, AC-GB-11 rewritten for AoE scenario, EC-GB-02 rewritten,
CR-7 contradiction rewritten, CR-6 Scout Ambush adjacent-ZoC clause, EC-GB-18 updated,
new EC-GB-37/EC-GB-38 (Scout WAIT interactions), new CR-3b AI soft-lock escalation,
AC-GB-05/09/17 observable-effect assertions added inline, new AC-GB-24 (UI-GB-04 120ms
render budget) + new AC-GB-25 (CR-3b soft-lock escalation) both BLOCKING, AI_SOFTLOCK_THRESHOLD
tuning knob added, 2 new test files registered, 7 new constants + 2 referenced_by updates
in design/registry/entities.yaml, header updated to Revision v3 / 2026-04-18. Final gate:
25 BLOCKING, 0 ADVISORY (up from 23 due to 2 new ACs covering new rules).
Prior verdict resolved: 2nd pass (2026-04-17 MAJOR REVISION NEEDED 18 blockers all closed;
3rd pass found new issues rather than residue from 2nd pass)

## Review — 2026-04-18 (4th pass) — Verdict: NEEDS REVISION (light) → Revised v3.1 (pending 4th re-review close-out)
Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, ux-designer, qa-lead, godot-specialist, creative-director (senior)
Blocking items: 3 | Recommended: 3 | Pillar-alignment design calls: 0 (all BLOCKING findings were in-document contract/arithmetic bugs with no pillar ambiguity)
Summary: Fourth review surfaced a thin tier of residual bugs (22 findings total across 6 specialists;
CD synthesis downgraded 2 qa-lead findings from BLOCKING to ADVISORY as test-infra issues rather
than in-document contract gaps). Three true BLOCKING items: (1) ai-programmer — CR-3b step 3
flushed remaining AI turns with `unit_turn_started → unit_turn_ended` only, bypassing the
`unit_waited(unit_id)` signal required by AC-GB-21, leaving UI-GB-01 initiative strip unable to
register the bypass; (2) systems-designer — F-GB-PROV D_mult variable table declared range 1.0–2.25
with a "Scout class mod 1.5×" justification, but Unit Role CR-6a caps class direction modifier at
×1.2 (Cavalry REAR), making the true maximum 1.80, and Worked Examples Row 6 "Scout REAR Charge"
was doubly unreachable (Scouts cannot Charge — CAVALRY-only per Unit Role CR-4/F-1); (3) ux-designer
— UI-GB-04 mobile collapse rule (<480pt viewports) hid section 3 (counter-attack line) behind a
chevron with no persistent affordance signalling counter-eligibility, violating Pillar 1
("is it safe to attack?") on mobile. Three ADVISORY items: (4) qa-lead/godot-specialist convergence
— AC-GB-24 referenced `is_layout_complete()` which is not a Godot 4.6 API; (5) qa-lead —
AC-GB-25 assertion 6 "critical log entry with round number + timed-out unit ids" was underspecified
for test assertion; (6) housekeeping — CR-3b `ai_soft_lock_counter` reset behaviour ambiguous on
mid-round `battle_ended`. No design calls required — all fixes were contract clarifications,
arithmetic corrections, and signal-plumbing repairs. Revision v3.1 applied 8 edits: CR-3b step 3
unit_waited emission made mandatory, CR-3b step 4 CLEANUP-abandonment clause appended, F-GB-PROV
D_mult row rewritten (range 1.0–1.80, explicit CR-6a class modifier enumeration, Charge clarified
as ATK factor), Worked Examples Row 6 rewritten as Cavalry REAR Charge (D_mult=1.80) with updated
footnote and paragraph, UI-GB-04 chevron 묵 dot indicator for counter_will_fire, AC-GB-24 replaced
is_layout_complete() with `resized` signal + single-frame await, AC-GB-25 assertion 6 rewritten as
exact push_error contract with GdUnit4 ErrorCapture fixture, header bumped to v3.1. Final gate:
25 BLOCKING, 0 ADVISORY (unchanged — v3.1 modified contract language, no new ACs).
Prior verdict resolved: 3rd pass (2026-04-18 NEEDS REVISION 15 blockers all closed;
4th pass found a thin residual tier with no pillar-level defects, consistent with convergence)

## Review — 2026-04-18 (5th pass) — Verdict: MAJOR REVISION NEEDED → Revised v3.2 (pending 5th re-review close-out)
Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, ux-designer, qa-lead, godot-specialist, creative-director (senior)
Blocking items: 8 | Recommended: 5 | Pillar-alignment design calls: 4 (all user-adjudicated, batched)
Summary: Fifth review surfaced 8 BLOCKING + 5 ADVISORY. The pattern vs 4th pass (3 BLOCKING) is
convergence-not-divergence — two thin seams kept resurfacing because v3.0/v3.1 patches were
symptomatic rather than contractual: (A) CR-3b AI soft-lock contract (threshold crossing leaked
Timer/CONNECT_ONE_SHOT listeners from CR-3 step 2 into the synthesized auto-WAIT path; per-unit log
double-fired at threshold; bypassed_units set membership was undefined for the triggering unit),
and (B) UI-GB-04 mobile chevron (binary dot indicator collapsed counter-fires and counter-kills
into one affordance, violating Pillar 1 "is it safe to attack?" on <480pt viewports; 44×44pt
touch target not enforced on chevron itself). Three further BLOCKING items were
contract/arithmetic bugs the 4th pass had glossed: F-GB-PROV Worked Examples Row 2 omitted
the Cavalry FLANK ×1.1 class modifier (D_mult written 1.2, correct value 1.32; Stage 2 result
floor(64×1.32)=84, not 76); Control.resized signal is silent on same-size re-renders so AC-GB-24's
`resized` + frame-await seam was non-deterministic for the 120ms render budget assertion; AC-GB-25
assertion 6 used a fabricated GdUnit4 `ErrorCapture` fixture (actual 4.5+ API is `monitor_errors()`
+ `assert_error_monitor`). Two ADVISORY items: AC-GB-25 missed the full `unit_waited` signal
triad per bypassed unit and the CONNECT_ONE_SHOT listener-count assertion after bypass; CLEANUP
state did not reset `ai_soft_lock_counter` (stale state leak into next battle). Creative-director
synthesis: Pillar 1 AT RISK on mobile — address via two-tier chevron encoding (dot for counter-fires,
斬 micro-glyph for counter-kills) and treat CR-3/CR-3b as a single unified state-machine contract
rather than independent handlers. User adjudicated 4 design calls as a single batched AskUserQuestion:
(1) single log at threshold crossing — suppress CR-3 step 2 per-unit log for the triggering unit,
(2) split CR-3b into two separate log entries (detection + completion) with explicit bypassed_units
membership (triggering unit excluded, only remaining AI units listed), (3) two unconditional
`await get_tree().process_frame` for AC-GB-24 layout-complete seam (replaces non-deterministic
Control.resized), (4) two-tier chevron encoding (6px 묵 dot for counter_will_fire, 10px 斬
micro-glyph for counter_will_kill) with 44×44pt chevron minimum touch target. Revision v3.2
applied 14 edits: CR-3 step 2 log-suppression rule for threshold-crossing unit; CR-3b full
5-step rewrite (detection/completion split, explicit bypassed_units definition, AI_WAITING
bypass guard `if ai_soft_lock_counter >= AI_SOFTLOCK_THRESHOLD and is_player_controlled == false:
synthesize_auto_wait(); return` placed inside CR-3 step 2 to short-circuit before Timer arm);
CR-1 new step 10 `Initialize ai_soft_lock_counter = 0` (emit renumbered to step 11); CLEANUP
state row now resets `cooldown_map`, `ai_soft_lock_counter = 0`, `movement_budget_map`;
F-GB-PROV D_mult numeric-coincidence guard (×1.2 Cavalry REAR class vs ×1.2 Charge ATK — do
NOT compound to ×1.44); F-GB-PROV Worked Examples Row 2 rewritten D_mult=1.32 Stage 2
floor(64×1.32)=84 with updated footnote D_mult derivation; UI-GB-04 mobile collapse two-tier
chevron (6px 묵 dot counter_will_fire, 10px 斬 micro-glyph counter_will_kill, 44×44pt chevron
minimum, scroll anchor bottom-edge); AC-GB-24 replaced `resized` seam with two unconditional
`await get_tree().process_frame`; AC-GB-25 7 assertions rewritten with exact signal triad per
bypassed unit, CONNECT_ONE_SHOT listener-count assertion, GdUnit4 `monitor_errors()` /
`assert_error_monitor` pattern, explicit `bypassed_units=[3,4]` (triggering unit 2 excluded),
5-unit fixture declared; AC-GB-21 CR-3b auto-WAIT binding clause added; fixtures list gained
`test_map_softlock_5unit.tres` and `attack_target_hovered_timing_probe.gd`; BATTLE_LOADING
state updated "CR-1 steps 1-10" → "1-11"; header bumped to v3.2. Final gate: 25 BLOCKING,
0 ADVISORY (unchanged — v3.2 modified contract language, arithmetic, fixtures, and signal
assertions; no new ACs).
Prior verdict resolved: 4th pass (2026-04-18 NEEDS REVISION light 3 BLOCKING + 3 ADVISORY all
closed; 5th pass found 8 BLOCKING but specialists confirmed convergence pattern — same two
seams resurfacing as contract-level rather than patch-level fixes)

## Review — 2026-04-18 (6th pass) — Verdict: MAJOR REVISION NEEDED → Revised v4.0 (pending 6th re-review close-out)
Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, ux-designer, qa-lead, godot-gdscript-specialist, creative-director (senior)
Blocking items: 13 (P0) | Recommended: 5 | Pillar-alignment design calls: 6 (all user-adjudicated, batched)
Summary: Sixth review found the v3.2 GDD had reached a cognitive-load ceiling at 982 lines —
creative-director's strategic recommendation was to split the monolith before further review
passes would diverge again. Specialists concurrently flagged 13 P0 BLOCKING items spanning
three families: (A) underspecified player-facing actions (DEFEND unspecified mechanically,
Archer counter-range ambiguous on non-natural ranges, WAIT vs END_TURN conflation, TacticalRead
role ability unspecified); (B) Godot 4.6 API correctness (`random_int` doesn't exist — must be
`randi_range`; IEEE 754 float drift in F-GB-PROV required `snappedf` quantization; "mobile
renderer" vague vs Vulkan Forward+); (C) test-ability gaps (no boundary-value AC for F-GB-PROV,
no DEFEND reduction AC, no END_TURN batch AC, AC-GB-25 listener-count missing
GdUnitArgumentCaptor + movement_budget_map post-flush assertion). Counter-kill forecast accuracy
was also unstated (no max-roll contract) — a Pillar 1 "is it safe to attack?" violation.
User adjudicated 6 design calls as a batched AskUserQuestion (all Recommended options taken):
DC-1 DEFEND = 50% reduction, ends turn, NO counter-attack, 1-turn duration;
DC-2 WAIT = per-unit pass (triggers unit_waited signal), END_TURN = player-level batch (flushes
remaining units via CR-3b synthesis path); DC-3 Archers counter ONLY at natural attack range
(range 2) — no adjacent-melee counter-jab; DC-4 TacticalRead = Strategist/Commander see forecast
one grid further than their natural attack range; DC-5 render budget contract asserts Vulkan
Forward+ only (mobile OpenGL compat deferred to post-MVP); DC-6 PC hover-off dismisses forecast
immediately with 80ms fade (no sticky forecast). Revision v4.0 applied a structural refactor
plus 13 P0 fixes. Structural: extracted all Visual/Audio Requirements + UI-GB-01..11 from
grid-battle.md into new companion spec design/ux/battle-hud.md (555 lines, 11 sections, 8
AC-UX-HUD acceptance criteria, 10 tuning knobs). Core GDD additions: CR-3a (WAIT/END_TURN
disambiguation), CR-6a (Archer natural-range-only counter), CR-13 (DEFEND full contract),
CR-14 (TacticalRead +1 grid forecast), F-GB-2 `randi_range(0, 99)` Godot 4.6 rewrite,
F-GB-PROV `snappedf(D_mult, 0.01)` + `floori`/`mini` typing + two-stage ceiling block,
F-GB-3 Counter-Kill Forecast max-roll formula (2RN upper-bound; over-warn never under-warn
pillar contract), EC-GB-39..44 for new rules, AC-GB-07b (F-GB-PROV boundary values),
AC-GB-09 cases (h) DEFEND_STANCE + (i) Archer adjacency, AC-GB-10b (DEFEND 50% reduction
contract), AC-GB-21b (END_TURN batch flush), AC-GB-21c (DEFEND stance integrity),
AC-GB-24 Vulkan Forward+ renderer assertion, AC-GB-25 assertion 3 GdUnitArgumentCaptor
listener-count delta + `movement_budget_map[flushed_id] == 0` post-flush, DEFEND_DAMAGE_REDUCTION
tuning knob (default 0.5, range 0.3–0.7), snapshot schema extended with `has_tactical_read` +
`tactical_read_forecasts`, header bumped to v4.0. Battle HUD UX spec covers: UI-GB-04 two-tier
chevron §4.2 counter-kill accuracy, §4.3 mobile collapse, §4.4 two-tier encoding (6px 묵 dot
Tier 1 / 10px 斬 micro-glyph Tier 2), §4.5 PC hover-off 80ms fade, §4.6 Forward+ 120ms render
budget; UI-GB-11 DEFEND Stance Badge; full UX-EC-01..07 edge cases; 8 AC-UX-HUD gate criteria.
Final gate: 25 BLOCKING in core GDD + 8 AC-UX-HUD in battle-hud.md = 33 total gate ACs.
Prior verdict resolved: 5th pass (2026-04-18 MAJOR REVISION NEEDED 8 BLOCKING + 5 ADVISORY all
closed via v3.2; 6th pass identified structural ceiling rather than residue — split + 6 new
design decisions, not refinement of prior fixes)

## Review — 2026-04-18 (6th pass close-out) — Verdict: MAJOR REVISION NEEDED
Scope signal: XL
Specialists: game-designer, systems-designer, ai-programmer, ux-designer, qa-lead, godot-gdscript-specialist, creative-director (senior)
Blocking items: 22 | Recommended: 13 | Pillar-alignment design calls: 4 pending (DC-7..DC-10)
Summary: Sixth re-review on v4.0 (post-split) did NOT converge to APPROVED as targeted. All 6
specialists independently returned blocking findings; creative-director synthesis confirmed the
revision process has lost coherence. Two pillar-level design failures cannot be patched as ACs:
(1) DEFEND (DC-1) dominates WAIT for 5 of 6 classes — collapses stance decision space and nullifies
Pillar 3 ("모든 무장에게 자리가 있다"); (2) UI-GB-04 §4.3 mobile-collapse hides counter-kill chevron
AND direction badge on declared primary platform, violating Pillar 1 "never under-warn" forecast
contract. Cross-document contradictions: EC-GB-42 long-press-to-confirm vs battle-hud.md §1
tap-only; battle-hud.md header cites v3.2 parent instead of v4.0; DEFEND_STANCE counter-suppression
reason absent from forecast tooltip. Arithmetic/interface errors: BASE_CEILING=100 violates stated
invariant 150/1.80=83.33; F-GB-1 ROAD×0.5=3 below stated floor 5; F-GB-3 passes evasion_bonus to
F_GB_PROV which doesn't accept it; F-GB-2 clamp[1,99] creates "never 100%/never 0%" footgun;
AC-UX-HUD-04 claims 25pt ≤ 22pt (25>22); AC-GB-25 uses wrong GdUnit4 captor API. Intra-document
contradictions: AC-GB-09 cases (h) vs (i) on wait_pressed timing; AC-GB-21b garbled sentence;
AC-GB-21c conflates logic + UI; AC-GB-24 no CI non-determinism bypass; AC-UX-HUD-03 80ms vs
§4.5 40ms hysteresis = 120ms; AC-UX-HUD-07 "full turn cycle" undefined. State-machine gaps:
CR-3a signal filter not implementable at dispatch layer + unit_died routing during AI_WAITING
unspecified; battle_ended mid-flush race; charge_active vs unit_waited split-brain; F-GB-3 T_def
underspecified (includes counter damage? modified by DEFEND?); timer.start() null coercion footgun.
User closed session without revising — opted to plan v5.0 pillar-alignment pass separately
(resolve DC-7..DC-10 in dedicated design session first, then reconcile grid-battle.md + battle-hud.md
together against shared invariants table). Creative-director recommendation: pause targeted edits,
run single pillar-alignment read of full bundle, submit v5.0 not v4.1.
Prior verdict resolved: No — 6th pass (v4.0 structural split + 14 edits) did NOT fully close
prior blockers; 22 new blockers surfaced from unaddressed pillar-level + document-hygiene layers.

## Review — 2026-04-19 (7th pass, full mode) — Verdict: MAJOR REVISION NEEDED → STOP for fresh v5.0 session (per creative-director)
Scope signal: XL
Specialists: systems-designer, ai-programmer, ux-designer, qa-lead, game-designer, creative-director (senior synthesis)
Blocking items: 32 | Recommended: 17 | Pillar-alignment design calls: ~12 pending (to be batched at start of v5.0 session, NOT in this session)
Summary: Seventh pass confirmed creative-director's pass-6 prediction. User did NOT execute the v5.0 pillar-alignment pass recommended by pass-6 CD; instead, the v4.0 document was left unmodified and re-reviewed. Result: 0 of 6 pass-6 blockers closed; 5 specialists converged independently on the same structural faults, producing 32 BLOCKING items that collapse without residue to 5 root causes.

**Five root causes (no residue — all 32 blockers map here):**

1. **RC-1 Registry drift (7 blockers)**: grid-battle.md + battle-hud.md carry stale values that authoritative sources have moved past. BASE_CEILING/DAMAGE_CEILING three-way schism (tuning knobs 100/150 vs F-GB-PROV table 100/150 vs entities.yaml 83/180) WIDENED from pass-6's two-way. battle-hud.md §4.6 cites "Vulkan Forward+" as project-wide renderer (contradicts tech-prefs D3D12/Windows, Metal/macOS/iOS). DEFEND_STANCE reduction CR-13 50% vs entities.yaml 30% (hp-status.md-owned) with no cross-doc acknowledgment. F-GB-PROV declared "superseded 2026-04-18" by damage-calc.md but still referenced throughout §CR-5, all ACs, §Tuning Knobs, F-GB-3 pseudocode. F-GB-1 ROAD×0.5=3 violates stated floor of 5. battle-hud.md header still cites v3.2 parent (parent is v4.0). Findings: P7-BLK-01/02/03/04/06/07, UX-B-1.

2. **RC-2 Parallel-document contradiction between grid-battle.md and battle-hud.md (6 blockers)**: EC-GB-42 says long-press for mobile DEFEND confirm, §5.1 forbids long-press for primary actions — active contradiction. "Defender is defending" counter-suppression reason in CR-13 rule 4 absent from UI-GB-04 §4.1 enumerated reason list. CR-6 counter-eligibility table missing DEFEND_STANCE row (programmer implementing CR-6 alone produces wrong system). Mobile DEFEND has no valid confirm interaction model (three incompatible models across EC-GB-42, §5.1, AC-GB-21c). AC-UX-HUD-03 deadline t+80ms missing 40ms hysteresis (should be t+120ms). AC-UX-HUD-07 "full turn cycle" undefined. Findings: UX-B-2/3/4/5/6/7, GD-B-1/B-2.

3. **RC-3 Unresolved design question masquerading as a spec (4 blockers, Pillar 3 trajectory: AT RISK → VIOLATED)**: WAIT vs DEFEND vs TacticalRead class-identity is not a drafting problem — it is a design decision that was never made. DEFEND is universally available with identical mechanics for all 6 classes, making WAIT vestigial for 5/6 classes. CR-13 rule 2 does NOT specify `acted_this_turn` behaviour on DEFEND (breaks Scout Ambush, END_TURN, implementability). CR-13 rationale misrepresents what DEFEND delivers (claims Infantry/Commander class identity but mechanics are class-agnostic). Strategist vs Commander overlap ~90% — Strategist strictly dominated. game-designer recommendation: "GD-B-3/GD-B-4/GD-B-5 are expressions of the same root problem — GDD does not have a coherent model of how class identity is expressed through the DEFEND/WAIT layer." Findings: GD-B-3/B-4/B-5/B-6.

4. **RC-4 State machine / signal plumbing under-specification (5 blockers)**: CR-3 AI_WAITING "drop all signals except X/Y/Z" is not implementable in Godot (no engine-level signal gate; requires per-handler guard clauses — spec is silent). `unit_died` filtered during AI_WAITING breaks CR-7 victory evaluation for DoT deaths (filter drops `unit_died`, but `battle_ended` depends on `unit_died` firing). CR-3b flush loop has no `battle_ended` abort guard — stale completion log if DoT kills last enemy mid-flush. Timer wait_time=0 footgun has no guard (misconfigured Timer → immediate AI timeout → immediate softlock). `charge_active` snapshot staleness after CR-3b flush unspecified. Findings: AI-B-1/B-2/B-3/B-4/B-5.

5. **RC-5 Acceptance criteria written as aspirations, not tests (11 blockers)**: AC-GB-21b garbled sentence unchanged from pass-6. AC-GB-21c mixes logic + render (unit test asserts badge rendering). AC-GB-24 no CI/Vulkan bypass — will permanently block headless CI. AC-GB-25 (3) `GdUnitArgumentCaptor` misused for connection-count assertion; AC-GB-25 (6) `monitor_errors()` intercept of `push_error` unverified. AC-GB-01 "no spurious events" has no closed expected-signal set. AC-GB-05 `base_atk` fixture value undeclared. AC-GB-08 missing roll=70/hit_chance=70 off-by-one boundary. AC-GB-25 fixture initiative stat values unspecified — unreproducible. AC-GB-19(b) snapshot access method unspecified. AC-UX-HUD-04 tap-offset arithmetic wrong (22pt > 17pt padding). Findings: QA-B-1..B-10, UX-B-4, AI-B-6.

**Cross-specialist convergence (5 independent reviewers → same 4 structural faults):**
- WAIT/DEFEND class identity: game-designer GD-B-3/4/5, ux-designer UX-R-1/R-3, systems-designer P7-BLK-07 (5 symptoms, 1 root cause)
- grid-battle↔battle-hud divergence: systems-designer BLK-06 + ADV-03, ux-designer UX-B-1/2/3/6/7, game-designer GD-B-1 (7 symptoms, 1 root cause)
- DEFEND confirmation model: systems-designer ADV-02, ux-designer UX-B-7, game-designer GD-B-6 (3 symptoms, 1 root cause)
- AC untestability: qa-lead QA-B-1..10, ai-programmer AI-B-6, ux-designer UX-B-4/5/6, systems-designer BLK-03 (14+ symptoms, 1 root cause)

**Creative-director senior verdict (pass-7)**:
"Seven passes in, same document fails the same way with more surface area each iteration. Pass-6 predicted this; evidence is now unambiguous. 0 of 6 pass-6 blockers closed cleanly. BASE_CEILING/DAMAGE_CEILING schism WIDENED (2 sources → 3). Targeted editing has negative yield — v4.0 has net more blockers than v3.x. Three of five root causes are cross-document (RC-1 registry drift, RC-2 parallel-doc, RC-4 signal plumbing across damage_calc/hp_status) — cannot be fixed inside grid-battle.md. RC-3 is a design decision, not a drafting task — you cannot draft your way out of 'we haven't decided what DEFEND means for class identity.' Path: STOP for fresh v5.0 authoring session. Do not attempt in-session revision."

**V5.0 session minimum brief (for fresh session inheritance):**
- Load bundle (read-only, full): entities.yaml (stat-value truth); .claude/docs/technical-preferences.md (render/input truth); damage-calc.md + hp-status.md (formula/state truth); grid-battle.md v4.0 + battle-hud.md v1.0 (read to identify drift, NOT to patch); pillar anchor (game-concept.md Pillars §).
- **Adjudicate upfront via one batched AskUserQuestion (before drafting):**
  1. DEFEND_STANCE reduction canonical value + which doc owns it (50% CR-13 vs 30% entities.yaml hp-status.md)
  2. WAIT's class-identity purpose — Scout-only niche acceptable, or give WAIT a distinct mechanic for all classes, or cut WAIT
  3. `acted_this_turn` semantics on DEFEND (true vs false — affects Scout Ambush and END_TURN batch)
  4. TacticalRead visual distinction — yes/no + ownership (grid-battle.md vs battle-hud.md)
  5. Mobile DEFEND confirm — two-tap, modal dialog, or cut from mobile entirely
  6. BASE_CEILING/DAMAGE_CEILING single source of truth (registry or tuning knob) + removal of stale duplicate
  7. Render driver per platform — Vulkan/D3D12/Metal per tech-prefs accepted; remove "Vulkan Forward+" as universal claim
  8. battle-hud.md scope boundary — UI contract only, or allowed to restate Grid Battle rules (RC-2 boundary)
  9. F-GB-PROV retirement — delete or mark historical-only + update all references
  10. Strategist vs Commander mechanical distinction (or accept Strategist is weaker Commander)
  11. AC rewrite strategy for 10+ untestable ACs — rewrite in v5.0 or defer to QA test-plan pass
  12. Fixture authoring — author required .tres/.gd fixtures in-session or gate until tests/ implementation sprint

- **Drafting rules for v5.0**: no value in grid-battle.md unless it cites its registry source by path+field; no AC ships without a named fixture file existing on disk; no cross-doc claim appears without bidirectional reference.
- **Success criterion**: single pillar-alignment read by creative-director returns APPROVED or CONCERNS (not REJECT) on first pass; if not, root cause is design, escalate to design resolution not another revision.

Files modified this session: NONE (grid-battle.md and battle-hud.md unchanged — per CD directive to stop targeted patching).
Prior verdict resolved: NO — pass-6 recommendation (run v5.0 pillar-alignment pass before next review) was not executed; pass-7 is the consequent evidence confirming that recommendation.

## 7-Pass History Snapshot (Grid Battle System)

| Pass | Date | Verdict | Blockers | Notes |
|------|------|---------|----------|-------|
| 1 | 2026-04-17 | NEEDS REVISION | 16 | First review; 3 pillar defects |
| 2 | 2026-04-17 | MAJOR REVISION | 18 | Evasion inversion, damage ceiling |
| 3 | 2026-04-18 | NEEDS REVISION | 15 | Godot 4.5+ deprecations, CR-5 off-by-one |
| 4 | 2026-04-18 | NEEDS REVISION (light) | 3 + 3 ADV | Thin residual tier |
| 5 | 2026-04-18 | MAJOR REVISION | 8 + 5 ADV | Convergence-not-divergence on CR-3b + UI-GB-04 |
| 6 | 2026-04-18 | MAJOR REVISION (close-out) | 22 + 13 REC | v4.0 structural split did NOT converge; CD recommends v5.0 pillar-alignment pass |
| 7 | 2026-04-19 | **MAJOR REVISION → STOP for v5.0** | **32 + 17 REC** | **0 of 6 pass-6 blockers closed; 5 root causes; CD confirms stop-and-restart** |

---

## v5.0 Drafting Session — 2026-04-19 (NOT a review pass)

Scope signal: L (design-systems-level revision)
Specialists consulted: creative-director (senior — pass-7 STOP synthesis), user adjudication on 12 batched design decisions (4 themed AskUserQuestion batches)
This is a **drafting pass**, not a review pass. The next review pass (/design-review of v5.0) is pending.

### 12 design decisions captured (all Recommended paths)

**RC-1 Registry drift (Batch 1):**
1. damage-calc.md is sole owner of `BASE_CEILING = 83` and `DAMAGE_CEILING = 180`; grid-battle.md consumer-only
2. Render driver per-platform (Windows D3D12, Linux+Android Vulkan, macOS+iOS Metal) — reference hardware Pixel 7/Vulkan; budget 120ms applies uniformly
3. F-GB-PROV deleted; all callers migrated to `damage_resolve()`; AC-DC-44 satisfiable

**RC-2 Cross-doc contradictions (Batch 2):**
4. DEFEND_STANCE reduction = 50%, hp-status.md owns (registry `defend_stance_reduction` 30 → 50); grid-battle.md deletes `DEFEND_DAMAGE_REDUCTION` stale duplicate
5. DEFEND_STANCE unit does not counter-attack at all (CR-13 rule 4 wins); hp-status.md EC-14/AC-20 rewritten
6. Mobile DEFEND confirm = two-tap same-target (like ATTACK); long-press + Korean modal retired
7. battle-hud.md scope = strict UI-only; rule-restatement migrated back to grid-battle.md

**RC-3 Class identity (Batch 3):**
8. WAIT kept per-unit as Scout Ambush setup tool (hidden from non-Scout menu by default; Settings toggle `show_wait_for_all_classes`)
9. DEFEND sets `acted_this_turn = true` (CR-13 rule 5 added)
10. TacticalRead UI affordance = Strategist-only (CR-14 rewrite); battle-hud.md UI-GB-12 added with 讀 glyph + 70% opacity
11. Strategist/Commander split: Strategist keeps TR (combat facet — terrain-evasion-ignore per unit-role.md CR-2; UI facet — forecast-extension per grid-battle.md CR-14 v5.0); Commander retains pre-existing `passive_rally` per unit-role.md CR-2 (no Rally-value upgrade in v5.0; deferred to future unit-role revision)

**RC-5 ACs/fixtures (Batch 4):**
12. 10 flagged ACs rewritten inline (AC-GB-10, 10b, 15, 16, 17, 21, 21b, 21c, 24, 25) with Given/When/Then + closed signal sets + fixture refs
13. 8 seed fixtures authored under `tests/fixtures/grid_battle/` + 1 under `tests/fixtures/battle_hud/`; full set deferred to implementation sprint

### Files modified this session

- `design/registry/entities.yaml` — `defend_stance_reduction` 30 → 50 + grid-battle consumer; `two_tap_timeout_s` + battle-hud consumer; NEW `tactical_read_extension_tiles = 1` constant; header rev note
- `design/gdd/hp-status.md` — SE-3 rewrite (50%/no-counter/acted=true/1-turn); EC-02/03 value updates; EC-14 repurposed (no counter); tuning knob 30→50 range 30-70%; AC-06 worked example 14→10; AC-20 repurposed to assert no-counter
- `design/gdd/grid-battle.md` — **v5.0**: header + revision log; CR-5 (F-GB-PROV delete + damage_resolve migration); CR-6 (DEFEND_STANCE suppression row); CR-10 (WAIT Scout-reframe + menu-visibility rule); CR-13 (7 rules + acted_this_turn=true + two-tap confirm); CR-14 (Strategist-only UI affordance + combat/UI facet clarifier); F-GB-PROV section replaced with retirement pointer; F-GB-3 rewritten to damage_resolve+max_roll; EC-GB-15/41/42/43 updated, EC-GB-44 deleted; Dependencies table rewritten; Tuning Knobs (DEFEND_DAMAGE_REDUCTION removed; registry-owned-constants table added); 10 ACs rewritten; fixture list expanded
- `design/ux/battle-hud.md` — **v1.1**: header + v1.1 revision log; §4.2 F-GB-PROV → damage_resolve(max_roll); §4.6 per-platform render-budget policy table; §5.2 NEW DEFEND two-tap flow; UI-GB-11 refresh (value deferred to hp-status); UI-GB-12 NEW TacticalRead Extended Range; AC-UX-HUD-09 NEW mobile DEFEND two-tap contract
- `design/gdd/unit-role.md` — Strategist passive row: combat/UI facet clarifier pointing to grid-battle.md CR-14 v5.0; `tactical_read_extension_tiles` ownership noted
- `tests/fixtures/grid_battle/counter_small.yaml`, `counter_medium.yaml`, `counter_max.yaml` (AC-GB-10 seeds)
- `tests/fixtures/grid_battle/defend_stance_20.yaml`, `defend_stance_min.yaml` (AC-GB-10b seeds)
- `tests/fixtures/grid_battle/defend_basic.yaml` (AC-GB-21c seed)
- `tests/fixtures/grid_battle/wait_scout.yaml` (AC-GB-21 seed)
- `tests/fixtures/grid_battle/end_turn_mixed.yaml` (AC-GB-21b seed)
- `tests/fixtures/battle_hud/defend_two_tap.yaml` (AC-UX-HUD-09 seed)

### Deferred items (implementation sprint)

- Full fixture coverage for AC-GB-15 (`skill_counter_damage/status/heal.yaml`)
- AC-GB-09 case-row data fixtures (cases a–i)
- AC-GB-25 soft-lock fixture file `test_map_softlock_5unit.tres` (scenario exists, content TBD)
- Unit-role.md full Rally → Rally Pulse upgrade (+10% ATK/DEF, cap TBD) — future revision

### Success criterion for v5.0 /design-review (pending)

Single pillar-alignment read by creative-director returns APPROVED or CONCERNS (not REJECT) on first pass. If REJECT, root cause is design (not drafting), and escalate to design resolution rather than another revision.

---

## Review — 2026-04-19 (pass-8) — Verdict: MAJOR REVISION NEEDED (REJECT)

Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, ux-designer, qa-lead, creative-director (senior synthesis)
Blocking items: 25 | Recommended: 12+
Prior verdict resolved: Partial — RC-1 RESOLVED in-doc (1 cross-doc residual in damage-calc.md), RC-2 PARTIAL, RC-3 PARTIAL (Scout win; Strategist/Commander residual + NEW Infantry/Commander overlap from WAIT-hiding), RC-4 3/5 RESOLVED + 2 new, RC-5 NOT RESOLVED (8/10 rewritten ACs defective + 2 ratified-unchanged broken).

### Summary

First /design-review of the v5.0 draft returned REJECT against CD's pass-7 success criterion. 4 specialists said NEEDS REVISION; qa-lead escalated to MAJOR REVISION NEEDED because RC-5 (ACs) — pass-7's explicit fix target — retained 80% defect rate. CD sided with qa-lead severity.

Root cause is MIXED between drafting execution defects and design composition gaps. Drafting defects include: AC-GB-07b stale BASE_CEILING=100/DAMAGE_CEILING=150 arithmetic (should be 83/180 after v5.0 registry ratification — 100→83 change not propagated), AC-GB-07 stale F-GB-PROV reference (ratified-unchanged AC missed in pass-7 rewrite list), AC-GB-01 references `tests/fixtures/test_map_2x2.tres` absent from disk, AC-GB-24 references `.github/workflows/perf-nightly.yml` absent from disk, `damage-calc.md` CR-10 still reads −30% DEFEND_STANCE annotation post-registry ratification to 50%, hardcoded Korean reason string `"반격 없음 — 방어 중"` with no localization key. Design composition gaps include: CR-13 DEFEND rationale ("distinct from WAIT's 'do nothing'") invisible for Infantry/Commander since CR-10 hides WAIT from 5/6 classes by default; `acted_this_turn=true` on DEFEND eliminates "bait Ambush by DEFENDing" tactical loop without design-note justification; `DEFEND_STANCE_ATK_PENALTY=40%` doubly-inert (counter path suppressed by CR-13 rule 4; own-turn primary gate in damage-calc CR-5 requires `is_counter=true`); timeout-substituted WAIT leaves `acted_this_turn=false` creating AI exploitation vector (Scout free-Ambush-target on timed-out AI); Strategist TacticalRead two-facet name collision (terrain-evasion-ignore + forecast-extension under one passive name); AI_WAITING "drop signals" mechanism still unspecified (pass-7 RC-4 residual); `Timer.start()` no `wait_time>0` guard (pass-7 RC-4 residual); "constructor parameter `animation_timeout_override_s`" Godot-incompatible (Node subclasses can't take `_init()` args); DEFEND two-tap cancel ambiguous on valid-move-tile during Beat 1 pending; hover-dismiss race at t=60ms + 40ms hysteresis + 120ms render concurrent window undefined; `show_wait_for_all_classes` Settings toggle has no discovery path; UI-GB-12 8px 讀 glyph WCAG-legibility concern.

### CD senior synthesis (extract)

> "v5.0 drafting resolved RC-1 cleanly and RC-4 partially, but created as many new defects as it fixed in RC-3 and RC-5. Net progress on the 'stop for revise' criteria is positive but not sufficient. Eight of ten rewritten ACs residual-defective, plus two ratified-unchanged ACs broken, plus three design-level composition gaps (WAIT-DEFEND-flag interaction), constitutes structural — not cosmetic — failure of the pass-7 revision plan. Recommend [C] STOP — fresh session for pass-9, split into 9a (drafting fixes only, ~2h mechanical) + 9b (design composition gaps, ~1h user adjudication). Splitting drafting from design reduces context load per session and prevents the 'decision propagation miss' failure mode that produced the AC-GB-07b arithmetic error. Pillar 3 structural fix deferred to v5.1."

User selected [C] STOP per CD recommendation. Pass-9 planning pending.

### Pass-9 scope (CD proposal)

**9a (drafting, ~2h, no design judgment needed)**:
- AC-GB-07b arithmetic fix (150→149, 100→83)
- AC-GB-07 F-GB-PROV removal
- AC-GB-01 fixture file creation or path correction
- AC-GB-24 perf-nightly.yml creation or AC rewrite
- AC-GB-10/10b/15/16/21b/21c/25 defect fixes per qa-lead detailed list
- damage-calc.md CR-10 −30% → 50% correction
- Korean reason string → localization key
- F-GB-2 internal clamp; F-GB-3 rng comment split
- Timer wait_time>0 guard; `_init()` arg fix to @export var pattern

**9b (design composition, ~1h, user adjudication via AskUserQuestion)**:
- WAIT visibility vs CR-13 rationale (resolve the invisibility contradiction)
- DEFEND `acted_this_turn` semantics (rationale document + timeout-substitution flag decision)
- DEFEND_STANCE_ATK_PENALTY scope (deprecate or define call-site gate)
- Battle-length sensitivity check for 50% DEFEND + no-WAIT Infantry scenario

### 8-Pass History Snapshot (Grid Battle System)

| Pass | Date | Verdict | Blockers | Notes |
|------|------|---------|----------|-------|
| 1 | 2026-04-17 | NEEDS REVISION | 16 | First review; 3 pillar defects |
| 2 | 2026-04-17 | MAJOR REVISION | 18 | Evasion inversion, damage ceiling |
| 3 | 2026-04-18 | NEEDS REVISION | 15 | Godot 4.5+ deprecations, CR-5 off-by-one |
| 4 | 2026-04-18 | NEEDS REVISION (light) | 3 + 3 ADV | Thin residual tier |
| 5 | 2026-04-18 | MAJOR REVISION | 8 + 5 ADV | Convergence-not-divergence on CR-3b + UI-GB-04 |
| 6 | 2026-04-18 | MAJOR REVISION (close-out) | 22 + 13 REC | v4.0 structural split did NOT converge; CD recommends v5.0 pillar-alignment pass |
| 7 | 2026-04-19 | MAJOR REVISION → STOP for v5.0 | 32 + 17 REC | 0 of 6 pass-6 blockers closed; 5 root causes |
| v5.0 drafting | 2026-04-19 | (drafting, not review) | — | 12 adjudicated decisions applied across 6 files + 9 seed fixtures |
| 8 | 2026-04-19 | **MAJOR REVISION → STOP for pass-9** | **25 + 12+ REC** | **RC-1 RESOLVED, RC-4 3/5 RESOLVED, RC-5 NOT RESOLVED (8/10 rewritten defective); CD recommends split pass-9a drafting + 9b design** |
