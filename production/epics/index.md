# Epics Index

> **Last Updated**: 2026-04-20
> **Engine**: Godot 4.6
> **Manifest Version**: 2026-04-20 (docs/architecture/control-manifest.md)
> **Layer coverage**: Platform (3/3 epics ready) + Foundation (1/4 epics ready — 3 blocked on ADR-0005/0006/0007)

## Epics

| Epic | Layer | System | GDD | Governing ADRs | Stories | Status |
|------|-------|--------|-----|----------------|---------|--------|
| [gamebus](gamebus/EPIC.md) | Platform | GameBus autoload | — (ADR-0001 authoritative) | ADR-0001 | Not yet created | Ready |
| [scene-manager](scene-manager/EPIC.md) | Platform | SceneManager autoload | — (ADR-0002 authoritative) | ADR-0002, ADR-0001 | Not yet created | Ready |
| [save-manager](save-manager/EPIC.md) | Platform | SaveManager autoload | — (ADR-0003 authoritative) | ADR-0003, ADR-0001, ADR-0002 | Not yet created | Ready |
| [map-grid](map-grid/EPIC.md) | Foundation | Map/Grid System (#14) | design/gdd/map-grid.md | ADR-0004, ADR-0001, ADR-0002, ADR-0003 | Not yet created | Ready |

## Pending (blocked on ADR)

These Foundation-layer systems have approved GDDs but no ADR yet. Epic creation deferred until the governing ADR is Accepted.

| Pending Epic | Layer | System | GDD | Blocked on | Engine Risk |
|--------------|-------|--------|-----|------------|-------------|
| input-handling | Foundation | Input Handling System (#29) | design/gdd/input-handling.md | ADR-0005 | **HIGH** (dual-focus 4.6, SDL3, Android edge-to-edge) |
| balance-data | Foundation | Balance/Data System (#26) | design/gdd/balance-data.md | ADR-0006 | MEDIUM (FileAccess 4.4) |
| hero-database | Foundation | Hero Database (#25) | design/gdd/hero-database.md | ADR-0007 | LOW |

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

## Gate Readiness

Pre-Production → Production gate still FAIL (see `production/gate-checks/pre-prod-to-prod-2026-04-20.md`). Current gate blockers resolved by this epic landing:

- ~~Epics in `production/epics/` (Foundation + Core layer epics present)~~ ✅ **Partial** — 4/7 Foundation+Platform epics present; Core-layer epics still needed

Remaining gate blockers unchanged: prototypes/, sprint plan, playtests, Vertical Slice build, main menu + pause menu UX specs, character visual profiles, Core + Feature ADRs.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-20 | Initial index. 4 epics created: gamebus, scene-manager, save-manager, map-grid. 3 Foundation-layer epics (input-handling, balance-data, hero-database) deferred pending ADR-0005/0006/0007 authoring. |
