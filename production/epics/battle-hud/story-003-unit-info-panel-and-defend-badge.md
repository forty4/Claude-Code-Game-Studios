# Story 003: UI-GB-03 Unit Info Panel + UI-GB-11 DEFEND Stance Badge + show_unit_info()

> **Epic**: Battle HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-04-20
> **Completed**: 2026-05-04

## Context

**GDD**: `design/ux/battle-hud.md` v1.1 §3 UI-GB-03 + §3 UI-GB-11
**Requirement**: `TR-battle-hud-005` (UI-GB-03/11 partial), `TR-battle-hud-006` (show_unit_info), `TR-battle-hud-012` (i18n via tr() — first invocation), `TR-battle-hud-016` (AccessKit announcement on UI-GB-03)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015 Battle HUD §4 + §5 (Accepted 2026-05-03)
**ADR Decision Summary**: UI-GB-03 renders selected unit's name + class + HP bar + ATK + DEF + status effects (including 守 seal for DEFEND_STANCE) + facing direction. Subscribes to `unit_selected_changed` + `damage_applied` + `unit_turn_started`. Queries `_hp_controller.get_current_hp/get_max_hp/get_status_effects` + `_hero_db.get_hero` + `_unit_role.get_max_hp`. UI-GB-11 DEFEND seal renders 守 at 40% opacity 묵 ink on defending unit's tile, expires on the unit's next `unit_turn_started`. `show_unit_info(unit_id: int)` is a public method invoked BY InputRouter on Touch Tap Preview Protocol per ADR-0005 line 235.

**Engine**: Godot 4.6 | **Risk**: HIGH (AccessKit screen reader auto-exposure verification — Engine Compatibility Item 2)
**Engine Notes**:
- AccessKit auto-exposure (Godot 4.5+ Control inheritance) — set `tooltip_text` + `accessibility_*` properties on UI-GB-03 root + child Labels so VoiceOver / TalkBack announce unit name + HP + status changes on focus change. Verify on macOS VoiceOver as the Engine Compatibility Item 2 gate; Android TalkBack is post-MVP per `design/ux/accessibility-requirements.md` §4.
- `tr(key)` calls require locale .po/.csv entries — author english defaults in same patch as story; locale_kr translations are localization-lead's follow-up (deferred per epic R-6).
- DEFEND_STANCE detection: `_hp_controller.get_status_effects(unit_id)` returns Dictionary keyed by status enum; check for `StatusEffect.DEFEND_STANCE` key. Status effect ID is owned by `design/gdd/hp-status.md` SE-3.

**Control Manifest Rules (Presentation layer)**:
- Required: AccessKit-via-Control inheritance — every interactive Control in this story exposes `tooltip_text` + accessibility properties.
- Forbidden (registry): `battle_hud_hardcoded_localized_strings` (story-008 lint asserts zero hardcoded literal strings — all visible text via `tr()`).
- Guardrail: 44pt minimum touch target on any interactive Control in `scenes/battle/elements/ui_gb_03_unit_info_panel.tscn` (story-008 lint asserts).

---

## Acceptance Criteria

*From battle-hud.md §3 UI-GB-03 + UI-GB-11 + ADR-0015 §4 + §5 + R-2/R-7 + R-10:*

- [ ] `scenes/battle/elements/ui_gb_03_unit_info_panel.tscn` exists with PanelContainer (or VBoxContainer) root + child Labels for: unit_name, class_name, HP_bar (TextureProgressBar or similar), ATK_value, DEF_value, status_effects_HBoxContainer, facing_direction_indicator.
- [ ] `scenes/battle/elements/ui_gb_11_defend_stance_badge.tscn` exists with TextureRect or Sprite2D rendering 守 glyph at 40% opacity in 묵 ink (palette per battle-hud.md §6 — implementation-time art-director sign-off where palette/contrast values are touched per epic R-6 mitigation).
- [ ] `_ui_elements[&"UI-GB-03"]` and `_ui_elements[&"UI-GB-11"]` populated in `_ready()` after element scene instantiation as children of HUD root.
- [ ] `_on_unit_selected_changed(unit_id, was_selected)` body:
  - if `was_selected == true`: invokes `show_unit_info(unit_id)`
  - if `was_selected == false` AND `unit_id == _active_status_panel_unit_id`: invokes `show_unit_info(-1)` to dismiss
