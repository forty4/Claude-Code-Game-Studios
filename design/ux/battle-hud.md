# Battle HUD — UX Specification

> **Status**: v1.1 — v5.0 sync pass against `design/gdd/grid-battle.md` v5.0 (2026-04-19)
> **Owner**: UX Design (Art Direction consulted for palette)
> **Parent GDD**: `design/gdd/grid-battle.md` (rules source of truth; this doc is strict UI-only post-v1.1)
> **Supports Pillars**: 형세의 전술 (Tactics of Momentum), 모든 무장에게 자리가 있다 (Every class has a role)
>
> **v1.1 revision log (2026-04-19)**:
> - §4.2 counter-max formula: F-GB-PROV replaced with `damage_resolve(max_roll)` per grid-battle.md v5.0 F-GB-3 rewrite.
> - §4.6 render-budget language changed from "Vulkan Forward+ project default" to "platform-default Forward+ (per-platform backend per tech-prefs)". Pixel 7 / Vulkan remains reference hardware.
> - §5.x added: DEFEND two-tap confirm flow (mobile) — replaces grid-battle.md v4.0 "long-press + Korean modal" model per CR-13 rule 7.
> - UI-GB-12 added: TacticalRead Extended Range visual — 황토 70% opacity + 讀 micro-glyph for Strategist-only TR tiles per grid-battle.md v5.0 CR-14.
> - UI-GB-11 notes refreshed: DEFEND_STANCE duration is 1 turn (matches hp-status.md + grid-battle.md CR-13 rule 2); reduction value deferred to `hp-status.md` ownership.
> - AC-UX-HUD-09 added: mobile DEFEND two-tap contract.
> - Scope: strict UI-only going forward. Rule-restatement from grid-battle.md CR-* is removed and replaced with `Per grid-battle.md §CR-X` references. Cross-doc divergence surface is now one-way (grid-battle.md wins on conflicts).

## Scope

This document owns the runtime battle screen: the HUD, the pre-combat forecast,
the action menu, the initiative queue, and the visual/audio treatment of every
on-battlefield event. It is consumed by `design/gdd/grid-battle.md` (which owns
the rules) and by the future Battle UI implementation GDD (not yet authored).

UX rules that apply project-wide (input model, accessibility, 44pt touch
targets, palette restrictions) are enforced locally in this spec and derive from:

- `.claude/docs/technical-preferences.md` (touch target, input methods)
- `design/art/art-bible.md` (ink-wash palette, 묵/황토/청회, 주홍/금색 reserved)
- `design/gdd/input-handling.md` (S0–S5 states, undo model)

---

## 1. Design Goals

1. **Forecast readability is a pillar feature.** Every mechanic in the pre-attack
   forecast (UI-GB-04) serves Pillar 1 — the player must be able to answer "is
   this attack worth it?" in under two seconds of reading.
2. **Palette restraint is non-negotiable.** The ink-wash palette (墨/黃土/靑灰)
   carries the entire visual language. **주홍** and **금색** are reserved for
   운명 분기 (destiny branch) moments only — kill forecast, victory/defeat treatment,
   and counter-salience all work within the base palette using brush weight and
   glyph shape, not hue.
3. **Touch parity.** Every interactive element works identically on touch and
   PC mouse. No hover-only interaction. No long-press for primary actions. The
   two-tap confirm model is the canonical touch flow; PC maps hover to Beat 1
   and click to Beat 2.
4. **Mobile-first UI density.** Small screens (<480pt viewport width) must
   preserve the most pillar-critical information; anything non-essential collapses
   behind explicit affordances.

---

## 2. Visual / Audio Requirements

> All visual effects operate within the ink-wash constraint: no particle emitters,
> no bloom-heavy glow, no colour outside the established palette unless the effect
> is explicitly a 운명 분기 moment (주홍/금색 reserved). Prefer brush-stroke
> animation, ink-wash fades, dry-brush lines, and calligraphic transitions.

### 2.1 Movement Range Highlight

