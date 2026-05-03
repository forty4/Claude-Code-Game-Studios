# Story 004: UI-GB-01 Initiative Queue + UI-GB-07 Turn/Round Counter + UI-GB-08 Victory Condition

> **Epic**: Battle HUD
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/ux/battle-hud.md` v1.1 §3 UI-GB-01 + UI-GB-07 + UI-GB-08
**Requirement**: `TR-battle-hud-005` (UI-GB-01/07/08 partial)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015 Battle HUD §5 (Accepted 2026-05-03)
**ADR Decision Summary**: UI-GB-01 Initiative Queue renders next 6-8 unit portraits in turn order; subscribes `round_started` + `unit_turn_started` + `unit_turn_ended` + `unit_died`. UI-GB-07 Turn/Round Counter shows current round (1-30) + current turn within round; subscribes `round_started` + `unit_turn_started`. UI-GB-08 Victory Condition is BattleScene-passed config; rendered at battle init (not signal-driven).

**Engine**: Godot 4.6 | **Risk**: LOW (pull-based query pattern; no post-cutoff API surface)
**Engine Notes**:
- `_turn_runner.get_turn_order_snapshot() -> Array[int]` returns the current initiative queue per ADR-0011 + registry line 635. Pull-based render — no signal payload state, query on receipt.
- `_hero_db.get_hero(unit_id) -> HeroData` for unit name + portrait reference per UI-GB-01 spec.
- UI-GB-08 victory condition string is set by BattleScene via a setter method `set_victory_condition(condition_text: StringName) -> void` on BattleHUD called once at battle init — see ADR-0016 §step 6 mount sequence.

**Control Manifest Rules (Presentation layer)**:
- Required: AccessKit-via-Control inheritance — UI-GB-01 portrait Controls expose tooltip_text with unit name; UI-GB-07/08 Labels expose accessibility_label.
- Forbidden (registry): `battle_hud_hardcoded_localized_strings` (story-008 lint).
- Guardrail: Initiative queue render ≤ 0.05 ms per signal handler invocation; queue rebuild on round_started ≤ 0.5 ms (8 portrait Texture refs swap, no allocations during steady-state).

---

## Acceptance Criteria

*From battle-hud.md §3 UI-GB-01 + UI-GB-07 + UI-GB-08 + ADR-0015 §5:*

- [ ] `scenes/battle/elements/ui_gb_01_initiative_queue.tscn` exists with HBoxContainer (or VBoxContainer) root + 6-8 child slots, each slot a TextureRect + Label (unit portrait + name).
- [ ] `scenes/battle/elements/ui_gb_07_turn_round_counter.tscn` exists with HBoxContainer holding 2 Labels: round_label + turn_label (e.g., "Round 3 / Turn 2").
- [ ] `scenes/battle/elements/ui_gb_08_victory_condition.tscn` exists with PanelContainer + Label rendering victory condition text.
- [ ] `_ui_elements[&"UI-GB-01"]`, `_ui_elements[&"UI-GB-07"]`, `_ui_elements[&"UI-GB-08"]` populated in `_ready()`.
- [ ] `_on_round_started(round_number)` body:
  - Updates UI-GB-07 round_label to `tr(&"hud.counter.round_format")` formatted with round_number (e.g., "Round %d")
  - Rebuilds UI-GB-01 from `_turn_runner.get_turn_order_snapshot()` — populates first 6-8 slots; remainder hidden
- [ ] `_on_unit_turn_started(unit_id)` body:
  - Updates UI-GB-07 turn_label with active unit name from `_hero_db.get_hero(unit_id)`
  - Highlights the matching slot in UI-GB-01 (e.g., outline tint or `modulate.a` increase) — visual highlight contract per battle-hud.md §3 UI-GB-01
  - **Also** invokes UI-GB-03 refresh per story-003 contract (already wired) and UI-GB-11 seal expiry per story-003 contract
- [ ] `_on_unit_turn_ended(unit_id)` body: removes UI-GB-01 highlight from the slot matching `unit_id`.
- [ ] `_on_unit_died(unit_id)` body extension: rebuilds UI-GB-01 from fresh `_turn_runner.get_turn_order_snapshot()` (the dead unit is removed from initiative).
- [ ] `set_victory_condition(condition_text: StringName) -> void` public method exists; sets UI-GB-08 Label `text = tr(condition_text)` AND sets `visible = true`. (BattleScene calls this once at battle init per ADR-0016 wiring.)
- [ ] All UI-GB-01 portrait slots have `tooltip_text = tr(&"hud.queue.upcoming") + " " + hero_data.name` (or i18n format-key equivalent) for AccessKit.
- [ ] All visible strings via `tr()` — no hardcoded literals.

---

## Implementation Notes

*Derived from ADR-0015 §5 + battle-hud.md §3 UI-GB-01/07/08 + ADR-0011 TurnOrderRunner pull-based query:*

1. **Pull-based render contract** — neither `round_started`, `unit_turn_started`, nor `unit_turn_ended` carry the queue payload. Always query `_turn_runner.get_turn_order_snapshot()` on receipt. The signal is a "queue may have changed — re-read" tap, not a state delivery.

2. **Queue rebuild strategy** — UI-GB-01 has fixed 8 slots in the .tscn; on rebuild, populate slot[0..N-1] from snapshot[0..N-1] where N = min(8, snapshot.size()). Hide slots[N..7]. Do NOT instantiate/free portrait slots per rebuild (allocation-free steady state per Guardrail).

3. **Highlight on active unit** — track `_active_queue_slot_index: int = -1` private field; on `unit_turn_started(unit_id)`, find the slot whose `unit_id == unit_id` and set `_active_queue_slot_index`; apply visual highlight to slot[index]; on `unit_turn_ended(unit_id)`, clear `_active_queue_slot_index = -1` and remove highlight. Highlight visual: implementation-time choice (e.g., `modulate.a = 1.2` boost or 1px outline); art-director sign-off per epic R-6.

4. **UI-GB-07 format string** — declare locale entries:
   - `hud.counter.round_format` → "Round %d" (or `tr_n` plural-aware later)
   - `hud.counter.turn_format` → "Turn: %s" (parameter is unit name)
   - `hud.queue.upcoming` → "Upcoming"
   - `hud.victory_condition.tooltip` → "Victory condition"

5. **UI-GB-08 victory condition rendering** — `set_victory_condition()` accepts a StringName which is itself an i18n key (e.g., `&"victory.scenario_01.defeat_commander"` resolved by `tr()`). Battle scenarios author the keys; BattleHUD does not own the text content. UI-GB-08 starts hidden (`visible = false` in .tscn); `set_victory_condition()` sets visible = true. There is no "hide" path within MVP — the condition stays visible until BattleScene tears down.

6. **Slot data model** — each slot's TextureRect + Label can be addressed via `_ui_gb_01_slots: Array[Control]` private field populated in `_ready()` from the .tscn's child enumeration. Allows index-based mutation in O(1) without per-rebuild scene-tree walks.

7. **No `_process()` body** — confirmed by Guardrail; all 3 elements are signal-driven.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: UI-GB-03 + UI-GB-11 (separate elements; already shipped).
- Story 005: UI-GB-02 Action Menu (consumes `unit_turn_started` for a different concern).
- Story 006: UI-GB-04 Combat Forecast.
- Story 007: UI-GB-09 End-of-Battle Results Screen — receives `battle_outcome_resolved` and renders victory/defeat overlay; UI-GB-08 stays for the during-battle obligation.
- Story 008: 44pt CI lint will validate UI-GB-01 portrait slots if interactive (in MVP they may be read-only — see exemption clause in TR-battle-hud-011).

---

## QA Test Cases

*UI story — automated state-transition tests + manual visual verification.*

- **AC-1: UI-GB-01/07/08 elements mount at _ready()**
  - Setup: instantiate BattleHUD + setup() flow
  - Verify: all three `_ui_elements[&"UI-GB-0X"]` keys non-null + are children of hud root; UI-GB-01 + UI-GB-07 visible by default at battle start; UI-GB-08 starts hidden
  - Pass condition: assertions pass

- **AC-2: round_started rebuilds UI-GB-01 from turn_runner snapshot**
  - Given: TurnOrderRunner stub returning snapshot `[42, 7, 99, 13, 21]` for round 3; HeroDatabase stub returning portrait textures + names for each unit_id
  - When: `GameBus.round_started.emit(3)` (deferred → flush)
  - Then: UI-GB-01 slots[0..4] visible with portrait + name for each unit; slots[5..7] hidden; UI-GB-07 round_label text resolves from `tr(&"hud.counter.round_format") % 3`
  - Edge cases: snapshot size > 8 → only first 8 rendered; snapshot empty → all 8 slots hidden + UI-GB-07 round_label still updates

- **AC-3: unit_turn_started highlights UI-GB-01 + updates UI-GB-07 turn_label**
  - Given: AC-2 happy state (slot[0]=42, slot[1]=7, ...)
  - When: `GameBus.unit_turn_started.emit(7)` (deferred → flush)
  - Then: slot[1] is highlighted (visual indicator present per implementation choice); UI-GB-07 turn_label includes hero name for unit 7; `_active_queue_slot_index == 1`
  - Edge cases: emit with unit_id NOT in queue (e.g., 999) → no slot highlighted, `_active_queue_slot_index == -1`, UI-GB-07 turn_label still updates with `_hero_db.get_hero(999)` result (or fallback)

- **AC-4: unit_turn_ended clears highlight**
  - Given: AC-3 happy state (slot[1] highlighted)
  - When: `GameBus.unit_turn_ended.emit(7)` (deferred → flush)
  - Then: slot[1] highlight removed; `_active_queue_slot_index == -1`
  - Edge cases: emit unit_turn_ended for unit not currently active → no-op no error

- **AC-5: unit_died rebuilds UI-GB-01 (dead unit removed)**
  - Given: AC-2 happy state, snapshot mutates to `[42, 99, 13, 21]` (unit 7 removed)
  - When: `GameBus.unit_died.emit(7)` (deferred → flush)
  - Then: UI-GB-01 rebuilt from new snapshot; slot[1] now shows unit 99 portrait
  - Edge cases: dying unit was the active unit (slot[1] highlighted before) → highlight cleared OR migrated to new active unit per turn_runner state (turn_runner advances on `unit_died`; verify slot[index_of_new_active] highlight follows)

- **AC-6: set_victory_condition() shows UI-GB-08 with translated text**
  - Given: UI-GB-08 hidden by default
  - When: `hud.set_victory_condition(&"victory.scenario_01.defeat_commander")`
  - Then: UI-GB-08 visible == true; Label text == tr(&"victory.scenario_01.defeat_commander") (or the key itself if no locale entry)
  - Edge cases: call set_victory_condition() twice — second call replaces text; calling with empty StringName — Label text becomes empty string + still visible (caller responsibility — no defensive guard required at MVP)

- **AC-7: i18n string discipline (manual grep gate, deferred to story-008 lint)**
  - Setup: open `src/feature/battle_hud/battle_hud.gd` + UI-GB-01/07/08 element scripts
  - Verify: every visible text assignment routes through `tr()`; format placeholders allowed
  - Pass condition: same as story-003 AC-9 — story-008 lint automates

- **AC-8: UI-GB-01 portrait tooltip presence (manual AccessKit pre-flight)**
  - Setup: instantiate UI-GB-01 with populated slots
  - Verify: each visible slot Control has non-empty `tooltip_text` (post-population, not in default .tscn)
  - Pass condition: per-slot tooltip = `tr(&"hud.queue.upcoming") + " " + hero_data.name` (or equivalent i18n format)

---

## Test Evidence

**Story Type**: UI + Logic
**Required evidence**:
- Integration test: `tests/integration/feature/battle_hud/battle_hud_initiative_queue_test.gd` covers AC-1 through AC-6
- Manual: `production/qa/evidence/battle-hud-story-004-evidence.md` covers AC-7 + AC-8

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (signal handler shims must exist; this story extends `_on_round_started`, `_on_unit_turn_started`, `_on_unit_turn_ended`, `_on_unit_died` bodies)
- Parallel-runnable with: Story 003 (disjoint elements; both extend handlers from story-002 — author them in either order or simultaneously; merge conflict surface = the 4 handler bodies, manageable)
- Unlocks: Story 005 (UI-GB-02 anchors near the active unit which UI-GB-01 highlights — non-blocking but cleaner ordering)
