#!/usr/bin/env bash
# tools/ci/lint_battle_hud_hidden_fate_non_subscription.sh
#
# battle_hud_subscribes_to_hidden_fate_signal forbidden_pattern enforcement
# (TR-battle-hud-004; ADR-0015 §Decision §8 + Engine Verification Item 7;
# CRITICAL — first pillar-anchored lint pattern in the project; KEEP forever).
#
# BattleHUD source MUST NOT contain the literal token
# `hidden_fate_condition_progressed`. ZERO tolerance — comments, variable names,
# .connect() calls, and string literals all trigger fail. Forces architects to
# use renamed references if discussing the topic.
#
# Justification: design/gdd/game-concept.md Pillar 2 (운명은 바꿀 수 있다 —
# Destiny Can Be Rewritten) ratifies that fate progress is HIDDEN from the
# player during battle. If HUD subscribes and renders any visual at Beat 6
# results screen, Pillar 2 contrast collapses.
#
# Build fail = Pillar 2 violation = three-doc revision required (this lint
# enforcement + ADR-0015 + destiny-branch.md + game-concept.md).
#
# Exit 0: zero matches (clean)
# Exit 1: any match (build fail — Pillar 2 violation)
set -euo pipefail
TARGET_DIR="src/feature/battle_hud"
if [ ! -d "$TARGET_DIR" ]; then
    echo "FAIL: target dir missing: $TARGET_DIR"
    exit 1
fi
set +e
COUNT=$(grep -rE -o 'hidden_fate_condition_progressed' "$TARGET_DIR" 2>/dev/null | wc -l | tr -d '[:space:]')
set -e
[ -z "$COUNT" ] && COUNT=0
if [ "$COUNT" -ne 0 ]; then
    echo "FAIL: BattleHUD source contains $COUNT 'hidden_fate_condition_progressed' references (Pillar 2 lock violation)"
    grep -rn 'hidden_fate_condition_progressed' "$TARGET_DIR"
    echo ""
    echo "Reason: design/gdd/game-concept.md Pillar 2 + design/gdd/destiny-branch.md Section B"
    echo "        ADR-0015 §Engine Verification Item 7 + TR-battle-hud-004"
    echo "If you genuinely need to surface fate progress, FIRST revise:"
    echo "  - ADR-0015 (Superseded-by)"
    echo "  - design/gdd/destiny-branch.md Section B"
    echo "  - design/gdd/game-concept.md Pillar 2"
    echo "Three coordinated revisions intentionally hard."
    exit 1
fi
echo "PASS: BattleHUD source contains 0 'hidden_fate_condition_progressed' references (Pillar 2 architectural lock holds)"
exit 0
