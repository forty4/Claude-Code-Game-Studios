# Gate Check — Pre-Production → Production (2026-05-05)

| Field | Value |
|---|---|
| **Verdict** | **CONCERNS** (upgraded from 4× CONCERNS at 2026-05-04 baseline) |
| **Mode** | Lean (per `production/review-mode.txt`) |
| **Checked by** | `/gate-check pre-production` skill |
| **Date** | 2026-05-05 |
| **Prior baseline** | `production/gate-checks/pre-prod-to-prod-2026-05-04.md` (CONCERNS) |
| **Sole remaining gating blocker** | **S7-11 user attestation** on 4 VS Validation items in `prototypes/chapter-prototype/REPORT.md` (USER-OWNED) |

---

## 1. Verdict Trajectory

| Date | Verdict | Director Panel | Note |
|---|---|---|---|
| 2026-04-20 | FAIL | (pre-lean baseline) | 7/17 artifacts present |
| 2026-05-04 | CONCERNS | 4× CONCERNS | 13/17 artifacts; 6-step path-to-PASS surfaced |
| **2026-05-05** | **CONCERNS** | **3× READY + 1× CONCERNS (CD)** | **15/17 artifacts; sole gate = S7-11 user attestation** |

**Trajectory**: 4 director panels with concerns → 1 CD CONCERNS only. All claude-owned path-to-PASS items closed. Gap is now **experiential validation only** (4 VS Validation items requiring human playtest evidence per refusal-to-fabricate posture).

---

## 2. Required Artifacts: 15/17 Present

| Artifact | Status | Note |
|---|---|---|
| ≥1 prototype with README | ✅ | `chapter-prototype/` + `vertical-slice/` |
| First sprint plan | ✅ | `sprint-1.md` ... `sprint-7.md` (7 sprints) |
| Art bible 9 sections | ✅ | 1196 lines; AD-ART-BIBLE Sign-Off "Skipped — Lean mode" (acceptable) |
| Character visual profiles | ❌ | `design/art/characters/` missing — AD ADVISORY (carryover) |
| All MVP-tier GDDs | ✅ | 19 GDDs in `design/gdd/`; story-event + destiny-state newly Designed; Save/Load #17 cut to sprint-8 |
| Master architecture doc | ✅ | `architecture.md` exists |
| ≥3 Foundation ADRs | ✅ | 19 ADRs total |
| Control manifest | ✅ | 634 lines (refreshed 2026-05-05; ADRs 0005..0013 + 0019 backfilled) |
| Epics: Foundation + Core | ✅ | 20 epics + index |
| Vertical Slice playable | ⚠️ | `chapter-prototype/` mechanically playable; full chapter-1 integration pending S7-10 unblock |
| ≥3 playtest sessions | ❌ | `production/playtests/` empty — S7-11 USER-OWNED |
| VS playtest report | ⚠️ | `chapter-prototype/REPORT.md` PROVISIONAL PROCEED (mechanical-only; 4 VS items unattested) |
| UX spec: main menu | ❌ | `design/ux/main-menu.md` missing — AD ADVISORY (carryover) |
| UX spec: HUD | ✅ | `design/ux/battle-hud.md` v1.1 |
| UX spec: pause menu | ❌ | `design/ux/pause-menu.md` missing — AD ADVISORY (carryover) |
| Interaction patterns | ✅ | `design/ux/interaction-patterns.md` |
| Accessibility requirements | ✅ | `design/ux/accessibility-requirements.md` (Tier: Intermediate; committed 2026-04-18) |

---

## 3. Quality Checks

### Test Baseline
- **978/978 PASSING** (108 suites; 0 errors / 0 failures / 0 orphans)
- 26th+ consecutive failure-free baseline
- Cumulative growth: 953 (post-S7-04) → 959 (post-S7-05) → 963 (post-S7-07 G-7 unblock) → 963 (S7-06 design-only) → 978 (post-S7-09 +15)

