# Accessibility Requirements — 천명역전 (Defying Destiny)

| Field | Value |
|---|---|
| Tier | **Intermediate** |
| Tier Committed | 2026-04-18 |
| Next Review | Pre-Production → Production gate (Alpha) |
| Supersedes | — (first authoring) |
| Owner | accessibility-specialist (review), ux-designer (screen-level compliance), producer (tier decisions) |

---

## 1. Tier Commitment

**Committed tier: Intermediate.**

Rationale:
- The game assigns load-bearing semantics to reserved colors — 주홍 (#C0392B) for tragedy / loss branches and 금색 (#D4A017) for triumph / accession branches. Under deuteranopia and protanopia these colors collapse toward similar brown-gold hues, which would erase the destiny-branch signal. Basic tier would be negligent under this design.
- Advanced tier requires AccessKit integration (Godot 4.5+), which is a **HIGH post-cutoff engine surface** the LLM does not reliably know. Taking on AccessKit before running an engine-reference verification pass would create implementation risk disproportionate to the tier-promotion value.
- Intermediate captures ~90% of player-impact accessibility coverage at ~40% of Advanced's implementation cost (solo-indie capacity constraint).

Re-review is scheduled at Pre-Production → Production gate. If that review elects Advanced, AccessKit engine-reference verification must be completed first (`docs/engine-reference/godot/modules/accessibility.md` — currently a stub).

---

## 2. In Scope (Intermediate tier commitments)

| Feature | Commitment |
|---|---|
| **Text scaling** | 100% / 125% / 150% via settings toggle. All text Control nodes must scale without layout break. |
| **Subtitles** | ON by default. Required for every audio cue flagged `has_narrative_weight: true` in sound catalog. |
| **Input remapping** | All 22 actions remappable (10 grid + 4 camera + 5 menu + 3 meta per Input Handling GDD). Persisted to `user://settings.tres`. |
| **Colorblind modes** | Three modes: deuteranopia, protanopia, tritanopia. Implemented via ColorPalette Resource swap (not shader) to preserve ink-wash aesthetic. |
| **Reduced motion** | Toggle disables screen-shake, particle-emitter VFX above 20 per second, and Beat 2 animation beyond static glyph. |
| **High-contrast UI** | Alternate Theme resource, toggleable in settings. All text/background pairs must meet WCAG 2.1 AA contrast ratio. |
| **Reduce haptics** *(rev 1.1 — 7th Intermediate toggle per destiny-branch rev 1.3 D1 decision 2026-04-19)* | Toggle disables haptic pulse / gamepad rumble on all gameplay interaction cues (destiny-branch A-DB-2 Beat 7 reserved-color haptic is the primary consumer). When enabled, haptic-emitting code paths are no-ops; the visual + audio channels carry the signal. Distinct knob from Reduced motion — a player may want motion suppressed but haptic retained (or vice versa). WCAG SC 2.3.3 "Animation from Interactions" governs the boundary. |
| **Touch targets ≥ 44×44 px** | Enforced via `camera_zoom_min = 0.70` (Input Handling TR-input-010) — already locked in `.claude/docs/technical-preferences.md`. |

---

## 3. Out of Scope (deferred to Full Vision tier)

- Screen reader / AccessKit integration (Godot 4.5+, HIGH post-cutoff engine risk)
- One-handed mode
- Cognitive-load presets (timer extensions, skip-able narrative beats beyond the Beat 2 reduced-motion handling in §4 R-3)
- Dyslexia-friendly font option
- Per-disability customization UI
- Full narration pipeline

Deferral rationale: each of these either depends on AccessKit (which requires engine-reference verification first) or requires design effort disproportionate to solo-indie capacity at MVP / VS tier. Re-evaluate at Full Vision scoping.

---

## 4. Project-Specific Requirements (mandatory regardless of tier)

These requirements propagate into Battle HUD, Scenario Progression, Story Event, and Settings specs. They are NOT optional under the Intermediate tier commitment.

### R-1 — Reserved destiny colors MUST have alternate encoding

주홍 (#C0392B) and 금색 (#D4A017) lose distinguishability under deuteranopia and protanopia. The destiny-branch semantic MUST be readable via at least one non-color channel in every UI that shows branch state.

**Required alternate channels** (all three applied redundantly — not alternatives):
1. **Unique iconography**: glyph per destiny state. Candidate set (subject to writer / narrative-director approval): 검 (sword) glyph for 주홍 / tragedy; 관 (crown) glyph for 금색 / triumph. Glyphs must be at least 32×32 px rendered size.
2. **Korean character prefix in UI text**: `[凶]` (xiōng, misfortune) for 주홍 outcomes; `[吉]` (jí, auspicious) for 금색 outcomes. Prefix appears in outcome banner, save-slot summary, epilogue header.
3. **Distinct animation signature**: beat cadence for 주홍 ≠ cadence for 금색. Applied to destiny-reveal moments (Beat 2 and Beat 7 per Scenario Progression v2.0). Minimum difference: envelope shape or onset timing differs by ≥ 300 ms.

Verification: AC-A11Y-2 and AC-A11Y-7 below.

### R-2 — Grid positional information MUST be text-readable

Tile selection and unit status MUST be conveyable entirely through text, without relying on visual indicators (color, icon placement, camera framing). This prepares for Advanced tier AccessKit work and ensures colorblind playability of the core tactical loop.

Required format for Battle HUD tile-info panel:
```
"Col [c] Row [r] · [terrain_type] · [occupant_role] [occupant_name] · HP [current]/[max]"
```
Example: `"Col 5 Row 3 · Forest · Enemy Archer Liu Bei · HP 24/40"`

Touch Tap Preview Protocol (Input Handling 80–120 px floating panel) already aligns with this contract — Battle HUD UX spec must fold R-2 into the panel content.

**R-2 Formation State Token (v1.2 — Formation Bonus v1.1 cross-doc obligation):**

When the tile-info panel announces a unit with an active formation snapshot entry, the panel text MUST append Formation state tokens to the existing R-2 string. Full announced format:

```
"Col [c] Row [r] · [terrain_type] · [occupant_role] [occupant_name] · HP [current]/[max] · [formation_tokens]"
```

Formation token format:

- **Pattern participation**: `FORMATION: [pattern_name_ko] ([role])`
  - `[pattern_name_ko]`: display name from `formations.json` `name` field (e.g., `어진형`, `방진`).
  - `[role]`: `anchor` if unit is the anchor unit of the pattern; `member` if non-anchor participant.
  - Example: `FORMATION: 어진형 (anchor)`

- **Relationship bond**: `BOND: [relation_type_label] with [hero_name_ko]`
  - `[relation_type_label]`: localized label. Default KO strings: SWORN_BROTHER → `의형제`; LORD_VASSAL → `군신`; RIVAL → `숙적`; MENTOR_STUDENT → `사제`.
  - `[hero_name_ko]`: the partner hero's display name from Hero Database.
  - Example: `BOND: 의형제 with 장비`

- **Multi-state (unit is anchor of pattern AND holds a relationship bond)**: announce BOTH tokens, separated by semicolon, Formation first, Bond second:
  - Example: `FORMATION: 어진형 (anchor); BOND: 의형제 with 장비`

- **Multiple relationships**: if a unit has two active bonds, announce each BOND token separated by semicolon:
  - Example: `BOND: 의형제 with 관우; BOND: 사제 with 제갈량`

- **No active formation**: token omitted entirely. R-2 base string unchanged.

This token appears in the R-2 focus-announcement string. Compatibility note: current Intermediate tier defers AccessKit screen-reader integration to Full Vision (§3), but R-2 is a text-completeness requirement independent of AccessKit — the token must appear in the panel's visible text at the time of tap/focus, as stated in the original R-2 contract. When AccessKit is adopted at Full Vision, the same token string feeds the accessibility node announcement without change.

Cross-reference: `design/ux/battle-hud.md` §3.1 UI-GB-14 (Formation Aura visual), UI-GB-04 §4.1 §6 (Formation forecast Passives line), `design/gdd/formation-bonus.md` CR-FB-1 through CR-FB-14.

**Formation color contrast obligation (v1.2 — tracked advisory):** `design/ux/battle-hud.md` §3.1 UI-GB-14 proposes **청록 #3A7D6E** as the Formation palette entry. The measured WCAG 2.1 SC 1.4.11 contrast ratio of this hex against the project's standard tile background colors (grass, dirt, stone) is **TBD** and must be verified by the art-director before UI-GB-14 ships. If the ratio falls below 3:1 on any tile background, the hex must be corrected and battle-hud.md §3.1 updated to match. This advisory parallels the existing Grid Battle pass-11c 황금 #C9A84C contrast tracking pattern established for Rally (UI-GB-13).

### R-3 — Beat 2 envelope MUST have reduced-motion alternative

Scenario Progression v2.0 defines Beat 2 animation envelope at 4.0–6.0 s (AC-SP-6 floor). Under reduced-motion setting:
- Collapse envelope to minimum duration (4.0 s — NOT below, to preserve AC-SP-6)
- Beat 2 animation reduces to a single static glyph + audio cue (no motion)
- Tap-to-dismiss becomes available immediately after the 4.0 s floor

Beat 7 dwell-lockout (narrative gate) is NOT overridden by reduced-motion — it is a gameplay gate, not a motion-for-motion's-sake animation.

Coordination required: narrative-director must confirm this reduction does not regress Scenario Progression v2.0 AC-SP-6 or Beat 2 pillar commitment (see OQ-4 below).

### R-4 — Touch targets ≥ 44×44 px

Already enforced via `camera_zoom_min = 0.70` (Input Handling TR-input-010). No additional work required in this doc; included here for completeness and cross-reference.

### R-5 — Subtitle style

- **Text color**: white (#FFFFFF)
- **Background**: 80% black overlay bar (#000000 at alpha 0.8)
- **Font size**: 18 pt minimum at 100% text scale; 24 pt minimum at 150% text scale
- **Position**: bottom center of viewport, above HUD action bar
- **Latency**: ≤ 100 ms from audio onset
- **Line limit**: 2 lines maximum; longer content pages with fade

---

## 5. Engine Dependencies (Godot 4.6)

| Feature | Godot API | Risk | Notes |
|---|---|---|---|
| Text scaling | `Theme.default_font_size` + Control-tree propagation | LOW | Stable 4.0+. |
| Subtitles | `Label` + `CanvasLayer` z-order | LOW | Stable. |
| Input remapping | `InputMap` runtime mutation + serialize to `user://settings.tres` | **MEDIUM** | Godot 4.5 SDL3 gamepad driver changes the gamepad code path — verify against `docs/engine-reference/godot/modules/input.md` before ADR-0005 lands. |
| Colorblind modes | Per-theme variant swap + `ColorPalette` Resource (no shader) | LOW | Theme switching stable 4.0+. Preserves ink-wash rendering aesthetic. |
| Reduced motion | `bool` in `Settings.tres`, consumed via GameBus `settings_changed(category, value)` | LOW | Plain signal contract. |
| High contrast | Second `Theme` resource + settings-toggle switch | LOW | Plain theme swap. |
| Touch 44 px | Camera zoom clamp (Input Handling TR-input-010) | LOW | Already enforced. |

**Accessibility row in architecture Engine Knowledge Gap Summary**: strike "blocked until `design/accessibility-requirements.md` exists" — this document now exists. The Accessibility row remains HIGH risk only for AccessKit-tier commitments (out of scope at Intermediate).

---

## 6. Acceptance Criteria (testable)

| ID | Criterion | Test method |
|---|---|---|
| AC-A11Y-1 | All text-displaying Control nodes in Battle HUD scale correctly at 100 % / 125 % / 150 % without layout break or clipping. | Screenshot-diff test across 3 scale settings; QA evidence in `production/qa/evidence/a11y-textscale-[date]/`. |
| AC-A11Y-2 | All four destiny-branch outcome screens are distinguishable under deuteranopia, protanopia, and tritanopia simulation. | Coblis simulator (or equivalent) screenshot comparison; ≥ 1 external CVD playtester confirms distinguishability (see OQ-2). |
| AC-A11Y-3 | Every one of 22 input actions (10 grid + 4 camera + 5 menu + 3 meta) is remappable via Settings; remapping persists in `user://settings.tres` across sessions. | Automated test walks every action, rebinds, restarts, verifies binding retained. |
| AC-A11Y-4 | Reduced-motion toggle disables: screen-shake, particle-emitter VFX > 20 /s, Beat 2 animation beyond static glyph. | Per-system QA smoke with toggle on/off; visual diff for VFX systems. |
| AC-A11Y-5 | High-contrast mode: all text-on-background pairs meet WCAG 2.1 AA — 4.5 : 1 for normal text, 3 : 1 for large text (≥ 18 pt). | Contrast ratio check tool against all Theme pairs in high-contrast variant. |
| AC-A11Y-6 | Subtitles appear for 100 % of audio cues flagged `has_narrative_weight: true`; latency ≤ 100 ms from audio onset. | Automated audio-cue sample test; timing measured via frame capture. |
| AC-A11Y-7 | Destiny outcome is communicable without color and without icons: a player using the dev flag `--no-color --no-icons` can still distinguish tragedy from triumph branches via UI text prefix (`[凶]` / `[吉]`). | Dev-flag smoke test; outcome-screen text is the sole distinguishing signal. |

---

## 7. System Dependencies

Accessibility requirements propagate into these systems. Each system's design doc must fold in the corresponding requirement during its next revision or initial authoring.

| System | GDD status | Accessibility touchpoint | Action required |
|---|---|---|---|
| Input Handling (#29) | Designed | 22-action remapping + 44 px touch floor | REQ: settings.tres persistence contract (fold into ADR-0005) |
| Battle HUD (#18) | Not Started | Text scaling + R-1 destiny icon + R-2 textual tile-info | REQ: R-1 through R-5 folded into UX spec at first authoring |
| Settings / Options (#28) | Not Started (Alpha — elevated per OQ-3 2026-04-18) | Toggle surface for all **7** Intermediate toggles (rev 1.1 — 7th toggle `reduce_haptics` added 2026-04-19 per destiny-branch rev 1.3 D1) | OQ-3 resolved 2026-04-18; rev 1.1 adds scope for `reduce_haptics` toggle |
| Destiny Branch (#4) | In Review (rev 1.3 post-ninth-pass) | R-1 reserved-color alternate encoding (color + audio 해금 + haptic triad per IP-006 Beat-7 ceremonial carve-out); `reduce_haptics` toggle opt-out path; V-DB-4 error-dialog R-1..R-5 gate (AC-DB-38 BLOCKING VS) | Rev 1.3 BLOCKING cross-doc binding: A-DB-2 + UI-DB-4 matrix + AC-DB-38 cite this file. Added for pass-9 ux B-UX-9-2 + a11y B-1 consistency. |
| Sound / Music System (#24) | Not Started | `has_narrative_weight` flag on audio catalog; subtitle generation pipeline | REQ: schema field added at first authoring |
| Scenario Progression (#6) | Designed (v2.0 review pending) | R-3 Beat 2 reduced-motion alternative | REQ: R-3 folded into next revision; narrative-director confirmation of AC-SP-6 non-regression |
| Damage/Combat Calculation (#11) | Designed (rev 2.5) | Reduce Motion popup lifecycle + TalkBack announcements | REQ: `damage-calc.md` UI-4 cross-refs §4 R-3 + §2 Reduced motion row. In-game Settings toggle is MVP activation path (Vertical Slice via Settings #28 Alpha elevation); OS-flag bridging deferred to Full Vision AccessKit. WCAG SC 2.3.3 "Animation from Interactions" governs the 1.55s popup lifecycle under Reduce Motion. Bidirectional citation per damage-calc.md rev 2.5 BLK-6-8. |
| Story Event (#10) | Not Started | R-1 destiny color encoding in story beats | REQ: R-1 folded into UX spec at first authoring |
| Localization (#30) | Not Started (Full Vision) | Destiny glyph `[凶]` / `[吉]` locale behaviour | OQ-1 carried forward |

---

## 8. Open Questions

| ID | Question | Owner | Blocking? |
|---|---|---|---|
| OQ-1 | Korean-native destiny glyphs `[凶]` / `[吉]` — how do they scale to English / Japanese / Chinese builds at Full Vision tier? Replace with locale-appropriate character, or keep Korean as a cross-locale constant brand mark? | localization-lead | No — defer to Polish. |
| OQ-2 | External playtester with declared CVD budget before Pre-Production → Production gate. At least one CVD external playtest required to validate AC-A11Y-2. Solo playtest alone insufficient. | producer | Advisory — must be budgeted before Alpha. |
| ~~OQ-3~~ | ~~Settings / Options (#28) tier elevation~~ — ✅ **resolved 2026-04-18**: Settings/Options (#28) elevated **Full Vision → Alpha** in `design/gdd/systems-index.md` (option [i] per recommendation). Intermediate a11y toggles will be player-exposable at Alpha milestone. Systems-index progress tracker updated (Alpha 0/6 → 0/7; Full Vision 0/4 → 0/3). | producer | ✅ resolved |
| OQ-4 | R-3 Beat 2 reduced-motion collapse to 4.0 s floor — does this regress Scenario Progression v2.0 AC-SP-6 or Beat 2 pillar commitment? If yes, alternative: render beat as audio-only cue with screen-reader-compatible text surface. | narrative-director | Advisory — resolve before Battle HUD spec lands. |

---

## 9. Review & Revision

| Date | Version | Change |
|---|---|---|
| 2026-04-18 | 1.0 | Initial authoring. Intermediate tier committed. R-1 through R-5 locked. 7 AC-A11Y criteria locked. 4 OQs logged; OQ-3 flagged as blocking. |
| 2026-04-19 | 1.1 | Added back-reference row in §7 System Dependencies for Damage/Combat Calculation (#11) per damage-calc.md rev 2.5 BLK-6-8 bidirectional-citation fix. No tier change, no new commitments. |
| 2026-04-19 | 1.1 (rev) | Added 7th Intermediate toggle `reduce_haptics` to §2 (rev 1.3 D1 decision on destiny-branch.md 2026-04-19 pass-9 — closes game-designer B-1 + ux B-UX-9-2 + a11y B-1 convergence). Updated §7 Settings/Options #28 toggle-count 6→7 and OQ-3 state to resolved. Added §7 Destiny Branch (#4) cross-reference row for A-DB-2 + UI-DB-4 + AC-DB-38 bindings. No tier change (Intermediate); Settings/Options #28 implementation-story scope expanded by one toggle. |
| 2026-04-20 | 1.2 | Added R-2 Formation State Token spec (§4) per Formation Bonus v1.1 cross-doc obligation (ux-designer pass-1 BLOCKER). Added Formation color contrast obligation advisory (청록 #3A7D6E — parallels pass-11c 황금 #C9A84C tracking). No tier change. |

Next review: Pre-Production → Production gate. Tier upgrade to Advanced is possible only after AccessKit engine-reference verification and OQ-3 resolution.
