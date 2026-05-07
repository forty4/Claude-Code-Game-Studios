#!/usr/bin/env bash
# tools/ci/lint_battle_hud_touch_target_size.sh
#
# battle_hud_touch_target_below_44pt forbidden_pattern enforcement
# (TR-battle-hud-011; ADR-0015 §Engine Verification §3 + accessibility-requirements.md
# WCAG 2.5.5 Target Size + technical-preferences.md mobile parity).
#
# Every interactive Control (Button / TextureButton / any Control with
# focus_mode != FOCUS_NONE) on the touch viewport MUST have:
#   custom_minimum_size.x >= 44 AND custom_minimum_size.y >= 44
#
# Files scanned:
#   - scenes/battle/battle_hud.tscn
#   - scenes/battle/elements/ui_gb_*.tscn
#
# MVP scope: enforce on nodes with the literal string `type="Button"`. The awk
# check below uses exact match (`cur_type == "Button"`), so subclasses declared
# as `type="TextureButton"` / `type="CheckBox"` / `type="OptionButton"` are
# NOT currently checked. Project state 2026-05-07: scenes/battle/ uses only
# `type="Button"` for interactive Controls (verified at story-008 implementation
# time), so this MVP scope captures all current interactive Controls. Extension
# path when subclasses arrive: add their type names to the awk match condition,
# OR generalize to `focus_mode != 0` parsing per the broader rule above.
#
# Exemption: read-only/decorative Controls (Label without focus_mode,
# ColorRect overlays). These types are not enforced.
#
# Pass-through cases:
#   - Buttons with custom_minimum_size = Vector2(N, M) where N >= 44 and M >= 44
#   - Buttons with NO custom_minimum_size set AND parent container imposes ≥44
#     (NOT auto-detected; this MVP requires explicit per-Button declaration)
#
# First dedicated accessibility lint in the project; establishes precedent for
# future UI ADRs (Battle Results polish / Tutorial overlay / Settings panel).
#
# Exit 0: all interactive Controls compliant
# Exit 1: any interactive Control below 44×44pt
set -euo pipefail
ROOT_TSCN="scenes/battle/battle_hud.tscn"
ELEMENTS_GLOB="scenes/battle/elements/ui_gb_*.tscn"

if [ ! -f "$ROOT_TSCN" ]; then
    echo "FAIL: root .tscn missing: $ROOT_TSCN"
    exit 1
fi

VIOLATIONS=""
TOTAL_CHECKED=0

# shellcheck disable=SC2086
for TSCN in $ROOT_TSCN $ELEMENTS_GLOB; do
    [ -f "$TSCN" ] || continue

    # awk parser: track each [node ...] block; capture type + custom_minimum_size;
    # at end of each block (next [node] OR EOF), validate Button compliance.
    RESULT=$(awk -v tscn_file="$TSCN" '
        function flush_node() {
            if (cur_type == "Button") {
                checked++
                if (cur_x == "" || cur_y == "") {
                    violations = violations sprintf("%s: %s (Button) missing custom_minimum_size\n", tscn_file, cur_name)
                } else if (cur_x + 0 < 44 || cur_y + 0 < 44) {
                    violations = violations sprintf("%s: %s (Button) custom_minimum_size = Vector2(%s, %s) below 44×44pt\n", tscn_file, cur_name, cur_x, cur_y)
                }
            }
            cur_type = ""
            cur_name = ""
            cur_x = ""
            cur_y = ""
        }
        /^\[node / {
            flush_node()
            # Parse type="X" — extract content between type=" and "
            if (match($0, /type="[^"]+"/)) {
                cur_type = substr($0, RSTART+6, RLENGTH-7)
            }
            # Parse name="X"
            if (match($0, /name="[^"]+"/)) {
                cur_name = substr($0, RSTART+6, RLENGTH-7)
            }
            next
        }
        /^custom_minimum_size = Vector2\(/ {
            # extract the two numeric args of Vector2(N, M)
            if (match($0, /Vector2\([^)]+\)/)) {
                vec = substr($0, RSTART+8, RLENGTH-9)
                # split on comma + optional whitespace
                n = split(vec, parts, /,[[:space:]]*/)
                if (n >= 2) {
                    cur_x = parts[1]
                    cur_y = parts[2]
                }
            }
            next
        }
        END {
            flush_node()
            printf "%d|%s", checked, violations
        }
    ' "$TSCN")

    CHECKED_THIS=$(echo "$RESULT" | cut -d'|' -f1)
    VIOLATIONS_THIS=$(echo "$RESULT" | cut -d'|' -f2-)
    TOTAL_CHECKED=$((TOTAL_CHECKED + CHECKED_THIS))
    if [ -n "$VIOLATIONS_THIS" ]; then
        VIOLATIONS="$VIOLATIONS$VIOLATIONS_THIS"
    fi
done

if [ -n "$VIOLATIONS" ]; then
    echo "FAIL: BattleHUD interactive Controls below 44×44pt (battle_hud_touch_target_below_44pt):"
    printf "%s" "$VIOLATIONS"
    exit 1
fi

echo "PASS: $TOTAL_CHECKED interactive Buttons checked across battle_hud.tscn + ui_gb_*.tscn; all ≥ 44×44pt (TR-battle-hud-011)"
exit 0
