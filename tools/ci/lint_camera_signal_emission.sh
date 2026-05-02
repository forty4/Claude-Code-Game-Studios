#!/usr/bin/env bash
# tools/ci/lint_camera_signal_emission.sh
#
# camera_signal_emission forbidden_pattern enforcement (ADR-0013).
#
# BattleCamera (src/feature/camera/battle_camera.gd) MUST NOT emit any GameBus
# signal in MVP. Lint via grep for GameBus.<X>.emit calls; the .emit suffix
# anchor distinguishes emit from subscribe / disconnect / is_connected lines
# (per godot-specialist 2026-05-02 ADR-0013 review advisory).
#
# Exit 0: no emit calls found (clean)
# Exit 1: any GameBus.<X>.emit call found
set -euo pipefail
TARGET="src/feature/camera/battle_camera.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi
COUNT=$(grep -cE 'GameBus\.[a-zA-Z_]+\.emit\(' "$TARGET" || true)
if [ "$COUNT" -ne 0 ]; then
    echo "FAIL: BattleCamera contains $COUNT GameBus.<X>.emit calls (forbidden_pattern camera_signal_emission)"
    grep -nE 'GameBus\.[a-zA-Z_]+\.emit\(' "$TARGET"
    exit 1
fi
echo "PASS: BattleCamera emits 0 GameBus signals (camera_signal_emission compliant)"
exit 0
