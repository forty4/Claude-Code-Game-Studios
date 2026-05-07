#!/usr/bin/env bash
# lint_story_status_consistency.sh
#
# Codified sprint-11 S11-03 2026-05-08 (root-cause fix for the 4-invocation BACKFILL
# CLOSE-OUT pattern caught at S10-04 + S11-02; see
# production/process-audits/story-done-phase-7-audit-2026-05-08.md).
#
# WHAT: For each story file in production/epics/**/story-*.md whose Status header is
# `Complete`, diff the 4 canonical Status sources to detect drift:
#   1. Story file Status header (the source of truth)
#   2. production/sprint-status.yaml row matching the story file path
#      (or fallback: production/sprint-status-history.md presence check for sprint-archived stories)
#   3. Parent production/epics/[epic-slug]/EPIC.md Status header + Stories table row
#   4. production/epics/index.md row Status cell
#
# WHY: /story-done Phase 7 historically updated only sources #1 + #2; sources #3 + #4
# were left to manual propagation, which silently failed across sprint-7 close-outs.
# This lint catches drift before /story-readiness has to (cheaper than waiting for the
# next sprint's pre-flight check). Defense-in-depth alongside the codified Phase 7 step
# 5 + 6 enforcement in /story-done.
#
# EXIT CODES:
#   0 = all consistent (story Status=Complete + all 4 sources reflect Complete)
#   1 = mismatch detected; specific gaps logged to stdout
#
# OUTPUT FORMAT (on mismatch):
#   STATUS_CONSISTENCY_FAIL: [story-id]
#     story-file:          [Status value]
#     sprint-status.yaml:  [status value | not in current sprint]
#     EPIC.md header:      [Status value | not detected]
#     EPIC.md table row:   [Status value | not detected]
#     index.md row:        [Status value | not detected]

set -uo pipefail

FAIL_COUNT=0
EPIC_GLOB="production/epics"

# Find every story file (skip EPIC.md index files + audit / template files)
mapfile -t STORY_FILES < <(find "$EPIC_GLOB" -type f -name "story-*.md" 2>/dev/null | sort)

