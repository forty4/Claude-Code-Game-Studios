---
paths:
  - "**"
---

# Tooling / Workflow Gotchas

Session-discovered pitfalls in the developer workflow tooling (gh CLI, git, Godot CLI, GdUnit4 runner) that cost real time to rediscover. Distinct from `.claude/rules/godot-4x-gotchas.md` (engine/test-framework code patterns) — this file is about the COMMANDS we run, not the code we write.

Each entry: **Context** → **Broken** → **Correct** → **Discovered** (source story for historical reference).

---

## TG-1 — `gh pr create` defaults to `upstream` remote when both `origin` (fork) and `upstream` (parent) are configured

**Context**: a project that was forked from an upstream repo (`origin` points to your fork; `upstream` points to the parent). Running `gh pr create` from a feature branch in your fork to merge into your fork's `main`.

**Broken**: `gh pr create --title ... --body ...` auto-detects `upstream` as the parent repo and tries to open the PR against `<parent>/main` instead of `<fork>/main`. If your token lacks write access to the parent (the normal case for a forked workflow that doesn't push back upstream), it fails with:

```
pull request create failed: GraphQL: <user> does not have the correct permissions to execute `CreatePullRequest` (createPullRequest)
```

The error message is misleading — it implies a token-scope problem, but the token is fine. The actual issue is that `gh` chose the wrong base repo.

```bash
# BROKEN — gh auto-picks upstream as base
gh pr create --title "feat: X" --body "..."
# → permissions error against <parent>/<repo>, not <fork>/<repo>
```

**Correct**: pass `--repo <fork-owner>/<repo>` explicitly to lock the base repo to your fork. Optionally also pin `--base` and `--head`:

```bash
# CORRECT — explicit base repo
gh pr create \
    --repo forty4/Claude-Code-Game-Studios \
    --base main \
    --head feature/my-feature-branch \
    --title "feat: X" \
    --body "..."
```

**Verification**: before opening any PR, sanity-check which repo `gh` thinks is the parent:

```bash
gh repo view 2>&1 | head -3
# If the name field shows the upstream owner instead of your fork owner,
# you'll need --repo on every gh PR/issue command in this repo.
```

**Alternative remediation** (if you never push back upstream): remove the upstream remote entirely:

```bash
git remote remove upstream
```

Most projects keep `upstream` for `git fetch upstream` to sync — so the explicit `--repo` flag in PR scripts is the more common fix.

**Symptom checklist** — if `gh pr create` fails with `createPullRequest` permission error:
1. Run `gh auth status` — verify `repo` scope is present (it almost certainly is)
2. Run `git remote -v` — check whether `upstream` exists alongside `origin`
3. Run `gh repo view 2>&1 | head -3` — confirm whether `gh` is targeting your fork or the upstream
4. If `upstream` is configured, retry with `--repo <fork-owner>/<repo>` explicit flag

**Discovered**: terrain-effect story-005 PR creation (2026-04-26). First failed `gh pr create` after the explicit-flag pattern was lost between story-004's PR (#38, succeeded — likely run from a clean repo state without `upstream` remote yet) and story-005's PR (#39, failed first try). Cost: ~5 minutes of confusion + one re-attempt with `--repo` flag.

---

## TG-2 — Stale handoff: trusting `active.md` without running `git fetch origin` at session resume

**Context**: resuming a Claude Code session via `/clear` or new-session-start when `production/session-state/active.md` describes "uncommitted local work" or "implementation pending" or "next priority = story-X". The handoff was written by a prior session that may not have run a final `git fetch` against origin before the session ended (or the user/teammate may have merged a PR AFTER the handoff was written).

**Broken**: trusting `active.md` as the source of truth for "what's local vs. what's already on origin" without first running `git fetch origin && git status -uno && git rev-list --left-right --count origin/main...HEAD`. If origin/main has advanced past local main (because a PR was merged AFTER the handoff was written, or because of an out-of-band push), the handoff text reads as a confident lie:

```bash
# BROKEN — trusting handoff verbatim
# active.md says: "story-007 next priority — implementation done locally; not yet committed"
# Reality (after fetch): origin/main has PR #67 (story-007) AND PR #68 (story-008) already merged.
# Without fetch, the next session re-does already-merged work.
```

The misleading pattern in `active.md` to watch for is the phrase "Discrepancy with prior extract above" or any "supersedes earlier note" qualifier — that text indicates the prior session was patching its own stale notes, which is a SYMPTOM of unsynced state, NOT an acceptable handoff. Do not accept it without verification.

**Correct**: ALWAYS run the fetch + sync-check sequence at session resume, BEFORE reading `active.md` as authoritative:

```bash
# CORRECT — sync check first
git fetch origin
git rev-list --left-right --count origin/main...HEAD
# Output: <left>\t<right>  → left = commits origin/main has that HEAD doesn't (local behind)
#                          → right = commits HEAD has that origin/main doesn't (local ahead)
# If left > 0 and you're on main: run `git pull --ff-only origin main` before trusting active.md.
# If right > 0: you're on a branch with local-only commits — verify they're not stale-after-squash-merge.
```

If the active.md handoff describes work as "uncommitted local" but `git fetch` shows origin ahead, audit before acting:

```bash
# Compare local working tree against the committed-on-origin version
git diff origin/main -- [story-files-mentioned-in-active.md]
# If significant diverge: the local work is a STALE re-implementation; reset to origin/main + drop redundant work.
```

**Symptom checklist** — flags that indicate unsynced state at session resume:
1. `active.md` "Next-session priorities" lists a story as "implementation pending" but you have no recent memory of running `/dev-story` for it
2. `git status -uno` shows the working tree carrying changes to files for a story whose merge commit you don't recognize in `git log --oneline origin/main -10`
3. `gh pr list --repo <repo> --state all --limit 5` shows recent merges (within the timeframe of the prior session) that aren't in your local `git log`
4. The current local branch is `feature/story-X-...` but a PR for that story already shows MERGED on origin

**Concrete cost**: damage-calc story-006 close-out (2026-04-27) ran `/code-review` against a local working-tree re-implementation BEFORE discovering PR #64 had merged the canonical version 24 hours earlier. The local re-implementation diverged from the merged version by 273 LoC in production code + 913 LoC in tests. Cost: ~30 minutes on stale-against-merged code review + explicit `git reset --hard origin/main` + cross-check of which review fixes still applied to the merged version (3 of 4 had already been independently addressed by the merged refactor; 1 was a 1-word doc nit not worth a follow-up PR).

**Wrapper script suggestion** (not yet implemented; future hardening): `tools/ci/session_resume_fetch_check.sh` that runs the fetch + count + warns if origin/main is ahead. Could be wired as a Claude Code SessionStart hook so it runs automatically before `active.md` is read by the agent.

**Discovered**: damage-calc story-006 close-out (2026-04-27 — the "PR #64 already-merged discovery" session-extract block in `production/session-state/active.md` documents the trap in detail). Re-confirmed at damage-calc story-010 session resume (2026-04-27, same day, fresh session): active.md handoff said "next priority = story-007 vertical-slice 7/7"; `git fetch origin` revealed PRs #67 (story-007) and #68 (story-008) had both merged hours earlier. Pattern is now stable at 2 invocations.

---

## TG-3 — `awk /start/,/end/` range pattern self-closes when start line also matches end pattern

**Context**: extracting a section from a config file via awk's range pattern `/start/,/end/` where both endpoints are section headers using a similar regex (e.g. `^\[` for TOML / INI sections, `^# ` for Markdown headers, or `^- ` for YAML list entries). The intent is "give me everything between the start marker and the next-marker-of-the-same-kind." But if the start line ALSO matches the end pattern (it usually does, when both endpoints are the same kind of thing), awk's range opens AND closes on the same line — the range emits only the start line.

**Broken**: extracting a TOML section from `project.godot`. Section headers all match `^\[`. The start line itself matches `^\[input_devices\.pointing\]` AND `^\[`, so awk closes the range immediately:

```bash
# BROKEN — range opens + closes on the start line because start matches end
awk '/^\[input_devices\.pointing\]/,/^\[/' project.godot
# → emits only:
# [input_devices.pointing]
# Section body lines never appear in the output.
```

This is silently wrong: a downstream `grep` against the awk output for the actual section body content (e.g. `emulate_mouse_from_touch=false`) will fail to match, and the lint will report a false negative ("section is missing the setting") when the setting is in fact present in the file.

**Correct**: use the `flag/next` pattern for section extraction when the start line might also match the end pattern. The `next` keyword skips to the next line BEFORE awk re-evaluates the patterns, so the end check only fires on subsequent lines:

```bash
# CORRECT — flag/next pattern; end check only fires on lines AFTER the start
awk '/^\[input_devices\.pointing\]/{flag=1; next} /^\[/{flag=0} flag' project.godot
# → emits the full section body after the header, until the next `[section]` line.
```

If you also need the header line in the output, drop the `next` from the start rule and use a separate flag-check before the end rule:

```bash
# CORRECT — emits header + body (rare; usually you only want the body)
awk '/^\[input_devices\.pointing\]/{flag=1} flag && /^\[/ && !/^\[input_devices\.pointing\]/{flag=0} flag' project.godot
```

**Verification recipe**: when writing a section-extraction awk one-liner, count the output lines and compare against expected body length. If the output is exactly 1 line and the section is known to have body content, suspect TG-3 immediately:

```bash
# Quick TG-3 sanity check
awk '...' file | wc -l
# If = 1 and you expected body content, switch to flag/next pattern.
```

**Symptom checklist** — if a lint script that extracts a config section is producing false-negative "missing setting" errors despite the setting being visibly present in the file:
1. Open the file at the relevant section + manually confirm the setting exists at the expected location
2. Run the lint's awk command in isolation: `bash -x tools/ci/lint_xxx.sh` (or copy the awk pipeline directly)
3. Check whether the awk output contains only the section header (1 line) with no body
4. If yes, replace the `/start/,/end/` range pattern with the `flag/next` pattern above
5. Re-run the lint to confirm it now passes

**Where this trap commonly appears**: TOML / INI section extraction (`^\[`), Markdown header-block extraction (`^# `, `^## `), YAML list-block extraction (`^- `, `^[a-z]:`), GDScript `func` body extraction (`^func ` for the start, `^func ` for the next-function-end). Anywhere both endpoints share a regex prefix.

**Cross-references in this codebase**: `tools/ci/lint_input_router_g15_reset.sh` and `tools/ci/lint_input_router_input_blocked_drop_without_set_input_as_handled.sh` both use the `flag/next` pattern correctly (extract `func before_test()` body and `_handle_action_in_s5` body respectively). The fix at `tools/ci/lint_emulate_mouse_from_touch.sh` (S9-05) brings that lint into the same family.

**Discovered**: input-handling story-010 (S9-05, 2026-05-07) — `tools/ci/lint_emulate_mouse_from_touch.sh` first-run failure. Cost: ~5 minutes of confusion ("the setting IS in the file but the lint says it's missing"); fix codified inline in the lint script comment at the awk line. Codified at sprint-9 retro time per Process Improvement #1 (sprint-8: pay codification debt at retro time, not next sprint).

---

## TG-4 — Regex extraction from prose-rich text MUST anchor on the literal phrase preceding the target token

**Context**: writing a CI lint that pulls a numeric value (or any token) out of a prose-rich human-authored markdown line — typically retros, sprint plans, or decision artifacts where the same syntactic shape (`**N**`, `**N items**`, `**N stories**`) can appear MULTIPLE times per paragraph. An unanchored shape-based extractor takes the first match and silently captures the wrong token.

**Broken**: `lint_sprint_carryover_count.sh` first-run pattern (S12-09):

```bash
# BROKEN — unanchored bolded-number capture matches the FIRST bold-number on the line
grep -oE '\*\*[0-9]+' "$RETRO_FILE" | head -1
# Source line: "**9 of 9 absorbed.** Carryover concentration into sprint-12: **2 USER-OWNED only**."
# → captures "**9" (the absorption count) instead of "**2" (the carryover concentration).
```

The misfire is silent — no parse error, no stderr noise, just a wrong number in the output. Downstream consumers (the next sprint's plan-author who trusts the lint) act on the wrong forecast.

**Correct**: anchor on the literal phrase that uniquely identifies the target token, THEN extract the shape-matched value from the suffix:

```bash
# CORRECT — literal-phrase anchor first; shape-extract from suffix only
grep -E "Carryover concentration into sprint-$LATEST_SPRINT" "$RETRO_FILE" \
  | head -1 \
  | sed -E "s/.*Carryover concentration into sprint-${LATEST_SPRINT}[: ]+//" \
  | grep -oE '^\**([0-9]+)' \
  | grep -oE '[0-9]+' \
  | head -1
```

The anchor (`Carryover concentration into sprint-N`) is the discriminator; the shape pattern is applied AFTER discrimination, eliminating any risk of capturing an unrelated bolded number elsewhere on the line.

**Verification recipe**: run the lint against a synthetic line containing TWO instances of the target shape:

```bash
echo "**9 of 9 absorbed.** Carryover concentration into sprint-12: **2 USER-OWNED only**." | <your-extractor>
# Expected: 2. If you got 9, the literal-phrase anchor is missing.
```

**Symptom checklist** — if a lint emits a plausible-but-wrong number from a retro / sprint-plan / decision artifact:
1. Open the source line + manually count target-shape token occurrences
2. If >1, the extractor needs a literal-phrase anchor (sed substitution OR grep -E with surrounding context)
3. The anchor MUST come BEFORE the shape-based extraction in the pipeline, not after
4. Re-test against a synthetic two-token line to confirm discrimination

**Where this trap commonly appears**: any sed/grep/awk pipeline pulling ONE numeric value out of markdown / prose where the same shape (`**N**`, `N items`, `N stories`) can appear multiple times. Sprint-status.yaml extractors are typically safe (structured); sprint-plan / retro extractors are NOT.

**Same family as**: G-1 (% binds left → use parens), G-9 (string-concat % precedence → use parens), G-24 (`as` operator low precedence → use parens), TG-3 (awk range pattern self-closes → flag/next). Pattern: when a syntactic shape can match multiple sites, anchor on a literal-phrase discriminator BEFORE applying the shape-based match.

**Cross-references in this codebase**: `tools/ci/lint_sprint_carryover_count.sh:117-122` shows the corrected pattern with the `Carryover concentration into sprint-N` literal anchor + trailing-number extraction.

**Discovered**: sprint-12 S12-09 first-run lint authoring (2026-05-09) — `lint_sprint_carryover_count.sh` initial draft used unanchored bolded-number capture; misread `**9 of 9 absorbed.**` as the carryover count. Fixed in same-session second pass with the literal-phrase anchor. Cost: ~10 min of "the lint says 9, the actual carryover is 2 — which is right?" debug. Codified at sprint-13 S13-04 per sprint-12 retro AI #5 + AI #1 sustained directive.

---

## TG-5 — SendMessage tool unavailable in environment: paused subagents cannot be resumed; must spawn fresh agents with cumulative context

**Context**: spawning a Task subagent that pauses mid-execution to ask the orchestrator a question (e.g., "May I write to [path]?" per CLAUDE.md collaborative protocol; OR "I discovered ambiguity X — should I proceed with approach Y?"). The Task tool's docstring suggests resuming a paused agent via `SendMessage with the agent's ID or name as the 'to' field — that resumes it with full context`. The agent's pause output also instructs `(use SendMessage with to: '<agentId>' to continue this agent)`.

**Broken**: trusting that SendMessage is available without verifying. If the deployed environment does NOT expose the SendMessage tool (current environment as of 2026-05-10 sprint-15 verification: ToolSearch lookup returned `No matching deferred tools found` for `SendMessage`), there is no path to resume the paused subagent. Each fresh `Agent` Task call starts a NEW agent with NO memory of the prior pause + reasoning. The user's approval that arrives between pause + intended-resume is effectively lost; the new agent must re-derive everything from prompt context.

```
# BROKEN — assumed SendMessage exists; agent paused asking "May I write to [path]?";
# orchestrator gets user approval; tries SendMessage:
#
# (no tool call possible — SendMessage not in tool list nor in deferred tools)
#
# → orchestrator forced to spawn fresh agent
# → fresh agent loads context from scratch (re-reads source files, ADRs, etc.)
# → high token cost per spawn cycle
# → if fresh agent ALSO pauses with same kind of permission question, infinite spawn loop risk
```

**Correct**: assume SendMessage is unavailable until proven otherwise. Two mitigation patterns:

1. **Verify availability at session start** if you anticipate needing agent resumption:
   ```
   ToolSearch(query="select:SendMessage", max_results=1)
   # If returns "No matching deferred tools found" → plan for spawn-only workflow
   ```

2. **Pre-approve writes in spawn prompt** to avoid the pause-for-permission trap. Structure subagent prompts so the agent does NOT pause for routine permission questions when the user has already approved at the orchestration level (via AskUserQuestion). Use explicit override language:
   ```
   # CORRECT — pre-approval directive in spawn prompt
   "**CRITICAL — pre-approval status**: The user has PRE-APPROVED all N write operations
   described below. Do NOT ask 'May I write to [path]?' — pre-approved per the AskUserQuestion
   gate before this spawn was invoked. Per CLAUDE.md collab protocol, this pre-approval
   directive satisfies the 'ask before writing' rule for THESE specific writes. Just write,
   test, report. Pause only if you discover a NEW gap that contradicts the design (e.g.,
   method signature differs from what's documented, test framework gotcha surfaces)."
   ```

   This explicit override prevents the agent from defaulting to the per-write permission
   pause that would otherwise create a SendMessage-unavailability trap.

**Symptom checklist** — if a subagent's final message ends with `agentId: <hex> (use SendMessage with to: '<hex>' to continue this agent)` and orchestrator tries SendMessage but it's not in tool list:

1. ToolSearch with query `select:SendMessage` → `No matching deferred tools found` confirms unavailability
2. The agent's "intended resume context" is GONE — they will not produce more output
3. Their work-in-progress IS preserved on disk if they wrote files before the pause; verify via `git status` + spot-checks
4. Orchestrator must spawn FRESH agent with cumulative context (including: original task + pre-approval directive + any user decisions made in the resume window)

**Concrete cost** (sprint-15 S15-J + S15-D, 2026-05-10): **5 agent spawn cycles total** required across 2 stories due to SendMessage unavailability. S15-J: 3 spawn cycles (initial → orchestrator-design-correction → execute-with-pre-approval). S15-D: 3 spawn cycles (initial → hybrid-fixture-pivot → 0-player-units-pivot, all paused with same SendMessage suggestion). Average ~75-95k tokens per agent spawn (cumulative context loading + work performed). Total token cost ~5×85k = ~425k tokens for what could have been ~2×85k + 3×SendMessage-resumes if SendMessage were available. ~3-4x token amplification factor.

**Workflow improvements** to mitigate:
1. Front-load pre-approval directives in EVERY subagent spawn prompt where multiple file writes are anticipated. Format above ("CRITICAL — pre-approval status").
2. Spawn agents with maximally complete context including all design decisions resolved at orchestration level (vs. pushing decisions onto agents that will then need to pause).
3. Accept that some agents will still pause for genuinely-ambiguous architectural questions — those are correct pauses; the gotcha is permission-pauses for routine writes.
4. If a deployment has SendMessage available, this gotcha doesn't apply; verify via ToolSearch at session-start when planning a multi-write task.

**Cross-references in this codebase**: sprint-15 commits `a4636dc` (S15-J close after 3 spawn cycles) + `dca58a4` (S15-D defer after 3 spawn cycles). Both commit messages document the spawn-cycle counts.

**Discovered**: sprint-15 S15-J + S15-D /dev-story (2026-05-10 PM late-late through PM very-late). 5 spawn cycles in <12 hours surfaced the pattern as stable. Codified at sprint-15 close-out with 13th retro debt item (process observation: SendMessage tool unavailability worth flagging if user has any control over tool availability OR worth permanent codification if environment permanent).

---

## Adding a new tooling gotcha

When a workflow command bites the team:

1. Add an entry in the **TG-N** format above: Context → Broken → Correct → Discovered
2. Keep the Broken example real (copy-paste from the actual failing command + error message)
3. Link the source story for historical trace
4. Cross-reference from the relevant skill or workflow doc if the gotcha is skill-adjacent (e.g., a /story-done gotcha would also be cross-referenced from `.claude/skills/story-done/SKILL.md`)
5. Consider if a wrapper script can prevent it (e.g., `tools/ci/gh_pr_create.sh` that always passes `--repo`)

## Cross-References

- `.claude/rules/godot-4x-gotchas.md` — engine/test-code gotchas (G-1 through G-29)
- `.claude/rules/test-standards.md` — general test discipline
- `docs/tech-debt-register.md` TD-013 — original gotcha-codification project
