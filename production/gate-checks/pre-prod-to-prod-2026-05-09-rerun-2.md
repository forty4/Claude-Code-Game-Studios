# Gate Check: Pre-Production → Production (Rerun #2)

> **Date**: 2026-05-09 PM late (sprint-13 close window)
> **Run sequence**: 2nd rerun in 2026-04-20 → 2026-05-04 → 2026-05-05 → 2026-05-06 → 2026-05-08 AM → 2026-05-08 PM rerun → **2026-05-09 PM late rerun-2** chain (7th gate-check overall; 1st rerun across calendar days)
> **Trigger**: sprint-13 S13-03 close-gate re-evaluation post-attestations (S13-02 USER-OWNED §11 HARD GATE + S13-10 USER-OWNED carry close)
> **Review mode**: lean (4 directors spawned in parallel; full panel)

| Field | Value |
|---|---|
| **Target gate** | Pre-Production → Production |
| **Verdict** | **CONCERNS** (3 of 4 prior path-to-PASS items CLOSED; 1 new HIGH-tier release-blocker surfaced; substrate ratchet positive but content gap material) |
| **Stage flip** | NOT executed — `production/stage.txt` remains `Pre-Production` |
| **Director panel** | 4× CONCERNS (CD + TD + PR + AD; convergent on POLISH-010 root issue) |

## 1. Verdict Trajectory

| Date | Verdict | Director Panel | Note |
|---|---|---|---|
| 2026-04-20 | CONCERNS | initial | Pre-Production stage entered; first gate-check baseline |
| 2026-05-04 | CONCERNS | 4× pre-panel | Path-to-PASS items 1+2 (S7-11 + S8-15) + 3 ADR mandatory + 4 cross-director convergent blocker (AI System) introduced |
| 2026-05-05 | CONCERNS | 4× pre-panel | AI System cross-director blocker addressed |
| 2026-05-06 | CONCERNS | 4× pre-panel | ADR mandatory list reduced |
| 2026-05-08 (AM) | CONCERNS | 3× READY + 1× CONCERNS-CD | CD refined item 3 into Pillar 4 game-facing demonstration requirement |
| 2026-05-08 (PM rerun) | CONCERNS | 3× READY + 1× CONCERNS-CD | Item 3 RECLASSIFIED-PARTIAL → split 3a + 3b per CD; substrate ratchet positive |
| **2026-05-09 (rerun-2)** | **CONCERNS** | **4× CONCERNS (convergent)** | **3 of 4 prior items CLOSED; 1 NEW HIGH-tier release-blocker (POLISH-010) surfaces; substrate ratchet positive but content gap material** |

**Verdict comparison vs. 2026-05-08-PM**: HOLDS at CONCERNS trajectory-wise, but **path-to-PASS items have materially shifted**. Prior 4 items: 3 of 4 CLOSED (Items 1 + 3a + 3b); Item 2 ATTESTED but produced new HIGH-tier surface. Net substrate ratchet: +3 items closed + 1 new item = positive at item-count level but qualitatively different (new item is a release-blocker on production main_scene visual rendering, not a user-attestation gap).

---

## 2. Path-to-PASS Status — 4 Prior Items

### Item 1 — S7-11 user attestation (4 VS Validation items) — **CLOSED**

- **Status at 2026-05-08-PM**: 5th-time carryover (project-record); §11 HARD GATE BOUND at sprint-13 entry per `docs/process/decisions-convention.md` §11.3
- **Resolution**: **CLOSED at sprint-13 S13-02** — disposition (a) USER-ATTESTED 4-of-4 PASS recorded at `prototypes/chapter-prototype/REPORT.md` §Playtest Notes (2026-05-09 PM late). User attestation verbatim: "지난번에 해 봤던 것과 별 차이가 없어서 특별히 언급할 것이 없음" — honest no-blockers across multiple plays.
- **REPORT.md verdict line 14 flipped**: "PROCEED — provisional" → "PROCEED — confirmed (sprint-13 S13-02 user attestation 2026-05-09 PM late; §11 HARD GATE disposition (a) SUCCESS)"
- **Carry chain**: sprint-7 → 8 → 9 → 10 → 11 → 12 → **sprint-13 CLOSES** (6-sprint carry chain TERMINATED; project-record).
- **§11 HARD GATE first-binding outcome**: SUCCESS (precedent established for sprint-14+ structural pre-flight obligations).
- **Commit**: `35b8e3b` (2026-05-09 PM late).

