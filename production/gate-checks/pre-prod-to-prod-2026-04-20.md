# Gate Check: Pre-Production → Production

**Date**: 2026-04-20
**Checked by**: `/gate-check production` (lean mode)
**Scope**: Artifact + quality check only — director panel skipped (self-evident FAIL; all four directors would return NOT READY given missing VS + epics + control manifest).

---

## Required Artifacts: 7/16 present

| # | Artifact | Status | Notes |
|---|----------|--------|-------|
| 1 | Art bible (9 sections) | ✅ | `design/art/art-bible.md` — 9/9 sections |
| 2 | ≥3 Foundation ADRs | ✅ | 4 ADRs present (GameBus, SceneManager, Save/Load, MapGrid) |
| 3 | Master architecture doc | ✅ | `docs/architecture/architecture.md` + traceability + review report |
| 4 | Accessibility requirements | ✅ | `design/ux/accessibility-requirements.md` (tier committed) |
| 5 | Interaction pattern library | ✅ | `design/ux/interaction-patterns.md` |
| 6 | Test framework + CI workflow | ✅ | `tests/` scaffolded + `.github/workflows/tests.yml` |
| 7 | HUD design doc | ⚠️ | `design/ux/battle-hud.md` present; gate spec asks for `hud.md` — accepted as equivalent (this game has no cross-mode HUD shared between battle and world) |
| 8 | MVP GDDs complete | ✅ | 14 GDDs + systems-index + game-concept; all APPROVED via `/design-review` |
| 9 | Character visual profiles | ❌ | Missing — only `art-bible.md` in `design/art/`. Key hero visual profiles not authored |
| 10 | `prototypes/` with README | ❌ | Directory empty / missing |
| 11 | First sprint plan `production/sprints/` | ❌ | Missing |
| 12 | Epics in `production/epics/` (Foundation + Core) | ❌ | Missing |
| 13 | Control manifest `docs/architecture/control-manifest.md` | ❌ | Missing — blocks epic creation |
| 14 | Main menu UX spec | ❌ | Missing |
| 15 | Pause menu UX spec | ❌ | Missing |
| 16 | **Vertical Slice build — playable** | ❌ | `src/` contains only placeholder CLAUDE.md |
| 17 | Vertical Slice 3+ playtest reports | ❌ | No VS → no playtests possible |

---

## Quality Checks: Deferred

All quality checks presume Vertical Slice existence (core loop fun validation, playtest data review, fun hypothesis validation). Not assessable in current state.

---

## Verdict: **FAIL**

Rationale: 9 of 17 required artifacts missing, including the two automatic-FAIL items from the gate spec:
- **Vertical Slice build is absent** — "Advancing without a validated Vertical Slice is the #1 cause of production failure" (gate-spec Vertical Slice Validation block)
- **No epics/stories** — Production phase is defined by Epic/Feature/Task tracking; cannot track what doesn't exist

No verdict-to-FAIL downgrade debate is meaningful here. The project is well-positioned in late Pre-Production but has not begun Pre-Production → Production prep.

---

## Minimal Path to PASS (ordered)

Each step unblocks the next:

1. **`/create-control-manifest`** — Extract programmer-actionable rules from 4 Accepted ADRs + technical-preferences + engine reference. Unblocks epics.
2. **`/create-epics`** — Decompose architecture into epics. `/create-epics layer: foundation` first, then `/create-epics layer: core`. Unblocks stories.
3. **`/create-stories [epic-slug]`** (per epic) — Break each epic into implementable stories with TR-ID, ADR ref, acceptance criteria.
4. **`/sprint-plan`** — Construct first sprint from story backlog. Creates `production/sprints/sprint-01.md`.
5. **Character visual profiles** — For key heroes referenced in narrative/GDDs, author profiles in `design/art/characters/[hero-name].md` (blocked on art-director spec). Can be deferred to first Production sprint if documented as TK.
6. **Main menu + Pause menu UX specs** — `/ux-design main-menu`, `/ux-design pause-menu`. Can parallel to epic authoring.
7. **Prototype (Vertical Slice skeleton)** — `prototypes/vertical-slice/` with README describing scope. Actual build happens via `/dev-story` cycle after sprint 1 kicks off.
8. **Vertical Slice implementation** — Execute sprint 1 (`/dev-story` per story). Integrated build must demonstrate one complete [start → challenge → resolution] cycle.
9. **3+ playtest sessions on VS** — Internal playtests OK. Use `/playtest-report` to capture.
10. **Re-run `/gate-check production`** — Expect PASS.

**Estimated time to PASS**: 2-4 weeks solo depending on VS scope. The 1st-order blockers (items 1-4) are paperwork (~1 day). Items 5-9 are the real work.

---

## Recommendations (non-blocking)

- **HUD path normalization**: Consider symlinking or renaming `design/ux/battle-hud.md` → `design/ux/hud.md`, or document in the UX index that `battle-hud.md` satisfies the HUD-design gate requirement. Prevents future gate checks from flagging path mismatch.
- **Character profiles early**: If narrative-director has authored hero lore, art-director should spec character profiles in parallel with epic/story authoring — they unblock asset generation during Production.
- **Damage Calc triad process insights** (pass-5 recursive-fabrication / pass-6 compute-don't-read / pass-9 change-the-cell-forget-the-citer) should be carried forward into code review discipline when Production begins — document in control manifest.

---

## Next action

`/create-control-manifest` (session plan already approved).

**Chain-of-Verification**: 5 questions checked against artifacts — verdict unchanged (FAIL with 9 missing required artifacts, 2 auto-FAIL conditions triggered: no VS, no epics).
