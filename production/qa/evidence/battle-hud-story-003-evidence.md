# Battle HUD story-003 — Manual AccessKit Evidence (AC-8)

> **Story**: `production/epics/battle-hud/story-003-unit-info-panel-and-defend-badge.md`
> **ADR**: `docs/architecture/ADR-0015-battle-hud.md` §Engine Compatibility Verification Item 2 (AccessKit on Control hierarchy — KEEP through Polish)
> **Story Type**: UI + Logic (state transitions automated; AccessKit announcement = manual platform gate)
> **Status**: **AUTOMATED ACs (AC-1..AC-7) PASS** / **AC-8 PENDING USER VERIFICATION** / AC-9 deferred to story-008 CI lint
> **Last updated**: 2026-05-03
> **Author**: Dowan Kim
> **Verification precedent**: 2nd invocation of manual-gate evidence pattern (1st: scene-manager `scene-manager-android-verification.md` 2026-04-26 + TD-062 cross-platform mouse_filter from battle-hud story-002 2026-05-03)

---

## Summary

This document is the manual verification artifact for battle-hud story-003 acceptance criterion **AC-8** (AccessKit screen reader announces UI-GB-03 unit info on focus, per ADR-0015 §Engine Compatibility Verification Item 2). Per the project's manual-gate evidence pattern, AC-8 cannot be verified by the headless GdUnit4 test runner — it requires macOS with VoiceOver active and the Godot editor running interactively.

**Verified this turn (HEADLESS GdUnit4)**:

- AC-1, AC-2: UI-GB-03 + UI-GB-11 element scenes mount as children of HUD root, hidden by default — `tests/integration/feature/battle_hud/battle_hud_unit_info_test.gd::test_ui_gb_03_panel_mounts_hidden_at_ready` + `test_ui_gb_11_defend_seal_mounts_hidden_at_ready`
- AC-3 happy path + edge: `show_unit_info()` populates UnitNameLabel + ClassLabel + HPBar + ATKLabel + DEFLabel + StatusEffectsHBox + FacingDirectionLabel; unknown-hero edge falls through to `tr(&"hud.unit_info.unknown_unit")` literal-key fallback — `test_show_unit_info_populates_panel_from_backends` + `test_show_unit_info_unknown_hero_renders_localized_placeholder`
- AC-4: `show_unit_info(-1)` dismisses the panel + clears `_active_status_panel_unit_id` sentinel — `test_show_unit_info_minus_one_dismisses_panel`
- AC-5: `unit_selected_changed` controller-LOCAL signal routes through `show_unit_info()` for both `was_selected != 0` (show) and `was_selected == 0` (dismiss for active-panel unit) — `test_unit_selected_changed_true_routes_to_show_unit_info`
- AC-6 main + edge: `damage_applied` refreshes HP bar value on active-panel defender; non-active-panel defender leaves HP bar untouched — `test_damage_applied_refreshes_hp_bar_when_defender_is_active_panel_unit` + `test_damage_applied_to_other_unit_does_not_refresh_hp_bar`
- AC-7 main + edge: `unit_turn_started` for active-panel unit refreshes status-effects HBox + UI-GB-11 visibility (1-turn DEFEND_STANCE expiry); non-active-panel unit's turn leaves panel untouched — `test_unit_turn_started_expires_defend_stance_seal` + `test_unit_turn_started_for_other_unit_does_not_refresh`
- Bonus: `unit_died` for active-panel unit defensively clears the sentinel — `test_unit_died_for_active_panel_unit_clears_state`

**Test result baseline**: 876/876 PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0 (run 2026-05-03 post-/code-review label-completion patch — 23rd consecutive failure-free regression baseline).

**Pending user verification (THIS DOC)**: AC-8 — macOS VoiceOver announces UI-GB-03 root tooltip + child Label texts in reading order on focus. See §Procedure below.

**Deferred to story-008 (NOT this doc)**: AC-9 i18n grep gate — codified as `tools/ci/lint_battle_hud_hardcoded_localized_strings.sh` per battle-hud epic story-008 plan. Scope: scan `src/feature/battle_hud/` for literal `text="..."` / `set_text("...")` patterns; deny-list with format-placeholder allowance.

**Reactivation trigger (if AC-8 cannot be verified now)**: "When a macOS host with VoiceOver enable permission is available + user willing to run the 6-step procedure below". Estimated effort: 10-15 minutes interactive.

---

## A. Implementation surface — `tooltip_text` inventory

