#!/usr/bin/env bash
# tools/ci/lint_battle_scene_sprint6_mock_marker.sh
#
# battle_scene_sprint6_mock_marker_must_exist forbidden_pattern enforcement
# (ADR-0016 §4 + TR-battle-scene-wiring-004 + TR-battle-scene-wiring-010).
#
# src/feature/battle_scene/battle_scene.gd MUST contain all 4 marker substrings:
#   "# === SPRINT-6 MOCK ENCOUNTER ==="
#   "# === END MOCK ==="
#   "# === SPRINT-6 MOCK ENCOUNTER HELPERS ==="
#   "# === END SPRINT-6 MOCK ENCOUNTER HELPERS ==="
# These markers bracket the inline mock encounter loader region in _ready()
# and the 4 mock helper methods. Sprint-7+ deletion is mechanical: delete content
# between markers + delete this lint OR flip it to "MUST NOT exist" semantic.
#
# *** SEMANTIC FLIPS AT ADR-0017 ACCEPTANCE ***
# Sprint-7+ (post-ADR-0017): change the loop body to FAIL when any marker is
# FOUND (i.e., the mock encounter region must be FORBIDDEN per Migration Plan §1
# deletion checklist). Same patch as ADR-0017 acceptance includes the lint flip.
#
# Exit 0: all 4 markers present (sprint-6 clean)
# Exit 1: any of the 4 markers missing
set -euo pipefail
TARGET="src/feature/battle_scene/battle_scene.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi

REQUIRED_MARKERS=(
    "# === SPRINT-6 MOCK ENCOUNTER ==="
    "# === END MOCK ==="
    "# === SPRINT-6 MOCK ENCOUNTER HELPERS ==="
    "# === END SPRINT-6 MOCK ENCOUNTER HELPERS ==="
)

FAILED=0
for marker in "${REQUIRED_MARKERS[@]}"; do
    if ! grep -F -q "$marker" "$TARGET"; then
        echo "FAIL: $TARGET missing marker: $marker"
        FAILED=1
    fi
done

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi

echo "PASS: $TARGET contains all 4 SPRINT-6 mock markers (will flip semantic at ADR-0017 acceptance)"
exit 0
