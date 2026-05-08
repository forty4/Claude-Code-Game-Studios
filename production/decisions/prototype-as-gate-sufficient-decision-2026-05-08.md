# Decision: Prototype-side Pillar 4 Atmospheric Demonstration — ACCEPT AS PRE-PROD-TO-PROD GATE-SUFFICIENT

> **Status**: BINDING (sprint-12 S12-03 close-rerun; closes gate-check 2026-05-08-rerun path-to-PASS item 3a)
> **Decision Date**: 2026-05-08
> **Author**: claude (sprint-12 S12-03 close-rerun owner; per gate-check 2026-05-08-rerun §6 Item 3a Route C mandate)
> **Reactivation Owner**: producer (at next gate-check pass; concurrent with stage.txt monitoring)

---

## Decision

**Prototype-side Pillar 4 atmospheric demonstration in `prototypes/chapter-prototype/` is accepted as Pre-Production → Production gate-sufficient evidence for the experiential validation of Pillar 4 (삼국지의 숨결).**

The S12-02 ship (commit chain `f6b14e6` → `17d3f84`; chapter-prototype-demo Demo-epic 1/1 epic-terminal close 2026-05-08) — applying reserved colors 주홍 `#C0392B` panel tint at 0.35α + 금색 `#D4A017` title color + synthesized 묵 hum audio cue (220Hz fundamental + 330Hz harmonic, 1.2s envelope) + 1.5s ceremonial dwell lockout per AC-SP-9 — closes gate-check path-to-PASS item 3a despite landing on a throwaway prototype surface rather than production scenario-runner code.

This is a **deferral with explicit reactivation triggers** — game-facing scenario-runner integration of the atmospheric layer is NOT cancelled; it is bound to the production scenario-runner authoring sprint when one opens. Until then, the prototype demonstration validates the experiential pattern (dispatch shape + reserved-color discipline + audio synthesis envelope + dwell architecture) sufficient for gate eligibility.

## Why accept-as-gate-sufficient (and not ship game-facing now)

Four load-bearing reasons:

1. **Production scenario-runner code does not yet exist.** `src/scenario/` is empty (verified `/dev-story` Phase 2 context scan 2026-05-08). The `chapter-prototype/` is the only Pillar-4 surface in the project; there is no game-facing chapter runtime to promote the atmospheric layer to. Authoring production scenario-runner code is multi-sprint work tracked in the `scenario-progression` Core epic (1/1 Complete since 2026-05-07 — but the epic shipped only the autoload skeleton + state machine substrate, not the chapter rendering surface; chapter rendering belongs to a yet-uncreated Presentation-layer epic). Expecting game-facing Pillar 4 demonstration before that authoring sprint exists is a category error.

2. **Prototype-isolation contract preserves implementation-pattern flexibility for production port.** Per `.claude/rules/prototype-code.md`: "If a prototype validates a concept and the feature moves to production: 1. The prototype code is NOT migrated directly — it is rewritten to production standards." The S12-02 prototype-side dispatch validates the atmospheric pattern (ColorRect-modulate-α + AudioStreamGenerator + Tween + dwell-lockout) without committing to its specific implementation as production-canonical. Production scenario runner is free to choose a different visual-effects layer (e.g., Godot 4.6 World3D post-process composition) when authored.

3. **Experiential validation is preserved across surfaces.** Per `design/gdd/scenario-progression.md` §V.3 Reserved Color Protocol, the binding semantic is "non-default branches receive reserved-color treatment per art bible." S12-02 satisfies this semantically — reserved-color treatment IS applied to non-default branch (REWRITTEN) and IS NOT applied to default branches (DEFEAT/HISTORICAL/PARTIAL). The "ceremonial witness" beat per `design/gdd/destiny-branch.md` Player Fantasy is fundamentally about the **moment** the player registers history bending — that registration is observable on the prototype surface (1.5s dwell + reserved-color reveal + audio hum) regardless of which scene tree the moment lives in. The art-director PHASE-GATE verdict at 2026-05-08-rerun confirmed: "the synthesized 묵 hum is an acceptable demo placeholder for Pre-Prod → Production gate. The art bible §4.7 already flags 'Audio Director 협업' as a pre-implementation collaboration item that is not a sprint-7+ blocker — explicitly deferred."

