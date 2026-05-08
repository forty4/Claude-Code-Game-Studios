# UX Spec: Main Menu

> **Status**: Stub (sprint-11 S11-08; closes AD-C6 ADVISORY for main-menu spec at next gate-check; pause-menu spec is a separate doc and remains AD-C6 open)
> **Author**: claude
> **Last Updated**: 2026-05-08
> **Journey Phase(s)**: Pre-game entry; post-quit return; settings access
> **Template**: UX Spec (per `.claude/skills/ux-design/SKILL.md` skeleton)
> **Parent docs**: `design/gdd/game-concept.md` (pillar identity), `design/ux/accessibility-requirements.md` (Intermediate tier — binding), `design/art/art-bible.md` (ink-wash palette restraint), `.claude/docs/technical-preferences.md` (44pt touch targets, mobile + PC parity)

---

## Purpose & Player Need

The main menu is the player's first point of contact with **천명역전 (Defying Destiny)** on every session. It must:

1. **Establish tone.** Within the first 2 seconds, the player must recognize this as a Three Kingdoms ink-wash strategy game — not a generic mobile menu. Pillar 4 (삼국지의 숨결 / The Spirit of Three Kingdoms) is the load-bearing aesthetic anchor.
2. **Route to the four entry intents** (New Game / Continue / Load / Settings) without ambiguity. The player's choice should be obvious within 3 seconds of recognition.
3. **Survive accessibility tier requirements** for the Intermediate tier (`design/ux/accessibility-requirements.md`) without aesthetic regression — color-blind safe, text-scalable, fully remappable, touch-target compliant.

This is NOT the place for tutorial introduction, world-building exposition, or social features. Those belong post-New-Game (intro cinematic) or in their dedicated screens.

---

## Player Context on Arrival

The player reaches this screen via:

- **Cold start** — app launched from OS home screen / Steam / desktop shortcut. Most common.
- **Post-quit return** — player chose Quit-to-Menu from the in-game pause flow. Settings/save state preserved.
- **Game over fallback** — defeat / loss-of-progress branch returns here after the failure screen acknowledgment. (Not all defeat states lead here; some return to checkpoint via `save-manager`.)
- **Credits exit** — completing or skipping credits returns the player here.

State assumptions on arrival:
- Save data may exist or may not (gates Continue button visibility).
- Settings have been loaded from `user://settings.tres` (per `accessibility-requirements.md` §2 Input remapping persistence) — the menu must already reflect chosen text scale, language, and accessibility toggles.
- Audio is unmuted unless the player muted it system-wide; main-menu music begins at fade-in.

---

## Navigation Position

```
[Cold start / Quit-to-Menu / Game Over / Credits exit]
                    │
                    ▼
            ┌───────────────┐
            │   Main Menu   │  ←── (this spec)
            └───────┬───────┘
                    │
   ┌────────┬───────┼───────┬─────────┬────────┐
   │        │       │       │         │        │
   ▼        ▼       ▼       ▼         ▼        ▼
New Game  Continue  Load  Settings  Credits   Quit
   │        │       │       │         │        │
   ▼        ▼       ▼       ▼         ▼        │
[Intro]  [Last    [Save  [Settings  [Credits   │
         save     slot   screen —    roll]     │
         resume]  pick]  AD-C6                 │
                         pause-menu           OS
                         shares]              exit
```

The main menu is the **hub** — every other top-level screen routes back here on Back/Cancel.

---

## Entry & Exit Points

### Entry

| Source | Trigger | State on entry |
|---|---|---|
| Cold start | Game executable launch | Save data scanned; Continue visibility resolved |
| Quit-to-Menu | Pause menu → Quit option | In-game state persisted; this screen reloads from `user://` |
| Game Over → Menu | Defeat screen → Return to Menu | Run state cleared; save data unchanged |
| Credits → Menu | Credits roll completes or player skips | No state change |

### Exit

