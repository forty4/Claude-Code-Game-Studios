# Architecture Review Report — Delta

> **Date**: 2026-04-20
> **Engine**: Godot 4.6
> **Mode**: Delta review — focused on ADR-0004 Proposed → Accepted escalation
> **Prior report**: `docs/architecture/architecture-review-2026-04-18.md` (PASS, 3 ADRs)
> **GDDs Reviewed (delta)**: 1 (map-grid.md — re-scanned for TR registration)
> **ADRs Reviewed (delta)**: 1 (ADR-0004 — Proposed on 2026-04-18, not in prior review)

---

## TL;DR

- **Verdict**: **PASS** — ADR-0004 escalated Proposed → Accepted
- godot-specialist context-isolated validation: 8/8 engine checks APPROVED
- map-grid.md 10 technical requirements 100% covered by ADR-0004; registered as TR-map-grid-001..010 in tr-registry.yaml v3
- ADR-0001/0002/0003 consistency clean (ADR-0004 applies the amendment pattern established in prior reviews)
- 1 advisory carried to implementation time (non-blocking): `get_movement_range()` return type choice between `PackedVector2Array` and `Array[Vector2i]` — GDScript specialist decision at /dev-story

---

## Scope Clarification — Why a Delta Review

The 2026-04-18 full review covered ADR-0001/0002/0003 (Foundation layer) and returned PASS with 8 coverage gaps flagged as advisory. ADR-0004 Map/Grid was listed as "Required ADR #1" next. ADR-0004 was authored same day (2026-04-18) but committed in Proposed status without passing through `/architecture-review`. Normal process is one `/architecture-review` run per ADR cluster; this delta report addresses the single-ADR gap.

**Mode used**: Delta (focused engine + coverage + consistency against existing 3 Accepted ADRs). Full-scope re-review of all 4 ADRs was not warranted — no ADR-0001/2/3 content changed since 2026-04-18 PASS.

---

## ADR-0004 Coverage — map-grid.md

All 10 technical requirements extracted from `design/gdd/map-grid.md` map cleanly to ADR-0004 sections. Registered as permanent TR-map-grid-001..010 in `tr-registry.yaml` v3.

| TR-ID | Requirement (abbrev) | ADR-0004 Section | Status |
|-------|---------------------|-------------------|--------|
| TR-map-grid-001 | CR-2 flat array `tiles[row*cols+col]` | §Decision 1 (Tile Storage) | ✅ |
| TR-map-grid-002 | CR-6 custom Dijkstra; AStarGrid2D/NavServer2D forbidden | §Decision 7 + §Alternatives 1 rejection | ✅ |
| TR-map-grid-003 | 9 public read-only query methods | §Decision 5 (Query API) + §Key Interfaces | ✅ |
| TR-map-grid-004 | Mutation API Grid-Battle-only; write-through to packed caches | §Decision 6 + §Decision 2 invariants | ✅ |
| TR-map-grid-005 | `tile_destroyed(coord)` single-primitive on GameBus | §Decision 9 + ADR-0001 Environment amendment | ✅ |
| TR-map-grid-006 | AC-PERF-2 <16ms on 40×30 move_range=10 | §Decision 2 (packed caches) + §Verification Required V-1 | ✅ |
| TR-map-grid-007 | Battle-scoped Node, freed with BattleScene | §Decision 4 + ADR-0002 alignment | ✅ |
| TR-map-grid-008 | Elevation 0/1/2 + Bresenham LoS rule | §Decision 8 | ✅ |
| TR-map-grid-009 | `.tres` authoring; OQ#2 resolved | §Decision 3 | ✅ |
| TR-map-grid-010 | TileData inline-only hard constraint (R-3) | §Risks R-3 hard constraint | ✅ |

**Coverage**: 10/10 TRs ✅ — zero gaps.

---

## Engine Compatibility Audit — ADR-0004

### godot-specialist Context-Isolated Validation

Spawned as parallel subagent with scope: Godot 4.6 engine-correctness of ADR-0004. Verdict: **APPROVED** (8/8 checks).

