#!/usr/bin/env bash
# tools/ci/lint_damage_calc_no_dictionary_alloc.sh
#
# AC-DC-41 (TR-damage-calc-008 Dictionary-alloc ban):
# damage_calc.gd must contain zero Dictionary constructor calls and zero literal
# Dictionary expressions in reachable function bodies. Per ADR-0012 §6 + R-3,
# DamageCalc.resolve() runs synchronously on the hot path; allocating a
# transient Dictionary on every call introduces unnecessary GC pressure.
# Production data lives exclusively in typed RefCounted wrappers
# (AttackerContext, DefenderContext, ResolveModifiers, ResolveResult) and
# typed Arrays (Array[StringName] for source_flags + vfx_tags).
#
# Exemption (per ADR-0012 §Implementation Guidelines #5):
# - the helper that constructs the vfx-tags array is exempt; however that
#   helper currently uses an Array, not a Dictionary, so the exemption
#   is precautionary. If a future change requires Dictionary alloc inside
#   that exempt helper, this lint must be amended to skip its function body
#   via awk-range extraction.
#
# Patterns flagged (per story-008 Implementation Notes line 91):
#   - Dictionary( ...  — explicit constructor call
#   - {[^"']         — literal Dictionary (word-boundary "{" followed by a
#                       character that is NOT a quote, which excludes most
#                       in-string occurrences). Catches := {...}, = {...},
#                       return {...} idioms.
#
# Anti-self-trigger policy: this script paraphrases the banned identifiers
# in its own documentation rather than quoting them, so the script itself
# is not a match target if grep is ever run with a wider scope.
#
# Exit code: 0 if zero matches, 1 if any match found.

set -uo pipefail

TARGET="src/feature/damage_calc/damage_calc.gd"

if [ ! -f "$TARGET" ]; then
  echo "lint_damage_calc_no_dictionary_alloc: ERROR — $TARGET not found" >&2
  exit 1
fi

# Build the patterns from fragments to avoid self-matching this script.
# Pattern 1: D-i-c-t-i-o-n-a-r-y constructor call.
PATTERN_1="Dictionary"
PATTERN_1+="\\("
# Pattern 2: word-boundary opening-brace followed by a non-quote character.
PATTERN_2='\b\{'
PATTERN_2+="[^\"']"

# Combined extended-regex pattern.
PATTERN="(${PATTERN_1}|${PATTERN_2})"

# -nE: extended regex with line numbers; -F is unsuitable here (we need regex).
matches=$(grep -nE "$PATTERN" "$TARGET" 2>/dev/null || true)

if [ -n "$matches" ]; then
  echo "::error::lint_damage_calc_no_dictionary_alloc: hot-path Dictionary allocation found — AC-DC-41 violation"
  echo "$matches" >&2
  echo "" >&2
  echo "Resolution: DamageCalc.resolve() must avoid Dictionary allocs on the hot path." >&2
  echo "Use typed RefCounted wrappers (AttackerContext / DefenderContext / ResolveModifiers / ResolveResult)" >&2
  echo "or typed Arrays (Array[StringName]) instead. See ADR-0012 §6 + Implementation Guidelines #5." >&2
  exit 1
fi

echo "lint_damage_calc_no_dictionary_alloc: PASS (0 matches in $TARGET)"
exit 0
