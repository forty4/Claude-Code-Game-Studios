#!/usr/bin/env bash
# tools/ci/lint_damage_calc_sole_entry_point.sh
#
# AC-DC-33 (TR-damage-calc-001 sole entry point):
# damage_calc.gd must export exactly 1 public function: resolve().
# All private helpers must be _-prefixed. This script counts non-underscore-prefixed
# top-level func declarations (i.e. "func [a-z]" lines where the name does NOT start
# with _). Exactly 1 match is required: `resolve`.
#
# Exit code: 0 if exactly 1 public func, 1 if not.
# Excludes: test files, comments, class_name / extends lines.

set -uo pipefail

TARGET="src/feature/damage_calc/damage_calc.gd"

if [ ! -f "$TARGET" ]; then
  echo "lint_damage_calc_sole_entry_point: ERROR — $TARGET not found" >&2
  exit 1
fi

# Count lines matching ^func [a-z] (public function declarations).
# "func _" (private) and "static func _" (private static) are excluded by the [a-z] pattern.
# "static func" with a public name IS a public API — resolve() uses "static func resolve".
count=$(grep -cE "^(static )?func [a-z]" "$TARGET" || true)

if [ "$count" -eq 1 ]; then
  echo "AC-DC-33 sole-entry-point lint: OK — $TARGET has exactly 1 public func (resolve)."
  exit 0
else
  echo "AC-DC-33 sole-entry-point VIOLATION: $TARGET has $count public func declarations (expected 1)."
  echo "Public func lines found:"
  grep -nE "^(static )?func [a-z]" "$TARGET" || true
  echo
  echo "Fix: prefix all non-resolve functions with _ to mark them private."
  exit 1
fi
