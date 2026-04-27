#!/usr/bin/env bash
# tools/ci/lint_damage_calc_no_stub_copy.sh
#
# AC-DC-45 stub-copy guard (TR-damage-calc-010):
# src/feature/damage_calc/ must contain zero stub-copy phrases in quoted
# GDScript string literals. Patterns checked (case-insensitive):
#   not yet implemented | TODO | placeholder | stub
#
# Scope: all .gd files under src/feature/damage_calc/ (recursive).
# Exclusion: GDScript line comments — lines whose content (after the
#   grep filename:linenum: prefix) begins with optional whitespace then '#'.
#   TODOs in source comments are permitted; stub copy in user-facing string
#   literals is not — per AC-DC-45 rev 2.5 BLK-6-10 + WCAG 2.1 SC 4.1.3.
#
# Anti-self-trigger policy: this script paraphrases the banned phrases
# in its own documentation rather than quoting them verbatim in a way that
# would match the grep pattern if the scope were ever widened.
#
# Exit 0: clean (zero matches in string literals).
# Exit 1: violation found (prints offending file:line:content for each match).
#
# Usage: bash tools/ci/lint_damage_calc_no_stub_copy.sh

set -euo pipefail

TARGET_DIR="src/feature/damage_calc"

if [ ! -d "$TARGET_DIR" ]; then
  echo "ERROR: $TARGET_DIR not found. Run from the project root." >&2
  exit 1
fi

# Pass 1: extract quoted-string LITERALS only — output format
#   filename:linenum:"quoted content"
# This skips comment-portion text and bare identifiers/keywords entirely.
# The pattern matches double-quoted ("...") and single-quoted ('...') strings;
# escaped quotes inside string literals are not currently handled (acceptable
# for damage_calc/ where no error-message strings embed quotes).
# Pass 2: filter to lines whose extracted-string content matches a stub-copy
# phrase (case-insensitive).
# '|| true' prevents set -e from treating grep-no-match (exit 1) as failure.
matches=$(
  grep -rnoE \
    '"[^"]*"|'\''[^'\'']*'\''' \
    --include="*.gd" \
    "$TARGET_DIR" \
    | grep -iE "not yet implemented|TODO|placeholder|stub" \
    || true
)

if [ -n "$matches" ]; then
  echo "::error::lint_damage_calc_no_stub_copy: stub-copy phrase found in string literals — AC-DC-45 violation"
  echo "$matches" >&2
  echo "" >&2
  echo "Resolution: user-facing string literals in $TARGET_DIR must not contain" >&2
  echo "stub-copy phrases (not yet implemented / TODO / placeholder / stub)." >&2
  echo "GDScript line comments (# ...) are exempt. Per AC-DC-45 rev 2.5 BLK-6-10." >&2
  exit 1
fi

echo "lint_damage_calc_no_stub_copy: PASS (0 matches in $TARGET_DIR)"
exit 0
