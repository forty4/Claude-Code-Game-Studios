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

## Adding a new tooling gotcha

When a workflow command bites the team:

1. Add an entry in the **TG-N** format above: Context → Broken → Correct → Discovered
2. Keep the Broken example real (copy-paste from the actual failing command + error message)
3. Link the source story for historical trace
4. Cross-reference from the relevant skill or workflow doc if the gotcha is skill-adjacent (e.g., a /story-done gotcha would also be cross-referenced from `.claude/skills/story-done/SKILL.md`)
5. Consider if a wrapper script can prevent it (e.g., `tools/ci/gh_pr_create.sh` that always passes `--repo`)

## Cross-References

- `.claude/rules/godot-4x-gotchas.md` — engine/test-code gotchas (G-1 through G-15)
- `.claude/rules/test-standards.md` — general test discipline
- `docs/tech-debt-register.md` TD-013 — original gotcha-codification project
