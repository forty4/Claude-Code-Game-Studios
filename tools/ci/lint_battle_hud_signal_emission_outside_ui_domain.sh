#!/usr/bin/env bash
# tools/ci/lint_battle_hud_signal_emission_outside_ui_domain.sh
#
# battle_hud_signal_emission forbidden_pattern enforcement (TR-battle-hud-007;
# ADR-0015 §5 R-5 + ADR-0001 §445 50-emits/frame budget).
#
# Non-emitter discipline: BattleHUD MUST NOT emit any GameBus signal. HUD is a
# pure CONSUMER + state-reader. Cross-system events that HUD initiates flow
# back through InputRouter as synthetic events (e.g., Undo button click invokes
# `_input_router._handle_event(synthetic_undo_event)`) — HUD itself never
# authors the cross-system payload.
#
# Pattern shape mirrors 4-precedent project discipline:
#   camera_signal_emission + balance_constants_signal_emission +
#   grid_battle_controller_signal_emission_outside_battle_domain +
#   damage_calc_signal_emission
#
# The `\.emit\(` anchor distinguishes emit calls from
# `.connect / .disconnect / .is_connected` lines.
#
# Exit 0: zero GameBus.<X>.emit calls
# Exit 1: any GameBus.<X>.emit call found
set -euo pipefail
TARGET="src/feature/battle_hud/battle_hud.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi
COUNT=$(grep -cE 'GameBus\.[a-zA-Z_]+\.emit\(' "$TARGET" || true)
if [ "$COUNT" -ne 0 ]; then
    echo "FAIL: BattleHUD contains $COUNT GameBus.<X>.emit calls (forbidden_pattern battle_hud_signal_emission)"
    grep -nE 'GameBus\.[a-zA-Z_]+\.emit\(' "$TARGET"
    exit 1
fi
echo "PASS: BattleHUD emits 0 GameBus signals (non-emitter discipline holds; cross-system events flow through InputRouter)"
exit 0
