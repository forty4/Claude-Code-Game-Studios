# Chapter Prototype — Findings Report

> **PROTOTYPE — NOT FOR PRODUCTION.** Throwaway code per `.claude/rules/prototype-code.md`.
> Prototype authored: 2026-05-02 (chapter.gd 19KB / battle_v2.gd 27KB / 470 LoC sum).
> Report authored: 2026-05-04 (retroactive; written to close `/gate-check pre-production` path-to-PASS item #2).

**Hypothesis under test** (`design/gdd/game-concept.md:296`):

> *"진형 기반 턴제 전투에서 숨겨진 운명 분기 조건을 발견하는 경험이 회차 플레이를 유발할 만큼 재미있는가?"*
> ("Is the experience of discovering hidden destiny-branch conditions in formation-based turn-based combat fun enough to drive replay?")

---

## Verdict: **PROCEED — provisional**

Mechanically the prototype implements every lever the MVP Core Hypothesis depends on (formation multipliers, hidden fate thresholds, role-asymmetric heroes, story-framed loop). The four pillars all have code-level substrate that can produce the intended dynamics. **The verdict is PROCEED on mechanical grounds.**

The verdict is **provisional**, not confirmed, because the subjective half of the hypothesis — "fun enough to drive replay" — cannot be answered from code inspection. It requires human playtest evidence which has **not been captured** for this prototype. See "Open Questions Requiring User Attestation" below.

This report is honest about that boundary on purpose. The damage-calc story-006 close-out (2026-04-27) and `.claude/rules/tooling-gotchas.md` TG-2 surfaced a "recursive fabrication trap" pattern in this project; this report explicitly refuses to manufacture UX findings the prototype has not actually produced.

---

## Scope of This Report

| Covered | Not Covered |
|---|---|
| Code-verifiable mechanical claims (formulas wire up; branches are reachable; thresholds match GDD intent) | "Did the discovery moment feel satisfying" |
| Pillar substrate audit (does the code support each pillar in principle) | "Did role swaps feel meaningfully different" |
| Threshold-tuning sanity check vs. game-concept Risk #1 ("운명 분기 조건이 완전 숨김일 때 플레이어가 좌절") | "Did the 5-turn limit force tactical decisions or feel arbitrary" |
| Coverage gap surfacing for Production-phase work | Multi-run replay loop validation |

---

## Findings By Pillar

### Pillar 1 — 형세의 전술 (Tactics of Formation): **substrate present**

**Code evidence** (`battle_v2.gd`):
- 7×7 grid with mixed terrain (plains / forest / hills / river-bisected-by-bridge); river is impassable, forcing the bridge as a chokepoint.
- Damage formula stacks four positional multipliers: `formation_mult` (+5%/adjacent ally, cap +20%), `angle_mult` (front 1.0× / side 1.25× / rear 1.50× or 1.75× for 황충), `aura_mult` (+15% if 유비 adjacent), terrain `def_bonus` subtracted from raw ATK-DEF.
- README's worked example (1.20 × 1.75 × 1.15 ≈ 2.41× rear-flank with full formation) is correct against the code.
- 5-turn `MAX_TURNS` cap forces tactical commitment over attrition (matches Pillar 1 design test "진형 시스템을 깊게 한다").

**What's verified**: positioning math actually rewards positioning; lone front attack vs. perfectly-positioned rear-flank produces the ~5× damage spread the GDD calls for.

**What's NOT verified**: whether the spread is *legible* to the player without explicit damage previews (no forecast UI in this prototype), and whether players actually use the lever instead of brute-forcing.

### Pillar 2 — 운명은 바꿀 수 있다 (Destiny Can Be Rewritten): **substrate present, threshold-tuning unproven**

**Code evidence** (`chapter.gd:34-37`):

| Condition | Threshold | Source field |
|---|---|---|
| 장비 alive at ≥60% HP | 0.60 | `_fate_threshold_tank_hp` |
| 조운 killed ≥2 enemies | 2 | `_fate_assassin_kills` |
| ≥2 rear attacks landed | 2 | `_fate_rear_attacks` |
| ≥3 turns formation-active | 3 | `_fate_formation_turns` |

`_judge_fate()` resolves 4-condition tally → REWRITTEN (all 4) / PARTIAL (1-3) / HISTORICAL (0) / DEFEAT (player wiped). All 4 branches have distinct result text and are reachable.

**What's verified**: hidden-condition silent tracking works; the result-text panel displays the *final values* (e.g. "rear attacks: 1") without naming the threshold. This is the exact "discovery from data" pattern the GDD requires (Pillar 2 design test "어렵지만 가능하게 한다").

**What's NOT verified — and is the highest-stakes open question**:
- Are the 4 thresholds tuned at the right difficulty? `game-concept.md:269` flags this as HIGH design risk: "운명 분기 조건이 완전 숨김일 때 플레이어가 좌절하고 포기할 수 있음". The prototype answers this only if humans have actually attempted multiple runs.
- Is REWRITTEN actually achievable by a skilled player within the 5-turn limit? Mechanically yes; subjectively unconfirmed.
- Does the stats panel give *enough* information to reason about which lever to pull on retry? A list of 4 unlabeled numbers may or may not telegraph the conditions.

**The code is ready to test the pillar; the playtest data to validate the tuning has not been captured.**

### Pillar 3 — 모든 무장에게 자리가 있다 (Every Hero Has a Role): **substrate present, asymmetry coded**

**Code evidence** (`battle_v2.gd:52-72`):

| Hero | Stats signature | Role differentiator |
|---|---|---|
| 장비 | DEF 25 / HP 120 / MOV 2 / range 1 | Tank — `bridge_blocker` declared |
| 조운 | ATK 35 / DEF 14 / MOV 5 / range 1 | Assassin — high MOV exploits gaps |
| 황충 | ATK 28 / range 2 / `rear_specialist` ×1.75 | Archer — rear positioning premium |
| 유비 | ATK 18 / `command_aura` +15% adjacent | Commander — formation enabler |

The party-select forces 장비 + 조운 (story-locked) and asks the player to pick *2 of {유비, 황충}* for the remaining slots. This is a real tactical choice: 황충's rear-specialist (×1.75) vs. 유비's command_aura (+15% to all adjacent), with neither dominating mathematically.

**What's verified**: stat asymmetry produces distinct strategic identities; the 4 hidden conditions structurally reward different heroes (tank survival → 장비; rear attacks → 황충; assassin kills → 조운; formation turns → 유비), so the optimal team CANNOT be "stack the strongest two".

**What's NOT verified**:
- Does AI behavior actually pressure the role asymmetry? Code review of enemy AI was out of scope of this report; the README does not commit to AI sophistication. **MVP requirement #6 ("AI가 기본적 진형 전술을 사용") is not yet demonstrably satisfied** — this is the strongest mechanical gap in the prototype.
- Per-hero passives `bridge_blocker`, `hit_and_run` are *declared* in HERO_POOL but only `command_aura`, `rear_specialist`, and the `rear_specialist` ×1.75 multiplier appear to be actively wired into the damage formula. Other passives may be flavor-only at this stage. (Confirmation requires deeper code-pass; not done in this report.)

### Pillar 4 — 삼국지의 숨결 (The Spirit of Three Kingdoms): **substrate present**

**Code evidence**:
- `STORY_DIALOG` 5-step intro frames the historical context (조조 50만 / 유비 후퇴 / 미부인 우물 default tragedy).
- 4 result texts (`RESULT_HISTORICAL` / `RESULT_REWRITTEN` / `RESULT_PARTIAL` / `RESULT_DEFEAT`) each provide narrative consequences referencing 적벽 / 형주 / 익주 — the chosen branch is *meant* to ripple forward.
- Story-locked party constraints (관우 양양 출정 → unselectable) reinforce historical authenticity.

**What's verified**: every battle outcome is wrapped in story text; every party choice has historical justification.

**What's NOT verified**: whether the framing is felt as story-integration or skipped as boilerplate. The prototype does not branch the dialog content based on *which* branch was achieved across replays; replays land back at the same story intro.

**Sprint-12 S12-02 update (2026-05-08) — atmospheric demonstration shipped on REWRITTEN branch:**
The REWRITTEN branch now demonstrates an atmospheric moment in-prototype: reserved colors 주홍 `#C0392B` and 금색 `#D4A017` are applied per Art Bible; a synthesized 묵 hum audio cue (220 Hz fundamental + 330 Hz harmonic, 1.2 s) plays on branch resolution; a 1.5 s dwell lockout prevents UI interaction during the moment per AC-SP-9. Integration coverage: `tests/integration/chapter_prototype/atmospheric_moment_test.gd` — 7 test functions covering all 7 ACs (color application, audio generation, dwell lockout, result-screen integration, skip-on-non-REWRITTEN, silence after dwell, and end-of-test cleanup). Test suite: 1266 baseline → 1273 total, 1273/1273 PASS.
**Pillar 4 verdict upgraded: substrate present + atmospheric demonstration shipped.** The code now proves not only that narrative text wraps outcomes, but that a sensory/atmospheric layer (color + audio + pacing) can be wired to the fate result with no engine-level obstacles. Subjective quality — whether the 묵 hum and color shift *feel* evocative rather than mechanical — remains a playtest question.

---

## MVP Core Hypothesis Assessment

The MVP Core Hypothesis decomposes into two clauses:

| Clause | Mechanical answer | Subjective answer |
|---|---|---|
| (A) "진형 기반 턴제 전투에서 숨겨진 운명 분기 조건을 발견하는 경험" — does the discovery experience exist as a first-class loop? | **YES** — code implements it end-to-end (story → party → battle → fate result → retry). | Requires playtest. |
| (B) "회차 플레이를 유발할 만큼 재미있는가" — is it fun enough to drive replay? | Cannot be answered mechanically. | Requires playtest. |

**Conclusion**: Clause (A) is satisfied at the code level. Clause (B) is *unanswered*.

**Recommended posture**: PROCEED to Production on the strength of (A) being satisfied — the prototype proves the loop is buildable and architecturally coherent. Treat (B) as the canonical first playtest target once Production builds reach a comparable feature surface; if the answer is "no" at that point, PIVOT options (looser thresholds, partial-condition hints, branch-aware story text) are all mechanical adjustments the architecture supports.

---

## Open Questions Requiring User Attestation

The 2026-05-04 `/gate-check pre-production` flagged 4 Vertical Slice Validation items as MANUAL CHECK NEEDED. This prototype is exactly the artifact those items were supposed to attest from. **Until the user (or another human playtester) actually plays multiple runs, the following remain unverified**:

1. **Did a human play through the core loop without dev guidance?** No captured evidence.
2. **Did the game communicate what to do within the first 2 minutes?** No captured evidence.
3. **Were there fun-blocker bugs?** No captured evidence.
4. **Did the core mechanic feel good?** No captured evidence.

**Recommended action for the user**: run the prototype 3-5 times (per the README's "How to evaluate" §) and append a `## Playtest Notes` section to this REPORT with concrete observations. That converts this provisional PROCEED into a confirmed verdict, and converts the 4 Validation items from "unverified" to "PASS" at the next `/gate-check pre-production` invocation.

The bar is honest notes, not perfection. Even "ran 3 times, hit HISTORICAL twice and PARTIAL once, never figured out the rear-attack lever, would try again" is data — and would point at a real tuning concern to carry into Story Event #10 / Destiny State #16 GDDs.

---

## Coverage Gaps Surfaced for Production

Beyond the playtest gap, this prototype-level audit surfaces three Production-phase work items:

1. **AI sophistication gap** — Pillar 3 cannot be conclusively proven without enemy AI that *uses* role asymmetry to apply pressure. Gate-check 2026-05-04 already flagged "AI System (#8 MVP) — no GDD, no ADR, no epic" as a cross-director convergent blocker; this prototype review reinforces it. See `/gate-check` path-to-PASS item #4.
2. **Discovery-from-data legibility** — the stats panel currently shows raw end-of-battle numbers without UI affordances. Production should explore: is a single retry's data enough? Does Pillar 2's "어렵지만 가능" tilt too far into "frustrating" without slight scaffolding (e.g., revealing thresholds AFTER first achievement)? This belongs in Story Event #10 + Destiny State #16 GDDs (currently PROVISIONAL per `design/gdd/systems-index.md`).
3. **Branch-aware narrative continuity** — REWRITTEN result text mentions ripple effects to 적벽 / 형주 / 익주 but the prototype loops back to the same intro on retry. Production must commit to whether changed history actually changes future chapter intros (Pillar 4's strongest claim) or whether ripple-narrative is constrained to result text only. Save/Load #17 GDD scope decision.

---

## What This Prototype Does NOT Test (intentional, per README)

Per `prototypes/chapter-prototype/README.md` §"What's intentionally still missing":
- No real sprites (placeholder ColorRect + Label)
- No sound, no camera controls, no animations beyond simple tween
- Multiple chapters (only 장판파)
- Save/load, real autoload integration (no GameBus), HeroDatabase JSON loading
- Status effects from hp-status epic (defend_stance / poison)
- Pathfinding (Manhattan distance only)
- Multi-finger touch (mouse only)

Production must rebuild from scratch per the prototype-code rule: "If a prototype validates a concept and the feature moves to production: the prototype code is NOT migrated directly — it is rewritten to production standards. The prototype README findings inform the production design document."

---

## Cross-References

- `design/gdd/game-concept.md` — pillars at lines 169-208; MVP definition at lines 294-322; design risks at 269 (frustration concern); 270 (depth concern); 271 (balance concern).
- `prototypes/chapter-prototype/README.md` — how-to-run + the 4-phase loop description.
- `prototypes/vertical-slice/REPORT.md` — prior prototype (technical-only, did not test pillars).
- `production/gate-checks/pre-prod-to-prod-2026-05-04.md` — the gate-check verdict that requested this report.
- `.claude/rules/prototype-code.md` — prototype standards (relaxed) defining what reports must contain.
- `.claude/rules/tooling-gotchas.md` TG-2 — the "stale handoff trust" pattern; this report's refusal-to-fabricate posture is downstream of that lesson.