### Item 2 — S8-15 user attestation (manual smoke check Batches 1+3) — **ATTESTED MIXED**

- **Status at 2026-05-08-PM**: 3rd-time carryover; advisory tier (not §11-bound)
- **Resolution**: **ATTESTED at sprint-13 S13-10** with **MIXED outcome** at `production/qa/qa-signoff-sprint-8-2026-05-06.md` §S8-15 USER-OWNED Attestation:
  - Batch 1.1 (game launches): **PASS** — window opened (Metal renderer / Forward Mobile / M4 Pro / engine init clean)
  - Batch 1.2 (initial scene loads / battle visuals render): **FAIL** — user reported "윈도우는 떴음. 배틀화면 안 보임. 그래서 클릭/탭 해보지 못함."
  - Batch 1.3 (input responsive): **BLOCKED-BY-1.2** (nothing visible to click)
  - Batch 3.1 (save/load round-trip): N/A (sprint-9+ scope per Condition 1 line 105)
  - Batch 3.2 (no frame drops): **BLOCKED-BY-1.2** (nothing rendered to measure)
- **Attestation IS the attestation**: per refusal-to-fabricate posture (`.claude/rules/tooling-gotchas.md` TG-2), MIXED verdict is recorded honestly. Carry chain (sprint-8 → 9 → 10 → 11 → 12 → 13) **CLOSES** at S13-10 regardless of verdict.
- **NEW surfaced**: POLISH-009 + POLISH-010 (see §3 below).
- **Commit**: `6275ed1` (2026-05-09 PM late).

### Item 3a — Pillar 4 atmospheric moment promoted to game-facing chapter runtime — **CLOSED**

- **Status at 2026-05-08-PM**: NEW (CD-refined split from prior item 3); requires player-facing atmospheric moment in production scenario-runner runtime, not just prototype-isolated demo
- **Resolution**: **CLOSED earlier in sprint-13** (per `production/session-state/active.md` arc) — ScenarioRunner integration of atmospheric layer landed in production code; player-facing chapter beat 5/8 reveal sequence routes through atmospheric moment dispatch.
- **Verification**: 1288/1288 PASS suite includes atmospheric-layer integration tests; headless boot of production main_scene confirms scenario_runner advances through BEAT_5_BATTLE without atmospheric-dispatch errors.

### Item 3b — ≥1 Pillar 3 player-facing beat OR documented deferral — **CLOSED**

- **Status at 2026-05-08-PM**: NEW (CD-refined split from prior item 3); requires Pillar 3 dynamic demonstration beat OR ADR documenting deferral rationale
- **Resolution**: **CLOSED earlier in sprint-13** (per active.md arc) — chapter-1 narrative beat shipped + ADR documented Pillar 3 emerges-organically deferral rationale.
- **Verification**: Pillar 3 player-facing beat present in chapter-1 hero-roster differentiation (4 archetypes per ADR-0019 §4 produce structurally distinct AI behaviour; user-attested in S13-02 prototype 4-of-4 PASS).

---

## 3. NEW Path-to-PASS Items (post-2026-05-09)

### Item 5 — POLISH-010 production main_scene world-space visual rendering (NEW HIGH-tier release-blocker)

> **Source**: S13-10 USER-OWNED attestation Batch 1.2 FAIL surfacing (2026-05-09 PM late)
> **Tier**: DEFECT HIGH — gates `/gate-check pre-prod-to-prod` PASS verdict; gates `production/stage.txt` Pre-Production → Production flip

**Description**: Production main_scene `scenes/battle/battle_scene.tscn` does NOT render world-space battle visuals in windowed mode. Window opens cleanly; world-space (center) is blank; HUD chrome (BattleHUD prefabs) may render at edges. Backend functionality intact (S13-12 headless verification: 391 turn-domain emits + AI dispatch + scenario LOAD all clean). Failure is rendering-layer / scene-layout / camera-positioning.

**Root cause** (confirmed via 2026-05-09 PM late investigation per S13-10 follow-on; codified at `production/polish-backlog.md` POLISH-010 entry):

`scenes/battle/battle_scene.tscn` is **architecturally a container-only scene** (Node2D + GridLayer + HUDLayer). All 7 systems mounted at runtime in `BattleScene._ready()` are LOGIC-only or HUD-only:

