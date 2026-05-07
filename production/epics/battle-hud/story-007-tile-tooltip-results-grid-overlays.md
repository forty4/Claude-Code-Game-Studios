# Story 007: UI-GB-06 Tile Tooltip + show_tile_info() + UI-GB-09 Results + UI-GB-12/13/14 Grid Overlays

> **Epic**: Battle HUD
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI + Integration
> **Manifest Version**: 2026-05-05 (refreshed 2026-05-07 at sprint-10 plan-time per sprint-9 retro PI #3 — manifest delta 2026-04-20 → 2026-05-05 covered ADR-0014/0015 sections; no new forbidden_patterns affecting this story)

## Context

**GDD**: `design/ux/battle-hud.md` v1.1 §3 UI-GB-06 + UI-GB-09 + UI-GB-12 + UI-GB-13 + UI-GB-14 + §3.1 Formation Aura detailed spec
**Requirement**: `TR-battle-hud-005` (UI-GB-06/09/12/13/14 partial), `TR-battle-hud-006` (show_tile_info), `TR-battle-hud-015` (grid-layer overlay positioning + cross-tree NodePath)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015 Battle HUD §4 + §5 + Pillar 2 §8 (Accepted 2026-05-03)
**ADR Decision Summary**: UI-GB-06 Tile Info Tooltip rendered via `show_tile_info(coord: Vector2i)` public method invoked BY InputRouter on Tap Preview Protocol per ADR-0005 line 236. UI-GB-09 End-of-Battle Results renders outcome (VICTORY/DEFEAT/DRAW) on `battle_outcome_resolved` — **Pillar 2 preservation: outcome only, NO fate counter detail** (no per-condition progress numbers; only the categorical outcome). UI-GB-12/13/14 grid-layer overlays mount under `BattleScene/GridLayer` (NOT under HUDLayer/CanvasLayer) per ADR-0016 §2 scene tree topology — cross-tree NodePath references resolved at HUD `_ready()`. Subscribes `formation_bonuses_updated` for UI-GB-13/14 render.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (cross-tree NodePath resolution + Camera2D world-to-screen via `get_canvas_transform()` per advisory D)
**Engine Notes**:
- Camera2D in Godot 4.6 does NOT expose `world_to_screen()` method per godot-specialist 2026-05-03 advisory D. Use `_camera.get_canvas_transform() * world_pos` directly. This is the primary path, not a fallback.
- UI-GB-12/13/14 mount under `GridLayer` Node2D in `scenes/battle/battle_scene.tscn` per ADR-0016 §2. BattleHUD holds `@export var grid_layer_overlays_path: NodePath` resolved at `_ready()`; if path doesn't resolve (missing parent BattleScene at test time), log warning + skip overlay registration (graceful — overlay-less HUD still functions for unit-test fixtures).
- Per-frame zoom-poll for UI-GB-12/13/14 counter-scale gated via `_has_active_grid_overlay()` per godot-specialist revision #3 (avoid `_process()` body when no overlays active). OQ-1 deferred: per-frame poll vs. camera_zoom_changed signal — first-story attempts per-frame poll; if budget breached, raise ADR-0013 amendment to add zoom signal.

**Control Manifest Rules (Presentation layer)**:
- Required: AccessKit-via-Control inheritance — UI-GB-06 + UI-GB-09 expose tooltip + accessibility_label.
- Forbidden (registry):
  - `battle_hud_subscribes_to_hidden_fate_signal` (Pillar 2 — UI-GB-09 must NOT subscribe to hidden_fate_condition_progressed; outcome-only renders from `battle_outcome_resolved` payload's categorical `outcome` field, NOT from the `fate_data` dict's per-condition counters).
  - `battle_hud_hardcoded_localized_strings` (story-008 lint).
- Guardrail: UI-GB-09 results render ≤ 200 ms one-shot per battle (Performance Implications §6); grid-overlay zoom-poll ≤ 0.05 ms per frame when active OR `set_process(false)` when no overlays active.

---

## Acceptance Criteria

*From battle-hud.md §3 UI-GB-06 + UI-GB-09 + UI-GB-12-14 + §3.1 + ADR-0015 §4 + §5 + §8 Pillar 2 lock:*

- [ ] `scenes/battle/elements/ui_gb_06_tile_info_tooltip.tscn` exists with PanelContainer + VBoxContainer holding 4 Labels (terrain_type, elevation, defense_bonus, evasion_bonus). Compact size — must NOT obstruct grid (verify in editor with art-director).
- [ ] `scenes/battle/elements/ui_gb_09_battle_results_screen.tscn` exists with full-screen overlay PanelContainer + VBoxContainer holding: outcome_label (VICTORY/DEFEAT/DRAW), surviving_units_count, turns_elapsed, scenario_rewards_list, "Continue" Button.
- [ ] `scenes/battle/elements/ui_gb_12_tactical_read_extended_range.tscn` — grid-layer overlay; renders 황토 70% opacity tile fills with 讀 micro-glyph 8px upper-left in 묵 ink for TR-extended tiles per battle-hud.md §3 UI-GB-12.
- [ ] `scenes/battle/elements/ui_gb_13_rally_aura.tscn` — grid-layer overlay; renders 황금 #C9A84C tile overlay (opacity scaling per battle-hud.md §3 UI-GB-13: 5%/10%/15% Commander stack → 20%/30%/40% opacity) + 2px logical dashed border for colorblind accessibility per pass-11c R-3.
- [ ] `scenes/battle/elements/ui_gb_14_formation_aura.tscn` — grid-layer overlay; MVP-fallback flat 청록 #3A7D6E 15% opacity + 陣 corner glyph (per battle-hud.md §3.1 fallback tier).
- [ ] `_ui_elements[&"UI-GB-06"]` + `_ui_elements[&"UI-GB-09"]` populated as children of HUD root in `_ready()`.
- [ ] `_grid_layer_overlays: Dictionary[StringName, Node2D]` populated at `_ready()` from cross-tree resolution: `_grid_layer_overlays[&"UI-GB-12"]`, `[&"UI-GB-13"]`, `[&"UI-GB-14"]` resolved via NodePath into BattleScene/GridLayer. If resolution fails (test fixture without parent BattleScene), log warning + initialize as empty dict (graceful degradation).
- [ ] `show_tile_info(coord: Vector2i) -> void` public method body:
  - if `coord == Vector2i(-1, -1)`: hides UI-GB-06, returns
  - else: queries `_map_grid.get_tile(coord) -> TileData` for terrain type / elevation / defense bonus / evasion bonus; queries `_terrain_effect.get_modifier(coord, ...)` for terrain modifier display; populates UI-GB-06 4 Labels via `tr()`-routed strings; positions UI-GB-06 in screen-space via `_camera.get_canvas_transform() * world_pos` derived from `coord`; sets `visible = true`
- [ ] `_on_battle_outcome_resolved(outcome, fate_data)` body:
  - Renders UI-GB-09 with `outcome` value mapped to VICTORY/DEFEAT/DRAW localized strings via `tr(&"hud.outcome.victory")` / `tr(&"hud.outcome.defeat")` / `tr(&"hud.outcome.draw")`
  - Renders surviving units count + turns elapsed (queryable from turn_runner / hp_controller)
  - Renders scenario rewards list per BattleScene-passed config
  - **CRITICAL Pillar 2 preservation**: does NOT read `fate_data` dict's per-condition progress counters; if reading at all, only categorical fields (e.g., total reward count). Per-condition fate progress is HIDDEN per Pillar 2 lock. The `fate_data` parameter is intentionally received per ADR-0014 contract but not surfaced visually beyond the outcome label.
  - Sets `visible = true`; render time < 200 ms one-shot (Performance.get_monitor instrumentation)
- [ ] `_on_formation_bonuses_updated(snapshot)` body:
  - Updates UI-GB-13 Rally aura overlays per Commander positions in snapshot (re-render affected tiles)
  - Updates UI-GB-14 Formation aura overlays per pattern role + relationship bond entries in snapshot
  - Visible-while-active semantics: overlays visible if at least one applicable Commander/formation snapshot present; hidden otherwise
- [ ] UI-GB-12 visibility: derived from selected Strategist unit + TR-extended tile set per `unit_role` query. `_on_unit_selected_changed(unit_id, was_selected)` body extension: if `was_selected == true` AND unit class == Strategist (per `_unit_role.get_class(unit_id)`), update UI-GB-12 with TR-extended tiles per `_unit_role.get_tactical_read_tiles(unit_id) -> Array[Vector2i]` query (verify method exists).
- [ ] Per-frame zoom-poll for grid overlays — `_process(delta)` body gated:
  ```gdscript
  func _process(_delta: float) -> void:
      if not _has_active_grid_overlay():
          return
      var zoom := _camera.get_zoom_value()
      # adjust UI-GB-12/13/14 element scales relative to zoom (counter-scale OR no-op if not needed)
  ```
  OR `set_process(false)` whenever `_has_active_grid_overlay() == false` is the lifecycle invariant (per godot-specialist revision #3 — implementation choice, both acceptable). Pre-MVP: if per-frame poll budget exceeds 0.05 ms p99 (TR-battle-hud-014), raise ADR-0013 amendment requesting `camera_zoom_changed` signal addition.
- [ ] UI-GB-13 dashed border (2px logical) renders for colorblind accessibility per pass-11c R-3 (battle-hud.md §3 UI-GB-13).
- [ ] No `GameBus.*.emit` calls; no `hidden_fate_condition_progressed` token references.
- [ ] All visible strings via `tr()` — locale keys: `hud.outcome.victory`, `hud.outcome.defeat`, `hud.outcome.draw`, `hud.results.surviving_units`, `hud.results.turns_elapsed`, `hud.results.continue`, `hud.tile.terrain_label`, `hud.tile.elevation_label`, `hud.tile.defense_label`, `hud.tile.evasion_label`.

---

## Implementation Notes

*Derived from ADR-0015 §4 + §5 + §8 + battle-hud.md §3 UI-GB-06/09/12-14 + §3.1 + advisory D:*

1. **`show_tile_info` is THE single render entry point** for UI-GB-06 — invoked by InputRouter Tap Preview Protocol per ADR-0005 line 236. The method handles both populate (`coord != (-1,-1)`) and dismiss (`coord == (-1,-1)`) paths. Mirror story-003 `show_unit_info` pattern.

2. **World-to-screen for UI-GB-06 positioning** — per advisory D:
   ```gdscript
   var world_pos := _map_grid.coord_to_world(coord)
   var screen_pos := _camera.get_canvas_transform() * world_pos
   _ui_elements[&"UI-GB-06"].position = screen_pos + tooltip_offset
   ```
   No `Camera2D.world_to_screen()` — Godot 4.6 doesn't expose it.

3. **Pillar 2 preservation in UI-GB-09** — re-read battle-hud.md §3 UI-GB-09 + ADR-0015 §8 carefully. The `battle_outcome_resolved(outcome: int, fate_data: Dictionary)` signal carries `fate_data` for end-of-battle reveal payload, but per Pillar 2 + destiny-branch.md Section B, the HUD MUST NOT surface per-condition fate counters during battle OR at the end-of-battle results screen. The Beat 7 reveal happens elsewhere (post-battle scenario layer per design/gdd/destiny-branch.md). UI-GB-09 reads ONLY the categorical `outcome` enum value (VICTORY=0/DEFEAT=1/DRAW=2). If implementation needs ANY field from `fate_data`, surface in this story for explicit review against Pillar 2 — do NOT silently render fate progress.

4. **Grid-layer overlay cross-tree resolution** — `@export var grid_layer_path: NodePath` declared in `battle_hud.gd`. Default value resolves to `"../GridLayer"` if HUD is `BattleScene/HUDLayer/BattleHUD`. Resolution at `_ready()`:
   ```gdscript
   var grid_layer := get_node_or_null(grid_layer_path) as Node2D
   if grid_layer == null:
       push_warning("BattleHUD: grid_layer_path failed to resolve; UI-GB-12/13/14 disabled")
       return
   # Instantiate UI-GB-12/13/14 element scenes as children of grid_layer
   var ui_gb_12 := preload("res://scenes/battle/elements/ui_gb_12_tactical_read_extended_range.tscn").instantiate()
   grid_layer.add_child(ui_gb_12)
   _grid_layer_overlays[&"UI-GB-12"] = ui_gb_12
   # ... 13 + 14
   ```

5. **UI-GB-13 Rally opacity scaling** — per battle-hud.md §3 UI-GB-13 stack rules:
   - 1 Commander adjacent → 20% opacity
   - 2 Commanders → 30%
   - 3+ Commanders (15% cap) → 40%
   - Commander itself does NOT render Rally on its own tile; instead 독전(獨戰) micro-seal at 8px upper-right at 60% opacity in 황금 ink (renders only when ≥1 ally in range)
   - Forecast tooltip line in UI-GB-04 §4.1 Section 6 — already shipped story-006 if applicable (verify Rally line precedence in story-006 implementation)
   Compute Commander adjacency from `_grid_controller.get_active_commanders() -> Array[int]` query — verify method exists; if not, raise same-patch addendum.

6. **UI-GB-14 Formation aura MVP-fallback** — flat 청록 15% opacity tint + 陣 corner glyph per battle-hud.md §3.1 fallback tier. Octagonal pulsing outline + 緣 bond glyph is post-MVP per fallback tier disclaimer.

7. **UI-GB-12 TacticalRead extension** — per battle-hud.md §3 UI-GB-12 + grid-battle.md CR-14 v5.0:
   - Strategist-only (verify `_unit_role.get_class(unit_id) == UnitClass.STRATEGIST`)
   - Natural attack range: 황토 25% opacity
   - TR-extended tiles (within `tactical_read_extension_tiles = 1` beyond natural range): 황토 70% opacity + 讀 micro-glyph 8px upper-left in 묵 ink
   - Commander units do NOT render UI-GB-12 (Commander v5.0 passive is `passive_rally`, not TR per unit-role.md CR-2)

8. **`_has_active_grid_overlay()` helper** — returns `true` if any of UI-GB-12/13/14 is currently visible. Used to gate `_process` body. If all three hidden, can `set_process(false)` per revision #3 — choose more performant path at impl time.

9. **i18n locale keys** (declare in same patch):
   - `hud.outcome.victory` → "Victory"
   - `hud.outcome.defeat` → "Defeat"
   - `hud.outcome.draw` → "Draw"
   - `hud.results.surviving_units` → "Surviving units: %d"
   - `hud.results.turns_elapsed` → "Turns: %d"
   - `hud.results.continue` → "Continue"
   - `hud.tile.terrain_label` → "Terrain"
   - `hud.tile.elevation_label` → "Elevation"
   - `hud.tile.defense_label` → "DEF +%d"
   - `hud.tile.evasion_label` → "EV +%d"

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: 6 CI lints + verification summary doc + 7 Verification items closure (this story authors source compliantly from start; lints automate).
- Future ADR (post-MVP): UI-GB-14 octagonal pulsing outline + 緣 bond glyph upgrade from fallback tier (per battle-hud.md §3.1 fallback tier).
- Future ADR (post-MVP): UI-GB-12 zoom-event signal subscription (if per-frame poll budget breached, raise ADR-0013 amendment).
- Future ADR (post-MVP): UI-GB-13 Commander 독전 micro-seal animation (current MVP is static).

---

## QA Test Cases

*UI + Integration story — automated tests for state transitions; manual for visual + Pillar 2 audit.*

- **AC-1: 5 elements + cross-tree overlays mount at _ready()**
  - Setup: instantiate BattleScene with HUD child + GridLayer sibling (full scene tree)
  - Verify: `_ui_elements[&"UI-GB-06/09"]` populated as HUD-root children + visible == false; `_grid_layer_overlays[&"UI-GB-12/13/14"]` populated as GridLayer children
  - Pass condition: assertions pass; if test fixture lacks GridLayer parent, `_grid_layer_overlays` is empty AND a warning is logged (graceful degradation)

- **AC-2: show_tile_info(coord) populates UI-GB-06 from map_grid + terrain_effect**
  - Given: map_grid stub returning `TileData{terrain=GRASS, elevation=1, defense_bonus=10, evasion_bonus=5}` for `coord = Vector2i(3, 4)`; terrain_effect stub returning modifier
  - When: `hud.show_tile_info(Vector2i(3, 4))`
  - Then: UI-GB-06 visible == true; 4 Labels render the values via `tr()`-routed format strings; position derived from `_camera.get_canvas_transform() * world_pos`
  - Edge cases: tile data missing (`get_tile` returns null) → log warning + render placeholder OR keep UI-GB-06 hidden

- **AC-3: show_tile_info(Vector2i(-1, -1)) dismisses UI-GB-06**
  - Given: AC-2 happy state
  - When: `hud.show_tile_info(Vector2i(-1, -1))`
  - Then: UI-GB-06 visible == false
  - Edge cases: dismiss when already hidden — no-op

- **AC-4: battle_outcome_resolved renders UI-GB-09 with outcome only — Pillar 2 lock**
  - Given: turn_runner stub returning turns elapsed = 12; hp_controller stub returning surviving units count = 3
  - When: `_grid_controller.battle_outcome_resolved.emit(BattleOutcome.VICTORY, {"hidden_fate_progress": {...}})` (deferred → flush)
  - Then: UI-GB-09 visible == true; outcome label text resolves from `tr(&"hud.outcome.victory")`; surviving units + turns rendered; **fate_data dict's per-condition counters do NOT appear in any UI-GB-09 child Label** (assertion: walk UI-GB-09 child tree + assert no Label.text contains a per-condition fate counter value from the test payload)
  - Edge cases: outcome = DEFEAT → `tr(&"hud.outcome.defeat")`; outcome = DRAW → `tr(&"hud.outcome.draw")`

- **AC-5: UI-GB-09 results render ≤ 200ms (Performance gate)**
  - Setup: headless mode; trigger `battle_outcome_resolved` 100 iterations with realistic stubs
  - Verify: avg + p99 render time recorded; p99 < 200 ms
  - Pass condition: per TR-battle-hud-014 Performance Implications

- **AC-6: formation_bonuses_updated re-renders UI-GB-13/14**
  - Given: snapshot dict with 1 Commander at coord (2,2) + 1 ally at (3,2) + 1 ally at (2,3); pattern role active for ally pair
  - When: `GameBus.formation_bonuses_updated.emit(snapshot)` (deferred → flush)
  - Then: UI-GB-13 Rally aura visible on (3,2) and (2,3) tiles at 20% opacity (1 Commander adjacent → tier 1); UI-GB-14 Formation aura visible on pattern role tiles
  - Edge cases: empty snapshot → all overlays hidden; Commander dies (next snapshot lacks Commander) → Rally overlay disappears on next render

- **AC-7: UI-GB-12 TacticalRead renders for Strategist + hidden for Commander**
  - Given: `_unit_role.get_class(42)` returns STRATEGIST; `get_tactical_read_tiles(42)` returns `[Vector2i(5,5), Vector2i(6,5)]` (TR-extended)
  - When: `_grid_controller.unit_selected_changed.emit(42, true)` (deferred → flush)
  - Then: UI-GB-12 renders TR-extended tiles at 황토 70% opacity + 讀 glyph
  - Edge cases: Commander unit selected → UI-GB-12 hidden (Commander has no TR per CR-14)

- **AC-8: Per-frame zoom-poll budget (TR-battle-hud-014)**
  - Setup: headless mode with one of UI-GB-12/13/14 active; sample `Time.get_ticks_usec()` over 1000 `_process` calls
  - Verify: avg per-call cost ≤ 0.05 ms; if breached, raise ADR-0013 amendment for camera_zoom_changed signal
  - Pass condition: budget met OR amendment raised

- **AC-9: Pillar 2 audit — no fate counter visible (manual + grep)**
  - Setup: open `src/feature/battle_hud/battle_hud.gd` + UI-GB-09 element script
  - Verify: zero references to `hidden_fate_condition_progressed` token; zero string-formatting of any `fate_data` dict's per-condition keys; UI-GB-09 reads `outcome` field only OR aggregate fields explicitly approved per Pillar 2 review
  - Pass condition: `grep -c 'hidden_fate_condition_progressed' src/feature/battle_hud/` returns 0; `grep` for fate_data field-name usage is human-reviewed and recorded in `production/qa/evidence/battle-hud-story-007-evidence.md` (story-008 lint automates the token-absence check)

- **AC-10: UI-GB-13 dashed border accessibility (manual visual)**
  - Setup: render UI-GB-13 in editor or test scene
  - Verify: 2px logical dashed border in 황금 80% opacity around each Rally-affected tile, visible regardless of fill opacity
  - Pass condition: shape-based colorblind indicator visible per pass-11c R-3; document outcome in evidence doc

---

## Test Evidence

**Story Type**: UI + Integration + Performance (zoom-poll + results render)
**Required evidence**:
- Integration test: `tests/integration/feature/battle_hud/battle_hud_overlays_test.gd` covers AC-1 through AC-7 + AC-8 (perf)
- Manual: `production/qa/evidence/battle-hud-story-007-evidence.md` covers AC-9 (Pillar 2 audit) + AC-10 (dashed border visual)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (final UI-element batch comes after forecast — minimizes simultaneous mid-air UI work)
- Unlocks: Story 008 (epic-terminal lints + verification summary)
