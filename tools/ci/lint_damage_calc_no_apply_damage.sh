#!/usr/bin/env bash
# tools/ci/lint_damage_calc_no_apply_damage.sh
#
# AC-DC-35 (TR-damage-calc-003 no write-path calls):
# damage_calc.gd must contain zero apply_damage calls and zero hp_status write-path
# member accesses. DamageCalc only COMPUTES damage; it never writes HP state.
# Writing HP is GridBattle's contract (story-007 integration).
#
# Grep targets:
#   - "apply_damage" — any call to an apply_damage function (HP mutation)
#   - "hp_status\." — any member access on an hp_status object (read OR write path;
#     DamageCalc must have no reference to hp_status at all)
#
# NOTE: these literal patterns must NOT appear in comments inside damage_calc.gd.
# Docstrings that need to reference the ban should paraphrase rather than quote the
# exact substring (same anti-self-trigger policy as story-004 §F-1 grep pattern).
#
# Exit code: 0 if zero matches, 1 if any match found.

set -uo pipefail

TARGET="src/feature/damage_calc/damage_calc.gd"

if [ ! -f "$TARGET" ]; then
  echo "lint_damage_calc_no_apply_damage: ERROR — $TARGET not found" >&2
  exit 1
fi

match_count=$(grep -cE "(apply_damage|hp_status\.)" "$TARGET" || true)

if [ "$match_count" -eq 0 ]; then
  echo "AC-DC-35 no-apply_damage lint: OK — $TARGET contains 0 apply_damage / hp_status references."
  exit 0
else
  echo "AC-DC-35 no-apply_damage VIOLATION: $TARGET has $match_count matching line(s) (expected 0)."
  echo "Matching lines:"
  grep -nE "(apply_damage|hp_status\.)" "$TARGET" || true
  echo
  echo "Fix: DamageCalc must not touch HP state per TR-damage-calc-003 / ADR-0012 §1."
  echo "HP mutations belong to GridBattle (story-007)."
  exit 1
fi