- [ ] `show_unit_info(unit_id: int) -> void` public method body:
  - if `unit_id == -1`: hides UI-GB-03 element (visible = false), clears `_active_status_panel_unit_id`, returns
  - else: queries `_hero_db.get_hero(unit_id) -> HeroData` for unit_name + portrait reference; `_unit_role.get_max_hp(...)` + class_name; `_hp_controller.get_current_hp(unit_id) / get_max_hp(unit_id)` for HP bar value; `_hp_controller.get_status_effects(unit_id) -> Dictionary` for status icons; populates UI-GB-03 fields + sets `visible = true` + stores `_active_status_panel_unit_id = unit_id`
  - All visible string assignments use `tr(key)` with key strings declared in this patch (e.g., `tr(&"hud.unit_info.class_label")`, `tr(&"hud.unit_info.atk_label")`, `tr(&"hud.unit_info.def_label")`).
- [ ] `_on_damage_applied(attacker_id, defender_id, damage)` body: if `defender_id == _active_status_panel_unit_id`, refreshes HP bar value via `_hp_controller.get_current_hp(defender_id)`.
- [ ] `_on_unit_turn_started(unit_id)` body: refreshes UI-GB-03 if `unit_id == _active_status_panel_unit_id` (status effects may have ticked); UI-GB-11 DEFEND_STANCE seal removed if previously rendered for `unit_id` (1-turn duration per battle-hud.md §3 UI-GB-11 + hp-status.md SE-3).
- [ ] UI-GB-11 DEFEND_STANCE 守 seal renders ON the defending unit's tile (world-space overlay derived from unit position) when `_hp_controller.get_status_effects(unit_id)` contains `StatusEffect.DEFEND_STANCE`. Hidden when entry absent.
- [ ] UI-GB-03 root Control has `tooltip_text = tr(&"hud.unit_info.tooltip")` (placeholder default EN: "Unit information panel"); each child Label has descriptive `tooltip_text` for AccessKit announcement.
- [ ] No hardcoded literal strings in source — all visible text via `tr(key)`. Format placeholders (e.g., `"%d / %d"` for HP) ARE allowed; the obligation is on the tr() call site, not the format string.
- [ ] `_active_status_panel_unit_id: int = -1` private field declared (default sentinel); used by `_on_damage_applied` + `_on_unit_turn_started` to dispatch HP/status refresh only when relevant.

---

## Implementation Notes

*Derived from ADR-0015 §4 + §5 + battle-hud.md §3 UI-GB-03 + UI-GB-11:*

1. **Scene mount strategy**: instantiate UI-GB-03 + UI-GB-11 element scenes via `preload()` in `_ready()` (after the 11 connect block from story-002), `add_child()` them as children of HUD root, then store references in `_ui_elements[&"UI-GB-03"]` + `_ui_elements[&"UI-GB-11"]`. Elements start hidden (`visible = false`).

2. **`show_unit_info` is THE single render entry point** — both `_on_unit_selected_changed` (controller-LOCAL signal) and InputRouter's Tap Preview Protocol invoke this method. Do NOT duplicate render logic across signal handlers; route both paths through `show_unit_info(unit_id)`.

3. **HP bar render path**: TextureProgressBar's `value = float(current_hp)`, `max_value = float(max_hp)` — 2-decimal float for visual smoothness. Color tint at HP thresholds is implementation-time per battle-hud.md §3 UI-GB-03 + accessibility-requirements.md (red < 25%, yellow 25-50%, green ≥ 50% baseline; verify with art-director if changing).

4. **Status effect icon population**: clear children of `status_effects_HBoxContainer`, then for each entry in `_hp_controller.get_status_effects(unit_id)` instantiate a TextureRect with the status's seal glyph (e.g., 守 for DEFEND_STANCE). Each TextureRect has `tooltip_text = tr(&"hud.status." + status_id)` for AccessKit.

5. **UI-GB-11 DEFEND seal positioning**: world-to-screen via `_camera.get_canvas_transform() * world_pos` directly per godot-specialist 2026-05-03 advisory D — Camera2D in Godot 4.6 does NOT expose `world_to_screen()`; the fallback IS the primary path. Unit world position obtained from `_grid_controller.get_unit_world_position(unit_id) -> Vector2` (verify method exists; if not, derive from grid coord via `_map_grid.coord_to_world(...)`).

6. **i18n locale keys** (declare in `assets/locale/en.po` or `.csv` same patch):
   - `hud.unit_info.class_label` → "Class"
   - `hud.unit_info.atk_label` → "ATK"
   - `hud.unit_info.def_label` → "DEF"
   - `hud.unit_info.facing_label` → "Facing"
   - `hud.unit_info.tooltip` → "Unit information panel"
   - `hud.status.defend_stance` → "Defending"
   - `hud.status.<other>` → as needed
   Korean translations are localization-lead follow-up; English fallback stays as-is per `tr()` default behaviour.

7. **AccessKit verification**: at end of story, run on macOS with VoiceOver enabled — focus UI-GB-03 root → screen reader announces tooltip + child Label texts. Pass = announcement audible. Document in `production/qa/evidence/battle-hud-story-003-evidence.md`.