The following Controls have explicit `tooltip_text` set in the .tscn or via runtime assignment, qualifying for AccessKit screen-reader exposure under Godot 4.5+ Control inheritance:

### `scenes/battle/elements/ui_gb_03_unit_info_panel.tscn` (8 Controls)

| Node path | Type | tooltip_text |
|---|---|---|
| `UI_GB_03_UnitInfoPanel` (root) | VBoxContainer | "Unit information panel" |
| `UnitNameLabel` | Label | "Unit name" |
| `ClassLabel` | Label | "Unit class" |
| `HPBar` | TextureProgressBar | "HP bar" |
| `ATKLabel` | Label | "ATK stat" |
| `DEFLabel` | Label | "DEF stat" |
| `StatusEffectsHBox` | HBoxContainer | "Active status effects" |
| `FacingDirectionLabel` | Label | "Facing direction" |

### `scenes/battle/elements/ui_gb_11_defend_stance_badge.tscn` (1 Control)

| Node path | Type | tooltip_text |
|---|---|---|
| `UI_GB_11_DefendStanceBadge` | TextureRect | "Defending" |

### Runtime-assigned (BattleHUD `show_unit_info()` body)

Each `TextureRect` icon dynamically appended to `StatusEffectsHBox` via `_populate_status_effects_box()` (line ~302 of `src/feature/battle_hud/battle_hud.gd`) gets `icon.tooltip_text = tr(_status_effect_to_i18n_key(effect.effect_id))`. For `defend_stance` the resolved tooltip resolves to `"Defending"` (via `hud.status.defend_stance` msgid in `assets/locale/en.po` when locale loaded; otherwise key string verbatim).

**Total surface**: 9 static + N dynamic icons (currently N=1 for defend_stance only) = **9-10 AccessKit-exposed Controls** within the UI-GB-03/11 hierarchy.

---

## B. Procedure — macOS VoiceOver Manual Verification

**Hardware required**: macOS host (Intel or Apple Silicon) with VoiceOver enabled.
**Software required**: Godot 4.6.x stable (matches `docs/engine-reference/godot/VERSION.md` pinned version), this project at HEAD (post story-003 label-completion patch).
**Estimated time**: 10-15 minutes.

### Step 1 — Enable VoiceOver

Press `Cmd+F5` to toggle VoiceOver on. (Alternative path: System Settings → Accessibility → VoiceOver → Enable.) Wait for the audible startup announcement before continuing.

### Step 2 — Open the project in the Godot editor

```bash
godot --path .
```

Or open `project.godot` from Finder via the Godot launcher. Wait for the editor to fully load.

### Step 3 — Open `scenes/battle/elements/ui_gb_03_unit_info_panel.tscn` in the 2D editor

Use the FileSystem dock to navigate to `scenes/battle/elements/ui_gb_03_unit_info_panel.tscn` and double-click. The scene should open in the 2D editor with all 8 Controls visible.

### Step 4 — Run the scene as standalone (`F6`)

Make the unit info panel visible by setting `visible = true` on the root in the Inspector before running, OR run the parent battle scene if the standalone scene renders empty by default.

**Alternative (recommended for AC-8 specifically)**: write a 5-line test runner scene that mounts a `BattleHUD` instance via the test factory `_make_hud_with_stubs()` + calls `hud.show_unit_info(42)` to populate the labels with deterministic content. This avoids battle-scene wiring (which is not yet shipped — see ADR-0016 Battle Scene Wiring at sprint-6 S6-07).

If a test runner scaffold is needed, this can be authored as a follow-up — for AC-8 verification purposes, even an empty-text version of the panel exercises the AccessKit announcement path because tooltip_text is the primary exposure mechanism, not Label.text.

### Step 5 — Tab-focus the UI-GB-03 root + child Controls in order

With the running scene focused, press `Tab` repeatedly. VoiceOver should announce each Control's tooltip_text as focus advances. Expected reading order (per VBoxContainer top-down child enumeration):

1. "Unit information panel" (root)
2. "Unit name" → "[unit name text]"
3. "Unit class" → "[class label text]"
4. "HP bar" → "[HP value pronouncement]"
5. "ATK stat" → "[atk text]"
6. "DEF stat" → "[def text]"
7. "Active status effects" → "[N icons each announced]"
8. "Facing direction" → "[facing text]"

(Then UI-GB-11 if focused: "Defending".)

### Step 6 — Record observations + verdict in §C below

