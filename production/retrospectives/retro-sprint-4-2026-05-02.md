# Sprint 4 Retrospective — 2026-05-02

> **Format**: lean (per `production/review-mode.txt`). Single-doc capture.
> **Sprint window**: 2026-05-10 to 2026-05-16 (planned) → effectively closed 2026-05-02 (8 calendar days ahead of deadline)
> **Final state**: 5/7 items done (Must-have 4/4 + Should-have 1/2 + Nice-to-have 0/1)
> **The first sprint with shipped user-visible-surface code** since project began (BattleCamera).

## What shipped

| ID | Item | Outcome |
|---|---|---|
| S4-00 | Sprint-3 retrospective + prototype pivot decision | DONE — pivot doc captures the 2-prototype iteration → MVP First Chapter pivot |
| S4-01 | ADR-0013 Camera | DONE — Accepted; ~280 LoC; godot-specialist 2 BLOCKING revisions resolved (BattleCamera rename + _exit_tree disconnect); 11 registry entries |
| S4-02 | Camera epic + impl | DONE — **first user-visible-surface ship**; BattleCamera ~140 LoC + 14 unit tests + 5 lints + 6 BalanceConstants + 7 stories; 743→757 PASS (9th consecutive failure-free baseline) |
| S4-03 | ADR-0014 Grid Battle Controller | DONE — Accepted MVP-scoped (4 deferral slots reserved); ~510 LoC (largest ADR in project); 2 godot-specialist revisions (DamageCalc static-call drop from DI; CONNECT_DEFERRED on unit_died as load-bearing reentrance prevention); 10 registry entries |
| S4-04 | Grid Battle Controller epic + 10 stories scaffold | DONE — 10 story files + EPIC.md ~250 LoC; impl carries to sprint-5 (~26h estimate) |
| S4-05 | 8 hero portraits gather | DEFERRED — owner reassigned to user (curation requires human taste + license review) |
| S4-06 | 2-3 BGM candidates | DEFERRED — owner reassigned to user (taste-driven; pulled in for sprint-6 chapter scene) |

7 commits pushed, all green:
- `0489dd7` chore(sprint-4): kickoff — sprint-3 retro + sprint-4 plan
- `5f7f5c1` feat(camera): ADR-0013 Camera Accepted
- `ded1aba` feat(grid-battle): ADR-0014 Grid Battle Controller Accepted
- `3c89652` feat(camera): S4-02 — BattleCamera epic Complete
- `db657b5` feat(grid-battle-controller): S4-04 — epic + 10 stories scaffold
- `[this commit]` chore(sprint-4): close-out

## What worked

- **Pivot validated**: sprint-3 retro decision (drop prototype iteration, start production MVP First Chapter) produced its first concrete payoff this sprint — `src/feature/camera/battle_camera.gd` exists. **First time `src/ui/` adjacent code shipped after 11 backend epics.**
- **Engine specialist as TD-ADR substitute (lean mode)**: godot-specialist Pass 1+2+3 review caught **3 BLOCKING revisions across 2 ADRs** (BattleCamera rename + _exit_tree disconnect for ADR-0013; DamageCalc static-call + CONNECT_DEFERRED-load-bearing for ADR-0014). All resolved before commit. Pattern stable at 2 invocations; should be standardized for all future ADRs in lean mode.
- **MVP-scope discipline (ADR-0014 §0)**: faced with grid-battle.md GDD's 1259 lines, explicitly scoped down with 4 deferral slots. Avoided the "800-LoC ADR / 4-6h overrun" trap. Pattern reusable for any future "GDD too large for sprint" situation.
- **Cross-ADR audit during ADR authoring**: ADR-0014's Implementation Notes section flagged 3 fresh-from-shipped-code findings before any story author hits them (apply_damage 4-param; is_alive canonical; HPStatusController._exit_tree already exists = TD-057 partial false alarm). Saved sprint-5 implementation time.
- **Single-session epic-terminal commit, again**: camera epic shipped 7 stories in one commit (`3c89652`) at 757 PASS. 4th invocation of the pattern (turn-order + hp-status + (recovered) hp-status epic-bundle + camera). Stable.
- **Cap discipline (S3-05) held**: every commit kept sprint-status.yaml ≤200 bytes per line; awk gate verified post-update each time.

## What didn't work

