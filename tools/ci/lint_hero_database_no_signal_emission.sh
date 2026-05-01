#!/usr/bin/env bash
# tools/ci/lint_hero_database_no_signal_emission.sh
#
# TR-hero-database-013 — enforces ADR-0001 line 372 non-emitter invariant for
# Hero Database (#25 in non-emitter list). Also enforces G-15 test-isolation
# discipline: every test file touching HeroDatabase static state must reset
# _heroes_loaded = false in before_test().
#
# Mirrors damage-calc + unit-role + balance-data 4-precedent stateless-non-emitter pattern.
#
# Exit code: 0 if zero violations, 1 if any violation.

set -uo pipefail

# ── Part 1: non-emitter invariant ─────────────────────────────────────────────
TARGETS=(
  "src/foundation/hero_database.gd"
  "src/foundation/hero_data.gd"
)

for target in "${TARGETS[@]}"; do
  if [ ! -f "$target" ]; then
    echo "lint_hero_database_no_signal_emission: ERROR — $target not found" >&2
    exit 1
  fi
done

emit_violations=$(grep -nE "(signal |connect\(|emit_signal\()" "${TARGETS[@]}" || true)

if [ -n "$emit_violations" ]; then
  echo "TR-hero-database-013 VIOLATION: HeroDatabase / HeroData must contain zero signal declarations / connect / emit_signal calls (non-emitter list per ADR-0001 line 372)."
  echo "Matching lines:"
  echo "$emit_violations"
  echo
  echo "Fix: HeroDatabase is on the non-emitter list. Use direct method calls, not signals."
  exit 1
fi

# ── Part 2: G-15 test isolation grep gate (AC-3) ──────────────────────────────
# Matches both direct-assignment form (_heroes_loaded = false) and
# reflective-set form (set("_heroes_loaded", false)) used by @abstract-class tests
# that access static vars via GDScript.set().
isolation_violations=$(grep -LE '(_heroes_loaded = false|set\("_heroes_loaded", false\))' \
    tests/unit/foundation/hero_database*.gd \
    tests/integration/foundation/hero_database*.gd 2>/dev/null || true)

if [ -n "$isolation_violations" ]; then
  echo "G-15 ISOLATION VIOLATION: HeroDatabase test files missing '_heroes_loaded = false' reset in before_test():"
  echo "$isolation_violations"
  echo
  echo "Fix: every test file touching HeroDatabase static state must reset _heroes_loaded in before_test() (G-15 + ADR-0006 §6 obligation)."
  exit 1
fi

echo "PASS: HeroDatabase non-emitter (TR-013) + G-15 isolation invariants intact."
exit 0
