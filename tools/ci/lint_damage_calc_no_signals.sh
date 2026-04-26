#!/usr/bin/env bash
# tools/ci/lint_damage_calc_no_signals.sh
#
# AC-DC-34 (TR-damage-calc-004 signal-free):
# damage_calc.gd must contain zero signal declarations and zero emit_signal calls.
# DamageCalc is a stateless synchronous pipeline; signals would violate ADR-0012 §1.
#
# Grep targets:
#   - "signal " — matches "signal foo_bar" declarations (leading space distinguishes
#     from identifiers that merely CONTAIN the word "signal")
#   - "emit_signal" — matches any call to the deprecated string-based emit_signal API
#
# NOTE: these literal patterns must NOT appear in comments inside damage_calc.gd.
# Docstrings that need to reference the ban should paraphrase rather than quote the
# exact substring (same anti-self-trigger policy as story-004 §F-1 grep pattern).
#
# Exit code: 0 if zero matches, 1 if any match found.

set -uo pipefail

TARGET="src/feature/damage_calc/damage_calc.gd"

if [ ! -f "$TARGET" ]; then
  echo "lint_damage_calc_no_signals: ERROR — $TARGET not found" >&2
  exit 1
fi

signal_count=$(grep -cE "(signal |emit_signal)" "$TARGET" || true)

if [ "$signal_count" -eq 0 ]; then
  echo "AC-DC-34 no-signals lint: OK — $TARGET contains 0 signal declarations / emit_signal calls."
  exit 0
else
  echo "AC-DC-34 no-signals VIOLATION: $TARGET has $signal_count matching line(s) (expected 0)."
  echo "Matching lines:"
  grep -nE "(signal |emit_signal)" "$TARGET" || true
  echo
  echo "Fix: DamageCalc must be signal-free per ADR-0012 §1. Use return values, not signals."
  exit 1
fi
