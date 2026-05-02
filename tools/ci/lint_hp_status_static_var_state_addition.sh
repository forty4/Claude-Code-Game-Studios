#!/usr/bin/env bash
# tools/ci/lint_hp_status_static_var_state_addition.sh
#
# TR-hp-status-015 — enforces ADR-0010 R-4 (forbidden_pattern: hp_status_static_var_state_addition).
#
# HPStatusController (src/core/hp_status_controller.gd) MUST NOT introduce static var fields
# for caching, optimization, or any other purpose. All mutable state lives in instance vars
# (_state_by_unit Dictionary, plus any future _cached_X instance vars).
#
# Adding static var to HPStatusController would:
#   (a) break the non-persistence contract (CR-1b mandates HP state resets between battles;
#       static vars persist across battles requiring explicit reset — same hazard ADR-0006 documented)
#   (b) drift the module form away from the battle-scoped Node pattern
#   (c) introduce a hybrid battle-scoped-Node + stateless-static pattern that no other ADR follows
#
# Fix: remove any `static var` declaration from src/core/hp_status_controller.gd.
#      Future caching needs MUST use instance vars (add to _state_by_unit or new _cached_X var).
#
# Exit code: 0 if no static vars exist, 1 if violation detected.

set -uo pipefail

TARGET="src/core/hp_status_controller.gd"

if [ ! -f "$TARGET" ]; then
  echo "ERROR: lint_hp_status_static_var_state_addition — $TARGET not found" >&2
  exit 1
fi

COUNT=$(grep -c '^static var' "$TARGET" || true)

if [ "$COUNT" != "0" ]; then
  echo "ADR-0010 R-4 VIOLATION (hp_status_static_var_state_addition): $TARGET has $COUNT static var declaration(s)."
  echo ""
  echo "Offending lines:"
  grep -n '^static var' "$TARGET"
  echo ""
  echo "Fix: remove all 'static var' declarations from $TARGET."
  echo "Future caching needs MUST extend the existing instance var pattern (ADR-0010 R-4)."
  exit 1
fi

echo "PASS: 0 static vars in $TARGET (ADR-0010 R-4 intact)."
exit 0
