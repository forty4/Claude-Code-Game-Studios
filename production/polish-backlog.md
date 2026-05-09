# Polish-tier Backlog

> **Established**: 2026-05-08 (sprint-11 S11-06; closes sprint-10 retro AI #7)
> **Owner**: producer (intake) + technical-artist / qa-tester / writer (per-entry as routed)

---

## Purpose

This file tracks **Polish-tier work items** — non-blocking deferrals that surface during MVP epic closures, ADR verification passes, or QA reviews and that are explicitly NOT meant for the in-flight sprint. Polish-tier items are picked up during the **Polish phase** of the project lifecycle (between MVP feature-complete and Release stage), or earlier if a forcing function fires.

Distinct from:

| Artifact class | Used for | This file is NOT for |
|---|---|---|
| `production/sprint-status.yaml` carryover-backlog section | In-flight sprint deferrals (1-2 sprint horizon) | Items expected to close within the next sprint |
| `production/decisions/` | Binding cross-sprint scope/process decisions | Decisions that bind future work; not item-tracking |
| `production/qa/bugs/` | Bugs (defects from intended behavior) | Bug reports — those track defects, not deferred polish |
| `docs/tech-debt-register.md` | Code-quality debt (refactor candidates) | Code-level debt — that is a separate ledger |

If an item fits one of those, route it there instead.

## Intake Criteria

An item belongs in this backlog when ALL of:

1. It surfaced in a story-close, ADR verification pass, gate-check, or retro as **ADVISORY** (not BLOCKING).
2. It does not have a forcing function in the next 1-2 sprints (otherwise it goes to `sprint-status.yaml` carryover-backlog).
3. It is not a binding scope/process commitment (otherwise it goes to `production/decisions/`).
4. It is not a defect (otherwise it goes to `production/qa/bugs/`).
5. It is not a code-quality refactor candidate (otherwise it goes to `docs/tech-debt-register.md`).

## Entry Format

Every entry uses this template:

```markdown
### POLISH-NNN — {short title}

| Field | Value |
|---|---|
| **Source** | {story file / ADR / retro / sprint plan path:line} |
| **Tier** | ADVISORY (default) / BLOCKING-at-{trigger} |
| **Closure trigger** | {what condition fires pickup — Polish phase entry / specific milestone / explicit user request / count threshold} |
| **Owner** | {role or specific agent at pickup time; "unassigned" until close} |
| **Status** | Open / In-progress / Resolved / Cancelled |
| **Added** | YYYY-MM-DD |
| **Resolved** | YYYY-MM-DD (filled at close) |

**Description**: 1-3 sentences stating what the deferred item is.

**Action when picked up**: 1-2 sentences stating the specific change/check needed.

**Cross-references**: bullet list of file:line references.
```

- IDs are sequential `POLISH-001`, `POLISH-002`, ...
- New entries append to the end of the §Live Entries section.
- Resolved/Cancelled entries stay in place — Status field changes; entry is NOT deleted.
- The §Index tables at the bottom are regenerated when entries are added/resolved.

## Pickup Discipline

- The producer scans this file at every gate-check pass to verify no Polish-tier item has accumulated a forcing function (would graduate to BLOCKING).
- At Polish-phase entry (when `production/stage.txt` flips Pre-Production → Polish), all Open entries are reviewed in a single producer pass; each is either scheduled into a Polish-phase sprint, deferred to a later trigger, or cancelled with rationale.
- Status flips Open → In-progress when a sprint task references the POLISH-NNN ID in its Acceptance Criteria.
- Status flips In-progress → Resolved when the sprint task ships AND the linked artifact is updated.

## Cross-Reference Contract

Every entry must back-reference (in its **Cross-references** field):

- The originating story / ADR / retro line where it first surfaced
- Any future sprint plan that schedules it (forward reference added at scheduling time)
- The closure artifact (test, doc edit, lint) once Resolved

When a sprint task is authored to address a POLISH-NNN entry, the sprint plan task row should cite the entry ID verbatim so grep finds the link.

---

## Live Entries

### POLISH-001 — Battle HUD story-008 title says "6 CI Lints" but body enumerates 7

| Field | Value |
|---|---|
| **Source** | `production/qa/evidence/battle_hud_verification_summary.md` line 167 + `production/epics/battle-hud/story-008-epic-terminal-lints-and-verification.md` (story title field) |
| **Tier** | ADVISORY |
| **Closure trigger** | Polish-phase doc-correction sweep OR next time the story file is touched for any reason |
| **Owner** | unassigned (writer or claude at pickup) |
| **Status** | Open |
| **Added** | 2026-05-08 |
| **Resolved** | — |

**Description**: Story-008's title field says "6 CI Lints" but the story body, ADR-0015 §Engine Verification, and the shipped lint suite all enumerate 7 lints (Lint 1 + 2 + 3 + 4 + 5 + 6 + Lint 7 BalanceConstants key-presence). The 7-lint reality is the source of truth.

**Action when picked up**: Edit story-008's title field from "6 CI Lints" to "7 CI Lints" (or "7 forbidden-pattern lints"). Verify no downstream cite-by-title in EPIC.md / index.md / sprint-status-history.md.

**Cross-references**:
- Source: `production/qa/evidence/battle_hud_verification_summary.md` §ADVISORY Deviations item 1
- Lint suite reality: `production/qa/evidence/battle_hud_verification_summary.md` §7 Forbidden-Pattern Lints — Master Inventory (table at line 147)

### POLISH-002 — Battle HUD story-008 Implementation Notes #1 claims "grid-battle-controller 4-lints"

| Field | Value |
|---|---|
| **Source** | `production/qa/evidence/battle_hud_verification_summary.md` line 168 + `production/epics/battle-hud/story-008-epic-terminal-lints-and-verification.md` (Implementation Notes section) |
| **Tier** | ADVISORY |
| **Closure trigger** | Polish-phase doc-correction sweep OR next grid-battle-controller-lint count audit |
| **Owner** | unassigned |
| **Status** | Open |
| **Added** | 2026-05-08 |
| **Resolved** | — |

**Description**: Implementation Notes #1 in story-008 claims grid-battle-controller has 4 lints. Actual count is 3 lints (`signal_emission_outside_battle_domain` + `static_state` + `external_combat_math`); `balance_entities_grid_battle_controller` is the 4th, but it's a key-presence balance lint, not a forbidden-pattern lint, so the count claim is shape-correct but slightly off in classification.

**Action when picked up**: Edit Implementation Notes #1 in story-008 to say "grid-battle-controller 3 forbidden-pattern lints + 1 BalanceConstants key-presence lint" (or equivalent precise phrasing).

**Cross-references**:
- Source: `production/qa/evidence/battle_hud_verification_summary.md` §ADVISORY Deviations item 2

### POLISH-003 — AC-10 references `tests/gdunit4_runner.gd` which does not exist

| Field | Value |
|---|---|
| **Source** | `production/qa/evidence/battle_hud_verification_summary.md` line 169 + `production/epics/battle-hud/story-008-epic-terminal-lints-and-verification.md` AC-10 + `CLAUDE.md` Coding Standards section (project-wide pattern) |
| **Tier** | ADVISORY |
| **Closure trigger** | Polish-phase doc-correction sweep — the wording is project-wide (CLAUDE.md mentions same path), so a sweep across all references should land in one PR |
| **Owner** | unassigned (devops-engineer + writer at pickup) |
| **Status** | Open |
| **Added** | 2026-05-08 |
| **Resolved** | — |

**Description**: AC-10 in story-008 (and `CLAUDE.md` Coding Standards line "godot --headless --script tests/gdunit4_runner.gd") references a runner file that does not exist. The actual CI runner is `MikeSchulze/gdUnit4-action@v1` invoked via `.github/workflows/tests.yml`. The smoke test invocation pattern works because the addon is invoked directly; the doc reference is a stale wording artifact.

**Action when picked up**: Find all references to `tests/gdunit4_runner.gd` across the repo (`grep -rn "gdunit4_runner.gd"`); replace with the action-based invocation pattern OR delete the line if redundant. Verify `.github/workflows/tests.yml` is the only file naming the runner correctly.

**Cross-references**:
- Source: `production/qa/evidence/battle_hud_verification_summary.md` §ADVISORY Deviations item 3
- Affected file: `CLAUDE.md` Coding Standards (engine-specific CI commands subsection)
- Authoritative runner: `.github/workflows/tests.yml`

### POLISH-004 — Lint 5 whitelist allows format-strings with embedded English prose

| Field | Value |
|---|---|
| **Source** | `production/qa/evidence/battle_hud_verification_summary.md` line 170 + `tools/ci/lint_battle_hud_no_hardcoded_strings.sh` (Lint 5) + `src/feature/battle_hud/battle_hud.gd` strings cited at lines 711/714/721/918/921 |
| **Tier** | ADVISORY (graduates to BLOCKING-at-i18n-pass when localization sprint begins) |
| **Closure trigger** | First localization sprint OR `/localize` skill first run OR explicit user request to harden i18n discipline |
| **Owner** | unassigned (localization-lead at pickup) |
| **Status** | Open |
| **Added** | 2026-05-08 |
| **Resolved** | — |

**Description**: Lint 5 (`lint_battle_hud_no_hardcoded_strings.sh`) currently whitelists format-strings with `%[ds]` specifiers. This means strings like `"Round %d"`, `"Turn: %s"`, `"Upcoming: %s"` pass the lint despite containing English prose ("Round", "Turn:", "Upcoming:") that should be localized. The lint's intent (catch fully-hardcoded English literals) is satisfied; the gap is partial-hardcoded prose embedded in format strings.

**Action when picked up**: Refactor the affected strings in `battle_hud.gd` (lines 711/714/721/918/921 are the existing-good `tr()`-prefix pattern; the offending strings are elsewhere in the file — `grep -n '"[A-Z][a-z].*%[ds]"' src/feature/battle_hud/battle_hud.gd` to enumerate). Then tighten Lint 5 to also reject format-strings with embedded `[A-Za-z]{4,}` outside of `tr()` calls. Run `/localize` to propagate.

**Cross-references**:
- Source: `production/qa/evidence/battle_hud_verification_summary.md` §ADVISORY Deviations item 4
- Lint script: `tools/ci/lint_battle_hud_no_hardcoded_strings.sh`
- Existing-good pattern: `src/feature/battle_hud/battle_hud.gd` lines 711/714/721/918/921 (tr()-prefix usage)

### POLISH-005 — Em-dash placeholder hoisted to const `_COUNTER_PLACEHOLDER_DASH`

| Field | Value |
|---|---|
| **Source** | `production/qa/evidence/battle_hud_verification_summary.md` line 171 + `src/feature/battle_hud/battle_hud.gd` line 96 (const declaration with inline rationale comment) |
| **Tier** | ADVISORY |
| **Closure trigger** | Resolves automatically when POLISH-004 closes (the const exists to keep Lint 5 clean; if Lint 5 is tightened, the const may be removable or refactored to a `tr()` lookup) |
| **Owner** | unassigned |
| **Status** | Open |
| **Added** | 2026-05-08 |
| **Resolved** | — |

**Description**: An em-dash placeholder was hoisted to a module-level const `_COUNTER_PLACEHOLDER_DASH` to keep Lint 5 happy without disabling the lint. This is a small refactor whose rationale is documented inline at the const declaration. When POLISH-004 lands, this const may be removable (if the em-dash is replaced by a `tr()` lookup) or remain as the canonical placeholder reference.

**Action when picked up**: Re-evaluate after POLISH-004 lands. If POLISH-004 introduces a `tr()` lookup that subsumes the em-dash placeholder, remove the const. If the const stays, verify the inline rationale comment is still accurate and matches the post-POLISH-004 lint behavior.

**Cross-references**:
- Source: `production/qa/evidence/battle_hud_verification_summary.md` §ADVISORY Deviations item 5
- Const declaration: `src/feature/battle_hud/battle_hud.gd` line 96
- Dependent on: POLISH-004 closure

### POLISH-006 — Guan Yu + Zhang Fei character visual profile stubs (DESCOPED carryover from sprint-10 S10-07)

| Field | Value |
|---|---|
| **Source** | `production/gate-checks/pre-prod-to-prod-2026-05-08.md` line 136 (NEW ADVISORY-CANDIDATE flagged at gate-check) + `production/gate-checks/pre-prod-to-prod-2026-05-08-rerun.md` line 142 (ADVISORY-1 carried) + `production/sprints/sprint-11.md` S11-09 (Liu Bei first-stub-shipped partial-state closure) + sprint-10 retro AI #5 (3-stub → 1-stub DESCOPE decision) |
| **Tier** | ADVISORY (graduates to BLOCKING-at-character-art-sprint-entry: stubs MUST land before any character-art commission sprint closes story-readiness; ALSO graduates to BLOCKING-at-Polish-gate per gate-check rerun line 142 "must resolve before Polish gate") |
| **Closure trigger** | (a) FIRST: any sprint plan adds a character-art commission story (forcing function — stubs must precede commission); OR (b) `production/stage.txt` content equals `Polish` (Polish gate hard-blocker per gate-check rerun); whichever fires first |
| **Owner** | unassigned (art-director at pickup; claude may co-author with art-director routing) |
| **Status** | Open |
| **Added** | 2026-05-09 |
| **Resolved** | — |

**Description**: Guan Yu (관우 / 关羽 / 云长 — `shu_002_guan_yu` per `assets/data/heroes/heroes.json`) and Zhang Fei (장비 / 张飞 / 翼德 — `shu_003_zhang_fei`) character visual profile stubs remain unauthored. Original 3-stub scope (sprint-10 S10-07: Liu Bei + Guan Yu + Zhang Fei) was DESCOPED at sprint-10 retro AI #5 to 1 stub when sprint-11 absorbed the carryover via S11-09 (Liu Bei only at `design/art/characters/liu-bei.md`). The 1-stub closure satisfied AD-C5 to "first-stub-shipped partial state" but explicitly did NOT cancel Guan Yu + Zhang Fei — they must land before character-art production begins, per the silhouette-distinguishability benchmark established by the Liu Bei stub (Pillar 4 minimum recognition triplet + reserved-color discipline). The Peach Garden Oath triangle composition documented in liu-bei.md cross-references both characters as `SWORN_BROTHER` per `heroes.json` `bond_oath_peach_garden` symmetric relations — so the triangle is structurally incomplete until both Guan Yu + Zhang Fei stubs ship.

**Action when picked up**: Author `design/art/characters/guan-yu.md` + `design/art/characters/zhang-fei.md` mirroring the Liu Bei stub format (Sections 1-3 minimum: silhouette + costume + role-anchor). Canonical anchors from `assets/data/heroes/heroes.json`: Guan Yu = COMMANDER class (per heroes.json class field), bond effect `bond_oath_peach_garden` (SWORN_BROTHER symmetric with Liu Bei + Zhang Fei), portrait_id `portrait_shu_guan_yu`, battle_sprite_id `sprite_shu_guan_yu`; Zhang Fei = COMMANDER class (verify per heroes.json), same Peach Garden Oath bond, portrait_id `portrait_shu_zhang_fei`, battle_sprite_id `sprite_shu_zhang_fei`. Pillar 4 minimum recognition triplet must be defined per stub (visual signature distinguishable in a 32px silhouette; non-default color allocation respects reserved-color discipline — 주홍 `#C0392B` and 금색 `#D4A017` are reserved for destiny-branch reveals only). Peach Garden Oath triangle composition update: Liu Bei stub already documents the triangle anchor; Guan Yu + Zhang Fei stubs should cite it back with their relative positioning rationale (Guan Yu typically associated with halberd 偃月刀 + full beard 美髯公; Zhang Fei with 蛇矛 + bristled-hog beard + dark complexion per traditional iconography). 8 ACs target per Liu Bei stub format; 5 OQs deferred per same. Verify no reserved-color baseline violation. Cross-bind to art-bible.md ink-wash palette + game-concept.md Pillar 4 (삼국지의 숨결).

**Cross-references**:
- Source flag: `production/gate-checks/pre-prod-to-prod-2026-05-08.md` line 136 NEW ADVISORY-CANDIDATE block ("On the descope-to-1-stub risk")
- Carry-forward: `production/gate-checks/pre-prod-to-prod-2026-05-08-rerun.md` line 142 ADVISORY-1 (carried; "must resolve before Polish gate")
- Originating descope: sprint-10 retro AI #5 + sprint-11 S11-09 (Liu Bei) close-out at `production/retrospectives/retro-sprint-11-2026-05-08.md` "What Went Well" item 7 (descope-not-cancel pattern)
- Reference stub (silhouette-distinguishability benchmark): `design/art/characters/liu-bei.md` (Sections 1-3 + 8 ACs + 5 OQs + Peach Garden Oath triangle anchor)
- Canonical character data: `assets/data/heroes/heroes.json` keys `shu_002_guan_yu` + `shu_003_zhang_fei` (name_ko + name_zh + name_courtesy + class + portrait_id + battle_sprite_id + bond relations)
- Sprint-12 plan row: `production/sprints/sprint-12.md` S12-08 (this entry's authoring task)
- AD-C5 partial-state closure: gate-check 2026-05-08 (AD-C5 closed to first-stub-shipped via Liu Bei; remains "first-stub-shipped" until Guan Yu + Zhang Fei land)
- Closure trigger (a) monitoring: any future sprint plan in `production/sprints/` containing scope referencing character-art commission OR portrait/sprite asset production
- Closure trigger (b) monitoring: `production/stage.txt` content (when flips to `Polish`)
- Cross-binding: `design/art/art-bible.md` ink-wash palette + reserved-color discipline; `design/game-concept.md` Pillar 4 (삼국지의 숨결) experiential bar

### POLISH-007 — GameBus soft cap exceeded (391 turn-domain emits per frame) under headless run

| Field | Value |
|---|---|
| **Source** | Headless boot of `scenes/battle/battle_scene.tscn` main_scene (sprint-13 mid-plan amendment 2026-05-09 PM Production VS bug surfacing) |
| **Tier** | ADVISORY (perf calibration; not a defect — headless artifact + no observable player impact at 60fps with UI animations) |
| **Closure trigger** | (a) Any future sprint plan with perf-budget hardening scope; OR (b) `production/stage.txt` flips to `Polish`; OR (c) a real-play F5 session reveals soft-cap warnings DURING gameplay (not just at headless exit) |
| **Owner** | unassigned (performance-analyst at pickup) |
| **Status** | Open |
| **Added** | 2026-05-09 |
| **Resolved** | — |

**Description**: Headless boot of the main_scene (`scenes/battle/battle_scene.tscn`) for ~5 seconds produced `WARNING: GameBus soft cap exceeded: 401 emits this frame (cap=50). Top domains: [scenario=3, battle=0, turn=391, unit=0, destiny=0, beat=1, input=1, ui=3, save=2, environment=0]` from `src/core/game_bus_diagnostics.gd:179`. Root cause hypothesis: AISystem `decide()` runs SYNCHRONOUSLY in headless mode without UI/animation gating; full battles complete in 1 frame; per-turn signals (`unit_turn_started` + `unit_turn_ended` × N units × M rounds) accumulate beyond the 50/frame soft-cap budget. In normal player F5 (60fps + animations + UI dwell), turn cadence is naturally rate-limited.

**Action when picked up**: (1) Run `godot --headless --path . --quit-after 5 --verbose` to confirm the per-domain breakdown matches the hypothesis (`turn=391` is the dominant contributor); (2) Decide between options: (A) increase headless soft-cap to 500 with comment explaining the artifact; (B) add `_process_test_mode` flag to TurnOrderRunner that disables soft-cap in headless; (C) batch emit to amortize across N frames in headless. Recommended: option A (least invasive). (3) Verify normal player F5 produces NO soft-cap warnings; if it does, this graduates to a real perf concern requiring deeper investigation.

**Cross-references**:
- Source: `src/core/game_bus_diagnostics.gd:179` (`_fire_soft_cap_warning`)
- Top domain reading: `src/core/turn_order_runner.gd:530/553/566` (`round_started`, `unit_turn_started`, `unit_turn_ended` emit sites)
- Soft-cap baseline: `BalanceConstants.GAMEBUS_SOFT_CAP_PER_FRAME` (search to confirm; may be hard-coded in diagnostics)
- Sprint-13 row: `production/sprints/sprint-13.md` Mid-Sprint Expansion section (entry note: bug #3 of 4 surfaced; deferred to POLISH-007)

### POLISH-008 — ObjectDB instances leaked at exit (1+ orphan)

| Field | Value |
|---|---|
| **Source** | Headless boot of `scenes/battle/battle_scene.tscn` main_scene (sprint-13 mid-plan amendment 2026-05-09 PM Production VS bug surfacing) |
| **Tier** | ADVISORY (defect-tier; LOW severity — exit-time leak, no in-session impact; NOT routed to `production/qa/bugs/` because closure is calibration-tier not behavioral-fix) |
| **Closure trigger** | (a) `production/stage.txt` flips to `Polish`; OR (b) memory ceiling pressure surfaces during multi-chapter playtests (sprint-14+ scenarios) |
| **Owner** | unassigned (performance-analyst or godot-gdscript-specialist at pickup) |
| **Status** | Open |
| **Added** | 2026-05-09 |
| **Resolved** | — |

**Description**: Headless boot of the main_scene at exit produced `WARNING: ObjectDB instances leaked at exit (run with --verbose for details).` Specific leaked instance(s) not yet identified. Common Godot 4.6 leak sources: orphan Nodes from `queue_free()` deferred past quit, RefCounted cycles, autoload-scoped Resources held by static state, signal connections referencing freed callables. Cross-reference G-6 (orphan detection between test exit and after_test) for related test-side patterns; this exit-time leak is production-side, not test-side.

**Action when picked up**: (1) Re-run with `--verbose` flag: `godot --headless --path . --quit-after 5 --verbose 2>&1 | grep -A5 "ObjectDB instances leaked"` to identify the leaked class + instance address. (2) Likely candidates per project history: TurnOrderRunner internal queue, BattleStateSnapshot RefCounted cache, BattleHUD subscriber Callables. (3) Add `_exit_tree()` cleanup or `reset_for_tests()` analog if a battle-scoped Node is the source. (4) Re-run; verify clean exit `WARNING: ObjectDB ...` line absent.

**Cross-references**:
- G-6 (orphan detection between test body exit and `after_test`) — `.claude/rules/godot-4x-gotchas.md`
- G-28 (bulk-disconnect-all severs production subscriptions) — same file
- Sprint-13 row: `production/sprints/sprint-13.md` Mid-Sprint Expansion section (entry note: bug #4 of 4 surfaced; deferred to POLISH-008)

### POLISH-009 — Missing `res://scenes/battle/mvp_chapter_01.tscn` referenced by mvp_shu.json

| Field | Value |
|---|---|
| **Source** | S13-11 + S13-12 headless verification 2026-05-09 PM late + S13-10 user windowed boot 2026-05-09 PM late (3 independent surfacings) |
| **Tier** | DEFECT (asset-content gap; LOW severity for headless logic but **likely contributing cause of POLISH-010 visual rendering failure**) |
| **Closure trigger** | (a) Bundled with POLISH-010 fix at sprint-14 entry; OR (b) authored as part of map-data epic (currently PROVISIONAL per `design/gdd/systems-index.md`) |
| **Owner** | unassigned (level-designer + godot-specialist at pickup) |
| **Status** | Open |
| **Added** | 2026-05-09 |
| **Resolved** | — |

**Description**: `assets/data/scenarios/mvp_shu.json:8` declares `"map_id": "mvp_chapter_01"`. The chapter loader at `BattleScene._build_map_resource_for_chapter()` (or upstream resolver) attempts to load `res://scenes/battle/mvp_chapter_01.tscn` (or `assets/data/maps/mvp_chapter_01.tres`) and fails with `ERROR: Cannot open file 'res://scenes/battle/mvp_chapter_01.tscn'. ERROR: Failed loading resource: ...`. Fallback path in `battle_scene.gd:_build_map_resource_for_chapter()` synthesizes a 15×15 all-grass MapResource so the battle CAN proceed in headless mode (391 turn-domain emits confirm logic flow), but in windowed mode the fallback grid does NOT render visibly (see POLISH-010).

**Action when picked up**: (1) Author `assets/data/maps/mvp_chapter_01.tres` (canonical MapResource path per ADR-0016 §4) — 15×15 grid with bridge tile pattern matching prototype-chapter-prototype; (2) Or relocate the load attempt to use the existing fallback synthesis as the canonical path (rename map_id to a synthetic-only key); (3) Verify `mvp_shu.json` map_id alignment with the actual file path the loader expects.

**Cross-references**:
- Surfacing 1: `production/session-state/active.md` (S13-11 verification re-run; deferred at S13-11 close-out as candidate)
- Surfacing 2: S13-12 headless verification — same ERROR
- Surfacing 3: S13-10 user windowed boot 2026-05-09 PM late — same ERROR + correlates with POLISH-010 visual rendering failure
- Source data: `assets/data/scenarios/mvp_shu.json:8`
- Loader: `src/feature/battle_scene/battle_scene.gd:_build_map_resource_for_chapter()` (fallback path)

### POLISH-010 — Production main_scene `scenes/battle/battle_scene.tscn` does not render battle visuals in windowed mode

| Field | Value |
|---|---|
| **Source** | S13-10 USER-OWNED attestation 2026-05-09 PM late (sprint-13) |
| **Tier** | DEFECT (HIGH severity — release-blocker; production main_scene boots cleanly but renders blank to screen; user attests "배틀화면 안 보임"; gates `/gate-check pre-prod-to-prod` PASS verdict) |
| **Closure trigger** | (a) MUST resolve before production stage advancement (gate-check rerun verdict cannot return PASS while POLISH-010 open); OR (b) sprint-14 dedicated bug-fix sprint absorbs |
| **Owner** | unassigned (godot-gdscript-specialist + technical-artist at pickup) |
| **Status** | Open |
| **Added** | 2026-05-09 |
| **Resolved** | — |

**Description**: User booted production build (`godot --path .` → main_scene `scenes/battle/battle_scene.tscn`). Window opened cleanly (Metal renderer / Forward Mobile / M4 Pro / engine init clean per stdout); battle visuals did NOT render to screen — user reports "윈도우는 떴음. 배틀화면 안 보임. 그래서 클릭/탭 해보지 못함." Headless boot of the same scene (S13-12 verification) shows game logic runs end-to-end with 391 turn-domain emits + scenario LOAD + AI dispatch all clean, so backend functionality is intact. Failure is rendering-layer / scene-layout / camera-positioning. **This is a production VS release-blocker** — main_scene must render visibly for any user-attestation path to verify gameplay.

**Likely root causes (investigation order)**:
1. **POLISH-009 cascade**: missing `mvp_chapter_01.tscn` triggers fallback `_build_map_resource_for_chapter()` → 15×15 grass synthesis, which may not include visual children (sprites / placeholder ColorRects) — fix POLISH-009 first, retest.
2. **BattleCamera positioning**: ADR-0014 §1 mandates camera setup-before-add_child; if camera viewport / zoom is unset for the synthetic fallback map dimensions, the visible region may be off-screen.
3. **Layer ordering**: `_grid_layer` Node2D at `battle_scene.gd:50` mounts overlays; if z-index / canvas-layer setup expects authored-tscn structure, runtime-built fallback may render to wrong layer.
4. **Scene-tree-light vs full instantiate**: BattleScene extends Node2D + has @onready scene-tree references (`$GridLayer` etc.); if those nodes are populated only by the missing tscn, they're null at runtime and child-mount paths silently fail.

**Action when picked up**: (1) Boot `godot --path . --verbose 2>&1 | head -100` to capture full init log; check for missing-node warnings beyond the mvp_chapter_01.tscn ERROR. (2) Take screenshot of windowed boot to attach as evidence in this entry. (3) Run `godot --debug` to attach Godot's runtime inspector — verify scene tree contents at runtime against expected hierarchy. (4) Bundle fix with POLISH-009 — likely single fix resolves both. (5) Add a smoke-tier "visual not blank" test to CI (verification gap exposed at sprint-13 retro AI #x; current 1288-test suite gates logic but not rendering).

**Verification gap pattern (sprint-13 retro AI seed)**:
The 1288/1288 PASS / 66th FFB baseline gates LOGIC correctness but does not gate VISUAL PRESENCE of the production main_scene. Headless tests CAN'T detect blank-window symptoms because they run with `--headless` (no rendering pipeline). This pattern surfaced at S13-10 attestation; sprint-13 retro must address: should there be a CI smoke test that boots windowed + screenshots + asserts non-blank? (Cross-reference POLISH-008 ObjectDB leak which surfaced via similar headless-only verification gap.)

**Cross-references**:
- Surfacing source: S13-10 attestation at `production/qa/qa-signoff-sprint-8-2026-05-06.md` §S8-15 USER-OWNED Attestation Batch 1.2 FAIL
- Likely cause: POLISH-009 (missing map fixture)
- Affected scene: `src/feature/battle_scene/battle_scene.gd` + `scenes/battle/battle_scene.tscn`
- Headless verification (passes): S13-11 / S13-12 verification logs (391 turn-domain emits)
- gate-check binding: `production/gate-checks/pre-prod-to-prod-2026-05-?-rerun-2.md` will list this as path-to-PASS item (S13-03 close-gate rerun)

---

## Index — by Status

| Status | Count | IDs |
|---|---|---|
| Open | 10 | POLISH-001 / POLISH-002 / POLISH-003 / POLISH-004 / POLISH-005 / POLISH-006 / POLISH-007 / POLISH-008 / POLISH-009 / POLISH-010 |
| In-progress | 0 | — |
| Resolved | 0 | — |
| Cancelled | 0 | — |

## Index — by Source

| Source | IDs |
|---|---|
| Battle HUD epic verification (story-008) | POLISH-001 / POLISH-002 / POLISH-003 / POLISH-004 / POLISH-005 |
| Gate-check 2026-05-08 ADVISORY-CANDIDATE (carried into 2026-05-08-rerun ADVISORY-1) | POLISH-006 |
| Sprint-13 mid-plan Production VS bug surfacing (2026-05-09 PM headless boot deferred non-blocker tier) | POLISH-007 / POLISH-008 |
| S13-11 + S13-12 + S13-10 verification surfacings (2026-05-09 PM late) | POLISH-009 / POLISH-010 |

## Index — by Closure Trigger

| Trigger | IDs |
|---|---|
| Polish-phase doc-correction sweep | POLISH-001 / POLISH-002 / POLISH-003 |
| Localization sprint OR `/localize` first run | POLISH-004 |
| Cascade from POLISH-004 closure | POLISH-005 |
| Character-art commission sprint enters planning (forcing function) OR Polish gate (`production/stage.txt` = `Polish`) | POLISH-006 |
| Bundled at sprint-14 entry (POLISH-009 likely root cause of POLISH-010) | POLISH-009 / POLISH-010 |

---

## Amendment log

*Append future amendments below — do not rewrite the body above.*

- 2026-05-08 — Initial backlog established (sprint-11 S11-06 close-out; 5 ADVISORY entries from battle-hud epic verification summary).
- 2026-05-09 — POLISH-006 added (sprint-12 S12-08 close-out per gate-check 2026-05-08 NEW ADVISORY-CANDIDATE; Guan Yu + Zhang Fei character profile stubs DESCOPED carryover from sprint-10 S10-07 → sprint-11 S11-09 Liu Bei first-stub-shipped). Lightweight conditional path chosen (no character-art sprint scheduled in sprint-12); entry-only authoring per S12-08 spec.
- 2026-05-09 PM — POLISH-007 + POLISH-008 added (sprint-13 mid-plan amendment Production VS bug surfacing; deferred non-blocker tier).
- 2026-05-09 PM late — POLISH-009 + POLISH-010 added (S13-10 USER-OWNED attestation surfaced production main_scene visual rendering FAIL; POLISH-010 is HIGH-tier release-blocker gating gate-check rerun PASS verdict). Verification gap pattern noted for sprint-13 retro: 1288/1288 PASS automated suite gates LOGIC but does not gate VISUAL PRESENCE of production main_scene; headless-only verification cannot surface blank-window symptoms.