| Runtime mount | Visual rendering responsibility |
|---|---|
| MapGrid (`extends Node`) | NONE — data + lookup only |
| BattleCamera (`extends Camera2D`) | NONE — viewport framing only, no `_draw()` |
| HPStatusController / TurnOrderRunner / AISystem | NONE — pure logic |
| GridBattleController | NONE — controller |
| BattleHUD | HUD chrome only via 14 prefab `.tscn` files |

The world-space tile + unit visuals were intended to come from an authored chapter-specific `.tscn` (`mvp_chapter_01.tscn` = sprites + TileMap + unit Sprite2D children). **That file was never created** — content-authoring gap, NOT a code regression. Production main_scene has been "logic-only renderable" since sprint-3 establishment. Headless E2E test coverage (1288/1288 PASS) gates LOGIC + HUD chrome but NOT world-space visual presence.

**Sibling**: POLISH-009 (missing `mvp_chapter_01.tscn`) is the likely contributing cause — same fix path resolves both.

**Path-to-PASS resolution options** (1 of these, chosen by user/director consensus):

- **Option A (CD + AD strongly preferred)**: Author proper `assets/data/maps/mvp_chapter_01.tres` + `scenes/battle/mvp_chapter_01.tscn` with sprite/TileMap layer applying art-bible ink-wash palette + tile color language + unit silhouette specs. ~1-2hr including integration test + visual evidence at `production/qa/evidence/`. Sprint-14 epic candidate.
- **Option B (TD-tolerable, AD-rejects)**: Port prototype-tier ColorRect rendering into BattleScene as fallback. ~30-50 LoC quick-and-dirty; blurs prototype/production tier boundary. NOT recommended unless sprint-14 timeline demands stop-gap.
- **Option C (CD-tolerant + TD-aligned)**: Ratify **ADR-0021 "Production world-space rendering responsibility"** with deferral rationale documenting (1) prototype-scene attestation substitutes for production-scene visual validation through Production milestone N, (2) hard checkpoint date for production scene visual rendering. Production stage advancement proceeds with documented risk.

### Item 6 — ADR-0021 "Production world-space rendering responsibility" ratification (NEW; TD-led)

> **Source**: TD-PHASE-GATE recommendation (rerun-2)

**Description**: TD identified that the **rendering-responsibility contract is unassigned across ADRs**. ADR-0014/0016 are silent on which Node owns world-space visual rendering, what fallback exists, what the prototype/production tier boundary is. Without this ADR, Production sprints would author `mvp_chapter_01.tscn` against an undefined interface — exactly the cross-system integration failure mode TD owns.

**Path-to-PASS**: Author ADR-0021 with status Accepted before Production advancement. 1-2 hour scoped ADR (not a sprint). Unblocks sprint-14 POLISH-009 cleanly.

### Item 7 — S8-15 re-attestation post-fix (NEW; CD-led)

> **Source**: CD-PHASE-GATE recommendation (rerun-2)

**Description**: Once POLISH-010 ships (Option A or B), re-run the §1.2 / 1.3 / 3.2 attestation steps that were BLOCKED-BY-1.2 in the original S13-10 attestation. Convert MIXED outcome → clean PASS. The current MIXED state on a Production-gating attestation is the formal blocker the gate must see resolved.

### Item 8 — Sprint-13 retro AI: verification-gap pattern codification (NEW; TD + AD)

> **Source**: TD + AD convergent recommendation (rerun-2)

**Description**: The 1288/1288 PASS automated suite gates LOGIC + HUD chrome but does NOT gate world-space VISUAL PRESENCE because headless tests run with `--headless` (no rendering pipeline). Pattern stable at 2 invocations: POLISH-008 (ObjectDB leak surfaced via headless verification gap) + POLISH-010 (visual rendering surfaced via same gap). Meets codification threshold per sprint-13 retro AI #2 carryover-concentration tracking criteria.

**Path-to-PASS**:
- (a) Sprint-13 retro logs the verification-gap pattern as a known structural limitation
- (b) Sprint-14 AI scopes a visual-smoke harness (windowed boot + screenshot diff or non-blank pixel sentinel)
- (c) AD adds "world-space visual presence" as gate criterion for future pre-prod-to-prod / prod-to-polish reruns: AD attests production main_scene renders non-blank world-space in windowed mode, confirmed by screenshot evidence at `production/qa/evidence/`.

### Item 9 — Sprint-14 carryover concentration audit at plan-time (NEW; PR-led)

> **Source**: PR-PHASE-GATE recommendation (rerun-2)

