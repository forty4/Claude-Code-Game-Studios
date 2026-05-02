#!/usr/bin/env bash
# tools/ci/lint_balance_entities_camera.sh
#
# Camera + Input-Handling F-1 BalanceConstants validation — ADR-0013 §Decision §2.
#
# Validates 6 keys present in assets/data/balance/balance_entities.json:
# - TILE_WORLD_SIZE = 64 (input-handling F-1 + map-grid)
# - TOUCH_TARGET_MIN_PX = 44 (input-handling F-1 floor)
# - CAMERA_ZOOM_MIN = 0.70 (F-1 derived: 44/64=0.6875 → 0.70 with comfort margin)
# - CAMERA_ZOOM_MAX = 2.00 (PC tactical readability ceiling)
# - CAMERA_ZOOM_DEFAULT = 1.00 (tile = 64px native)
# - CAMERA_ZOOM_STEP = 0.10 (wheel-zoom delta per camera_zoom_in/out event)
#
# Exit 0: all 6 keys present
# Exit 1: any key missing (with the missing key name in stdout)
set -euo pipefail
TARGET="assets/data/balance/balance_entities.json"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi
KEYS=("TILE_WORLD_SIZE" "TOUCH_TARGET_MIN_PX" "CAMERA_ZOOM_MIN" "CAMERA_ZOOM_MAX" "CAMERA_ZOOM_DEFAULT" "CAMERA_ZOOM_STEP")
MISSING=()
for KEY in "${KEYS[@]}"; do
    if ! grep -q "\"$KEY\"" "$TARGET"; then
        MISSING+=("$KEY")
    fi
done
if [ ${#MISSING[@]} -ne 0 ]; then
    echo "FAIL: ${#MISSING[@]} BalanceConstants keys missing from $TARGET:"
    for KEY in "${MISSING[@]}"; do
        echo "  - $KEY"
    done
    exit 1
fi
echo "PASS: 6/6 camera + F-1 BalanceConstants keys present"
exit 0
