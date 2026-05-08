# Story 001: Pillar 4 Atmospheric Moment Dispatch (REWRITTEN branch)

> **Epic**: Chapter Prototype Demo
> **Status**: Complete (2026-05-08; sprint-12 S12-02; commit `aa55969`; 7 tests; 1273/1273 PASS 57th FFB; epic-terminal close 1/1)
> **Layer**: Demo (prototype-isolated)
> **Type**: Integration
> **Manifest Version**: (n/a — prototype-isolated; control-manifest does not gate prototype code per `.claude/rules/prototype-code.md`)
> **Sprint**: sprint-12 (S12-02 Must-Have)
> **Estimate**: 1.0d nominal (greenfield ÷5 → ~0.2d actual per sprint-12 mixed-mode velocity multiplier)

## Context

**GDD (quick-spec stand-in)**: `design/quick-specs/chapter-prototype-pillar-4-atmospheric-moment-2026-05-08.md`

**Cross-references**:
- `design/gdd/scenario-progression.md` §V.3 Reserved Color Protocol + AC-SP-7 + AC-SP-9
- `design/gdd/destiny-branch.md` Player Fantasy + Overview ("ceremonial witness" 30-sec moment)
- `design/art/art-bible.md` Reserved Colors (locked: 주홍 `#C0392B` + 금색 `#D4A017`)

**Requirement**: AC-S12-02-1..7 (sprint-tracker IDs). NOT in `tr-registry.yaml` —
prototype-isolated work; not gated by tr-registry coverage rules.

**ADR Governing Implementation**: None (prototype-isolated per
`.claude/rules/prototype-code.md`; production scenario runner integration will
be governed by ADR-0017 when authored).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `AudioStreamGenerator` + `AudioStreamGeneratorPlayback.push_buffer()`
is pre-cutoff stable API. Modulate-α tween (`Tween.tween_property()`) stable.
ColorRect + `add_theme_color_override()` stable. No post-cutoff API usage.

**Prototype Code Standards** (per `.claude/rules/prototype-code.md`):
- Hardcoded color/Hz values OK (inline `const` block at top of `chapter.gd`).
- Minimal doc comments OK.
- No production code may import from `prototypes/`.

---

## Acceptance Criteria

*From quick-spec; carried 1:1:*

- [ ] **AC-S12-02-1** When `_judge_fate()` resolves to `branch == "REWRITTEN"`, ColorRect overlay tints `_result_panel` to `#C0392B` at 0.35 alpha within 0.4s of `_show_result_phase()` entry.
- [ ] **AC-S12-02-2** AudioStreamPlayer plays synthesized 묵 hum cue (220Hz + 330Hz harmonic) at REWRITTEN-branch resolution; cue duration 1.2s; cue plays exactly once per resolution.
- [ ] **AC-S12-02-3** Result-panel buttons (`다시 도전` / `스토리로`) `disabled == true` for 1.5s after REWRITTEN resolution; re-enabled at dwell end.
- [ ] **AC-S12-02-4** Title color for REWRITTEN branch reads `#D4A017` (canonical 금색); replaces prior `Color(1, 0.85, 0.2)`.
- [ ] **AC-S12-02-5** For DEFEAT / HISTORICAL / PARTIAL branches: no panel tint, no audio cue, no dwell lockout (regression criterion — atmospheric layer is REWRITTEN-only).
- [ ] **AC-S12-02-6** Integration test asserts (a) ColorRect alpha > 0 within 0.5s of REWRITTEN resolution, (b) AudioStreamPlayer.playing == true within 0.1s of resolution, (c) buttons disabled at t=0.5s, enabled at t=1.6s.
- [ ] **AC-S12-02-7** No regression: full test suite passes 1267/1267 (1266 + 1 new) post-change.

---

## Implementation Notes

*From quick-spec §Implementation Notes (informational; non-binding):*

1. **Audio**: Use `AudioStreamGenerator` (Godot 4.6 stable). Get `AudioStreamGeneratorPlayback` via `audio_player.get_stream_playback()` after `play()`. Pre-bake `PackedVector2Array` of stereo samples in `_ready()`: `mix_rate * AUDIO_CUE_DURATION_S` frames; per-sample `value = sin(2π * freq * t) * envelope` summed across fundamental + harmonic; envelope = ease-in (0..0.2s) + sustain (0.2..0.8s) + decay (0.8..1.2s).
2. **Dwell**: prefer `await get_tree().create_timer(DWELL_LOCKOUT_S).timeout` over a Timer node. Keeps `chapter.gd` self-contained (no scene-tree dependency).
3. **ColorRect**: child of `_result_panel`, `mouse_filter = MOUSE_FILTER_IGNORE` (do not eat clicks), initial `modulate.a = 0.0`. Tween `modulate:a` 0→0.35 over 0.4s using `Tween.TRANS_CUBIC`, `Tween.EASE_OUT`.
4. **Title color**: `result_title.add_theme_color_override("font_color", Color8(0xD4, 0xA0, 0x17))`. Override REPLACES the existing `Color(1, 0.85, 0.2)` line at `chapter.gd:433`.
5. **Constants**: live as inline `const` block at top of `chapter.gd` (per prototype-code rules; no `assets/data/` config). Names per quick-spec §Tuning Knobs table.