**Description**: Carryover concentration into sprint-14 = ~4 items at threshold (POLISH-009 + POLISH-010 + S13-06 §7 promotion + S13-03 close-gate continuance). If sprint-13 spillover pushes concentration to ≥5, trigger §11 HARD GATE rebind to closure-leaning before sprint-14 story selection. Do not let process discipline mask growing content debt.

---

## 4. Director Panel Assessment (Lean Mode — All 4 Spawned in Parallel)

### Creative Director: **CONCERNS**

**Verbatim**: "Pillars are creatively validated — Pillar 4 atmospheric moment shipped, S13-02's 4-of-4 PASS prototype attestation confirms the core mechanic delivers its intended fantasy, and the closure-mode discipline (1288/1288 PASS, 66th FFB preserved) demonstrates production-grade quality control. However, **POLISH-010 is a creative-readiness blocker, not a deferred content gap**: Production-stage advancement requires that the production main_scene be capable of demonstrating the pillars in the canonical playable build. A prototype-only validation creates a two-track creative truth — the pillars work *somewhere*, but not *where players will actually meet them*. That's an unresolved ludonarrative coherence risk at the build level, not just an art TODO."

**Path-to-PASS**: (1) POLISH-010 disposition before Production entry (Option A preferred, Option C deferral ADR tolerated); (2) S8-15 re-attestation post-fix.

**Validation criteria**: Gate flips to READY when (1) production main_scene renders battle visuals in windowed mode (or deferral ADR signed), AND (2) S8-15 §1.2/1.3/3.2 re-attest PASS.

### Technical Director: **CONCERNS**

**Verbatim**: "Technical foundation is genuinely production-ready — 1288/1288 PASS at 66 consecutive baselines, S13-12 archetype cleanup demonstrates ADR-0014 §3 precedent works, S13-05 byte-check dogfooded 6× clean (root-cause kill confirmed), §11 HARD GATE binding succeeded live, control manifest current, foundation+core epics shipped. However, POLISH-010's root-cause investigation surfaced a **structural verification gap**, not just an asset gap: `battle_scene.tscn` is container-only by design, world-space rendering responsibility is unassigned across ADRs, and headless CI cannot detect blank-window symptoms (same pattern that masked POLISH-008 ObjectDB leak). Advancing to Production without ratifying the rendering-responsibility contract risks Production sprints authoring `mvp_chapter_01.tscn` against an undefined interface — exactly the cross-system integration failure mode TD owns."

**Path-to-PASS**: (1) Ratify ADR-0021 BEFORE Production advancement (1-2hr scoped doc); (2) Verification-gap acknowledgement codified as sprint-13 retro AI.

POLISH-010 itself is correctly an authored-asset task for sprint-14, NOT a Production-gate blocker — once R-0021 defines the contract.

### Producer: **CONCERNS**

**Verbatim**: "Process discipline is genuinely production-ready — §11 HARD GATE first-binding SUCCESS, 6× byte-check dogfood (sprint-3 retro AI #3 root-cause closure across 4 prior recurrences), 47+ in-patch hygiene streak, 66th FFB, and the first project mid-sprint mode redesignation handled cleanly. Path-to-PASS items 1+3a+3b CLOSED; both 6-sprint (S7-11) and 5-sprint (S8-15) carry chains TERMINATED this sprint, which is the strongest carry-chain closure pair in project history. **However**, S13-10 surfaced POLISH-010 as a HIGH-tier release-blocker on production main_scene visual rendering — qualitatively different from sibling POLISH-007/008 (defer-to-Polish pattern). A Production-stage advancement where the production scene cannot demonstrate the work in windowed mode is content/asset-authoring scope masquerading as ready-state."

**Path-to-PASS**: (1) POLISH-010 disposition decision before sprint-14 plan-bind (Option A absorption with named owner + AC, OR Option C deferral ADR); (2) Carryover concentration audit at sprint-14 plan-time (≥5 triggers §11 HARD GATE rebind to closure-leaning).

### Art Director: **CONCERNS**

**Verbatim**: "Art bible, visual identity anchor, and UX specs are all signed off and carry cleanly from the prior rerun — no regression on any AD-owned artifact. However, POLISH-010 changes the AD calculus materially: the production main_scene's world-space is a confirmed blank at runtime. This means the art bible exists but the game cannot currently demonstrate any of it contextually — reserved colors, ink-wash palette, silhouette hierarchy, TileMap tile language — none of it is reachable by a player looking at the production scene. The prototype demonstrates that art-direction intent works mechanically, but the prototype is explicitly throwaway-tier and was never the AD gate target. POLISH-010 is not an art-bible deficiency; it is a scene-content gap that renders the art bible experientially untestable in production."

