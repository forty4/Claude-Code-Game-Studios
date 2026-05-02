#!/usr/bin/env bash
# tools/ci/lint_balance_entities_grid_battle_controller.sh
#
# Grid Battle Controller BalanceConstants validation — ADR-0014 §7 + §8 +
# story-010 AC-5.
#
# Validates 6 keys present in assets/data/balance/balance_entities.json:
# - MAX_TURNS_PER_BATTLE = 5         (ADR-0014 §7 turn limit)
# - FATE_TANK_HP_THRESHOLD = 0.60    (Destiny Branch tank-survival threshold)
# - FATE_ASSASSIN_KILLS_THRESHOLD = 2 (Destiny Branch assassin-pressure threshold)
# - FATE_REAR_ATTACKS_THRESHOLD = 2  (Destiny Branch tactical-discipline threshold)
# - FATE_FORMATION_TURNS_THRESHOLD = 3 (Destiny Branch formation-discipline threshold)
# - FATE_BOSS_KILLED_REQUIRED = 1    (Destiny Branch decisive-victory threshold)
#
# 5 fate-condition thresholds may shift to Destiny Branch ADR namespace
# at sprint-6 — additive move, no breaking-change to existing key references.
#
# Exit 0: all 6 keys present
# Exit 1: any key missing
set -euo pipefail
TARGET="assets/data/balance/balance_entities.json"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi
KEYS=(
    "MAX_TURNS_PER_BATTLE"
    "FATE_TANK_HP_THRESHOLD"
    "FATE_ASSASSIN_KILLS_THRESHOLD"
    "FATE_REAR_ATTACKS_THRESHOLD"
    "FATE_FORMATION_TURNS_THRESHOLD"
    "FATE_BOSS_KILLED_REQUIRED"
)
MISSING=()
for KEY in "${KEYS[@]}"; do
    if ! grep -q "\"$KEY\"" "$TARGET"; then
        MISSING+=("$KEY")
    fi
done
if [ ${#MISSING[@]} -ne 0 ]; then
    echo "FAIL: ${#MISSING[@]} BalanceConstants key(s) missing from $TARGET:"
    for KEY in "${MISSING[@]}"; do
        echo "  - $KEY"
    done
    exit 1
fi
echo "PASS: 6/6 grid-battle-controller BalanceConstants keys present"
exit 0
