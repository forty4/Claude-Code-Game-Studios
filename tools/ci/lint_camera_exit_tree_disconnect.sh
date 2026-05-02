#!/usr/bin/env bash
# tools/ci/lint_camera_exit_tree_disconnect.sh
#
# camera_missing_exit_tree_disconnect forbidden_pattern enforcement (ADR-0013 R-6).
#
# BattleCamera MUST include _exit_tree() that explicitly disconnects
# GameBus.input_action_fired callback. Without this, the autoload retains a
# callable pointing at the freed Camera Node = leak + potential crash.
#
# Per godot-specialist 2026-05-02 ADR-0013 review concern #2 (BLOCKING revision).
#
# Exit 0: _exit_tree present + contains GameBus.input_action_fired.disconnect
# Exit 1: missing _exit_tree OR missing the disconnect literal inside it
set -euo pipefail
TARGET="src/feature/camera/battle_camera.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi
if ! grep -q '^func _exit_tree' "$TARGET"; then
    echo "FAIL: BattleCamera missing _exit_tree() body (camera_missing_exit_tree_disconnect)"
    exit 1
fi
if ! grep -q 'GameBus\.input_action_fired\.disconnect' "$TARGET"; then
    echo "FAIL: BattleCamera _exit_tree missing GameBus.input_action_fired.disconnect call"
    exit 1
fi
echo "PASS: BattleCamera _exit_tree includes explicit GameBus disconnect (R-6 compliant)"
exit 0