| Destination | Trigger | State change |
|---|---|---|
| New Game (intro flow) | Tap "New Game" → confirm overwrite if save exists | New save slot allocated; pre-existing save preserved unless overwrite confirmed |
| Continue (most recent save) | Tap "Continue" (visible only if save exists) | Save loaded; transition to in-game scene at saved checkpoint |
| Load (save slot selection) | Tap "Load Game" | Modal opens listing save slots; selection routes to in-game |
| Settings | Tap "Settings" | Settings screen opens; back returns here |
| Credits | Tap "Credits" | Credits screen opens; back or roll-end returns here |
| Quit | Tap "Quit" | OS-level exit (PC); minimize-to-background (mobile, per platform convention) |

---

## Layout Specification

### Information Hierarchy

| Tier | Element | Why this tier |
|---|---|---|
| 1 (must-read first) | Game title (천명역전 / Defying Destiny) + dynasty era subtitle | Tone-setting; pillar 4 anchor |
| 2 (must-read second) | Primary action group: **New Game / Continue / Load** | Player's most likely intent; Continue is the most-tapped option for returning players |
| 3 (must-be-findable) | Secondary action group: **Settings / Credits / Quit** | Accessed less often but must not require search |
| 4 (ambient) | Build version + platform indicator (small, bottom corner) | Devops/QA reference; not player-facing primary content |
| 5 (ambient) | Background art / animation (ink-wash brushwork) | Pillar 4 aesthetic; must NOT compete with action button visibility |

### Layout Zones

Mobile portrait (reference: 1080×2400, scaled):

```
┌──────────────────────────────┐
│                              │
│      [Title zone — 30%]      │   ← Game title + subtitle, ink-wash backdrop
│                              │
├──────────────────────────────┤
│                              │
│    [Primary action zone]     │   ← New Game / Continue / Load (~50% width, vertical stack)
│         New Game             │
│         Continue             │   ← visible only if save exists; otherwise omitted (no greyed-out)
│         Load Game            │
│                              │
│   [Secondary action zone]    │   ← Settings / Credits / Quit (smaller; horizontal row OR tucked)
│   Settings · Credits · Quit  │
│                              │
├──────────────────────────────┤
│ [Ambient zone — 10%]         │   ← Build version, platform, bottom-corner accents
└──────────────────────────────┘
```

PC landscape (reference: 1920×1080):

- Title zone shifts to upper-left third (allows ink-wash brushwork to flow into the right two-thirds as background art).
- Primary action zone is centered vertically, left-aligned within its column.
- Secondary action zone is in the bottom-right corner stack OR a compact horizontal row at the bottom.
- Touch-target size still ≥ 44×44pt despite mouse-primary input (tablet PC + Steam Deck convertible parity).

### Component Inventory

| Component | Type | Tier 1 a11y note |
|---|---|---|
| Game title | Label (custom font; falls back to default on font-load failure) | Text scale must apply; does NOT scale to 150% (overflow risk — fixed at 100% with manual responsive sizing) |
| Subtitle | Label | Scales 100% / 125% / 150% per accessibility tier |
| New Game button | Button | 44×44pt min; primary action visual weight; Tab-order index 1 |
| Continue button | Button (conditional) | Tab-order index 2; hidden (not greyed) when no save exists |
| Load Game button | Button | Tab-order index 3 |
| Settings button | Button | Tab-order index 4 |
| Credits button | Button | Tab-order index 5 |
| Quit button | Button | Tab-order index 6; on mobile shows confirmation dialog before OS-level minimize |
| Build version label | Label (small, dimmed) | Not in Tab order; visible to QA/devops |

### ASCII Wireframe

Mobile portrait (post-Continue-eligible state):

```
┌──────────────────────────────┐
│                              │
│        天命逆轉                │
│      Defying Destiny         │
│                              │
│  ─ ink-wash backdrop ─       │
│                              │
├──────────────────────────────┤
│                              │
│    ┌──────────────────┐      │
│    │   Continue       │      │   ← top of primary stack when save exists
│    └──────────────────┘      │     (most-tapped action for returning players)
│                              │
│    ┌──────────────────┐      │
│    │   New Game       │      │
│    └──────────────────┘      │
│                              │
│    ┌──────────────────┐      │
│    │   Load Game      │      │
│    └──────────────────┘      │
│                              │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─       │
│                              │
│  Settings · Credits · Quit   │   ← compact secondary row
│                              │
│                       v0.x.x │   ← build label, dim
└──────────────────────────────┘
```

