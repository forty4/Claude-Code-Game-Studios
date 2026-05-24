#!/usr/bin/env bash
# tools/ci/lint_civilian_token_no_static_var.sh
#
# civilian_token_static_var forbidden_pattern enforcement
# (ADR-0022 §4 #2 + §Verification Required #5).
#
# Battle-scoped lifetime discipline — multiple battles MUST produce independent
# token populations. Static state would leak between battles, corrupting fate
# counter accuracy and ★ trigger semantics on repeat runs.
#
# Two scopes enforced:
#   (a) src/feature/grid_battle/civilian_token.gd        — NO `static var` at all
#   (b) src/feature/grid_battle/grid_battle_controller.gd — NO `static var _civilian_*`
#       (civilian-related fields must be instance state on GridBattleController)
#
# Mirrors `grid_battle_controller_static_state` + `ai_system_static_var` pattern
# family (5+ battle-scoped subsystems now enforced this way).
#
# Exit 0: PASS. Exit 1: FAIL.
set -euo pipefail

CIVILIAN_TOKEN="src/feature/grid_battle/civilian_token.gd"
GBC="src/feature/grid_battle/grid_battle_controller.gd"

if [ ! -f "$CIVILIAN_TOKEN" ]; then
    echo "FAIL: target file missing: $CIVILIAN_TOKEN"
    exit 1
fi
if [ ! -f "$GBC" ]; then
    echo "FAIL: target file missing: $GBC"
    exit 1
fi

FAIL=0

# Scope (a): civilian_token.gd — ANY static var is forbidden.
if matches=$(grep -En '^[[:space:]]*static[[:space:]]+var' "$CIVILIAN_TOKEN" || true); then
    if [ -n "$matches" ]; then
        echo "FAIL: $CIVILIAN_TOKEN declares static var — ADR-0022 §4 #2 violated:"
        echo "$matches"
        echo "CivilianToken is RefCounted + battle-scoped; instance state only."
        FAIL=1
    fi
fi

# Scope (b): grid_battle_controller.gd — civilian-related static var is forbidden.
# Match `static var _civilian_*` or `static var _fate_civilians_*` (both belong
# to the civilian system substrate and must be battle-scoped instance state).
if matches=$(grep -En '^[[:space:]]*static[[:space:]]+var[[:space:]]+(_civilian_|_fate_civilians_)' "$GBC" || true); then
    if [ -n "$matches" ]; then
        echo "FAIL: $GBC declares civilian-related static var — ADR-0022 §4 #2 violated:"
        echo "$matches"
        echo "Civilian fields on GridBattleController must be instance state (battle-scoped)."
        FAIL=1
    fi
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi

echo "PASS: civilian_token.gd + grid_battle_controller.gd civilian fields are instance-scoped (ADR-0022 §4 #2)"
exit 0
