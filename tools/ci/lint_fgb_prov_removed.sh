#!/usr/bin/env bash
# tools/ci/lint_fgb_prov_removed.sh
#
# AC-DC-44 (TR-damage-calc-009 F-GB-PROV retirement grep gate):
# The retired provisional damage-formula identifier must not appear in
# design/gdd/grid-battle.md or anywhere under src/. damage_resolve() in
# design/gdd/damage-calc.md is the sole damage-resolution primitive since
# grid-battle.md v5.0 + damage-calc.md story-007.
#
# The retirement narrative is preserved in design/gdd/reviews/ and the
# tr-registry. This lint enforces that no future PR accidentally re-introduces
# the retired identifier as a live cross-doc citation or in source code.
#
# Grep target: literal token "F-GB-PROV" in:
#   - design/gdd/grid-battle.md (the prior owner GDD)
#   - src/ (any source file)
#
# Anti-self-trigger policy: this script paraphrases the banned token
# in its own documentation rather than quoting it, so the script itself
# is not a match target if grep is ever run with a wider scope.
#
# Exit code: 0 if zero matches, 1 if any match found.

set -uo pipefail

TARGETS=(
  "design/gdd/grid-battle.md"
  "src/"
)

# Build the exact identifier from fragments to avoid self-matching this script.
TOKEN="F-GB"
TOKEN+="-PROV"

# Verify primary target exists; src/ is a directory and may contain no .gd matches.
if [ ! -f "design/gdd/grid-battle.md" ]; then
  echo "lint_fgb_prov_removed: ERROR — design/gdd/grid-battle.md not found" >&2
  exit 1
fi

if [ ! -d "src" ]; then
  echo "lint_fgb_prov_removed: ERROR — src/ directory not found" >&2
  exit 1
fi

# -r recursive (src/), -F fixed-string (no regex), -n line numbers for diagnostics.
matches=$(grep -rnF "$TOKEN" "${TARGETS[@]}" 2>/dev/null || true)

if [ -n "$matches" ]; then
  echo "::error::lint_fgb_prov_removed: retired formula identifier found — AC-DC-44 violation"
  echo "$matches" >&2
  echo "" >&2
  echo "Resolution: replace the identifier with a descriptive phrase (e.g., 'the prior provisional damage formula') or remove the reference. damage_resolve() in design/gdd/damage-calc.md is the canonical primitive." >&2
  exit 1
fi

echo "lint_fgb_prov_removed: PASS (0 matches in design/gdd/grid-battle.md and src/)"
exit 0