Cold-start (no save) state: the Continue row is omitted entirely. New Game promotes to top-of-stack visual emphasis. Spacing of remaining buttons re-flows; total layout height does not change.

---

## States & Variants

| State | Trigger | Visual delta |
|---|---|---|
| **Cold start (no save)** | First launch / save deleted | Continue button hidden; New Game promoted to top |
| **Returning player (save exists)** | `user://saves/` has at least one slot | Continue visible at top of primary stack |
| **Returning player (corrupt save)** | Save file present but fails load validation | Continue visible but disabled with non-color cue (dimmed + small ⚠ glyph); tooltip says "Save data could not be loaded — try Load Game to choose another slot." |
| **Settings-just-changed** | Player exited Settings with a change | Subtle visual confirmation (text scale change, palette swap) reflected immediately on return |
| **Reduced motion enabled** | Accessibility toggle | Background ink-wash animation pauses on a static frame; menu transitions between buttons use cross-fade not slide |
| **High-contrast UI enabled** | Accessibility toggle | Alternate Theme resource swaps; button outlines thicken; text contrast meets WCAG 2.1 AA |
| **Colorblind mode enabled** | Accessibility toggle (deuteranopia / protanopia / tritanopia) | ColorPalette Resource swap; reserved 주홍/금색 tokens remap to their alt-encoded equivalents (per accessibility-requirements.md R-1) — note: main menu uses no reserved colors at all in MVP, so this is a no-op here but the swap pipeline must propagate |

---

## Interaction Map

### Touch (mobile primary)

| Gesture | Target | Effect |
|---|---|---|
| Single tap | Any primary or secondary button | Activate that button's action; brief visual confirm flash (≤ 100ms) |
| Tap-outside | Anywhere on title/ambient zone | No effect (no accidental dismiss; menu has no dismiss state) |
| Back gesture (Android) | OS back | Confirm dialog "Exit game?" → Yes returns to OS home; No remains here |

### Keyboard (PC + Steam Deck)

| Input | Effect |
|---|---|
| Tab / Down | Focus next button in tab order |
| Shift+Tab / Up | Focus previous button |
| Enter / Space | Activate focused button |
| Esc | Quit confirmation dialog (same as Quit button) |
| All actions are remappable per `accessibility-requirements.md` §2 Input remapping (22 actions total; main menu uses 5 of them: navigate-up, navigate-down, activate, back, quit) |

### Mouse (PC primary)

| Input | Effect |
|---|---|
| Hover | Visual focus indicator on target button (cursor + outline change). Hover does NOT activate. |
| Left click | Activate hovered button |
| Right click | No effect |

### Gamepad (partial support per technical-preferences.md)

| Input | Effect |
|---|---|
| D-pad / left stick | Move focus between buttons (same tab order as keyboard) |
| A / Cross | Activate focused button |
| B / Circle | Quit confirmation dialog |

---

## Events Fired

| Event | When | Subscribers |
|---|---|---|
| `main_menu_entered` | Screen mounted | Audio (start menu music), analytics (session_start) |
| `main_menu_exited` | Player chose any exit destination | Audio (fade music), analytics (menu_choice) |
| `new_game_requested` | Player tapped New Game (after overwrite-confirm if needed) | save-manager (allocate slot), scene transition |
| `continue_requested` | Player tapped Continue | save-manager (load most-recent slot), scene transition |
| `load_requested` | Player tapped Load Game | Modal save-slot selector |
| `settings_requested` | Player tapped Settings | Settings screen route |
| `credits_requested` | Player tapped Credits | Credits screen route |
| `quit_requested` | Player tapped Quit | Quit confirmation flow |

GameBus / signal contract details are NOT specified at stub-level — they fall out of the menu implementation sprint (post-AD-C6 closure) and will reference this spec.

---

## Transitions & Animations

[To be designed at menu implementation sprint — stub-level commitments only:]

