#!/usr/bin/env bash
# tools/ci/lint_hp_status_consumer_mutation.sh
#
# TR-hp-status-015 — enforces ADR-0010 R-5 (forbidden_pattern: hp_status_consumer_mutation).
#
# This lint validates that the documented FAIL-STATE regression test EXISTS and has the
# required header comment that declares it is a documented failure mode (NOT a protective test).
#
# R-5 mitigation strategy:
#   - get_status_effects() returns a shallow copy with SHARED StatusEffect Resource references.
#   - Consumer mutation of returned effects corrupts authoritative state for all downstream readers.
#   - GDScript has no const-reference enforcement at runtime; convention is the sole defense.
#   - The documented FAIL-STATE regression test (hp_status_consumer_mutation_test.gd) serves as
#     regression guard: it ASSERTS the corruption IS visible (convention is sole defense).
#   - If get_status_effects is changed to deep-copy, the test will FAIL and must be updated.
#
# Contract: the lint validates the regression test is PRESENT (file + header comment).
#           The test itself validates the mutation IS observable (proves the hazard is real).
#
# Fix if lint fails:
#   - If file missing: ensure tests/unit/core/hp_status_consumer_mutation_test.gd exists.
#   - If header missing: add '# DOCUMENTED FAIL-STATE — convention is sole defense per R-5'
#     as the first line of the file.
#
# Exit code: 0 if documented fail-state regression test is present + valid, 1 if not.

set -uo pipefail

FAIL_STATE_TEST="tests/unit/core/hp_status_consumer_mutation_test.gd"
REQUIRED_HEADER="# DOCUMENTED FAIL-STATE — convention is sole defense per R-5"

if [ ! -f "$FAIL_STATE_TEST" ]; then
  echo "ADR-0010 R-5 VIOLATION (hp_status_consumer_mutation): documented FAIL-STATE regression test missing."
  echo ""
  echo "Expected file: $FAIL_STATE_TEST"
  echo "This file must exist and assert that consumer mutation of get_status_effects() IS visible"
  echo "(proving convention is the sole defense per ADR-0010 R-5)."
  echo ""
  echo "Fix: create $FAIL_STATE_TEST with the '# DOCUMENTED FAIL-STATE' header and the"
  echo "corruption-visible assertion (effects[0].remaining_turns = 999 persists cross-call)."
  exit 1
fi

if ! grep -qF "$REQUIRED_HEADER" "$FAIL_STATE_TEST"; then
  echo "ADR-0010 R-5 VIOLATION (hp_status_consumer_mutation): FAIL-STATE regression test is missing required header."
  echo ""
  echo "File: $FAIL_STATE_TEST"
  echo "Required header (first line): $REQUIRED_HEADER"
  echo ""
  echo "Fix: add the required header as the first line of $FAIL_STATE_TEST."
  echo "The header signals that this test DOCUMENTS a failure mode rather than asserting protection."
  exit 1
fi

echo "PASS: documented FAIL-STATE regression test present with required header (ADR-0010 R-5 hp_status_consumer_mutation)."
exit 0