4. **4-pattern-stable CONCERNS resolution requires unblocking the gate without forcing a multi-sprint scenario-runner production sprint.** The Pre-Prod → Production gate-check has held at CONCERNS across 4 consecutive invocations (2026-05-05 / 05-06 / 05-08-AM / 05-08-PM-rerun) with the same 3× READY + 1× CONCERNS-CD shape. Forcing game-facing promotion as the gate-closure path would mean dedicating sprint-13 + likely sprint-14 to scenario-runner production code authoring before any Production-stage feature work begins — a strategic choice not currently aligned with sprint-13 priority signals (live-ops + main menu UI epic + gate-check-residual closure) per active.md Recommended Next Session Option D handoff. Accepting prototype-side as gate-sufficient unblocks Production stage flip without precommitting sprint-13 scope.

## What is NOT being decided here

This decision does NOT:

- Cancel the production scenario-runner integration of the atmospheric layer. The Audio Director collaboration item per art bible §4.7 + AD-PHASE-GATE 2026-05-08-rerun ADVISORY-3 (NEW from S12-02: "Production audio port — synthesized 묵 hum placeholder must be replaced by commissioned asset at audio-pass sprint") + scenario-runner production code authoring all remain open commitments tracked under their respective triggers.
- Reduce the Pillar 4 (삼국지의 숨결) experiential bar. The "ceremonial witness" beat MUST land in production with commissioned audio + game-facing scene integration before Polish-stage gate-check passes. Prototype-as-gate-sufficient is for Pre-Prod-to-Prod ONLY.
- Affect the chapter-prototype's throwaway-status. Per `.claude/rules/prototype-code.md` §"When a Prototype Succeeds": prototype code is NOT migrated; production scenario runner reauthors per GDD when the implementation sprint arrives. The prototype directory remains preserved for reference but never extended.
- Override the AD ADVISORY-3 audio-port flag. Synthesized cue replacement at the audio-pass sprint is a separate binding obligation tracked at the Polish gate.
- Affect the gate-check verdict at THIS rerun. The 2026-05-08-rerun verdict remains CONCERNS — this decision closes ONE of 4 path-to-PASS items (3a). Items 1 + 2 + 3b remain open.

## Reactivation Triggers

This decision **automatically re-opens** when any one of the following becomes true:

### Trigger 1 — `src/scenario/` directory becomes non-empty

When production scenario runner code exists in the canonical location (i.e., the empty `src/` Pillar 4 surface gap is filled), this decision must be re-evaluated. The prototype-as-gate-sufficient acceptance is bound to the ABSENCE of production scenario runner code; once that absence is filled, the decision's load-bearing reason 1 (no production surface to promote to) no longer holds.

**Signal**: `src/scenario/` directory contains at least one `.gd` file with non-empty content (i.e., `find src/scenario -name "*.gd" -size +1c | head -1` returns a non-empty result).

**Required action when fired**: producer opens new sprint task "Re-evaluate prototype-as-gate-sufficient decision post-`src/scenario/` authoring — promote atmospheric layer to game-facing OR document continued prototype-acceptance"; this decision doc is referenced and amended per §3.9.

### Trigger 2 — Polish-stage gate-check (`/gate-check production-to-polish`) approaches

The Polish-stage gate-check defines a stricter experiential bar than Pre-Prod-to-Prod. Per existing gate definitions (`.claude/skills/gate-check/SKILL.md` §"Production → Polish"), the Polish gate requires "all implemented screens have corresponding UX specs" + "No 'confusion loops' identified." A prototype-side atmospheric demonstration cannot satisfy the Polish gate's player-facing-validation requirements; the production-side promotion MUST happen before Polish gate passes.

