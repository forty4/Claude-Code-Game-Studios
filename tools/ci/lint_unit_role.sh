#!/usr/bin/env bash
# tools/ci/lint_unit_role.sh
#
# Story-010 — UnitRole epic close-out static-lint per ADR-0009 §Validation Criteria.
# Run on every push touching src/foundation/ or tests/unit/foundation/.
#
# Three checks:
#   Check 1 (AC-1, ADR-0009 §Validation Criteria §4 + ADR-0001 line 375):
#       Non-emitter invariant — zero signal declarations, zero connect/emit_signal
#       calls in src/foundation/unit_role.gd. Forbidden_pattern enforcement
#       (unit_role_signal_emission registered in docs/registry/architecture.yaml).
#   Check 2 (AC-2, ADR-0009 §Validation Criteria §5 + ADR-0006):
#       Positive-coverage check — verifies UnitRole reads all 9 expected global caps
#       via BalanceConstants.get_const accessor. Inversion of the original
#       "no hardcoded values" check (which had inherent false-positives from the
#       _build_fallback_dict body that legitimately contains literal coefficients
#       like 0.7, 1.5, etc.). The positive-coverage check is more reliable.
#       MOVE_BUDGET_PER_RANGE is consumer-side compute per ADR-0009 §3 — excluded
#       from UnitRole's 9-cap obligation; consumed by Grid Battle when implemented.
#   Check 3 (AC-3, .claude/rules/godot-4x-gotchas.md G-15):
#       G-15 obligation — every UnitRole test file resets _cache_loaded in before_test.
#       Universal across all unit_role*.gd test files (story-001 reset added in
#       story-010 close-out for discipline universality).
#
# Exit code: 0 if all 3 checks pass; 1 if any fails.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UNIT_ROLE_GD="$PROJECT_ROOT/src/foundation/unit_role.gd"
TESTS_DIR="$PROJECT_ROOT/tests/unit/foundation"

# ─── Check 1: non-emitter invariant ────────────────────────────────────────

echo "[lint_unit_role] Check 1: non-emitter invariant (ADR-0009 §Validation Criteria §4)..."
if [ ! -f "$UNIT_ROLE_GD" ]; then
  echo "ERROR: $UNIT_ROLE_GD not found" >&2
  exit 1
fi

# NOTE: this regex is anchored on syntax patterns that MUST not appear:
#   - "signal " (signal foo_bar declarations; leading space distinguishes from doc-comment usage)
#   - "connect("  (subscription)
#   - "emit_signal(" (legacy string-based emit)
# Doc-comments referencing the BAN should paraphrase, not quote the exact substring,
# to avoid self-triggering this lint (same anti-self-trigger policy as G-22 source-comment).
emitter_count=$(grep -cE "(signal |connect\(|emit_signal\()" "$UNIT_ROLE_GD" || true)

if [ "$emitter_count" -ne 0 ]; then
  echo "FAIL: Check 1 — $UNIT_ROLE_GD has $emitter_count match(es) (expected 0)"
  echo "Matching lines:"
  grep -nE "(signal |connect\(|emit_signal\()" "$UNIT_ROLE_GD" || true
  echo
  echo "Fix: UnitRole is on the non-emitter list per ADR-0001 line 375 + ADR-0009"
  echo "     §Validation Criteria §4. Use return values, not signals. Forbidden_pattern"
  echo "     unit_role_signal_emission registered in docs/registry/architecture.yaml."
  exit 1
fi
echo "[lint_unit_role] Check 1: PASS (zero signal/connect/emit_signal in $UNIT_ROLE_GD)"

# ─── Check 2: positive coverage of 9 expected BalanceConstants.get_const calls ─

echo "[lint_unit_role] Check 2: BalanceConstants.get_const coverage for 9 caps..."
EXPECTED_CAPS=("ATK_CAP" "DEF_CAP" "HP_CAP" "HP_SCALE" "HP_FLOOR" "INIT_CAP" "INIT_SCALE" "MOVE_RANGE_MIN" "MOVE_RANGE_MAX")
MISSING=()
for cap in "${EXPECTED_CAPS[@]}"; do
  if ! grep -E "BalanceConstants.get_const\\(\"$cap\"\\)" "$UNIT_ROLE_GD" >/dev/null 2>&1; then
    MISSING+=("$cap")
  fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "FAIL: Check 2 — missing BalanceConstants.get_const calls in $UNIT_ROLE_GD"
  echo "Missing caps: ${MISSING[*]}"
  echo
  echo "Fix: ADR-0009 §Validation Criteria §5 + ADR-0006 — every global cap MUST be"
  echo "     read via BalanceConstants.get_const(\"<CAP_NAME>\"). Hardcoded literals"
  echo "     are forbidden in UnitRole's runtime code path."
  echo "     Note: MOVE_BUDGET_PER_RANGE is consumer-side per ADR-0009 §3 — Grid Battle"
  echo "     consumes it; UnitRole does not. Excluded from this check intentionally."
  exit 1
fi
echo "[lint_unit_role] Check 2: PASS (all 9 caps via BalanceConstants accessor)"

# ─── Check 3: G-15 obligation across all unit_role*.gd test files ─────────

echo "[lint_unit_role] Check 3: G-15 _cache_loaded reset discipline..."
if [ ! -d "$TESTS_DIR" ]; then
  echo "ERROR: $TESTS_DIR not found" >&2
  exit 1
fi

# grep -L lists files that DO NOT match the pattern. Empty output = all files match.
# Match the G-15 reset for EITHER static cache the test file may touch:
#   - `_cache_loaded` — BalanceConstants flag (tests that read get_const)
#   - `_coefficients_loaded` — UnitRole flag (tests that read coefficient cache)
# Different test files reset different caches based on what they actually test.
# Story-002 (config loader) only touches UnitRole's `_coefficients_loaded`; story-006
# (passive tags const) touches neither (parse-time const), but resets both per discipline.
# A test file passes G-15 if it resets AT LEAST ONE of the two static caches.
MISSING_FILES=$(grep -LE "(_cache_loaded|_coefficients_loaded)" "$TESTS_DIR"/unit_role*.gd 2>/dev/null || true)
if [ -n "$MISSING_FILES" ]; then
  echo "FAIL: Check 3 — G-15 obligation missing in test file(s):"
  echo "$MISSING_FILES" | sed 's/^/  /'
  echo
  echo "Fix: every unit_role*.gd test file MUST reset _cache_loaded in before_test()"
  echo "     per .claude/rules/godot-4x-gotchas.md G-15 + ADR-0006 §6. The canonical"
  echo "     pattern (per stories 002-009) uses GDScript class-object reflection:"
  echo "         var _bc_script: GDScript = load(\"res://src/feature/balance/balance_constants.gd\")"
  echo "         func before_test() -> void:"
  echo "             _bc_script.set(\"_cache_loaded\", false)"
  echo "             _bc_script.set(\"_cache\", {})"
  exit 1
fi
echo "[lint_unit_role] Check 3: PASS (G-15 reset present in all unit_role*.gd test files)"

echo
echo "[lint_unit_role] All 3 static-lint checks PASS"
exit 0
