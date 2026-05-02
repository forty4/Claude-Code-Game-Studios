#!/usr/bin/env bash
# tools/ci/lint_camera_external_screen_to_grid.sh
#
# external_screen_to_grid_implementation forbidden_pattern enforcement (ADR-0013).
#
# BattleCamera.screen_to_grid is the SOLE implementation of screen-to-grid
# coordinate conversion in src/. No other class may implement a function
# with this name.
#
# Test helpers (tests/helpers/) are exempt — stub-injection precedent.
#
# Exit 0: exactly 1 match in src/feature/camera/battle_camera.gd
# Exit 1: 0 matches OR > 1 match (multi-implementation = silent drift bug)
set -euo pipefail
MATCHES=$(grep -rln 'func screen_to_grid' src/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$MATCHES" -eq 0 ]; then
    echo "FAIL: no func screen_to_grid found in src/ (BattleCamera missing implementation)"
    exit 1
fi
if [ "$MATCHES" -gt 1 ]; then
    echo "FAIL: $MATCHES implementations of screen_to_grid in src/ (only BattleCamera should have it):"
    grep -rln 'func screen_to_grid' src/
    exit 1
fi
EXPECTED="src/feature/camera/battle_camera.gd"
ACTUAL=$(grep -rln 'func screen_to_grid' src/)
if [ "$ACTUAL" != "$EXPECTED" ]; then
    echo "FAIL: screen_to_grid found in unexpected location: $ACTUAL (expected $EXPECTED)"
    exit 1
fi
echo "PASS: screen_to_grid sole implementation in $EXPECTED (external_screen_to_grid_implementation compliant)"
exit 0
