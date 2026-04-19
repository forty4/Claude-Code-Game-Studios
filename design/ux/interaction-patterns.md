# Interaction Patterns Library — 천명역전 (Defying Destiny)

| Field | Value |
|---|---|
| Status | Active (initial stub) |
| Created | 2026-04-18 |
| Owner | ux-designer (growth), accessibility-specialist (a11y compliance review) |
| Linked | `design/accessibility-requirements.md` v1.0, `design/gdd/input-handling.md`, `.claude/docs/technical-preferences.md` |

---

## 1. Purpose & Scope

This document is the shared interaction-pattern library. Every UX spec under `design/ux/[screen-name].md` references patterns here by ID (e.g. "Tile info panel uses **IP-001** + **IP-008**") rather than redefining them. This prevents interaction inconsistency across screens and reduces UX spec length.

**This doc is not**:
- A visual style guide — see `design/art/art-bible.md`
- A per-screen UX specification — those live at `design/ux/[screen-name].md`
- An input system specification — see `design/gdd/input-handling.md`

**This doc is**: the vocabulary of reusable interaction behaviours, with PC and Touch implementations locked for each.

---

## 2. Dual-Input Invariant

Every pattern in this library MUST specify both a PC (keyboard / mouse) implementation AND a Touch implementation. Rules:

- **No hover-only interactions**. Per `.claude/docs/technical-preferences.md` Platform Notes: hover cues are decorative only; every hover-revealed affordance MUST have an equivalent tap or click trigger.
- **Touch target floor: 44 × 44 px**, enforced via `camera_zoom_min = 0.70` (Input Handling TR-input-010). No interactive element may be smaller on touch devices.
- **Input symmetry**: PC keyboard shortcuts and touch gestures resolve to the same logical action via Input Handling's 22-action vocabulary. A pattern never introduces a PC-only or Touch-only action.
- **Gamepad support**: partial per tech prefs. Patterns may call out gamepad behaviour where it differs from keyboard, but gamepad is not blocking for MVP.

---

## 3. Accessibility Invariant

Every pattern MUST respect `design/accessibility-requirements.md` v1.0 Intermediate tier. Specifically:

- **R-1 — Destiny color alternate encoding**: patterns that display destiny-branch state MUST combine color + icon + `[凶]` / `[吉]` prefix + distinct animation cadence.
- **R-2 — Textual tile-info readability**: patterns that surface tile state MUST format as readable text (`"Col 5 Row 3 · Forest · Enemy Archer Liu Bei · HP 24/40"`).
- **R-3 — Reduced-motion fallback**: patterns with motion MUST specify a reduced-motion variant.
- **R-4 — 44 px touch target floor**: non-negotiable.
- **R-5 — Subtitle style**: white text + 80% black bar + ≥ 18 pt @ 100% scale + ≤ 100 ms latency.
- **Text scale response**: all patterns layout-flex at 100% / 125% / 150% without clipping.

---

## 4. Pattern Library

### IP-001 — Tile Selection with Preview

**Summary**: Player selects a grid tile; an 80–120 px floating panel appears adjacent showing tile state (terrain + occupant + modifiers). Selection is non-committal — no game state changes until a follow-up action (IP-002).

**PC implementation**: Left-click tile → panel appears anchored to cursor with 12 px offset; hover on same tile after selection updates panel in real time (hover is decorative reinforcement only — tap-preview is the authoritative pattern).

**Touch implementation**: Single tap on tile (not drag — drag reserved for camera pan per IP-005) → panel appears adjacent to tap point, anchored opposite the thumb-grip hand (auto-detect via Input Handling device-mode).

**Accessibility**:
- Panel content MUST follow R-2 format: `"Col [c] Row [r] · [terrain] · [occupant] · HP [cur]/[max]"`
- Panel text honours text-scaling (100/125/150%) — panel dimensions flex up to a hard max of 160 px before scrolling
- Reduced-motion: skip panel fade-in; appear instantly

**Used by**: Battle HUD (primary), Battle Preparation UI (unit selection on grid)
**Related**: IP-002 (preview → commit progression), IP-008 (text scale response)
**Source**: Input Handling GDD §CR-2 Touch Tap Preview Protocol

---

### IP-002 — Two-Step Commit (Preview → Confirm)

**Summary**: Actions that change game state require two inputs: a preview selection (non-committal) and a confirm action. Prevents touch-device misfires on destructive actions (attack, end-turn, save-overwrite).

**PC implementation**: First click = preview + visual indicator (targeting overlay); second click on the same target within 5 seconds = commit; Enter key confirms, Escape cancels.