**Signal**: `/gate-check production-to-polish` is invoked OR `production/stage.txt` content equals `Polish`.

**Required action when fired**: this decision is automatically marked "RESOLVED at Polish gate" in the amendment log; if production-side promotion has NOT yet shipped, the Polish gate-check returns FAIL on this item (not CONCERNS — Polish-stage cannot accept prototype-side demonstration).

### Trigger 3 — AD ADVISORY-3 audio-port commission story enters a sprint

When a sprint plan adds a story whose scope includes commissioning the production 묵 hum audio asset (replacing the synthesized 220Hz + 330Hz placeholder), this decision is re-opened to track the simultaneous game-facing scene integration of the asset. Audio commission without scene integration is a partial-state risk.

**Signal**: any story file in `production/epics/` includes acceptance criteria referencing the literal substring `묵 hum` OR `atmospheric audio commission` OR `replaces synthesized 220Hz`.

**Required action when fired**: producer pairs the audio-commission story with a game-facing scene integration story in the same sprint OR documents why they should ship across separate sprints (with explicit hand-off plan).

### Trigger 4 — Any playtest report flags the prototype-isolation as confusing or off-pitch

When playtest data — captured via `/playtest-report` or recorded in `production/playtests/` — explicitly notes that the atmospheric moment surface (chapter-prototype) does not deliver the Pillar 4 experiential payload, this decision is re-opened.

**Signal**: any file under `production/playtests/` contains the literal substring `prototype` AND `Pillar 4` in the same paragraph, with negative framing (e.g., "did not feel ceremonial," "missed the atmospheric moment," "synthetic audio felt placeholder").

**Required action when fired**: producer immediately escalates to creative-director for binding re-rating; this decision is amended with the playtest reference + may be superseded if the re-rating verdict is "force game-facing now."

## Dependency on User Actions

None. This decision is fully claude-side and does NOT require user attestation, user-paid prerequisites, or user-only credentials. Its closure is a process commitment captured in this artifact + cross-referenced from the gate-check rerun report.

The reactivation triggers above include user-action conditions (e.g., a playtest report authored by user observation) but those are reactivation-time obligations, not closure-time prerequisites.

## Cost-Benefit Summary

| Factor | Force game-facing scenario-runner integration now | Accept prototype-as-gate-sufficient (decided outcome) |
|---|---|---|
| Sprint budget impact | 1.5-3 sprints (sprint-13 + likely sprint-14 dedicated to scenario-runner production code authoring + atmospheric layer integration) | 0d additional (S12-02 already shipped; this decision is doc-only at ~0.05d) |
| Verification value pre-VS | Marginal: production scenario-runner code without VS playtest cannot validate "does it feel ceremonial?" | Same: prototype-side demo can be playtested once user attests S12-10 (4 VS Validation items); experiential bar is satisfied at the player-experience layer regardless of surface |
| Verification value post-VS | High once production scenario-runner exists: VS players directly experience the atmospheric moment in the game-flow context | Identical at the experiential level (Pillar 4 pattern works); production-port quality bound to Polish-stage gate (see Trigger 2) |
| Risk to current baseline | High: scenario-runner production code authoring touches multiple systems (scene rendering + chapter-state-machine integration + battle-hud cross-binding); 1273/1273 PASS baseline at risk during the integration sprint | Zero: 1273/1273 PASS baseline preserved (already established at S12-02 close); this decision adds doc only |
| User-action prerequisite | Possibly: production scenario-runner UI tuning may need user playtest input mid-sprint | None: this decision closes immediately upon /story-done at S12-03 close-rerun |
| Pattern alignment | Production-stage scenario-runner authoring is post-Pre-Prod work; forcing it pre-Pre-Prod inverts the stage progression | Aligned: gate-check accepts evidence at the experiential validation level; surface-vs-substrate distinction codified in `.claude/rules/prototype-code.md` ratifies this acceptance |

