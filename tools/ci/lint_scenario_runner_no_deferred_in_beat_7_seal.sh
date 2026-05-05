#!/usr/bin/env bash
# tools/ci/lint_scenario_runner_no_deferred_in_beat_7_seal.sh
#
# scenario_runner_deferred_seal_in_beat_7_entry forbidden_pattern enforcement
# (TR-scenario-progression-008 + ADR-0017 F-SP-3 v2.2 systems-designer B-1
#  invariant + Pillar 2 architectural lock 2nd precedent).
#
# CRITICAL: BEAT_7_JUDGMENT entry must seal first_attempt_resolved
# SYNCHRONOUSLY before DestinyBranchJudge.resolve() reads it. Any
# call_deferred / CONNECT_DEFERRED / await between BEAT_6 exit and BEAT_7
# entry corrupts the seal and breaks Pillar 2 ("운명은 바꿀 수 있다").
#
# Greps for forbidden async patterns in the BEAT_7 entry handler.
#
# Exit 0: PASS (synchronous seal preserved)
# Exit 1: FAIL (async pattern detected in BEAT_7 entry)
set -euo pipefail
TARGET="src/core/scenario_runner.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi

# Forbidden patterns (regex) within _enter_beat_7_judgment() body:
#   call_deferred(
#   CONNECT_DEFERRED
#   await
#
# Use awk to scope to the _enter_beat_7_judgment function body.
violations=$(awk '
    /^func _enter_beat_7_judgment/ {in_h=1; next}
    /^func / && in_h {in_h=0}
    in_h && /(call_deferred[[:space:]]*\(|CONNECT_DEFERRED|^\s*await\s|[[:space:]]await[[:space:]])/ && !/^[[:space:]]*#/ {print NR": "$0}
' "$TARGET" || true)

if [ -n "$violations" ]; then
    echo "FAIL: $TARGET _enter_beat_7_judgment() contains forbidden async pattern:"
    echo "$violations"
    echo "  (Pillar 2 lock 2nd precedent: BEAT_7 seal must be synchronous)"
    exit 1
fi

# Also check that the seal is not routed through GameBus dispatch.
seal_via_bus=$(awk '
    /^func _enter_beat_7_judgment/ {in_h=1; next}
    /^func / && in_h {in_h=0}
    in_h && /GameBus\..*\.connect[[:space:]]*\(/ && !/^[[:space:]]*#/ {print NR": "$0}
' "$TARGET" || true)
if [ -n "$seal_via_bus" ]; then
    echo "FAIL: $TARGET _enter_beat_7_judgment() routes seal through GameBus.connect():"
    echo "$seal_via_bus"
    exit 1
fi

echo "PASS: $TARGET BEAT_7 entry handler is synchronous (no call_deferred / CONNECT_DEFERRED / await)"
exit 0
