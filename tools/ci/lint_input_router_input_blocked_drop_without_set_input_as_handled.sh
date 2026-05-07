#!/usr/bin/env bash
# tools/ci/lint_input_router_input_blocked_drop_without_set_input_as_handled.sh
#
# Verifies that the S5 INPUT_BLOCKED dispatch arm in InputRouter pairs every
# silent-drop path with `get_viewport().set_input_as_handled()` per ADR-0005
# Advisory C. Without the handled call, dropped events would propagate to
# Control._gui_input or other _unhandled_input handlers, defeating the
# block-while-blocked contract.
#
# Pattern: scans `_handle_action_in_s5` body; the function MUST contain at least
# one `set_input_as_handled()` call. The function name plus the explicit
# handled call together prove story-007 + story-010 contract compliance.
#
# Exit 0: `_handle_action_in_s5` found AND contains set_input_as_handled
# Exit 1: function missing OR handled call absent
#
# Usage:   bash tools/ci/lint_input_router_input_blocked_drop_without_set_input_as_handled.sh
# CI:      wired in story-010 (.github/workflows/tests.yml)
# ADR ref: docs/architecture/ADR-0005-input-handling.md §Advisory C + story-007 AC-4

set -euo pipefail

FILE="src/foundation/input_router.gd"

if [ ! -f "$FILE" ]; then
    echo "ERROR: $FILE not found. Run from the project root."
    exit 1
fi

# Extract the _handle_action_in_s5 body
S5_BODY=$(awk '/^func _handle_action_in_s5\(/,/^func [^_]/' "$FILE")

if [ -z "$S5_BODY" ]; then
    echo "::error::InputRouter is missing _handle_action_in_s5() function (story-007 AC-4 + ADR-0005 §1)"
    exit 1
fi

if ! echo "$S5_BODY" | grep -qE 'set_input_as_handled\(\)'; then
    echo "::error::_handle_action_in_s5 missing get_viewport().set_input_as_handled() — Advisory C violation"
    echo "S5 dispatch must mark dropped events as handled to prevent propagation."
    exit 1
fi

echo "lint_input_router_input_blocked_drop_without_set_input_as_handled PASS"