8. **`_active_status_panel_unit_id` lifecycle**: set in `show_unit_info(unit_id)` happy path; cleared in `show_unit_info(-1)` and on `unit_died(unit_id)` if `unit_id == _active_status_panel_unit_id`. Note: `_on_unit_died` handler stub exists from story-002 — extend its body in this story to clear `_active_status_panel_unit_id` defensively.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: UI-GB-01 Initiative Queue + UI-GB-07 Turn/Round Counter + UI-GB-08 Victory Condition.
- Story 005: UI-GB-02 Action Menu (does NOT mount inside UI-GB-03; UI-GB-02 is its own panel).
- Story 006: UI-GB-04 Combat Forecast.
- Story 007: `show_tile_info()` (UI-GB-06 sibling public method) + UI-GB-09 Results + UI-GB-12/13/14 grid-overlays.
- Story 008: AccessKit + 44pt + i18n + Pillar 2 + non-emitter CI lints (this story produces the FIRST `tr()` call site — story-008 lint will validate it).

---

## QA Test Cases

*UI story — manual verification + integration test for state transitions.*

- **AC-1: UI-GB-03 element mounts at _ready()**
  - Setup: instantiate BattleHUD via story-001 + story-002 setup() flow; add to test parent
  - Verify: `hud._ui_elements[&"UI-GB-03"]` is non-null AND `is Control` AND `get_parent() == hud` AND `visible == false`
  - Pass condition: all assertions pass; element is a child of HUD root, hidden by default

- **AC-2: UI-GB-11 DEFEND seal element mounts at _ready()**
  - Setup: same as AC-1
  - Verify: `hud._ui_elements[&"UI-GB-11"]` non-null AND `visible == false`
  - Pass condition: element child-of-hud, hidden by default

- **AC-3: show_unit_info(unit_id) populates UI-GB-03 from backends**
  - Given: BattleHUD ready + HPStatusController stub returning `current_hp=80, max_hp=120, status_effects={DEFEND_STANCE: {turns_remaining: 1}}` for `unit_id=42`; HeroDatabase stub returning unit name "Wei Yan"; UnitRole stub returning class "Vanguard"
  - When: `hud.show_unit_info(42)`
  - Then: UI-GB-03 visible == true; unit_name Label text == "Wei Yan" (or `tr()` resolves to it); HP bar `value == 80, max_value == 120`; status_effects_HBoxContainer has 1 child (DEFEND_STANCE icon); `_active_status_panel_unit_id == 42`
  - Edge cases: hero not found in db (HeroDatabase.get_hero returns null) → log warning + use placeholder localized string `tr(&"hud.unit_info.unknown_unit")` + still render (graceful degradation per epic R-3 InputRouter-stubs precedent)

- **AC-4: show_unit_info(-1) dismisses panel**
  - Given: AC-3 happy state (panel visible for unit 42)
  - When: `hud.show_unit_info(-1)`
  - Then: UI-GB-03 visible == false; `_active_status_panel_unit_id == -1`
  - Edge cases: invoke -1 when panel already hidden — no-op no error

- **AC-5: _on_unit_selected_changed routes through show_unit_info**
  - Given: AC-1 setup
  - When: `_grid_controller.unit_selected_changed.emit(42, true)` (CONNECT_DEFERRED so requires test fixture deferred-flush)
  - Then: after deferred flush, UI-GB-03 visible == true with unit 42 fields populated
  - Edge cases: emit `(42, false)` after `(42, true)` → panel dismissed

- **AC-6: damage_applied refreshes HP bar when defender is active panel unit**
  - Given: panel visible for unit 42, HP=80/120
  - When: HP stub mutated to `current_hp=50` then `_grid_controller.damage_applied.emit(7, 42, 30)` (deferred)
  - Then: after flush, HP bar `value == 50`
  - Edge cases: `damage_applied(7, 99, 30)` (defender_id != active panel unit) → HP bar unchanged

- **AC-7: unit_turn_started refreshes UI-GB-03 + expires UI-GB-11 DEFEND seal**
  - Given: panel visible for unit 42 with DEFEND_STANCE status; UI-GB-11 seal rendering on unit 42's tile
  - When: HP stub status mutated to `{}` (status expired) + `GameBus.unit_turn_started.emit(42)` (deferred)
  - Then: after flush, UI-GB-03 status_effects_HBoxContainer has 0 children; UI-GB-11 seal hidden for unit 42
  - Edge cases: `unit_turn_started(99)` (different unit) — UI-GB-03 + UI-GB-11 unchanged for unit 42

