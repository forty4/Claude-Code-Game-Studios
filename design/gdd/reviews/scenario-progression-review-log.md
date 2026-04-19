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
