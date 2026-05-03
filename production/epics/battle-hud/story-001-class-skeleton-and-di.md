# Story 001: BattleHUD Class Skeleton + 9-Param DI Setup

> **Epic**: Battle HUD
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/ux/battle-hud.md` v1.1 (UX spec — UI specs live in `design/ux/`, not `design/gdd/`)
**Requirement**: `TR-battle-hud-001`, `TR-battle-hud-002`, `TR-battle-hud-014` (perf-budget context)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015 Battle HUD (Accepted 2026-05-03)
**ADR Decision Summary**: BattleHUD is a battle-scoped Control mounted under `BattleScene/HUDLayer/BattleHUD`. 9-param `setup()` DI seam called BEFORE `add_child()`; `_ready()` asserts all 9 backends non-null. `extends Control` (NOT CanvasLayer) so AccessKit auto-exposure inherits.

**Engine**: Godot 4.6 | **Risk**: HIGH (UI domain — Control inheritance + AccessKit + dual-focus + recursive Control disable)
**Engine Notes**:
- `extends Control` is REQUIRED — `extends CanvasLayer` would lose Control's input routing + focus management + theme inheritance + AccessKit auto-exposure (Alternative 1 rejected per ADR-0015 §1).
- Typed `Dictionary[StringName, Control]` syntax is **verified at first-story implementation** per ADR-0015 review-time advisory A-4 — softened from authoring-time "stable in 4.6" wording. If syntax errors at parse, fall back to untyped `Dictionary` with documented type-comment.
- Mount the Control at full viewport via `set_anchors_preset(Control.PRESET_FULL_RECT)` in `_ready()` — direct API call, no NodePath indirection.

**Control Manifest Rules (Presentation layer)**:
- Required: AccessKit screen reader integration on Control nodes (Godot 4.5+) — `extends Control` inheritance grants this for free; do NOT replace with CanvasLayer.
- Forbidden (registry): `battle_hud_signal_emission` (zero `GameBus.*.emit` calls), `battle_hud_subscribes_to_hidden_fate_signal` (Pillar 2 lock — story 008 lints).
- Guardrail: per-frame steady-state HUD update ≤ 0.1ms; instance memory ≈ 5 KB total (12 fields + 14 element refs + 9 backend refs).

---

## Acceptance Criteria

*From ADR-0015 §1, §3, §10 + battle-hud.md §3 element list, scoped to skeleton-only:*

- [ ] `src/feature/battle_hud/battle_hud.gd` exists with `class_name BattleHUD extends Control`.
- [ ] `setup(camera, hp_controller, turn_runner, grid_controller, input_router, map_grid, terrain_effect, unit_role, hero_db) -> void` is a 9-param DI seam — all 9 args typed (`BattleCamera, HPStatusController, TurnOrderRunner, GridBattleController, InputRouter, MapGrid, TerrainEffect, UnitRole, HeroDatabase`).
- [ ] `_ready()` asserts all 9 backend deps non-null (one `assert(_backend != null, "...")` per dep) BEFORE doing any other work.
- [ ] `_ready()` calls `set_anchors_preset(Control.PRESET_FULL_RECT)`.
- [ ] `_handle_signal(signal_name: StringName, args: Array) -> void` test-seam method exists with empty body (handlers wired in story-002).
- [ ] `scenes/battle/battle_hud.tscn` exists with `BattleHUD` as root Control; mounted under `CanvasLayer` via parent path `BattleScene/HUDLayer/BattleHUD` (path realised by ADR-0016 BattleScene wiring — story does NOT instantiate BattleScene; mount-point is the .tscn file existence + tree contract).
- [ ] No `_process()` body OR `set_process(false)` called in `_ready()` (per godot-specialist authoring revision #3 — no per-frame work in skeleton; story-007 may re-enable for grid-overlay zoom-poll).
- [ ] No `GameBus.*.emit` calls anywhere in source (non-emitter discipline; story-008 lint enforces).
- [ ] No `hidden_fate_condition_progressed` token in source (Pillar 2 lock; story-008 lint enforces).

---

## Implementation Notes

*Derived from ADR-0015 §1, §3, §10 Implementation Guidelines + Migration Plan:*

1. **DI seam ordering**: `setup()` is invoked BEFORE `add_child()` per battle-scoped Node mandate (ADR-0010/0011/0013/0014 5-precedent pattern). Pattern in test:
   ```gdscript
   var hud := preload("res://src/feature/battle_hud/battle_hud.gd").new()
   hud.setup(camera_stub, hp_stub, turn_stub, grid_stub, input_stub, map_stub, terrain_stub, role_stub, hero_stub)
   parent.add_child(hud)  # _ready() fires here; all 9 backends already wired
   ```

2. **Backend storage**: store all 9 deps as private `_<backend>: <Type>` typed instance fields (e.g., `_camera: BattleCamera`). Do NOT use `@onready` — DI happens pre-add_child, not at scene-tree-ready time.

3. **`_handle_signal` test seam**: empty body in this story; subclass test override pattern proven by ADR-0014 GridBattleController + ADR-0010 HPStatusController. Signature: `func _handle_signal(signal_name: StringName, args: Array) -> void`. Args is intentionally untyped Array — 11 handlers in story-002 have heterogeneous arg shapes (per godot-specialist revision #2).

4. **`_exit_tree()` skeleton** — declare `func _exit_tree() -> void` with empty body in this story; story-002 fills in 11 disconnect calls. `disconnect()` is a safe no-op on unconnected signals in Godot 4.x; defensive guards retained per godot-specialist revision #1 but NOT correctness requirement.

5. **`_ui_elements: Dictionary` field declaration**: declare `var _ui_elements: Dictionary[StringName, Control] = {}` (typed Dictionary syntax — verify parses at first compile per advisory A-4; if rejected, downgrade to `var _ui_elements: Dictionary = {}` + a docstring noting expected key/value types). Do NOT populate yet — stories 003-007 fill the 14 entries.

6. **Scene file `.tscn`**: root Control, name `BattleHUD`, attach `battle_hud.gd`. No child nodes in this story. `anchor_*` properties set via PRESET_FULL_RECT in `_ready()` rather than via .tscn editor — keeps the .tscn minimal and code-driven.

7. **No InputRouter behavioural integration yet** — `_input_router` is held as a typed reference; story-002 wires the 2 GameBus signal subscriptions; story-005 + story-007 invoke `_input_router._handle_event(synthetic_event)` for two-tap / undo flows.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 11 GameBus signal subscriptions + per-handler stubs + `_exit_tree()` 11-disconnect body + S5 INPUT_BLOCKED `MOUSE_FILTER_IGNORE` toggle.
- Story 003: UI-GB-03 Unit Info Panel + UI-GB-11 DEFEND Stance Badge child element scenes + `show_unit_info()` body + i18n `tr()` first call site.
- Story 004: UI-GB-01/07/08 child element scenes.
- Story 005: UI-GB-02/05/10 child element scenes + two-tap timer state.
- Story 006: UI-GB-04 forecast + FORECAST_RENDER_BUDGET_MS BalanceConstants entry.
- Story 007: UI-GB-06 tile tooltip + UI-GB-09 results + UI-GB-12/13/14 grid-overlays + `show_tile_info()` body.
- Story 008: 6 CI lints + verification summary doc + 7 Verification items closure.

---

## QA Test Cases

*All Logic — automated unit tests required.*

- **AC-1: BattleHUD class declaration**
  - Given: a fresh test fixture
  - When: `preload("res://src/feature/battle_hud/battle_hud.gd")` loads + `.new()` instantiates
  - Then: instance `is BattleHUD` AND `is Control`; `class_name` resolves to `BattleHUD`
  - Edge cases: confirm `is CanvasLayer` returns FALSE (Control extends CanvasItem not CanvasLayer)

- **AC-2: 9-param setup() signature**
  - Given: a fresh BattleHUD instance + 9 stub backend instances
  - When: `hud.setup(camera, hp, turn, grid, input, map, terrain, role, hero)` invoked
  - Then: no error; all 9 private `_<backend>` fields are wired to the passed instances
  - Edge cases: invoking setup() twice on same instance — second call replaces references (no special re-entry guard required at this story; ADR does not mandate single-shot)

- **AC-3: _ready() asserts all 9 backends non-null**
  - Given: a fresh BattleHUD instance with `setup()` skipped (all 9 backends = null)
  - When: `parent.add_child(hud)` triggers `_ready()`
  - Then: assertion failure (one of 9 `assert(_<backend> != null, ...)` triggers); test confirms one assertion fails per missing backend (parameterised: 9 sub-cases, one per backend null)
  - Edge cases: all 9 wired → no assertion fires; happy path

- **AC-4: _ready() calls PRESET_FULL_RECT**
  - Given: a fresh BattleHUD added to parent with all 9 backends wired
  - When: `_ready()` completes
  - Then: `hud.anchor_left == 0.0`, `anchor_top == 0.0`, `anchor_right == 1.0`, `anchor_bottom == 1.0` (PRESET_FULL_RECT outcomes)
  - Edge cases: parent Control with non-default anchors — PRESET_FULL_RECT overrides locally

- **AC-5: _handle_signal seam empty in this story**
  - Given: a fresh BattleHUD instance
  - When: `hud._handle_signal(&"any_signal", [])` invoked directly (test-only access)
  - Then: no error, no side effects, returns void
  - Edge cases: invoke with various signal_name + args shapes — all silently no-op (handler bodies are story-002)

- **AC-6: _exit_tree() empty in this story**
  - Given: a fresh BattleHUD added to parent
  - When: `parent.remove_child(hud)` triggers `_exit_tree()`
  - Then: no error, no disconnect calls (none to disconnect — signals not subscribed in this story)
  - Edge cases: `queue_free()` path also triggers `_exit_tree()` — same behaviour

- **AC-7: scenes/battle/battle_hud.tscn exists**
  - Given: project file system
  - When: test loads `preload("res://scenes/battle/battle_hud.tscn")`
  - Then: PackedScene non-null; instantiated root is a `BattleHUD` instance
  - Edge cases: scene file missing → FileAccess error; test asserts file exists explicitly first

- **AC-8: Non-emitter source discipline (manual grep gate)**
  - Setup: open `src/feature/battle_hud/battle_hud.gd` in editor or via `cat`
  - Verify: zero `GameBus.*.emit` substrings present
  - Pass condition: `grep -c 'GameBus\..*\.emit' src/feature/battle_hud/battle_hud.gd` returns 0 (story-008 automates as CI lint)

- **AC-9: Pillar 2 token absence (manual grep gate)**
  - Setup: open `src/feature/battle_hud/battle_hud.gd`
  - Verify: zero occurrences of literal token `hidden_fate_condition_progressed`
  - Pass condition: `grep -c 'hidden_fate_condition_progressed' src/feature/battle_hud/battle_hud.gd` returns 0 (story-008 automates as CRITICAL CI lint — KEEP forever)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/feature/battle_hud/battle_hud_skeleton_test.gd` — must exist and pass (covers AC-1 through AC-7)
- Manual gates AC-8 + AC-9 verified at code-review time; codified as CI lints by story-008

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (first story in epic; ADR-0015 Accepted, ADR-0001/0004/0005/0006/0007/0008/0009/0010/0011/0013/0014 all Accepted, all 9 backend stubs available from prior epics — verify `tests/helpers/{battle_camera,grid_battle_controller,input_router,hp_status_controller,turn_order_runner}_stub.gd` at first-author time)
- Unlocks: Story 002 (signal subscriptions need the skeleton + DI seam)