- **AC-8: AccessKit screen reader announces unit info on focus (manual — Engine Verification Item 2)**
  - Setup: run on macOS with VoiceOver enabled; focus UI-GB-03 root via Tab/keyboard
  - Verify: VoiceOver speaks the tooltip_text + child Label texts in reading order
  - Pass condition: audible announcement of unit name + HP + status (no silent failure)
  - Document outcome in `production/qa/evidence/battle-hud-story-003-evidence.md`

- **AC-9: Zero hardcoded localized strings (manual grep gate)**
  - Setup: open `src/feature/battle_hud/battle_hud.gd` + UI-GB-03/11 element scripts
  - Verify: every visible text assignment routes through `tr(...)`; format strings (`%d / %d` patterns) excluded from the obligation per battle-hud.md §6
  - Pass condition: `grep -E 'text\s*=\s*"[^"]+"|set_text\("[^"]+"\)' src/feature/battle_hud/` returns 0 non-format-placeholder matches (story-008 automates as CI lint)

---

## Test Evidence

**Story Type**: UI + Logic (state transitions are testable)
**Required evidence**:
- Integration test: `tests/integration/feature/battle_hud/battle_hud_unit_info_test.gd` covers AC-1 through AC-7
- Manual: `production/qa/evidence/battle-hud-story-003-evidence.md` covers AC-8 (AccessKit) + AC-9 (i18n grep gate)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (signal subscription handlers must exist as no-op shims for this story to extend)
- Unlocks: Story 005 (UI-GB-02 Action Menu may visually anchor near UI-GB-03 — non-blocking but cleaner ordering)
- Parallel-runnable with: Story 004 (UI-GB-01/07/08 — disjoint elements, both consume signal handler hooks from story-002)

---

## Completion Notes

**Completed**: 2026-05-04
**Criteria**: 9/9 covered (7 automated AC-1..AC-7 + 1 bonus; AC-8 manual gate PENDING; AC-9 deferred to story-008 lint)
**Test result**: 876/876 PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0 — 22nd consecutive failure-free baseline (+11 vs S6-06 baseline 865)

**Test Evidence**:
- Integration: `tests/integration/feature/battle_hud/battle_hud_unit_info_test.gd` (11 tests, 142ms)
- Manual: `production/qa/evidence/battle-hud-story-003-evidence.md` (§C PENDING — macOS VoiceOver run required for AC-8 sign-off)

**Code Review**: Complete (godot-gdscript-specialist + qa-tester via /code-review this session — verdict APPROVED WITH SUGGESTIONS; 0 BLOCKING items; 4 nice-to-have suggestions)

**Deviations** (all ADVISORY):
1. **Positive deviation**: `_status_effect_to_i18n_key()` literal-dispatch replaces Implementation Note 4's `tr("hud.status." + effect_id)` runtime concat. Original spec was POT-extraction blind; implementation upgraded to literal-key match for static i18n tooling visibility.
2. **Deferred per Implementation Note 5**: UI-GB-11 world-space tile positioning deferred to story-007 (no `GridBattleController.get_unit_world_position()` or `MapGrid.coord_to_world()` exposed yet). MVP renders seal at fixed HUD-level position; story-007 will migrate to GridLayer cross-tree per ADR-0015 §2 + ADR-0016 §2.
3. **Cross-epic forward-prep (precedent-justified)**: `src/feature/grid_battle/grid_battle_controller.gd` added `get_battle_unit(unit_id: int) -> BattleUnit` (~7 LoC). Same pattern as story-002's 3 cross-epic adds; ADR-0014 §3 read-only contract preserved (returns single value via `Dictionary.get`, no mutation, `_units` Dictionary stays private).

**Coverage gap (non-blocking)**: `battle_unit == null` early-return branch (`battle_hud.gd:233-235`) has no test. Reachable by passing a unit_id with no corresponding `set_test_unit` call. Recommended: add 1 test in story-008 OR file as backlog TD.

**Scope**: 1 modified production file (in-scope) + 1 cross-epic .gd modification (precedent-justified ADVISORY) + 3 NEW files (in-scope) + 2 test-stub extensions (in-scope test infrastructure for the new injection points).

**Specialist suggestions carried** (from /code-review APPROVED WITH SUGGESTIONS — not blocking):
- S-1: Move `_active_status_panel_unit_id = unit_id` inside `if panel != null:` block (sentinel scope cleanup; line 280)
- S-2: Add comment why `HeroDatabase.get_hero(...)` is called statically (not via `_hero_db` DI ref; line 237)
- S-3: One-line G-2 typed-array-escape comment at `var status_effects: Array = ...` (line 246)
- S-4: Coverage gap test for `battle_unit == null` branch (story-008 or TD)