**Touch implementation**: First tap = preview + persistent targeting overlay; second tap on same target = commit. Alternate commit route: dedicated "Confirm" button in action bar (always visible during preview state).

**Accessibility**:
- Targeting overlay must be non-color-dependent (outline + fill pattern, not just color tint)
- Confirm button in action bar MUST be ≥ 44 × 44 px (R-4)
- Confirm button text announced via R-2 textual format in accessible builds

**Used by**: Battle HUD (attack, wait, end-turn), Main Menu (save-overwrite, delete-save, quit-to-menu), Destiny Branch selection
**Related**: IP-001 (preview surface), IP-004 (cancel = modal dismiss)
**Source**: Input Handling GDD state machine AttackTargetSelect → AttackConfirm

---

### IP-003 — Undo Window

**Summary**: A recently-committed movement can be reversed for a bounded window. The window closes when the unit commits to a terminal action (attack, wait, end-turn), not on turn timer.

**PC implementation**: Ctrl+Z while unit is in post-move state; undo button in action bar.

**Touch implementation**: Tap undo button in action bar. No gesture-based undo (too error-prone on touch).

**Scope rules** (from Input Handling):
- One level of undo per unit per turn (not a full history stack)
- Closes on: attack commit, wait commit, end-turn commit, or unit-switch
- Does NOT close on: camera pan, menu open, tile inspection

**Accessibility**:
- Undo button MUST persist visually throughout the window (no fade, no hover-only reveal)
- Button visibility is a state indicator that undo is available — R-1-style redundant encoding: icon + text label "Undo" + distinct edge-outline vs. greyed-out state

**Used by**: Battle HUD
**Related**: IP-002 (undo closes two-step commits already completed within the window)
**Source**: Input Handling GDD per-unit undo spec

---

### IP-004 — Modal Dismiss

**Summary**: Consistent dismissal behaviour across all modal windows (confirmation dialogs, pause menu, tutorial overlays, destiny-branch choice prompts). Prevents accidental dismissal of consequential modals.

**PC implementation**: Esc key dismisses non-critical modals; critical modals (destiny-branch, save-overwrite confirmation) ignore Esc and require explicit button click.

**Touch implementation**: Explicit close button (X in top-right, ≥ 44 × 44 px) OR back-swipe gesture for non-critical modals. **Tap-outside-to-dismiss is FORBIDDEN** on any modal that commits state — too easy to trigger accidentally.

**Classification** (each modal must declare one):
- **Non-critical** (pause menu, info overlay, tile-info popup): Esc or back-swipe or tap-outside to dismiss
- **Critical** (destiny-branch, save-overwrite, quit-to-menu, scenario restart): explicit button click only; Esc cancels any preview state but does NOT dismiss the modal

**Accessibility**:
- Close button ≥ 44 × 44 px (R-4)
- Close button has visible label ("Close" or "Cancel") not icon-only
- Critical modals announce their critical status (R-1-style encoding: border color + warning icon + `[주의]` text prefix)

**Used by**: all screens that host modals
**Related**: IP-002 (modals often host two-step commits)
**Source**: UX convention + a11y R-1 invariant

---

### IP-005 — Camera Pan & Zoom

**Summary**: Symmetric camera control across PC and Touch. Pan is gesture-distinguished from selection (IP-001). Zoom is clamped to preserve touch target floor.

**PC implementation**:
- **Pan**: middle-mouse drag OR right-mouse drag OR arrow keys
- **Zoom**: mouse wheel (smooth), `+` / `-` keys (step)

**Touch implementation**:
- **Pan**: single-finger drag, gesture-classified by distance threshold (drag > 10 px = pan, else tap = IP-001 selection)
- **Zoom**: two-finger pinch (standard mobile gesture)

**Clamp rules** (non-negotiable):
- `camera_zoom_min = 0.70` — prevents tile cells from falling below 44 × 44 px touch target (R-4)
- `camera_zoom_max = 1.50` — prevents over-zoom that occludes tactical information
- Both clamps documented in `balance_constants.json` for tuning

**Accessibility**:
- Reduced-motion: pan inertia disabled; zoom step-only (no smooth)
- Keyboard-only pan via arrow keys is a Full Vision tier commitment (currently advisory at Intermediate)

**Used by**: Battle HUD, Battle Preparation UI, Main Menu (scenario select map if map-based)
**Related**: IP-001 (drag vs. tap disambiguation)
**Source**: Input Handling GDD camera subsystem + a11y R-4

---

### IP-006 — Destiny Outcome Reveal

