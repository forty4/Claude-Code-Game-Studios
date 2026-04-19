# Scenario Progression — Design Review Log

Target: `design/gdd/scenario-progression.md`
Owner: narrative-director (supporting: game-designer, systems-designer)

---

## Review — 2026-04-18 — Verdict: MAJOR REVISION NEEDED
Scope signal: XL
Specialists: game-designer, systems-designer, narrative-director, ux-designer, audio-director, qa-lead, godot-specialist, creative-director
Blocking items: 30 | Recommended: ~20
Prior verdict resolved: First review

Summary: First-pass adversarial review surfaced pillar-level design failures
that cannot be patched incrementally. Three top issues per creative-director
synthesis: (1) Pillar 2 (운명 역전) cascade-claim is architecturally empty at
3–5 chapter linear MVP — the GDD promises consequence propagation that the
data model cannot carry; (2) `retry_attempt_cap = 0` (free unlimited retry)
is ludonarrative dissonance against the defiance thesis — defeat has no
cost, so victory has no meaning; (3) Beat 2 (Prior-State Echo) is a
five-specialist convergent failure — game-designer flags the form as
telling-not-showing, narrative-director flags the lack of a Chapter-1
variant, ux-designer flags 7s arithmetic contradicting the 4–6s envelope,
audio-director flags ≤−24 LUFS as inaudible on mobile primary platform,
qa-lead flags AC-SP-20 as untestable. Additional cross-cutting failures:
Pillar 4 DRAW-to-LOSS mapping erases historical texture; three "tuning
knobs" (GameBus ADR status, chapter count, retry cap) are actually
contracts not knobs; mobile-primary platform delivery is untestable for
audio and layout; four upstream provisional contracts (Destiny Branch,
Destiny State, Story Event, Save/Load) need pre-commit before this GDD
can stabilize. Pillar-level redesign required before v2.0 revision pass.

Specialist disagreements surfaced (unresolved):
- Pillar 2 MVP reachability — game-designer + narrative-director: unreachable
  at 3–5 linear chapters; creative-director: contests, pre-authored
  divergence could deliver the fantasy within scope.
- Beat 7→8 post-outcome revelation timing — narrative-director: dramatically
  inverted (the judgment beat comes after the outcome is already known);
  game-designer: does not flag.

Broken cross-references: `design/gdd/game-pillars.md` referenced in the GDD
but does not exist — pillars live in `design/gdd/game-concept.md`.

Next action: fresh-session pillar-alignment pass (single batched
AskUserQuestion to creative-director resolving Pillar 2 framing, retry
consequence model, DRAW policy, Beat 2 redesign, GameBus ADR status)
BEFORE touching the file. Same pattern as grid-battle v5.0 prep.

---

## Review — 2026-04-18 — Verdict: MAJOR REVISION NEEDED (v2.0 re-review)
Scope signal: M leaning L (~12–16h revision)
Specialists: game-designer, systems-designer, narrative-director, ux-designer, audio-director, qa-lead, godot-specialist, creative-director
Blocking items: 34 | Recommended: ~22
Prior verdict resolved: No — same-severity regression. V2.0 resolved all 30 v1.0 structural
blockers but introduced a **pillar-integrity regression** on Echo-gate mechanic.

Summary: V2.0 rewrite delivered on the 5 locked pillar decisions (pre-authored
divergence, Echo-state retry cost, DRAW tri-state, multi-modal Beat 2, ADR-0001
binding) and closed all 30 v1.0 blockers. However, three pillar-level defects
emerged in the Echo mechanic itself: (1) F-SP-1 discards echo_count on WIN, so
1st-attempt WIN = 4th-attempt WIN, erasing the persistence-as-cost doctrine;
(2) echo-gate predicate F-SP-2 creates a dominant degenerate strategy —
players seeking echo-reveal branches are incentivized to deliberately LOSS →
DRAW → farm echo_count, directly contradicting "defiance has a cost"; (3)
F-SP-6 vs TK-SP-5 contradiction on beat_2_envelope — declared "hard constraint"
in F-SP-6 but listed tunable in TK-SP-5 with different safe range. Flagged
independently by game-designer, systems-designer, and ux-designer. Plus ~30
mechanical defects: state count mismatch (12 vs 13 in transition table),
scenario_path_key delimiter collision (`-` conflicts with chapter slugs),
EC-SP-8 unguarded DRAW-fallback recursion, F-SP-3 echo unbounded, F-SP-5
epilogue count vs TK-SP-2 safe range contradiction, Godot memory hazards
(await animation_finished on freed panel, ShaderMaterial leak, GameBus
signal disconnect protocol), AccessKit reduced-motion API unverified on
Godot 4.6, AC-SP-37 LUFS measurement method ambiguous (integrated vs
short-term), dual-focus system UI-6 touch variant missing, WCAG 1.1.1
silent-visual Ch1 variant fallback undefined, and 6 untestable acceptance
criteria. Chapter authoring budget (F-SP-5 up to 243 variants) exceeds
TK-SP-2 safe range [8, 81] — needs producer-locked cap in GDD.