**Visual**: Tile overlay using 청회(#5C7A8A) at 30% opacity, applied as an ink-wash
flood fill — edges feather softly rather than hard-clip, as if the colour seeped
into paper. On unit selection, the wash bleeds outward from the unit's tile to
its full range over 0.15s (ink spreading). Unreachable and occupied tiles receive
no highlight.

**Audio**: Low, dry brush-on-paper sound — single short sweep (0.2s). Plays once
on range reveal, not per-tile.

**Priority**: MVP

### 2.2 Attack Range Highlight

**Visual**: Tile overlay using 황토(#C8874A) at 25% opacity. Same feathering style
as movement range. Where attack range overlaps movement range, the two washes mix
to a warm amber — communicating "you can move here AND attack from here" without
a third colour. Attack range reveals only after movement destination is selected.

**Audio**: Subtle tension cue — a single dry percussion tap (목탁 or small taiko),
0.15s.

**Priority**: MVP

### 2.3 Path Preview

**Visual**: Dry-brush directional arrow line rendered as a broken ink stroke —
matching the 포석도 (formation diagram) language. Style: 건식 붓(dry brush) with
small gaps in the stroke. Colour: 청회(#5C7A8A) at 70% opacity. Each tile in the
path shows a small movement-cost numeral in calligraphic notation — 묵(#1C1A17)
ink, 10px, right-aligned within the tile.

**Audio**: No sound. Path preview updates every pointer-hover frame.

**Priority**: MVP

### 2.4 Attack Direction Indicator (FRONT / FLANK / REAR)

**Visual**: Compass-rose style indicator centered on the target unit. Three arc
segments surround the target tile as thin ink-brush arc strokes. FRONT arc: 청회
at 50% opacity. FLANK arcs (left and right): 황토 at 50% — moderate advantage.
REAR arc: 황토 at 70% with thicker brush stroke — maximum advantage. The active
arc pulses once with a 0.1s stroke-thickening animation on hover.

**Audio**: No sound on hover. Covered by hit feedback on attack confirmation.

**Priority**: MVP

### 2.5 Hit / Miss Feedback

**Hit visual**: Target unit's sprite flashes with a brief (2-frame) white ink-wash
overlay, as if struck through with diluted ink. Duration: 0.1s flash, then returns
to normal. No screen shake.

**Miss visual**: Attacker's brush-stroke weapon animation passes through without
contact. Target sprite performs a brief lean-and-recover (2-frame tilt, 0.2s). A
small 「避」(evade) kanji fades up from the target tile in 묵 ink, dissolves in
0.4s.

**Hit audio**: Short dry bamboo-on-wood strike (0.15s). Layered with paper-tear
texture for heavier hits.

**Miss audio**: Soft whoosh (0.15s) followed by silence.

**Priority**: MVP

### 2.6 Damage Numbers

**Visual**: Calligraphic brush font — not pixel-art. Rise 12px upward over 0.5s,
fade out. Size scales with damage magnitude (small=16px, medium=20px, large=24px,
anchored at 15 base damage). Colour: 묵(#1C1A17) for standard damage.
Counter-attack damage numbers rendered 30% smaller. Miss displays 「避」 instead
of a number.

**Design note**: No red damage numbers. 주홍 is reserved for 운명 분기.

**Audio**: Covered by hit sound.

**Priority**: MVP

### 2.7 Counter-Attack Visual

**Visual**: After primary attack resolves, a reversal beat: defending unit shifts
weight toward attacker (1-frame lean), then its attack animation plays in reverse
direction. Counter-stroke rendered as a slightly desaturated, lighter-weight
brush line — communicating "response, not initiation." Counter damage number:
30% smaller (see 2.6).

**Audio**: Softer, shorter version of hit sound — tap rather than strike. Plays
after 0.15s silence following primary hit, giving clear temporal separation.

**Priority**: MVP

### 2.8 Status Effect Application / Removal

**Application visual**: A calligraphic seal/stamp (인장, 印章) drops onto the
affected unit's tile. Each status has a distinct 漢字 seal: POISON=毒,
DEMORALIZED=喪, DEFEND_STANCE=守, INSPIRED=昂, EXHAUSTED=疲. The seal fades from
full opacity to 40% semi-transparent overlay persisting as the status icon.
Size: 16×16px, upper-left corner. Animation: stamp drops with single-frame ink
blot expansion (0.2s), then settles.

**Removal visual**: Seal fades out with ink-wash dissolve (0.3s). No pop, no
particle burst.

**Application audio**: Single ink-stamp sound (0.1s). Pitch variation: higher =
harmful to enemy, lower = buff to ally (accessibility support).

**Removal audio**: Soft paper-brush sound (0.1s), lighter than application.

**Priority**: MVP (status icons), Polish (per-status audio variation)

### 2.9 Unit Death

**Visual**: The 묵화(墨化) transition from art bible Section 5.3 — unit sprite
gradually loses colour saturation over 0.6s, draining to full monochrome ink
drawing. Final frame holds 0.3s as greyed ink silhouette. Silhouette dissolves
upward as if ink evaporating — brush strokes break apart and fade over 0.4s.
Total: ~1.3s. Non-interruptible (input blocked per Grid Battle CR-12).

**Audio**: Long, low 二胡(erhu) note — mournful, not dramatic. 1.0-1.5s, fades
out. Plays once per death.

**Priority**: MVP

### 2.10 Turn Transition

**Visual**: Initiative queue UI updates with incoming unit highlighted. Active
unit's tile receives a thin animated 묵 ink border that "draws itself" around
the tile edge over 0.2s. AI turn: same animation at 60% opacity (communicating
"not player-controlled").

**Audio**: Single short woodblock/bamboo percussion tap (0.15s). Same sound for
player and AI turns — distinction is visual only.

**Priority**: MVP

### 2.11 Victory / Defeat / Draw Screen

**Victory visual**: Screen transitions to State 5 atmosphere: 금색(#D4A017) wash
bleeds from centre outward over 2.0s. Surviving hero portraits gain gold-border
glow. Victory title renders as a large calligraphic brush stroke "painting
itself" over 0.5s. 금색 usage sanctioned here as 운명 역전 moment.

**Defeat visual**: Screen transitions to State 6: colour drains, full
desaturation over 2.0s. Fallen hero portraits show 수묵화 산화 (ink oxidation).
Defeat title fades in quietly — no paint-stroke animation. Contrast with victory
is deliberate.

**Draw visual**: Muted neutral treatment. No colour drain, no gold — palette
settles to 황토 + 묵. Draw title in standard 묵 ink.

**Victory audio**: Traditional percussion flourish, brief and measured. Short
melodic phrase on 가야금(gayageum). 3-5s total.

**Defeat audio**: Sustained 二胡 note (3s), resolving downward. Silence after.

**Draw audio**: Single resonant bell tone (0.5s decay).

**Priority**: MVP (all three outcomes)

### 2.12 Deployment Camera Pan

**Visual**: Camera begins top-down overview of full map. Over 2.0s
(`DEPLOYMENT_CAMERA_PAN_DURATION`), pans at shallow diagonal angle, landing on
player deployment zone. Smooth ease-in/ease-out arc — evokes unrolling a scroll,
revealing the map progressively. Input blocked (Grid Battle CR-12, CR-2) for
full duration. Speed affected by `ANIMATION_SPEED_MULTIPLIER`.

**Audio**: Brief ambient sting — low wind, distant drums settling. 2.0s, matching
pan duration, fades into battle ambient.

**Priority**: MVP

### 2.13 AI Soft-Lock User-Facing Surface

**Visual**: When Grid Battle CR-3b escalates (AI_SOFTLOCK_THRESHOLD reached),
the initiative queue (UI-GB-01) shows affected AI portraits with a muted
"대기" (wait) seal overlaid in 묵 ink. No error message appears to the player —
the queue simply resolves the remainder of the round silently.

**Audio**: No sound distinct from a normal WAIT. The escalation is a defensive
mechanism; it must not call attention to itself.

**Rationale**: Players should never see the words "AI soft-lock" or "error." The
`push_error` calls from CR-3b are for developer diagnostics only. If the AI
pipeline regresses in production, the silent WAIT treatment preserves the
experience while logs flag the issue for debugging.

**Priority**: MVP

---

## 3. UI Elements

| ID | Element | Description | Update Trigger | Priority |
|----|---------|-------------|----------------|----------|
| UI-GB-01 | **Initiative Queue** | Horizontal or vertical strip showing upcoming unit turn order. Highlights the active unit. Shows at least the next 6-8 units. Player must be able to see who acts next to plan sequences (Pillar 1: "reading momentum"). | `round_started`, `unit_turn_started`, `unit_died` | MVP |
| UI-GB-02 | **Action Menu** | Contextual menu for the active player unit showing available actions: MOVE, ATTACK, USE_SKILL, DEFEND, WAIT, END_TURN. Greyed-out actions whose tokens are spent. Appears on unit selection (S1). | `unit_turn_started`, token spend, state change | MVP |
| UI-GB-03 | **Unit Info Panel** | Shows selected unit's key stats: name, class, HP bar, ATK, DEF, active status effects (seal icons), facing direction. Appears on any unit tap/hover (observation mode S0 or selection S1). | `unit_select`, `hp_changed`, `status_changed` | MVP |
| UI-GB-04 | **Combat Forecast** | Pre-attack preview. See Section 4 for full spec. | `attack_target_hovered` | MVP |
| UI-GB-05 | **Skill List** | Sub-menu of UI-GB-02. Shows unit's 2 skill slots with name, cooldown remaining, range indicator. Greyed-out if on cooldown. | USE_SKILL selected from action menu | MVP |
| UI-GB-06 | **Tile Info Tooltip** | On tile hover/tap (S0): shows terrain type, elevation level, defense bonus, evasion bonus. Must be small enough not to obstruct the grid. | `tile_hover` | MVP |
| UI-GB-07 | **Turn/Round Counter** | Displays current round number (1-30) and current turn within the round. Visible at all times during COMBAT_ACTIVE. | `round_started`, `unit_turn_started` | MVP |
| UI-GB-08 | **Victory Condition Display** | Shows the active victory condition for the scenario (e.g., "Defeat all enemies" or "Defeat Commander [Name]"). Visible at battle start and accessible via menu during battle. | Battle start, on-demand | MVP |
| UI-GB-09 | **End-of-Battle Results Screen** | Shows outcome (VICTORY/DEFEAT/DRAW), surviving units, turns elapsed, scenario-specific rewards. Overlays the battlefield with the victory/defeat visual treatment from Section 2.11. | `battle_ended` | MVP |
| UI-GB-10 | **Undo Indicator** | Small visual cue when undo is available (unit has moved but not yet attacked). Shows "Undo" button or tap zone. Disappears when undo window closes (attack confirmed or end-turn). | Movement confirmed, ACTION token spent | MVP |
| UI-GB-11 | **DEFEND Stance Badge** | Added in v1.0 for Grid Battle CR-13. When a unit has DEFEND_STANCE active, a 守 seal badge overlays its tile at 40% opacity 묵 ink. Persists until the unit's next `unit_turn_started` (DEFEND_STANCE duration is 1 turn per grid-battle.md CR-13 rule 2 / hp-status.md SE-3). Damage-reduction value is owned by hp-status.md (registry `defend_stance_reduction`); this element is visual only. | `status_applied(DEFEND_STANCE)`, `unit_turn_started` | MVP |
| UI-GB-12 | **TacticalRead Extended Range** *(v1.1 — Strategist-only per grid-battle.md CR-14 v5.0)* | Extends the natural attack-range overlay for Strategist units. Natural attack range: 황토 25% opacity (current UI-GB-02 treatment). **TR-extended tiles** (those within `tactical_read_extension_tiles = 1` beyond natural range per registry): 황토 70% opacity with a 讀 (read) micro-glyph 8px, upper-left anchor, per extended tile in 묵 ink. Hovering a TR-extended target displays UI-GB-04 with a `[TR]` chip adjacent to the direction badge (§4.1 Section 5) so the player can distinguish TR-sourced forecasts from natural-range ones. TR does NOT extend attack range — the chip on a TR-tile communicates "you need to move 1 tile to attack here" visually via the natural-range vs TR-range opacity split. Commander units do NOT render UI-GB-12 (Commander's v5.0 passive is `passive_rally` per `design/gdd/unit-role.md` CR-2, not TR). | Strategist unit selected (S1), `unit_turn_started` | MVP |

---

## 4. UI-GB-04 — Combat Forecast (Full Spec)

The Combat Forecast is the single most pillar-critical UI element in the game.
Pillar 1 (형세의 전술) requires the player to read the battlefield and predict
the outcome before committing. UI-GB-04 IS that reading surface.

### 4.1 Section Order (top-to-bottom)

1. **Damage line** — `[ATK → raw_damage → defender HP_before → HP_after]`. Always visible.
2. **Kill indicator** — when `HP_after ≤ 0`, render a heavy 묵(#1C1A17) ink brush outline (3px stroke) around the damage line plus an oversized 斬 (참) ink-seal glyph at 300% standard seal size in 묵 ink. **No red color.** Palette rule (Section 2.6 design note) reserves 주홍 for 운명 분기 only. Kill salience is achieved via brush weight and glyph size, not hue. Always visible when applicable.
3. **Counter-attack line** — if Grid Battle CR-6 counter-eligibility is met: `[defender ATK → counter_damage (×0.5) → attacker HP_before → HP_after]` with the `×0.5` modifier displayed inline. If not eligible, replace with a short muted reason: "No counter — out of range / Ambush suppressed / status-only skill / counter-is-counter / Archer out of natural range".
4. **Hit chance** — displays `hit_chance%` per Grid Battle F-GB-2 hit-semantics (actual long-run hit rate, not miss-inverted). Small "2RN" chip indicates variance collapse.
5. **Direction badge** — FRONT / FLANK / REAR chip with `D_mult` value.
6. **Passives list** — one line per active passive, CAPPED at 3 lines per side visible (6 total). If more exist, a "+N more" affordance expands on tap. Each line format: `[Source → Passive → effect]`.

### 4.2 Counter-Kill Forecast Accuracy (P0 — Pillar 1 contract; v1.1 rewrite)

The `counter_would_kill_attacker` boolean that drives the two-tier chevron in
§4.4 MUST be computed on the **max-roll** of the 2RN distribution — NOT the
expected value. The 2RN distribution is triangular with range [0, 99] and mean
49.5; at HP near the kill threshold, using the expected value under-predicts
counter-kills in roughly 8% of marginal cases, which violates Pillar 1's
"never surprised" contract.

Formula (delegates to `grid-battle.md` F-GB-3, which in turn consumes
`damage-calc.md` `damage_resolve`):

```
# Per grid-battle.md F-GB-3 v5.0:
counter_result = damage_calc.resolve(
    attacker = defender.as_attacker(counter_context),
    defender = original_attacker.as_defender(),
    modifiers = {
        attack_type    = defender.primary_attack_type,
        direction_rel  = reverse(primary_direction_rel),
        is_counter     = true,                  # F-DC-7 applies counter_attack_modifier internally
        skill_id       = "",
        rng            = pinned_max_roll_rng,   # max-roll per Pillar 1
    },
)
counter_max_damage = counter_result.resolved_damage  # 0 if MISS

counter_will_fire = (all CR-6 conditions satisfied AND hit_chance > 0 AND NOT defender.has_status(DEFEND_STANCE))
counter_would_kill_attacker = counter_will_fire AND (original_attacker.current_hp - counter_max_damage <= 0)
```

If `counter_will_fire == false` (including the DEFEND_STANCE suppression
from grid-battle.md CR-13 rule 4), `counter_would_kill_attacker` is always
`false` and the chevron shows no indicator (§4.4 Tier 0).

**Rationale**: A warning indicator that triggers on "might kill you" is the
correct conservative stance for a tactics game. Under-warning is a pillar
violation; over-warning is an aesthetic irritation. We accept the latter.

**v1.1 migration note**: The v1.0 formula invoked `F-GB-PROV` directly. In
v5.0, grid-battle.md deleted F-GB-PROV; the authoritative primitive is
`damage_resolve`. This section now mirrors the grid-battle.md F-GB-3 call
shape for parity; if the two diverge, grid-battle.md wins.

### 4.3 Mobile Collapse Rule (viewport width < 480pt)

- Sections 1, 2, 4 are always visible.
- Sections 3, 5, 6 collapse behind a single tap-to-expand chevron.
- **Chevron touch target**: the chevron glyph MUST occupy a minimum 44×44pt hit
  area (per project-wide touch-target rule) even if the visible glyph itself is
  smaller — padding extends the tappable zone to 44pt each side.
- The expanded forecast scrolls if it exceeds the anchored panel's max height
  (50% of viewport); scroll anchor is **bottom-edge** so the target tile and
  attacker remain visible as the panel grows upward.

### 4.4 Two-Tier Counter-Salience Encoding (mobile chevron)

The chevron carries a persistent counter-state indicator in 묵(#1C1A17) ink,
placed **upper-right** of the chevron glyph, with two tiers:

| Tier | Condition | Glyph | Meaning |
|------|-----------|-------|---------|
| — (no indicator) | `counter_will_fire == false` | (none) | No counter — safe |
| 1 | `counter_will_fire == true` AND `counter_would_kill_attacker == false` | 6px filled 묵 dot | Counter exists — survivable |
| 2 | `counter_will_fire == true` AND `counter_would_kill_attacker == true` | 10px 斬(참) micro-glyph in 묵 ink, 2px stroke | Counter kills you — pillar-critical warning |

**Palette compliance**: both tiers use 묵 ink only; no 주홍 (reserved for
운명 분기). Kill salience is encoded via brush weight + glyph shape, not hue —
consistent with Section 2.6's primary-kill brush-outline treatment.

**Pillar guarantee**: the two-tier encoding ensures the Pillar 1 question "is it
safe to attack?" can be answered without expanding the chevron on mobile.

### 4.5 PC Viewport Behaviour (viewport ≥ 480pt)

- All sections visible by default, no collapse.
- **Hover-off dismissal** (P0 — DC-6 resolution): when the mouse cursor leaves
  the target tile, the forecast panel dismisses **immediately** (fade out over
  80ms, same animation as touch Beat 2 commit dismiss). No delay, no stickiness.
  This matches PC tooltip convention and the ink-wash restraint — crisp
  appearance, crisp dismissal.
- **Render-abort on hover-dismiss race** (v1.1): if `attack_target_hovered`
  fires and the cursor leaves the target tile BEFORE the two-frame layout+paint
  window completes (per §4.6 seam), the render is aborted mid-flight — the
  panel visibility MUST NOT transition to true (no 1-frame flash of a
  forecast the player has already dismissed). AC-UX-HUD-01 includes this
  sub-assertion.
- Re-hovering a different valid target repositions the panel to the new target
  with a 60ms cross-fade; re-hovering the same target within 80ms of dismiss is
  a no-op (the panel is already visible).
- Keyboard-driven targeting (for future accessibility): arrow-key moves the
  target cursor, Tab focuses the forecast, Esc dismisses. Full keyboard flow
  specified in `design/ux/accessibility-requirements.md` (not yet authored).

### 4.6 Render Budget (v1.1 — per-platform)

The forecast panel MUST render all required sections within **120ms** of
`attack_target_hovered` firing, measured on Pixel 7-class mobile reference
hardware (Android → Vulkan Forward+ per Godot 4.6 default).

**Platform policy** (per `.claude/docs/technical-preferences.md`):

| Platform | Rendering backend | Budget applicability |
|----------|-------------------|---------------------|
| Android (reference) | Vulkan Forward+ | Hard 120ms budget — `BLOCKING` |
| Linux | Vulkan Forward+ | 120ms target; divergence `WARN` |
| Windows | D3D12 Forward+ (Godot 4.6 default since Jan 2026) | 120ms target; divergence `WARN` |
| macOS / iOS | Metal Forward+ | 120ms target; divergence `WARN` |

The 120ms budget applies uniformly — divergence outside reference hardware is
a regression to investigate, not a hard ship blocker. Enforcement split: AC-
GB-24 asserts reference-hardware blocker; per-platform perf runs handled by a
nightly job (out of scope for this spec).

Test seam is specified in Grid Battle AC-GB-24: two consecutive
`await get_tree().process_frame` calls from the signal handler (first frame
resolves layout, second resolves first paint).

---

## 5. Touch-Specific Requirements

- All interactive elements meet 44pt minimum touch target (technical preferences).
- Combat Forecast (UI-GB-04) must be repositionable — cannot obstruct the target
  tile on small screens.
- Action Menu (UI-GB-02) anchors near the selected unit but auto-repositions to
  avoid screen edges.
- Tile Info Tooltip (UI-GB-06) must not require long-press — single tap in
  observation mode (S0) reveals it.
- Initiative Queue (UI-GB-01) is scrollable if queue exceeds visible space.

### 5.1 S3/S4 Touch Flow — Two-Tap Confirm

Touch devices have no hover state, so the S3 (target selection) / S4 (confirm)
flow uses a deterministic two-tap interaction distinct from PC hover behaviour.

| Beat | Input | Grid Battle State | UI Result |
|------|-------|-------------------|-----------|
| Beat 1 | Player taps a valid attack target tile (S3) | Target highlighted, forecast shown, `TWO_TAP_TIMEOUT_S` timer starts | Combat Forecast (UI-GB-04) appears anchored to the target |
| Beat 2 | Player taps the **same** target tile again (S4) **within `TWO_TAP_TIMEOUT_S`** | Attack confirmed, pipeline CR-5 begins | Forecast fades out over 80ms, attack animation starts |
| — | Player taps a **different** valid target | Target reselected (back to Beat 1) | Forecast repositions to new target, Beat 2 counter resets, timer restarts |
| — | Player taps an empty tile or UI dismiss area | Return to S1 | Forecast closes, no action taken |
| — | `TWO_TAP_TIMEOUT_S` expires without Beat 2 | Return to S1 automatically | Forecast fades out over 150ms; target highlight clears. No attack fires. |
| — | Player taps the Undo button (visible in S3 if MOVE was used and ACTION unspent) | Transitions to S1, undo executed | Forecast closes; UI-GB-10 undo processes per Grid Battle CR-4 step 8 |

**`TWO_TAP_TIMEOUT_S` default = 15s**, safe range 8–30s. Below 8s: players
reading the forecast on first exposure feel rushed; above 30s: accidental Beat 2
from a phone in pocket or a misclick after a long read becomes realistic. The
timeout is an anti-fat-finger safeguard only — a player who reads the forecast
at a normal pace (5-10s) is never hurried.

**Undo availability during S3**: The Undo button (UI-GB-10) remains visible
during S3/S4 if the player used MOVE but has not spent ACTION. Tapping Undo in
S3 transitions back to S1, dismisses the forecast, and runs the move-undo
pipeline per Grid Battle CR-4 step 8. This aligns with Input Handling's undo
model (M-1 `undo_last_move`) — Grid Battle does not define a separate S3 undo
gesture; the single undo button handles all states where undo is valid.

### 5.2 DEFEND Two-Tap Confirm (v1.1 — mobile)

Mobile DEFEND commitment uses a two-tap same-target flow identical in shape
to the attack confirm flow (§5.1), with the DEFEND button in UI-GB-02 serving
as the "target". Per `grid-battle.md` CR-13 rule 7 / EC-GB-42 (v5.0), **no
long-press, no modal dialog** — the two-tap vocabulary keeps the mobile
interaction surface unified with ATTACK and complies with §1 design goal 3
("no long-press for primary actions").

| Beat | Input | Grid Battle / HP-Status State | UI Result |
|------|-------|------------------------------|-----------|
| Beat 1 | Player taps the DEFEND row in UI-GB-02 during PLAYER_TURN_ACTIVE (S1) | Button highlighted; `TWO_TAP_TIMEOUT_S` (15s, registry) starts | DEFEND button pulses once (0.15s ink-wash fade-in/fade-out); remaining tokens displayed; surrounding action-menu rows receive a brief desaturation to emphasise the committed-focus target |
| Beat 2 | Player taps the DEFEND row **again** within the timeout | DEFEND commits: `unit_defended` then `unit_turn_ended` (grid-battle.md CR-13 rule 2); `DEFEND_STANCE` applied via HP/Status | Menu dismisses (80ms ink-wash fade-out); UI-GB-11 守 seal renders; initiative queue advances |
| — | Player taps any UI element other than DEFEND or the UI-GB-02 panel | Returns to S1; DEFEND not committed | Button pulse clears; menu remains open if the tap target was elsewhere in UI-GB-02; closes if the tap was outside the menu bounds |
| — | Player taps a **valid move-range tile** during Beat-1 pending state | Returns to S1; DEFEND not committed; the tap initiates MOVE to S2 with that tile as the new move target (MOVE preview shows immediately) | Menu dismisses (80ms fade); move preview renders; Beat-1 DEFEND state cleared. Fixture variant B (`defend_two_tap_cancel_move.yaml` — DEFERRED FIXTURE) covers this path. |
| — | `TWO_TAP_TIMEOUT_S` expires without Beat 2 | Returns to S1; DEFEND not committed | Button pulse clears; menu remains open; no action taken |
| — | Player taps Undo (UI-GB-10) during Beat-1 pending state | Returns to S1; prior MOVE undone per Input Handling M-1 | Menu dismisses; movement reverts (applies only if MOVE was used and ACTION unspent) |

**Once DEFEND is committed, it is NOT reversible.** Undo (UI-GB-10) becomes
unavailable after `unit_defended` emits — this matches grid-battle.md
AC-GB-21c rule 7 ("calling undo_last_move after DEFEND returns a REJECTED-
DEFEND error code; state is unchanged").

**PC mapping**: Beat 1 = hover over DEFEND row (standard action-menu
highlight behaviour); Beat 2 = click. No two-tap timer on PC since hover is
implicit. Click-off dismisses Beat 1 state identically to the touch "tap
elsewhere" case above.

**Rationale (Pillar 3 / cross-platform parity)**: Under grid-battle.md CR-13
v5.0, DEFEND is a high-commitment irreversible choice (sets `acted_this_turn
= true`; suppresses counter; consumes both tokens; no undo). A high-
commitment action demands a deliberate input. The two-tap model supplies the
deliberateness without introducing a new interaction vocabulary (modals,
long-press) that would break the §1 design-goal 3 palette rule. Same shape
as ATTACK confirm → zero cognitive overhead for the player.

### 5.3 Gamepad Mapping (future)

Gamepad maps Beat 1 to cursor-on-target (D-pad or left stick) and Beat 2 to
confirm button (A/Cross). Full gamepad spec deferred to
`design/ux/gamepad-input.md` (not yet authored).

---

## 6. Palette & Accessibility

### 6.1 Palette Constraints

- **묵 (#1C1A17)** — default ink, all text, kill salience glyphs, counter dots.
- **황토 (#C8874A)** — attack range, FLANK indicator.
- **청회 (#5C7A8A)** — movement range, FRONT indicator, path preview.
- **주홍 (reserved)** — forbidden outside 운명 분기 moments. Any visual that
  needs "urgent" must use brush weight or glyph shape.
- **금색 (reserved)** — victory screen only (Section 2.11).

### 6.2 Colorblind Support

- Counter-salience (§4.4) uses shape distinction (dot vs 斬 glyph), not hue.
- FRONT/FLANK/REAR indicators use brush thickness variation in addition to hue.
- Status seals use distinct 漢字 glyphs (毒/喪/守/昂/疲), not color-coded icons.
- Audio cues (Section 2.8) carry harmful/beneficial distinction via pitch.

### 6.3 Touch Target Minimums

- Primary action buttons: 44×44pt (project rule).
- Chevron (§4.3): 44×44pt hit area regardless of visible glyph size.
- Initiative Queue entries: 44pt tall.
- Undo button (UI-GB-10): 44×44pt.

### 6.4 Text Sizing

- Damage numbers (§2.6): 16/20/24pt, scales with magnitude.
- Status seal icons: 16×16px visual, 44pt tap zone when interactive.
- Forecast body text: 14pt minimum, 16pt preferred on mobile.

---

## 7. Edge Cases

| ID | Case | Handling |
|----|------|----------|
| UX-EC-01 | Forecast overflow (passives > 3 per side) | "+N more" affordance; tap expands to scrollable list. Never truncate silently. |
| UX-EC-02 | Target tile obscured by forecast on small screen | Panel auto-repositions to opposite side of target; if both sides are obscured, panel floats 8pt above the target tile in a minimal 3-section form (sections 1, 2, 4 only). |
| UX-EC-03 | Mouse cursor jitter across tile boundary | Hysteresis: 40ms debounce before treating hover-off as dismiss. Below 40ms is treated as continued hover. |
| UX-EC-04 | Rapid-tap Beat 1 → Beat 1 on different targets | Only the latest Beat 1 target is tracked. Previous target's Beat 2 window is discarded. |
| UX-EC-05 | Accessibility screen-reader on forecast | Forecast sections are announced in order 1 → 4 → 2 → 3 → 5 → 6 (pillar priority: damage, hit, kill, counter, direction, passives). Full a11y spec in `design/ux/accessibility-requirements.md`. |
| UX-EC-06 | DEFEND_STANCE badge overlaps status seal | 守 badge takes precedence on upper-left; other status seals stack below in age order. Maximum 3 visible; oldest evicted per HP/Status rule. |
| UX-EC-07 | Victory screen mid-animation when player taps dismiss | Dismissal queues until animation completes (input blocked during Victory transition per Grid Battle CR-12). |

---

## 8. Acceptance Criteria

**AC-UX-HUD-01**: Given `attack_target_hovered` fires on Vulkan Forward+ reference
hardware (Pixel 7-class mobile), UI-GB-04 renders all applicable sections within
120ms measured via the deterministic two-frame seam in Grid Battle AC-GB-24.
**Sub-assertion — render-abort on hover-dismiss race (v1.1, §4.5)**: in a
companion test case, inject a cursor-exit event at frame 1 of the two-frame
layout+paint seam; assert panel visibility never transitions to true between
`attack_target_hovered` and the cursor-exit — no 1-frame flash. Panel remains
at visibility=false throughout.
— Type: Integration — Gate: BLOCKING — Co-owned with Grid Battle AC-GB-24.

**AC-UX-HUD-02**: Given a counter-attack that would reduce attacker HP to ≤ 0
on the max-roll of the 2RN distribution, the two-tier chevron renders the Tier 2
10px 斬 micro-glyph (not the Tier 1 dot). Given a counter-attack that fires but
does not kill on max-roll, the chevron renders the Tier 1 6px dot. Given no
counter, no indicator. All three cases use 묵 ink only; no pixel of the
indicator is 주홍 or 금색.
— Type: Unit — Gate: BLOCKING.

**AC-UX-HUD-03**: On PC (viewport ≥ 480pt), when the mouse cursor leaves the
target tile, UI-GB-04 dismisses within 80ms (hover-off immediate dismiss per §4.5).
Test injects mouse-off event at t=0, asserts panel visibility transitions to
false by t+80ms. Hysteresis (UX-EC-03) is tested independently with a t=20ms
bounce: panel must NOT dismiss.
— Type: Integration — Gate: BLOCKING.

**AC-UX-HUD-04**: On touch (viewport < 480pt), the UI-GB-04 chevron's hit area
measures at least 44×44pt regardless of visible glyph size. Test taps 22pt
outside the visible chevron edge; the tap must register as a chevron expand.
— Type: Unit — Gate: BLOCKING.

**AC-UX-HUD-05**: No pixel of any UI-GB-04 variant renders in 주홍 (#C0392B) or
its close neighbours (within ΔE 5.0). Test scans the rendered panel for
forbidden colours across all section-order variants (kill / no-kill, counter /
no-counter, Tier 1 / Tier 2).
— Type: Unit — Gate: BLOCKING.

**AC-UX-HUD-06**: CR-3b soft-lock resolution produces no user-facing error text.
Assert that no Label, RichTextLabel, or Toast node in the scene tree contains
the substring "soft-lock", "AI_SOFTLOCK", or "error" at any point during the
flush sequence of Grid Battle AC-GB-25.
— Type: Integration — Gate: BLOCKING.

**AC-UX-HUD-07**: DEFEND_STANCE 守 seal badge (UI-GB-11) renders on the defending
unit's tile at 40% opacity 묵 ink immediately on `status_applied(DEFEND_STANCE)`
and dismisses on the defender's next `unit_turn_started`. Test asserts badge
presence across exactly one full turn cycle, absent before and after.
— Type: Unit — Gate: BLOCKING.

**AC-UX-HUD-08**: Status seals for POISON/DEMORALIZED/DEFEND_STANCE/INSPIRED/
EXHAUSTED render the correct 漢字 (毒/喪/守/昂/疲 respectively). Test
parameterised over all 5 statuses; glyph identity asserted via OCR or rendered-
glyph hash against reference.
— Type: Unit — Gate: ADVISORY (glyph-hash comparison is brittle; visual review
backstop is acceptable).

**AC-UX-HUD-09 (v1.1 — DEFEND two-tap)**: Mobile DEFEND confirm flow per §5.2.
Given fixture `tests/fixtures/battle_hud/defend_two_tap.yaml` (Infantry unit on
turn, MOVE unspent, ACTION unspent, viewport width 390pt):
(1) Beat 1 = tap DEFEND row in UI-GB-02 → DEFEND button's `modulate.a` pulses
from 1.0 to 0.6 to 1.0 over 0.15s ±20ms; `TWO_TAP_TIMEOUT_S = 15s` timer
started; surrounding action-menu rows desaturate to 0.5 alpha. No Grid Battle
signal emitted yet. (2) Beat 2 = second tap on DEFEND row within timeout →
grid-battle emits `unit_defended(unit_id)` followed by `unit_turn_ended(
unit_id)`; menu dismisses with 80ms fade. (3) Cancel path — tap an empty
tile during Beat-1 pending state → menu closes, no `unit_defended` emitted
(assert via `monitor_signals()` + `is_not_emitted()`). (4) Timeout path —
wait `TWO_TAP_TIMEOUT_S + 100ms` without Beat 2 → menu remains open; button
pulse clears; no `unit_defended`. (5) Accessibility: the DEFEND row's
effective touch-target is ≥ 44×44pt (§6.3). (6) **No long-press gesture
is registered anywhere in the flow** — assert no `InputEventScreenTouch`
consumer has `pressed == true` for > 500ms as a gating condition; long-press
detection MUST NOT be wired to DEFEND.
— Type: Integration — Fixture: `tests/fixtures/battle_hud/defend_two_tap.yaml` — File: `tests/integration/battle_hud/battle_hud_defend_two_tap_test.gd` — Gate: BLOCKING.

---

## 9. Dependencies

### Upstream (this spec consumes)

| System | GDD Status | What this spec uses |
|--------|-----------|---------------------|
| Grid Battle (`design/gdd/grid-battle.md`) | In review | CR-3b soft-lock states, CR-6 counter-eligibility, `damage_resolve()` output (F-DC-3..F-DC-6 in `damage-calc.md` — v5.0 retirement of F-GB-PROV), F-GB-2 hit-semantics, `attack_target_hovered` signal |
| Input Handling (`design/gdd/input-handling.md`) | Designed | S0–S5 state machine, two-beat confirmation model |
| Art Bible (`design/art/art-bible.md`) | Complete | Palette, 묵화 transition, seal iconography |
| Technical Preferences | Complete | 44pt touch target, Vulkan Forward+ pin |

### Downstream (this spec constrains)

| System | Status | What this spec provides |
|--------|--------|-------------------------|
| Battle UI implementation | Not yet started | All of UI-GB-01..11, the 12 visual/audio specs, §4 forecast contract |
| Accessibility requirements spec | Not yet authored | Colorblind shape-distinction rules, screen-reader order |
| Animation system | Not yet started | Animation durations and triggers from §2 |
| Audio system | Not yet started | SFX/music cues from §2 |

---

## 10. Tuning Knobs

| Knob | Default | Safe Range | Affects |
|------|---------|------------|---------|
| `FORECAST_RENDER_BUDGET_MS` | 120 | 80–200 | UI-GB-04 frame-time budget under Forward+ renderer. Below 80: device-specific failures in real deployment. Above 200: forecast feels laggy; Pillar 1 reading flow degrades. |
| `FORECAST_DISMISS_FADE_MS` | 80 | 40–200 | PC hover-off fade duration. Too short: jarring. Too long: feels sticky. |
| `FORECAST_SWITCH_CROSSFADE_MS` | 60 | 30–150 | Cross-fade when switching target without dismiss. |
| `HOVER_HYSTERESIS_MS` | 40 | 20–100 | Mouse-jitter debounce (UX-EC-03). |
| `TWO_TAP_TIMEOUT_S` | 15.0 | 8.0–30.0 | Touch Beat 1 → Beat 2 window. Owned jointly with Grid Battle. |
| `CHEVRON_DOT_PX` | 6 | 4–10 | Tier 1 counter indicator diameter. |
| `CHEVRON_GLYPH_PX` | 10 | 8–14 | Tier 2 斬 micro-glyph size. |
| `CHEVRON_HIT_AREA_PT` | 44 | 44–60 | Fixed at project touch-target minimum; upper bound for accessibility-preferred enlargement. |
| `STATUS_SEAL_OPACITY` | 0.40 | 0.30–0.60 | Per-status overlay opacity. |
| `DEATH_TRANSITION_S` | 1.3 | 0.8–2.5 | 묵화 death visual duration. |

---

## 11. Open Questions

1. **Gamepad input flow** — full spec deferred to `design/ux/gamepad-input.md`. Target: Alpha milestone.
2. **Accessibility requirements** — screen-reader order, keyboard flow, text-scaling rules all deferred to `design/ux/accessibility-requirements.md`. Target: before first playtest.
3. **UI-GB-04 forecast section reordering** — current order is pillar-priority, but accessibility review may suggest damage → hit → direction → kill → counter → passives. Pending a11y lead review.
4. **Non-MVP status icons** — additional status types (BURN, FREEZE, STUN) from future content; iconography not yet designed.
5. **Rendered-glyph hash for AC-UX-HUD-08** — investigate whether Godot 4.6 offers a stable glyph hash API; if not, this AC remains ADVISORY with visual backstop.
