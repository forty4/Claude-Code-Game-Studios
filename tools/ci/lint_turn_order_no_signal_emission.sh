#!/usr/bin/env bash
# tools/ci/lint_turn_order_no_signal_emission.sh
#
# TR-turn-order-007 + TR-turn-order-019 — enforces ADR-0011 §Key Interfaces §Signal Contract
# 4-signal whitelist + G-15 test-isolation discipline.
#
# TurnOrderRunner emits ONLY these 4 GameBus signals:
#   1. GameBus.round_started
#   2. GameBus.unit_turn_started
#   3. GameBus.unit_turn_ended
#   4. GameBus.victory_condition_detected
#
# Any OTHER signal-emission call violates forbidden_pattern: turn_order_signal_emission_outside_domain.
# Also enforces G-15 test-isolation: every test file touching TurnOrderRunner static state
# must reset that state in before_test().
#
# Exit code: 0 if both constraints satisfied, 1 if violation detected.

set -uo pipefail

# ── Part 1: 4-signal whitelist ──────────────────────────────────────────────
TARGET="src/core/turn_order_runner.gd"

if [ ! -f "$TARGET" ]; then
  echo "lint_turn_order_no_signal_emission: ERROR — $TARGET not found" >&2
  exit 1
fi

# Extract all lines with GameBus signal emission calls.
# Pattern matches: GameBus.round_started.emit, GameBus.unit_turn_started.emit, etc.
emission_lines=$(grep -nE "GameBus\.(round_started|unit_turn_started|unit_turn_ended|victory_condition_detected)\.emit" "$TARGET" || true)

# Check for FORBIDDEN signals (any GameBus.* emit NOT in the whitelist).
# This catches: GameBus.some_other_signal.emit(), GameBus.battle_prepare_requested.emit(), etc.
forbidden_signals=$(grep -nE "GameBus\..*\.emit" "$TARGET" | grep -vE "GameBus\.(round_started|unit_turn_started|unit_turn_ended|victory_condition_detected)\.emit" || true)

if [ -n "$forbidden_signals" ]; then
  echo "TR-turn-order-007 VIOLATION: TurnOrderRunner emits signals outside the 4-signal whitelist."
  echo "Forbidden emissions:"
  echo "$forbidden_signals"
  echo
  echo "Fix: TurnOrderRunner must emit ONLY these 4 GameBus signals (ADR-0011 §Key Interfaces):"
  echo "  1. GameBus.round_started.emit()"
  echo "  2. GameBus.unit_turn_started.emit()"
  echo "  3. GameBus.unit_turn_ended.emit()"
  echo "  4. GameBus.victory_condition_detected.emit()"
  echo "Use method calls instead of signals for internal orchestration (ADR-0011 Decision)."
  exit 1
fi

# ── Part 2: G-15 test isolation grep gate (AC-17/AC-19/AC-20/AC-21) ────────
# TurnOrderRunner uses static class vars for battle-scoped caching (none currently,
# but pattern defined for future-proofing). Tests must reset any static state.
# This grep checks that test files explicitly declare reset handling.
test_files=$(find tests/unit/core tests/integration/core -name "*turn_order*test.gd" 2>/dev/null || true)

if [ -n "$test_files" ]; then
  isolation_violations=""
  for test_file in $test_files; do
    # Check if test file has before_test() or comment indicating no static state reset needed
    if ! grep -q "func before_test\|# G-15: no static state" "$test_file" 2>/dev/null; then
      isolation_violations="$isolation_violations$test_file (missing before_test or G-15 marker)"$'\n'
    fi
  done

  if [ -n "$isolation_violations" ]; then
    echo "G-15 ISOLATION VIOLATION: TurnOrderRunner test files missing before_test() hook or G-15 marker:"
    echo "$isolation_violations"
    echo
    echo "Fix: if TurnOrderRunner uses static state, add before_test() with reset logic."
    echo "If no static state exists, add comment '# G-15: no static state' near top of test file."
    exit 1
  fi
fi

echo "PASS: TurnOrderRunner 4-signal whitelist (TR-007) + G-15 test isolation (TR-019) intact."
exit 0
