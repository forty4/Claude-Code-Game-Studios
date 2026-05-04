# Story 003: 3 Lint Scripts + CI Wiring + 3 Forbidden_Patterns + Epic Terminal

> **Epic**: Battle Scene
> **Status**: Ready
> **Layer**: Feature (scene-root)
> **Type**: Config/Data
> **Manifest Version**: 2026-04-20
> **Sprint**: sprint-6 (post-S6-07 + story-002; capacity permitting) OR sprint-7

## Context

**GDD**: None — architecture-only epic
**Requirement**: `TR-battle-scene-wiring-010`, `TR-battle-scene-wiring-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0016 Battle Scene Wiring (Accepted 2026-05-03)
**ADR Decision Summary**: 3 lint scripts enforce ADR-0016's invariants at CI: (1) `lint_battle_scene_pre_instanced_children.sh` asserts `.tscn` contains EXACTLY 3 nodes (BattleScene + GridLayer + HUDLayer); (2) `lint_battle_scene_no_gamebus_subscriptions.sh` asserts `battle_scene.gd` has zero `GameBus.*.connect` / `GameBus.*.emit` calls (non-emitter + non-subscriber discipline per R-7); (3) `lint_battle_scene_sprint6_mock_marker.sh` asserts the sprint-6 mock encoder markers exist in source (semantic flips at ADR-0017 acceptance to "MUST NOT exist"). All 3 wired into `.github/workflows/tests.yml` after the 5 battle-hud lint group. 3 forbidden_patterns registered in `docs/registry/architecture.yaml` (already done same-patch with ADR-0016 acceptance via `/architecture-review` delta #11; this story confirms registry presence + adds CI lint scripts as enforcement).

**Engine**: Godot 4.6 | **Risk**: LOW (lint scripts are bash + grep; no Godot APIs)
**Engine Notes**:
- Godot's `.tscn` text format is grep-friendly: `[node name="..." type="..."]` lines are the node-count signal; `parent="..."` attributes establish hierarchy. Lint can use `grep -c '^\[node name=' file.tscn` for node count assertion.
- Bash lint scripts must be executable (`chmod +x`) and use `#!/usr/bin/env bash` shebang for cross-platform CI.
- Same precedent as battle-hud's 5 lints (story-008 pending) + grid-battle-controller's 4 lints (story-010 ✅ shipped) + camera's 4 lints (story-007 ✅ shipped); follow the same script template.

