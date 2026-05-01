#!/usr/bin/env bash
# tools/ci/lint_turn_order_external_queue_write.sh
#
# TR-turn-order-009 — enforces forbidden_pattern: turn_order_external_queue_write.
# ADR-0011 §Key Interfaces: _queue field MUST only be mutated by TurnOrderRunner itself,
# never by external consumers. Violations surface as state-coherence bugs at production-load time.
#
# Protected pattern: _queue.clear() + _queue.append_array() only (in-place mutations).
# Forbidden pattern: external assignment via get_queue(), or direct _queue field access outside TurnOrderRunner.
#
# Exit code: 0 if no external writes, 1 if violation detected.

set -uo pipefail

TARGET="src/core/turn_order_runner.gd"
CONSUMER_PATTERN="src/core/*.gd"

if [ ! -f "$TARGET" ]; then
  echo "lint_turn_order_external_queue_write: ERROR — $TARGET not found" >&2
  exit 1
fi

# Scan for forbidden external queue writes:
# Pattern 1: var x = turn_order_runner._queue (external read of private field)
# Pattern 2: var x = get_queue() (if a public getter exists — check if it does)
# Pattern 3: _queue = (reassignment, forbidden per ADR-0011 + G-2)
#
# Legitimate uses within TurnOrderRunner:
#   _queue.clear()
#   _queue.append_array(units)
# These are OK and will not trigger the lint.
#
# Exclude doc comments (lines starting with ##) and single-line comments (##).

external_queue_writes=$(find src -name "*.gd" -type f ! -name "turn_order_runner.gd" -exec grep -l "^\s*[^#]*\._queue" {} \; 2>/dev/null || true)

if [ -n "$external_queue_writes" ]; then
  echo "TR-turn-order-009 VIOLATION: External files accessing TurnOrderRunner._queue private field."
  echo "Offending files:"
  echo "$external_queue_writes" | sed 's/^/  /'
  echo
  echo "Fix: _queue is a private TurnOrderRunner field (ADR-0011 §Key Interfaces)."
  echo "Consumers must use the public API (methods/signals), not direct field access."
  exit 1
fi

# Check for reassignment pattern within TurnOrderRunner itself (forbidden per G-2 + ADR-0011 decision advisory B).
internal_reassignment=$(grep -n "^\s*_queue\s*=" "$TARGET" 2>/dev/null || grep -n "^\s*_queue\s*:=" "$TARGET" 2>/dev/null || true)

if [ -n "$internal_reassignment" ]; then
  echo "TR-turn-order-009 VIOLATION: _queue reassignment detected (forbidden_pattern: turn_order_typed_array_reassignment)."
  echo "Matching lines:"
  echo "$internal_reassignment"
  echo
  echo "Fix: Mutate _queue in-place using .clear() + .append_array() only. Never reassign."
  echo "Reason: typed-array reassignment hazard (G-2) + ADR-0011 Decision Advisory B."
  exit 1
fi

echo "PASS: TurnOrderRunner external queue-write protection intact (TR-009)."
exit 0
