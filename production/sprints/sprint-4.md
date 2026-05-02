# Sprint 4 — 2026-05-10 to 2026-05-16

> **Review mode**: lean (per `production/review-mode.txt`) — PR-SPRINT director gate skipped
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)
> **Generated**: 2026-05-02
> **Carries**: sprint-3 retrospective (sprint-3 closed 7/7 effectively)

## Sprint Goal

**Begin MVP First Chapter (sprint-4 of 3-sprint arc).** Pivot away from prototype-only validation — both prototypes confirmed the backend math but neither produced a surface a SRPG-experienced user could evaluate. This sprint authors **Camera ADR (ADR-0013) + Grid Battle Controller ADR (ADR-0014)** + asset gathering, setting up the production-quality battle scene that sprint-5+6 will integrate into a playable 장판파 chapter for the first true GO/PIVOT decision.

## Pivot context (from this session, 2026-05-02)

User explicitly answered (post-chapter-prototype playtest):
1. **Motivation**: 10/10 — concept (천명역전: defying tragic fate of Three Kingdoms heroes via tactical formation play) is alive
2. **Genre experience**: deep — has played KOEI 영걸전 extensively; comparison frame in their head already
3. **Self-target**: would play 30+ hours if shipped per concept

The two prior prototypes (`prototypes/vertical-slice/` + `prototypes/chapter-prototype/`) were ColorRect + Label wireframes. SRPG appeal lives in *visual character + animation + BGM + cutscenes*, none of which prototype tooling captures. **Conclusion**: prototype iteration is exhausted as an evaluation tool; only production-grade assets + scene wiring will produce a surface comparable to 영걸전 in the user's head.

The chapter-prototype's `battle_v2.gd` (722 LoC, 4-phase loop, formation/angle/passive math, hidden-fate-condition tracking) and `chapter.gd` (478 LoC, story → party → battle → result orchestration) serve as the **design brief** for sprint-4..6 production code. They are NOT refactored — production code is written from scratch per `/prototype` skill rules.

## Capacity (per retro AI #1 recalibration)

- Total days: **7 calendar → 5 working**
- Buffer (15%): **0.75 day** for unplanned work
- Available: **4.25 working days**

Note: build-from-scratch ADRs (Camera, Grid Battle Controller) use *full* estimate scale per retro AI #1 (no ratification discount).

## Context

Project state as of 2026-05-02 (post-S3-06 + post-prototype pivot):

- **Sprint-3 effectively closed 7/7** (Must-have 3/3 + Should-have 2/2 + Nice-to-have 1/1)
- **All 12 ADRs Accepted**, **11 epics Complete** (Platform 3/3 + Foundation 4/5 + Core 3/4 + Feature 1/13)
- **Full regression**: 743 testcases / 0 errors / 0 failures / 0 orphans (8th consecutive failure-free baseline)
- **Two prototypes shipped** (vertical-slice + chapter-prototype) — both confirmed backend soundness; neither evaluable by user
- **`src/ui/` empty** — first surface this sprint must crack open

After sprint-4 ships, the project will have **(a) Camera production code Complete + (b) Grid Battle Controller stories Ready (impl carries to sprint-5)**, plus an art + audio asset pool that sprint-5 + sprint-6 can wire in.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S4-00 | Sprint-3 retrospective (lean — single doc capturing prototype pivot decision + 1-2 action items) | claude | 0.25 | — | `production/retrospectives/retro-sprint-3-2026-05-02.md` exists; pivot decision documented |
| S4-01 | **ADR-0013 Camera** — `/architecture-decision` Camera2D system: zoom range 0.70-2.00 (F-1 floor from input-handling), drag-to-pan, mouse-wheel zoom, screen↔grid coordinate conversion, no edge-clamp for prototype | claude | 0.5 | — | ADR file Accepted; tr-registry entries; engine compatibility verified against Godot 4.6 Camera2D API |
| S4-02 | Camera epic + stories + implementation: `src/feature/camera/camera_controller.gd` + GameBus integration + `screen_to_grid` function exposed for Grid Battle Controller consumption | claude | 1.5 | S4-01 | Epic Complete; ≥4 stories Complete; full regression PASS; perf < 0.05ms per frame on dev |
| S4-03 | **ADR-0014 Grid Battle Controller** — `/architecture-decision` battle-scoped Node owning unit list + selection state + range computation, delegating math to TurnOrderRunner + HPStatusController + DamageCalc + UnitRole. Formation/angle/passive math from chapter-prototype is the ratified brief | claude | 0.75 | S4-01 | ADR file Accepted; cross-references all 7 backend systems consumed; signal contract via ADR-0001 |
| S4-04 | Grid Battle Controller epic + stories scaffold (8-12 stories estimated; impl deferred to sprint-5 — same epic-decomposition pattern as input-handling S3-04) | claude | 0.75 | S4-03 | Epic file at `production/epics/grid-battle-controller/EPIC.md`; 8-12 stories Ready with TRs/ACs; epics-index.md updated |

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S4-05 | **Asset gathering — hero portraits**: source 8 public-domain or CC-licensed Three Kingdoms hero illustrations (유비/관우/장비/조운/황충/제갈량/조조/여포 minimum) at ≥256×256, organize into `assets/art/heroes/portraits/` with attribution metadata file | claude | 0.5 | — | 8 PNG files in `assets/art/heroes/portraits/` + `ATTRIBUTION.md` listing source + license per file |

