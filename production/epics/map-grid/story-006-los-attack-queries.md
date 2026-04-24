# Story 006: LoS + attack queries + adjacency (remaining 7 queries)

> **Epic**: map-grid
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 4-5 hours (Bresenham LoS with corner-cut conservatism + 4 remaining queries + V-3 20-case LoS matrix + attack-direction horizontal tie-break)

## Context

**GDD**: `design/gdd/map-grid.md`
**Requirement**: `TR-map-grid-003` (remaining 7 of 9 queries), `TR-map-grid-008` (LoS)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 Map/Grid Data Model
**ADR Decision Summary**: Bresenham line-of-sight rasterized from attacker to target over `_elevation_cache`; block iff an intermediate tile has `elevation > max(from.elev, to.elev)` OR `is_passable_base == false`; endpoints never self-block; destroyed walls NO LONGER block. Attack direction uses the GDD F-5 formula with horizontal-axis tie-break on perfect diagonals (`abs(dc) == abs(dr)` → EAST/WEST), matching the cross-system contract to `damage-calc.md`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs in this story. `PackedVector2Array` / `PackedInt32Array` for return types; `_elevation_cache` and `_passable_base_cache` already built by story-002. Integer arithmetic only.

**Control Manifest Rules (Foundation + Core layers)**:
- Required: LoS via Bresenham over `_elevation_cache` — block iff `elevation > max(from.elev, to.elev)`; destroyed walls NO LONGER block; endpoints never self-block (TR-map-grid-008)
- Required: LoS corner-cut conservatism — Bresenham line passing through a tile corner treats BOTH adjacent tiles as intermediates; either blocking condition blocks LoS (prevents "shoot through wall gap" exploit — GDD §EC-3)
- Required: Attack direction tie-break — on `abs(dc) == abs(dr)` (perfect diagonal), horizontal axis wins (EAST/WEST) — deterministic cross-system rule to `damage-calc.md`
- Required: 9 public read-only query methods total — this story completes the last 7; signatures must match ADR-0004 §Decision 5 verbatim (TR-map-grid-003)
- Forbidden: `MapGrid.get_unit_at(coord)` — that API does NOT exist; Formation Bonus self-caches `coord_to_unit_id` at `round_started` (cross-system contract)
- Forbidden: TileData dereference in LoS hot loop — read `_elevation_cache` + `_passable_base_cache` only
- Guardrail: `has_line_of_sight` + `get_attack_range` must stay O(distance) — Bresenham on a 40×30 map has max path length ~67 tiles; well under frame budget

---

## Acceptance Criteria

*From GDD `design/gdd/map-grid.md` §CR-5, §CR-7, §AC-CR-5, §AC-CR-7, §AC-F-4, §AC-F-5, §AC-EDGE-3, §EC-3, §EC-4 + ADR-0004 §Decision 5, §Decision 8, V-3:*