| Check | Result | Notes |
|-------|--------|-------|
| 1. `Resource.duplicate_deep()` R-3 edge case | ✅ correct | 4.5+ API; UID-referenced sub-resources return shared instance (documented); hard-constraint mitigation is sufficient |
| 2. `Array[TileData]` @export inspector at 1200 elements (R-5) | ✅ acceptable | No hard limit; scroll lag only. Per-TileData file alternative would worsen UX (1200 individually-selectable file pickers) |
| 3. Packed caches write-through design (§2) | ✅ correct | Hybrid "typed Resource + packed caches at load" is idiomatic Godot; R-4 mitigation adequate |
| 4. CR-6 AStarGrid2D rejection 4.6-valid? | ✅ still correct | `set_point_weight_scale` is per-cell scalar only — cannot carry (unit_type, terrain_type) 2D matrix. NavigationServer2D is for continuous 2D meshes, not discrete grid cost. |
| 5. Bresenham LoS | ✅ correct | Integer raster over elevation cache is standard; PhysicsServer2D raycast would be inappropriate for logical grid LoS |
| 6. Post-Cutoff API declaration | ✅ complete | Only `duplicate_deep()` (4.5+); all others pre-cutoff. Declaration matches actual API usage. |
| 7. ADR-0001/0002/0003 consistency | ✅ clean | Environment domain amendment correct; BattleScene child lifecycle correct; terrain_version + CACHE_MODE_IGNORE pattern matches ADR-0003 |
| 8. V-1..V-7 GdUnit4 testability | ✅ all-testable | V-7 (editor hang) correctly flagged as human-verified per coding-standards.md test-evidence table |

### Post-Cutoff API Inventory (project-wide, delta)

Post-cutoff APIs in use across 4 Accepted ADRs:

| API | Version | ADR | Status |
|-----|---------|-----|--------|
| Typed signals with Resource payloads | 4.2+ (strictness tightened 4.5) | ADR-0001 | declared + verified |
| `ResourceLoader.load_threaded_request` / `load_threaded_get_status` | 4.2+ (stable 4.4/4.5/4.6) | ADR-0002 | declared + verified |
| Recursive Control disable | 4.5+ | ADR-0002 | declared, verification pending at implementation |
| `Resource.duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` | 4.5+ | ADR-0001 (payload cloning), ADR-0003 (save), ADR-0004 (map clone) | declared + verified |
| `DirAccess.get_files_at` | 4.6-idiomatic (replaces legacy list_dir_begin) | ADR-0003 | declared |
| `ResourceSaver.FLAG_COMPRESS` | 4.0+ (pre-cutoff) | ADR-0003 | declared |

No conflicts between ADRs on post-cutoff API assumptions. No deprecated API references detected.

---

## Cross-ADR Conflict Detection (Delta)

Scanned ADR-0004 against ADR-0001/0002/0003. No conflicts detected:

- **Signal contract**: ADR-0004's `tile_destroyed(coord: Vector2i)` follows ADR-0001 §Evolution Rule #1 (minor amendment, no supersession). Environment domain banner added to ADR-0001 via amendment during ADR-0004 authoring (signal count 26→27, domain count 7→8). Consistent with prior amendment pattern used by ADR-0002 (`scene_transition_failed`) and ADR-0003 (`save_persisted`, `save_load_failed`).
- **Lifecycle**: ADR-0004 MapGrid as BattleScene child matches ADR-0002 IDLE→LOADING_BATTLE→IN_BATTLE→free lifecycle. No lifecycle ownership conflict.
- **Schema pattern**: ADR-0004 `@export`-typed Resource + `terrain_version` + `CACHE_MODE_IGNORE` mirrors ADR-0003's save-schema pattern exactly. No schema-pattern drift.
- **Mid-battle persistence**: ADR-0004 §Decision 10 correctly defers mid-battle save to future `MapRuntimeState` ADR. ADR-0003 CP-1/CP-2/CP-3 all fire outside battle — no conflict.

---

## ADR Dependency Order (updated)

```
Foundation (all Accepted):
  1. ADR-0001 ✅  GameBus Autoload (2026-04-18)
  2. ADR-0002 ✅  Scene Manager   (2026-04-18; requires ADR-0001)
  3. ADR-0003 ✅  Save/Load        (2026-04-18; requires ADR-0001 + ADR-0002)
  4. ADR-0004 ✅  Map/Grid Data Model (2026-04-20; no Foundation-layer deps; concurrent amendment to ADR-0001)
```

