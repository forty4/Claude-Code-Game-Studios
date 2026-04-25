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