### Nice-to-have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S4-06 | BGM candidate gathering — 2-3 free/CC-licensed Three-Kingdoms-mood orchestral or East-Asian instrumental tracks (~3-5min each) into `assets/audio/bgm/candidates/` for sprint-6 selection | claude | 0.25 | — | 2-3 OGG/MP3 files + attribution metadata; sprint-6 picks 1 for first chapter |

## Out of Scope

- **Battle HUD ADR/epic** — deferred to sprint-5 (after Camera + Grid Battle Controller code is real, HUD requirements clarify)
- **Scenario Progression epic** — deferred to sprint-6 (chapter data structure depends on Grid Battle Controller signal shape)
- **Destiny Branch epic** — deferred to sprint-6 (hidden condition tracking depends on event surface from Grid Battle Controller)
- **Real sprite animations** — sprint-6 considers static portraits + simple position tweens; full animation deferred to Polish phase
- **Sound effects integration** — deferred to sprint-6 (BGM gathered this sprint as preparation only)
- **Multiple chapters** — sprint-4..6 ships chapter-1 (장판파) only; data-driven chapter system is post-MVP

## Risks

- **R1**: Camera zoom edge-cases on Godot 4.6 (M4 Pro Metal verified for prototype; production needs cross-resolution test). Mitigation: start with simple zoom range, defer edge-case polish to story-tier.
- **R2**: Grid Battle Controller has 7 backend dependencies — ADR consistency check across 7 prior ADRs is heavy. Mitigation: chapter-prototype already exercised the integration shape; ADR ratifies what works, doesn't redesign.
- **R3**: Public-domain Three Kingdoms art quality varies wildly. Mitigation: accept "good enough" for sprint-4..6; commission proper art is a Polish-tier concern (post first GO decision).
- **R4**: BGM selection is subjective — wasting time picking. Mitigation: ship 2-3 candidates this sprint; choose in sprint-6 *with* the surface they'll play under.
- **R5**: 4.25 working days is tight for 2 ADRs + 1 full epic + 1 epic scaffold + asset gathering. Carry buffer is small. Mitigation: S4-02 Camera implementation is the biggest variable — if it slips, S4-03/S4-04 can carry to sprint-5 (Camera is the gate; Grid Battle Controller ADR can wait one sprint).

## Definition of Done

Sprint-4 is COMPLETE when:
- All Must-have tasks done; full regression remains 0 errors / 0 failures / 0 orphans
- ADR-0013 + ADR-0014 both Accepted (no Proposed lingering)
- Camera epic Complete; `src/feature/camera/camera_controller.gd` exists + tested
- Grid Battle Controller epic Ready with 8-12 stories scaffolded (impl carries to sprint-5)
- `production/epics/index.md` updated: Feature layer 1/13 → 2/13 (camera Complete) + 1 Ready (grid-battle-controller)
- `production/sprint-status.yaml` updated per the 200-byte cap discipline (S3-05 active)
- Hero portrait asset pool gathered (8 files + attribution)
- Sprint-4 retrospective written before sprint-5 kickoff

## Cross-References

- **Pivot trigger**: This conversation 2026-05-02 — user response to chapter-prototype playtest
- **Design briefs (throwaway)**: `prototypes/vertical-slice/` + `prototypes/chapter-prototype/`
- **Production reuse-targets**: TurnOrderRunner + HPStatusController + DamageCalc + HeroDatabase + MapGrid + TerrainEffect + UnitRole + BalanceConstants + GameBus (all Complete in `src/`)
- **Game concept**: `design/gdd/game-concept.md` (MVP Core Hypothesis line 296)
- **Prior sprints**: `production/sprints/sprint-{1,2,3}.md`
