#!/usr/bin/env bash
# lint_foundation_balance_no_hardcoded_constants.sh
#
# TR-balance-data-010 (foundation-layer scope) — verify no hardcoded
# balance-constant declarations in src/foundation/ consumer .gd files
# (excluding balance_constants.gd which IS the source-of-truth and therefore
# allow-listed).
#
# Per balance-data/story-003 AC-3: extends AC-DC-48 lint precedent
# (tools/ci/lint_damage_calc_no_hardcoded_constants.sh) to foundation-layer
# scope. Instantiated from tools/ci/lint_no_hardcoded_balance_constants.sh.template
# (Approach B per story-003 AC-1).
#
# Current foundation-layer consumers (verified 2026-05-01):
#   - src/foundation/unit_role.gd (uses BalanceConstants.get_const for
#     class-direction tables per ADR-0009)
#   - src/foundation/hero_data.gd (Resource wrapper; no BalanceConstants refs
#     currently — passes trivially as long as no const X = ... declarations
#     are added that match watched names)
#
# Allow-listed (NOT scanned):
#   - src/foundation/balance/balance_constants.gd — IS the source-of-truth
#     file by definition; contains the constants this lint forbids elsewhere.
#     Excluded via --exclude-dir="balance".
#
# Future consumers added under src/foundation/ (e.g. hp-status, turn-order
# epics if their modules land here) will be auto-included if their .gd files
# declare any of the watched constants.
#
# ## Exit codes (story-008 codified)
#
#   0  — clean (no hardcoded const declarations found)
#   1  — domain failure: violation found (prints offending lines; CI fails)
#   ≥2 — tool failure: lint infrastructure error (e.g., grep crash, missing dir)
#
# Usage: bash tools/ci/lint_foundation_balance_no_hardcoded_constants.sh

set -euo pipefail

TARGET_DIR="src/foundation"

if [ ! -d "$TARGET_DIR" ]; then
  echo "ERROR: $TARGET_DIR/ not found. Run from the project root." >&2
  exit 2
fi

# Constant names this lint forbids in foundation-layer consumers (Option β
# per balance-data/story-003 — hardcoded subset). Mirrors damage_calc lint's
# original 12 + ADR-0010 (HP_*) + ADR-0011 (INIT_*) + map-grid (MOVE_*)
# same-patch appends. Source-of-truth: assets/data/balance/balance_entities.json
# (verified 2026-05-01 — 18 scalar + 2 dict = 20 keys).
PATTERN="const (BASE_CEILING|MIN_DAMAGE|ATK_CAP|DEF_CAP|DEFEND_STANCE_ATK_PENALTY|P_MULT_COMBINED_CAP|CHARGE_BONUS|AMBUSH_BONUS|DAMAGE_CEILING|COUNTER_ATTACK_MODIFIER|BASE_DIRECTION_MULT|CLASS_DIRECTION_MULT|HP_CAP|HP_SCALE|HP_FLOOR|INIT_CAP|INIT_SCALE|MOVE_RANGE_MIN|MOVE_RANGE_MAX|MOVE_BUDGET_PER_RANGE) "

# Scan all .gd files under src/foundation/ EXCEPT balance/balance_constants.gd
# (allow-listed source-of-truth). The `if grep -r ...; then` form correctly
# distinguishes domain-fail (exit 0 = match) from clean (exit 1 = no match);
# tool failures (exit ≥2) propagate via `set -euo pipefail`. See template
# header for the story-008 silent-fail antipattern guard explanation.
if grep -rnE "$PATTERN" "$TARGET_DIR" --include="*.gd" --exclude-dir="balance"; then
  echo "" >&2
  echo "FAIL: hardcoded balance constants found in $TARGET_DIR/ (TR-balance-data-010)." >&2
  echo "Move the literal value to assets/data/balance/balance_entities.json and" >&2
  echo "read it via BalanceConstants.get_const(\"KEY\") per ADR-0006 §Decision 7." >&2
  exit 1
fi

echo "PASS: no hardcoded balance constants in $TARGET_DIR/ (excluding balance/) (TR-balance-data-010)."
exit 0