- [ ] `has_line_of_sight(from: Vector2i, to: Vector2i) -> bool` implemented via integer Bresenham rasterization over `_elevation_cache`
- [ ] AC-CR-7: FORTRESS_WALL (is_passable_base=false) between attacker(elev=0) and target(elev=0) → returns `false`
- [ ] AC-F-4 elevation rule: intermediate tile blocks iff `T.elevation > max(A.elevation, B.elevation)`; intermediate at `elev=1` with A=1, B=0 does NOT block (1>1=false)
- [ ] AC-EDGE-3: adjacent tiles (Manhattan distance 1) always return `true` — no intermediate tiles to loop over; short-circuit without entering Bresenham loop
- [ ] GDD §EC-3 corner-cut conservatism: when Bresenham line passes exactly through a tile corner (two adjacent tiles share only a corner), both are treated as intermediates; either blocking → LoS blocked
- [ ] GDD §EC-3 same-tile LoS: `from == to` (D=0) returns `true` with a single `push_warning("ERR_SAME_TILE_LOS")` (caller bug)
- [ ] Destroyed walls do NOT block: a tile with `_tile_state_cache[idx] == STATE_DESTROYED` is NOT treated as LoS-blocking, even if its `_passable_base_cache` is `0` (which it won't be post-destruction per story-004, but the LoS code must handle edge-case legacy states gracefully)
- [ ] `get_attack_range(origin: Vector2i, attack_range: int, apply_los: bool) -> PackedVector2Array` returns tiles within Manhattan distance ≤ `attack_range`; when `apply_los == true`, filters out tiles where `has_line_of_sight(origin, tile) == false`
- [ ] `get_attack_range` return EXCLUDES origin itself (attacker doesn't attack own tile)
- [ ] `get_attack_direction(attacker: Vector2i, defender: Vector2i, defender_facing: int) -> int` returns the enum `FRONT=0`, `FLANK=1`, `REAR=2` per GDD F-5 `(attack_dir - facing + 4) % 4` lookup
- [ ] AC-F-5 direction matrix: facing=NORTH(0); attacker at NORTH(0)→FRONT, EAST(1)→FLANK, SOUTH(2)→REAR, WEST(3)→FLANK
- [ ] GDD §EC-4 horizontal tie-break: when `abs(dc) == abs(dr)` (perfect diagonal attacker-defender offset), `attack_dir` resolves to EAST or WEST (not NORTH/SOUTH) — deterministic cross-system rule
- [ ] GDD §EC-4 same-tile attack: `attacker == defender` returns `FRONT` with `push_warning("ERR_SAME_TILE_ATTACK")` (caller bug, deterministic default)
- [ ] `get_adjacent_units(coord: Vector2i, faction: int = -1) -> PackedInt32Array` returns unit IDs from the 4 cardinal neighbours of `coord`; optional `faction` filter (`-1` = any faction, returns all); reads `_occupant_id_cache` + `_occupant_faction_cache`
- [ ] `get_occupied_tiles(faction: int = -1) -> PackedVector2Array` returns all coords where `_occupant_id_cache[idx] != 0` (0 = none); optional `faction` filter
- [ ] V-3: 20-case LoS matrix passes — fixed test fixture covering elevation combinations (A.elev ∈ {0,1,2} × B.elev ∈ {0,1,2} × T.elev ∈ {0,1,2}) + destroyed-wall cases + adjacent-tile cases + corner-cut cases

---

## Implementation Notes

*Derived from ADR-0004 §Decision 5, §Decision 8 + GDD §CR-5, §CR-7, §F-4, §F-5, §EC-3, §EC-4:*

- Attack direction enum-mirror constants (add to `map_grid.gd`):
  - `const ATK_DIR_FRONT := 0, ATK_DIR_FLANK := 1, ATK_DIR_REAR := 2`
  - Facing mirrors (already implied by CR-5): `const FACING_NORTH := 0, FACING_EAST := 1, FACING_SOUTH := 2, FACING_WEST := 3`
- Bresenham integer algorithm: use the standard `error`-driven form, NOT floating-point slope. For each `(x, y)` tile produced strictly between `from` and `to` (exclude endpoints), check: `elevation = _elevation_cache[y*cols+x]`; `passable = _passable_base_cache[y*cols+x]`; if `elevation > max(from_elev, to_elev) OR passable == 0`, return false.
- Corner-cut handling (§EC-3): when the Bresenham step's error term crosses exactly zero (diagonal moves through corner), the line passes through the corner of two adjacent tiles. Conservatively check BOTH tiles as intermediates — if either blocks, LoS blocked. This prevents the "shoot through wall gap" exploit. Implement by detecting the diagonal-step case and adding BOTH `(x_prev, y_new)` and `(x_new, y_prev)` as intermediate checks.
- LoS endpoints: always return true without entering the loop if `D(from, to) <= 1` (AC-EDGE-3). Same-tile case (D=0) produces a warning.
- `get_attack_range` algorithm:
  - Manhattan filter: for each tile within `attack_range` of origin (diamond pattern), add to candidate list. O(attack_range²) candidate count.
  - If `apply_los == true`, filter via `has_line_of_sight(origin, candidate)`. Consumer decides per-call whether to apply (melee skips LoS; ranged applies it per GDD §CR-7 "원거리 유닛에만 적용").
  - EXCLUDE origin from result.
- `get_attack_direction` formula: `dc = defender.x - attacker.x`, `dr = defender.y - attacker.y`. Determine `attack_dir: int`:
  - if `abs(dc) >= abs(dr)`: horizontal-axis (EAST if `dc > 0`, WEST if `dc < 0`)
  - else: vertical-axis (SOUTH if `dr > 0`, NORTH if `dr < 0`)
  - Note: `>=` not `>` — this encodes the horizontal-tie-break rule (`abs(dc) == abs(dr)` → horizontal wins).
  - Then: `relative_angle = (attack_dir - defender_facing + 4) % 4`; lookup `{0: FRONT, 1: FLANK, 2: REAR, 3: FLANK}`.
- Same-tile attack (§EC-4): `dc == 0 and dr == 0` → return `FRONT` + `push_warning("ERR_SAME_TILE_ATTACK")`. Deterministic fallback for caller-bug recovery.
- `get_adjacent_units` implementation:
  - Iterate the 4 cardinal offsets `[(0,-1), (1,0), (0,1), (-1,0)]`
  - For each, compute `nidx = nr * cols + nc`; skip if out of bounds
  - Read `uid := _occupant_id_cache[nidx]`; skip if `uid == 0` (no occupant)
  - If `faction != -1 and _occupant_faction_cache[nidx] != faction`: skip
  - Else: append `uid` to PackedInt32Array result
  - Result is NOT de-duplicated — adjacent_units is by-tile, not by-unit; large units occupying multiple tiles would produce duplicates, but MVP assumes 1 tile = 1 unit (ADR-0004 contract).
- `get_occupied_tiles` implementation: single pass over `_occupant_id_cache`; where `cache[i] != 0` AND (faction filter matches if specified), append `Vector2(i % cols, i / cols)` to PackedVector2Array. This is a full-map scan — acceptable because callers (AI, HUD) invoke this at round boundaries, not per-frame.
- For LoS tests, use small fixtures (3-5 tile rows) where the Bresenham path is deterministic and easy to reason about. The 20-case V-3 matrix uses a 7×7 fixture with varied elevations and a known wall — test scaffold defined once, asserted 20 times with different `from/to` pairs.
- Do NOT call `get_tile(coord)` in the LoS hot loop — always read the packed caches.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: `get_movement_range`, `get_path` Dijkstra queries (already complete by the time this story starts)
- Story 007: Performance benchmark for `get_movement_range` at 40×30 (AC-PERF-2)
- Grid Battle's actual attack resolution (this story provides the geometry; damage calc lives in its own epic)
- Fog of war / vision range filtering — GDD §Open Questions #4 (Alpha phase, not MVP)

---

## QA Test Cases

*Authored from GDD + ADR directly (lean mode).*

- **AC-1**: has_line_of_sight adjacent tiles always true (AC-EDGE-3)
  - Given: any 15×15 map; pairs (0,0)-(1,0), (0,0)-(0,1), and any Manhattan-1 pair
  - When: `has_line_of_sight(from, to)`
  - Then: returns `true` without depending on intermediate state (no loop entered)
  - Edge cases: same-tile D=0 → true + `push_warning` captured

- **AC-2**: AC-CR-7 FORTRESS_WALL blocks flat LoS
  - Given: 5×5 PLAINS with a single FORTRESS_WALL at (2,2), is_passable_base=false; attacker (0,2) elev=0, target (4,2) elev=0
  - When: `has_line_of_sight(Vector2i(0,2), Vector2i(4,2))`
  - Then: returns `false` (wall blocks)
  - Edge cases: wall at (2,3) instead — does NOT block LoS from (0,2) to (4,2) (line passes through row=2, not row=3)

- **AC-3**: AC-F-4 elevation max rule
  - Given: 5×5 PLAINS; attacker (0,2) elev=1, target (4,2) elev=0, intermediate tile (2,2) elev=2
  - When: `has_line_of_sight`
  - Then: returns `false` (2 > max(1,0) = 1)
  - Edge cases: same setup with intermediate elev=1 → returns `true` (1 > 1 = false, does not block); attacker elev=2, target elev=0, intermediate elev=2 → returns `true` (2 > max(2,0)=2 = false)

- **AC-4**: V-3 20-case LoS matrix
  - Given: 7×7 fixture with pre-placed elevations and 1 FORTRESS_WALL at (3,3); 20 `(from, to, expected_los)` tuples covering:
    - 3×3×3=27 elevation triple combinations (trimmed to 20 representative cases)
    - 2 destroyed-wall cases (mutation via story-004 API to set STATE_DESTROYED → LoS restored)
    - 2 adjacent-tile cases
    - 2 corner-cut cases (line through tile corner)
  - When: each call to `has_line_of_sight`
  - Then: matches `expected_los` for all 20 cases
  - Edge cases: the fixture is built in `before_test`; cases are table-driven via a PackedArray of tuples

- **AC-5**: Corner-cut conservatism (§EC-3)
  - Given: 3×3 with walls forming a diagonal gap — (0,1) and (1,0) are FORTRESS_WALL; attacker (0,0), target (1,1) at Manhattan D=2
  - When: `has_line_of_sight`
  - Then: returns `false` — both "shortcut" tiles are walls, conservative rule blocks LoS through the corner
  - Edge cases: if only one of (0,1) or (1,0) is a wall, still conservative → still blocked

- **AC-6**: get_attack_range without LoS
  - Given: 5×5 PLAINS; origin (2,2), attack_range=2, apply_los=false
  - When: `get_attack_range(Vector2i(2,2), 2, false)`
  - Then: returned PackedVector2Array contains all tiles within Manhattan 2 of (2,2), EXCLUDING origin — diamond pattern, 12 tiles
  - Edge cases: origin excluded even when `attack_range=0` (returns empty array)

- **AC-7**: get_attack_range with LoS filter
  - Given: same map as AC-2 but add attack_range=5 from (0,2)
  - When: `get_attack_range(Vector2i(0,2), 5, true)`
  - Then: tiles that Bresenham-line through the wall at (2,2) are excluded; tiles off the line-of-wall axis remain
  - Edge cases: attacker at elevation=2 (hill) should see more tiles per elev-max rule

- **AC-8**: AC-F-5 attack direction full matrix
  - Given: defender at (2,2), facing=FACING_NORTH (0)
  - When: attackers at (2,1) [north], (3,2) [east], (2,3) [south], (1,2) [west]
  - Then: returns ATK_DIR_FRONT, ATK_DIR_FLANK, ATK_DIR_REAR, ATK_DIR_FLANK respectively
  - Edge cases: defender facing=FACING_EAST (1); attacker at (3,2) (east) → FRONT; (2,3) (south) → FLANK; (1,2) (west) → REAR; (2,1) (north) → FLANK

- **AC-9**: §EC-4 horizontal tie-break on perfect diagonal
  - Given: defender (2,2) facing=FACING_NORTH; attacker at (4,4) — dc=2, dr=2, abs equal
  - When: `get_attack_direction`
  - Then: `attack_dir` resolves to EAST (horizontal axis wins); `relative_angle = (EAST - NORTH + 4) % 4 = 1` → ATK_DIR_FLANK
  - Edge cases: (0,0) attacker (dc=-2, dr=-2) → attack_dir=WEST; diagonal tie at (3,3) with dc=1, dr=1 → also EAST

- **AC-10**: §EC-4 same-tile attack returns FRONT + warning
  - Given: attacker == defender (both (2,2)), facing irrelevant
  - When: `get_attack_direction(Vector2i(2,2), Vector2i(2,2), 0)`
  - Then: returns ATK_DIR_FRONT; `push_warning("ERR_SAME_TILE_ATTACK")` captured
  - Edge cases: deterministic regardless of defender_facing value

- **AC-11**: get_adjacent_units with faction filter
  - Given: 5×5 map; (2,2) center; (1,2)=ALLY(unit=10), (3,2)=ENEMY(unit=20), (2,1)=ALLY(unit=11), (2,3)=EMPTY
  - When: `get_adjacent_units(Vector2i(2,2))` then same with `faction=FACTION_ALLY` and `faction=FACTION_ENEMY`
  - Then: no-filter returns PackedInt32Array containing 10, 11, 20 (size 3; EMPTY tile skipped); ALLY filter returns [10, 11]; ENEMY filter returns [20]
  - Edge cases: no occupants → empty array; faction=-1 returns all

- **AC-12**: get_occupied_tiles full-map scan
  - Given: 15×15 with 5 occupants (3 ALLY, 2 ENEMY) scattered
  - When: `get_occupied_tiles()` no-filter
  - Then: PackedVector2Array of size 5 containing the 5 coords; ordering MUST be deterministic (row-major scan)
  - Edge cases: `faction=FACTION_ALLY` returns 3-entry array; after one occupant is `clear_occupant`-ed (story-004 API), count drops to 4

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/map_grid_queries_test.gd` — must exist and pass (12 tests covering AC-1..12, including V-3 20-case LoS matrix)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (packed caches), Story 004 (mutation API used for LoS destroyed-wall + occupant tests), Story 005 (not strictly depended on but ordering puts pathfinding first)
- Unlocks: Story 007 (performance story may benchmark LoS alongside Dijkstra), Grid Battle + AI + Formation Bonus + Damage Calc consumer epics (all 4 need at least some of these queries)
