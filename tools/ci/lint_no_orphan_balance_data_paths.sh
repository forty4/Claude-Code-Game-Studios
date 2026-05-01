#!/usr/bin/env bash
# tools/ci/lint_no_orphan_balance_data_paths.sh
#
# TR-balance-data-017 (file-rename verification + ADR-0006 §Validation §5):
# After balance-data ratification (ADR-0006 Accepted 2026-04-30 via /architecture-review
# delta #9) + foundation-layer relocation (story-001), two res:// URI forms must
# NOT appear in src/, tests/, or tools/:
#
#   1. Pre-relocation feature-layer URI (the OLD module path before story-001's
#      src/feature/balance/ -> src/foundation/balance/ move).
#
#   2. Pre-rename data URI (the OLD JSON filename before ADR-0006 §Decision 4's
#      [system]_[name].json rename to balance_entities.json).
#
# Allow-listed (NOT scanned):
#   - production/, design/, docs/ markdown -- historical references in completed
#     stories and migration narratives.
#   - This script itself -- anti-self-trigger via fragment concatenation; the
#     literal orphan URI never appears in source text.
#
# Anti-self-trigger policy: literal patterns are assembled from fragments at
# runtime (per lint_fgb_prov_removed.sh precedent).
#
# ## Exit codes (story-008 codified)
#
#   0  -- clean (no orphan URIs found)
#   1  -- domain failure: orphan URI reference found (prints offending lines; CI fails)
#   >=2 -- tool failure: lint infrastructure error (e.g., missing target dir)
#
# Usage: bash tools/ci/lint_no_orphan_balance_data_paths.sh

set -uo pipefail

TARGETS=(
  "src/"
  "tests/"
  "tools/"
)

for target in "${TARGETS[@]}"; do
  if [ ! -d "$target" ]; then
    echo "lint_no_orphan_balance_data_paths: ERROR -- $target/ not found" >&2
    exit 2
  fi
done

# Pattern 1 (pre-relocation URI) -- fragments avoid self-match.
P1_A="res://"
P1_B="src/"
P1_C="feature/"
P1_D="balance/"
PATTERN_FEATURE="${P1_A}${P1_B}${P1_C}${P1_D}"

# Pattern 2 (pre-rename URI) -- fragments avoid self-match.
P2_A="res://"
P2_B="assets/data/balance/"
P2_C="entities."
P2_D="json"
PATTERN_DATA="${P2_A}${P2_B}${P2_C}${P2_D}"

# -F fixed-string match. The post-rename URI res://assets/data/balance/balance_entities.json
# does NOT substring-contain the orphan pattern (the "balance_" infix is between
# "balance/" and "entities"), so no false-positive filter is needed.
matches_feature=$(grep -rnF "$PATTERN_FEATURE" "${TARGETS[@]}" 2>/dev/null || true)
matches_data=$(grep -rnF "$PATTERN_DATA" "${TARGETS[@]}" 2>/dev/null || true)

found=0
if [ -n "$matches_feature" ]; then
  echo "::error::lint_no_orphan_balance_data_paths: pre-relocation URI found -- TR-balance-data-017 violation"
  echo "$matches_feature" >&2
  echo "" >&2
  found=1
fi
if [ -n "$matches_data" ]; then
  echo "::error::lint_no_orphan_balance_data_paths: pre-rename data URI found -- TR-balance-data-017 violation"
  echo "$matches_data" >&2
  echo "" >&2
  found=1
fi

if [ $found -ne 0 ]; then
  echo "Resolution:" >&2
  echo "  - Replace pre-relocation URI fragment with res://src/foundation/balance/ (post-story-001 layer)." >&2
  echo "  - Replace pre-rename URI fragment with res://assets/data/balance/balance_entities.json (post-ADR-0006-§Decision-4 prefix)." >&2
  echo "Reference: ADR-0006 §Validation Criteria §5; balance-data story-001 (relocation); story-004 (this lint)." >&2
  exit 1
fi

echo "lint_no_orphan_balance_data_paths: PASS (0 orphan URIs in src/, tests/, tools/)"
exit 0
