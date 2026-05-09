# Gate Check: Pre-Production → Production (Rerun #3)

> **Date**: 2026-05-09 PM late-late (sprint-14 mid-session closure)
> **Run sequence**: 3rd rerun in 2026-04-20 → 2026-05-04 → 2026-05-05 → 2026-05-06 → 2026-05-08 AM → 2026-05-08 PM rerun → 2026-05-09 PM late rerun-2 → **2026-05-09 PM late-late rerun-3** chain (8th gate-check overall; 2nd rerun across the same calendar day)
> **Trigger**: sprint-14 S14-04 (path-to-PASS execution + POLISH-011 triage outcome) — runs after sprint-14 absorbed Items 5/6/7/8/9 and surfaced new release-blocker
> **Review mode**: lean (4 directors spawned in parallel; full panel)

| Field | Value |
|---|---|
| **Target gate** | Pre-Production → Production |
| **Verdict** | **FAIL** (3 of 4 directors NOT READY; convergent on POLISH-011 turn-loop integration gap; substrate ratchet on prior 4 items strongly positive but new release-blocker is qualitatively worse than predecessor) |
| **Stage flip** | NOT executed — `production/stage.txt` remains absent (Pre-Production implicit) |
| **Director panel** | CD: NOT READY / TD: NOT READY / PR: NOT READY / AD: **READY** (1st READY in rerun chain history) |

## 1. Verdict Trajectory

| Date | Verdict | Director Panel | Note |
|---|---|---|---|
| 2026-04-20 | CONCERNS | initial | Pre-Production stage entered; first gate-check baseline |
| 2026-05-04 | CONCERNS | 4× pre-panel | Path-to-PASS items 1+2 + 3 ADR mandatory + cross-director AI System blocker |
| 2026-05-05 | CONCERNS | 4× pre-panel | AI System cross-director blocker addressed |
| 2026-05-06 | CONCERNS | 4× pre-panel | ADR mandatory list reduced |
| 2026-05-08 (AM) | CONCERNS | 3× READY + 1× CONCERNS-CD | CD refined item 3 into Pillar 4 game-facing demonstration |
| 2026-05-08 (PM rerun) | CONCERNS | 3× READY + 1× CONCERNS-CD | Item 3 RECLASSIFIED-PARTIAL → split 3a + 3b per CD |
| 2026-05-09 (rerun-2) | CONCERNS | 4× CONCERNS (convergent) | 3 of 4 prior items CLOSED; POLISH-010 NEW HIGH release-blocker |
| **2026-05-09 (rerun-3)** | **FAIL** | **3× NOT READY (CD/TD/PR) + 1× READY (AD)** | **4 of 4 prior items CLOSED + 1 partial; POLISH-011 NEW CRITICAL release-blocker (qualitatively worse than POLISH-010); 1st verdict downgrade in rerun chain history** |

**Verdict comparison vs. rerun-2**: DOWNGRADED CONCERNS → FAIL. The substrate ratchet on prior items is strongly positive (Items 5/6/7/8/9 disposition all closed or partial), but the NEW Item 10 (POLISH-011) is qualitatively worse than its predecessor (POLISH-010 was a content-authoring gap; POLISH-011 is an MVP integration gap). Three directors moved from CONCERNS to NOT READY because production main_scene progressed from "cannot demonstrate visuals" to "cannot demonstrate gameplay" — a downgrade in experiential state despite substrate gains.

**1st READY in rerun chain history**: Art Director returned READY for the first time across all 8 gate-checks. POLISH-010 closure via Option A (CD + AD strongly preferred path at rerun-2) shipped cleanly at S14-02. AD-bound substrate (art bible compliance, palette discipline, silhouette specs, world-space rendering presence) is now in verified production state.

---

## 2. Path-to-PASS Status — 5 Prior Items (rerun-2 Items 5/6/7/8/9)

### Item 5 — POLISH-010 disposition — **CLOSED** ✅

