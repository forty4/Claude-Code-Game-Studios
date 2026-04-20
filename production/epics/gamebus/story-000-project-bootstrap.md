# Story 000: Godot 4.6 project + GdUnit4 test harness bootstrap

> **Epic**: gamebus
> **Status**: Ready
> **Layer**: Platform (prerequisite infrastructure)
> **Type**: Config/Data
> **Manifest Version**: 2026-04-20
> **Estimate**: 2 hours (S)

## Context

**GDD**: — (infrastructure bootstrap; no game-design requirement)
**Requirement**: — (N/A — prerequisite for all TR-* implementation)

**ADR Governing Implementation**: ADR-0001, ADR-0002, ADR-0003, ADR-0004
**ADR Decision Summary**: Every Foundation-layer ADR assumes a live Godot 4.6 project with GdUnit4 available. This story creates the substrate so subsequent stories (001..008 and all downstream epics) can author `.gd` files that parse and tests that execute.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (4.6 is post-cutoff; GdUnit4 version must match 4.6)
**Engine Notes**:
- Godot 4.6 defaults: Jolt physics, D3D12 on Windows, Metal on Mac/iOS, Vulkan on Linux/Android, Forward+ Mobile renderer (per `.claude/docs/technical-preferences.md`).
- `project.godot` uses `config_version=5` for 4.x.
- GdUnit4 compatibility: pin to a version tagged for Godot 4.6 (check Asset Library or releases page at author time).

**Control Manifest Rules (Global)**:
- Required: `project.godot` targets Godot 4.6; no custom `--rendering-driver` overrides (trust engine defaults per technical-preferences)
- Required: Autoload block present and **empty** (Story 002 populates GameBus as first entry)
- Required: GdUnit4 installed at `addons/gdUnit4/` OR available via CI action
- Forbidden: Committing `.godot/` cache directory (gitignored)
- Forbidden: Hardcoding rendering driver per-platform in the project file

## Acceptance Criteria

- [ ] `project.godot` exists at repo root with:
  - `config_version=5`
  - `[application]` section with `config/name="천명역전"`, `config/features=PackedStringArray("4.6")` (renderer tag is NOT stored in features — renderer is selected via `renderer/rendering_method` in `[rendering]`, verified against 4.6 godot-demo-projects)
  - `[physics]` section selecting Jolt (`3d/physics_engine="Jolt Physics"` — or 2D equivalent)
  - `[rendering]` section declaring `renderer/rendering_method="mobile"`
  - `[autoload]` section present but **empty** (populated by Story 002)
  - Directory import settings left at defaults
- [ ] `src/` subdirectories created per `.claude/docs/directory-structure.md`: `src/core/`, `src/gameplay/`, `src/ai/`, `src/networking/`, `src/ui/`, `src/tools/` (each with a `.gitkeep` placeholder)
- [ ] `addons/gdUnit4/` installed (git submodule OR vendored checkout, version compatible with Godot 4.6) and committed
- [ ] `.gitignore` updated: `.godot/` cache excluded; `addons/gdUnit4/` NOT excluded
- [ ] `tests/unit/example_test.gd` passes: running `godot --headless --import` (one-time class-cache build) followed by `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c` exits with code 0 and reports 3 test cases PASSED
- [ ] CI workflow green: push branch; `.github/workflows/tests.yml` completes with status success (verifies `MikeSchulze/gdUnit4-action@v1` + Godot 4.6 provisioning still works)
- [ ] `project.godot` loads in Godot 4.6 editor without errors or warnings (manual verification — screenshot or note to `production/qa/smoke-2026-04-20.md`)

## Implementation Notes

1. **Minimal project.godot** — keep it lean. Only what's required to boot + run tests. No `run/main_scene` entry yet (no scene exists). Export templates, input map, display/window settings all deferred to later stories.
2. **GdUnit4 install method** — prefer git submodule at `addons/gdUnit4/` pointed at the latest tag compatible with Godot 4.6. Submodule keeps the repo thin and the version pin explicit. Alternative: vendored checkout if submodules cause friction on Windows/corp networks.
3. **Jolt physics** — Godot 4.6 default per technical-preferences. Verify the project file uses the correct property name (4.6 renamed some physics settings from 4.5).
4. **Do NOT add GameBus or any autoload here** — Story 002 owns that. The `[autoload]` block should exist but be empty; Story 002 appends the GameBus entry.
5. **Do NOT create any `.gd` source files under `src/`** — Story 001 creates the first ones. This story only scaffolds directories.
6. **Verify post-cutoff APIs before committing** — cross-check `docs/engine-reference/godot/VERSION.md` for 4.6-specific setting names. The LLM's knowledge predates 4.6; rely on `https://docs.godotengine.org/en/stable/` + the 4.5→4.6 migration guide.

## Out of Scope

- **Story 001**: Payload Resource class authoring
- **Story 002**: GameBus autoload registration in `[autoload]` block
- **Later epics**: Export templates (Android/iOS/PC), input map, display/window config, run/main_scene
- **Polish phase**: Rendering tuning, physics parameter adjustment

## QA Test Cases

*Inline QA specification (lean mode).*

**Test evidence**: `production/qa/smoke-2026-04-20.md` (Config/Data story → smoke check)

- **AC-1** (Project loads): Open `project.godot` in Godot 4.6 editor → zero errors in Output panel → screenshot attached to smoke report.
- **AC-2** (Headless test runner): After `godot --headless --import` (prereq), run `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c` → exit code 0; stdout shows "Statistics: 3 test cases | 0 errors | 0 failures" + "PASSED"; no `push_error` lines.
- **AC-3** (CI runs green): Branch pushed; GitHub Actions `Tests` workflow completes with status `success`; artifact `gdunit4-report` uploaded.
- **AC-4** (Directory structure): `ls src/` shows `core/ gameplay/ ai/ networking/ ui/ tools/`; each contains `.gitkeep`.
- **AC-5** (Autoload block empty + ready): `grep -A2 "^\[autoload\]" project.godot` shows the section header with no autoload entries below it (or only comments).

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-2026-04-20.md` — smoke check pass documenting AC-1..AC-5
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: None (bootstrap story)
- **Unlocks**: Story 001 (payload classes cannot parse without project.godot), Story 002 (autoload registration), all subsequent `.gd` authoring across every epic