---

## Out of Scope

*Per quick-spec §Out of Scope:*

- Production `src/scenario/` integration (deferred until scenario runner production code lands).
- Asset-commissioned audio cue (synthesized cue is the demo placeholder; replaced at audio-pass sprint).
- Beat 7 full visual surface (반신 portrait / 묵 dark panel takeover / ink-wash 번짐 wipe transition).
- Color-blind alternative treatment for reserved colors (`accessibility-requirements.md` §X — production-integration deferral).

---

## QA Test Cases

*Lean review-mode (per `production/review-mode.txt` = `lean`): QL-STORY-READY
gate skipped. Test cases authored from AC list directly using Given/When/Then
format. Developer implements against these specs.*

- **AC-S12-02-1** ColorRect tint on REWRITTEN
  - **Given**: chapter-prototype scene loaded; battle ends with all 5 fate conditions met (triggers REWRITTEN)
  - **When**: `_show_result_phase()` is called
  - **Then**: ColorRect overlay child of `_result_panel` has `color == Color8(0xC0,0x39,0x2B)` and `modulate.a >= 0.34` within 0.5s
  - **Edge cases**: tint NOT applied when branch != REWRITTEN (covered by AC-S12-02-5 test sweep)

- **AC-S12-02-2** Audio cue plays exactly once
  - **Given**: chapter-prototype scene loaded
  - **When**: REWRITTEN branch resolves
  - **Then**: AudioStreamPlayer child of `_result_panel` has `.playing == true` within 0.1s; `.stream_paused == false`; cue ends within 1.3s
  - **Edge cases**: re-running `_show_result_phase()` does NOT stack cues (verify single AudioStreamPlayer instance reused or stop-then-replay); non-REWRITTEN branches do NOT trigger cue

- **AC-S12-02-3** Dwell lockout disables buttons
  - **Given**: REWRITTEN branch just resolved
  - **When**: t=0.5s post-resolution
  - **Then**: result-panel buttons (`다시 도전`, `스토리로`) `disabled == true`
  - **Edge cases**: at t=1.6s post-resolution, both buttons `disabled == false`

- **AC-S12-02-4** Title color matches canonical 금색
  - **Given**: REWRITTEN branch resolved (post-dwell)
  - **When**: ResultTitle Label is inspected
  - **Then**: theme color override `"font_color"` equals `Color8(0xD4,0xA0,0x17)` (within ±1 channel byte tolerance for any color-space conversion)

- **AC-S12-02-5** Other branches unchanged (regression)
  - **Given**: chapter-prototype with battle resolving to DEFEAT, HISTORICAL, or PARTIAL
  - **When**: `_show_result_phase()` runs
  - **Then**: ColorRect overlay `modulate.a == 0` throughout result phase; AudioStreamPlayer.playing == false; buttons enabled immediately (no dwell)
  - **Edge cases**: each of the 3 non-REWRITTEN branches independently tested in same test file

- **AC-S12-02-6** Integration test composite assertion
  - **Test file**: `tests/integration/chapter_prototype/atmospheric_moment_test.gd`
  - **Setup**: stub `_battle_outcome` with all 5 fate conditions met → triggers REWRITTEN; non-REWRITTEN tests stub fewer conditions
  - **Asserts**: (a) ColorRect alpha > 0 within 0.5s of REWRITTEN resolution; (b) AudioStreamPlayer.playing == true within 0.1s of resolution; (c) buttons disabled at t=0.5s and enabled at t=1.6s

- **AC-S12-02-7** Full suite regression
  - **Pre-change baseline**: 1266 PASS / 0 FAIL (sprint-12 baseline at `3b2cb0d`)
  - **Post-change target**: 1267 PASS / 0 FAIL (1266 existing + 1 new integration test)
  - **Verification command**: `godot --headless --script tests/gdunit4_runner.gd` (per coding-standards.md CI rule)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/chapter_prototype/atmospheric_moment_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: None (prototype self-contained; `prototypes/chapter-prototype/chapter.tscn` already exists; no upstream stories required)
