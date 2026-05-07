# Story 008: Epic Terminal — 6 CI Lints + Verification Summary + 7 Engine Verification Items Closure

> **Epic**: Battle HUD
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Config/Data + Audit
> **Manifest Version**: 2026-05-05 (refreshed 2026-05-07 at sprint-10 plan-time per sprint-9 retro PI #3 — manifest delta 2026-04-20 → 2026-05-05 covered ADR-0014/0015 sections; no new forbidden_patterns affecting this story)

## Context

**GDD**: `design/ux/battle-hud.md` v1.1 §6 + `design/ux/accessibility-requirements.md` + `design/gdd/game-concept.md` Pillar 2 + `design/gdd/destiny-branch.md` Section B
**Requirement**: `TR-battle-hud-004` (Pillar 2 lint — CRITICAL), `TR-battle-hud-007` (non-emitter discipline lint), `TR-battle-hud-011` (44pt touch target lint), `TR-battle-hud-012` (i18n no-hardcoded-strings lint), `TR-battle-hud-013` (5 forbidden_patterns registry — already shipped via ADR-0015 commit; this story authors the lint scripts that enforce them)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015 Battle HUD §Engine Compatibility + §"Same-Patch Obligations from ADR-0015 Acceptance" items 3-4 (Accepted 2026-05-03)
**ADR Decision Summary**: 5 forbidden_patterns + 1 BalanceConstants key-presence lint = 6 total lint scripts at `tools/ci/lint_battle_hud_*.sh`. 6 lint steps wired into `.github/workflows/tests.yml`. Verification summary doc at `production/qa/evidence/battle_hud_verification_summary.md` rolls up all 7 Engine Compatibility verification items per `grid-battle-controller story-010` precedent. Epic-terminal: closes the epic when ALL 6 lints pass + ALL 7 verification items closed + 841/841 + ~30-40 = ~870-880 PASS regression baseline.

**Engine**: Godot 4.6 | **Risk**: LOW (lint scripts are bash + grep; no engine API surface)
**Engine Notes**:
- Lint pattern shape mirrors 4-precedent project discipline (camera 4-lints + grid-battle-controller 4-lints + balance-constants single-lint); see `tools/ci/lint_grid_battle_controller_*.sh` as the closest template.
- `tools/ci/lint_battle_hud_hidden_fate_non_subscription.sh` is THE CRITICAL lint — first project precedent of pillar-anchored CI gate. KEEP forever (not just MVP). Failure of this lint = build fail = Pillar 2 violation.

**Control Manifest Rules (Presentation layer)**:
- Required: every interactive Control on touch viewport ≥ 44×44pt (44pt lint enforces).
- Forbidden (registry — all 5 enforced by this story's lints):
  1. `battle_hud_signal_emission` (zero `GameBus.*.emit` calls)
  2. `battle_hud_subscribes_to_hidden_fate_signal` (Pillar 2 lock — CRITICAL)
  3. `battle_hud_missing_exit_tree_disconnect` (≥ 11 `disconnect` calls inside `_exit_tree`)
  4. `battle_hud_touch_target_below_44pt` (every interactive Control ≥ 44×44pt)
  5. `battle_hud_hardcoded_localized_strings` (every visible string via `tr()`)
- Guardrail: lint suite total wall-clock ≤ 5 s (mirrors grid-battle-controller 4-lint step timing); must not slow CI critical path.

---

## Acceptance Criteria

*From ADR-0015 §Same-Patch Obligations 3-4 + §Engine Compatibility table + battle-hud.md §6 + accessibility-requirements.md §4 + Pillar 2 + Engine Verification Items 1-7:*

- [ ] **Lint 1 — `tools/ci/lint_battle_hud_hidden_fate_non_subscription.sh`** (CRITICAL Pillar 2 lock):
  - Greps `src/feature/battle_hud/battle_hud.gd` (and any future split source files in `src/feature/battle_hud/`) for the literal token `hidden_fate_condition_progressed`
  - Returns exit 0 if zero matches; exit 1 if any match (build fail)
  - Comments are NOT exempt — even `# do not subscribe to hidden_fate_condition_progressed` triggers fail (forces architects to use a renamed reference if discussing the topic)
  - **KEEP forever — not just MVP. First pillar-anchored lint pattern in the project.**
- [ ] **Lint 2 — `tools/ci/lint_battle_hud_signal_emission_outside_ui_domain.sh`** (non-emitter discipline):
  - Greps `src/feature/battle_hud/battle_hud.gd` for `GameBus\..*\.emit` (the `\.emit` anchor distinguishes emit calls from `.connect / .disconnect / .is_connected` lines per camera + grid-battle-controller lint precedent)
  - Returns exit 0 if zero matches; exit 1 if any match
- [ ] **Lint 3 — `tools/ci/lint_battle_hud_missing_exit_tree_disconnect.sh`**:
  - Counts `disconnect` calls inside the `_exit_tree(` function body of `src/feature/battle_hud/battle_hud.gd` (multi-line awk parser; locate `_exit_tree(` start + matching `func ` end OR file end)
  - Returns exit 0 if count ≥ 11; exit 1 otherwise
  - Per TR-battle-hud-013 lint shape note: `grep -E '^func _exit_tree\\('` confirms presence; `grep -c 'GameBus\\..*\\.disconnect'` insufficient because controller-LOCAL disconnects are on `_grid_controller.<signal>.disconnect` not `GameBus.*.disconnect` — broaden lint pattern to count any `\\.disconnect(` inside the function body
- [ ] **Lint 4 — `tools/ci/lint_battle_hud_touch_target_size.sh`** (44pt accessibility):
  - Parses `scenes/battle/battle_hud.tscn` AND `scenes/battle/elements/ui_gb_*.tscn` files for Control nodes
  - For each Control with `mouse_filter` ≠ `MOUSE_FILTER_IGNORE` (i.e., interactive), asserts `custom_minimum_size.x ≥ 44 AND custom_minimum_size.y ≥ 44`
  - Exemption: read-only/decorative Controls (Label without focus_mode, ColorRect overlays per TR-battle-hud-011)
  - Returns exit 0 if all interactive Controls compliant; exit 1 otherwise
  - Per TR-battle-hud-011 first-dedicated-accessibility-lint precedent
- [ ] **Lint 5 — `tools/ci/lint_battle_hud_no_hardcoded_strings.sh`** (i18n via tr()):
  - Greps `src/feature/battle_hud/` for `text\s*=\s*"[^"]+"|set_text\("[^"]+"\)` patterns
  - Whitelist: empty string `""`, debug-only `push_error / push_warning`, format placeholders (`%d HP`, `%s` patterns)
  - Returns exit 0 if zero non-whitelisted matches; exit 1 otherwise
  - Per TR-battle-hud-012 first-dedicated-i18n-lint precedent
- [ ] **Lint 6 — `tools/ci/lint_battle_hud_connect_deferred.sh`** (CONNECT_DEFERRED discipline):
  - Greps `src/feature/battle_hud/battle_hud.gd` for `\.connect\(` calls
  - For each `.connect(` line, asserts `Object.CONNECT_DEFERRED` is on the same line (or within multi-line continuation)
  - Returns exit 0 if all 11 subscriptions compliant; exit 1 otherwise
  - Per Engine Verification Item 6 (KEEP forever)
- [ ] **Lint 7 (BalanceConstants key-presence) — `tools/ci/lint_balance_entities_battle_hud.sh`**:
  - Parses `assets/data/balance/balance_entities.json` for `FORECAST_RENDER_BUDGET_MS` key
  - Asserts presence + value type is integer + value within sanity range (50-300)
  - Returns exit 0 if compliant; exit 1 otherwise
- [ ] All 7 lints wired into `.github/workflows/tests.yml` as separate steps under the `battle-hud-lints` job (mirrors grid-battle-controller story-010 4-lint block); each step `name:` matches the lint script filename for failure-traceability.
- [ ] All 7 lints PASS on current `main` HEAD (verify by running each locally before commit).
- [ ] `production/qa/evidence/battle_hud_verification_summary.md` shipped — full 7-Engine-Verification-item rollup doc per grid-battle-controller story-010 precedent. Document covers:
  1. Dual-focus end-to-end (story-006 outcome + macOS Metal + Linux Vulkan logs)
  2. AccessKit screen reader (story-003 outcome + macOS VoiceOver log)
  3. 44pt touch target (this story Lint 4 — automated forever)
  4. Forecast 80ms dismiss latency (story-006 perf gate numbers)
  5. Recursive MOUSE_FILTER_IGNORE propagation (story-002 integration test outcome)
  6. CONNECT_DEFERRED discipline (this story Lint 6 — automated forever)
  7. **Pillar 2 hidden-fate non-subscription** (this story Lint 1 — CRITICAL, automated forever)
- [ ] Full GdUnit4 regression run reports ≥ 870-880 PASS / 0 errors / 0 failures / 0 orphans / Exit 0 (current 841 + ~30-40 from stories 001-007 tests).
- [ ] ADR-0015 status remains Accepted (post-impl no-op; no flip-back).
- [ ] `production/sprint-status.yaml` battle-hud epic stories all marked `done`; epic-level entry marked `done`.
- [ ] Update `docs/architecture/architecture-traceability.md` Coverage summary: Presentation layer 1/6 → 1/6 still (battle-hud was already counted as 1 of 6); refresh row status from "Ready" → "Complete".

---

## Implementation Notes

*Derived from ADR-0015 §Same-Patch Obligations 3-4 + grid-battle-controller story-010 4-lint precedent + camera 4-lint precedent:*

1. **Lint script template** — copy shape from `tools/ci/lint_grid_battle_controller_*.sh`. Each lint:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   ROOT="$(git rev-parse --show-toplevel)"
   SOURCE="$ROOT/src/feature/battle_hud/battle_hud.gd"
   if [[ ! -f "$SOURCE" ]]; then
       echo "ERROR: $SOURCE not found"
       exit 2
   fi
   # ... lint-specific grep/awk logic
   ```

2. **Lint 1 (Pillar 2) script body**:
   ```bash
   if grep -q 'hidden_fate_condition_progressed' "$SOURCE"; then
       echo "FAIL: BattleHUD source must NOT reference hidden_fate_condition_progressed (Pillar 2 lock)"
       echo "Reason: design/gdd/game-concept.md Pillar 2 + design/gdd/destiny-branch.md Section B"
       exit 1
   fi
   echo "PASS: zero hidden_fate_condition_progressed token occurrences"
   ```

3. **Lint 3 (_exit_tree disconnect count) — multi-line awk parser**:
   ```bash
   COUNT=$(awk '
     /^func _exit_tree\(/ { in_fn=1; next }
     in_fn && /^func / { in_fn=0 }
     in_fn && /\.disconnect\(/ { count++ }
     END { print count+0 }
   ' "$SOURCE")
   if [[ "$COUNT" -lt 11 ]]; then
       echo "FAIL: _exit_tree() body has $COUNT disconnect calls; expected ≥ 11"
       exit 1
   fi
   ```

4. **Lint 4 (44pt) — .tscn parser** — Godot .tscn format parses as INI-like sections. Use `awk` or `python` (project may already have a python parser util — check `tools/ci/` first). Approximate awk:
   ```bash
   for tscn in scenes/battle/battle_hud.tscn scenes/battle/elements/ui_gb_*.tscn; do
       # parse [node] sections; check Control type + mouse_filter + custom_minimum_size
       # if mouse_filter != 2 (IGNORE) AND (custom_minimum_size.x < 44 OR y < 44): FAIL
       :
   done
   ```
   Implementation choice: pure-bash awk parser OR python script if heavier. Document in script header.

5. **Lint 5 (i18n) script body** — `grep -E 'text\s*=\s*"[^"]+"|set_text\("[^"]+"\)' src/feature/battle_hud/ -r` then filter out whitelist via `grep -v -E '^.*: ?(""|push_error|push_warning|"%[ds]")$'`. Real production patterns may need additional whitelist entries — document in script.

6. **`.github/workflows/tests.yml` wiring** — add a new job or extend existing lint job:
   ```yaml
   battle-hud-lints:
     runs-on: ubuntu-latest
     steps:
       - uses: actions/checkout@v4
       - name: lint_battle_hud_hidden_fate_non_subscription
         run: tools/ci/lint_battle_hud_hidden_fate_non_subscription.sh
       - name: lint_battle_hud_signal_emission_outside_ui_domain
         run: tools/ci/lint_battle_hud_signal_emission_outside_ui_domain.sh
       # ... 5 more steps
   ```

7. **Verification summary doc structure** — mirror `production/qa/evidence/grid_battle_controller_verification_summary.md` (verify exists; if not, mirror the closest precedent — likely camera or hp-status). 7-section doc, one section per Engine Verification item, each with: source story, evidence link, outcome (PASS / DEFERRED / etc.), KEEP-through milestone.

8. **Test baseline math**:
   - Pre-impl: 841/841 (sprint-5 close 19th failure-free baseline)
   - Stories 001-007 add: ~30-40 unit + integration tests (story-001 AC-1..7 = 7; story-002 = 6; story-003 integ = 7; story-004 integ = 6; story-005 integ = 7; story-006 unit + integ = 9; story-007 integ = 8 → ~50 test cases; some parameterised, total ≈ 30-40 unique test functions)
   - Story-008 adds: 0 GD tests (lints are bash); but the lint scripts themselves should have a smoke test in `tests/unit/tools_ci/lint_battle_hud_smoke_test.gd` that invokes each script and asserts exit 0 OR documents expected exit code per failure scenario
   - Target post-impl: ≥ 870-880 PASS

---

## Out of Scope

*Handled elsewhere — do not implement here:*

- Future ADR amendment if zoom-poll budget breached (story-007 raises if needed; story-008 only enforces what currently exists).
- Android TalkBack verification (post-MVP per design/ux/accessibility-requirements.md §4).
- Locale_kr / locale_jp translations of i18n keys (localization-lead follow-up; English fallback ships with this story).

---

## QA Test Cases

*Config/Data + Audit story — automated lint outcomes + manual rollup verification.*

- **AC-1: Lint 1 (Pillar 2) PASS on current main HEAD**
  - Setup: run `tools/ci/lint_battle_hud_hidden_fate_non_subscription.sh` from project root
  - Verify: exit code 0; output contains "PASS"
  - Pass condition: zero `hidden_fate_condition_progressed` token in `src/feature/battle_hud/`
  - Negative test: temporarily insert `# hidden_fate_condition_progressed` comment into source; re-run lint; assert exit 1; revert (negative test documented in `tests/unit/tools_ci/lint_battle_hud_smoke_test.gd`)

- **AC-2: Lint 2 (non-emitter) PASS**
  - Setup: run `tools/ci/lint_battle_hud_signal_emission_outside_ui_domain.sh`
  - Verify: exit code 0
  - Negative test: insert `GameBus.test_signal.emit()` line; re-run; assert exit 1; revert

- **AC-3: Lint 3 (_exit_tree disconnect ≥ 11) PASS**
  - Setup: run lint
  - Verify: exit code 0; count reported = 11
  - Negative test: comment out one `disconnect()` call inside `_exit_tree()`; re-run; assert exit 1; revert

- **AC-4: Lint 4 (44pt touch targets) PASS**
  - Setup: run lint over all UI-GB-* element scenes
  - Verify: exit code 0; report lists 0 violating Controls
  - Negative test: edit `ui_gb_02_action_menu.tscn` to set MOVE button `custom_minimum_size = Vector2(40, 40)`; re-run; assert exit 1; revert

- **AC-5: Lint 5 (i18n) PASS**
  - Setup: run lint
  - Verify: exit code 0
  - Negative test: insert `_label.text = "Hardcoded English"` line; re-run; assert exit 1; revert

- **AC-6: Lint 6 (CONNECT_DEFERRED) PASS**
  - Setup: run lint
  - Verify: exit code 0; report lists 11 compliant connect calls
  - Negative test: edit one `.connect(...)` to remove `Object.CONNECT_DEFERRED` flag; re-run; assert exit 1; revert

- **AC-7: Lint 7 (BalanceConstants key) PASS**
  - Setup: run lint
  - Verify: exit code 0; FORECAST_RENDER_BUDGET_MS = 120 confirmed
  - Negative test: temporarily delete the key from balance_entities.json; re-run; assert exit 1; revert

- **AC-8: All 7 lints wired into `.github/workflows/tests.yml`**
  - Setup: read `.github/workflows/tests.yml`
  - Verify: 7 step entries exist with `run: tools/ci/lint_battle_hud_*.sh` paths
  - Pass condition: CI run on PR shows 7 PASS step results

- **AC-9: Verification summary doc covers all 7 items**
  - Setup: read `production/qa/evidence/battle_hud_verification_summary.md`
  - Verify: 7 sections present, each with source story link + evidence link + outcome (PASS / DEFERRED) + KEEP-through milestone
  - Pass condition: doc structurally matches grid-battle-controller verification summary precedent

- **AC-10: Full regression baseline ≥ 870-880 PASS / 0 errors / 0 failures / 0 orphans**
  - Setup: run `godot --headless --script tests/gdunit4_runner.gd` from project root
  - Verify: GdUnit4 report shows total ≥ 870; failures + errors + orphans = 0; Exit 0
  - Pass condition: 20th-or-better consecutive failure-free baseline preserved

- **AC-11: Sprint-status.yaml battle-hud epic marked done**
  - Setup: read `production/sprint-status.yaml`
  - Verify: each S6-XX battle-hud story status: done; epic-level battle-hud entry status: done; updated: today's date stamped
  - Pass condition: assertions pass

---

## Test Evidence

**Story Type**: Config/Data + Audit
**Required evidence**:
- Smoke test: `tests/unit/tools_ci/lint_battle_hud_smoke_test.gd` covers AC-1 through AC-7 negative tests
- Manual: `production/qa/evidence/battle_hud_verification_summary.md` — full 7-item rollup doc (THE epic-terminal artifact)
- Smoke check: `production/qa/smoke-2026-XX-XX.md` documents the regression run pass for AC-10

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001-007 (all 6 lints + verification summary need source code shipped + tests passing first)
- Unlocks: **Battle HUD epic Complete** — closes 7 Engine Verification items + clears all 5 forbidden_pattern lints; sprint-6 advances; downstream `/qa-plan battle-hud` (S6-08) consumes this story's verification summary
