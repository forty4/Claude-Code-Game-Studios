#!/usr/bin/env bash
# lint_damage_calc_no_hardcoded_constants.sh
#
# AC-DC-48 — Verify no hardcoded balance-constant declarations in damage_calc.gd.
#
# Enforces ADR-0012 §6: the 12 tuning constants (BASE_CEILING, MIN_DAMAGE,
# ATK_CAP, DEF_CAP, DEFEND_STANCE_ATK_PENALTY, P_MULT_COMBINED_CAP,
# CHARGE_BONUS, AMBUSH_BONUS, DAMAGE_CEILING, COUNTER_ATTACK_MODIFIER,
# BASE_DIRECTION_MULT, CLASS_DIRECTION_MULT) must NOT appear as `const X = ...`
# declarations in damage_calc.gd. Their values live exclusively in
# assets/data/balance/entities.json, read via BalanceConstants.get_const(key).
#
# Exit 0: clean (no hardcoded const declarations found).
# Exit 1: violation found (prints offending lines; CI should fail the build).
#
# Usage: bash tools/ci/lint_damage_calc_no_hardcoded_constants.sh

set -euo pipefail

TARGET="src/feature/damage_calc/damage_calc.gd"

if [ ! -f "$TARGET" ]; then
  echo "ERROR: $TARGET not found. Run from the project root."
  exit 1
fi

PATTERN="const (BASE_CEILING|MIN_DAMAGE|ATK_CAP|DEF_CAP|DEFEND_STANCE_ATK_PENALTY|P_MULT_COMBINED_CAP|CHARGE_BONUS|AMBUSH_BONUS|DAMAGE_CEILING|COUNTER_ATTACK_MODIFIER|BASE_DIRECTION_MULT|CLASS_DIRECTION_MULT) "

if grep -nE "$PATTERN" "$TARGET"; then
  echo ""
  echo "FAIL: hardcoded balance constants found in $TARGET (AC-DC-48)."
  echo "Move the literal value to assets/data/balance/entities.json and"
  echo "read it via BalanceConstants.get_const(\"KEY\") per ADR-0012 §6."
  exit 1
fi

echo "PASS: no hardcoded balance constants in $TARGET (AC-DC-48)."
exit 0
