#!/usr/bin/env bash
# tools/ci/lint_input_router_hardcoded_bindings.sh
#
# Enforces CR-1b: InputRouter MUST NOT hardcode input-event keycodes or
# button indices via direct enum-literal comparisons. All bindings come
# from `assets/data/input/default_bindings.json` via `_populate_input_map`.
# Runtime remap goes through `set_binding(action, event)` per ADR-0005 §Soft
# (4) — Settings/Options scene is the sole external caller.
#
# Forbidden patterns (comparison sites):
#   - `event.keycode == KEY_*`
#   - `event.button_index == MOUSE_BUTTON_*`
#   - `event.button_index == JOY_BUTTON_*`
#
# Allowed:
#   - bare `event.keycode` field reads in InputEventKey constructor calls
#     within `_construct_input_event` (loading from JSON to InputMap)
#   - any `KEY_*` / `MOUSE_BUTTON_*` reference inside doc comments
#
# Exit 0: no hardcoded comparison sites
# Exit 1: at least one `event.keycode == KEY_*` or `event.button_index == MOUSE_BUTTON_*` / JOY_BUTTON_* found
#
# Usage:   bash tools/ci/lint_input_router_hardcoded_bindings.sh
# CI:      wired in story-010 (.github/workflows/tests.yml)
# ADR ref: docs/architecture/ADR-0005-input-handling.md §CR-1b

set -euo pipefail

FILE="src/foundation/input_router.gd"

if [ ! -f "$FILE" ]; then
    echo "ERROR: $FILE not found. Run from the project root."
    exit 1
fi

FAILED=0

# Comparison sites: `== KEY_*` / `== MOUSE_BUTTON_*` / `== JOY_BUTTON_*`
# Strip comment lines to avoid false positives from doc-comment references.
NON_COMMENT=$(grep -vE '^[[:space:]]*##' "$FILE" || true)

KEY_HITS=$(echo "$NON_COMMENT" | grep -nE '==[[:space:]]*(KEY_[A-Z0-9_]+|MOUSE_BUTTON_[A-Z0-9_]+|JOY_BUTTON_[A-Z0-9_]+)' || true)

if [ -n "$KEY_HITS" ]; then
    echo "::error::InputRouter contains hardcoded keycode/button comparison (CR-1b violation):"
    echo "$KEY_HITS"
    echo ""
    echo "All bindings must come from assets/data/input/default_bindings.json."
    echo "Use InputMap.action_has_event(action, event) for runtime matching, NOT == comparisons."
    FAILED=$((FAILED + 1))
fi

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi

echo "lint_input_router_hardcoded_bindings PASS"