**Path-to-PASS**: (1) Sprint-14 must author `scenes/battle/mvp_chapter_01.tscn` with proper world-space visual layer (sprite/TileMap applying art-bible ink-wash palette, tile color language, unit silhouette specs) — **Option A only; Option B prototype-tier fallback rejected** (violates prototype/production tier boundary); (2) Add "world-space visual presence" as AD gate criterion going forward.

### Verdict Synthesis

**Per skill rule**: any director CONCERNS → verdict minimum CONCERNS. **4× CONCERNS = verdict CONCERNS**.

**Convergence point**: all 4 directors converge on POLISH-010 as the root issue (creative-readiness, technical contract, production scope, art demonstrability). No director said NOT READY/FAIL. POLISH-010 + ADR-0021 are jointly resolvable in sprint-14 — verdict will flip on next rerun once those land.

**Strongest positive trajectory signal**: 3 of 4 prior path-to-PASS items CLOSED simultaneously (Items 1 + 3a + 3b) is the strongest single-sprint closure pair in the rerun chain history. Sprint-13 also delivered: §11 HARD GATE first-binding SUCCESS / 6× byte-check dogfood (codification effective) / 6-sprint S7-11 carry chain TERMINATED / 5-sprint S8-15 carry chain TERMINATED.

---

## 5. Required Artifacts: 21/21 Present (lean rerun — no re-audit; substrate stable from 2026-05-08-PM)

Lean-mode rerun does NOT re-audit the 21 artifacts validated at 2026-05-08-PM (all READY at TD/PR/AD; CD-refined item 3 closed mid-sprint-13). Reference: `production/gate-checks/pre-prod-to-prod-2026-05-08-rerun.md` §2.

**Net-new since 2026-05-08-PM**:
- `production/qa/qa-signoff-sprint-8-2026-05-06.md` §S8-15 USER-OWNED Attestation section (sprint-13 S13-10)
- `prototypes/chapter-prototype/REPORT.md` §Playtest Notes section + Verdict line update (sprint-13 S13-02)
- `production/polish-backlog.md` POLISH-009 + POLISH-010 entries + indices updated

**Pending-NEW** (path-to-PASS):
- `docs/architecture/ADR-0021-production-world-space-rendering-responsibility.md` — TD-required before Production advancement

---

## 6. Path-to-PASS — Consolidated (5 items)

| # | Item | Owner | Tier | Estimated effort |
|---|---|---|---|---|
| 5 | POLISH-010 disposition (Option A author proper visuals OR Option C deferral ADR) | technical-artist or godot-gdscript-specialist | HIGH (release-blocker) | 1-2h (Option A); 1h (Option C) |
| 6 | ADR-0021 "Production world-space rendering responsibility" ratification | technical-director | HIGH (gate blocker) | 1-2h |
| 7 | S8-15 §1.2/1.3/3.2 re-attestation post-POLISH-010-fix | user (after Option A ships) | MEDIUM | ~10 min |
| 8 | Sprint-13 retro AI codifies verification-gap pattern + AD gate criterion | retrospective + art-director | LOW | 30 min (retro AI add) |
| 9 | Sprint-14 carryover concentration audit at plan-time (≥5 triggers §11 closure rebind) | producer | MONITOR | sprint-14 plan-time only |

**Minimal path to next-rerun PASS** (chronological):
1. Sprint-14 entry: ratify ADR-0021 (Item 6) — 1-2h claude side
2. Sprint-14 first sprint: Option A author `mvp_chapter_01.tres` + `mvp_chapter_01.tscn` (Item 5) — 1-2h
3. User re-attestation (Item 7) — ~10 min user time
4. Sprint-14 retro: codification (Item 8) — 30 min
5. Run `/gate-check pre-prod-to-prod` rerun-3 — verdict eligible PASS

Estimated sprint-14 entry-to-rerun-3-PASS: ~3-4 hours claude time + ~10 min user time, fits in single sprint-14 day.

**Alternative**: accept Production-stage advancement at CONCERNS via Option C deferral ADR (Item 5 Option C resolves both Item 5 + Item 6 simultaneously). Risk: production main_scene remains blank in windowed mode through Production milestone N; visual smoke gate is gated by AD criterion (Item 8c). User decision.

