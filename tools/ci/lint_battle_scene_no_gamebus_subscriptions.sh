#!/usr/bin/env bash
# tools/ci/lint_battle_scene_no_gamebus_subscriptions.sh
#
# battle_scene_root_signal_subscription forbidden_pattern enforcement
# (ADR-0016 R-7 + TR-battle-scene-wiring-007).
#
# src/feature/battle_scene/battle_scene.gd MUST have zero GameBus.<X>.connect
# AND zero GameBus.<X>.emit substring matches. BattleScene root is non-emitter
# AND non-subscriber by design — cross-system signal flow goes through the 6
# mounted children, not through the scene-root orchestrator.
#
# Exit 0: no connect/emit calls found (clean)
# Exit 1: any GameBus.<X>.(connect|emit) call found
set -euo pipefail
TARGET="src/feature/battle_scene/battle_scene.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi
COUNT=$(grep -cE 'GameBus\.[a-zA-Z_]+\.(connect|emit)\(' "$TARGET" || true)
if [ "$COUNT" -ne 0 ]; then
    echo "FAIL: BattleScene contains $COUNT GameBus.<X>.(connect|emit) calls (forbidden_pattern battle_scene_root_signal_subscription)"
    grep -nE 'GameBus\.[a-zA-Z_]+\.(connect|emit)\(' "$TARGET"
    exit 1
fi
echo "PASS: BattleScene has zero GameBus.<X>.connect/emit (battle_scene_root_signal_subscription compliant)"
exit 0
