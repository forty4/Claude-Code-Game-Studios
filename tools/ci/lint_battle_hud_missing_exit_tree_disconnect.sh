#!/usr/bin/env bash
# tools/ci/lint_battle_hud_missing_exit_tree_disconnect.sh
#
# battle_hud_missing_exit_tree_disconnect forbidden_pattern enforcement
# (TR-battle-hud-003 + TR-battle-hud-013; ADR-0015 §3 + Engine Verification §6).
#
# BattleHUD MUST include _exit_tree() that explicitly disconnects all 11+
# subscriptions (4 GridBattleController controller-LOCAL + 1 HPStatus +
# 3 TurnOrder + 2 InputRouter + 1 Formation Bonus = 11 baseline; story-005
# button click handlers + timer.timeout add to the count).
#
# Without explicit disconnects, the autoload retains callables pointing at the
# freed BattleHUD Node = leak + potential crash. Mirrors 4-precedent
# exit_tree_disconnect discipline.
#
# Lint approach: count `\.disconnect\(` occurrences inside the `_exit_tree(`
# function body using a multi-line awk parser. Pattern broadens beyond
# `GameBus.*.disconnect` to also count controller-LOCAL `_grid_controller.X.disconnect`
# and Control-local `_btn_X.pressed.disconnect` calls per ADR-0015 §3 obligation.
#
# Exit 0: count ≥ 11
# Exit 1: missing _exit_tree OR count < 11
set -euo pipefail
TARGET="src/feature/battle_hud/battle_hud.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi
if ! grep -q '^func _exit_tree(' "$TARGET"; then
    echo "FAIL: BattleHUD missing _exit_tree() body (battle_hud_missing_exit_tree_disconnect)"
    exit 1
fi
# Multi-line awk parser: extract _exit_tree body + count .disconnect( occurrences.
# Per .claude/rules/tooling-gotchas.md TG-3: use flag/next pattern to avoid
# start-line self-close trap when start matches end pattern.
COUNT=$(awk '
    /^func _exit_tree\(/ { flag=1; next }
    flag && /^func / { flag=0 }
    flag && /\.disconnect\(/ { count++ }
    END { print count+0 }
' "$TARGET")
if [ "$COUNT" -lt 11 ]; then
    echo "FAIL: BattleHUD _exit_tree() body has $COUNT disconnect calls; expected ≥ 11 (TR-battle-hud-003)"
    exit 1
fi
echo "PASS: BattleHUD _exit_tree() body has $COUNT disconnect calls (≥ 11 required; TR-battle-hud-003 holds)"
exit 0
