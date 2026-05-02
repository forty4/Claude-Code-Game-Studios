#!/usr/bin/env bash
# tools/ci/lint_balance_entities_hp_status.sh
#
# HP/Status BalanceConstants validation — ADR-0010 §12, story-001.
#
# Validates that all 27 HP/Status-owned BalanceConstants keys are present in
# assets/data/balance/balance_entities.json AND that each value is within the
# safe-tuning range defined in ADR-0010 §12.
#
# Provenance contract (Resolution 2): this script IS the provenance record for
# the 27 HP/Status-owned keys. The HP_STATUS_KEYS array below documents which
# keys belong to HP/Status, their default values, and their safe ranges.
# Pure-JSON format is maintained (no inline JSONC comments) per project convention.
#
# Exit 0: all 27 keys present + all values within safe ranges
#         stdout: "27/27 keys present, all within safe ranges"
# Exit 1: any key missing or any value outside safe range
#         stdout: key name + actual value + expected range for each violation
#
# Usage:   bash tools/ci/lint_balance_entities_hp_status.sh
# CI:      wired in story-008 (.github/workflows/tests.yml)
# ADR ref: docs/architecture/ADR-0010-hp-status.md §12
#
# Cross-references:
#   tools/ci/lint_damage_calc_no_hardcoded_constants.sh (sibling lint pattern)
#   assets/data/balance/balance_entities.provenance.md (key-to-owner mapping)

set -euo pipefail

JSON_FILE="assets/data/balance/balance_entities.json"

if [ ! -f "$JSON_FILE" ]; then
    echo "ERROR: $JSON_FILE not found. Run from the project root."
    exit 1
fi

# ── HP_STATUS_KEYS provenance table ──────────────────────────────────────────
# Format per key: "KEY:DEFAULT:MIN:MAX:TYPE"
# TYPE: "int" or "float"
# For signed-integer keys (negative allowed), MIN may be negative.
# Keys with "locked" range use MIN==MAX==DEFAULT (exact-match enforcement).
#
# 4 keys already present (no-change; lint validates defaults):
#   MIN_DAMAGE                 owned by HP/Status; dual-enforced at Damage Calc per ADR-0012 line 92
#   ATK_CAP                    owned by HP/Status; consumed by Damage Calc per ADR-0012 line 297-299
#   DEF_CAP                    owned by HP/Status; consumed by Damage Calc per ADR-0012 line 297-299
#   DEFEND_STANCE_ATK_PENALTY  damage-calc fraction form (0.40 = 40% reduction); the .tres-embedded
#                              -40 in defend_stance.tres modifier_targets is the F-4 percent-modifier
#                              and is INDEPENDENT of this JSON value. ADR-0010 §12 prescribed -40
#                              represents aspirational future-state unification (carry-forward).
#
# 23 new keys appended (story-001 same-patch obligation per ADR-0006 §6 pattern):
HP_STATUS_KEYS=(
    "MIN_DAMAGE:1:1:3:int"
    "ATK_CAP:200:200:200:int"
    "DEF_CAP:105:105:105:int"
    "DEFEND_STANCE_ATK_PENALTY:0.40:0.40:0.40:float"
    "SHIELD_WALL_FLAT:5:3:8:int"
    "HEAL_BASE:15:5:30:int"
    "HEAL_HP_RATIO:0.10:0.05:0.20:float"
    "HEAL_PER_USE_CAP:50:30:80:int"
    "EXHAUSTED_HEAL_MULT:0.5:0.3:0.7:float"
    "DOT_HP_RATIO:0.04:0.02:0.08:float"
    "DOT_FLAT:3:0:10:int"
    "DOT_MIN:1:1:3:int"
    "DOT_MAX_PER_TURN:20:15:30:int"
    "DEMORALIZED_ATK_REDUCTION:-25:-40:-15:int"
    "DEMORALIZED_RADIUS:4:2:6:int"
    "DEMORALIZED_TURN_CAP:4:2:6:int"
    "DEMORALIZED_RECOVERY_RADIUS:2:1:3:int"
    "DEMORALIZED_DEFAULT_DURATION:4:2:6:int"
    "DEFEND_STANCE_REDUCTION:50:30:70:int"
    "INSPIRED_ATK_BONUS:20:10:30:int"
    "INSPIRED_DURATION:2:1:3:int"
    "EXHAUSTED_MOVE_REDUCTION:1:1:2:int"
    "EXHAUSTED_DEFAULT_DURATION:2:1:3:int"
    "MODIFIER_FLOOR:-50:-60:-20:int"
    "MODIFIER_CEILING:50:20:60:int"
    "MAX_STATUS_EFFECTS_PER_UNIT:3:2:4:int"
    "POISON_DEFAULT_DURATION:3:2:4:int"
)

# ── Validation logic ──────────────────────────────────────────────────────────

FAIL=0
PASS_COUNT=0
TOTAL=${#HP_STATUS_KEYS[@]}

# Detect whether jq is available
if command -v jq >/dev/null 2>&1; then
    USE_JQ=1
else
    USE_JQ=0
fi

for entry in "${HP_STATUS_KEYS[@]}"; do
    KEY=$(echo "$entry" | cut -d: -f1)
    SAFE_MIN=$(echo "$entry" | cut -d: -f3)
    SAFE_MAX=$(echo "$entry" | cut -d: -f4)
    KEY_TYPE=$(echo "$entry" | cut -d: -f5)

    # Extract value from JSON
    if [ "$USE_JQ" -eq 1 ]; then
        VALUE=$(jq -r --arg k "$KEY" '.[$k] // "MISSING"' "$JSON_FILE")
    else
        # Grep-based fallback for environments without jq
        # Matches: "KEY": value  (int, float, or negative)
        RAW=$(grep -o "\"$KEY\"[[:space:]]*:[[:space:]]*-\?[0-9][0-9.]*" "$JSON_FILE" || true)
        if [ -z "$RAW" ]; then
            VALUE="MISSING"
        else
            VALUE=$(echo "$RAW" | sed 's/.*:[[:space:]]*//')
        fi
    fi

    if [ "$VALUE" = "MISSING" ] || [ "$VALUE" = "null" ]; then
        echo "FAIL: key '$KEY' is missing from $JSON_FILE"
        FAIL=1
        continue
    fi

    # Range check using awk (handles int and float; handles negative numbers)
    IN_RANGE=$(awk -v val="$VALUE" -v lo="$SAFE_MIN" -v hi="$SAFE_MAX" \
        'BEGIN { print (val + 0 >= lo + 0 && val + 0 <= hi + 0) ? "yes" : "no" }')

    if [ "$IN_RANGE" = "no" ]; then
        echo "FAIL: key '$KEY' value=$VALUE is outside safe range [$SAFE_MIN, $SAFE_MAX]"
        FAIL=1
    else
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
done

if [ "$FAIL" -eq 1 ]; then
    echo "$PASS_COUNT/$TOTAL keys present and within safe ranges (see FAILs above)."
    exit 1
fi

echo "${TOTAL}/${TOTAL} keys present, all within safe ranges"
exit 0