- **Status at rerun-2**: NEW HIGH-tier release-blocker (production main_scene blank window in windowed mode)
- **Resolution**: **CLOSED at sprint-14 S14-02 via Option A** (CD + AD strongly preferred path)
  - `assets/data/maps/mvp_chapter_01.tres` — Changbanpo 15×15 + col 3 RIVER + 3 BRIDGE chokepoints (exact-match to `mvp_shu.json`)
  - `scenes/battle/mvp_chapter_01.tscn` — Node2D root + 6 Polygon2D unit silhouettes per art-bible §3-2 병종 형태 매핑
  - `chapter_visuals.gd` (NEW) — `_draw()` tile renderer using non-reserved-color subset of art-bible §4.1 (주홍/금색 absolute prohibition observed)
  - `battle_scene.gd` STEP 1.5 mount per ADR-0021 §6 verbatim (Path A precedent)
- **Verification**: 1288/1288 PASS preserved (67th consecutive FFB); user-captured visual evidence at `production/qa/evidence/sprint-14-polish-010-screenshot.png` (44KB) + `production/qa/evidence/sprint-14-polish-010-evidence.md` (7-section AC mapping)
- **Commit**: `715350c` (sprint-14 mid-session bundled batch)

### Item 6 — ADR-0021 ratification — **CLOSED** ✅

- **Status at rerun-2**: NEW (TD-led; 1-2hr scoped doc)
- **Resolution**: **CLOSED at sprint-14 S14-01** — Status: **Accepted**. 576 lines covering §1 GridLayer mount + §2 paths + §3 fallback + §4 tier-boundary + §6 ADR-0016 §3 STEP 1.5 amendment via Path A precedent. First project ADR ratified at sprint entry as gate-check carry-condition.
- **Commit**: `715350c`

### Item 7 — S8-15 §1.2/1.3/3.2 re-attestation post-fix — **PARTIAL** ⚠️

- **Status at rerun-2**: NEW (CD-led; ~10 min user time after Option A ships)
- **Resolution**: **PARTIAL at sprint-14 S14-03** — user re-attestation post-S14-02:
  - §1.2 (visual rendering): MIXED → **PASS** (S14-02 Option A confirmed)
  - §3.2 (no frame drops): MIXED → **PASS** (battle progresses without frame drops)
  - §1.3 (input responsive): **FAIL** — input non-responsive in windowed mode despite visual rendering correct → **POLISH-011 NEW filed**
- **MIXED outcome**: still MIXED (different composition than original S13-10 MIXED; §1.2/§3.2 closed but §1.3 surfaces NEW issue)
- **2nd refusal-to-fabricate invocation in S8-15 lifecycle** (per `.claude/rules/tooling-gotchas.md` TG-2). Pattern stable at 2 invocations.
- **Commit**: `715350c`

### Item 8 — Verification-gap pattern G-30 codification + AD gate criterion — **CLOSED** ✅

