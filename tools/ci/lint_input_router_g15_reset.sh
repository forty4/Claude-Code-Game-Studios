#!/usr/bin/env bash
# tools/ci/lint_input_router_g15_reset.sh
#
# Enforces TR-input-handling-013: every InputRouter test file's `before_test()`
# hook MUST reset all 17 InputRouter-mutable fields (6 architectural + 11
# transient/scratch added across stories 003-009) to clean defaults. Failure
# to reset causes test-isolation bleed via static-state leak (G-6 + G-15
# canonical pitfall).
#
# Scope: every file matching `tests/unit/foundation/input_router_*_test.gd`
# AND `tests/performance/foundation/input_router_perf_test.gd` (if present).
# For each, extract the `before_test()` body and verify each required field
# name appears at least once (assignment, .clear() call, or PackedInt32Array()
# reassignment).
#
# Exit 0: every test file resets every required field
# Exit 1: any test file missing any field reset (lists offenders)
#
# Usage:   bash tools/ci/lint_input_router_g15_reset.sh
# CI:      wired in story-010 (.github/workflows/tests.yml)
# ADR ref: docs/architecture/ADR-0005-input-handling.md §1 + TR-input-handling-013

set -euo pipefail

# 17 fields total: 6 architectural (ADR-0005 §1) + 11 transient/scratch
# Architectural (story-001):
#   _state, _active_mode, _pre_menu_state, _undo_windows, _input_blocked_reasons, _bindings
# Transient (story-004): _pending_end_phase
# Transient (story-007): _pre_block_state
# Transient (story-008): _last_tap_unit_id, _last_tap_time_ms, _camera, _map_grid
# Transient (story-009): _touch_start_pos, _touch_start_time_ms, _touch_travel_px, _active_touch_indices
# Test seam (story-003+): _grid_battle
REQUIRED_FIELDS=(
    "_state"
    "_active_mode"
    "_pre_menu_state"
    "_undo_windows"
    "_input_blocked_reasons"
    "_bindings"
    "_pending_end_phase"
    "_pre_block_state"
    "_last_tap_unit_id"
    "_last_tap_time_ms"
    "_camera"
    "_map_grid"
    "_touch_start_pos"
    "_touch_start_time_ms"
    "_touch_travel_px"
    "_active_touch_indices"
    "_grid_battle"
)

# Test files in scope. Globs may not expand if directory empty; use find.
TEST_FILES=()
while IFS= read -r f; do
    TEST_FILES+=("$f")
done < <(find tests/unit/foundation tests/performance/foundation -type f -name 'input_router_*_test.gd' 2>/dev/null || true)

if [ ${#TEST_FILES[@]} -eq 0 ]; then
    echo "::warning::No InputRouter test files found under tests/unit/foundation or tests/performance/foundation"
    echo "lint_input_router_g15_reset PASS (no test files to validate; warn-only)"
    exit 0
fi

FAILED=0
PASSED=0

for test_file in "${TEST_FILES[@]}"; do
    if [ ! -f "$test_file" ]; then
        continue
    fi

    # Extract before_test() body (until next `func ` line)
    BEFORE_TEST_BODY=$(awk '/^func before_test\(/{flag=1; next} /^func [^_]/{flag=0} flag' "$test_file")

    if [ -z "$BEFORE_TEST_BODY" ]; then
        echo "::error::$test_file missing before_test() hook entirely (G-15 violation)"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Shortcut: a call to InputRouter.reset_for_tests() is the canonical 5th-precedent
    # G-28 reset path and resets all 17 fields by construction. Test files that delegate
    # via the helper PASS the lint without per-field listing (story-010 close-out).
    if echo "$BEFORE_TEST_BODY" | grep -qE 'InputRouter\.reset_for_tests\(\)'; then
        PASSED=$((PASSED + 1))
        continue
    fi

    FILE_FAILED=0
    for field in "${REQUIRED_FIELDS[@]}"; do
        # Field must appear in before_test body (assignment OR .clear() OR reset call)
        if ! echo "$BEFORE_TEST_BODY" | grep -qE "${field}([[:space:]]|\.|=)"; then
            echo "::error::$test_file before_test() missing reset for field $field (TR-input-handling-013)"
            FILE_FAILED=$((FILE_FAILED + 1))
        fi
    done
    if [ "$FILE_FAILED" -gt 0 ]; then
        FAILED=$((FAILED + FILE_FAILED))
    else
        PASSED=$((PASSED + 1))
    fi
done

if [ "$FAILED" -gt 0 ]; then
    echo "lint_input_router_g15_reset FAIL — $FAILED missing field resets across ${#TEST_FILES[@]} test file(s)"
    exit 1
fi

echo "lint_input_router_g15_reset PASS — $PASSED/${#TEST_FILES[@]} test file(s); all 17 fields reset in every before_test()"