### Sprint-7 Closure (9/11 done; 1 BLOCKED; 1 USER-OWNED)
- **Must-have (4/4)**: S7-01..S7-04 all closed
- **Should-have (3/3)**: S7-05 + S7-06 + S7-07 all closed
- **Nice-to-have (2/4)**:
  - S7-08 control-manifest backfill ✅ closed
  - S7-09 battle-hud story-004 ✅ closed
  - **S7-10 BLOCKED** on input-handling epic — InputRouter is 33-line PLACEHOLDER without `_handle_event` method; full FSM is input-handling 10-story scope (sprint-8+)
  - **S7-11 USER-OWNED** — 4 VS Validation items in `prototypes/chapter-prototype/REPORT.md` require human playtest attestation (refusal-to-fabricate posture per `tooling-gotchas.md` TG-2 + damage-calc 2026-04-27 recursive-fabrication-trap precedent)

### 4 VS Validation Items (still MANUAL CHECK NEEDED)
1. ❌ Human played through core loop without dev guidance — no captured evidence
2. ❌ Game communicates what to do within first 2 minutes — no captured evidence
3. ❌ No critical "fun blocker" bugs in Vertical Slice — no captured evidence
4. ❌ Core mechanic feels good — no captured evidence

> **Note**: These are unverified, not failed. Treated as MANUAL CHECK NEEDED per 2026-05-04 precedent (CONCERNS, not auto-FAIL). Closure requires user to run prototype 3-5 times + append `## Playtest Notes` section to REPORT.md.

---

## 4. Director Panel Assessment (Lean Mode — All 4 Spawned in Parallel)

### Creative Director — **CONCERNS**
- **Pillar 1 (형세의 전술)**: SUBSTRATE STABLE — grid-battle + chokepoints schema landed; AI archetypes apply terrain pressure; Initiative Queue makes 형세 legible. Provable.
- **Pillar 2 (운명은 바꿀 수 있다)**: SUBSTRATE STABLE — destiny-branch + destiny-state + story-event + scenario-runner all Designed; F-DB-1 + 12-vocab + is_canonical_history payload; Pillar 2 architectural lock pattern firmly stable at 4 invocations + 2 candidates. **Strongest pillar**.
- **Pillar 3 (모든 무장에게 자리가 있다)**: SUBSTRATE PARTIAL — AISystem 4 archetypes shipped, but "every general has a seat" is a roster-design promise unproven without playtest evidence on roster-feel.
- **Pillar 4 (지난 장의 선택이 살아 있다)**: SUBSTRATE LANDED, NOT YET DEMONSTRATED — story-event branch-aware text codified; cross-chapter ripple unprovable until chapter-2+ exists.
- **Blockers**: S7-11 attestation gap (CONCERN, not BLOCKER) + Pillar 4 chapter-2 demonstration unprovable pre-Production (ADVISORY).
- **Recommendation**: Production may proceed. Sprint-8 must include S7-11 closure + input-handling epic + chapter-2 scoping.

### Technical Director — **READY**
- **Foundation 5/5 + Core 5/5 + Feature 4/4 ADRs Accepted**.
- 978/978 + 26-baseline streak demonstrates Foundation/Core integration health.
- **Concerns (non-blocking)**:
  1. Input-handling epic (S7-10 InputRouter PLACEHOLDER) — Production-phase work; recommend ADR before implementation.
  2. S7-11 user attestation — USER-OWNED; does not gate TD verdict.
  3. ADR Engine Compatibility/Dependencies — ADVISORY; consider hardening pass to add explicit Depends-on/Depended-by headers.
- **Validation criteria**: Sprint-8 opens with InputRouter ADR; no Foundation/Core ADR retroactively amended in first 2 Production sprints; 1000+ test baseline maintained.

