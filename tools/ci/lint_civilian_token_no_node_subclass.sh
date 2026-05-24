#!/usr/bin/env bash
# tools/ci/lint_civilian_token_no_node_subclass.sh
#
# civilian_token_node_subclass forbidden_pattern enforcement
# (ADR-0022 §4 #1 + §Verification Required #4).
#
# CivilianToken MUST extend RefCounted ONLY — Node / Node2D / Control /
# CanvasItem subclassing is forbidden. RefCounted is the correct base because
# the entity is a pure data object with a 3-state machine, NO scene-tree
# presence required, NO signals, NO lifecycle hooks. A Node subclass would
# add lifecycle complexity for zero benefit + would couple entity state with
# visualization (which is a separate sibling Node per spec §4.3).
#
# Exit 0: PASS. Exit 1: FAIL.
set -euo pipefail

TARGET="src/feature/grid_battle/civilian_token.gd"

if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi

# Forbid extends Node / Node2D / Control / CanvasItem (any whitespace prefix).
# RefCounted is the ONLY allowed base.
if matches=$(grep -En '^[[:space:]]*extends[[:space:]]+(Node|Node2D|Control|CanvasItem)([[:space:]]|$)' "$TARGET" || true); then
    if [ -n "$matches" ]; then
        echo "FAIL: $TARGET extends a Node-family class — ADR-0022 §4 #1 violated:"
        echo "$matches"
        echo "CivilianToken MUST 'extends RefCounted' only (data-object discipline)."
        exit 1
    fi
fi

# Positive assertion: extends RefCounted must be present (catches accidental
# rename / decorator-only edits that strip the base entirely).
if ! grep -qE '^[[:space:]]*extends[[:space:]]+RefCounted([[:space:]]|$)' "$TARGET"; then
    echo "FAIL: $TARGET missing 'extends RefCounted' — ADR-0022 §4 #1 baseline absent"
    exit 1
fi

echo "PASS: $TARGET extends RefCounted only (ADR-0022 §4 #1)"
exit 0
