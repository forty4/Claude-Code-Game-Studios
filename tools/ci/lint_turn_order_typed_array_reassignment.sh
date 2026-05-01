#!/usr/bin/env bash
# tools/ci/lint_turn_order_typed_array_reassignment.sh
#
# TR-turn-order-010 + G-2 — enforces forbidden_pattern: turn_order_typed_array_reassignment.
# Typed-array fields MUST be mutated in-place (.clear() + .append_array()) only.
# Reassignment (_queue = new_array) breaks G-2 typed-array coalescence guarantees and
# invites type-boundary bypass hazards in production. ADR-0011 Decision Advisory B.
#
# Forbidden pattern: _queue = [...] or _queue := [...]
# Allowed pattern: _queue.clear(); _queue.append_array([...])
#
# Exit code: 0 if no reassignments, 1 if violation detected.

set -uo pipefail

TARGET="src/core/turn_order_runner.gd"

if [ ! -f "$TARGET" ]; then
  echo "lint_turn_order_typed_array_reassignment: ERROR — $TARGET not found" >&2
  exit 1
fi

# Scan for reassignment patterns (forbidden per G-2 + ADR-0011).
# Match: _queue = [...] OR _queue := [...]
# Pattern: line starts with optional whitespace, _queue, optional space, then = or :=
reassignments=$(grep -nE "^\s*_queue\s*(:?=)" "$TARGET" 2>/dev/null || true)

if [ -n "$reassignments" ]; then
  echo "TR-turn-order-010 VIOLATION: TurnOrderRunner._queue reassignment detected."
  echo "Matching lines:"
  echo "$reassignments"
  echo
  echo "Fix: Mutate _queue in-place using .clear() + .append_array() only."
  echo "Reason: typed-array reassignment hazard (G-2 gotcha) + ADR-0011 Decision Advisory B."
  echo "Correct pattern:"
  echo "  _queue.clear()"
  echo "  _queue.append_array(new_units)"
  exit 1
fi

echo "PASS: TurnOrderRunner typed-array reassignment protection intact (TR-010 + G-2)."
exit 0
