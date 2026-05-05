#!/usr/bin/env bash
# tools/ci/lint_battle_scene_sprint6_mock_marker.sh
#
# battle_scene_sprint6_mock_marker_must_NOT_exist forbidden_pattern enforcement
# (PHASE-FLIPPED 2026-05-05 per ADR-0017 acceptance + Migration Plan §1).
#
# *** SEMANTIC FLIPPED 2026-05-05 ***
# This lint previously asserted that the 4 sprint-6 mock-encounter markers
# MUST EXIST in src/feature/battle_scene/battle_scene.gd. After ADR-0017
# ScenarioRunner ships and the mock encoder is DELETED, the inverse is true:
# any of the 4 markers re-appearing in source is now a regression and MUST FAIL.
#
# This is the project's 1st-precedent phase-flipping lint pattern: same script
# file, opposite semantic, atomically flipped at the ADR-0017 acceptance commit
# alongside the source deletion.
#
# Forbidden marker substrings:
#   "# === SPRINT-6 MOCK ENCOUNTER ==="
#   "# === END MOCK ==="
#   "# === SPRINT-6 MOCK ENCOUNTER HELPERS ==="
#   "# === END SPRINT-6 MOCK ENCOUNTER HELPERS ==="
#
# Exit 0: NO marker found (clean post-sprint-7 state)
# Exit 1: ANY marker present (regression — mock encoder must remain deleted)
set -euo pipefail
TARGET="src/feature/battle_scene/battle_scene.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi

FORBIDDEN_MARKERS=(
    "# === SPRINT-6 MOCK ENCOUNTER ==="
    "# === END MOCK ==="
    "# === SPRINT-6 MOCK ENCOUNTER HELPERS ==="
    "# === END SPRINT-6 MOCK ENCOUNTER HELPERS ==="
)

FAILED=0
for marker in "${FORBIDDEN_MARKERS[@]}"; do
    if grep -F -q "$marker" "$TARGET"; then
        echo "FAIL: $TARGET contains forbidden marker: $marker"
        echo "  (sprint-6 mock encoder was DELETED at ADR-0017 acceptance — must NOT return)"
        FAILED=1
    fi
done

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi

echo "PASS: $TARGET contains no SPRINT-6 mock-encounter markers (post-mock-deletion state preserved)"
exit 0
