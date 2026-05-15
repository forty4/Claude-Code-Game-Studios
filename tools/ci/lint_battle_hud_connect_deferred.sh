#!/usr/bin/env bash
# tools/ci/lint_battle_hud_connect_deferred.sh
#
# CONNECT_DEFERRED discipline enforcement (ADR-0015 §Engine Verification §6 +
# ADR-0001 §5 mandate; Engine Verification Item 6 — KEEP forever).
#
# All 15 GameBus + GridBattleController-LOCAL signal subscriptions in
# BattleHUD.gd MUST use Object.CONNECT_DEFERRED:
#   - 8 GridBattleController controller-LOCAL (unit_selected_changed,
#     unit_moved, damage_applied, battle_outcome_resolved,
#     attack_preview_requested, attack_preview_dismissed [session-10],
#     unit_defend_stance_applied [session-24], unit_skill_used [session-24])
#   - 7 GameBus (unit_died, round_started, unit_turn_started, unit_turn_ended,
#     input_state_changed, input_mode_changed, formation_bonuses_updated)
#
# Scope: only the 15 GameBus / _grid_controller subscriptions are checked.
# Local Control signal subscriptions (Button.pressed, Timer.timeout) are NOT
# subject to ADR-0001 §5 CONNECT_DEFERRED mandate — those are intra-class
# Control-tree connections, not cross-system bus subscriptions.
#
# Lint logic:
#   1. Find all `\.connect\(` lines in battle_hud.gd
#   2. Filter to lines containing `GameBus\.` OR `_grid_controller\.`
#   3. Assert each filtered line contains `Object.CONNECT_DEFERRED`
#   4. Assert filtered count == 15 (catches accidental subscription drop)
#
# Exit 0: all 15 GameBus/controller subscriptions use CONNECT_DEFERRED
# Exit 1: any subscription missing CONNECT_DEFERRED OR count != 15
set -euo pipefail
TARGET="src/feature/battle_hud/battle_hud.gd"
EXPECTED_COUNT=15
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi

# Stage 1: extract the 11 cross-system connect lines.
SUBSCRIPTIONS=$(grep -nE '(GameBus|_grid_controller)\.[a-zA-Z_]+\.connect\(' "$TARGET" || true)
COUNT=$(echo "$SUBSCRIPTIONS" | grep -c . || true)
# Note: when SUBSCRIPTIONS is empty, `grep -c .` of empty input returns 0.

if [ "$COUNT" -ne "$EXPECTED_COUNT" ]; then
    echo "FAIL: BattleHUD has $COUNT GameBus/controller subscriptions; expected $EXPECTED_COUNT"
    echo "Found subscriptions:"
    echo "$SUBSCRIPTIONS"
    exit 1
fi

# Stage 2: assert every subscription line includes Object.CONNECT_DEFERRED.
NON_DEFERRED=$(echo "$SUBSCRIPTIONS" | grep -v 'Object\.CONNECT_DEFERRED' || true)
if [ -n "$NON_DEFERRED" ]; then
    echo "FAIL: $EXPECTED_COUNT GameBus/controller subscriptions found, but some missing Object.CONNECT_DEFERRED:"
    echo "$NON_DEFERRED"
    echo ""
    echo "ADR-0001 §5 mandate: all GameBus subscriptions MUST use Object.CONNECT_DEFERRED."
    echo "ADR-0015 Engine Verification Item 6: KEEP forever."
    exit 1
fi

echo "PASS: All $EXPECTED_COUNT BattleHUD GameBus/controller subscriptions use Object.CONNECT_DEFERRED (ADR-0001 §5 mandate holds)"
exit 0