### Producer — **READY (with one ADVISORY)**
- **Sprint-7 closure**: 9/11 (Must 4/4 + Should 3/3 + Nice 2/4); BLOCKED + USER-OWNED carryover; 26-baseline streak; velocity 5-6× nominal sustained.
- **Hygiene**: Retro AI #1 ("close in same patch") violated S7-01..S7-04, enforced S7-05+ (4-story streak; not yet stable at 6+).
- **Sprint-8 recommendation**: **DO NOT absorb full 10-story input-handling epic.** Split:
  - Sprint-8 must-haves: input-handling stories 1-5 + S7-10 unblock + Save/Load #17 GDD + Story Event #10 impl + Destiny State #16 impl + chapter-1 integration target
  - Defer to sprint-9: input-handling 6-10 + polish + S7-11 re-verification post-input-handling
- **Cross-director convergent blockers vs 2026-05-04**: None new.

### Art Director — **READY**
- **Visual Identity Foundation**: Art bible solid (9/9 sections; §4.7 reserved_color_treatment addendum landed); color system enforced at 3 layers; character direction sufficient for first-character production; UI/HUD spec ↔ S7-09 implementation aligned (no drift).
- **Carryover (acceptable)**:
  - AD-C5 ADVISORY: character visual profile stubs — author for first 2-3 characters before sprint-8 art tasks
  - AD-C6 ADVISORY: main-menu + pause-menu UX specs — author before menu implementation sprint
  - AD-C2 OPEN: 청록/적색 contrast — resolve before accessibility gate
  - AD-C3 OPEN: 緣 glyph font-set check — resolve before story-event text rendering
- **Sprint-8 art priority**: (1) first character profile stub → portrait spec, (2) AD-C3 font check → story-event rendering, (3) AD-C2 contrast pass, (4) main-menu UX stub.

### Aggregate
| Director | Verdict | Blockers |
|---|---|---|
| Creative | CONCERNS | Pillar 3+4 demonstration unproven (CONCERN); S7-11 attestation gap (CONCERN) |
| Technical | READY | None |
| Producer | READY | None (ADVISORY: split input-handling epic) |
| Art | READY | None |

**Per skill text**: "Any director returns CONCERNS → verdict is minimum CONCERNS." → **CONCERNS**.

---

## 5. Path to PASS (Single Item)

**SOLE remaining blocker** for CONCERNS → PASS upgrade:

### S7-11: User attestation on 4 VS Validation items
- **Owner**: USER (not claude-fabricable per refusal-to-fabricate posture)
- **Action**: Run `prototypes/chapter-prototype/` 3-5 times + append `## Playtest Notes` section to `REPORT.md` with concrete observations on:
  1. Did you play through the core loop without prompts/guidance? Yes/No
  2. Did the game communicate what to do within first 2 minutes? Yes/No
  3. Were there fun-blocker bugs? List or "none observed"
  4. Did the core mechanic (formation + role + hidden-fate-discovery) feel good? Yes/No + 1-line reason
- **Bar**: "Honest notes, not perfection. Even 'ran 3 times, hit HISTORICAL twice and PARTIAL once, never figured out the rear-attack lever, would try again' is data."
- **After completion**: Re-run `/gate-check pre-production` for upgrade CONCERNS → PASS.

---

## 6. Alternative Path: Accept Production at CONCERNS

**If user prefers immediate phase flip without S7-11 attestation**:
- Write `production/stage.txt` = `Production` manually
- Document acceptance-with-conditions in `active.md` and the next sprint plan retro AI seed
- Carry S7-11 attestation as **Production sprint-8 must-have** (not pre-stage gate)
- Re-validate Pillar 1+3+4 fantasy delivery via first 2 Production-sprint playtests (Producer + CD recommendation)

**Tradeoff**: Faster phase progression at the cost of unverified core fantasy. Per CD: "Production can begin with explicit acknowledgment that Pillars 3+4 await play-validation in the first two Production sprints."

**Per refusal-to-fabricate posture**: Recommended to wait on S7-11 user evidence rather than flip stage prematurely. But the choice is yours.

