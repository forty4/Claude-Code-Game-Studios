#!/usr/bin/env bash
# tools/ci/lint_grid_battle_controller_signal_emission_outside_battle_domain.sh
#
# grid_battle_controller_signal_emission_outside_battle_domain forbidden_pattern
# enforcement (ADR-0014 §8 + story-010 AC-2).
#
# GridBattleController emits 5 LOCAL signals only:
#   unit_selected_changed / unit_moved / damage_applied /
#   battle_outcome_resolved / hidden_fate_condition_progressed
# It MUST NOT emit any GameBus.<X>.emit signal — Battle-domain signals are
# controller-LOCAL by ADR-0014 §8 contract (Battle HUD subscribes to the
# controller's own signals, not via GameBus).
#
# Exit 0: no GameBus.<X>.emit calls in the controller (clean)
# Exit 1: any GameBus.<X>.emit call found
set -euo pipefail
TARGET="src/feature/grid_battle/grid_battle_controller.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi
COUNT=$(grep -cE 'GameBus\.[a-zA-Z_]+\.emit\(' "$TARGET" || true)
if [ "$COUNT" -ne 0 ]; then
    echo "FAIL: GridBattleController contains $COUNT GameBus.<X>.emit calls (forbidden_pattern grid_battle_controller_signal_emission_outside_battle_domain)"
    grep -nE 'GameBus\.[a-zA-Z_]+\.emit\(' "$TARGET"
    exit 1
fi
echo "PASS: GridBattleController emits 0 GameBus signals (5 LOCAL signals only per ADR-0014 §8)"
exit 0
