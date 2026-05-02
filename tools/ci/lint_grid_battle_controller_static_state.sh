#!/usr/bin/env bash
# tools/ci/lint_grid_battle_controller_static_state.sh
#
# grid_battle_controller_static_state forbidden_pattern enforcement
# (ADR-0014 + story-010 AC-3).
#
# GridBattleController is a battle-scoped Node — state must NOT persist across
# battles. Mirrors hp_status_static_state + turn_order_static_state precedent
# (ADR-0010 + ADR-0011). Any `static var` would survive BattleScene teardown
# and contaminate the next battle's state.
#
# Exit 0: no `static var` declarations in the controller (clean)
# Exit 1: any `static var` declaration found
set -euo pipefail
TARGET="src/feature/grid_battle/grid_battle_controller.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi
# Anchor at line start to avoid matching `var x: static_thing` etc.
COUNT=$(grep -cE '^static var ' "$TARGET" || true)
if [ "$COUNT" -ne 0 ]; then
    echo "FAIL: GridBattleController contains $COUNT 'static var' declarations (forbidden_pattern grid_battle_controller_static_state)"
    grep -nE '^static var ' "$TARGET"
    exit 1
fi
echo "PASS: GridBattleController has 0 static var declarations (battle-scoped state contract preserved)"
exit 0