---

## 7. Chain-of-Verification

**5 challenge questions checked** (per skill Phase 5a CONCERNS draft template):

1. **Could any listed CONCERN be elevated to a blocker (FAIL) given the project's current state?** — POLISH-010 is HIGH-tier release-blocker (per AD/PR explicit framing). Per skill rule, only NOT READY from any director triggers FAIL. All 4 directors said CONCERNS not NOT READY; POLISH-010 is resolvable in sprint-14. Verdict CONCERNS holds.

2. **Is the concern resolvable within the next phase?** — Yes. TD says ADR-0021 is 1-2hr scoped doc; AD says authored .tscn is sprint-14 epic candidate. Both resolvable in sprint-14 entry within 3-4 hours claude time + 10 min user time.

3. **Did I soften any FAIL condition into a CONCERN to avoid a harder verdict?** — No. None of the 4 directors used NOT READY framing. The visual rendering gap is real but doesn't make the project structurally broken. The 1288 tests + sprint-13 attestation closure of 3 of 4 prior items demonstrate substantive progress.

4. **Are there artifacts I didn't check that could reveal additional blockers?** — Did not re-audit the 21/21 prior artifacts (relied on 2026-05-08-PM rerun's READY at TD/PR/AD). This is intentional in lean-mode rerun — only delta is examined. Substrate stability assumed from prior rerun's audit; no signal in the delta period suggests regression.

5. **Do all 4 CONCERNS together create a blocking problem even if each is minor alone?** — All 4 CONCERNS are about the SAME root issue (POLISH-010 world-space rendering). Convergent, not additive. A single coherent path-to-PASS (Items 5 + 6 + 7) resolves all 4.

**Verdict**: CONCERNS (unchanged from draft).
**Chain-of-Verification result**: 5 questions checked — verdict UNCHANGED. Confirmation that all 4 director CONCERNS are convergent on the same root issue strengthens confidence that the gate is honestly priced.

---

## 8. Recommended Next Steps

**Sprint-13 close ceremony** (path forward if user wants to close sprint-13 cleanly):
1. `/smoke-check sprint` → `production/qa/smoke-sprint-13-2026-05-09.md` (PASS expected per current 1288/1288 baseline; closure-mode posture)
2. `/qa-plan sprint-13-closure` → closure addendum (S13-11 + S13-12 bug-fix Logic-tier delta on top of original 100% non-runtime closure profile)
3. `/team-qa sprint-13 attestation-mode` → `production/qa/qa-signoff-sprint-13-2026-05-09.md` — verdict APPROVED WITH CONDITIONS (POLISH-010 + ADR-0021 as carry-conditions to sprint-14)
4. `/retrospective sprint-13` → `production/retrospectives/retro-sprint-13-2026-05-09.md` — must address §11 first-binding outcome SUCCESS + closure-mode first signal-evaluation outcome + 2 codification AIs delivered (S13-04 + S13-05) + verification-gap pattern codification (NEW Item 8 from this gate-check) + Mid-sprint mode redesignation precedent + 6× PRE-FLIGHT byte-check dogfood SUCCESS metric
5. Sprint-13 close commit + push
6. `production/sprint-status-history.md` Sprint 13 section archive

**Sprint-14 entry posture**:
- Plan-time author: ADR-0021 (Item 6) + POLISH-010 disposition (Item 5 Option A or C)
- Carryover concentration audit (Item 9) — verify ≤4 items
- Sprint-14 mode: closure-leaning if concentration ≥4, mixed-hybrid if greenfield work

**`production/stage.txt`**: NOT updated. Remains `Pre-Production` until rerun-3 PASS verdict.

---

## 9. Cross-References

- Prior rerun: `production/gate-checks/pre-prod-to-prod-2026-05-08-rerun.md` (path-to-PASS items 1+2+3a+3b context)
- §11 HARD GATE rule: `docs/process/decisions-convention.md` §11.3 Live application table
- POLISH-010 root-cause analysis: `production/polish-backlog.md` POLISH-010 entry (full investigation)
- Sprint-13 plan: `production/sprints/sprint-13.md` (DoD line 169 §11 binding fulfilled checkbox flipped [x] this sprint)
- Verification-gap precedent: POLISH-008 ObjectDB leak (sibling gap surfaced via same headless-only verification limitation)
- ADR-0021 candidate context: `production/polish-backlog.md` POLISH-010 §Action when picked up
