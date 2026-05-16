#!/usr/bin/env bash
# tools/ci/lint_outcome_stringname_coverage.sh
#
# Prevents the S36 bug class: production code that dispatches on the battle-
# outcome StringName must cover ALL 8 emitted values, not just the original
# ANNIHILATION-only set.
#
# Background: pre-S36 the BattleHUD results-panel OutcomeLabel match arms
# only matched VICTORY_ANNIHILATION / DEFEAT_ANNIHILATION / TURN_LIMIT_
# REACHED — the original ANNIHILATION-only set. The 5 outcome StringNames
# added by S28 / S30 / S31 (VICTORY_SURVIVE, VICTORY_ESCORT, VICTORY_REACH_
# TILE, DEFEAT_ESCORT_LOST, DEFEAT_REACH_FAILED) silently fell through to
# the default — a winning ESCORT battle displayed "DRAW" on the stats sheet.
# Same class of bug as the historical lowercase &"victory" arms the file
# comment already documented. S36 fixed the HUD; S37 backfilled tests.
# This lint codifies the invariant going forward.
#
# Heuristic: any production src/ file that mentions BOTH VICTORY_ANNIHILATION
# AND DEFEAT_ANNIHILATION is presumed to be a dispatcher / consumer that
# should be complete. It must also mention all 5 newer outcome StringNames.
#
# A file that only mentions one side (e.g., outcome_was_win checks only
# VICTORY_*) correctly skips the lint — single-side files are NOT
# dispatchers.
#
# Exit 0: every flagged file mentions all 8 outcome StringNames
# Exit 1: at least one flagged file is missing one or more newer outcomes
#
# Usage:   bash tools/ci/lint_outcome_stringname_coverage.sh
# CI:      not yet wired (sprint-15+ candidate per active.md S37 close-out)

set -euo pipefail

SRC_DIR="src"

if [ ! -d "$SRC_DIR" ]; then
    echo "ERROR: $SRC_DIR/ not found. Run from the project root."
    exit 1
fi

# Outcome StringNames emitted by GridBattleController._emit_battle_outcome.
# Mirrors src/core/payloads/victory_conditions.gd ConditionType + the
# DEFEAT_*/VICTORY_* StringName set wired in S28 / S30 / S31. Update this
# list when a new outcome StringName is added (and add a match arm to every
# file flagged by this lint).
ANCHOR_VICTORY="VICTORY_ANNIHILATION"
ANCHOR_DEFEAT="DEFEAT_ANNIHILATION"
NEWER_OUTCOMES=(
    "VICTORY_SURVIVE"
    "VICTORY_ESCORT"
    "VICTORY_REACH_TILE"
    "DEFEAT_ESCORT_LOST"
    "DEFEAT_REACH_FAILED"
)

# Find all .gd files that contain BOTH anchors (dispatcher-shaped files).
# Use literal grep -F (anchors have no regex metacharacters).
# G-7 hardening: if no files match, mapfile produces an empty array; the
# loop body simply doesn't execute. PASS exit holds.
CANDIDATES=()
while IFS= read -r -d '' f; do
    if grep -qF "$ANCHOR_VICTORY" "$f" && grep -qF "$ANCHOR_DEFEAT" "$f"; then
        CANDIDATES+=("$f")
    fi
done < <(find "$SRC_DIR" -type f -name "*.gd" -print0)

FAIL=0
for f in "${CANDIDATES[@]}"; do
    MISSING=()
    for token in "${NEWER_OUTCOMES[@]}"; do
        if ! grep -qF "$token" "$f"; then
            MISSING+=("$token")
        fi
    done
    if [ "${#MISSING[@]}" -gt 0 ]; then
        echo "::error file=$f::outcome StringName coverage gap"
        echo "  $f mentions both $ANCHOR_VICTORY and $ANCHOR_DEFEAT but is missing:"
        for t in "${MISSING[@]}"; do
            echo "    - $t"
        done
        echo "  S36 bug class: dispatchers / consumers that handle both sides must cover all 8 outcomes."
        echo "  Add the missing arms or, if the omission is intentional, restructure to remove one of the anchors."
        FAIL=1
    fi
done

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi

echo "lint_outcome_stringname_coverage PASS — ${#CANDIDATES[@]} file(s) cover all 8 outcome StringNames"
