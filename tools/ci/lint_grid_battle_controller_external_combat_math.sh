#!/usr/bin/env bash
# tools/ci/lint_grid_battle_controller_external_combat_math.sh
#
# grid_battle_controller_external_combat_math forbidden_pattern enforcement
# (ADR-0014 R-2 + story-010 AC-4).
#
# Migration safety rail: when Formation Bonus ADR ships, formation/angle/aura
# math moves to FormationBonusSystem. Until then, the math lives ONLY in
# GridBattleController + DamageCalc. This lint blocks any 5th file from
# accidentally re-implementing the math during the cutover.
#
# Allowlist (legitimate references):
#   src/feature/grid_battle/grid_battle_controller.gd  — sole math implementer
#   src/feature/damage_calc/damage_calc.gd             — consumer of formation_atk_bonus
#   src/feature/damage_calc/resolve_modifiers.gd       — data carrier
#   src/core/battle_unit.gd                            — doc-comment references
#   tests/helpers/                                     — test stubs
#
# Keywords: formation_atk_bonus | attack_angle | adjacent_command_aura |
#           _count_adjacent_allies | _attack_angle | _has_adjacent_command_aura
#
# Exit 0: keywords found only in allowlist (clean)
# Exit 1: any keyword found in unauthorized file
set -euo pipefail
PATTERN='formation_atk_bonus|attack_angle|adjacent_command_aura|_count_adjacent_allies|_attack_angle|_has_adjacent_command_aura'
ALLOWLIST=(
    "src/feature/grid_battle/grid_battle_controller.gd"
    "src/feature/damage_calc/damage_calc.gd"
    "src/feature/damage_calc/resolve_modifiers.gd"
    "src/core/battle_unit.gd"
)
# Find every src/ file referencing any keyword.
MATCHES=$(grep -rlE "$PATTERN" src/ 2>/dev/null || true)
VIOLATIONS=()
for FILE in $MATCHES; do
    AUTHORIZED=0
    for ALLOWED in "${ALLOWLIST[@]}"; do
        if [ "$FILE" = "$ALLOWED" ]; then
            AUTHORIZED=1
            break
        fi
    done
    if [ "$AUTHORIZED" -eq 0 ]; then
        VIOLATIONS+=("$FILE")
    fi
done
if [ ${#VIOLATIONS[@]} -ne 0 ]; then
    echo "FAIL: ${#VIOLATIONS[@]} unauthorized file(s) reference combat-math keywords (forbidden_pattern grid_battle_controller_external_combat_math):"
    for FILE in "${VIOLATIONS[@]}"; do
        echo "  $FILE"
        grep -nE "$PATTERN" "$FILE" | head -3 | sed 's/^/    /'
    done
    echo ""
    echo "Allowlist: ${ALLOWLIST[*]}"
    exit 1
fi
echo "PASS: combat-math keywords confined to allowlist (${#ALLOWLIST[@]} files)"
exit 0