**Summary**: Any UI moment that reveals a destiny-branch outcome (Beat 7, epilogue header, save-slot summary) combines THREE (or more) redundant signals per accessibility R-1. Color alone is never sufficient. Rev 2026-04-19: amended with a documented Beat-7-Destiny-Branch ceremonial carve-out.

**Default triad (signals 1-3 applied to epilogue header, save-slot summary, scenario-select flags, and any non-Beat-7 destiny reveal):**
1. **Color** — 주홍 (#C0392B) for tragedy / 금색 (#D4A017) for triumph
2. **Icon** — 검 (sword) glyph for 주홍 / 관 (crown) glyph for 금색, minimum 32 × 32 px rendered
3. **Text prefix** — `[凶]` for tragedy / `[吉]` for triumph, prepended to outcome label
4. **Animation cadence** — distinct envelope shape or onset timing (≥ 300 ms difference between tragedy and triumph reveals)

**Beat-7 Destiny Branch ceremonial carve-out (authored 2026-04-19, rev 1.2 of destiny-branch.md)**:

Beat 7 (see `design/gdd/destiny-branch.md` V-DB-1..5 + A-DB-2 + UI-DB-1..5) substitutes audio + haptic for the icon + text-prefix pair to preserve the "wordless pre-linguistic realization" Ceremonial Witness fantasy codified in that GDD's Section B. The Beat 7 triad is:

1. **Color** — 주홍 (#C0392B) edge vignette + panel wash (as default)
2. **Audio** — 해금 modal-shift phrase at −18 LUFS on non-default / echo-gated branches (owned by scenario-progression §A.1; 가야금 at −22 LUFS on default variant)
3. **Haptic/Rumble** — destiny-branch A-DB-2: mobile haptic pulse 50ms, PC gamepad rumble when connected; degraded to 2 channels (color + audio) for PC-no-gamepad — documented accepted gap for Intermediate tier per destiny-branch UI-DB-5 reversal trigger

**Icon and text-prefix are explicitly NOT rendered at Beat 7.** Rationale: adding them would break the Section B "wordless" fantasy that is load-bearing for Pillar 2 (creative-director framing, 2026-04-19). The Beat 7 carve-out keeps total redundancy at 3+ channels while replacing the icon + text pair with audio + haptic, preserving WCAG R-1 compliance through substitution, not reduction. Colorblind players receive the audio (해금) + haptic signals; deaf players receive the color + haptic signals; deaf+colorblind mobile players receive the haptic; deaf+colorblind+PC-no-gamepad is the documented accepted gap.

**PC implementation**: Default triad applies identically to click-to-reveal and passive-reveal contexts. Keyboard-driven skip (Space or Enter) honours reduced-motion settings. Beat 7 specifically: per destiny-branch V-DB-5, tap-ready affordance at 1500ms dwell exit is owned by scenario-progression.

**Touch implementation**: Default triad applies identically. Tap-to-skip after R-3 minimum dwell (4.0 s per Scenario Progression v2.0 AC-SP-6). Beat 7 specifically: 1500ms dwell lockout per scenario-progression CR-10.

**Accessibility**:
- Default triad: R-1 compliant by construction (all three signals mandatory)
- Beat 7 carve-out: R-1 compliant by substitution (color + audio + haptic with documented PC-no-gamepad accepted gap — see destiny-branch.md UI-DB-4 channel matrix)
- R-3 reduced-motion: default triad collapses animation envelope to 4.0s floor + static glyph; Beat 7 variant per destiny-branch V-DB-1/V-DB-2 Reduce Motion subsections (snap to peak, hold through dwell)
- Audio cue distinct per branch (post-R-3 coordination with sound designer); Beat 7 audio owned by scenario-progression §A.1

**Used by**:
- Scenario Progression (Beat 7 outcome banner — **applies the Beat-7 carve-out, not the default triad**)
- Story Event UI (Beat 8 revelation — applies the default triad once #10 VS is designed)
- Main Menu (save-slot summary — compact variant with just icon + prefix, applies the default triad)
- Scenario select / chapter summary flags — applies the default triad

**Authoritative specs**:
- Default triad: this file + `design/accessibility-requirements.md` R-1
- Beat 7 carve-out: `design/gdd/destiny-branch.md` V-DB-1..5 + A-DB-2 + UI-DB-1..5 (canonical)

**Related**: IP-007 (subtitles of outcome audio)
**Source**: Accessibility Requirements R-1 + Scenario Progression v2.0 + destiny-branch.md rev 1.2 (Beat-7 carve-out)

---

### IP-007 — Subtitle Presentation

**Summary**: Consistent subtitle style across all audio cues flagged `has_narrative_weight: true` in the sound catalog. Appears for 100% of flagged cues.

**Style**:
- Text color: white (#FFFFFF)
- Background: 80% black overlay bar (#000000 alpha 0.8)
- Font size: 18 pt minimum at 100% text scale; 24 pt minimum at 150% text scale
- Position: bottom center, above HUD action bar
- Line limit: 2 lines; longer content pages with fade
- Latency: ≤ 100 ms from audio onset

**PC implementation**: Same as touch. No input required (passive display). Space or Enter advances to next page if paging.

**Touch implementation**: Same as PC. Tap-anywhere advances to next page if paging (does NOT dismiss — dismissal is automatic on audio end).

**Accessibility**:
- ON by default per a11y R-5 (not opt-in)
- WCAG 2.1 AA contrast enforced (white-on-80%-black ≈ 16:1 — well above 4.5:1 floor)
- Text scaling flexes font size and bar height together
- Reduced-motion: page transition is instant (no fade)

**Used by**: Battle HUD (combat SFX with narrative weight), Story Event UI (all cues), Scenario Progression Beat 2 audio
**Related**: IP-006 (destiny reveals have subtitle-worthy audio)
**Source**: Accessibility Requirements R-5

---

### IP-008 — Text Scale Response

**Summary**: All Control-tree containers holding text layout-flex at 100% / 125% / 150% without clipping, truncation, or overlap. This is a pattern-level contract: every UX spec that displays text is responsible for flex verification.

**Implementation** (Godot 4.6):
- Use `HBoxContainer` / `VBoxContainer` with `size_flags_horizontal = SIZE_EXPAND_FILL`
- Set explicit `custom_minimum_size` for button-like elements to absorb scaling without layout break
- For fixed-width panels (IP-001 tile info), grow height to accommodate wrapped text up to a vertical max of 160 px then scroll
- Never use fixed-pixel text widths in Theme styles

**PC / Touch**: Identical (pattern is layout-level, not input-level).

**Accessibility**:
- Verification is a QA gate (AC-A11Y-1): screenshot-diff across 3 scale settings for every screen
- Screens failing flex at 150% must either refactor layout or carve an exception with accessibility-specialist sign-off

**Used by**: every screen with text (all)
**Related**: IP-001 tile info panel, IP-007 subtitle bar
**Source**: Accessibility Requirements §R-5 implication + AC-A11Y-1

---

## 5. Pattern Contribution Template

When adding a new pattern to this library, use the following template:

```markdown
### IP-[NNN] — [Name]

**Summary**: [1–2 sentence description of the interaction behaviour]

**PC implementation**: [keyboard / mouse specifics]

**Touch implementation**: [gesture / touch specifics]

**Accessibility**:
- [R-1 through R-5 compliance notes]
- [reduced-motion variant if applicable]
- [touch target size if interactive]

**Used by**: [list of screens]
**Related**: [other IP-NNN cross-references]
**Source**: [GDD, ADR, or design decision that established the pattern]
```

**Numbering**: monotonic. Never re-number existing patterns. Superseded patterns get a new ID and the old one gains a `[DEPRECATED → IP-NNN]` banner.

**Review**: new patterns require `ux-designer` authoring + `accessibility-specialist` review for a11y-invariant compliance.

---

## 6. Status & Growth

**Current coverage (v1.0, 2026-04-18)**: 8 patterns. These cover the interaction surface currently implied by Designed-status GDDs (Input Handling, Scenario Progression v2.0, Grid Battle stub pending v5.0) plus accessibility commitments.

**Expected growth** as UX specs land (priority order per systems-index):
- Main Menu / Scenario Select UI (#21) → expect +2–3 patterns (scenario card selection, save-slot interaction)
- Battle HUD (#18) → expect +2 patterns (action-bar layout, status-effect hover / tap)
- Settings / Options (#28) → expect +2 patterns (toggle row layout, binding-remap capture UI)
- Story Event UI (#20) → expect +1–2 patterns (dialogue advance, choice presentation)
- Battle Preparation UI (#19) → expect +1–2 patterns (party composition drag, equipment assignment)

Target mature library: 18–24 patterns by Alpha. Not a hard limit — patterns exist to serve screens, not vice versa.

---

## 7. Changelog

| Date | Version | Change |
|---|---|---|
| 2026-04-18 | 1.0 | Initial authoring. 8 patterns: IP-001 through IP-008 covering tile selection, two-step commit, undo window, modal dismiss, camera pan/zoom, destiny outcome reveal, subtitle presentation, text scale response. All patterns a11y-Intermediate compliant by construction. Dual-input + accessibility invariants locked. |