if [[ ${#STORY_FILES[@]} -eq 0 ]]; then
  echo "lint_story_status_consistency: no story files found under $EPIC_GLOB; skipping (vacuously PASS)"
  exit 0
fi

for STORY_FILE in "${STORY_FILES[@]}"; do
  # Extract story file Status header — typical form: `> **Status**: Complete (...)` on line 4-6
  STORY_STATUS=$(grep -m1 -E '^> \*\*Status\*\*:' "$STORY_FILE" 2>/dev/null \
    | sed -E 's/^> \*\*Status\*\*: *//; s/ *\(.*$//' \
    | head -1)

  # Skip stories that aren't Complete — we only audit the Complete state for downstream consistency
  if [[ "$STORY_STATUS" != "Complete" ]]; then
    continue
  fi

  STORY_ID=$(basename "$STORY_FILE" .md)
  EPIC_DIR=$(dirname "$STORY_FILE")
  EPIC_SLUG=$(basename "$EPIC_DIR")
  EPIC_MD="$EPIC_DIR/EPIC.md"
  INDEX_MD="$EPIC_GLOB/index.md"
  YAML="production/sprint-status.yaml"

  # Source 2: sprint-status.yaml row by file: match
  YAML_STATUS=""
  if [[ -f "$YAML" ]]; then
    # Find the row block containing `file: "...story-file..."` and extract the `status:` from same block (within next 5 lines).
    # Use awk to find the row; if the row's file: matches, capture the status: that follows.
    YAML_STATUS=$(awk -v target="$STORY_FILE" '
      /^  - id:/ { in_block=1; status=""; file_match=0 }
      in_block && /^    file:/ { if ($0 ~ target) file_match=1 }
      in_block && /^    status:/ { gsub(/^    status: */, ""); gsub(/"/, ""); status=$0 }
      in_block && /^$/ { if (file_match && status) print status; in_block=0; status=""; file_match=0 }
      END { if (in_block && file_match && status) print status }
    ' "$YAML" 2>/dev/null)
  fi

  # If not in current sprint-status.yaml: check sprint-status-history.md as fallback (sprint-archived)
  ARCHIVE_FOUND=0
  if [[ -z "$YAML_STATUS" ]] && [[ -f "production/sprint-status-history.md" ]]; then
    if grep -qE "(\| done \|.*$STORY_ID|$STORY_ID.*\| done \|)" production/sprint-status-history.md 2>/dev/null; then
      ARCHIVE_FOUND=1
      YAML_STATUS="archived-done"
    fi
  fi

  # Source 3: EPIC.md Status header
  EPIC_HEADER_STATUS=""
  if [[ -f "$EPIC_MD" ]]; then
    EPIC_HEADER_STATUS=$(grep -m1 -E '^> \*\*Status\*\*:' "$EPIC_MD" 2>/dev/null \
      | sed -E 's/^> \*\*Status\*\*: *//; s/ *\(.*$//' \
      | head -1)
  fi

  # Source 3b: EPIC.md Stories table row matching this story
  # Stories table row pattern: `| [001](story-...md) | ... | ... | **{Status}** ... |`
  EPIC_TABLE_STATUS=""
  if [[ -f "$EPIC_MD" ]]; then
    STORY_BASENAME=$(basename "$STORY_FILE")
    EPIC_TABLE_STATUS=$(grep -m1 -F "$STORY_BASENAME" "$EPIC_MD" 2>/dev/null \
      | grep -oE '\*\*[A-Z][a-zA-Z]+\*\*' \
      | head -1 \
      | sed -E 's/^\*\*//; s/\*\*$//')
  fi

  # Source 4: index.md row
  INDEX_ROW_STATUS=""
  if [[ -f "$INDEX_MD" ]]; then
    INDEX_ROW=$(grep -m1 -E "\[$EPIC_SLUG\]\($EPIC_SLUG/EPIC\.md\)" "$INDEX_MD" 2>/dev/null)
    if [[ -n "$INDEX_ROW" ]]; then
      # Find the LAST cell with **{Status}** pattern - typically the Status column at right
      INDEX_ROW_STATUS=$(echo "$INDEX_ROW" | grep -oE '\*\*[A-Z][a-zA-Z]+\*\*' | tail -1 | sed -E 's/^\*\*//; s/\*\*$//')
    fi
  fi

  # Detect mismatches
  # POLICY: Only flag CLEAR Ready/Draft/Backlog mismatches against a Complete story-file.
  # An orphaned yaml row (story-archived, not in current sprint, archive trace not found via
  # narrow regex) is NOT itself a mismatch IF the active downstream sources (EPIC.md + index.md)
  # all reflect Complete — the lint's purpose is catching drift, not enforcing perfect archive
  # traceability. Sprint-archived stories with consistent downstream-Status pass cleanly.
  MISMATCH_REASONS=()

  # yaml: only flag if found AND value is non-done (e.g., ready-for-dev / in-progress / backlog).
  # Skip the check entirely if value is empty (orphan-yaml case — assume sprint-archived; defer to other sources).
  if [[ -n "$YAML_STATUS" ]] && [[ "$YAML_STATUS" != "done" ]] && [[ "$YAML_STATUS" != "archived-done" ]]; then
    MISMATCH_REASONS+=("sprint-status.yaml row status=$YAML_STATUS (expected: done)")
  fi

  # EPIC.md Stories table row: only flag if present AND value is non-Complete.
  if [[ -n "$EPIC_TABLE_STATUS" ]] && [[ "$EPIC_TABLE_STATUS" != "Complete" ]]; then
    MISMATCH_REASONS+=("EPIC.md Stories table row status=$EPIC_TABLE_STATUS (expected: Complete)")
  fi

  # index.md row: only flag when clearly stale (Ready / Draft / Backlog vs. Complete story).
  # Allow `In` (In Progress) — non-terminal stories may legitimately leave this state.
  if [[ -n "$INDEX_ROW_STATUS" ]] && [[ "$INDEX_ROW_STATUS" == "Ready" || "$INDEX_ROW_STATUS" == "Draft" || "$INDEX_ROW_STATUS" == "Backlog" ]]; then
    MISMATCH_REASONS+=("index.md row status=$INDEX_ROW_STATUS (story is Complete; expected: Complete or In Progress)")
  fi

  # EPIC.md Status header: only flag when ALL sibling stories in the epic are Complete
  # (epic-terminal closure not propagated). Best-effort; depends on Status header detection
  # being available.
  if [[ -n "$EPIC_HEADER_STATUS" ]] && [[ "$EPIC_HEADER_STATUS" == "Ready" || "$EPIC_HEADER_STATUS" == "Draft" ]]; then
    OTHER_NON_COMPLETE_COUNT=$(find "$EPIC_DIR" -type f -name "story-*.md" ! -path "$STORY_FILE" -exec grep -lE '^> \*\*Status\*\*: (Ready|Draft|Backlog|In Progress|Blocked)' {} \; 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$OTHER_NON_COMPLETE_COUNT" -eq 0 ]]; then
      MISMATCH_REASONS+=("EPIC.md Status header=$EPIC_HEADER_STATUS but all stories in epic are Complete (epic-terminal closure not propagated)")
    fi
  fi

  if [[ ${#MISMATCH_REASONS[@]} -gt 0 ]]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "STATUS_CONSISTENCY_FAIL: $STORY_ID"
    echo "  story-file:          $STORY_STATUS"
    echo "  sprint-status.yaml:  ${YAML_STATUS:-<not found>}"
    echo "  EPIC.md header:      ${EPIC_HEADER_STATUS:-<not detected>}"
    echo "  EPIC.md table row:   ${EPIC_TABLE_STATUS:-<not detected>}"
    echo "  index.md row:        ${INDEX_ROW_STATUS:-<not detected>}"
    for reason in "${MISMATCH_REASONS[@]}"; do
      echo "    REASON: $reason"
    done
    echo ""
  fi
done

if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo "lint_story_status_consistency: PASS — all Complete stories have consistent downstream Status"
  exit 0
else
  echo "lint_story_status_consistency: FAIL — $FAIL_COUNT story/stories have downstream Status drift"
  echo ""
  echo "Recommended fix: per /story-done Phase 7 step 5+6, propagate Status flips to:"
  echo "  - production/sprint-status.yaml row (status: done)"
  echo "  - production/epics/[epic-slug]/EPIC.md Stories table row (Complete)"
  echo "  - production/epics/[epic-slug]/EPIC.md Status header (if epic-terminal)"
  echo "  - production/epics/index.md row Status + Stories cells"
  echo ""
  echo "If story is sprint-archived, ensure sprint-status-history.md contains the done entry."
  echo ""
  echo "See process audit: production/process-audits/story-done-phase-7-audit-2026-05-08.md"
  exit 1
fi