No dependency cycles. No unresolved Proposed-status references.

---

## GDD Revision Flags (Delta)

No new flags from this delta review. Carried forward from 2026-04-18 (unchanged):

| GDD | Flag | Source | Action |
|---|---|---|---|
| `turn-order.md` | `battle_ended` emitter ownership moved to Grid Battle | ADR-0001 | GDD v-next required |
| `grid-battle.md` | `battle_complete` → `battle_outcome_resolved` rename | ADR-0001 | GDD v5.0 pending (MAJOR REVISION NEEDED status carried from grid-battle-review-log) |

---

## Advisory Findings (non-blocking, carried to implementation)

### ADV-1: `get_movement_range()` return type contract

ADR-0004 §Decision 5 + §Key Interfaces declares `get_movement_range(...) -> PackedVector2Array`. MapGrid internally stores coordinates as `Vector2i`. `PackedVector2Array` elements are `Vector2` (float pair), introducing implicit int→float conversion at the API boundary.

**Options at implementation time (GDScript specialist to decide)**:
- (a) Change return type to `Array[Vector2i]` — preserves integer precision, loses Packed array memory efficiency
- (b) Keep `PackedVector2Array` — document caller-side cast requirement to `Vector2i`

Neither affects the architectural contract. Captured here for /dev-story pickup; ADR text does not require revision.

### ADV-2: Inspector ergonomics for 40×30 maps (R-5 restatement)

ADR correctly flags this as a tolerable cost for MVP (≤5 maps). Post-MVP, if content authoring becomes a bottleneck during playtest content push, consider a custom editor dock as a tools-programmer workstream. Not this ADR's scope.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` exists but was not updated with ADR-0004 entries. Re-evaluation at ≥6 ADRs remains the guidance from 2026-04-18 report. Current count is 4.

---

## Verdict: **PASS**

ADR-0004 Status: Proposed → **Accepted (2026-04-20)**.

Project now has 4 Accepted Foundation-layer ADRs. Coverage gaps from 2026-04-18 report (Input, Balance/Data, Hero DB, Terrain Effect, Formation Bonus ADRs) remain as pre-production pipeline advisories — still expected work, still non-blocking.

### Required ADRs (prioritized, Foundation-first, carried from 2026-04-18)

1. ~~ADR-0004 — Map/Grid data model~~ ✅ **Accepted this review**
2. **ADR-0005** — Input System (Godot 4.5 InputMap changes = MEDIUM engine risk)
3. **ADR-0006** — Balance Data resources (blocks Hero DB + Terrain Effect)
4. **ADR-0007** — Hero Database schema (depends on ADR-0006)
5. **ADR-0008** — Terrain Effect evaluation (depends on ADR-0004 + ADR-0006)
6. **ADR-0009** — Formation Bonus (depends on ADR-0004; GDD now APPROVED)
7. **ADR-0010** — Destiny Branch (depends on Scenario Progression v2.1; GDD APPROVED)
8. **ADR-0011** — Destiny State (depends on ADR-0003; GDD APPROVED)

### Gate Guidance

Running `/create-control-manifest` immediately with 4 Accepted ADRs is now unblocked. Control manifest will cover Foundation layer + initial Core layer rules for Map/Grid. Remaining ADRs (#2–#8 above) will drive control-manifest updates as they land.

---

## Phase 8 — Writes

- ✅ `docs/architecture/ADR-0004-map-grid-data-model.md` — Status Proposed → Accepted; Last Verified + Decision Makers added; changelog entry
- ✅ `docs/architecture/tr-registry.yaml` — v2 → v3; last_updated 2026-04-20; 10 new TR-map-grid-* entries appended
- ✅ `docs/architecture/architecture-review-2026-04-20.md` — this delta report
- ✅ `docs/architecture/architecture-traceability.md` — ADR-0004 rows moved from ⏳ Pending to Registered; coverage summary updated
- ✅ `production/session-state/active.md` — Phase 8 silent append
- ⏭ `docs/consistency-failures.md` append — skipped (no CONFLICT entries found)

---

## Chain-of-Verification

5 challenge questions checked against artifacts and specialist output — verdict **unchanged (PASS)**. Strongest candidate for downgrade was ADV-1 (return-type contract) but ADR text is correct as written; concern is implementation-time, not architectural.