- **Unlocks**: gate-check 2026-05-08 path-to-PASS item 3 close-out (S12-03 close-gate rerun candidate; combined with S12-10 + S12-11 user attestations could flip CONCERNS → PASS)

---

## Performance Budget

- **Frame budget impact**: <0.5ms per frame during atmospheric envelope (1.7s window). ColorRect modulate animation is GPU-trivial; AudioStreamGenerator buffer feed is one-time at scene-enter.
- **Memory impact**: ~414 KiB for pre-baked PackedVector2Array (44100 Hz × 1.2s × 8 bytes per Vector2 stereo sample ≈ 423,360 bytes). One-time allocation per chapter scene load; freed at scene exit.
- **Headless test runtime**: <2.0s (dwell + cue envelope = 1.7s; setup + teardown overhead ~0.3s).

---

## Completion Notes

**Completed**: 2026-05-08 (sprint-12 S12-02; implementation commit `aa55969` /dev-story patch; close-out via /story-done same day)
**Criteria**: 7/7 PASSING (all auto-verified via `tests/integration/chapter_prototype/atmospheric_moment_test.gd` 7 functions + full-suite green)
**Test Coverage**: 100% AC-COVERED via 7 granular test functions (vs spec's 1-composite expectation — better failure isolation)
**Test budget**: spec called for +1; actual +7 (1266 → 1273); **57th consecutive failure-free baseline** (130/130 suites; 1273/1273 cases; 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans)

**Deviations from spec** (4 advisory; none harmful; all documented; no tech-debt entries warranted):
1. **Test count +7 instead of +1** — agent split AC coverage into 7 granular tests instead of 1 composite. Better failure-isolation; aligned with story's QA Test Cases table (which already enumerated 7 distinct cases). Spec/implementation drift in story's `## Performance Budget` ("1267" target) — actual outcome cleaner.
2. **`prototypes/chapter-prototype/chapter.tscn` NOT edited** — story's `## Affected Systems` table listed it but the .tscn file is empty (13 lines: Control root + script attach only); all UI in chapter-prototype is programmatic per existing convention. Atmospheric ColorRect + AudioStreamPlayer added programmatically in `_ready()` via `_build_atmospheric_nodes()`. Implementation cleaner than story-spec assumed.
3. **`AudioStreamGenerator.push_buffer()` bool return not checked** — sample-drop indicator. Acceptable for prototype per `.claude/rules/prototype-code.md` relaxed standards; production-port should check + handle. Documented in Engine Risks section of /dev-story summary.
4. **`tests/integration/chapter_prototype/` directory created** — was implied by Test Evidence path but not explicitly listed in story's Affected Systems table. Required for the test file to land in conventional location.

**Test Evidence**: Integration story — `tests/integration/chapter_prototype/atmospheric_moment_test.gd` (445 LoC; 7 functions; covers AC-S12-02-1..6; G-3/G-6/G-15 gotcha-aware per docstring; headless-audio caveat documented)

**Code Review**: APPROVED (manual lean review per prototype-relaxed standards + AI #9 mitigation; no specialist spawn; verdict committed inline at conversation 2026-05-08)

**AI #9 codification ratchet** (sprint-12 retro candidate): godot-gdscript-specialist mid-execution stall pattern stable at **4 invocations** now (was 2 at sprint-12 entry; +2 this story — first-spawn + continuation-spawn during /dev-story). Final-report had hallucinated `src/chapter_prototype/atmospheric_moment.gd` path; `git status` verification revealed actual files correctly prototype-scoped. **Codification strengthened**: pre-authorize end-to-end execution (already in retro AI #9) + verify agent's final-report claims against `git status` before trusting narration. Recommend codification at sprint-12 retro.

**Cross-pillar effects** (mechanically observable for first time):
- **Pillar 4 (삼국지의 숨결)** atmospheric layer demonstrated in-prototype on REWRITTEN branch (reserved colors 주홍 + 금색 + synthesized 묵 hum + 1.5s ceremonial dwell)
- **Gate-check 2026-05-08 path-to-PASS item 3** ("≥1 player-facing Pillar 3/4 demonstration") — **CLOSED** by this story's ship
- **chapter-prototype-demo epic** graduates 1/1 — first **Demo-layer epic** in the project; establishes precedent for prototype-side `/quick-design` → `/create-stories` → `/dev-story` chain when design source is not architecturally an epic
- **REPORT.md Pillar 4 verdict upgraded**: "substrate present" → "substrate present + atmospheric demonstration shipped"
