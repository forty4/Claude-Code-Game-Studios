#!/usr/bin/env bash
# tools/ci/lint_scenario_runner_outcome_synthesis.sh
#
# scenario_runner_outcome_synthesis forbidden_pattern enforcement
# (TR-scenario-progression-014 + ADR-0017 §CR-3 invariant: ScenarioRunner
#  consumes BattleOutcome.result; never assigns or overrides it).
#
# Greps src/core/scenario_runner.gd for any pattern that assigns to
# BattleOutcome.result OR _last_battle_outcome.result.
#
# Exit 0: PASS (CR-3 single-emitter ownership preserved)
# Exit 1: FAIL (outcome assignment detected)
set -euo pipefail
TARGET="src/core/scenario_runner.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi

# Forbidden patterns (regex):
#   _last_battle_outcome.result =
#   BattleOutcome.result =          (would only appear in unusual access patterns)
#   .result = BattleOutcome.Result. (cross-instance write)
PATTERNS=(
    '_last_battle_outcome\.result[[:space:]]*='
    '\.result[[:space:]]*=[[:space:]]*BattleOutcome\.Result\.'
)

FAILED=0
for pattern in "${PATTERNS[@]}"; do
    matches=$(grep -En "$pattern" "$TARGET" | grep -v '^\s*#' || true)
    if [ -n "$matches" ]; then
        echo "FAIL: $TARGET matches outcome-synthesis pattern '$pattern':"
        echo "$matches"
        FAILED=1
    fi
done

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi

echo "PASS: $TARGET preserves CR-3 single-emitter outcome ownership (no synthesis)"
exit 0