- **Status at rerun-2**: NEW (TD + AD convergent; sprint-13 retro AI #6/#7)
- **Resolution**: **CLOSED at sprint-14 S14-06 + S14-07**
  - **S14-06**: G-30 entry at `.claude/rules/godot-4x-gotchas.md` (+40 LoC). Pattern stability ESCALATED from 2 invocations (rerun-2 framing) to **4 invocations within 48hr** (POLISH-008 ObjectDB + POLISH-010 visual + POLISH-011-input-frame + POLISH-011-actual turn-loop). TD-013 register cross-ref updated; rule file 21→22 entries.
  - **S14-07**: AD-PHASE-GATE + TD-PHASE-GATE production-gate amendments at `.claude/docs/director-gates.md`. AD criterion: "world-space visual presence" check. TD criterion: "lifecycle integrity" check (input dispatch + battle-loop end-to-end). Both reference G-30; both return CONCERNS-min if no windowed-smoke harness exists.
- **Commit**: `164c5ad` (S14-06) + `b2ad3e9` (S14-07 + S14-08)

### Item 9 — Sprint-14 carryover concentration audit at plan-time — **CLOSED** ✅

- **Status at rerun-2**: NEW (PR-led; ≥5 triggers §11 HARD GATE rebind)
- **Resolution**: **CLOSED at sprint-14 plan-time** — concentration audited at ≥5 (POLISH-009 + POLISH-010 + S13-06 §7 promotion + S13-03 close-gate continuance + 3 retro AI codifications); **§11 HARD GATE rebind TRIGGERED**; sprint-14 plan adopted MIXED HYBRID closure-leaning posture per `production/sprints/sprint-14.md:4f2ea2e`. Plan absorbed Items 5/6/7/8 as dedicated stories; only S14-09 (mid-sprint mode redesignation tracking) deferred as backlog.

---

## 3. NEW Path-to-PASS Item 10 (post-rerun-2 → rerun-3)

### Item 10 — POLISH-011 turn-loop architectural integration gap (NEW CRITICAL release-blocker)

> **Source**: S14-03 USER-OWNED §1.3 re-attestation FAIL surfacing (2026-05-09 PM late) → escalated to CRITICAL after rerun-3 PM late-late triage finding
> **Tier**: DEFECT CRITICAL — gates `/gate-check pre-prod-to-prod` PASS verdict; gates `production/stage.txt` Pre-Production → Production flip; **scope qualitatively WORSE than POLISH-010 was** (predecessor was 1-2hr content fix; POLISH-011 is 2-3 sprint-15 story arc spanning 3 ADR amendments)

**Description**: Production main_scene `scenes/battle/battle_scene.tscn` boots cleanly post-S14-02 (visuals render correctly per Item 7 §1.2 PASS attestation), but the natural battle loop **does not execute end-to-end**. With ROUND_CAP=30 + T5=`pass`, the entire battle plays out across deferred slots in 2-3 seconds → DRAW outcome. **No player input is honored; no AI command is executed**; the game is unplayable in production main_scene.

**Originally filed (sprint-14 S14-03 PM late) as HIGH-tier "input non-responsive"**. **TRIAGE FINDING (sprint-14 PM late-late post-/clear recovery) re-attributed** root cause from input pipeline to turn-loop architectural integration gap; tier escalated **HIGH → CRITICAL**:

1. **`src/core/turn_order_runner.gd:561-562` `_execute_action_budget(_unit_id)` is a STUB** (body is `pass`). Every unit's turn falls through T4→T5→T6→T7 synchronously without any external system declaring an action. ADR-0011 §Decision Contract 5 specifies a Callable controller injection that was never wired (story-005 obligation unfulfilled).
2. **`AISystem.ai_action_ready` signal has NO subscriber in `src/`** (verified via `grep -rn ai_action_ready src/`). AISystem.decide() runs and emits, but no handler exists to call `_turn_runner.declare_action()` with the chosen command.
3. **`_turn_runner.declare_action()` is only called from `src/feature/grid_battle/grid_battle_controller.gd:721`** inside `end_player_turn()` — the explicit "End Turn" button handler. No path exists to declare MOVE/ATTACK/USE_SKILL/DEFEND during a unit's turn from the natural grid-click flow.

**ROUND_CAP=30** in `assets/data/balance/balance_constants.json` matches user-observed 30-turn DRAW exactly. With T5=`pass` + deferred chaining at `turn_order_runner.gd:534/641`, all 30 rounds tick across deferred slots in 2-3 seconds and `_end_round` emits DRAW per `:626-627`.

**Why headless 1288/1288 PASS doesn't catch it**: tests call `_advance_turn` / `declare_action` / individual T-step methods directly via test seams. The full `initialize_battle` → `_begin_round.call_deferred()` → end-to-battle flow is exercised in windowed-mode boot only. **G-30 verification gap pattern, 4th invocation** (POLISH-008 / POLISH-010 / POLISH-011-input-frame / POLISH-011-turn-loop-actual).

**Path-to-PASS resolution** (sprint-15 dedicated scope; sprint-14 cannot absorb per closure-mode discipline):

- **S15-A**: ADR-0011 §Decision Contract 5 Callable controller wiring + T5 await — replace `_execute_action_budget(_unit_id)` stub with the controller dispatch obligated by story-005. ~3-5h with tests.
- **S15-B**: AISystem.ai_action_ready subscriber on GBC + declare_action plumbing for AI commands — wire `AISystem.ai_action_ready` to a handler that routes the emitted command into `_turn_runner.declare_action()`. ~2-4h.
- **S15-C**: Input-action → declare_action plumbing for player commands — extend `grid_battle_controller.gd` so natural grid-click MOVE/ATTACK/USE_SKILL/DEFEND flows call `declare_action()`. ~3-5h.

Estimated sprint-15 entry-to-rerun-4-eligible: ~10-15 hours claude time + new natural-loop integration test (non-seam) closing G-30 gap for the turn loop itself.

**Cross-references**:
- POLISH-011 entry + TRIAGE FINDING: `production/polish-backlog.md` (search "POLISH-011")
- TRIAGE FINDING evidence: `production/session-state/active.md` (gitignored ephemeral)
- Triage commit: `9c249ca` (TRIAGE FINDING amendment)
- G-30 codification: `.claude/rules/godot-4x-gotchas.md` G-30 entry (sprint-14 S14-06 commit `164c5ad`)
- ADR cross-references: ADR-0011 §Decision Contract 5 (TurnOrderRunner) / ADR-0014 §3 (GridBattleController) / ADR-0019 §Decision (AISystem)

---

## 4. Director Panel Assessment (Lean Mode — All 4 Spawned in Parallel)

### Creative Director: **NOT READY**

**Verbatim**: "The substrate ratchet since rerun-2 is genuine and substantial — POLISH-010 closed cleanly via Option A (Changbanpo 15×15 + chokepoints + 6 unit silhouettes + ADR-0021 §6 STEP 1.5 mount), ADR-0021 ratified at 576 lines, S8-15 partial re-attestation flipped §1.2/§3.2 to PASS, G-30 codified at 4 invocations, and §11 HARD GATE rebind correctly produced a closure-leaning sprint-14. From a Creative Direction lens, that is the strongest closure pair in rerun-chain history and proves the discipline is working. But POLISH-011 is not a content-authoring gap dressed up as a release-blocker the way POLISH-010 was — it is a turn-loop integration void where `_execute_action_budget` is `pass`, `AISystem.ai_action_ready` has no subscriber, and `declare_action()` only fires from the explicit \"End Turn\" button. With T5=pass, the entire battle plays out across deferred slots in 2-3 seconds without any player input or AI dispatch and terminates at ROUND_CAP=30 DRAW, which means none of Pillar 1-4 can be experienced AT ALL in production main_scene. Advancing to Production stage when no pillar is demonstrable in the canonical entry point is the definition of a stage-name that means nothing — Production is the stage where pillars get polished, not the stage where they first become reachable. Sprint-14 closure-mode discipline correctly refused absorption; that is the right call for sprint integrity but it also means rerun-3 is asking the gate to bless a worse experiential state than rerun-2 (cannot demonstrate gameplay > cannot demonstrate visuals). NOT READY is the honest verdict — this is a structural integration gap, not a CONCERNS-tier polish item."

**Path-to-PASS**:
- POLISH-011 fix MUST land before pre-prod→prod rerun-4: sprint-15 stories spanning ADR-0011 §Decision Contract 5 + ADR-0014 + ADR-0019.
- S8-15 §1.3 third re-attestation required after POLISH-011 fix (refusal-to-fabricate posture preserved; would be 3rd invocation; pattern stability ESCALATES 2→3).
- Validation criterion for rerun-4 PASS: a 30-second smoke-check session in production main_scene must demonstrate at least one player-declared action AND one AI-dispatched action without ROUND_CAP DRAW; if the battle still resolves in <5s, POLISH-011 is not actually closed.
- Sprint-15 plan-time §11 HARD GATE check: POLISH-011 occupies the protected slot; any other carryover concentration ≥4 triggers closure-mode posture again.

### Technical Director: **NOT READY**

**Verbatim**: "The substrate ratchet is genuinely production-grade — 1288/1288 tests, 67th FFB, ADR-0021 ratified, G-30 codified at 4-invocation stability, tech-debt register hygiene maintained — but Production-stage advancement requires that the production scene execute the core gameplay loop end-to-end, and POLISH-011 proves it cannot. Three integration boundaries are unwired across ADR-0011 (Callable controller stub at `turn_order_runner.gd:561-562`), ADR-0014 (`AISystem.ai_action_ready` has zero subscribers in `src/`), and ADR-0019 (`declare_action()` only fires from the End Turn button — no MOVE/ATTACK/USE_SKILL/DEFEND pathway during natural play). With T5=pass + deferred chaining + ROUND_CAP=30 the battle resolves to DRAW in 2-3 seconds; this is qualitatively WORSE than POLISH-010's rendering ambiguity because it is a CORE GAMEPLAY LOOP gap, not a presentation-layer gap. Headless tests pass because they bypass the natural loop via direct seam calls — the exact G-30 verification-gap pattern this gate just codified, now manifesting as a release-blocker the gate would itself ratify by advancing. Advancing to Production with a battle loop that cannot complete naturally would invert the gate's purpose; \"READY\" is not defensible while the production main scene plays itself to a draw."

**Path-to-PASS**:
- Wire ADR-0011 §Decision Contract 5: replace `_execute_action_budget(_unit_id)` stub at `turn_order_runner.gd:561-562` with the Callable controller dispatch obligated by story-005.
- Wire ADR-0014 subscriber: connect `AISystem.ai_action_ready` to a handler that routes the emitted command into `_turn_runner.declare_action()`.
- Wire ADR-0019 player path: extend `grid_battle_controller.gd` so natural grid-click MOVE/ATTACK/USE_SKILL/DEFEND flows call `declare_action()`, not just `end_player_turn()`.
- Add a natural-loop integration test (non-seam) that drives one full battle to a non-DRAW resolution; this closes the G-30 verification gap for the turn loop itself.
- Re-run `/gate-check pre-prod-to-prod` after POLISH-011 lands; substrate ratchet items 5/6/8/9 remain CLOSED and need no re-attestation.

### Producer: **NOT READY**

**Verbatim**: "Sprint-14 has delivered exceptional substrate ratchet — 4 of 4 prior path-to-PASS items CLOSED (strongest single-sprint closure ratio in rerun-chain history) with sustained process discipline (PRE-FLIGHT byte-check ~17× clean, §11 HARD GATE rebind succeeded plan-time, G-30 codified, AD+TD prompts amended, ADVISORY batch classified). However, S14-03's POLISH-011 discovery is a categorical Production-readiness failure that overrides the substrate gains: §1.3 attestation FAIL means the production main_scene cannot execute a battle end-to-end through any natural input or AI dispatch path — turn-loop architectural integration gap spanning ADR-0011 + ADR-0014 + ADR-0019. Production stage advancement requires a working core gameplay loop in the production scene, not just well-tested subsystems in test scenes. POLISH-011 is qualitatively worse than POLISH-010 was (CRITICAL release-blocker tier vs HIGH; 2-3 sprint-15 stories vs 1-2hr fix; ADR amendments vs single-file POLISH). Sprint-14 closure-mode discipline correctly PROHIBITED absorption — that's the right call, but it pushes the gate decision out. Additionally, sprint-15 carryover concentration audit (POLISH-011 = 2-3 stories + S13-06 promotion call + likely S14-05 carry) puts concentration ALREADY at ~5+, which will trigger ANOTHER §11 HARD GATE rebind at sprint-15 plan-time — a second consecutive closure-leaning sprint is a strong tell that Production-stage is at least one full sprint away."

**Path-to-PASS**:
- POLISH-011 must be CLOSED via sprint-15 Must Have stories (turn-loop architectural integration in production main_scene; ADR-0011/0014/0019 amendments ratified).
- S8-15 §1.3 re-attestation must PASS (production main_scene executes battle end-to-end through natural input + AI dispatch paths).
- Sprint-15 must complete without §11 HARD GATE rebind triggering a third consecutive closure-leaning sprint (signal that substrate is finally stable enough for new-feature posture).
- S13-06 §7 producer promotion call resolved (carry from sprint-14 S14-05).
- Sprint-15 retro must show carryover concentration <5 at sprint-16 plan-time (substrate-decay confirmed).
- Re-run `/gate-check pre-prod-to-prod` rerun-4 after sprint-15 close, not before.

### Art Director: **READY** (1st READY in rerun chain history)

**Verbatim**: "The rerun-2 AD blocker has been completely resolved. Option A — my strongly-preferred path — shipped clean at S14-02: `assets/data/maps/mvp_chapter_01.tres` (Changbanpo 15×15 with col-3 RIVER + 3 BRIDGE chokepoints matching `mvp_shu.json` exactly), `scenes/battle/mvp_chapter_01.tscn` (Node2D root + 6 Polygon2D unit silhouettes per art-bible §3-2 병종 형태 매핑), and `chapter_visuals.gd` (`_draw()` tile renderer using the non-reserved-color subset of §4.1). The user-captured screenshot confirms it: 15×15 grid renders in windowed mode with correct tile color language (소록 PLAINS, 청회 RIVER column, 황토 갈색 BRIDGE chokepoints, 황토 어두움 HILLS), 6 unit silhouettes at correct deployment positions with 촉 deep-blue squares and 위 iron-gray shapes distinguishable, 1px 묵 먹선 grid boundaries, and zero reserved-color violations — 주홍 and 금색 are absent from every rendered surface. ADR-0021 ratified at S14-01 assigns the rendering-responsibility contract cleanly. S14-07 added world-space visual presence as an AD gate criterion going forward. S8-15 §1.2 visual rendering re-attestation flipped MIXED to PASS. The prototype/production tier boundary was honored throughout — Polygon2D editor-authored nodes and `_draw()` CanvasItem API, zero `ColorRect.new()` or `Label.new()` calls. POLISH-011 is a turn-loop architectural integration gap under TD/PR scope; it does not touch visual identity, art bible compliance, palette discipline, silhouette specs, or world-space rendering presence — all of which are now in verified production state. From an Art Direction standpoint, the game can demonstrate its visual identity in the canonical production scene, which was the precise condition I required. This gate is clear."

**Path-to-PASS**: None. AD-bound substrate is READY.

### Verdict Synthesis

**Per skill rule**: any director NOT READY → verdict minimum FAIL. **3 of 4 NOT READY (CD/TD/PR) = verdict FAIL**.

**Convergence point**: 3 directors converge on POLISH-011 as the root issue (creative-readiness, technical contract, production scope). AD returns READY for the first time in rerun chain history because POLISH-010 closure shipped Option A cleanly + S14-07 added the AD gate criterion + S8-15 §1.2 attestation flipped to PASS — POLISH-011 does NOT touch AD-bound substrate.

**Strongest positive trajectory signal**: 4 of 4 prior path-to-PASS items CLOSED (Items 5/6/8/9) + Item 7 partial — this is the strongest single-sprint closure ratio in rerun chain history. Sprint-14 also delivered: ADR-0021 ratified / G-30 codified at 4 invocations / TD-013 register 70→73 entries (TD-071/072/073 NEW from S14-08) / AD+TD phase-gate prompts amended / §11 HARD GATE rebind succeeded plan-time / PRE-FLIGHT byte-check dogfood ~17× clean.

**Strongest negative signal**: 1st verdict downgrade (CONCERNS → FAIL) in rerun chain history. The downgrade is NOT from substrate regression — it is from a NEW release-blocker that is qualitatively WORSE than its predecessor. POLISH-011's scope (2-3 sprint-15 stories + 3 ADR amendments) means rerun-4 is at minimum sprint-15 close away.

---

## 5. Required Artifacts: 22/22 Present (lean rerun — no re-audit; substrate stable from rerun-2 except Items 5/6/8 closure)

Lean-mode rerun does NOT re-audit the 21 artifacts validated at rerun-2. Reference: `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-2.md` §5.

**Net-new since rerun-2**:
- `docs/architecture/ADR-0021-production-world-space-rendering-responsibility.md` — Status: Accepted (sprint-14 S14-01)
- `assets/data/maps/mvp_chapter_01.tres` + `scenes/battle/mvp_chapter_01.tscn` + `src/feature/battle_scene/chapter_visuals.gd` — POLISH-010 Option A (sprint-14 S14-02)
- `production/qa/evidence/sprint-14-polish-010-screenshot.png` (44KB user-captured) + `production/qa/evidence/sprint-14-polish-010-evidence.md` (S14-02 deliverable)
- `production/qa/qa-signoff-sprint-8-2026-05-06.md` §S14-03 Re-Attestation section (sprint-14 S14-03 partial)
- `production/polish-backlog.md` POLISH-011 entry + TRIAGE FINDING block (sprint-14 S14-03 + PM late-late triage)
- `.claude/rules/godot-4x-gotchas.md` G-30 entry (sprint-14 S14-06)
- `.claude/docs/director-gates.md` AD-PHASE-GATE + TD-PHASE-GATE production-gate amendments (sprint-14 S14-07)
- `docs/tech-debt-register.md` TD-071 + TD-072 + TD-073 + S14-08 classification matrix (sprint-14 S14-08)

**Pending-NEW** (path-to-PASS rerun-4):
- Sprint-15 dedicated stories S15-A/B/C closing POLISH-011 turn-loop integration gap
- Natural-loop integration test (non-seam) driving full battle to non-DRAW resolution
- Optional: `tools/ci/smoke_battle_loop_windowed.sh` per G-30 mitigation

---

## 6. Path-to-PASS — Consolidated (1 NEW item; rerun-4 minimum scope)

| # | Item | Owner | Tier | Estimated effort |
|---|---|---|---|---|
| 10 | POLISH-011 turn-loop integration gap closure (3 sprint-15 stories: S15-A ADR-0011 §Decision Contract 5 + S15-B AISystem.ai_action_ready subscriber + S15-C player declare_action plumbing) | godot-gdscript-specialist + lead-programmer + technical-director | CRITICAL (release-blocker) | ~10-15h sprint-15 implementation |

**Minimal path to rerun-4 PASS** (chronological):

1. **Sprint-14 close ceremony** (this sprint; pending): /smoke-check + /qa-plan-closure + /team-qa attestation + /retrospective with POLISH-011 carry-condition documented.
2. **Sprint-15 entry**: §11 HARD GATE rebind expected (concentration ≥5 with POLISH-011 occupying protected slot). Plan adopts closure-leaning posture for 2nd consecutive sprint.
3. **Sprint-15 implementation**: 3 stories (S15-A/B/C) closing POLISH-011 turn-loop integration gap. Spans ADR-0011 + ADR-0014 + ADR-0019 amendments. Estimated 10-15h.
4. **Sprint-15 verification**: natural-loop integration test (non-seam) drives full battle to non-DRAW resolution. Closes G-30 verification gap for the turn loop itself.
5. **Sprint-15 user re-attestation**: S8-15 §1.3 input-responsive 3rd attestation (3rd invocation of refusal-to-fabricate posture in S8-15 lifecycle).
6. **Run `/gate-check pre-prod-to-prod` rerun-4**: verdict eligible PASS if 30s windowed smoke session demonstrates ≥1 player-declared action + ≥1 AI-dispatched action without ROUND_CAP DRAW.

Estimated sprint-15 entry-to-rerun-4-PASS: full sprint-15 cycle (~5-7 days). NO same-day rerun-3-to-rerun-4 path exists.

**No alternative**: unlike rerun-2 → rerun-3 (which had Option C deferral ADR available), POLISH-011 has NO acceptable deferral path. The integration gap means production main_scene cannot execute the battle loop — there is no Production stage where this is acceptable. Sprint-15 absorption is the only path.

---

## 7. Chain-of-Verification

**5 challenge questions checked** (per skill Phase 5a FAIL draft template):

1. **Have I accurately separated hard blockers from strong recommendations?** — Yes. POLISH-011 is the SINGLE blocker; all 3 NOT READY directors converge on it. Items 5/6/8/9 are CLOSED; Item 7 is partial only because §1.3 specifically blocks on POLISH-011. There is no over-stating: the 3 directors independently (parallel spawns) concluded NOT READY based on the CRITICAL tier escalation.

2. **Are there any PASS items I was too lenient about?** — No. AD's READY is supported by user-captured visual evidence + Option A clean ship + S14-07 prompt amendment + tier boundary respected throughout. AD's READY is the first in rerun chain history precisely because the substrate finally meets AD's bar.

3. **Am I missing any additional blockers the user should know about?** — Sprint-15 §11 HARD GATE rebind almost certain (concentration ≥5 with POLISH-011). Two consecutive closure-leaning sprints is a watchpoint per PR. Should rerun-4 also include a §11 HARD GATE outcome assessment? Yes — adding that to Item 10 path-to-PASS bullet 2.

4. **Can I provide a minimal path to PASS — the specific 3 things that must change?** — Yes: (a) S15-A `_execute_action_budget` body landed; (b) S15-B AISystem.ai_action_ready subscriber wired; (c) S15-C grid-click MOVE/ATTACK/USE_SKILL/DEFEND → declare_action plumbed. With those 3 wires, the natural battle loop completes; S8-15 §1.3 re-attestation will PASS; rerun-4 verdict eligible.

5. **Is the fail condition resolvable, or does it indicate a deeper design problem?** — Resolvable. ADR-0011 §Decision Contract 5 already specified the design (Callable controller dispatch); the implementation just wasn't completed at story-005 time. S15-A/B/C are wire-up + integration test work, not redesign work. The deeper question (why story-005 closed without the Callable wired) is a sprint-15 retro AI candidate, not a design-problem blocker.

**Verdict**: FAIL (unchanged from draft). 1st verdict downgrade in rerun chain history is honestly priced.

**Chain-of-Verification result**: 5 questions checked — verdict UNCHANGED. Confirmation that 3 director NOT READY verdicts are convergent on a SINGLE root issue (POLISH-011) strengthens confidence that the gate is honestly priced. Q3 surfaced an additional path-to-PASS bullet (sprint-15 §11 HARD GATE outcome assessment) — added to §6.

---

## 8. Recommended Next Steps

**Immediate (this session)**:
1. Commit + push this rerun-3 artifact — preserves the FAIL verdict + path-to-PASS evidence trail for sprint-15 entry context.
2. Sprint-status.yaml: flip S14-04 status:done.
3. Sprint-14 §11 HARD GATE re-evaluation: review sprint-14 plan against new POLISH-011 CRITICAL tier — verdict implications for sprint-14 close ceremony + sprint-15 plan-time §11 HARD GATE rebind expected.

**Sprint-14 close ceremony** (next session candidate):
1. `/smoke-check sprint` → `production/qa/smoke-sprint-14-2026-05-09.md` (PASS expected per current 1288/1288 baseline; closure-mode posture preserved through S14-04 FAIL doc-only outcome).
2. `/qa-plan sprint-14-closure` → closure addendum if any closure-tier stories materially changed since plan-time.
3. `/team-qa sprint-14 attestation-mode` → `production/qa/qa-signoff-sprint-14-2026-05-09.md` — verdict APPROVED WITH CONDITIONS expected (POLISH-011 + S14-05 + S14-09 as carry-conditions to sprint-15).
4. `/retrospective sprint-14` → `production/retrospectives/retro-sprint-14-2026-05-09.md` — must address: 4-of-4 prior items CLOSED (strongest closure ratio); 1st verdict downgrade in rerun chain history; POLISH-011 5-hypothesis miss + triage outcome (retro AI #11/#13); refusal-to-fabricate posture 2nd invocation in S8-15 (retro AI #12); G-30 codification effective + 2→4 invocation escalation within 48hr; AD's 1st READY verdict; PRE-FLIGHT byte-check dogfood ~17× clean (codification stable across S14 work).
5. Sprint-14 close commit + push.
6. `production/sprint-status-history.md` Sprint 14 section archive.

**Sprint-15 entry posture**:
- Plan-time author: 3 stories absorbing POLISH-011 (S15-A/B/C ADR-0011/0014/0019 amendments)
- Carryover concentration audit at sprint-15 plan-time: expected ≥5+ → §11 HARD GATE rebind expected (2nd consecutive)
- Sprint-15 mode: closure-leaning (2nd consecutive)
- S13-06 §7 promotion call carry from S14-05 — user concurrence still pending
- Mid-sprint mode redesignation precedent tracking (S14-09): pattern stability check at sprint-15 close

**`production/stage.txt`**: NOT updated; remains absent (Pre-Production implicit) until rerun-4 PASS verdict.

---

## 9. Cross-References

- Prior rerun: `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-2.md` (path-to-PASS items 5/6/7/8/9 origin context)
- §11 HARD GATE rule: `docs/process/decisions-convention.md` §11.3 Live application table
- POLISH-011 entry + TRIAGE FINDING: `production/polish-backlog.md` (search "POLISH-011")
- POLISH-011 triage commit: `9c249ca` (TRIAGE FINDING amendment 2026-05-09)
- POLISH-010 closure evidence: `production/qa/evidence/sprint-14-polish-010-evidence.md` + `production/qa/evidence/sprint-14-polish-010-screenshot.png`
- ADR-0021: `docs/architecture/ADR-0021-production-world-space-rendering-responsibility.md` (Status: Accepted)
- G-30 codification: `.claude/rules/godot-4x-gotchas.md` G-30 entry (4-invocation pattern stability)
- AD-PHASE-GATE + TD-PHASE-GATE production-gate amendments: `.claude/docs/director-gates.md` (sprint-14 S14-07)
- Sprint-14 plan: `production/sprints/sprint-14.md` (4f2ea2e at sprint-14 entry; MIXED HYBRID closure-leaning per §11 HARD GATE rebind)
- Verification gap pattern siblings: POLISH-008 (ObjectDB leak) / POLISH-010 (visual rendering) — G-30 4-invocation cluster
- Sprint-15 absorption candidate stories: S15-A (ADR-0011 §Decision Contract 5) / S15-B (AISystem.ai_action_ready subscriber) / S15-C (player declare_action plumbing) — to be authored at sprint-15 plan-time
