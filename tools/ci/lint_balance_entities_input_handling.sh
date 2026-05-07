#!/usr/bin/env bash
# tools/ci/lint_balance_entities_input_handling.sh
#
# Validates that all 7 input-handling-owned BalanceConstants keys are present
# in assets/data/balance/balance_entities.json AND that each value is within
# the safe-tuning range defined in ADR-0005 §Tuning Knobs.
#
# Provenance contract: this script IS the provenance record for the 7 input-
# handling keys. The INPUT_HANDLING_KEYS array below documents each key's
# default value + safe range. Pure-JSON format (no inline JSONC comments)
# per project convention; see assets/data/balance/balance_entities.provenance.md
# for the cross-system key-to-owner mapping.
#
# Mirrors lint_balance_entities_hp_status.sh + lint_balance_entities_camera.sh
# + lint_balance_entities_grid_battle_controller.sh established 3-precedent
# per-system balance-keys-presence-and-range pattern.
#
# Exit 0: all 7 keys present + all values within safe ranges
#         stdout: "7/7 keys present, all within safe ranges"
# Exit 1: any key missing or any value outside safe range
#         stdout: key name + actual value + expected range for each violation
#
# Usage:   bash tools/ci/lint_balance_entities_input_handling.sh
# CI:      wired in story-010 (.github/workflows/tests.yml)
# ADR ref: docs/architecture/ADR-0005-input-handling.md §Tuning Knobs

set -euo pipefail

JSON_FILE="assets/data/balance/balance_entities.json"

if [ ! -f "$JSON_FILE" ]; then
    echo "ERROR: $JSON_FILE not found. Run from the project root."
    exit 1
fi

if ! command -v python3 > /dev/null 2>&1; then
    echo "ERROR: python3 required for JSON parsing. Install Python 3.x."
    exit 1
fi

# ── INPUT_HANDLING_KEYS provenance table ─────────────────────────────────────
# Format per key: "KEY:DEFAULT:MIN:MAX"
# All input-handling keys are integers. Safe ranges per ADR-0005 §Tuning Knobs.
INPUT_HANDLING_KEYS=(
    "TOUCH_TARGET_MIN_PX:44:32:64"
    "TILE_WORLD_SIZE:64:32:128"
    "TPP_DOUBLE_TAP_WINDOW_MS:500:300:1000"
    "DISAMBIG_EDGE_PX:8:4:16"
    "DISAMBIG_TILE_PX:32:16:64"
    "PAN_ACTIVATION_PX:16:8:32"
    "MIN_TOUCH_DURATION_MS:80:50:200"
)

FAILED=0

for entry in "${INPUT_HANDLING_KEYS[@]}"; do
    key="${entry%%:*}"
    rest="${entry#*:}"
    expected_default="${rest%%:*}"
    rest="${rest#*:}"
    min="${rest%%:*}"
    max="${rest#*:}"

    # Read value via python3 (jq not always installed on dev boxes)
    value=$(python3 -c "
import json, sys
try:
    with open('$JSON_FILE') as f:
        data = json.load(f)
    v = data.get('$key')
    if v is None:
        sys.exit(1)
    print(v)
except Exception as e:
    sys.exit(1)
" 2>/dev/null || echo "MISSING")

    if [ "$value" = "MISSING" ]; then
        echo "::error::balance_entities.json missing required input-handling key: $key (default would be $expected_default)"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Range check (integer comparison; bash -lt / -gt only handle ints)
    if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
        echo "::error::balance_entities.json $key=$value out of safe range [$min..$max] per ADR-0005 §Tuning Knobs"
        FAILED=$((FAILED + 1))
    fi
done

if [ "$FAILED" -gt 0 ]; then
    echo "lint_balance_entities_input_handling FAIL — $FAILED violations"
    exit 1
fi

echo "lint_balance_entities_input_handling PASS — 7/7 keys present, all within safe ranges"
