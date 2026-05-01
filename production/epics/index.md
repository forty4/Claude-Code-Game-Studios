# Epics Index

> **Last Updated**: 2026-05-01 (Sprint 2 S2-08 DONE — turn-order Core epic 7/7 stories Ready; prior S2-04 hero-database epic Complete 5/5 + S2-05 admin + S2-06 turn-order GDD revision)
> **Engine**: Godot 4.6
> **Manifest Version**: 2026-04-20 (docs/architecture/control-manifest.md)
> **Layer coverage**: Platform (3/3 epics Complete 🎉) + Foundation (**4/5 epics Complete** — map-grid + unit-role + balance-data + hero-database 🎉) + Core (1/4 epics Complete + **1 Ready** — terrain-effect Complete 🎉; turn-order Ready 2026-05-01) + **Feature (1/13 epics Complete — damage-calc Complete 2026-04-27 🎉)**
>
> **Note**: All 12 ADRs reached Accepted on 2026-04-30 (commit `2fa178b`). hp-status / turn-order / input-handling Pending entries below now have Accepted ADRs and will graduate to Ready as their epics are scaffolded across Sprint 2 (S2-07 hp-status, S2-08 turn-order, S2-09 input-handling).

## Epics

| Epic | Layer | System | GDD | Governing ADRs | Stories | Status |
|------|-------|--------|-----|----------------|---------|--------|
| [gamebus](gamebus/EPIC.md) | Platform | GameBus autoload | — (ADR-0001 authoritative) | ADR-0001 | 9/9 Complete | **Complete** (2026-04-21) 🎉 |
| [scene-manager](scene-manager/EPIC.md) | Platform | SceneManager autoload | — (ADR-0002 authoritative) | ADR-0002, ADR-0001 | 7/7 Complete (story-007 V-7/V-8 on-device portions deferred to Polish per Sprint 1 R3) | **Complete** (2026-04-26) 🎉 |
| [save-manager](save-manager/EPIC.md) | Platform | SaveManager autoload | — (ADR-0003 authoritative) | ADR-0003, ADR-0001, ADR-0002 | 8/8 Complete | **Complete** (2026-04-24) 🎉 |
| [map-grid](map-grid/EPIC.md) | Foundation | Map/Grid System (#14) | design/gdd/map-grid.md | ADR-0004, ADR-0001, ADR-0002, ADR-0003 | 8/8 Complete | **Complete** (2026-04-25) 🎉 |
| [terrain-effect](terrain-effect/EPIC.md) | Core | Terrain Effect System (#2) | design/gdd/terrain-effect.md | ADR-0008, ADR-0004 (+§5b), ADR-0001 | 8/8 Complete | **Complete** (2026-04-26) 🎉 |
| [damage-calc](damage-calc/EPIC.md) | Feature | Damage Calc System (#11) | design/gdd/damage-calc.md (rev 2.9.3) | ADR-0012, ADR-0001, ADR-0008 | Not yet created — run `/create-stories damage-calc` | **Ready** (2026-04-26) — first Feature-layer epic |
| [unit-role](unit-role/EPIC.md) | Foundation | Unit Role System (#5) | design/gdd/unit-role.md | ADR-0009, ADR-0001, ADR-0006, ADR-0008 | **10/10 Complete** 🎉 (all stories done 2026-04-28) | **Complete** (2026-04-28) 🎉 — Foundation epic shipped: 6 derived-stat methods + cost matrix + direction multiplier + passive tags const + 8-cap balance append + 2 cross-epic integrations + lint + perf baseline; **501/501 full-suite green** |
| [balance-data](balance-data/EPIC.md) | Foundation | Balance/Data System (#26) | design/gdd/balance-data.md | ADR-0006, ADR-0001 | **5/5 Complete** 🎉 (all stories done 2026-05-01) | **Complete** (2026-05-01) 🎉 — ratification epic shipped: Foundation-layer relocation + TR-traced test suite + lint template + perf baseline + orphan-grep gate; 20/20 TRs traced (7 COVERED + 13 Alpha-deferred BY DESIGN); **506/506 full-suite green** |
| [hero-database](hero-database/EPIC.md) | Foundation | Hero Database (#25) | design/gdd/hero-database.md | ADR-0007, ADR-0001, ADR-0006, ADR-0009 | **5/5 Complete** 🎉 (all stories done 2026-05-01) | **Complete** (2026-05-01) 🎉 — build-from-scratch epic shipped: HeroDatabase 459 LoC + 6 query API + 3-pass validation pipeline (FATAL CR-1/CR-2/EC-1/EC-2 + WARNING EC-4/5/6) + 9-record MVP roster heroes.json (4-faction × 4-dominant-stat + Peach Garden Oath bond) + perf baseline (143 LoC test) + non-emitter+G-15 lint + Polish-tier validation lint scaffold (TD-044 + TD-045 reactivation triggers); 15/15 TRs traced (11 MVP-runtime + TR-011 Polish-deferred via §11+N2 + TR-015 100-hero forward-compat extrapolation deferred); **564/564 full-suite green** (1 carried orthogonal failure from story-001 baseline) |
| [turn-order](turn-order/EPIC.md) | Core | Turn Order/Action Management (#13) | design/gdd/turn-order.md (Accepted via ADR-0011 2026-04-30; Contract 5 layer-invariant resolution prose added 2026-05-01 via S2-06) | ADR-0011, ADR-0001, ADR-0002, ADR-0006, ADR-0007, ADR-0009, ADR-0010 | **7/7 created** (2026-05-01 via /create-stories) | **Ready** (2026-05-01) — battle-scoped Node form epic (3rd Core-layer Node after InputRouter + HPStatusController); 22/22 TRs traced + 23/23 GDD ACs assigned (4 cross-system Integration ACs deferred via TD-047 to Vertical Slice once HP/Status + Damage Calc + Grid Battle ship); 0 untraced; LOW engine risk; 7-story decomposition: story-001 module skeleton + story-002 initialize_battle/F-1 cascade + story-003 _advance_turn T1-T7 + story-004 declare_action + story-005 death-handling/CR-7d/Charge-F-2 (Integration) + story-006 victory detection (AC-18/AC-22 precedence) + story-007 epic terminal (perf+lints+G-15+TD entries); ~18-24h estimated total |

## Pending (blocked on ADR)

These systems have approved GDDs but no ADR yet. Epic creation is deferred until the governing ADR is Accepted, per project pattern (no speculative EPIC.md content that would drift from eventual ADR decisions).

### Foundation layer (1 pending — balance-data + hero-database graduated to Complete 2026-05-01)

| Pending Epic | Layer | System | GDD | Blocked on | Engine Risk |
|--------------|-------|--------|-----|------------|-------------|
| input-handling | Foundation | Input Handling System (#29) | design/gdd/input-handling.md | ~~ADR-0005~~ Accepted 2026-04-30 — Sprint 2 S2-09 will scaffold | **HIGH** (dual-focus 4.6, SDL3, Android edge-to-edge) |

### Core layer (1 pending — terrain-effect graduated to Ready 2026-04-25 + Complete 2026-04-26; unit-role reclassified to Foundation per ADR-0009 §Engine Compatibility 2026-04-28; turn-order graduated to Ready via /create-epics 2026-05-01 S2-08)

| Pending Epic | Layer | System | GDD | Blocked on | TR Registry | Notes |
|--------------|-------|--------|-----|------------|-------------|-------|
| hp-status | Core | HP/Status System (#12) | design/gdd/hp-status.md (Designed) | **ADR-0010** (status-effect stacking contract) | ⚠ partial (TR-hp-status-001 only) | Single authoritative emitter of `unit_died` per ADR-0001; needs TR registry expansion to cover DoT/heal/morale pipelines |
| ~~turn-order~~ — **graduated to Epics table 2026-05-01 via S2-08** (`/create-epics turn-order`); 22/22 TRs traced; preview ~6-7 stories | | | | | | |

### Deferred to Vertical Slice tier

| System | Layer | GDD Status | Notes |
|--------|-------|-----------|-------|
| Save/Load (#17) | Core | **Not Started** (GDD pending) | Schema spec (what is saved); save-manager Platform epic already covers infra (how it's saved). VS tier — author GDD before creating Core epic. |

## Implementation Order (historical — all 5 listed epics are now Complete or in flight)

Per architecture.md layer invariants (Platform → Foundation → Core → ...), the 5 ready epics shipped in this dependency order:

1. **GameBus** — Complete 2026-04-21 (PR #9 closure). Unblocked stub-injectable test infrastructure for all downstream epics.
2. **SaveManager** — Complete 2026-04-24 (8/8 stories). Built on GameBus stub pattern.
3. **Map/Grid** — Complete 2026-04-25 (8/8 stories; PRs #26-#30). Foundation layer.
4. **SceneManager** — Complete 2026-04-26 (7/7 stories; story-007 closed via Polish-deferral pattern per Sprint 1 R3 — desktop-verifiable portions PASS, V-7/V-8 on-device portions deferred to Polish phase with documented reactivation trigger).
5. **Terrain Effect** — Complete 2026-04-26 (8/8 stories; PR #43 closure). First Core-layer epic; consumes ADR-0004 §5b constants.

## Dependency Snapshot

```
  GameBus (Platform, ADR-0001) ✅ Complete 2026-04-21
      │
      ▼
  SceneManager (Platform, ADR-0002) ✅ Complete 2026-04-26 (Polish-deferral on V-7/V-8)
      │
      ▼
  SaveManager (Platform, ADR-0003) ✅ Complete 2026-04-24
      │
      ▼
  Map/Grid (Foundation, ADR-0004 + §5b erratum) ✅ Complete 2026-04-25
      │
      ▼
  Terrain Effect (Core, ADR-0008) ✅ Complete 2026-04-26
      │
      ▼
  Damage Calc (Feature, ADR-0012) ⚠ Ready 2026-04-26 — stories not yet created
      │ (soft-depends on unwritten ADR-0006/0009/0010/0011 via provisional-dependency strategy)
      └─ next: /create-stories damage-calc (Sprint 1 S1-05 cont.)
```

All 6 epics traced to 1+ Accepted ADR with full TR coverage. No untraced requirements.

## Next Steps (Sprint 1 — 2026-04-26 → 2026-05-10)

See `production/sprints/sprint-1.md` for the active sprint plan. Highlights:

- **S1-01**: ✅ Closed scene-manager story-007 via Polish-deferral pattern (4th invocation of pattern; precedents: save-manager/story-007 + map-grid/story-007). SceneManager epic graduated to Complete 2026-04-26 — desktop-verifiable portions PASS; V-7/V-8 on-device portions deferred to Polish per Sprint 1 R3.
- **S1-02**: ✅ Admin pass (Status field flips on the 4 Complete epics) — done 2026-04-26.
- **S1-03**: ✅ Authored **ADR-0012 Damage Calc** from rev 2.9.3 GDD → `/architecture-decision damage-calc` (PR #46 merged 2026-04-26).
- **S1-04**: ✅ `/architecture-review` ADR-0012 delta → **Accepted** (PR #48 merged 2026-04-26; APPROVED WITH SUGGESTIONS, 2 wording corrections + 1 advisory).
- **S1-05**: ✅ Partially complete — `/create-epics damage-calc` written 2026-04-26 (this entry); next: `/create-stories damage-calc` (first Feature-layer epic story decomposition).
- **S1-06/07** (Should-Have): Author ADR-0009 Unit Role → `/architecture-review` → Accepted (unblocks unit-role + populates terrain-effect cost_matrix).
- **S1-09** (Nice-to-Have): Author ADR-0006 Balance/Data (FileAccess 4.4 — MEDIUM engine risk).

### Outstanding ADRs (post-Sprint-1 priority)

- **ADR-0005** Input Handling (HIGH engine risk — dual-focus 4.6 + SDL3 + Android edge-to-edge) → unblocks input-handling Foundation epic.
- **ADR-0007** Hero Database (LOW risk; schema decision primarily) → unblocks hero-database Foundation epic.
- **ADR-0010** HP/Status (status-effect stacking contract) → unblocks hp-status Core epic.
- **ADR-0011** Turn Order signal-inversion (resolves architecture.md §1 invariant-#4 blocker; GDD `turn-order.md` revision required first) → unblocks turn-order Core epic.

After each ADR is Accepted: run `/create-epics layer: <layer>` to scaffold the corresponding EPIC.md file (the index Pending entry below will graduate to the "Epics" table).

## Gate Readiness

Pre-Production → Production gate FAIL (re-checked 2026-04-25 — see `production/qa/qa-signoff-map-grid-2026-04-25.md` + smoke-2026-04-25.md). Map-grid epic close-out is APPROVED WITH CONDITIONS but does not by itself advance the project stage — Vertical Slice + Core layer + playtest data remain outstanding.

Current gate blockers (post-2026-04-25 update):

- ~~Epics in `production/epics/` (Foundation + Core layer epics present)~~ ✅ **Partial** — 4/7 Foundation+Platform epics present; **1/5 Core-layer epics present (terrain-effect, 2026-04-25)**; **1/13 Feature-layer epics present (damage-calc Ready 2026-04-26)**; 3 Core epics blocked on ADR-0009/0010/0011
- ❌ Vertical Slice build — does not exist (no main scene wired up; queries are Foundation-only)
- ❌ ≥3 Vertical Slice playtests — `production/playtests/` directory missing
- ❌ Sprint plan in `production/sprints/` — directory missing
- ❌ Core + Feature ADRs — 3 Core ADRs (0009..0011) + Feature ADRs (Grid Battle, Damage Calc, AI, etc.) not yet written

## Changelog

| Date | Change |
|------|--------|
| 2026-04-20 | Initial index. 4 epics created: gamebus, scene-manager, save-manager, map-grid. 3 Foundation-layer epics (input-handling, balance-data, hero-database) deferred pending ADR-0005/0006/0007 authoring. |
| 2026-04-25 | Map-grid epic close-out (8/8 stories Complete; PRs #26-#30 pending merge). 4 Core-layer pending entries added (terrain-effect, unit-role, hp-status, turn-order) — all blocked on ADR-0008..0011 + TR registry expansion (terrain-effect, unit-role have no TR-IDs registered). Save/Load (#17) deferred to VS tier (GDD doesn't exist; save-manager Platform epic already covers infra). Gate readiness re-checked: still FAIL (Vertical Slice + playtest + Core ADRs outstanding). |
| 2026-04-25 | terrain-effect epic created (Core layer, governed by ADR-0008 Accepted same day via `/architecture-review` delta + concurrent ADR-0004 §5b erratum). 18 TR-terrain-effect-* registered in tr-registry v4. terrain-effect graduates from Pending to Ready; remaining 3 Core-layer Pending entries (unit-role / hp-status / turn-order) still blocked on missing ADRs. |
| 2026-04-26 | **Sprint 1 S1-02 admin pass** — flip stale Status fields on 4 fully-Complete epics that were still labeled Ready: gamebus (Complete 2026-04-21, 9/9), save-manager (Complete 2026-04-24, 8/8), map-grid (Complete 2026-04-25, 8/8), terrain-effect (Complete 2026-04-26, 8/8 — already flipped in own EPIC.md via /story-done; index sync only). 33/33 cumulative stories shipped across these 4 epics; 4 PRs in Sprint 0 close-out window. scene-manager remains Ready (6/7; story-007 is Sprint 1 S1-01). No content changes — admin labels only. |
| 2026-04-26 | **Sprint 1 S1-01 close-out** — scene-manager story-007 (target-device verification) closed via Polish-deferral pattern (4th invocation; precedents: save-manager/story-007 2026-04-24, map-grid/story-007 2026-04-25). Desktop-verifiable portions PASS (AC-5 CONNECT_DEFERRED ordering test 3/3 PASSED 0 errors / 0 failures / 0 orphans / exit 0; AC-4 async load partial-substitute observably non-blocking on macOS). V-7/V-8 on-device portions explicitly deferred to Polish per Sprint 1 R3 mitigation with documented reactivation trigger ("when first Android export build is green AND Snapdragon 7-gen device available"); estimated Polish-phase effort 3-4h. V-7 fallback (per-Control mouse_filter recursive walk per ADR-0002 §Neutral Consequences) ready-to-ship in evidence doc §D if Polish-phase AC-1 detects need. **Scene-manager epic graduates to Complete (2026-04-26) — 7/7 stories done 🎉**. **All 5 Platform/Foundation/Core epics now Complete** (gamebus + scene-manager + save-manager + map-grid + terrain-effect = 41/41 cumulative stories shipped). |
| 2026-04-26 | **Sprint 1 S1-04 close-out** — `/architecture-review` delta promoted ADR-0012 Damage Calc Proposed → Accepted (PR #48 merged). godot-specialist context-isolated validation APPROVED WITH SUGGESTIONS (12/12 engine claims PASS; 2 wording corrections AF-1+Item 3 applied pre-acceptance; 1 advisory AF-3 carried). 13 architectural TRs registered (TR-damage-calc-001..013); tr-registry.yaml v4 → v5; architecture-traceability.md v0.3 → v0.4 (48 → 61 registered TRs). Project: 5 → **6 Accepted ADRs** (4 Foundation + 1 Core + **1 Feature** — first Feature-layer ADR). Provisional-dependency strategy proven 2 invocations (ADR-0008→ADR-0006 + ADR-0012→ADR-0006/0009/0010/0011). 4 advisories carried non-blocking: ADV-1 int↔StringName direction encoding (defer to Grid Battle ADR), ADV-2 in-operator O(n) at MVP scale, ADV-3 DataRegistry cast safety, ADV-4 R-8 floating-point cross-platform 1 ULP residue. |
| 2026-04-26 | **Sprint 1 S1-05 (partial) — damage-calc Feature epic created** (governed by ADR-0012 Accepted same day). First Feature-layer epic in the project. 13 TRs covered 100% by ADR-0012; 0 untraced requirements. Soft dependencies on unwritten ADR-0006/0009/0010/0011 acknowledged via provisional-dependency strategy with API-stable workaround patterns documented (direct entities.yaml read; locally-defined direction multiplier const tables; stub interface contracts in test fixtures). Status flips: Feature layer 0/13 → 1/13 (damage-calc Ready); preview story decomposition lists ~8-10 stories with story-001 = CI infrastructure prerequisite (gates story-002+). Next: `/create-stories damage-calc`. |
| 2026-04-30 | **Sprint 2 S2-01 — balance-data Foundation epic created** (governed by ADR-0006 Accepted same day via /architecture-review delta #9, commit `2fa178b`). First Sprint-2 epic. **Ratification epic** for the MVP `BalanceConstants` wrapper shipped in damage-calc story-006b PR #65 (2026-04-27); same-patch obligations from delta #9 already complete (file rename, const path update, data-files.md exception, ADR-0008/0012 cross-refs, architecture.yaml ratification). 20 TRs registered (TR-balance-data-001..020) — 7 COVERED + 13 Alpha-deferred BY DESIGN per ADR-0006 §7 (CR-2/3/4/5/6/8/9 reactivate when future Alpha-tier "DataRegistry Pipeline" ADR is authored); 0 untraced. Status flips: Foundation 2/5 Complete → 2/5 Complete + 1 Ready (balance-data); Pending list 3 → 2 (input-handling, hero-database; both ADRs Accepted but epic-scaffolding deferred to S2-02/S2-09). Engine Risk: LOW. Residual epic scope: Foundation-layer relocation (`src/feature/balance/` → `src/foundation/balance/`), TR-traced test suite, perf baseline, per-system lint template, TD-041 logged, orphan-reference grep gate. Next: `/create-stories balance-data`. |
| 2026-05-01 | **Sprint 2 S2-02 — hero-database Foundation epic created** (governed by ADR-0007 Accepted 2026-04-30). 15 TRs registered (TR-hero-database-001..015); 100% traced to ADR-0007; 0 untraced. **Build-from-scratch epic with §Migration Plan §1 head-start** — provisional `src/foundation/hero_data.gd` 26-field shape + "Ratified by ADR-0007" header shipped 2026-04-30 same-patch with ADR-0007 acceptance; remaining residual scope: `hero_database.gd` (~300 LoC, 6 static query methods + lazy-init + per-record validation pipeline), `assets/data/heroes/heroes.json` (8-10 MVP records, 4-faction coverage), `tests/unit/foundation/hero_database*.gd` (validation severity + R-1 consumer-mutation regression + perf baseline), Polish-tier `tools/ci/lint_hero_database_validation.sh` scaffold (F-1..F-4 thresholds Polish-deferred per ADR-0007 §11 + N2 — 5-precedent pattern). 5th-precedent stateless-static utility class pattern (ADR-0008 → 0006 → 0012 → 0009 → 0007). Engine Risk: LOW (no post-cutoff API; Dictionary[StringName, HeroData] / Array[StringName] / Resource.duplicate_deep all 4.4-4.5+ stable). Status flips: Foundation 3/5 Complete (balance-data closed 2026-05-01) + 1 Ready (hero-database); Pending list 2 → 1 (input-handling only). Sprint 2 must-have load advances 2/5 → 3/5 (S2-01 + S2-02 + S2-03 done). Next: `/create-stories hero-database`. |
| 2026-05-01 | **Sprint 2 S2-03 close-out — balance-data epic Complete (5/5 stories)**. story-001 Foundation-layer relocation + story-002 TR-traced test suite + story-003 lint template + story-005 perf baseline + story-004 orphan-grep validation audit (epic terminal step) — all closed via `/story-done`. 506/506 full-suite green; 1 orthogonal pre-existing failure (test_hero_data_doc_comment_contains_required_strings) carried forward. Status flips: Foundation 2/5 Complete + 1 Ready → **3/5 Complete** (balance-data 🎉). Sprint 2 progress: 2/5 must-have done → ready for S2-02 + S2-04 hero-database track. |
| 2026-05-01 | **Sprint 2 S2-04 close-out — hero-database epic Complete (5/5 stories) + S2-05 admin pass**. story-001 module skeleton + 6 query API + lazy-init + story-002 validation pipeline FATAL (CR-1+CR-2+EC-1+EC-2 with 4 validator helpers + `_load_heroes_from_dict` test seam) + story-003 9-record MVP roster authoring (4-faction × 4-dominant-stat coverage + Three-Brothers Peach Garden Oath bond) + happy-path integration test + story-004 WARNING tier (EC-4 self-ref / EC-5 orphan FK / EC-6 asymmetric conflict) via Pass 3 wiring + 3 helpers + R-1 consumer-mutation regression test (proves convention-as-sole-defense per §5 duplicate_deep rejection) + story-005 perf baseline (143 LoC test, 4 perf tests at ×3-25 generous gates) + non-emitter+G-15 isolation lint (dual-pattern regex matching reflective set() form) + Polish-tier validation lint scaffold (TD-044 6-key reactivation triggers + TD-045 100-hero/100ms on-device benchmark) — all closed via `/story-done`. **506→564 full-suite green** across stories 001-005 (1 orthogonal pre-existing carried failure from story-001 baseline; not introduced by hero-database epic). Status flips: Foundation 3/5 Complete + 1 Ready → **4/5 Complete** (hero-database 🎉). hero-database EPIC.md Status `Ready` → `Complete`; sprint-status.yaml S2-04 `backlog` → `done`. Sprint 2 must-have advances 3/5 → 4/5 (~80% must-have burndown at ~15% time elapsed). 4 TD entries logged across stories 003 + 005 (TD-042 data-files.md Entity Data File Exception + TD-043 raw-JSON dedup E2E gap + TD-044 + TD-045). Next: S2-05 minimal admin pass complete (this entry); deeper post-sprint-1 layer refresh (Implementation Order historical list, Outstanding ADRs section now-stale since all 12 ADRs Accepted 2026-04-30, Next Steps Sprint 1 → Sprint 2 rewrite, Gate Readiness re-check) deferred to dedicated follow-up story. |
| 2026-05-01 | **Sprint 2 S2-06 close-out + S2-08 turn-order Core epic created**. S2-06 (turn-order GDD revision should-have): Contract 5 §Layer-invariant resolution prose added (~50 lines) explaining ADR-0011 §Why-this-form Callable-delegation rationale — Turn Order depends on generic Callable abstraction (Godot built-in primitive); zero AI System symbol references; Battle Preparation injects per-unit controller Callable at BI-1; signal-inversion explicitly evaluated + rejected per ADR-0011 §Alternatives Considered. S2-08 (`/create-epics turn-order`): turn-order Core epic created (3rd battle-scoped Node form after InputRouter + HPStatusController; 22/22 TRs traced TR-turn-order-001..022 to ADR-0011 + 6 supporting ADRs ADR-0001/0002/0006/0007/0009/0010; 0 untraced; LOW engine risk — Callable + CONNECT_DEFERRED + typed Dictionary all 4.x stable). Story decomposition preview ~6-7 stories spanning module skeleton + initialize_battle/F-1 cascade + T1-T7 sequence + declare_action + death-handling/CR-7d + victory detection + perf+lint+TD epic terminal (~18-24h estimated; comparable to hero-database/damage-calc precedent). Status flips: Core 1/4 Complete → 1/4 Complete + 1 Ready (turn-order); Pending list 2 → 1 (hp-status remaining). Sprint 2 must-have 5/5 + 2 should-have done (S2-06 + S2-08); 2 should-have remaining (S2-07 hp-status + S2-09 input-handling); ~15% time elapsed; ~50% should-have burndown. Next: `/create-stories turn-order` to expand the epic into implementable stories. |
| 2026-04-28 | **Sprint 1 S1-07 close-out — unit-role Foundation epic created** (governed by ADR-0009 Accepted same day via /architecture-review delta-mode). Layer reclassified Core → Foundation per ADR-0009 §Engine Compatibility "Foundation — stateless gameplay rules calculator" (the prior Pending entry preceded ADR-0009 authoring). 12 TRs covered 100% by ADR-0009 + ADR-0006 + ADR-0001 + ADR-0008 (TR-unit-role-001..012); 0 untraced requirements. Ratifies ADR-0008 cost-matrix unit-class dim placeholder + ADR-0012 CLASS_DIRECTION_MULT[6][3]. Soft-dep on unwritten ADR-0007 Hero DB (provisional `src/foundation/hero_data.gd` wrapper, parameter-stable migration; provisional-dependency strategy proven 3 invocations). Status flips: Foundation 1/4 → 1/5 + 1 Ready (unit-role); Core 1/5 → 1/4 (unit-role removed from Core pending). Preview story decomposition lists ~10 stories. Next: `/create-stories unit-role`. Sprint-1 reconciliation now COMPLETE (10/10 + DoD 12/12 + S1-07 ADR-0009 acceptance + S1-07 epic creation). |
