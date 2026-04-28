# Epics Index

> **Last Updated**: 2026-04-28
> **Engine**: Godot 4.6
> **Manifest Version**: 2026-04-20 (docs/architecture/control-manifest.md)
> **Layer coverage**: Platform (3/3 epics Complete 🎉) + Foundation (1/5 epics Complete + **1/5 Ready — unit-role**; 3 blocked on ADR-0005/0006/0007) + Core (1/4 epics Complete — 2 blocked on ADR-0010/0011 + 1 deferred to VS; unit-role reclassified to Foundation per ADR-0009 §Engine Compatibility 2026-04-28) + **Feature (1/13 epics Ready — damage-calc Sprint 1 S1-05)**

## Epics

| Epic | Layer | System | GDD | Governing ADRs | Stories | Status |
|------|-------|--------|-----|----------------|---------|--------|
| [gamebus](gamebus/EPIC.md) | Platform | GameBus autoload | — (ADR-0001 authoritative) | ADR-0001 | 9/9 Complete | **Complete** (2026-04-21) 🎉 |
| [scene-manager](scene-manager/EPIC.md) | Platform | SceneManager autoload | — (ADR-0002 authoritative) | ADR-0002, ADR-0001 | 7/7 Complete (story-007 V-7/V-8 on-device portions deferred to Polish per Sprint 1 R3) | **Complete** (2026-04-26) 🎉 |
| [save-manager](save-manager/EPIC.md) | Platform | SaveManager autoload | — (ADR-0003 authoritative) | ADR-0003, ADR-0001, ADR-0002 | 8/8 Complete | **Complete** (2026-04-24) 🎉 |
| [map-grid](map-grid/EPIC.md) | Foundation | Map/Grid System (#14) | design/gdd/map-grid.md | ADR-0004, ADR-0001, ADR-0002, ADR-0003 | 8/8 Complete | **Complete** (2026-04-25) 🎉 |
| [terrain-effect](terrain-effect/EPIC.md) | Core | Terrain Effect System (#2) | design/gdd/terrain-effect.md | ADR-0008, ADR-0004 (+§5b), ADR-0001 | 8/8 Complete | **Complete** (2026-04-26) 🎉 |
| [damage-calc](damage-calc/EPIC.md) | Feature | Damage Calc System (#11) | design/gdd/damage-calc.md (rev 2.9.3) | ADR-0012, ADR-0001, ADR-0008 | Not yet created — run `/create-stories damage-calc` | **Ready** (2026-04-26) — first Feature-layer epic |
| [unit-role](unit-role/EPIC.md) | Foundation | Unit Role System (#5) | design/gdd/unit-role.md | ADR-0009, ADR-0001, ADR-0006, ADR-0008 | Not yet created — run `/create-stories unit-role` | **Ready** (2026-04-28) — Sprint 1 S1-07 close-out |

## Pending (blocked on ADR)

These systems have approved GDDs but no ADR yet. Epic creation is deferred until the governing ADR is Accepted, per project pattern (no speculative EPIC.md content that would drift from eventual ADR decisions).

### Foundation layer (3 pending)

| Pending Epic | Layer | System | GDD | Blocked on | Engine Risk |
|--------------|-------|--------|-----|------------|-------------|
| input-handling | Foundation | Input Handling System (#29) | design/gdd/input-handling.md | ADR-0005 | **HIGH** (dual-focus 4.6, SDL3, Android edge-to-edge) |
| balance-data | Foundation | Balance/Data System (#26) | design/gdd/balance-data.md | ADR-0006 | MEDIUM (FileAccess 4.4) |
| hero-database | Foundation | Hero Database (#25) | design/gdd/hero-database.md | ADR-0007 | LOW |

### Core layer (2 pending — terrain-effect graduated to Ready 2026-04-25; unit-role reclassified to Foundation per ADR-0009 §Engine Compatibility 2026-04-28)

| Pending Epic | Layer | System | GDD | Blocked on | TR Registry | Notes |
|--------------|-------|--------|-----|------------|-------------|-------|
| hp-status | Core | HP/Status System (#12) | design/gdd/hp-status.md (Designed) | **ADR-0010** (status-effect stacking contract) | ⚠ partial (TR-hp-status-001 only) | Single authoritative emitter of `unit_died` per ADR-0001; needs TR registry expansion to cover DoT/heal/morale pipelines |
| turn-order | Core | Turn Order/Action Management (#13) | design/gdd/turn-order.md (**Needs Revision**) | **ADR-0011** (AI-inversion signal contract) + GDD revision | ⚠ partial (TR-turn-order-001 only) | Architecture.md §1 blocker: GDD `turn-order.md:442` direct call into AI (Feature) violates invariant #4 — must invert to GameBus signal pattern |

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
| 2026-04-28 | **Sprint 1 S1-07 close-out — unit-role Foundation epic created** (governed by ADR-0009 Accepted same day via /architecture-review delta-mode). Layer reclassified Core → Foundation per ADR-0009 §Engine Compatibility "Foundation — stateless gameplay rules calculator" (the prior Pending entry preceded ADR-0009 authoring). 12 TRs covered 100% by ADR-0009 + ADR-0006 + ADR-0001 + ADR-0008 (TR-unit-role-001..012); 0 untraced requirements. Ratifies ADR-0008 cost-matrix unit-class dim placeholder + ADR-0012 CLASS_DIRECTION_MULT[6][3]. Soft-dep on unwritten ADR-0007 Hero DB (provisional `src/foundation/hero_data.gd` wrapper, parameter-stable migration; provisional-dependency strategy proven 3 invocations). Status flips: Foundation 1/4 → 1/5 + 1 Ready (unit-role); Core 1/5 → 1/4 (unit-role removed from Core pending). Preview story decomposition lists ~10 stories. Next: `/create-stories unit-role`. Sprint-1 reconciliation now COMPLETE (10/10 + DoD 12/12 + S1-07 ADR-0009 acceptance + S1-07 epic creation). |
