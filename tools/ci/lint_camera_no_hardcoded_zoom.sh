#!/usr/bin/env bash
# tools/ci/lint_camera_no_hardcoded_zoom.sh
#
# hardcoded_zoom_literals forbidden_pattern enforcement (ADR-0013).
#
# BattleCamera source MUST NOT contain hardcoded zoom literal floats
# (0.70 / 2.00 / 1.00 / 0.10 in zoom-related lines). All values must come
# from BalanceConstants.get_const("CAMERA_ZOOM_*").
#
# False-positive control: lint allows comments referencing the values
# (e.g., "# F-1 derived: 44/64=0.70"). Only ACTIVE code lines are checked.
#
# Exit 0: clean
# Exit 1: any hardcoded zoom literal in non-comment source
set -euo pipefail
TARGET="src/feature/camera/battle_camera.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi
# Strip comments (lines starting with # or trailing # comments) then grep
# for the 4 forbidden literals when used as standalone numbers (not embedded
# in other strings like "0.703" or "20.00").
VIOLATIONS=$(grep -nE '^[^#]*\b(0\.70|2\.00|1\.00|0\.10)\b' "$TARGET" | grep -v '^\s*#' || true)
if [ -n "$VIOLATIONS" ]; then
    echo "FAIL: BattleCamera contains hardcoded zoom literals (use BalanceConstants.get_const instead):"
    echo "$VIOLATIONS"
    exit 1
fi
echo "PASS: BattleCamera has no hardcoded zoom literals (hardcoded_zoom_literals compliant)"
exit 0
