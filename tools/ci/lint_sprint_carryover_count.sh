#!/usr/bin/env bash
# lint_sprint_carryover_count.sh
#
# Codified sprint-12 S12-09 2026-05-09 (sprint-11 retro AI #5 optional automation candidate).
#
# WHAT: For the latest production/sprints/sprint-N.md, count rows in the Carryover
# Backlog table. Cross-verify against the sprint-(N-1) retro's "Carryover concentration
# into sprint-N" forecast count when extractable. Flag the ≥4 visibility threshold
# breach codified at sprint-9 retro AI #2 (sustained sprint-10/11/12).
#
# WHY: AI #2's load-bearing carryover-watcher metric — "sprint N's pre-sprint
# carryover count vs sprint-N-end carryover-out count = absorbed count" — is verified
# manually at every sprint close. Sprint-11 retro AI #5 noted this manual cross-check
# as recurring overhead. This lint automates the pre-count read + threshold breach
# detection + best-effort retro-forecast cross-verification. Forward-looking: when
# AI #2 retires (after ≥3 sprints below threshold), this lint becomes redundant +
# is a candidate for removal — at which point its presence as a vacuous-pass becomes
# part of S12-04 hygiene drift detection.
#
# CARRYOVER BACKLOG SECTION HEADER COMPATIBILITY:
#   - sprint-12+: "## Carryover Backlog (from Previous Sprint)" — codified at S11-01
#   - sprint-11 and earlier: "## Carryover from Previous Sprint" — pre-codification
#   Both forms are detected; rows are counted from the table that follows.
#
# CARRYOVER ROW PATTERN: any table row inside the section that contains an `S<N>-<NN>`
# story identifier (e.g., `S11-12`, `S10-13`) outside of the table-header / separator
# rows. Excludes the column-header row + separator row + section preamble paragraphs.
#
# RETRO FORECAST PATTERN (best-effort; prior-sprint retro):
#   Primary: "Carryover concentration into sprint-{N}: **X**" (sprint-11+ canonical)
#   Fallback: any line near "forecast carryover" containing a leading digit
#   ADVISORY-only when no pattern matches (the pre-canonical retros).
#
# EXIT CODES:
#   0 = PASS (count consistent with retro forecast OR retro forecast unextractable;
#       count below ≥4 visibility threshold)
#   1 = FAIL (count mismatch between latest sprint plan + prior retro forecast)
#   2 = WARN (count ≥4 visibility threshold breached per sprint-9 retro AI #2)
#       — NOTE: lint exits 0 on threshold-only-breach (non-blocking, surfaced for
#       producer awareness); exit 2 is reserved for future hardening if the
#       threshold becomes a hard gate.
#
# OUTPUT FORMAT (tail):
#   sprint-N pre-carryover: X (from production/sprints/sprint-N.md Carryover Backlog)
#   sprint-(N-1) retro forecast: Y (from production/retrospectives/retro-sprint-(N-1)-*.md)
#   PASS / FAIL / ADVISORY / WARN line
#
# CROSS-REFERENCES:
#   - sprint-11 retro AI #5: production/retrospectives/retro-sprint-11-2026-05-08.md
#   - sprint-9 retro AI #2 (≥4 threshold codification): production/retrospectives/retro-sprint-9-2026-05-07.md
#   - sprint-12 plan: production/sprints/sprint-12.md (S12-09 row + Carryover Backlog section)
#   - companion lints: tools/ci/lint_story_status_consistency.sh (parallel hygiene-drift detection)

set -uo pipefail

SPRINT_DIR="production/sprints"
RETRO_DIR="production/retrospectives"
THRESHOLD=4

# ─── Step 1: Find latest sprint plan ──────────────────────────────────────────
LATEST_SPRINT=$(find "$SPRINT_DIR" -maxdepth 1 -type f -name "sprint-*.md" 2>/dev/null \
  | sed -E 's|.*/sprint-([0-9]+)\.md|\1|' \
  | sort -n \
  | tail -1)

