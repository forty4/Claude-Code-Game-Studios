# Story 004: Mutation API + packed cache write-through + tile_destroyed signal

> **Epic**: map-grid
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Estimate**: 4-5 hours (3 mutation methods + 6-cache write-through + signal emission via GameBusStub + state-transition matrix + V-5 cache-sync parametric test)

## Context

**GDD**: `design/gdd/map-grid.md`
**Requirement**: `TR-map-grid-004`, `TR-map-grid-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 Map/Grid Data Model (emitter side) + ADR-0001 GameBus Autoload (signal contract host)
**ADR Decision Summary**: Three mutation methods (`set_occupant`, `clear_occupant`, `apply_tile_damage`) called only by `GridBattleController` by convention. Every mutation writes through to both `Array[TileData]` (authoritative) AND matching packed cache in the same call (R-4 hazard). `apply_tile_damage` emits `GameBus.tile_destroyed(coord: Vector2i)` exactly once per destruction — single-primitive payload per TR-gamebus-001 canonical form.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `tile_destroyed` signal already declared on `/root/GameBus` per ADR-0001 amendment (Environment domain banner, signal count 26→27). No new post-cutoff APIs in this story. `GameBusStub.swap_in()` test-isolation utility already shipped from gamebus epic story-006; use it for signal-emission tests.

**Control Manifest Rules (Foundation layer)**:
- Required: Every mutation writes through to both `Array[TileData]` AND matching packed cache in the same call — R-4 correctness hazard (TR-map-grid-004)
- Required: Mutation API (`set_occupant`, `clear_occupant`, `apply_tile_damage`) called only by `GridBattleController` by convention — enforced in code review (not runtime)
- Required: MapGrid emits exactly one GameBus signal: `tile_destroyed(coord: Vector2i)` — single-primitive payload per TR-gamebus-001 canonical form (TR-map-grid-005)
- Required: `CONNECT_DEFERRED` mandatory for cross-scene connects — consumer tests must honor this
- Forbidden: Emit `tile_destroyed` from `_process` / `_physics_process` / `_input` (GameBus per-frame ban — ADR-0001)
- Forbidden: Multiple emissions for the same destruction event — idempotent transition (V-6 contract)
- Guardrail: Mutation cost O(1) per call (6 cache writes max); frequency upper-bounded by turn structure, well under GameBus 50-emit/frame soft cap

---

## Acceptance Criteria

*From GDD `design/gdd/map-grid.md` §AC-ST-1/2/3/4, §AC-EDGE-4, §EC-6 + ADR-0004 §Decision 6, §Decision 9, V-5, V-6:*

- [ ] `set_occupant(coord: Vector2i, unit_id: int, faction: int) -> void` updates `_map.tiles[idx].occupant_id`, `.occupant_faction`, `.tile_state` AND matching packed cache entries in the same call (AC-ST-1)
- [ ] `clear_occupant(coord: Vector2i) -> void` resets occupant fields + tile_state to EMPTY (or DESTROYED if the tile was previously DESTROYED), with write-through to both Array[TileData] and caches
- [ ] `apply_tile_damage(coord: Vector2i, damage: int) -> bool` returns `true` iff the tile was destroyed by this damage — i.e., tile went from DESTRUCTIBLE with `destruction_hp > 0` to `destruction_hp <= 0`
- [ ] On destruction: `tile_state` → DESTROYED, `is_passable_base` → `true` (both TileData and cache), `GameBus.tile_destroyed(coord)` emitted exactly once (AC-ST-2, V-6)
- [ ] AC-EDGE-4: If a DESTRUCTIBLE tile with an occupant is destroyed, the occupant fields are preserved — `tile_state` is immediately re-set to ALLY_OCCUPIED or ENEMY_OCCUPIED (the occupant outlives the tile); `is_passable_base` becomes `true`. Signal still emitted exactly once.
- [ ] AC-ST-3 `set_occupant(coord, unit_id, ALLY)` on a tile currently ENEMY_OCCUPIED is rejected with `push_error("ERR_ILLEGAL_STATE_TRANSITION")`; state unchanged; caller must clear first
- [ ] AC-ST-4: Mutations on `tile_state == IMPASSABLE` tiles reject any transition except: if `is_destructible == true` and `destruction_hp <= 0` after `apply_tile_damage`, transition to DESTROYED is allowed
- [ ] `apply_tile_damage` on a tile with `is_destructible == false` is a no-op that pushes `push_warning("...damage on non-destructible")` and returns `false`
- [ ] `apply_tile_damage` with cumulative damage (e.g., hp=10, two calls of damage=5) emits `tile_destroyed` on the second call only — exactly one emission per destruction event (V-6)
- [ ] V-5 cache-sync: for each mutation method, a parametrised test verifies that after the call, `_occupant_id_cache[idx]`, `_occupant_faction_cache[idx]`, `_tile_state_cache[idx]`, and `_passable_base_cache[idx]` all match the corresponding `_map.tiles[idx]` field

---

## Implementation Notes

*Derived from ADR-0004 §Decision 6, §Decision 9, §Risks R-4, GDD §ST-1, §EC-6:*

- The six tile_state enum mirror values used in validation / mutation come from GDD §ST-1. Lock the integer mirror in `map_grid.gd` as constants:
  - `const STATE_EMPTY := 0`
  - `const STATE_ALLY_OCCUPIED := 1`
  - `const STATE_ENEMY_OCCUPIED := 2`
  - `const STATE_IMPASSABLE := 3`
  - `const STATE_DESTRUCTIBLE := 4`
  - `const STATE_DESTROYED := 5`
  - Same for faction: `FACTION_NONE := 0`, `FACTION_ALLY := 1`, `FACTION_ENEMY := 2`
  - These match the `@export var tile_state: int` enum-mirror pattern from ADR-0004 §Decision 1.
- Single write-through helper: `_write_tile(idx: int, td: TileData) -> void` updates the TileData fields AND the 6 packed caches in one block. All mutation methods call this helper. This is the single choke-point R-4 defends against.
- `set_occupant` faction derivation: `ALLY → STATE_ALLY_OCCUPIED`, `ENEMY → STATE_ENEMY_OCCUPIED`. Direct transition from ALLY to ENEMY is rejected — AC-ST-3 requires caller to `clear_occupant` first, then `set_occupant` with new faction.
- `clear_occupant` on a DESTROYED tile keeps `tile_state = DESTROYED` (not EMPTY) — the tile's terrain state is preserved across occupant transitions.
- `apply_tile_damage` signal emission: emit AFTER the TileData + cache update completes. Use `GameBus.tile_destroyed.emit(coord)` — the signal is already declared via the gamebus epic's ADR-0001 amendment.
- For AC-EDGE-4 (occupant survives tile destruction): detect `is_destructible == true && destruction_hp > 0 && damage >= destruction_hp` BEFORE the write. If the tile currently has an occupant (tile_state == ALLY_OCCUPIED or ENEMY_OCCUPIED), destruction sets `is_passable_base = true` (for future pathfinding), but `tile_state` is RESTORED to the occupant state (not set to DESTROYED). Signal still fires — consumers need to know the tile is gone regardless of occupant state.
- Signal emission is synchronous at the call site (GameBus is pure relay — ADR-0001). `CONNECT_DEFERRED` is the CONSUMER's responsibility when subscribing — tests must use `CONNECT_DEFERRED` per control-manifest, matching the pattern from gamebus epic story-007.
- Use `GameBusStub.swap_in()` (shipped from gamebus story-006) for the test-isolation setup — do NOT subscribe directly to `/root/GameBus` from the test. The stub gives a deterministic emit-count probe.
- All mutation methods are NOT marked private in GDScript (no access control) but are documented in class header as "GridBattleController-only by convention" matching ADR-0004 §Decision 6.
- `apply_tile_damage` return value: `true` = destroyed by this call, `false` = damage applied but not destroyed (or tile wasn't destructible). Callers use this to drive VFX + outcome logic.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: Pathfinding queries (`get_movement_range`, `get_path`). Consumers of `tile_destroyed` (AI path cache invalidation) live in their own epics.
- Story 006: LoS / attack-direction queries
- Consumer-side signal subscription (AI, Formation Bonus, VFX) — enforced only by negative rule in control-manifest; those subscribers are built in their own epics

---

## QA Test Cases

*Authored from GDD + ADR directly (lean mode).*

- **AC-1**: set_occupant writes through to TileData + all relevant caches (AC-ST-1)
  - Given: loaded 15×15 PLAINS map, tile (3,5) is EMPTY
  - When: `grid.set_occupant(Vector2i(3,5), 42, FACTION_ALLY)`
  - Then: `grid._map.tiles[5*15+3].occupant_id == 42`, `.occupant_faction == FACTION_ALLY`, `.tile_state == STATE_ALLY_OCCUPIED`; `_occupant_id_cache[78] == 42`, `_occupant_faction_cache[78] == FACTION_ALLY`, `_tile_state_cache[78] == STATE_ALLY_OCCUPIED`
  - Edge cases: FACTION_ENEMY produces STATE_ENEMY_OCCUPIED analogously

- **AC-2**: clear_occupant resets occupant fields with write-through
  - Given: tile (3,5) has occupant 42 ALLY
  - When: `grid.clear_occupant(Vector2i(3,5))`
  - Then: occupant_id == 0, occupant_faction == FACTION_NONE, tile_state == STATE_EMPTY (both TileData and caches); `is_passable_base` unchanged (PLAINS stays passable)
  - Edge cases: clearing an already-EMPTY tile is a no-op (idempotent), emits no error

- **AC-3**: apply_tile_damage partial (non-destroying)
  - Given: DESTRUCTIBLE tile (3,5) with destruction_hp=10, is_destructible=true, occupant empty
  - When: `grid.apply_tile_damage(Vector2i(3,5), 5)`
  - Then: returns `false`; `destruction_hp == 5`; tile_state unchanged; `GameBus.tile_destroyed` NOT emitted (stub emit-count == 0)
  - Edge cases: damage=0 is a no-op (returns false, destruction_hp unchanged)

- **AC-4**: apply_tile_damage destroying (AC-ST-2 + V-6 single emission)
  - Given: same tile, after AC-3 (destruction_hp=5)
  - When: `grid.apply_tile_damage(Vector2i(3,5), 5)`
  - Then: returns `true`; destruction_hp=0, tile_state=STATE_DESTROYED, is_passable_base=true; ALL 6 caches updated; stub observes EXACTLY ONE `tile_destroyed(Vector2i(3,5))` emit
  - Edge cases: damage=99 with hp=5 also destroys with one emit (no "over-damage" double emission); second `apply_tile_damage` call on the already-DESTROYED tile emits nothing and returns false

- **AC-5**: AC-EDGE-4 — occupant survives tile destruction
  - Given: DESTRUCTIBLE tile (3,5) with destruction_hp=10, occupant_id=42, tile_state=STATE_ALLY_OCCUPIED, is_destructible=true
  - When: `grid.apply_tile_damage(Vector2i(3,5), 10)`
  - Then: returns `true`; `GameBus.tile_destroyed(coord)` emitted exactly once; post-state: `tile_state == STATE_ALLY_OCCUPIED` (preserved, NOT DESTROYED), `occupant_id == 42` (preserved), `is_passable_base == true` (terrain now passable); caches match
  - Edge cases: same scenario with STATE_ENEMY_OCCUPIED — signal fires once; occupant state preserved

- **AC-6**: AC-ST-3 direct ALLY→ENEMY rejected
  - Given: tile (3,5) is STATE_ALLY_OCCUPIED with occupant_id=42
  - When: `grid.set_occupant(Vector2i(3,5), 99, FACTION_ENEMY)`
  - Then: `push_error` captured containing "ERR_ILLEGAL_STATE_TRANSITION"; state unchanged (occupant_id still 42, faction still ALLY, tile_state still ALLY_OCCUPIED)
  - Edge cases: ENEMY→ALLY direct also rejected; ALLY→ALLY overwrite (same faction, different unit) — decision: rejected as "must clear first" per GDD §EC-6 strict-sync discipline

- **AC-7**: AC-ST-4 IMPASSABLE immutability
  - Given: tile (3,5) is STATE_IMPASSABLE, is_destructible=false
  - When: `grid.set_occupant(...)` or `grid.apply_tile_damage(..., 100)`
  - Then: state unchanged; `set_occupant` raises `ERR_ILLEGAL_STATE_TRANSITION`; `apply_tile_damage` is a no-op with `push_warning`; no `tile_destroyed` emit
  - Edge cases: IMPASSABLE with is_destructible=true — apply_tile_damage IS allowed; on `hp<=0` transitions to DESTROYED with signal emit (AC-ST-4 exception path)

- **AC-8**: apply_tile_damage on non-destructible warning
  - Given: PLAINS tile (3,5), `is_destructible=false`
  - When: `grid.apply_tile_damage(Vector2i(3,5), 100)`
  - Then: returns `false`; `push_warning` emitted; no state change; no signal emit
  - Edge cases: idempotent — repeat call same behaviour

- **AC-9**: V-5 cache-sync parametric (every mutation × every cache)
  - Given: 3×3 test grid seeded with mixed tile_states
  - When: a sequence of 10 mutations across `set_occupant`, `clear_occupant`, `apply_tile_damage` is executed
  - Then: after EACH mutation, for every cache index `i` in `0..8`, `_occupant_id_cache[i] == _map.tiles[i].occupant_id` AND same for faction, tile_state, is_passable_base (bool→byte); ZERO mismatches across the entire 10-step sequence
  - Edge cases: this is the R-4 safety net — the assertion runs after EVERY mutation, not just at end-state

---

## Test Evidence

**Story Type**: Integration (crosses MapGrid internals + GameBus signal + GameBusStub)
**Required evidence**:
- `tests/integration/core/map_grid_mutation_test.gd` — must exist and pass (9 tests covering AC-1..9)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (MapGrid skeleton + caches; `_write_tile` helper attaches to this structure), Story 003 (validator ensures tests start from a known-valid map)
- Unlocks: Story 005 (Dijkstra reads `_tile_state_cache` + `_passable_base_cache` set by this story's mutations), Story 006 (LoS reads `_passable_base_cache`)
