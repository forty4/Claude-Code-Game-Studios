#!/usr/bin/env bash
# Lint: every action declared in InputRouter's ACTIONS_BY_CATEGORY["grid"]
# vocabulary must appear as a match arm in at least one `_handle_action_in_sN`
# body — otherwise the action falls through every arm, `_did_visible_work`
# stays false, and the emit gate at `_handle_action` epilogue silently drops
# the press (per G-32 in .claude/rules/godot-4x-gotchas.md).
#
# This catches the exact S86 trap pattern: `use_skill` + `defend_stance` were
# declared in vocabulary, bound in default_bindings.json, matched at InputMap
# level (logs showed MATCH), but had no per-state arm — every press dropped
# silently and the controller never saw it. 3 hours of debugging cost.
#
# Exit codes:
#   0 — PASS (every grid action has at least one arm in some state)
#   1 — FAIL (one or more grid actions missing from every arm body)
#   2 — invocation error (source file missing or vocabulary unparseable)
#
# TG-3 NOTE: the awk extraction uses the flag/next pattern (NOT range pattern)
# because section boundaries (`}` for Dictionary close, `]` for Array close)
# match the start line pattern too — range would self-close on entry.

set -euo pipefail

INPUT_ROUTER="src/foundation/input_router.gd"

if [[ ! -f "$INPUT_ROUTER" ]]; then
    echo "FAIL: $INPUT_ROUTER not found (working dir: $(pwd))" >&2
    exit 2
fi

# ── Step 1: extract the grid action vocabulary ─────────────────────────────
# Source of truth: ACTIONS_BY_CATEGORY["grid"] entry. Multi-line value;
# flag/next state machine reads from `&"grid": [` to the matching `],`.
GRID_VOCABULARY=$(awk '
    /^const ACTIONS_BY_CATEGORY/{in_dict=1; next}
    in_dict && /^}/{in_dict=0; exit}
    in_dict && /^[[:space:]]+&"grid":[[:space:]]*\[/{in_grid=1; next}
    in_grid && /^[[:space:]]+\],/{in_grid=0; next}
    in_grid {print}
' "$INPUT_ROUTER" | grep -oE '&"[a-z_]+"' | sed 's/&"//;s/"//' | sort -u)

if [[ -z "$GRID_VOCABULARY" ]]; then
    echo "FAIL: ACTIONS_BY_CATEGORY[\"grid\"] vocabulary not found or empty" >&2
    echo "      Expected canonical anchor: 'const ACTIONS_BY_CATEGORY' + '&\"grid\": ['" >&2
    exit 2
fi

GRID_COUNT=$(echo "$GRID_VOCABULARY" | wc -w | tr -d ' ')

# ── Step 2: extract action references inside _handle_action_in_sN bodies ───
# Match arms are recognized by `&"<action_name>"` inside function bodies named
# `_handle_action_in_s<digit>`. Comments + const declarations are excluded by
# the in_arm flag (which only flips inside a function body).
ARM_REFERENCES=$(awk '
    /^func _handle_action_in_s[0-9]/{in_arm=1; next}
    /^func /{in_arm=0}
    in_arm {print}
' "$INPUT_ROUTER" | grep -oE '&"[a-z_]+"' | sed 's/&"//;s/"//' | sort -u)

# ── Step 3: diff vocabulary against arm references ─────────────────────────
# Documented exceptions: actions that are intentionally vocabulary-registered
# but not state-dispatched. Add new exceptions ONLY with cross-ref to the
# design comment in input_router.gd justifying the absence.
#
#   - grid_hover: PC-only synthesized via mouse-move (CR-1c). Not key-bound;
#     not dispatched through _handle_action_in_sN. Referenced in vocabulary
#     for R-5 parity count + camera/hover subscriber routing.
KNOWN_EXCEPTIONS=("grid_hover")

is_known_exception() {
    local needle="$1"
    for known in "${KNOWN_EXCEPTIONS[@]}"; do
        [[ "$needle" == "$known" ]] && return 0
    done
    return 1
}

MISSING=()
while IFS= read -r action; do
    [[ -z "$action" ]] && continue
    if is_known_exception "$action"; then
        continue
    fi
    if ! echo "$ARM_REFERENCES" | grep -qx "$action"; then
        MISSING+=("$action")
    fi
done <<< "$GRID_VOCABULARY"

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "FAIL — per G-32 (.claude/rules/godot-4x-gotchas.md):"
    echo ""
    echo "The following ACTIONS_BY_CATEGORY[\"grid\"] entries have NO match arm"
    echo "in any _handle_action_in_sN body. The input_action_fired emit gate"
    echo "at _handle_action epilogue will silently drop every press of these"
    echo "actions — subscribers (controller, HUD) will never see them."
    echo ""
    for action in "${MISSING[@]}"; do
        echo "  - $action"
    done
    echo ""
    echo "Fix: add &\"<action>\": arm with _did_visible_work = true to the"
    echo "relevant state arm(s) in $INPUT_ROUTER. Reference fix:"
    echo "  - input_router.gd:1005-1011  (S0 use_skill/defend_stance — S86)"
    echo "  - input_router.gd:1063-1071  (S1 use_skill/defend_stance — S86)"
    echo ""
    echo "If the action is intentionally vocabulary-only (no state dispatch),"
    echo "remove it from ACTIONS_BY_CATEGORY[\"grid\"] OR add an explicit"
    echo "no-op arm with a comment explaining the design."
    exit 1
fi

echo "PASS — all $GRID_COUNT grid action(s) declared in ACTIONS_BY_CATEGORY[\"grid\"]"
echo "       appear in at least one _handle_action_in_sN match arm."
exit 0