The combination of (1) zero current-sprint cost + (2) pattern-alignment with prototype-isolation contract + (3) experiential validation preserved + (4) production-port bound by explicit Polish-gate trigger (Trigger 2) makes the binding outcome **accept-as-gate-sufficient**, not force-game-facing-now.

## Why this satisfies the prior AI / retro mandate

The originating mandate is gate-check 2026-05-08-rerun §6 Item 3a:

> **Item 3a NEW**: Pillar 4 atmospheric moment promoted to game-facing chapter runtime OR explicit ADR accepting prototype as gate-sufficient. S12-02 demonstrated atmospheric layer in prototype sandbox; CD requires player-facing surface OR ADR exception.

Per `docs/process/decisions-convention.md` §1, this decision is **not** an architectural choice (it does not commit to API shape, system boundary, or engine surface) — it is a SCOPE decision about gate semantics ("what counts as gate-sufficient evidence for Pillar 4 experiential validation pre-Pre-Prod-to-Prod"). The convention explicitly directs SCOPE decisions to `production/decisions/` rather than `docs/architecture/ADR-NNNN-*.md`. This file fulfills the OR branch of Item 3a's binary: "process-decision per Route c" rather than ADR.

The CD-side concern raised at gate-check rerun ("the surface is `prototypes/chapter-prototype/`, an explicitly throwaway sandbox, not the game-facing chapter runtime") is acknowledged in §"Why accept-as-gate-sufficient" reason 3 + addressed via Trigger 2 (Polish-stage gate FAIL if production-side promotion has not shipped by then). The decision does not dismiss CD's concern; it bounds it to the next gate.

## Cross-references

- **Gate-check rerun (originating)**: `production/gate-checks/pre-prod-to-prod-2026-05-08-rerun.md` §6 Item 3a + §10 Action Summary
- **S12-02 ship chain**: commits `f6b14e6` (`/quick-design`) → `e5689d3` (`/create-stories`) → `f577345` (`/story-readiness`) → `aa55969` (`/dev-story`) → `17d3f84` (`/story-done` + epic-terminal)
- **Quick-spec (design source)**: `design/quick-specs/chapter-prototype-pillar-4-atmospheric-moment-2026-05-08.md`
- **Story file**: `production/epics/chapter-prototype-demo/story-001-pillar-4-atmospheric-moment.md`
- **Implementation**: `prototypes/chapter-prototype/chapter.gd` (+126 LoC) + `tests/integration/chapter_prototype/atmospheric_moment_test.gd` (445 LoC; 7 functions)
- **Pillar 4 GDD references**: `design/gdd/scenario-progression.md` §V.3 Reserved Color Protocol + AC-SP-7 + AC-SP-9; `design/gdd/destiny-branch.md` Player Fantasy + Overview ("ceremonial witness" 30-sec moment)
- **Art bible reference**: `design/art/art-bible.md` §4.7 Reserved Colors + sound-companion deferral
- **Prototype-isolation contract**: `.claude/rules/prototype-code.md` (especially §"What's Still Required" + §"When a Prototype Succeeds")
- **Decisions convention**: `docs/process/decisions-convention.md` (ratifies Route c for SCOPE decisions)
- **Reactivation Trigger 2 monitoring**: `production/stage.txt` (when content flips to `Polish`)
- **Reactivation Trigger 1 monitoring**: `src/scenario/` directory non-empty check
- **Sprint plan**: `production/sprints/sprint-12.md` S12-03 row
- **Companion decision (Item 3b)**: `production/decisions/pillar-3-deferral-decision-2026-05-08.md`

## Amendment log

*Append future amendments below — do not rewrite the body above.*

- 2026-05-08 — Initial binding decision recorded (sprint-12 S12-03 close-rerun close-out; closes gate-check 2026-05-08-rerun path-to-PASS item 3a).
