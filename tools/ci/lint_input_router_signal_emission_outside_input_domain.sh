#!/usr/bin/env bash
# tools/ci/lint_input_router_signal_emission_outside_input_domain.sh
#
# Enforces TR-input-handling-017: InputRouter is the SOLE emitter of 3
# input-domain GameBus signals (input_action_fired / input_state_changed /
# input_mode_changed) and emits ZERO other GameBus signals. Subscriptions
# (`.connect()`) to OTHER signals (e.g. ui_input_block_requested) are allowed
# per ADR-0002 — only emit calls are restricted.
#
# Lint distinguishes emit vs subscribe by matching the literal `.emit(` suffix.
#
# Exit 0: only allowed input-domain emits found
# Exit 1: any GameBus.X.emit() call where X is NOT in the 3-signal allowlist
#
# Usage:   bash tools/ci/lint_input_router_signal_emission_outside_input_domain.sh
# CI:      wired in story-010 (.github/workflows/tests.yml)
# ADR ref: docs/architecture/ADR-0005-input-handling.md §1 + TR-input-handling-017
#
# Allowed input-domain signals:
#   - input_action_fired
#   - input_state_changed
#   - input_mode_changed
#
# Synthesized signal-actions (`magnifier_open`, `panel_reposition_request`,
# `camera_pinch_zoom`, `camera_two_finger_tap_cancel`) are emitted via
# `input_action_fired` and ARE allowed — they reuse the input_action_fired
# emit channel rather than introducing new signals.

set -euo pipefail

FILE="src/foundation/input_router.gd"

if [ ! -f "$FILE" ]; then
    echo "ERROR: $FILE not found. Run from the project root."
    exit 1
fi

# Find ALL GameBus.X.emit() call sites
ALL_EMITS=$(grep -nE 'GameBus\.[a-zA-Z_]+\.emit\(' "$FILE" || true)

# Filter OUT the 3 allowed input-domain signals
FORBIDDEN=$(echo "$ALL_EMITS" | grep -vE 'GameBus\.(input_action_fired|input_state_changed|input_mode_changed)\.emit\(' || true)

if [ -n "$FORBIDDEN" ]; then
    echo "::error::InputRouter emits non-input-domain GameBus signals (TR-input-handling-017 violation):"
    echo "$FORBIDDEN"
    echo ""
    echo "InputRouter MUST only emit on input_action_fired / input_state_changed / input_mode_changed."
    echo "Synthesized signal-actions (magnifier_open, etc.) reuse input_action_fired — they are allowed."
    exit 1
fi

echo "lint_input_router_signal_emission_outside_input_domain PASS"