**Control Manifest Rules (Feature layer + scene-root)**:
- Required: every forbidden_pattern in registry MUST have a corresponding CI lint script (per `tools/ci/lint_*.sh` convention). 3 lints map 1:1 to 3 forbidden_patterns.
- Forbidden (registry, registered same-patch with ADR-0016 acceptance via delta #11): `battle_scene_pre_instanced_children`, `battle_scene_root_signal_subscription`, `battle_scene_sprint6_mock_marker_must_exist`.
- Guardrail: each lint script runs <100ms wall-clock (matches grid-battle-controller + camera precedent); 3 scripts total <300ms additional CI cost; cumulative CI lint pipeline budget remains <5s.

---

## Acceptance Criteria

*From ADR-0016 §Implementation Guidelines + R-10 + R-11 + Migration Plan §1, scoped to lints + CI wiring + epic close:*

- [ ] **AC-1**: `tools/ci/lint_battle_scene_pre_instanced_children.sh` exists, executable (`chmod +x`), uses `#!/usr/bin/env bash`. Asserts `scenes/battle/battle_scene.tscn` contains EXACTLY 3 nodes (BattleScene + GridLayer + HUDLayer). Exits 0 on pass, non-zero with diagnostic message on fail. (TR-002 + TR-010 + TR-011)
- [ ] **AC-2**: `tools/ci/lint_battle_scene_no_gamebus_subscriptions.sh` exists, executable, asserts `src/feature/battle_scene/battle_scene.gd` has zero `GameBus.*\.connect` AND zero `GameBus.*\.emit` substring matches. Exits 0 on pass, non-zero with diagnostic + match count + file:line citations on fail. (TR-007 + TR-010 + TR-011)
- [ ] **AC-3**: `tools/ci/lint_battle_scene_sprint6_mock_marker.sh` exists, executable, asserts `src/feature/battle_scene/battle_scene.gd` contains all 4 marker substrings: `# === SPRINT-6 MOCK ENCOUNTER ===`, `# === END MOCK ===`, `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===`, `# === END SPRINT-6 MOCK ENCOUNTER HELPERS ===`. Exits 0 on pass, non-zero on fail. Includes inline comment noting the semantic flip at ADR-0017 acceptance ("MUST exist" → "MUST NOT exist"). (TR-004 + TR-010 + TR-011)
- [ ] **AC-4**: `.github/workflows/tests.yml` invokes all 3 lint scripts in a dedicated step (or steps) AFTER the 5 battle-hud lint group + before / alongside the existing CI lint pipeline (camera + grid-battle-controller + hp-status). Step naming follows existing precedent (e.g., `Battle Scene lints — pre-instanced children`). (TR-011)
- [ ] **AC-5**: 3 forbidden_patterns are confirmed present in `docs/registry/architecture.yaml`: `battle_scene_pre_instanced_children`, `battle_scene_root_signal_subscription`, `battle_scene_sprint6_mock_marker_must_exist`. (Note: these were registered same-patch with ADR-0016 acceptance via `/architecture-review` delta #11 — this AC verifies registry presence; if missing, add same-patch.) (TR-010)
- [ ] **AC-6**: All 3 lint scripts pass against the post-story-001 + post-story-002 source state (i.e., the actual production `battle_scene.gd` + `battle_scene.tscn` shipped). PASS demonstrated by running each script locally + capturing the pass output in epic close evidence. (TR-011)
- [ ] **AC-7**: `production/epics/battle-scene/EPIC.md` Stories table updated: story-001/002/003 status reflected; epic Status field flips from `Ready` → `In Progress` (during story-001) → `Complete` at this story's `/story-done` close.
- [ ] **AC-8**: Verification summary doc at `production/qa/evidence/battle_scene_verification_summary.md` aggregates: (a) story-002 smoke evidence doc reference; (b) lint pass output (all 3 PASS); (c) 11/11 TR coverage matrix; (d) regression baseline preserved (876+ PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0). Same precedent as `grid_battle_controller_verification_summary.md`. (TR-011 epic-terminal)
- [ ] **AC-9**: Existing test runner regression baseline preserved post-CI-wiring (876+ PASS preserved + new lint steps add to PASS column; 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0).

---

## Implementation Notes

*Derived from ADR-0016 Implementation Guidelines + R-10 + Migration Plan §1; reuses lint script template from camera/grid-battle-controller/battle-hud precedents:*

1. **Lint script template** (per `tools/ci/lint_*.sh` precedent shipped by camera epic story-007 + grid-battle-controller epic story-010):
   ```bash
   #!/usr/bin/env bash
   # tools/ci/lint_battle_scene_pre_instanced_children.sh
   # Enforces forbidden_pattern: battle_scene_pre_instanced_children
   # ADR-0016 §2 + TR-battle-scene-wiring-002 + R-2

   set -euo pipefail
   SCENE_FILE="scenes/battle/battle_scene.tscn"

   if [[ ! -f "$SCENE_FILE" ]]; then
     echo "FAIL: $SCENE_FILE not found"
     exit 1
   fi

   NODE_COUNT=$(grep -c '^\[node name=' "$SCENE_FILE" || true)

   if [[ "$NODE_COUNT" -ne 3 ]]; then
     echo "FAIL: $SCENE_FILE has $NODE_COUNT nodes; expected EXACTLY 3 (BattleScene + GridLayer + HUDLayer)"
     grep '^\[node name=' "$SCENE_FILE" | head -10
     exit 1
   fi

   echo "PASS: $SCENE_FILE has exactly 3 nodes"
   exit 0
   ```

2. **Lint #2 (no GameBus subscriptions)**:
   ```bash
   #!/usr/bin/env bash
   # tools/ci/lint_battle_scene_no_gamebus_subscriptions.sh
   # Enforces forbidden_pattern: battle_scene_root_signal_subscription
   # ADR-0016 R-7 + TR-battle-scene-wiring-007

   set -euo pipefail
   SOURCE_FILE="src/feature/battle_scene/battle_scene.gd"

   if [[ ! -f "$SOURCE_FILE" ]]; then
     echo "FAIL: $SOURCE_FILE not found"
     exit 1
   fi

   # Match GameBus.<anything>.connect or GameBus.<anything>.emit
   MATCHES=$(grep -E -n 'GameBus\.[A-Za-z_]+\.(connect|emit)' "$SOURCE_FILE" || true)

   if [[ -n "$MATCHES" ]]; then
     echo "FAIL: $SOURCE_FILE has forbidden GameBus subscription/emission:"
     echo "$MATCHES"
     exit 1
   fi

   echo "PASS: $SOURCE_FILE has zero GameBus.*.connect/emit"
   exit 0
   ```

3. **Lint #3 (sprint-6 mock marker presence)**:
   ```bash
   #!/usr/bin/env bash
   # tools/ci/lint_battle_scene_sprint6_mock_marker.sh
   # Enforces forbidden_pattern: battle_scene_sprint6_mock_marker_must_exist
   # ADR-0016 §4 + TR-battle-scene-wiring-004 + TR-battle-scene-wiring-010
   # SEMANTIC FLIPS AT ADR-0017 ACCEPTANCE: "MUST exist" → "MUST NOT exist"

   set -euo pipefail
   SOURCE_FILE="src/feature/battle_scene/battle_scene.gd"

   if [[ ! -f "$SOURCE_FILE" ]]; then
     echo "FAIL: $SOURCE_FILE not found"
     exit 1
   fi

   declare -a REQUIRED_MARKERS=(
     "# === SPRINT-6 MOCK ENCOUNTER ==="
     "# === END MOCK ==="
     "# === SPRINT-6 MOCK ENCOUNTER HELPERS ==="
     "# === END SPRINT-6 MOCK ENCOUNTER HELPERS ==="
   )

   FAILED=0
   for marker in "${REQUIRED_MARKERS[@]}"; do
     if ! grep -F -q "$marker" "$SOURCE_FILE"; then
       echo "FAIL: $SOURCE_FILE missing marker: $marker"
       FAILED=1
     fi
   done

   if [[ $FAILED -ne 0 ]]; then
     exit 1
   fi

   echo "PASS: $SOURCE_FILE contains all 4 SPRINT-6 mock markers (will flip semantic at ADR-0017 acceptance)"
   exit 0
   ```

4. **CI workflow wiring** in `.github/workflows/tests.yml`:
   ```yaml
   - name: Battle Scene lints — pre-instanced children
     run: tools/ci/lint_battle_scene_pre_instanced_children.sh

   - name: Battle Scene lints — no GameBus subscriptions
     run: tools/ci/lint_battle_scene_no_gamebus_subscriptions.sh

   - name: Battle Scene lints — sprint-6 mock marker presence
     run: tools/ci/lint_battle_scene_sprint6_mock_marker.sh
   ```
   Place AFTER the 5 battle-hud lint group (when story-008 ships) OR alongside existing camera + grid-battle-controller lint steps. Naming follows existing convention.

5. **Registry verification**: read `docs/registry/architecture.yaml` post-delta-#11 to confirm 3 forbidden_patterns are present. If any are missing (delta-#11 was supposed to register them same-patch), add via:
   ```yaml
   forbidden_patterns:
     - id: battle_scene_pre_instanced_children
       adr: ADR-0016
       lint: tools/ci/lint_battle_scene_pre_instanced_children.sh
     - id: battle_scene_root_signal_subscription
       adr: ADR-0016
       lint: tools/ci/lint_battle_scene_no_gamebus_subscriptions.sh
     - id: battle_scene_sprint6_mock_marker_must_exist
       adr: ADR-0016
       lint: tools/ci/lint_battle_scene_sprint6_mock_marker.sh
       sprint6_lifecycle: "Lint asserts marker presence; flips to 'must not exist' at ADR-0017 acceptance per Migration Plan §1"
   ```

6. **Verification summary doc shape** (~80-150 lines markdown — same precedent as `grid_battle_controller_verification_summary.md`):
   ```markdown
   # Battle Scene Epic — Verification Summary

   > **Epic**: production/epics/battle-scene/EPIC.md
   > **Closed**: 2026-05-XX (sprint-6 SX-XX)
   > **ADR**: docs/architecture/ADR-0016-battle-scene-wiring.md (Accepted 2026-05-03)

   ## §A. Stories shipped

   | # | Story | Type | Status | Test Evidence |
   |---|-------|------|--------|---------------|
   | 001 | Class skeleton + `.tscn` + 6-step mount + mock encoder | Integration | Complete | tests/integration/feature/battle_scene/battle_scene_smoke_test.gd |
   | 002 | main_scene flip + cross-launch-source smoke evidence | Integration | Complete | production/qa/evidence/battle_scene_smoke_2026-05-XX.md |
   | 003 | 3 lints + CI wiring + 3 forbidden_patterns + epic terminal | Config/Data | Complete | (this doc) |

   ## §B. TR coverage matrix (11/11)

   | TR-ID | Requirement (summary) | Story | Status |
   |-------|----------------------|-------|--------|
   | TR-001 | NEW pattern: scene-root-as-orchestrator | 001 | ✅ |
   | TR-002 | 3-node `.tscn` skeleton | 001 + 003 (lint) | ✅ |
   | TR-003 | 6-step `_ready()` mount | 001 | ✅ |
   | TR-004 | Sprint-6 mock encoder | 001 + 003 (lint) | ✅ |
   | TR-005 | project.godot main_scene flip | 002 | ✅ |
   | TR-006 | NO _exit_tree() body (auto-tree-free) | 001 | ✅ |
   | TR-007 | Non-emitter + non-subscriber | 001 + 003 (lint) | ✅ |
   | TR-008 | 3-launch-source idempotency | 002 | ✅ (b/c PASS; a DEFERRED) |
   | TR-009 | <50ms _ready() wall-clock | 001 | ✅ |
   | TR-010 | 3 forbidden_patterns | 003 | ✅ |
   | TR-011 | 3 lint scripts + CI + smoke evidence | 003 | ✅ |

   ## §C. Lint pass output

   (Capture stdout from running each of 3 lints locally pre-close.)

   ## §D. Regression baseline

   - 876+ PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0 — preserved at epic close.

   ## §E. Migration Plan revert (sprint-7+ when ADR-0017 lands)

   - Mock encoder deletion sites: `src/feature/battle_scene/battle_scene.gd` lines [N..M] (between MOCK markers in `_ready()`) + `_build_mock_*` helper block.
   - `project.godot` main_scene revert to title screen / overworld entry per ADR-0017.
   - Lint `lint_battle_scene_sprint6_mock_marker.sh` semantic flip from "MUST exist" to "MUST NOT exist" (single-character grep flag flip + comment rewrite).
   - Smoke evidence doc re-author for new launch path.
   ```

7. **Epic Status flip in EPIC.md**: at this story's `/story-done`, update Stories table + Status field. Stories table format (per battle-hud / grid-battle-controller precedent):
   ```markdown
   ## Stories

   | # | Story | Type | Status | TR-IDs | Estimate |
   |---|-------|------|--------|--------|----------|
   | 001 | Class skeleton + .tscn + 6-step mount + mock encoder | Integration | Complete | TR-001/002/003/004/006/007/009 | 3h |
   | 002 | main_scene flip + cross-launch-source smoke evidence | Integration | Complete | TR-005/008 | 1.5h |
   | 003 | 3 lints + CI + forbidden_patterns + epic terminal | Config/Data | Complete | TR-010/011 | 1.5h |
   ```

8. **No new code in BattleScene source this story** — purely tooling + CI + docs. If a lint catches an unintended source pattern in `battle_scene.gd` during local run (regression introduced between story-001 close and story-003 author time), the fix belongs to the originating story as an amendment, NOT inline here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: BattleScene class skeleton + `.tscn` + 6-step mount + mock encoder (must be Complete before this story can author lints against the production source).
- **Story 002**: `project.godot` main_scene flip + cross-launch-source smoke evidence (must be Complete; story-002's evidence doc is referenced from story-003 verification summary §A).
- **Cross-platform CI lanes** (macOS Metal + Linux Vulkan + Windows D3D12) — V-8/V-9 verification on real hardware deferred to Polish per ADR-0016 V-11; CI lint scripts run on test-runner platform only.
- **Lint flip at ADR-0017 acceptance** (semantic "MUST exist" → "MUST NOT exist") — owned by ADR-0017 acceptance patch, NOT this story; documented in §E of verification summary doc.
- **Mock encoder deletion** — owned by ADR-0017 acceptance patch.

---

## QA Test Cases

*Config/Data story — smoke check pass + manual verification of CI wiring.*

- **AC-1: Lint #1 — pre-instanced children**
  - Setup: `tools/ci/lint_battle_scene_pre_instanced_children.sh` exists + `chmod +x`
  - Verify: bash `tools/ci/lint_battle_scene_pre_instanced_children.sh` returns 0 on the shipped `.tscn` (3 nodes); manually inject a 4th node in a tmp copy and verify lint returns non-zero
  - Pass condition: PASS on shipped state; FAIL on injected violation

- **AC-2: Lint #2 — no GameBus subscriptions**
  - Setup: `tools/ci/lint_battle_scene_no_gamebus_subscriptions.sh` exists + `chmod +x`
  - Verify: bash `tools/ci/lint_battle_scene_no_gamebus_subscriptions.sh` returns 0 on the shipped `battle_scene.gd`; manually inject a `GameBus.unit_died.connect(...)` line in a tmp copy and verify lint returns non-zero with the matching line cited
  - Pass condition: PASS on shipped state; FAIL on injected violation

- **AC-3: Lint #3 — sprint-6 mock marker presence**
  - Setup: `tools/ci/lint_battle_scene_sprint6_mock_marker.sh` exists + `chmod +x`
  - Verify: bash `tools/ci/lint_battle_scene_sprint6_mock_marker.sh` returns 0 on the shipped `battle_scene.gd`; manually delete one of the 4 markers in a tmp copy and verify lint returns non-zero with the missing marker cited
  - Pass condition: PASS on shipped state; FAIL on each of the 4 marker deletions

- **AC-4: CI workflow wiring**
  - Setup: open `.github/workflows/tests.yml`
  - Verify: 3 step entries present invoking the 3 lint scripts; step names follow existing convention; placement is post-existing-lint-group; YAML parses cleanly (`yamllint` or equivalent)
  - Pass condition: 3 steps present + YAML parses + CI dry-run succeeds (or push + observe Actions log)

- **AC-5: 3 forbidden_patterns in registry**
  - Setup: `grep -E '^\s+- id: battle_scene_(pre_instanced_children|root_signal_subscription|sprint6_mock_marker_must_exist)' docs/registry/architecture.yaml`
  - Verify: 3 matches returned (one per forbidden_pattern)
  - Pass condition: exactly 3 matches; if any missing, add same-patch + reverify

- **AC-6: All 3 lints pass on shipped source**
  - Given: shipped post-story-001 + post-story-002 source
  - When: each lint script runs locally (`bash tools/ci/lint_battle_scene_*.sh`)
  - Then: all 3 exit 0
  - Edge cases: any lint failing post-ship → fix belongs to originating story (story-001 for source defects; story-002 for `.tscn` defects)

- **AC-7: EPIC.md Stories table + Status field updated**
  - Setup: open `production/epics/battle-scene/EPIC.md`
  - Verify: Stories table rows for 001/002/003 with Status = Complete; epic Status field = Complete (or In Progress mid-flow); Last Updated date refreshed
  - Pass condition: 3 story rows present + epic Status reflects close

- **AC-8: Verification summary doc**
  - Setup: open `production/qa/evidence/battle_scene_verification_summary.md`
  - Verify: §A stories table (3 rows); §B 11-row TR coverage matrix (all ✅ except TR-008 which may be ✅ with DEFERRED-noted for launch source (a)); §C 3 lint PASS captures; §D regression baseline; §E migration plan revert
  - Pass condition: 5 sections present; matrix complete; regression baseline preserved

- **AC-9: Regression baseline preserved**
  - Given: post-story-003 working tree
  - When: full test suite runs via project's CI invocation (`godot --headless --script tests/gdunit4_runner.gd` or equivalent) AND 3 new lint scripts run
  - Then: 876+ PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0; new CI lint steps PASS
  - Edge cases: lint scripts themselves should not be COUNTED in PASS total (they're CI steps, not tests)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- Smoke check pass: lint scripts run locally + captured in `production/qa/evidence/battle_scene_verification_summary.md` §C
- Verification summary: `production/qa/evidence/battle_scene_verification_summary.md` (covers AC-5 through AC-8)
- Regression: full test suite PASS preserved (AC-9)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (BattleScene source must exist for lints #2 + #3 to target; `.tscn` must exist for lint #1) AND Story 002 (project.godot flip already in place; smoke evidence doc available for §A reference). Without both, this story's verification step has nothing to assert against.
- **Unlocks**: Epic close + S6-07 complete + sprint-6 +1 playable-surface delta target hit + ADR-0017 Scenario Progression unblocked (sprint-7+ work begins on a stable BattleScene foundation).

---

## Completion Notes

*To be authored at /story-done.*
