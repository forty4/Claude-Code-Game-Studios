#!/usr/bin/env bash
# tools/ci/lint_battle_hud_font_size_budget.sh
#
# AC-B13-06 — Tier font size budget enforcement (battle-hud-info-hierarchy.md §5.1).
#
# Tier floor/ceiling table (any add_theme_font_size_override in battle_hud.gd
# must fall in the union [T4_floor 8 … T1_ceiling 24]):
#   T1 (UI-GB-01/03/04/07/08/09): 18..24
#   T2 (UI-GB-02/05/10)         : 14..18
#   T3 (UI-GB-06)               : 12..16
#   T4 (UI-GB-11/12/13/14)      : 8..10
#
# Lint logic:
#   1. Grep every add_theme_font_size_override("font_size", N) call in battle_hud.gd
#   2. Extract the integer N from each
#   3. Fail if N < 8 or N > 24 (outside union of all tier ranges)
#   4. Print a table of (line, value, candidate tier) for manual cross-check
#
# This lint enforces only the union range. Per-element tier validation requires
# tag annotations not yet present in the source. When tag annotations land, this
# lint can grow into a stricter per-tier check.
#
# Exit 0: all overrides within [8, 24]
# Exit 1: any override outside [8, 24] OR missing source file
set -euo pipefail

TARGET="src/feature/battle_hud/battle_hud.gd"
GLOBAL_FLOOR=8
GLOBAL_CEILING=24

if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi

# Extract (line:number_value) pairs from add_theme_font_size_override calls.
# Pattern: add_theme_font_size_override("font_size", <integer>)
HITS=$(grep -nE 'add_theme_font_size_override\("font_size",\s*[0-9]+\s*\)' "$TARGET" || true)

if [ -z "$HITS" ]; then
    echo "PASS: no add_theme_font_size_override calls in $TARGET (vacuous)"
    exit 0
fi

VIOLATIONS=0
TOTAL=0

echo "── Font size budget audit (battle-hud-info-hierarchy.md §5.1) ──"
printf "  %-6s %-8s %-12s\n" "LINE" "VALUE" "CANDIDATE TIER"
echo "  ──────────────────────────────────"

while IFS= read -r hit; do
    LINE_NUM=$(echo "$hit" | cut -d: -f1)
    # Extract the integer after the "font_size" key. Pipeline survives BSD sed:
    # grep -oE pulls the literal pattern; tail/grep peels off the trailing int.
    VALUE=$(echo "$hit" | grep -oE 'add_theme_font_size_override\("font_size",[[:space:]]*[0-9]+' \
        | grep -oE '[0-9]+$')
    TOTAL=$((TOTAL + 1))

    # Tier inference for the table (overlap regions print all candidates).
    TIER=""
    if [ "$VALUE" -ge 18 ] && [ "$VALUE" -le 24 ]; then TIER="T1"; fi
    if [ "$VALUE" -ge 14 ] && [ "$VALUE" -le 18 ]; then TIER="${TIER:+$TIER/}T2"; fi
    if [ "$VALUE" -ge 12 ] && [ "$VALUE" -le 16 ]; then TIER="${TIER:+$TIER/}T3"; fi
    if [ "$VALUE" -ge 8 ] && [ "$VALUE" -le 10 ]; then TIER="${TIER:+$TIER/}T4"; fi
    if [ -z "$TIER" ]; then TIER="OUT-OF-BUDGET"; fi

    printf "  %-6s %-8s %-12s\n" "$LINE_NUM" "$VALUE" "$TIER"

    if [ "$VALUE" -lt "$GLOBAL_FLOOR" ] || [ "$VALUE" -gt "$GLOBAL_CEILING" ]; then
        echo "    ↑ FAIL: $VALUE outside global budget [$GLOBAL_FLOOR, $GLOBAL_CEILING]"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done <<< "$HITS"

echo "  ──────────────────────────────────"
echo "  TOTAL: $TOTAL calls · VIOLATIONS: $VIOLATIONS"

if [ "$VIOLATIONS" -gt 0 ]; then
    echo "FAIL: $VIOLATIONS font_size override(s) outside [$GLOBAL_FLOOR, $GLOBAL_CEILING]"
    exit 1
fi

echo "PASS: $TOTAL font_size override(s) within global budget [$GLOBAL_FLOOR, $GLOBAL_CEILING]"
exit 0