Note any silent Controls (no announcement), incorrect reading order, mispronounced text, or VoiceOver hangs. Mark each AC-8 sub-criterion PASS / FAIL / N/A.

---

## C. Observations + Verdict — PENDING

> **Status**: 🟡 PENDING — to be filled in by the user when macOS VoiceOver verification is run.
>
> **Until this section is completed with a PASS verdict (or an explicit FAIL with follow-up bug filed), AC-8 remains an open obligation tracked at the epic-close level.**

### Test environment (fill in when run)

| Field | Value |
|---|---|
| Date of run | _YYYY-MM-DD_ |
| Verifier | _name_ |
| macOS version | _macOS X.Y.Z_ |
| Godot version | _4.6.x.stable.official.{commit-sha}_ |
| Branch / commit | `main @ {sha — post story-003 label-completion patch}` |
| VoiceOver speech voice | _e.g., Samantha (default)_ |
| Test runner mode | _F6 standalone / battle-scene mock / dedicated test scene_ |

### Pass conditions per AC-8 wording

- [ ] **Audible announcement of UI-GB-03 root tooltip on focus** ("Unit information panel"). If silent, capture screenshot of VoiceOver utterance buffer.
- [ ] **Audible announcement of each child Label's tooltip_text on Tab traversal** (8 child Controls per §A).
- [ ] **Reading order matches VBoxContainer top-down child enumeration** (per §B Step 5 expected list).
- [ ] **No silent failure** — every focused Control produces an utterance OR has a documented exception (e.g., decorative Controls excluded).
- [ ] **UI-GB-11 DEFEND seal "Defending" tooltip is announced when focused** (if seal is visible at test time).

### Free-form observations

_e.g., "Tab from root skipped HPBar — went directly UnitNameLabel → ClassLabel → ATKLabel. Need to add focus_mode = 2 (FOCUS_ALL) on the TextureProgressBar."_

### Verdict

- [ ] **PASS** — all 5 sub-conditions met; AC-8 satisfied; no follow-up needed.
- [ ] **PASS WITH NOTES** — substantive PASS but specific advisory items logged below; no blocking gap.
- [ ] **FAIL** — at least one sub-condition unmet; bug report file path: _production/qa/bugs/{filename}.md_; follow-up story slot: _e.g., battle-hud post-MVP S7-NN_.
- [ ] **PARTIAL — POLISH-DEFERRED** — verification incomplete due to environmental constraint (e.g., no macOS host with VoiceOver permission this session); reactivation trigger: "next session with macOS host + ~15 min slot".

---

## D. Cross-references

- **ADR-0015** §Engine Compatibility Verification Item 2 — AccessKit auto-exposure on Control hierarchy (Godot 4.5+); KEEP through Polish per the ADR's Verification Item lifecycle policy.
- **ADR-0015** §Risks R-2 — AccessKit screen reader integration risk (Android TalkBack post-MVP per `design/ux/accessibility-requirements.md` §4); macOS VoiceOver MVP-required.
- **`design/ux/accessibility-requirements.md`** §R-2 announcements — screen reader exposure of unit/tile info on focus is a project-wide accessibility requirement.
- **Story AC-8** (line 140-144 of story-003-unit-info-panel-and-defend-badge.md) — pass-condition wording.
- **Story Implementation Note 7** (line 78) — references this exact evidence doc path.
- **Test infrastructure**: `tests/integration/feature/battle_hud/battle_hud_unit_info_test.gd` (11 tests covering AC-1..AC-7 + 1 bonus, 876/876 PASS).
- **Precedent — manual-gate evidence pattern**: `production/qa/evidence/scene-manager-android-verification.md` (Polish-deferral structure, 2026-04-26).
- **Cross-epic open item**: TD-062 (battle-hud story-002 mouse_filter cross-platform manual gate) — same manual-gate template family; future consolidation candidate.

---

## E. Next steps after PASS

1. Update §C verdict block above with date + verifier + observations.
2. `/story-done battle-hud/story-003` runs the end-of-story ceremony, references this doc + automated 876/876 PASS evidence, and flips story Status to Complete.
3. If FAIL: file bug report under `production/qa/bugs/`, update verdict to FAIL with bug-report link, decide whether to block /story-done (severity-dependent) or close-with-known-issue-tracked-in-bug-tracker.
4. If PARTIAL — POLISH-DEFERRED: log TD-NN in `docs/tech-debt-register.md` with reactivation trigger + estimated effort, then proceed to /story-done with documented deferral.