Specialist disagreements surfaced (unresolved):
- Beat 2 Ch1 variant scope — narrative-director: core variant requiring own
  AC entries; main review: single edge case.
- AC-SP-37 LUFS measurement — audio-director: EBU R128 integrated only;
  qa-lead: short-term LUFS for playtest affordability.
- EC-SP-1 empty-branch behavior — ux-designer: visible fallback toast;
  main review: silent fall-through.

Dependency graph: 3 existing (balance-data, grid-battle, hero-database) +
ADR-0001 Accepted; 4 PROVISIONAL correctly flagged (destiny-branch,
destiny-state, story-event, save-load).

Top leverage decision (requires creative-director arbitration BEFORE v2.1):
Does echo modulate branch *selection* (unlocks a third option) OR branch
*flavor* (tints existing options)? Current v2.0 is architecturally ambiguous —
F-SP-1, F-SP-2, F-SP-3 cannot be re-derived until this lands.

Next action: creative-director arbitration on Pillar 2 echo mechanic
(selection vs flavor) in a fresh session, then batch the ~30 mechanical
blockers with the re-derived formulas in one revision pass. Estimated
v2.1 scope: M leaning L, 12–16 hours.

---

## Review — 2026-04-19 — Verdict: CONCERNS → APPROVED (v2.1 + v2.2 close-out)
Scope signal: M
Specialists: narrative-director, systems-designer, game-designer, ux-designer, audio-director, qa-lead, godot-specialist
Blocking items: 5 (v2.1) → 0 (v2.2) | Recommended: ~10 (advisory deferred)
Prior verdict resolved: Yes — pass-2 MAJOR REVISION NEEDED with pillar-integrity Echo regression resolved across v2.1 + v2.2.

Summary: User adjudicated 4 design decisions (Echo SELECTION + first_attempt_resolved anti-farm; WIN+echo cue_tag tinting; F-SP-6 hard-constraint wins; sub-threshold DRAW persistence acknowledgment via draw_after_persistence). v2.1 spawned 5 specialists in parallel for fix authoring (~30 mechanical edits across narrative + systems + godot + ux + qa domains). v2.1 full 7-specialist re-review returned 3 APPROVED + 4 CONCERNS with 5 mechanical blockers all specialist-authored. v2.2 applied: F-SP-1 sub-threshold DRAW persistence cue_tag (B-ND-1), CR-10 dramatic doctrine sentence (B-ND-2), F-SP-3 seal timing prose (systems B-1), AC-SP-38(c)/39(c)/40 ADVISORY tags (qa 3-of-3), AC-SP-41 NEW for draw_after_persistence rendering, UX.7 draw_after_persistence section, Gate Summary v2.2 with 41 ACs explicit enumeration. Narrow v2.2 re-review (narrative-director + systems-designer + qa-lead) all APPROVED.

3 pass-2 pillar-level Echo defects all CLOSED:
- F-SP-1 echo discarded on WIN → cue_tag tinting ("win_after_persistence"); branch unchanged; no new authoring
- F-SP-2 LOSS→DRAW farming → first_attempt_resolved gate; predicate adds NOT first_attempt_resolved
- F-SP-6 vs TK-SP-5 contradiction → TK-SP-5 deleted; hard-constraint sealed in "Explicitly NOT Tuning Knobs" list

3 pass-2 specialist disagreements all resolved:
- Beat 2 Ch1 variant scope (narrative vs main) → AC-SP-38 dedicated coverage (additive to AC-SP-6)
- AC-SP-37 LUFS measurement (audio vs qa) → integrated EBU R128 official gate + short-term informal probe
- EC-SP-1 empty-branch (ux vs main) → EC-SP-13 visible toast + AC-SP-39 (delineated from EC-SP-8 fault path)

Final state: 41 BLOCKING/ADVISORY ACs (10 fixture-independent + 26 deferred-fixture + 8 ADVISORY); 14 Edge Cases (added EC-SP-13 toast, EC-SP-14 WIN+persistence cue_tag); 16 Core Rules; 6 Formulas (all rewritten or extended); 4 user-adjudicated design decisions integrated.

Status: MAJOR REVISION NEEDED → Designed (APPROVED).

Pass history: pass-1 (v1.0 — 30 BLOCKING) → pass-2 (v2.0 — 34 BLOCKING + Echo regression) → v2.1 drafting + 7-spec re-review (CONCERNS) → v2.2 mechanical close-out + narrow re-review (APPROVED).