if [[ -z "$LATEST_SPRINT" ]]; then
  echo "lint_sprint_carryover_count: no sprint plan found in $SPRINT_DIR; vacuously PASS"
  exit 0
fi

LATEST_PLAN="$SPRINT_DIR/sprint-$LATEST_SPRINT.md"
PRIOR_SPRINT=$((LATEST_SPRINT - 1))

if [[ ! -f "$LATEST_PLAN" ]]; then
  echo "lint_sprint_carryover_count: latest sprint plan $LATEST_PLAN not readable; FAIL"
  exit 1
fi

# ─── Step 2: Count carryover rows in latest sprint plan ───────────────────────
# Handles both section header variants (TG-3 flag/next pattern per
# .claude/rules/tooling-gotchas.md: end pattern `^## ` would match the start
# header itself — so we use flag/next to advance past the header before
# checking for the next-section terminator).
PRE_COUNT=$(awk '
  /^## Carryover Backlog|^## Carryover from Previous Sprint/ { flag=1; next }
  flag && /^## / { flag=0 }
  flag && /^\| \*\*S[0-9]+-[0-9]+\*\*/ { count++ }
  END { print count+0 }
' "$LATEST_PLAN")

# Fallback: row pattern may use unbolded story IDs (sprint-11 form
# `| S10-06 ... |` rather than `| **S10-06** ... |`)
if [[ "$PRE_COUNT" -eq 0 ]]; then
  PRE_COUNT=$(awk '
    /^## Carryover Backlog|^## Carryover from Previous Sprint/ { flag=1; next }
    flag && /^## / { flag=0 }
    flag && /^\| / && /S[0-9]+-[0-9]+/ && !/^\|---/ && !/Carryover Task/ && !/Sprint-[0-9]+ Task/ { count++ }
    END { print count+0 }
  ' "$LATEST_PLAN")
fi

echo "lint_sprint_carryover_count: latest sprint = sprint-$LATEST_SPRINT"
echo "  source plan: $LATEST_PLAN"
echo "  pre-carryover count: $PRE_COUNT"

# ─── Step 3: Best-effort retro forecast extraction ────────────────────────────
RETRO_FILE=$(find "$RETRO_DIR" -maxdepth 1 -type f -name "retro-sprint-$PRIOR_SPRINT-*.md" 2>/dev/null | head -1)
RETRO_FORECAST=""
RETRO_PATTERN_USED=""

if [[ -n "$RETRO_FILE" ]] && [[ -f "$RETRO_FILE" ]]; then
  echo "  prior retro: $RETRO_FILE"

  # Pattern 1 (canonical, sprint-11+): "Carryover concentration into sprint-{N}: **X** ..."
  # Anchor on the literal phrase to avoid matching unrelated bolded numbers earlier in the line
  # (e.g., "**9 of 9 absorbed.** Carryover concentration into sprint-12: **2 USER-OWNED only**.").
  RETRO_FORECAST=$(grep -E "Carryover concentration into sprint-$LATEST_SPRINT" "$RETRO_FILE" 2>/dev/null \
    | head -1 \
    | sed -E "s/.*Carryover concentration into sprint-${LATEST_SPRINT}[: ]+//" \
    | grep -oE '^\**([0-9]+)' \
    | grep -oE '[0-9]+' \
    | head -1)

  if [[ -n "$RETRO_FORECAST" ]]; then
    RETRO_PATTERN_USED="canonical (Carryover concentration into sprint-N)"
  else
    # Pattern 2 (fallback): table-row "Carryover from prior sprint" with "X USER-OWNED" / "Y claude"
    # Tries first numeric value after "→ sprint-{N}" or near "forecast carryover" header.
    RETRO_FORECAST=$(awk -v target="sprint-$LATEST_SPRINT" '
      /forecast carryover/ || /Carryover from prior sprint/ { in_section=1; lines_remaining=8 }
      in_section && lines_remaining>0 {
        if (match($0, /([0-9]+) USER-OWNED/, a)) { user_count=a[1]+0 }
        if (match($0, /([0-9]+) claude/, b))     { claude_count=b[1]+0 }
        lines_remaining--
      }
      END {
        total = user_count + claude_count
        if (total > 0) print total
      }
    ' "$RETRO_FILE")
    if [[ -n "$RETRO_FORECAST" ]]; then
      RETRO_PATTERN_USED="fallback (USER-OWNED + claude-owned counts)"
    fi
  fi

  echo "  retro forecast count: ${RETRO_FORECAST:-<not extractable>}"
  if [[ -n "$RETRO_FORECAST" ]]; then
    echo "  retro pattern matched: $RETRO_PATTERN_USED"
  fi
else
  echo "  prior retro: <not found at retro-sprint-$PRIOR_SPRINT-*.md>"
fi

# ─── Step 4: Cross-verification + threshold check ─────────────────────────────
EXIT_CODE=0
THRESHOLD_BREACHED=0

if [[ -n "$RETRO_FORECAST" ]]; then
  if [[ "$PRE_COUNT" -ne "$RETRO_FORECAST" ]]; then
    echo ""
    echo "FAIL: sprint-$LATEST_SPRINT pre-carryover ($PRE_COUNT) != sprint-$PRIOR_SPRINT retro forecast ($RETRO_FORECAST)"
    echo ""
    echo "Diagnosis options:"
    echo "  - Sprint plan's Carryover Backlog table is missing rows that the retro forecast"
    echo "    expected (under-recording); add the missing rows."
    echo "  - Sprint plan added rows beyond the retro forecast (new mid-sprint carryover);"
    echo "    update the prior retro's forecast count via amendment OR document the delta"
    echo "    in the sprint plan's Carryover Backlog preamble."
    echo "  - Retro pattern extraction misread the source; verify the canonical line:"
    echo "    \"Carryover concentration into sprint-$LATEST_SPRINT: **N** ...\""
    EXIT_CODE=1
  else
    echo ""
    echo "PASS: sprint-$LATEST_SPRINT pre-carryover ($PRE_COUNT) == sprint-$PRIOR_SPRINT retro forecast ($RETRO_FORECAST)"
  fi
else
  echo ""
  echo "ADVISORY: prior retro forecast not extractable; cross-verification skipped"
  echo "  (this lint is forward-looking; pre-canonical retros may not declare a forecast"
  echo "  in either canonical or fallback form. Carryover count itself is still recorded.)"
fi

# Threshold check (independent of cross-verification result; non-blocking)
if [[ "$PRE_COUNT" -ge "$THRESHOLD" ]]; then
  echo ""
  echo "WARN: sprint-$LATEST_SPRINT pre-carryover ($PRE_COUNT) ≥ $THRESHOLD visibility threshold"
  echo "  per sprint-9 retro AI #2 (sustained sprint-10/11/12). Producer should review:"
  echo "  - Are individual items at ≥4-time-carryover count? (escalate per S12-06 5th-time threshold rule)"
  echo "  - Should next sprint plan apply cut/descope/keep sweep (sprint-11 S11-04 precedent)?"
  echo "  This warning is non-blocking — sprint plan may proceed with documented rationale."
  THRESHOLD_BREACHED=1
fi

# ─── Step 5: Final outcome ────────────────────────────────────────────────────
if [[ "$EXIT_CODE" -eq 0 ]]; then
  if [[ "$THRESHOLD_BREACHED" -eq 1 ]]; then
    echo ""
    echo "lint_sprint_carryover_count: PASS-WITH-WARN (count consistent; threshold breached)"
  else
    echo ""
    echo "lint_sprint_carryover_count: PASS"
  fi
fi

exit $EXIT_CODE