- Initial fade-in: ≤ 800ms; Reduced-motion toggle replaces with instant cut.
- Button activation feedback: ≤ 100ms visual flash; no haptic at MVP (Reduce-haptics toggle is a no-op here per accessibility-requirements.md §2).
- Background ink-wash animation: looping, ≤ 30% screen-area motion; Reduced-motion pauses on static frame per accessibility-requirements.md §2.
- Inter-screen transitions: cross-fade ≤ 400ms; Reduced-motion replaces with instant cut.

---

## Data Requirements

| Data source | Used for |
|---|---|
| `user://saves/` slot enumeration | Continue visibility + Continue→latest-save-resolution + Load slot list |
| `user://settings.tres` | Pre-applied accessibility toggles + audio volumes + remapped actions |
| Build version (read from `ProjectSettings`) | Build label in ambient zone |
| Localization key prefix `menu.main.*` | All player-facing strings (per `accessibility-requirements.md` §2 + i18n discipline; subject to POLISH-004 hardening) |

No game-state data is read at this screen.

---

## Accessibility

This spec is **bound to Intermediate tier** per `design/ux/accessibility-requirements.md`. Compliance summary:

| Intermediate tier requirement | Main-menu compliance |
|---|---|
| Text scaling 100% / 125% / 150% | All Label and Button text scales; title is fixed at 100% with manual responsive sizing (overflow risk) |
| Subtitles (audio cues with `has_narrative_weight`) | Main menu has no narrative-weight audio cues; n/a but the subtitle pipeline must still load correctly |
| Input remapping (22 actions; 5 used here) | Tab order is fixed; key bindings are remappable via Settings; default bindings work without remap |
| Colorblind modes (deuteranopia / protanopia / tritanopia) | Main menu uses no reserved color tokens; ColorPalette Resource swap is a no-op here but pipeline must propagate without error |
| Reduced motion | Background ink-wash freezes on static frame; transitions become instant cuts |
| High-contrast UI | Theme swap; button outlines thicken; WCAG 2.1 AA contrast on all text/background pairs |
| Reduce haptics | No haptic emitters on main menu (no-op) |
| Touch targets ≥ 44×44 px | All 6 buttons sized at ≥ 44×44pt minimum (per `.claude/docs/technical-preferences.md` mobile parity) |

**Project-specific R-1 (reserved-color alternate encoding)**: not applicable on main menu — no reserved-color elements present at MVP. (The Title may use 묵 ink-tone but does not encode 운명 분기 state.)

**Project-specific R-2 (focus-announcement string)**: applicable. Each focusable button must, when focused, present a string that includes its action name (e.g., "New Game button focused; activate to start a new game"). This requirement is independent of AccessKit (which is deferred to Full Vision tier per accessibility-requirements.md §3).

---

## Localization Considerations

| Concern | Approach |
|---|---|
| Title rendering | The Korean/Hanzi title must render with the project font; if font load fails, fall back to default font without crashing the menu (per CLAUDE.md verification-driven development). |
| Subtitle wrapping | "Defying Destiny" English subtitle wraps differently in long-form locales (DE/FR could be 2× length); subtitle Label must allow wrap or auto-shrink. |
| Hardcoded-string audit | All player-facing strings under key prefix `menu.main.*`. Lint 5 hardening (POLISH-004) applies — author with `tr()` from day one to avoid retroactive cleanup. |
| RTL locales | Out-of-scope for MVP; revisit at first localization sprint. Layout zones currently assume LTR. |

---

## Acceptance Criteria

