# Epics Index

> **Last Updated**: 2026-04-25
> **Engine**: Godot 4.6
> **Manifest Version**: 2026-04-20 (docs/architecture/control-manifest.md)
> **Layer coverage**: Platform (3/3 epics ready) + Foundation (1/4 epics ready — 3 blocked on ADR-0005/0006/0007) + Core (0/5 epics ready — 4 blocked on ADR-0008..0011 + 1 deferred to VS)

## Epics

| Epic | Layer | System | GDD | Governing ADRs | Stories | Status |
|------|-------|--------|-----|----------------|---------|--------|
| [gamebus](gamebus/EPIC.md) | Platform | GameBus autoload | — (ADR-0001 authoritative) | ADR-0001 | Not yet created | Ready |
| [scene-manager](scene-manager/EPIC.md) | Platform | SceneManager autoload | — (ADR-0002 authoritative) | ADR-0002, ADR-0001 | Not yet created | Ready |
| [save-manager](save-manager/EPIC.md) | Platform | SaveManager autoload | — (ADR-0003 authoritative) | ADR-0003, ADR-0001, ADR-0002 | Not yet created | Ready |
| [map-grid](map-grid/EPIC.md) | Foundation | Map/Grid System (#14) | design/gdd/map-grid.md | ADR-0004, ADR-0001, ADR-0002, ADR-0003 | Not yet created | Ready |

## Pending (blocked on ADR)

These systems have approved GDDs but no ADR yet. Epic creation is deferred until the governing ADR is Accepted, per project pattern (no speculative EPIC.md content that would drift from eventual ADR decisions).

### Foundation layer (3 pending)

| Pending Epic | Layer | System | GDD | Blocked on | Engine Risk |
|--------------|-------|--------|-----|------------|-------------|
| input-handling | Foundation | Input Handling System (#29) | design/gdd/input-handling.md | ADR-0005 | **HIGH** (dual-focus 4.6, SDL3, Android edge-to-edge) |
| balance-data | Foundation | Balance/Data System (#26) | design/gdd/balance-data.md | ADR-0006 | MEDIUM (FileAccess 4.4) |
| hero-database | Foundation | Hero Database (#25) | design/gdd/hero-database.md | ADR-0007 | LOW |

### Core layer (4 pending — added 2026-04-25 per `/create-epics layer: core` survey)

| Pending Epic | Layer | System | GDD | Blocked on | TR Registry | Notes |
|--------------|-------|--------|-----|------------|-------------|-------|
| terrain-effect | Core | Terrain Effect System (#2) | design/gdd/terrain-effect.md (Designed) | **ADR-0008** + TR registry seed | ❌ no TR-IDs registered | Most-referenced future ADR; consumed by story-005's `cost_multiplier` placeholder + Damage Calc + AI |
| unit-role | Core | Unit Role System (#5) | design/gdd/unit-role.md (Designed) | **ADR-0009** (class-coefficient schema) + TR registry seed | ❌ no TR-IDs registered | Stateless rules calculator; consumed by HP/Status, Turn Order, Damage Calc |
| hp-status | Core | HP/Status System (#12) | design/gdd/hp-status.md (Designed) | **ADR-0010** (status-effect stacking contract) | ⚠ partial (TR-hp-status-001 only) | Single authoritative emitter of `unit_died` per ADR-0001; needs TR registry expansion to cover DoT/heal/morale pipelines |
| turn-order | Core | Turn Order/Action Management (#13) | design/gdd/turn-order.md (**Needs Revision**) | **ADR-0011** (AI-inversion signal contract) + GDD revision | ⚠ partial (TR-turn-order-001 only) | Architecture.md §1 blocker: GDD `turn-order.md:442` direct call into AI (Feature) violates invariant #4 — must invert to GameBus signal pattern |

### Deferred to Vertical Slice tier

| System | Layer | GDD Status | Notes |
|--------|-------|-----------|-------|
| Save/Load (#17) | Core | **Not Started** (GDD pending) | Schema spec (what is saved); save-manager Platform epic already covers infra (how it's saved). VS tier — author GDD before creating Core epic. |

## Recommended Implementation Order

Per architecture.md layer invariants (Platform → Foundation → Core → ...), these 4 ready epics can be started in any order within Platform (no cross-dependencies at runtime), but sprint-plan should front-load GameBus since the other 3 Platform epics subscribe to it in tests.

Suggested order:

1. **GameBus** — unblocks stub-injectable test infrastructure for the other 3 Platform epics + all Foundation/Core consumers
2. **SceneManager** + **SaveManager** in parallel — both depend only on GameBus being stub-able
3. **Map/Grid** — can parallelize with SceneManager / SaveManager (different test surfaces)

## Dependency Snapshot

```
  GameBus (Platform, ADR-0001) ──────┐
      │                              │
      ▼                              │
  SceneManager (Platform, ADR-0002)  │
      │                              │
      ▼                              │
  SaveManager (Platform, ADR-0003) ◀─┘
      │
      ▼
  Map/Grid (Foundation, ADR-0004)
```

All 4 ready epics trace to 1+ Accepted ADR with full TR coverage. No untraced requirements.

## Next Steps

- Run `/create-stories gamebus` first (unblocks test infrastructure for all other epics)
- Run `/create-stories scene-manager` and `/create-stories save-manager` in parallel after GameBus stories are Ready
- Run `/create-stories map-grid` in parallel with any of the above (independent test surface)
- Author ADR-0005 (Input, HIGH engine risk) → `/create-epics input-handling` when Accepted
- Author ADR-0006 (Balance/Data) → `/create-epics balance-data` when Accepted
- Author ADR-0007 (Hero DB) → `/create-epics hero-database` when Accepted

### Core layer ADRs (next session priority — unblocks Pre-Production → Production gate)

- Author **ADR-0008 Terrain Effect** (highest leverage — referenced by 6+ downstream Feature systems including Grid Battle, Damage Calc, AI; also unblocks story-005's `cost_multiplier` placeholder in `src/core/terrain_cost.gd`) → `/architecture-decision terrain-effect`
- Author **ADR-0009 Unit Role** (class-coefficient schema; consumed by HP/Status, Turn Order, Damage Calc) → `/architecture-decision unit-role`
- Author **ADR-0010 HP/Status** (status-effect stacking contract) → `/architecture-decision hp-status`
- Author **ADR-0011 Turn Order signal-inversion** (resolves architecture.md §1 invariant-#4 blocker; GDD `turn-order.md` revision required first to invert AI direct-call to GameBus signal pattern) → GDD revision + `/architecture-decision turn-order-ai-inversion`

After each ADR is Accepted: re-run `/create-epics layer: core` to scaffold the corresponding EPIC.md file (the index entry above will graduate to the "Epics" table).

## Gate Readiness

Pre-Production → Production gate FAIL (re-checked 2026-04-25 — see `production/qa/qa-signoff-map-grid-2026-04-25.md` + smoke-2026-04-25.md). Map-grid epic close-out is APPROVED WITH CONDITIONS but does not by itself advance the project stage — Vertical Slice + Core layer + playtest data remain outstanding.

Current gate blockers (post-2026-04-25 update):

- ~~Epics in `production/epics/` (Foundation + Core layer epics present)~~ ✅ **Partial** — 4/7 Foundation+Platform epics present; **0/4 Core MVP epics** (all blocked on ADR-0008..0011)
- ❌ Vertical Slice build — does not exist (no main scene wired up; queries are Foundation-only)
- ❌ ≥3 Vertical Slice playtests — `production/playtests/` directory missing
- ❌ Sprint plan in `production/sprints/` — directory missing
- ❌ Core + Feature ADRs — 4 Core ADRs (0008..0011) + Feature ADRs (Grid Battle, Damage Calc, AI, etc.) not yet written

## Changelog

| Date | Change |
|------|--------|
| 2026-04-20 | Initial index. 4 epics created: gamebus, scene-manager, save-manager, map-grid. 3 Foundation-layer epics (input-handling, balance-data, hero-database) deferred pending ADR-0005/0006/0007 authoring. |
| 2026-04-25 | Map-grid epic close-out (8/8 stories Complete; PRs #26-#30 pending merge). 4 Core-layer pending entries added (terrain-effect, unit-role, hp-status, turn-order) — all blocked on ADR-0008..0011 + TR registry expansion (terrain-effect, unit-role have no TR-IDs registered). Save/Load (#17) deferred to VS tier (GDD doesn't exist; save-manager Platform epic already covers infra). Gate readiness re-checked: still FAIL (Vertical Slice + playtest + Core ADRs outstanding). |
