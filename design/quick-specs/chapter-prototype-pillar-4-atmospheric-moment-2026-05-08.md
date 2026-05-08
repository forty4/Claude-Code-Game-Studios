# Quick Design Spec: Chapter-Prototype Pillar 4 Atmospheric Moment

**Type**: Addition
**System**: Chapter Prototype (throwaway demo surface) — implements Beat 7 atmospheric moment per `scenario-progression.md` §V.3 + `destiny-branch.md` Player Fantasy
**GDD Reference**: `design/gdd/scenario-progression.md` §V.3 Reserved Color Protocol + AC-SP-7 + AC-SP-9 dwell lockout; `design/gdd/destiny-branch.md` Player Fantasy + Overview ("ceremonial witness" 30-sec moment); `design/art/art-bible.md` Reserved Colors
**Date**: 2026-05-08
**Sprint Tracker**: S12-02 (sprint-12 Must-Have; gate-check 2026-05-08 path-to-PASS item 3)

## Change Summary

Demonstrate Pillar 4 (삼국지의 숨결) atmospheric moment in `prototypes/chapter-prototype/` by applying the GDD-spec'd reserved-color treatment + synthesized audio cue at REWRITTEN-branch resolution only. Closes gate-check 2026-05-08 path-to-PASS item 3.

## Motivation

Gate-check 2026-05-08 verdict CONCERNS lists "ship ≥1 player-facing Pillar 3 OR Pillar 4 demonstration" as path-to-PASS item 3. The atmospheric branch-resolution moment is the canonical Pillar 4 payoff per `destiny-branch.md` Player Fantasy ("ceremonial witness — when a non-default branch fires, reserved colors enter the frame for the first and only time that chapter, and the player — without ever seeing a branch menu — registers that history just took a different path because of what they did"). All design work is complete; this slice wires implementation in the prototype where the branch-resolution code already runs. Production `src/scenario/` integration is deferred — the production scenario runner does not exist yet (chapter-prototype is the only Pillar-4 surface at sprint-12).

## Design Delta

The chapter-prototype currently calls `_show_result_phase()` → `_judge_fate()` at `prototypes/chapter-prototype/chapter.gd:391-464` and writes branch-typed title color + body text directly into `_result_panel`. **There is no atmospheric layer**: no dwell, no panel tint, no audio cue. The REWRITTEN branch's title color is currently `Color(1, 0.85, 0.2)` — close to but not aligned with art-bible's reserved 금색 `#D4A017`.

This spec adds a sequenced atmospheric layer **for REWRITTEN-branch only**:

1. At result-phase entry on REWRITTEN: gate the title/body text reveal behind a 1.5s dwell (per GDD AC-SP-9). During dwell, fade in 주홍 `#C0392B` panel-tint overlay (35% alpha) + emit synthesized 묵-wash audio cue. After dwell, reveal title in canonical 금색 `#D4A017` + body.
2. DEFEAT / HISTORICAL / PARTIAL branches — no change (per `scenario-progression.md` §V.3 "Beat 7 default WIN branches: standard 묵 panel … no vignette. Absence of reserved colors is the affirmative signal").

## New Rules / Values

### Atmospheric Slice (REWRITTEN branch only)

**Reserved-color application surface**:
- Panel-tint overlay: `ColorRect` at front of `_result_panel`, color `#C0392B`, alpha 0.35, full-rect.
- Envelope: fade-in 0.4s easeOut → hold 1.1s → fade-out 0.2s easeIn after dwell ends. Total 1.7s envelope.
- Title/body labels reveal (alpha 0→1) over the same envelope tail, settling at dwell-end.

**Title color**: `#D4A017` (canonical 금색; replaces existing `Color(1, 0.85, 0.2)`).

**Audio cue source**: synthesized procedural tone via `AudioStreamGenerator` (no new asset commission). Single ink-wash 묵 hum:
- 220Hz fundamental + 330Hz harmonic at −6dB.
- 1.2s total duration: 200ms ease-in attack + 600ms sustain + 400ms decay.
- One-shot `AudioStreamPlayer` child of `_result_panel`.
- Output volume −12dB.

**Dwell lockout**: Result-panel buttons (`다시 도전` / `스토리로`) `disabled = true` for 1.5s after `_show_result_phase()` entry on REWRITTEN-branch. Re-enabled at dwell end. Other branches: no dwell, buttons immediately interactive (current behavior).

### Tuning Knobs (prototype-side; inline constants per `.claude/rules/prototype-code.md`)

| Knob | Default | Range | Rationale |
|------|---------|-------|-----------|
| `RESERVED_COLOR_VERMILION` | `Color8(0xC0,0x39,0x2B)` | locked by Art Bible | 주홍 — Beat 7 panel tint |
| `RESERVED_COLOR_GOLD` | `Color8(0xD4,0xA0,0x17)` | locked by Art Bible | 금색 — Beat 7 title color |
| `DWELL_LOCKOUT_S` | `1.5` | `[1.0, 2.0]` | Per AC-SP-9 |
| `PANEL_TINT_ALPHA` | `0.35` | `[0.20, 0.50]` | Reads as wash, not solid; demo-tunable |
| `AUDIO_CUE_FUNDAMENTAL_HZ` | `220.0` | `[180.0, 280.0]` | 묵 wash low-hum register |
| `AUDIO_CUE_HARMONIC_HZ` | `330.0` | `[300.0, 380.0]` | Perfect-fifth-ish ceremonial |
| `AUDIO_CUE_DURATION_S` | `1.2` | `[0.8, 1.6]` | Aligns with dwell envelope |
| `AUDIO_CUE_VOLUME_DB` | `-12.0` | `[-18.0, -6.0]` | Ducks below result text reading |