| ID | Criterion | Verification |
|---|---|---|
| AC-MM-01 | Continue button is visible if-and-only-if at least one save slot exists in `user://saves/`; layout reflows when toggling | Manual test — delete saves; reload; verify Continue absent. Add saves; verify Continue present at top. |
| AC-MM-02 | All 6 (or 5 if no save) buttons meet ≥ 44×44pt touch target on the smallest supported viewport (480×800 minimum) | Lint by extending `tools/ci/lint_battle_hud_touch_target_size.sh` pattern when scenes/menu/main_menu.tscn is authored |
| AC-MM-03 | All player-facing strings use `tr()` calls; no hardcoded English strings outside debug labels | Lint 5 (`lint_*_no_hardcoded_strings.sh`) extended pattern at impl time; pre-PR grep `grep -E '"[A-Z][a-z]"' scenes/menu/main_menu.gd` |
| AC-MM-04 | Reduced-motion toggle pauses the background ink-wash animation on a static frame within 1 frame of toggle change | Manual smoke test — open Settings, flip toggle, return, observe |
| AC-MM-05 | Tab order matches the spec (1=New Game OR Continue, 2-6 sequential); Enter activates focused button | Automated keyboard input test at integration tier |
| AC-MM-06 | Quit shows confirmation dialog on mobile; on PC, Quit invokes OS-level exit directly | Manual platform parity check at impl smoke |
| AC-MM-07 | High-contrast theme swap meets WCAG 2.1 AA on all text/background pairs (button labels, title, subtitle, build label) | `accessibility-specialist` review at impl close |
| AC-MM-08 | Spec gates AD-C6 ADVISORY closure for **main-menu only**; pause-menu spec remains a separate AD-C6 follow-on | At next gate-check pass: AD-C6 ADVISORY rerated as "main-menu closed; pause-menu open" |

---

## Open Questions

| ID | Question | Owner | When to resolve |
|---|---|---|---|
| OQ-MM-01 | Does the build version label include git short-hash, or just semantic version? | producer + devops-engineer | At menu implementation sprint kick-off |
| OQ-MM-02 | What is the credits screen's content list? (Solo-indie credits will likely be a single page; verify whether Three Kingdoms reference attribution is required for cultural/historical sources) | narrative-director + writer | At credits screen UX spec authoring (not blocking main menu) |
| OQ-MM-03 | Should "Quit" be hidden entirely on mobile per platform convention (iOS HIG says no Quit button), or kept with a confirmation dialog? | ux-designer + producer | At first mobile certification readiness check |
| OQ-MM-04 | Does the main menu need a "Daily Login" / "What's New" surface for live-ops content (post-launch)? | live-ops-designer | NOT blocking MVP; revisit at post-launch live-ops scoping |
| OQ-MM-05 | Title rendering — is the project font finalized, and does it cover the full 천명역전 + Defying Destiny character set? (Cross-check AD-C3 緣 glyph status — may share font dependency) | art-director | Before main-menu implementation sprint |

---

## Cross-references

- Closes: AD-C6 ADVISORY (main-menu side only) — gate-check `production/gate-checks/pre-prod-to-prod-2026-05-05.md` line 107 + 169; pause-menu AD-C6 remains open
- Sprint: sprint-9 S9-09 (1st-time deferred) → sprint-10 S10-09 (2nd-time deferred) → sprint-11 S11-08 (this stub)
- Accessibility binding: `design/ux/accessibility-requirements.md` §1 Tier Commitment + §2 In Scope + §4 R-1/R-2
- Aesthetic binding: `design/art/art-bible.md` ink-wash palette + `design/gdd/game-concept.md` Pillar 4
- Input binding: `.claude/docs/technical-preferences.md` (44pt + mobile/PC parity); `design/gdd/input-handling.md` (5 menu actions of the 22 total remappable)
- Save-state binding: `production/epics/save-manager/EPIC.md` (8/8 Complete since 2026-04-24); save slot enumeration via existing API
- Polish dependency: POLISH-004 (Lint 5 i18n hardening) — main-menu strings should be authored with `tr()` from day one
- Settings #28 systems-index row: `design/gdd/systems-index.md` (Alpha tier — main menu's Settings button routes here when implemented)

---

## Status & Next Step

**Stub-level spec.** Layout, transitions, and Events Fired are committed at the structural level only; full visual design + signal-contract details fall to the menu implementation sprint (currently unscheduled; post-AD-C6 closure unblocks scheduling).

Next checkpoint: `/gate-check` re-evaluation after this spec ships — AD-C6 ADVISORY should re-rate to "main-menu spec closed; pause-menu spec remains open." Pause-menu UX spec is a separate doc and a separate sprint task (not in sprint-11 scope).
