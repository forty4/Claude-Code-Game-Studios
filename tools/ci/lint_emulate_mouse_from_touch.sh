#!/usr/bin/env bash
# tools/ci/lint_emulate_mouse_from_touch.sh
#
# Enforces R-3 / CR-2e per ADR-0005 §Verification Required §3:
# `project.godot` MUST set `emulate_mouse_from_touch=false` in the
# `[input_devices.pointing]` section. Without this, touch events synthesize
# fake mouse events that double-fire the same action via two dispatch paths
# (real screen_touch + synthesized mouse_button), corrupting input semantics.
#
# Lint scope: project.godot section [input_devices.pointing] presence + the
# emulate_mouse_from_touch=false line.
#
# Exit 0: section + setting both present
# Exit 1: section missing OR setting !=false OR setting absent
#
# Usage:   bash tools/ci/lint_emulate_mouse_from_touch.sh
# CI:      wired in story-010 (.github/workflows/tests.yml)
# ADR ref: docs/architecture/ADR-0005-input-handling.md §Verification Required §3 + CR-2e + R-3

set -euo pipefail

FILE="project.godot"

if [ ! -f "$FILE" ]; then
    echo "ERROR: $FILE not found. Run from the project root."
    exit 1
fi

# Extract [input_devices.pointing] section content. The flag/next pattern
# avoids the awk range-pattern self-close trap (the start-line also matches
# `^\[`, which would otherwise close the range on entry — discovered S9-05).
SECTION=$(awk '/^\[input_devices\.pointing\]/{flag=1; next} /^\[/{flag=0} flag' "$FILE")

if [ -z "$SECTION" ]; then
    echo "::error::project.godot missing [input_devices.pointing] section (R-3 / CR-2e violation)"
    echo "Add the section + emulate_mouse_from_touch=false setting per ADR-0005 §3."
    exit 1
fi

if ! echo "$SECTION" | grep -qE '^emulate_mouse_from_touch[[:space:]]*=[[:space:]]*false'; then
    echo "::error::project.godot [input_devices.pointing] missing 'emulate_mouse_from_touch=false' (R-3 / CR-2e violation)"
    echo "Found section, but the false-valued setting is absent. Without it, touch events double-fire as fake mouse events."
    exit 1
fi

echo "lint_emulate_mouse_from_touch PASS"
