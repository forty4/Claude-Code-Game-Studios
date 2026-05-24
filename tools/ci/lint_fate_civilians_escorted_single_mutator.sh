#!/usr/bin/env bash
# tools/ci/lint_fate_civilians_escorted_single_mutator.sh
#
# civilian_escorted_counter_direct_mutation forbidden_pattern enforcement
# (ADR-0022 §4 #3 + §Verification Required #6 + Risk R-3 mitigation).
#
# `_fate_civilians_escorted` is the single source-of-truth for the ch05 ★
# trigger (`WIN_xinye_civilians_saved`). Per ADR-0022 §1 + §2 the SOLE mutator
# is GridBattleController._civilian_commit_save(token_id). Direct mutation
# elsewhere (`= ` / `+= ` / `-= `) would silently drift the counter from the
# civilian state machine, making the ★ trigger non-deterministic.
#
# Allowed sites:
#   - `var _fate_civilians_escorted: int = 0` declaration  (regex excludes — `:` between name and `=`)
#   - reads (emit / dict snapshot / equality compare)       (regex excludes — `[^=]|$` after `=`)
#   - mutation inside `_civilian_commit_save()` body only   (function-scope allow-list)
#
# Lint scope:
#   src/feature/grid_battle/grid_battle_controller.gd
#
# Pattern: AST-shape (function-body scope) — bash regex alone insufficient.
# Uses awk function-scope tracking (TG-3 family — cross-ref `lint_emulate_mouse_from_touch.sh`
# + `lint_input_router_g15_reset.sh` for the flag/next family pattern this is built on).
#
# Exit 0: PASS. Exit 1: FAIL.
set -euo pipefail

TARGET="src/feature/grid_battle/grid_battle_controller.gd"

if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi

# awk single-pass function-scope tracker.
# - On every line matching `^func <name>(`, capture <name> as cur_func.
# - On every line matching the mutation regex, check cur_func.
# - Mutation regex `_fate_civilians_escorted[[:blank:]]*[-+]?=([^=]|$)`:
#     - matches `= `, `+= `, `-= ` after the symbol
#     - rejects `==` (equality) via [^=] / line-end alternation
#     - rejects declaration `var _fate_civilians_escorted: int = 0` (colon between)
#     - rejects reads (`,` / `)` / etc. after the symbol)
# - Module-level (cur_func == "") mutations are flagged (defensive — should
#   be impossible since instance fields can't be assigned at module scope,
#   but the lint stays correct under any future refactor).
RESULT=$(awk '
/^func[[:space:]]+/ {
    line = $0
    sub(/^func[[:space:]]+/, "", line)
    sub(/\(.*/, "", line)
    cur_func = line
    next
}
/_fate_civilians_escorted[[:blank:]]*[-+]?=([^=]|$)/ {
    if (cur_func != "_civilian_commit_save") {
        ctx = (cur_func == "" ? "<module>" : cur_func "()")
        printf "  %s:%d  [%s]  %s\n", FILENAME, NR, ctx, $0
        fail = 1
    }
}
END { exit fail }
' "$TARGET") || AWK_FAIL=$?

if [ "${AWK_FAIL:-0}" -ne 0 ]; then
    echo "FAIL: $TARGET mutates _fate_civilians_escorted outside _civilian_commit_save()"
    echo "      ADR-0022 §4 #3 / R-3 single source-of-truth lock violated:"
    echo "$RESULT"
    echo "      _civilian_commit_save(token_id) is the SOLE allowed mutator."
    exit 1
fi

echo "PASS: $TARGET — _fate_civilians_escorted mutated only inside _civilian_commit_save() (ADR-0022 §4 #3)"
exit 0
