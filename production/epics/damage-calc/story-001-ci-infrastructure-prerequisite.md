# Story 001: CI infrastructure prerequisite — headed CI + cross-platform matrix + gdUnit4 addon pin

> **Epic**: damage-calc
> **Status**: Ready
> **Layer**: Feature
> **Type**: Config/Data
> **Manifest Version**: 2026-04-20
> **Estimate**: 3-4 hours (CI workflow delta + addon pin documentation; no source code changes)

## Context

**GDD**: `design/gdd/damage-calc.md`
**Requirement**: `TR-damage-calc-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 Damage Calc (Accepted 2026-04-26)
**ADR Decision Summary**: Test infrastructure prerequisites — headless CI per push, headed CI via xvfb-run weekly+rc/* tag, cross-platform matrix (macOS Metal per-push baseline + Windows D3D12 + Linux Vulkan weekly+rc/* tag), GdUnitTestSuite-extends-Node base for AC-DC-51(b), gdUnit4 addon pinning at Godot 4.6 LTS line.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No engine API surface — this is a CI workflow + documentation story. The cross-platform matrix tests AC-DC-37/50 on three rendering backends (Metal/D3D12/Vulkan) per ADR-0012 §10 + ADR-0012 R-7 softened-determinism contract (WARN-not-fail). The headed `xvfb-run` job is required for AC-DC-46 frame-trace + AC-DC-47 monochrome screenshot capture which observe `Control` nodes (cannot run headlessly).

**Control Manifest Rules (Feature layer)**:
- Required: All gameplay system tests run on every push (current `.github/workflows/tests.yml` Linux runner already satisfies this for headless)
- Required: gdUnit4 addon version pinned and recorded in two locations (per ADR-0012 §10 #5 — `tests/README.md` + `CLAUDE.md`)
- Forbidden: Skipping or disabling failing CI tests (project standard from coding-standards.md)
- Guardrail: `rc/*` tags MUST have full matrix green pre-release (per AC-DC-37 hard gate)

---

## Acceptance Criteria

*From ADR-0012 §10 Test Infrastructure Prerequisites:*

- [ ] `.github/workflows/tests.yml` adds **headed `xvfb-run` job** on Linux runner with virtual display, configured to run `tests/integration/damage_calc/damage_calc_ui_test.gd` (file does not yet exist; created in story-009). Cadence: weekly cron + every `rc/*` tag push. Trigger filters configured.
- [ ] `.github/workflows/tests.yml` adds **cross-platform matrix** for AC-DC-37/50 — macOS Metal runner (per-push baseline), Windows D3D12 runner (weekly + rc/* tag), Linux Vulkan runner (weekly + rc/* tag). Per-push macOS run is a hard gate; Windows/Linux divergences emit `WARN` annotations but do not fail the build (per AC-DC-37 softened-determinism contract).
- [ ] gdUnit4 addon pinned version recorded in `tests/README.md` AND `CLAUDE.md` Engine Specialists section. Version recorded matches `addons/gdUnit4/` actual contents.
- [ ] `tests/README.md` documents the GdUnitTestSuite-extends-Node base requirement for AC-DC-51(b) bypass-seam — per-test-class choice (only AC-DC-51(b) requires Node base; other tests may use either base).
- [ ] CI workflow asserts the gdUnit4 pinned version on every push (fails build if `addons/gdUnit4/` differs from documented version)
- [ ] Smoke check: trigger a manual workflow_dispatch on the new headed job; verify `xvfb-run` virtual display starts, gdUnit4 discovers `tests/integration/`, and a placeholder integration test passes. Capture as `production/qa/smoke-damage-calc-ci-bringup.md`.

---

## Implementation Notes

*Derived from ADR-0012 §10 Test Infrastructure Prerequisites + ADR-0012 R-3 mitigation:*

- This story is **a hard prerequisite for stories 002-010**. `/story-readiness` will block any subsequent damage-calc story if AC-DC-37/46/47/50/51(b) infrastructure is unmet at story time.
- Per AC-DC-37 softened contract (ADR-0012 §10): cross-platform divergence on `snappedf` boundary residue is a critical-tier WARN, NOT a hard ship-block. The CI workflow must reflect this — divergent macOS-vs-Windows-vs-Linux outputs on AC-DC-50 should annotate the run with WARN markers, not fail the build. Hard fail on `rc/*` tag only (per AC-DC-37 release-candidate gate).
- Per AC-DC-46 + AC-DC-47 (Story-009): `xvfb-run` virtual display is required for `Control` node observation. Headless mode cannot validate Reduce Motion lifecycle frame-traces or monochrome screenshot captures. The headed job is on Linux only (xvfb is Linux-only); AC-DC-45 TalkBack manual walkthrough on Android/iOS is still a separate manual-evidence task.
- The ADR-0012 §10 #4 GdUnitTestSuite-extends-Node base is a per-test-class choice. AC-DC-51(b) bypass-seam test in story-006 uses `extends GdUnitTestSuite` (Node-based) for `@onready` decorator support; other test files may use the lighter RefCounted base.
- Pinning gdUnit4 addon: this project currently uses `addons/gdUnit4/` (committed). Verify the version string in the addon's `plugin.cfg` or equivalent, then record. CI workflow asserts via grep/diff on a known-pinned hash or version field.
- Workflow file edit pattern matches PR #44 (Sprint 1 kickoff sprint-status.yaml pattern) and PR #43 (terrain-effect story-008 perf baseline CI delta) — both project precedents in `.github/workflows/`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: RefCounted wrapper class declarations (`AttackerContext`, `DefenderContext`, `ResolveModifiers`, `ResolveResult`)
- Story 008: Engine-pin tests AC-DC-49/50 themselves (this story sets up the matrix that runs them)
- Story 009: Headed CI test files `damage_calc_ui_test.gd` (this story sets up the runner that executes them)

---

## QA Test Cases

*Authored from ADR-0012 §10 + AC-DC-37 softened contract directly (lean mode — QL-STORY-READY gate skipped). Smoke-check based since this is a Config/Data story.*

- **AC-1**: Headed `xvfb-run` job exists in `.github/workflows/tests.yml`
  - Setup: open the workflow file
  - Verify: a job named `headed-tests` (or equivalent) exists with `runs-on: ubuntu-latest` and uses `xvfb-run` to invoke godot
  - Pass condition: workflow YAML lints clean (`gh workflow view tests.yml` succeeds); job has weekly cron schedule + `rc/*` tag trigger filters

- **AC-2**: Cross-platform matrix exists in `.github/workflows/tests.yml`
  - Setup: open the workflow file
  - Verify: a matrix strategy lists 3 runners — `macos-latest` (per-push), `windows-latest` (weekly + rc/* tag), `ubuntu-latest` (weekly + rc/* tag with Vulkan)
  - Pass condition: macOS job has unconditional trigger (every push); Windows + Linux jobs have `schedule:` cron + `tags: rc/*` triggers; AC-DC-37 WARN-not-fail behavior implemented (e.g., `continue-on-error: true` on Windows/Linux jobs OR explicit step that converts non-macOS divergence to annotation)

- **AC-3**: gdUnit4 addon version pinned in 2 documentation files
  - Setup: read `tests/README.md` and `CLAUDE.md`
  - Verify: both files contain a "gdUnit4 pinned version: X.Y.Z" line where X.Y.Z matches the actual `addons/gdUnit4/` version
  - Pass condition: grep for the version string returns 1 match in each file; both versions are identical; version matches actual addon contents

- **AC-4**: CI workflow asserts pinned addon version
  - Setup: run a CI build via `gh workflow run`
  - Verify: a workflow step verifies the addon version matches the pinned value (e.g., `cat addons/gdUnit4/plugin.cfg | grep version`)
  - Pass condition: the verification step succeeds; if the addon is updated without bumping the pinned version, the step fails

- **AC-5**: Smoke check evidence captured
  - Setup: manually dispatch the new headed job via `gh workflow run --ref [branch]`
  - Verify: the run completes; xvfb-run logs show virtual display started; a placeholder integration test passes
  - Pass condition: `production/qa/smoke-damage-calc-ci-bringup.md` exists with run URL + log excerpt + verdict PASS

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `production/qa/smoke-damage-calc-ci-bringup.md` — smoke check pass with workflow run URL + xvfb-run log excerpt + placeholder test result
- `.github/workflows/tests.yml` diff included in PR for code-review

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (this story unblocks all subsequent damage-calc stories)
- Unlocks: Story 002, 008, 009, 010 (and transitively all damage-calc stories)
