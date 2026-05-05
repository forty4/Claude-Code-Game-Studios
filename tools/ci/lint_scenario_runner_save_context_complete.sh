#!/usr/bin/env bash
# tools/ci/lint_scenario_runner_save_context_complete.sh
#
# scenario_runner_save_context_partial_emit forbidden_pattern enforcement
# (TR-scenario-progression-011 + ADR-0017 §Decision §Risks R-4 + AC-SP-21).
#
# All SaveContext.new() calls in scenario_runner.gd MUST be inside the
# _make_save_context() helper body. This guarantees every emitted SaveContext
# has all required fields populated (chapter_id, outcome, branch_key,
# echo_count, echo_marks_archive, flags_to_set, etc.).
#
# Exit 0: PASS (single-helper construction preserved)
# Exit 1: FAIL (SaveContext.new() found outside helper)
set -euo pipefail
TARGET="src/core/scenario_runner.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi

# Use awk to track function-scope: violations are SaveContext.new() that appear
# OUTSIDE the _make_save_context() function body.
violations=$(awk '
    /^func _make_save_context/ {in_h=1; next}
    /^func / && in_h {in_h=0}
    /SaveContext\.new[[:space:]]*\(/ && !in_h && !/^[[:space:]]*#/ {print NR": "$0}
' "$TARGET" || true)

if [ -n "$violations" ]; then
    echo "FAIL: $TARGET contains SaveContext.new() outside _make_save_context() helper:"
    echo "$violations"
    echo "  (TR-scenario-progression-011: all SaveContext construction goes through the helper)"
    exit 1
fi

echo "PASS: $TARGET SaveContext.new() only appears inside _make_save_context()"
exit 0
