#!/usr/bin/env bash
# tools/ci/lint_story_event_invalid_gate_first.sh
#
# story_event_invalid_gate_first forbidden_pattern enforcement
# (design/gdd/story-event.md §CR-SE-12 — D1 BLOCKING per destiny-branch.md rev 1.2 D1).
#
# CR-SE-12 mandates: in `_on_destiny_branch_chosen(choice)`, the `is_invalid`
# guard MUST run BEFORE any other DestinyBranchChoice field access. The
# `DestinyBranchChoice.invalid()` factory sets `outcome = LOSS` as enum default
# — reading `outcome` before `is_invalid` would silently process a corrupt
# path as a genuine LOSS with no runtime error.
#
# Lint algorithm: extract the body of `_on_destiny_branch_chosen` (awk-scoped).
# In that body, the FIRST line accessing `choice.<field>` MUST be the
# `is_invalid` check (`choice.is_invalid` or `not choice.is_invalid`).
# Any earlier access to choice.outcome/chapter_id/branch_key/echo_count/
# is_draw_fallback/is_canonical_history/reserved_color_treatment FAILS.
#
# Scan-set: production source files only.
#
# Exit 0: PASS (invalid-gate is the first choice.<field> access)
# Exit 1: FAIL (D1 BLOCKING contract violated)
set -euo pipefail

TARGET="src/feature/story_event/story_event.gd"

if [ ! -f "$TARGET" ]; then
    echo "PASS: $TARGET not yet implemented (skip — pre-S8-09 baseline)"
    exit 0
fi

# Awk extracts the body of _on_destiny_branch_chosen function (from `func _on_destiny_branch_chosen`
# through the next top-level `func ` or end-of-file).
BODY=$(awk '
    /^func _on_destiny_branch_chosen\(/ { inside=1; next }
    inside && /^func / { inside=0 }
    inside { print }
' "$TARGET")

if [ -z "$BODY" ]; then
    echo "PASS: $TARGET does not yet declare _on_destiny_branch_chosen (skip)"
    exit 0
fi

# Find the FIRST line containing `choice.` access (skipping comments).
FIRST_ACCESS=$(printf '%s\n' "$BODY" | grep -nE 'choice\.' | grep -Ev ':[[:space:]]*#' | head -n 1 || true)

if [ -z "$FIRST_ACCESS" ]; then
    echo "PASS: $TARGET _on_destiny_branch_chosen has no choice.<field> access (vacuous)"
    exit 0
fi

# The first access MUST be is_invalid (or `choice == null` / null check, which is OK before is_invalid).
# Acceptable patterns: `choice.is_invalid`, `not choice.is_invalid`, `choice == null`.
if printf '%s\n' "$FIRST_ACCESS" | grep -qE 'choice\.is_invalid|choice == null|choice != null'; then
    echo "PASS: $TARGET _on_destiny_branch_chosen invalid-gate is FIRST choice.<field> access (D1 BLOCKING preserved)"
    exit 0
fi

echo "FAIL: $TARGET _on_destiny_branch_chosen reads choice.<field> BEFORE is_invalid guard — D1 BLOCKING per CR-SE-12 violated:"
echo "  First access: $FIRST_ACCESS"
echo "  (DestinyBranchChoice.invalid() sets outcome=LOSS as enum default;"
echo "   reading outcome before is_invalid silently misclassifies a corrupt"
echo "   path as defeat. Per destiny-branch.md rev 1.2 D1 BLOCKING contract.)"
exit 1