- **Estimate vs actual diverged 3-4×**: planned 5 working days of work shipped in 1 calendar day (single session). Same as sprint-3 (5d planned / 1d actual). Retro AI #1 recalibration is **still not tight enough** — sprint plans should target 1-2 working days, not 5.
- **Asset gathering wasn't suited for the agent**: S4-05 + S4-06 were originally agent-owned. Closer inspection: image curation and BGM selection are *taste-driven and license-review-driven*, both human-eye work. Agent-as-curator was a mis-allocation. Fix: future asset gathering tasks default to user-owner.
- **Story scaffolding overhead is heavy**: S4-04 grid-battle-controller scaffold = 10 story files × 80-200 LoC each = ~2000 LoC of pre-implementation authoring. While valuable as a brief, the question "is this scaffold worth the writing time vs. just letting story-001 read the ADR fresh?" is open. Decision deferred to sprint-5: if implementing grid-battle-controller goes smoothly using the scaffold, pattern is validated; if scaffold turns out to be ignored noise, pattern needs revisiting.

## The big-picture win this sprint

**Sprint-4 was the inflection point**: 3 sprints of pure backend (no `src/ui/`, no playable surface, 11 epics shipped to silence) followed by 1 prototype iteration that confirmed the wireframe scope was wrong, followed by sprint-4 which **finally produced production code that BattleScene can mount**. The "playable-surface delta" metric from retro AI #1 = +1 — the first +1 since project began.

**Sprint-5 is poised to be the second +1 (or +2)**: GridBattleController implementation (10 stories, ~26h) + Battle HUD ADR + scaffold. Sprint-6 = Battle Scene + first chapter playable.

## Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | **Tighten estimation further** (continued retro AI #1) — sprint-5 plans for 2 working days max. If shipped in 1 day, sprint-6 plans for 1 day. Eventually converge on actual velocity. | claude (sprint-5 plan) | High | sprint-5 kickoff |
| 2 | **Asset gathering (S4-05 + S4-06) to user before sprint-6 begins** — user collects 8 hero portraits + 2-3 BGM tracks in any spare 1-2h window between sprint-5 and sprint-6. Stash at `assets/art/heroes/portraits/` + `assets/audio/bgm/candidates/`. Sprint-6 wires them into Battle Scene. | user | Medium | sprint-6 kickoff |
| 3 | **Standardize godot-specialist review as TD-ADR substitute** in lean mode for ALL future ADRs. Pattern stable at 2 invocations (ADR-0013 + ADR-0014); 3-pass format (API correctness / architectural fit / risks missed) catches blocking issues before commit. Update `/architecture-decision` skill to make this explicit. | claude (skill amendment, opportunistic) | Medium | next time /architecture-decision invoked |
| 4 | **Sprint-5 plan**: implement grid-battle-controller epic (S5-01 = qa-plan; S5-02..S5-11 = stories 001..010 implementation) + author Battle HUD ADR (S5-12) + scaffold Battle HUD epic (S5-13). Test target: 757 → ~785 PASS. | claude (sprint-5 plan) | Critical | sprint-5 first commit |

## Snapshot

- **Sprint 1**: Platform 3/3 + Foundation 1/5 + 1 carry test
- **Sprint 2**: Foundation 4/5 + Core 1/4 + bonus turn-order full impl
- **Sprint 3**: Foundation 4/5 + Core 3/4 + Foundation 1/5 input-handling Ready scaffold + 2 prototypes shipped + pivot to MVP First Chapter
- **Sprint 4**: ADR-0013 Camera + ADR-0014 Grid Battle Controller + camera Feature epic Complete (+1 playable-surface delta) + grid-battle-controller 10-story scaffold
- **Sprint 5 ahead**: grid-battle-controller implementation (10 stories) + Battle HUD ADR + scaffold

## Cross-References

- Sprint plan: `production/sprints/sprint-4.md`
- Pivot trigger conversation: 2026-05-02 session (post-S3-06)
- Camera epic: `production/epics/camera/EPIC.md`
- Grid Battle Controller epic: `production/epics/grid-battle-controller/EPIC.md`
- ADR-0013 Camera: `docs/architecture/ADR-0013-camera.md`
- ADR-0014 Grid Battle Controller: `docs/architecture/ADR-0014-grid-battle-controller.md`
- Sprint-status history: `production/sprint-status-history.md` (S4-01 + S4-02 + S4-03 + S4-04 archived)