---

## 7. Carryover into Sprint-8 (Production Phase Start)

| Item | Source | Owner | Sprint-8 priority |
|---|---|---|---|
| S7-10 battle-hud story-005 (UI-GB-02/05/10 + two-tap timer) | Sprint-7 BLOCKED | claude | After input-handling 1-5 |
| S7-11 user attestation (4 VS items) | Sprint-7 USER-OWNED | user | Anytime |
| Save/Load #17 GDD authoring | Sprint-7 CUT | claude | Should-have (design-only filler) |
| Input-handling epic stories 1-5 | New | claude | Must-have (unblocks S7-10 + UI-GB-09) |
| InputRouter ADR | New (TD recommendation) | claude | Must-have (gate before implementation) |
| Story Event #10 implementation | S7-06 GDD newly Designed | claude | Should-have |
| Destiny State #16 implementation | S7-07 GDD newly Designed | claude | Should-have |
| ADR-0001 minor amendments (3 new GameBus signals from Story Event + 1+ from Destiny State) | Newly required | claude | Bundled with implementations |
| Chapter-1 (장판파) end-to-end integration run | S7-05 data shipped | claude | Should-have (vertical-slice validation target) |
| Character profile stubs (first 2-3 characters) | AD-C5 carryover | art | Should-have |
| AD-C3 font glyph check | AD-C3 carryover | art | Should-have (gates story-event text rendering) |
| Main-menu + pause-menu UX specs | AD-C6 carryover | ux | Nice-to-have |
| Pillar 4 chapter-2 scoping with chapter-1-callback ACs | CD recommendation | design | Nice-to-have (sprint-9+ start) |

---

## 8. Chain-of-Verification

5 challenge questions checked against the CONCERNS draft:

1. **Could any CONCERN be elevated to a blocker?** → No. CD-flagged Pillar 3+4 demonstration is explicitly Production-phase activity per all 4 directors. S7-11 is USER-OWNED; refusal-to-fabricate posture means MANUAL CHECK NEEDED is correctly classified, not soft-FAIL.
2. **Is the concern resolvable in next phase?** → Yes. S7-11 closeable in 1 user session; Pillar 3 roster-feel + Pillar 4 chapter-2 are explicitly Production-sprint work; input-handling addressable in sprint-8 first half.
3. **Did I soften any FAIL into CONCERN?** → No. 4 VS Validation items are unverified-not-failed; treating as MANUAL CHECK NEEDED preserves the 2026-05-04 precedent. Strict skill-text reading would auto-FAIL but operational convention has been CONCERNS.
4. **Are there artifacts I didn't check that could reveal blockers?** → Spot-check risk only. TD spot-checked ADR Engine Compatibility consistency; test baseline cited from recent commit message rather than re-run; not all 9 art-bible sections content-validated. Risk LOW given multiple cross-director confirmations align.
5. **Do all CONCERNS together create a blocking problem?** → No. S7-11 + Pillar 3+4 demonstration + input-handling + Save/Load are separable work streams, not interlocking.

**Chain-of-Verification: 5 questions checked — verdict unchanged (CONCERNS).**

---

## 9. Files Produced

- This report: `production/gate-checks/pre-prod-to-prod-2026-05-05.md`

## 10. Cross-References

- Prior gate check: `production/gate-checks/pre-prod-to-prod-2026-05-04.md`
- Sprint-7 plan: `production/sprints/sprint-7.md`
- Sprint-status: `production/sprint-status.yaml` (sprint 7; updated 2026-05-05)
- User attestation gate: `prototypes/chapter-prototype/REPORT.md` §Open Questions Requiring User Attestation
- Pillar 2 architectural locks: `docs/architecture/control-manifest.md` §Pillar 2 Architectural Locks (4 shipped + 2 candidates)
- Refusal-to-fabricate posture: `.claude/rules/tooling-gotchas.md` TG-2 + damage-calc 2026-04-27 precedent
