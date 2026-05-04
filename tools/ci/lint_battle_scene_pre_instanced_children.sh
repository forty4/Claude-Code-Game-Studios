#!/usr/bin/env bash
# tools/ci/lint_battle_scene_pre_instanced_children.sh
#
# battle_scene_pre_instanced_children forbidden_pattern enforcement (ADR-0016
# §2 + R-2 + TR-battle-scene-wiring-002).
#
# scenes/battle/battle_scene.tscn MUST contain EXACTLY 3 nodes:
# BattleScene root Node2D + GridLayer Node2D + HUDLayer CanvasLayer (layer=1).
# All 6 system Nodes (MapGrid + BattleCamera + HPStatusController + TurnOrderRunner
# + GridBattleController + BattleHUD) are code-driven via the 6-step _ready()
# mount sequence in battle_scene.gd per TR-battle-scene-wiring-003. A 4th
# (or higher) node count means a child was pre-instanced via the Godot editor —
# silently violating the setup-before-add_child mandate from 5 prior ADRs.
#
# Exit 0: scene file has exactly 3 nodes (clean)
# Exit 1: scene file has != 3 nodes (violation) OR file missing
set -euo pipefail
TARGET="scenes/battle/battle_scene.tscn"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi
NODE_COUNT=$(grep -c '^\[node name=' "$TARGET" || true)
if [ "$NODE_COUNT" -ne 3 ]; then
    echo "FAIL: $TARGET has $NODE_COUNT nodes; expected EXACTLY 3 (BattleScene + GridLayer + HUDLayer)"
    grep '^\[node name=' "$TARGET" | head -10
    exit 1
fi
echo "PASS: $TARGET has exactly 3 nodes (battle_scene_pre_instanced_children compliant)"
exit 0