Values are inline constants in `chapter.gd` per prototype-code rules (relaxed; no asset/data file).

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| `prototypes/chapter-prototype/chapter.gd` | Adds atmospheric moment dispatch on REWRITTEN branch + dwell lockout state | EDIT — primary work |
| `prototypes/chapter-prototype/chapter.tscn` | Adds `ColorRect` overlay node + `AudioStreamPlayer` node under `_result_panel` | EDIT — scene authoring |
| `prototypes/chapter-prototype/REPORT.md` | Updates Findings to note Pillar 4 atmospheric demonstration is now in-prototype | EDIT — finding update |
| `design/gdd/*` | NO CHANGE — design fully spec'd already | none |
| `src/` production code | NO CHANGE — prototype-isolated per `.claude/rules/prototype-code.md` | none |
| `tests/integration/chapter_prototype/atmospheric_moment_test.gd` | NEW integration test (1 new test asserting AC-S12-02-1/2/3) | NEW test file |

## Acceptance Criteria

- [ ] **AC-S12-02-1** When `_judge_fate()` resolves to `branch == "REWRITTEN"`, the `ColorRect` overlay tints `_result_panel` to `#C0392B` at 0.35 alpha within 0.4s of `_show_result_phase()` entry.
- [ ] **AC-S12-02-2** `AudioStreamPlayer` plays the synthesized 묵 hum cue (220Hz + 330Hz harmonic) at REWRITTEN-branch resolution; cue duration 1.2s; cue plays exactly once per resolution.
- [ ] **AC-S12-02-3** Result-panel buttons remain disabled (`disabled == true`) for 1.5s after REWRITTEN resolution; re-enable at dwell end.
- [ ] **AC-S12-02-4** Title color for REWRITTEN branch reads `#D4A017` (canonical 금색); replaces prior `Color(1, 0.85, 0.2)`.
- [ ] **AC-S12-02-5** For DEFEAT / HISTORICAL / PARTIAL branches: no panel tint, no audio cue, no dwell lockout (regression criterion — atmospheric layer is REWRITTEN-only).
- [ ] **AC-S12-02-6** Integration test at `tests/integration/chapter_prototype/atmospheric_moment_test.gd` asserts: (a) ColorRect overlay alpha > 0 within 0.5s of REWRITTEN resolution, (b) AudioStreamPlayer.playing == true within 0.1s of resolution, (c) result-panel buttons disabled at t=0.5s post-resolution and enabled at t=1.6s.
- [ ] **AC-S12-02-7** No regression: full test suite (1266 tests at sprint-12 baseline) passes 1267/1267 (1266 + 1 new) post-change.

## GDD Update Required?

**No.** The atmospheric moment behavior is fully spec'd in `scenario-progression.md` §V.3 Reserved Color Protocol + AC-SP-7 + AC-SP-9 (dwell lockout) and `destiny-branch.md` Player Fantasy. This spec only documents the prototype-side implementation slice; no design change.

## Out of Scope (deferred)

- **Production `src/scenario/` integration** — scheduled when production scenario runner code lands; this prototype demo is a stand-in until then.
- **Asset-commissioned audio cue** — synthesized procedural cue is the demo placeholder; replaced at audio-pass sprint.
- **Beat 7 full visual surface** (반신 portrait, 묵 dark panel takeover, ink-wash 번짐 wipe transition) — prototype omits per "demo, not production" framing.
- **Color-blind alternative treatment** for reserved colors (accessibility-requirements §X) — deferred to production integration where the full Beat 7 surface is built.

## Notes on Prototype-Code Rules

This spec lives wholly inside `prototypes/chapter-prototype/`. Per `.claude/rules/prototype-code.md`:
- Hardcoded color/Hz values OK (no data-driven config).
- Inline constants allowed; doc comments minimal.
- Test directly targets prototype scene (placed in `tests/integration/chapter_prototype/`).
- Prototype is NOT migrated to production; production scenario runner re-implements per GDD when authored.
- No production code references prototype.

## Implementation Notes (informational; non-binding)

These are hints for the `/dev-story` step — they are NOT acceptance criteria.

- The `AudioStreamGenerator` Godot 4.6 API uses `AudioStreamGeneratorPlayback.push_buffer(PackedVector2Array)` for stereo samples. A simple sine-stack fill loop populating `mix_rate * duration` frames is sufficient. Alternative: pre-bake samples into a `PackedVector2Array` via `_ready()` and feed once.
- For the dwell lockout, prefer `await get_tree().create_timer(DWELL_LOCKOUT_S).timeout` over a `Timer` node — keeps prototype `chapter.gd` self-contained.
- The ColorRect can be added to `chapter.tscn` as a child of `_result_panel`, with `mouse_filter = MOUSE_FILTER_IGNORE` so it does not eat clicks. Initial `modulate.a = 0.0`; tween modulate.a 0→0.35 over 0.4s.
