#!/usr/bin/env bash
# tools/ci/lint_battle_hud_no_hardcoded_strings.sh
#
# battle_hud_hardcoded_localized_strings forbidden_pattern enforcement
# (TR-battle-hud-012; ADR-0015 R-10 + technical-preferences.md i18n via tr()
# obligation + design/ux/battle-hud.md locale keys).
#
# All visible strings in HUD source code MUST route through tr(key) Godot
# localization function. Korean/English literal strings = build fail.
#
# Lint patterns enforced:
#   1. .text = "..." with non-empty literal RHS
#   2. .tooltip_text = "..." with non-empty literal RHS (same regex match)
#   3. set_text("...") with non-empty literal arg
#
# Whitelist (allowed patterns):
#   - text = "" / set_text("") (empty string)
#   - text = tr(...) / set_text(tr(...)) (tr() call — RHS not a literal)
#   - text = <identifier> (constant name; lint regex requires quoted RHS)
#   - text = "<format-spec>" — strings containing %d / %s / %f / %.Xf format
#     specifiers per story-008 spec ("format placeholders (%d HP, %s patterns)")
#   - text = "<escape-only>" — strings that are purely escape sequences
#     (e.g., `"\n"` as join separator); not localized prose
#   - text = "..." . join(...) — string used as separator for Array.join,
#     not as localized content
#   - push_error / push_warning calls (debug-only diagnostics)
#
# First dedicated i18n lint in the project; establishes precedent for future
# UI ADRs (Battle Results polish / Tutorial overlay / Settings panel /
# Localization UI).
#
# Exit 0: zero non-whitelisted hardcoded strings
# Exit 1: any non-whitelisted hardcoded string found
set -euo pipefail
TARGET_DIR="src/feature/battle_hud"
if [ ! -d "$TARGET_DIR" ]; then
    echo "FAIL: target dir missing: $TARGET_DIR"
    exit 1
fi

# Find all files in the target dir
FILES=$(find "$TARGET_DIR" -name '*.gd' -type f)
VIOLATIONS=""

for f in $FILES; do
    # Stage 1: catch text = "..." OR set_text("...") with NON-EMPTY literal.
    # Use grep -nE to get line numbers; -o would lose context.
    HITS=$(grep -nE 'text[[:space:]]*=[[:space:]]*"[^"]+"|set_text\("[^"]+"\)' "$f" || true)
    [ -z "$HITS" ] && continue

    # Stage 2: filter out whitelisted patterns.
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        # Whitelist 1: format-specifier strings (contain %d, %s, %f, %.Xf)
        if echo "$line" | grep -qE '%[dsf]|%\.[0-9]+f'; then
            continue
        fi
        # Whitelist 2: push_error / push_warning calls
        if echo "$line" | grep -qE 'push_(error|warning)\('; then
            continue
        fi
        # Whitelist 3: comments only (line starts with optional whitespace + #)
        if echo "$line" | grep -qE '^[0-9]+:[[:space:]]*#'; then
            continue
        fi
        # Whitelist 4: escape-only strings (e.g., `"\n"` newline separator).
        # Match `"\X"` where X is any single escape char.
        if echo "$line" | grep -qE 'text[[:space:]]*=[[:space:]]*"\\[a-z]"|set_text\("\\[a-z]"\)'; then
            continue
        fi
        # Whitelist 5: separator usage — string immediately followed by .join(
        if echo "$line" | grep -qE '"[^"]+"\.join\('; then
            continue
        fi
        VIOLATIONS="$VIOLATIONS$f:$line
"
    done <<< "$HITS"
done

if [ -n "$VIOLATIONS" ]; then
    echo "FAIL: BattleHUD source contains hardcoded localized strings (battle_hud_hardcoded_localized_strings):"
    printf "%s" "$VIOLATIONS"
    echo ""
    echo "Fix: route through tr(&\"key\") with the key declared in locale .po/.csv files."
    echo "Whitelist exemptions: empty strings, format-spec strings (%d/%s/%f), push_error/push_warning."
    exit 1
fi

echo "PASS: BattleHUD source has 0 hardcoded localized strings (TR-battle-hud-012)"
exit 0
