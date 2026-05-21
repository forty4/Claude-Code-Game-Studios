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

### POLISH-009 — Missing `res://scenes/battle/mvp_chapter_01.tscn` referenced by shu_canon_full.json

| Field | Value |
|---|---|
| **Source** | S13-11 + S13-12 headless verification 2026-05-09 PM late + S13-10 user windowed boot 2026-05-09 PM late (3 independent surfacings) |
| **Tier** | DEFECT (asset-content gap; LOW severity for headless logic but **likely contributing cause of POLISH-010 visual rendering failure**) |
| **Closure trigger** | (a) Bundled with POLISH-010 fix at sprint-14 entry; OR (b) authored as part of map-data epic (currently PROVISIONAL per `design/gdd/systems-index.md`) |
| **Owner** | unassigned (level-designer + godot-specialist at pickup) |
| **Status** | Open |
| **Added** | 2026-05-09 |
| **Resolved** | — |

**Description**: `assets/data/scenarios/shu_canon_full.json:8` declares `"map_id": "mvp_chapter_01"`. The chapter loader at `BattleScene._build_map_resource_for_chapter()` (or upstream resolver) attempts to load `res://scenes/battle/mvp_chapter_01.tscn` (or `assets/data/maps/mvp_chapter_01.tres`) and fails with `ERROR: Cannot open file 'res://scenes/battle/mvp_chapter_01.tscn'. ERROR: Failed loading resource: ...`. Fallback path in `battle_scene.gd:_build_map_resource_for_chapter()` synthesizes a 15×15 all-grass MapResource so the battle CAN proceed in headless mode (391 turn-domain emits confirm logic flow), but in windowed mode the fallback grid does NOT render visibly (see POLISH-010).

**Action when picked up**: (1) Author `assets/data/maps/mvp_chapter_01.tres` (canonical MapResource path per ADR-0016 §4) — 15×15 grid with bridge tile pattern matching prototype-chapter-prototype; (2) Or relocate the load attempt to use the existing fallback synthesis as the canonical path (rename map_id to a synthetic-only key); (3) Verify `shu_canon_full.json` map_id alignment with the actual file path the loader expects.

**Cross-references**:
- Surfacing 1: `production/session-state/active.md` (S13-11 verification re-run; deferred at S13-11 close-out as candidate)
- Surfacing 2: S13-12 headless verification — same ERROR
- Surfacing 3: S13-10 user windowed boot 2026-05-09 PM late — same ERROR + correlates with POLISH-010 visual rendering failure
- Source data: `assets/data/scenarios/shu_canon_full.json:8`
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

**ROOT CAUSE (confirmed 2026-05-09 PM late investigation per S13-10 follow-on)**:

Production main_scene `scenes/battle/battle_scene.tscn` is **intentionally a container-only scene** (3 nodes: BattleScene Node2D + GridLayer Node2D + HUDLayer CanvasLayer). All 7 systems mounted at runtime in `BattleScene._ready()` are either pure LOGIC or HUD-only:

| Runtime mount | Type | Visual rendering responsibility |
|---|---|---|
| MapGrid | `extends Node` (NOT Node2D) | NONE — data + lookup only |
| BattleCamera | `extends Camera2D` | NONE — viewport framing only, no `_draw()` |
| HPStatusController | logic | NONE |
| TurnOrderRunner | logic | NONE |
| GridBattleController | controller | NONE — no rendering code |
| AISystem | logic | NONE |
| BattleHUD | mounts 14 prefab `.tscn` files from `scenes/battle/elements/` | HUD chrome only (initiative queue, turn counter, etc.) — renders at screen edges; does NOT render world-space map/units |

**The world-space tile + unit visuals were INTENDED to come from an authored chapter-specific `.tscn` (e.g., `mvp_chapter_01.tscn` = sprites + TileMap + unit Sprite2D children). That file was never created.** This is a content-authoring gap, not a code regression — production main_scene has been "logic-only renderable" since sprint-3 establishment. It worked for headless E2E test coverage (391 turn-domain emits prove the loop runs) but renders blank world-space in windowed mode.

The 4 sprint-3..sprint-10 epics that "shipped" Production VS (Camera / GridBattleController / BattleHUD / BattleScene per session-state phrasing) shipped the LOGIC layer + HUD chrome. The world-space sprite layer was deferred without an explicit epic to track it.

**What user actually sees (consistent with this analysis)**:
- HUD chrome around screen edges (initiative queue, turn-round counter, action menu skeleton, etc.) — likely present but visually subtle without map context
- World-space (center): empty / void / no tiles / no units — this is the "배틀화면 안 보임" experience
- Camera viewport frames an empty world

**Comparison with prototype (`prototypes/chapter-prototype/chapter.tscn`)**: prototype renders properly because `chapter.gd` builds runtime ColorRect + Label visuals (lines 183/206/251/261/329 — `bg.size = Vector2(820, 720)` etc.). Prototype-tier code is in `prototypes/` per `.claude/rules/prototype-code.md` standards (relaxed; placeholder visuals OK). Production code is NOT supposed to use prototype-tier patterns.

**Fix is NOT a 5-line patch**. Two real options:

- **Option A — author `assets/data/maps/mvp_chapter_01.tres` + `scenes/battle/mvp_chapter_01.tscn`**: proper visual layer; canonical path per ADR-0016 §4 + chapter_definition.gd:23 docstring. Estimated: 1-2 hours including sprite/TileMap setup + integration test + visual evidence doc. Sprint-14 epic candidate ("production VS world-space rendering").
- **Option B — port prototype-tier ColorRect rendering into BattleScene as fallback**: 30-50 LoC patch in battle_scene.gd that synthesizes placeholder visuals when no authored-tscn exists. Quick-and-dirty; needs ADR alignment (currently ADR-0014/0016 silent on placeholder fallback); blurs prototype/production tier boundary. NOT recommended unless sprint-14 timeline demands a stop-gap.

**Sprint-13 disposition**: defer fix to sprint-14 (scope-too-large for sprint-13 close window). Sprint-13 closes with `/gate-check pre-prod-to-prod` rerun verdict CONCERNS (POLISH-010 + POLISH-009 listed as path-to-PASS items). `production/stage.txt` Pre-Production → Production flip cannot occur this sprint.

**Action when picked up (sprint-14 epic candidate)**: (1) Decide Option A (author proper visuals) vs Option B (placeholder fallback) vs Option C (Production-level epic for full visual tier including sprites + animations). Recommend Option A baseline + Option C as the longer-term arc. (2) Add CI smoke test that boots windowed (or `--xvfb` with a virtual display) + takes screenshot + asserts non-zero non-clear-color pixels. This closes the verification gap. (3) ADR-0021 candidate: "Production world-space rendering responsibility" — codify which Node mounts the visual layer, what fallback exists, what the prototype/production tier boundary is.

**Verification gap** (sprint-13 retro AI seed — UPDATED with full root cause):
The 1288/1288 PASS / 66th FFB automated suite gates LOGIC + HUD chrome but does NOT gate world-space VISUAL PRESENCE. Headless tests run with `--headless` (no rendering pipeline). Windowed mode reveals architectural content gap that automated tests cannot surface. Sprint-13 retro must address: visual smoke-tier CI test (windowed boot + screenshot + non-blank assertion) is the structural gate that would have caught this 4 sprints ago.

**Verification gap pattern (sprint-13 retro AI seed)**:
The 1288/1288 PASS / 66th FFB baseline gates LOGIC correctness but does not gate VISUAL PRESENCE of the production main_scene. Headless tests CAN'T detect blank-window symptoms because they run with `--headless` (no rendering pipeline). This pattern surfaced at S13-10 attestation; sprint-13 retro must address: should there be a CI smoke test that boots windowed + screenshots + asserts non-blank? (Cross-reference POLISH-008 ObjectDB leak which surfaced via similar headless-only verification gap.)

**Cross-references**:
- Surfacing source: S13-10 attestation at `production/qa/qa-signoff-sprint-8-2026-05-06.md` §S8-15 USER-OWNED Attestation Batch 1.2 FAIL
- Likely cause: POLISH-009 (missing map fixture)
- Affected scene: `src/feature/battle_scene/battle_scene.gd` + `scenes/battle/battle_scene.tscn`
- Headless verification (passes): S13-11 / S13-12 verification logs (391 turn-domain emits)
- gate-check binding: `production/gate-checks/pre-prod-to-prod-2026-05-?-rerun-2.md` will list this as path-to-PASS item (S13-03 close-gate rerun)

### POLISH-011 — Production main_scene input non-responsive in windowed mode (post-S14-02 visual fix)

| Field | Value |
|---|---|
| **Source** | S14-03 USER-OWNED re-attestation 2026-05-09 PM late (sprint-14) — distinct from POLISH-010 root cause; surfaced AFTER visual rendering restored |
| **Tier** | DEFECT (CRITICAL severity — release-blocker; ESCALATED 2026-05-09 PM late-late from HIGH after triage finding re-attributed root cause from input non-responsive to turn-loop architectural gap. See TRIAGE FINDING block below.) |
| **Closure trigger** | (a) MUST resolve before production stage advancement (gate-check rerun verdict cannot return PASS while POLISH-011 open); OR (b) sprint-14+ dedicated bug-fix story absorbs |
| **Owner** | unassigned (godot-gdscript-specialist + godot-specialist at pickup; input_router.gd + battle_scene.gd integration boundary suspected) |
| **Status** | Open |
| **Added** | 2026-05-09 |
| **Resolved** | — |

**Description**: User booted production build (`godot --path .` → main_scene `scenes/battle/battle_scene.tscn`) post-S14-02 fix. **Visual rendering CORRECT** (Changbanpo 15×15 grid + 6 unit silhouettes + bridges/river all render per art-bible per `production/qa/evidence/sprint-14-polish-010-evidence.md`). **However, mouse input on the top-left HUD panel area produced no game response at any timing**: from boot through 30-turn auto-progression through DRAW results screen + "hud.results.continue" label state, no clicks were acknowledged by the game. Player units (유비/장비) appear to have been driven by AI dispatch (or auto-skipped) rather than pausing for player input, given the battle reached MAX_TURNS_PER_BATTLE=30 → DRAW outcome with zero player turn observed.

**HYPOTHESES** (to be confirmed at pickup-time triage):

1. **Player input mode never engaged** — `InputRouter` FSM may not be transitioning to S1/S2 (move/attack input) states for player turns; player units silently fall into AI dispatch. Affected files: `src/foundation/input_router.gd` mode determination + `src/feature/battle_scene/battle_scene.gd` standalone-launch bootstrap (lines 110-119 advance scenario through BEAT_5_BATTLE).
2. **Input dispatch deadlock** — Mouse events received by `InputRouter` but action signals not emitted on `GameBus` (or emitted but not subscribed by GridBattleController). G-28 (bulk-disconnect-all severs production subscriptions) cross-reference candidate.
3. **Click coordinates intercepted by HUD chrome** — HUD CanvasLayer covers grid area top-left per S14-02 evidence side observation #4.1; clicks may land on HUD widgets that have no input handler (text labels, not buttons). However, this hypothesis ALONE doesn't explain auto-progression past player turns.
4. **Standalone-launch bootstrap auto-advances past player input window** — `battle_scene.gd:110-119` calls `advance_beat()` 3× + `confirm_deployment()` synchronously to drive scenario into BATTLE state for standalone demo; possible side effect that player turn input loop never opens.
5. **AISystem dispatching on player units** — Sprint-13 S13-12 fixed BattleUnit.archetype field separation from tag; possible regression where player_unit_ids aren't filtered out of AI dispatch dispatcher targets.

**Test scope limitation noted at attestation time**: User clicked HUD panel area only — grid tile clicks + unit silhouette clicks + keyboard input (Enter / Space for continue) were NOT exhaustively tested. A more thorough re-test could narrow root cause: if grid clicks DO respond but HUD doesn't, it's hypothesis 3; if NOTHING responds anywhere it's hypothesis 1, 2, or 4.

**Action when picked up**:
1. Reproduce in windowed mode + try grid tile clicks + unit clicks + keyboard input (Enter/Space) to narrow scope
2. Add diagnostic logging: `InputRouter` FSM state transitions + GameBus signal emit traces + GridBattleController input subscription status — reproduce + observe at battle start
3. If hypothesis 4 (standalone-launch auto-advance): the 3× `advance_beat()` calls in `battle_scene.gd:110-119` may need to be guarded by a "first frame after BATTLE state" hook OR removed entirely once non-standalone launch path (Main Menu → Overworld → Battle) ships
4. If hypothesis 1 (input mode never engages): trace `InputRouter._determine_mode()` (CR-2) to confirm mode transitions on `unit_turn_started` signal for player_unit_ids
5. If hypothesis 5 (AI dispatching on player units): grep `AISystem.dispatch()` filter logic for player_unit_ids exclusion check

**TRIAGE FINDING (2026-05-09 PM late-late session, post-active.md /clear recovery)** — Root cause is NOT input non-responsive. The 5 listed hypotheses are all secondary or unrelated. Actual root cause is a turn-loop architectural gap:

1. **`src/core/turn_order_runner.gd:561-562` `_execute_action_budget(_unit_id)` is a STUB** (body is `pass`). Every unit's turn falls through T4→T5→T6→T7 synchronously without any external system declaring an action. Documented as "Story-005 wires the Callable controller injection per ADR-0011 §Decision Contract 5" — that wiring was never completed.
2. **`AISystem.ai_action_ready` signal has NO subscriber in `src/`** (verified via `grep -rn ai_action_ready src/`). AISystem.decide() runs and emits, but no handler exists to call `_turn_runner.declare_action()` with the chosen command.
3. **`_turn_runner.declare_action()` is only called from `src/feature/grid_battle/grid_battle_controller.gd:721`** inside `end_player_turn()` — the explicit "End Turn" button handler. No path exists to declare MOVE/ATTACK/USE_SKILL/DEFEND during a unit's turn.
4. **ROUND_CAP=30** in `assets/data/balance/balance_constants.json` matches the user-observed 30-turn DRAW outcome exactly. With T5=`pass` + deferred chaining at `turn_order_runner.gd:534` and `:641`, all 30 rounds tick across deferred slots in 2-3 seconds and `_end_round` emits DRAW per `:626-627`.

**5-hypothesis disposition**:

- H1 (InputRouter FSM mode determination) — InputRouter wiring intact; irrelevant (no time window for input to matter).
- H2 (GameBus input_action_fired dispatch) — `grid_battle_controller.gd:246` subscribes correctly; not the cause.
- H3 (HUD chrome occluding clicks) — possibly contributing but secondary; even if clicks reached the grid, T5=`pass` renders any declared action moot.
- H4 (standalone-launch auto-advance bootstrap) — RIGHT pattern, WRONG file. Auto-advance lives in `turn_order_runner.gd:561` (T5 stub) + `:534/641` (synchronous-deferred chain), not `battle_scene.gd:115-119`.
- H5 (AISystem dispatching on player units) — `ai_system.gd:152` correctly filters `side != 0`; GBC `:434` correctly filters `is_player_controlled`. Both clean. AI subscriber gap (#2 above) makes this moot anyway.

**Severity re-tier**: HIGH → **CRITICAL** (release-blocker semantics unchanged; escalation reflects scope: not a polish item but an MVP turn-loop integration gap spanning ADR-0011 (TurnOrderRunner) + ADR-0014 (GridBattleController) + ADR-0019 (AISystem)).

**Why headless 1288/1288 PASS doesn't catch it**: tests call `_advance_turn` / `declare_action` / individual T-step methods directly via test seams. The full `initialize_battle` → `_begin_round.call_deferred()` → end-to-battle flow is exercised in windowed-mode boot only.

**Defer to sprint-15** with ADR amendment scope. Sprint-14 closure-mode discipline prohibits new dev; this finding is too large to absorb. Path-to-PASS for `/gate-check pre-prod-to-prod` rerun-3 must list POLISH-011 (CRITICAL) explicitly as a release-blocker requiring sprint-15 resolution.

**Verification gap pattern** (4th invocation, escalated from 3rd): same headless-vs-windowed verification gap as POLISH-008 (ObjectDB leak) + POLISH-010 (visual rendering) + POLISH-011-as-originally-filed (input frame). Now 4th invocation as POLISH-011-actual (turn-loop integration gap). Automated 1288/1288 PASS / 67th FFB does NOT exercise the full battle loop end-to-end in windowed mode. Sprint-14 retro AI seed: visual smoke harness (S14-06 G-30 codification candidate) should ALSO include a full battle-loop end-to-end run (initialize_battle → DRAW or victory), not just "scene loads + visuals render" — codification target strongly reinforced by 4th invocation.

**Cross-references**:
- Surfacing source: S14-03 re-attestation at `production/qa/qa-signoff-sprint-8-2026-05-06.md` §S8-15 Re-Attestation Batch 1.3 FAIL
- Distinct from POLISH-010 (visual rendering — CLOSED at this attestation §1.2 PASS) — same windowed-mode verification gap pattern
- Affected files: `src/foundation/input_router.gd` (FSM + mode determination) + `src/feature/battle_scene/battle_scene.gd:110-119` (standalone-launch bootstrap) + `src/feature/ai_system/ai_system.gd` (AI dispatch player_unit_id filter)
- ADR cross-references: ADR-0005 (input handling) + ADR-0014 (GridBattleController) + ADR-0017 (Scenario Progression) + ADR-0019 (AI System)
- gate-check binding: `production/gate-checks/pre-prod-to-prod-2026-05-?-rerun-3.md` will list this as new path-to-PASS item replacing POLISH-010
- Verification gap pattern siblings: POLISH-008 / POLISH-010 — sprint-14 S14-06 G-30 codification target

---

### POLISH-012 — POLISH-011 absorption-arc residual: `set_action_controller` production-wiring gap (NATURAL-LOOP mode never engages in production)

| Field | Value |
|---|---|
| **Source** | sprint-15 S15-D /dev-story Phase 4 (2026-05-10 PM late-late) — godot-gdscript-specialist mid-implementation investigation BEFORE first test run; 4th absorbed POLISH-011 root cause discovered while authoring the natural-loop integration test that was MEANT to verify the 3-root-cause closure |
| **Tier** | DEFECT (CRITICAL severity — release-blocker; same release-blocker semantics as POLISH-011 since this is the production-wiring residual that activates the S15-A/B/C absorption work; without this fix the 3-story arc S15-A/B/C is functionally inert in production main_scene) |
| **Closure trigger** | (a) MUST resolve before production stage advancement (gate-check rerun verdict cannot return PASS while POLISH-012 open); OR (b) sprint-15 mid-sprint amendment absorbs as S15-J per sprint-15.md R4 mitigation pattern explicitly anticipated at plan time |
| **Owner** | godot-gdscript-specialist (BattleScene._ready mount sequence + GridBattleController.setup body — the 5-line fix that wires the missing Callable injection) |
| **Status** | Open (sprint-15 S15-J mid-amendment in flight 2026-05-10 PM late-late) |
| **Added** | 2026-05-10 |
| **Resolved** | — |

**Description**: S15-A wired the `set_action_controller(controller: Callable)` DI surface on `TurnOrderRunner` per ADR-0011 §Amendment 2026-05-09 (commit `ab924aa`). The setter body assigns `_action_controller` and the T5 `_execute_action_budget` body branches on `_action_controller.is_null()` → if injected, calls `_action_controller.call(unit_id, snapshot)` (NATURAL-LOOP mode — awaits external `declare_action`); if NOT injected, falls through to TEST-SEAM mode (no-op pass). 7 sites in `tests/integration/core/turn_order_t5_await_test.gd` exercise the injected NATURAL-LOOP path. **Zero sites in `src/` ever call `set_action_controller`.** `BattleScene._ready()` STEP 4-5 (`battle_scene.gd:175-200`) creates `_turn_runner` + `_grid_controller` and passes `_turn_runner` to `_grid_controller.setup(...)` as 5th positional arg, but neither side registers the Callable that would put T5 into NATURAL-LOOP mode. Production main_scene `scenes/battle/battle_scene.tscn` therefore runs T5 = no-op pass for every unit's turn → all 5 rounds tick across deferred slots in 2-3 seconds → `_end_round` emits ROUND_CAP_DRAW → battle resolves identically with-or-without S15-A/B/C wiring.

**Verification gap pattern (5th invocation, escalated from 4th)**: same headless-vs-windowed verification gap as POLISH-008 (ObjectDB leak) + POLISH-010 (visual rendering) + POLISH-011-input-frame (originally filed) + POLISH-011-turn-loop-actual (TRIAGE FINDING). NEW invocation #5 surfaces a CLOSED-LOOP variant: even after the 3 root-cause stories absorb the verification-target component, the production WIRING that activates them remains unverified. Headless tests use direct test seams (`_runner.set_action_controller(_recording_controller)` injected via test helper); production code never exercises the same injection. Pattern stability advanced 4 → 5 within ~24 hours of POLISH-011 absorption arc closure (S15-C `971c2ae` 2026-05-10 PM late + this discovery 2026-05-10 PM late-late at S15-D /dev-story Phase 4).

**Why discovered BEFORE first test run** (instead of after, as sprint-15.md R4 anticipated): godot-gdscript-specialist Phase 4 investigation ("does production BattleScene._ready actually call set_action_controller?") preceded any code authoring for `battle_scene_natural_loop_test.gd`. `grep -rn "set_action_controller" src/ tests/` returned 7 test sites + 0 production callers. The 3-grep finding was conclusive. This is faster than the sprint-15.md R4 mitigation path ("S15-D natural-loop integration test catches these by failing on first run; mid-sprint amendment absorbs via Should Have promotion") — caught at investigation time, before any code author cycle. Saves ~2-3h of would-have-been-wasted test authoring + first-run failure + diagnostic + amendment.

**S15-J fix scope (single ~5-line wire-up in production code)**: in `BattleScene._ready()` STEP 5 (`battle_scene.gd:182-194`) immediately after `_grid_controller.setup(...)` but BEFORE `add_child(_grid_controller)` (so the Callable is registered before T5 first fires), add:

```gdscript
# S15-J: wire NATURAL-LOOP mode per ADR-0011 §Amendment 2026-05-09 + ADR-0014 §Amendment 2026-05-10 (#1 + #2).
# Without this call, T5 _execute_action_budget falls through to TEST-SEAM no-op; production
# battle loop runs to ROUND_CAP_DRAW in ~2-3 seconds without natural input/AI dispatch.
_turn_runner.set_action_controller(_grid_controller._on_turn_runner_action_request)
```

Where `_on_turn_runner_action_request(unit_id: int, snapshot: UnitTurnState)` is a NEW handler method on GridBattleController that the AI / player paths trigger by emitting a deferred-call into. Exact handler signature TBD per S15-J story-014 implementation; the surface contract is per ADR-0011 §Amendment 2026-05-09 §Decision Contract 5 Callable signature.

**Why the 3-story S15-A/B/C arc didn't catch this**: each story scoped its OWN absorption boundary (S15-A internal T5 await; S15-B internal AI handler; S15-C internal player helpers). None of the 3 included AC verification of the production CALL SITE for `set_action_controller`. ADR-0014 §Amendment 2026-05-10 (#1 + #2) documents the helper bypass pattern but neither amendment specifies the BattleScene mount-sequence integration point. ADR amendment process gap: amendments described component contracts but not the integration test that proves end-to-end wiring at production scope.

**Cross-references**:
- Surfacing source: sprint-15 S15-D /dev-story Phase 4 godot-gdscript-specialist agent investigation 2026-05-10 PM late-late — agent paused before code authoring after `grep -rn "set_action_controller" src/ tests/` finding (verified independently via orchestrator before agent resume direction)
- Mid-sprint amendment vehicle: sprint-15 S15-J (Must Have promotion per sprint-15.md R4 mitigation pattern; story-014 in `production/epics/grid-battle-controller/story-014-set-action-controller-production-wiring.md`)
- Blocks: S15-D (story-013 natural-loop integration test — must wait for S15-J close before AC-4 both-paths can MEANINGFULLY demonstrate POLISH-011 closure end-to-end); S15-E (gate-check rerun-4 — natural-loop demonstration is the CD/TD/PR pivot); S15-G (S8-15 §1.3 third re-attestation — user-time test must POST-DATE the production-wiring fix to demonstrate POLISH-011 actually closed)
- Affected files: `src/feature/battle_scene/battle_scene.gd` STEP 5 (mount sequence) + `src/feature/grid_battle/grid_battle_controller.gd` (NEW handler method `_on_turn_runner_action_request`)
- ADR cross-references: ADR-0011 §Amendment 2026-05-09 (S15-A T5 await mechanism — defines the Callable contract); ADR-0014 §Amendment 2026-05-10 (#1 S15-B AI subscriber); ADR-0014 §Amendment 2026-05-10 (#2 S15-C player path mirror); both ADR-0014 amendments will receive an Amendment #3 (this S15-J wiring) as part of story-014 close
- Verification gap pattern siblings: POLISH-008 / POLISH-010 / POLISH-011-input-frame / POLISH-011-turn-loop — sprint-14 S14-06 G-30 codification (5th invocation; escalation candidate to G-30 §Discovered list update at sprint-15 retro)
- Sprint-15 R4 risk evaluation: REALIZED (anticipated path "test catches it on first run + mid-sprint amendment absorbs"; actual path "investigation catches it BEFORE first run + mid-sprint amendment absorbs"; faster + cheaper)

---

### POLISH-013 — Natural-loop integration test surfaces deferred-chain progression gap exceeding S15-D scope (test environment vs production unresolved)

| Field | Value |
|---|---|
| **Source** | sprint-15 S15-D /dev-story 3-spawn-cycle attempt at natural-loop integration test (2026-05-10 PM very-late) — godot-gdscript-specialist 3 fixture iterations all surfaced same stall pattern |
| **Tier** | DEFECT (HIGH severity — verification gap; downgraded from CRITICAL because S15-J wiring test #2 already verifies the enemy-side dispatch chain end-to-end at unit-scope; production code IS verified at S15-J level; what's missing is the CI-level natural-loop end-to-end demonstration) |
| **Closure trigger** | (a) sprint-16+ dedicated test infrastructure story with reframed scope (likely requires input simulation OR delayed-victory-eval mechanism); OR (b) S15-G windowed re-attestation by user PROVES production main_scene loop progresses → POLISH-013 reclassified to test-env-only gap (still requires sprint-16 fix for CI); OR (c) S15-G windowed re-attestation FAILS → POLISH-013 escalates to CRITICAL (real production defect; POLISH-011 not actually closed) |
| **Owner** | unassigned (sprint-16 pickup; godot-gdscript-specialist + qa-tester at story-013-revised authoring time) |
| **Status** | Open |
| **Added** | 2026-05-10 |
| **Resolved** | — |

**Description**: Sprint-15 S15-D `/dev-story` attempted authoring `tests/integration/feature/battle_scene/battle_scene_natural_loop_test.gd` over 3 godot-gdscript-specialist agent spawn cycles. Each cycle progressed the test design + ran the test; each fixture variant (chapter-1 / hybrid 1-stub-player+4-enemies / TRUE 0-player-units+4-enemies) produced identical stall behavior:

- 2 emits captured: `round_started(1)` + 1 `unit_turn_started(<first_unit>)`
- 4000 frames consumed (~27s wall-clock @ 60fps virtual time)
- 0 `ai_action_requested` emits captured (S15-B chain not firing)
- 0 additional `unit_turn_started` (loop never advances past unit 1)
- 0 `victory_condition_detected` emits (terminal outcome never reached)
- AC-7 OBJECT_COUNT delta ~260-272 (POLISH-008 leak surfacing under prolonged loop)

The test mirrors `src/feature/battle_scene/battle_scene.gd` STEP 1-5.5 mount sequence programmatically (instantiates MapGrid + BattleCamera + HPStatusController + TurnOrderRunner + GridBattleController + AISystem in the correct order; wires `set_action_controller(_grid_controller._on_turn_runner_action_request)` per S15-J pattern; calls `_turn_runner.initialize_battle(roster)` to queue `_begin_round.call_deferred()`). Despite mirroring production mount, the natural-loop progression fails to advance.

**Critical UNRESOLVED question** (test-env vs production):

- **Hypothesis A (test-env-only gap)**: AISystem `CONNECT_DEFERRED` subscriber, `_make_battle_state_snapshot()`, or `decide(unit_id, snapshot)` chain has a dependency on a runtime condition that the programmatic test doesn't establish (e.g., chapter chokepoints array emptiness causes silent AI fail; HeroDatabase asset state needed for full enemy decide; map-grid query depends on TileSet being loaded which only happens in BattleScene mount). Production main_scene works fine; only the test setup is incomplete. **S15-G windowed re-attestation by user is the gate that determines this.**
- **Hypothesis B (real production defect)**: POLISH-011 absorption arc S15-A/B/C/J wired the COMPONENT contracts but the END-TO-END natural deferred-chain progression has a latent stall under any condition (production main_scene would also stall at unit 1; real release-blocker that POLISH-012 closure didn't actually fix). **S15-G windowed re-attestation FAIL would confirm this.**

S15-J wiring test #2 (`battle_scene_set_action_controller_wiring_test.gd:150`) verified the enemy-side dispatch chain works at UNIT scope (handler → ai_action_requested → AISystem → ai_action_ready → declare_action) by direct method call. So Hypothesis A is more likely than B but unresolved without the windowed re-attestation evidence.

**Why headless 1320/1320 PASS doesn't catch the S15-D failure**: ironically, this IS the G-30 verification gap pattern — the existing 1320 tests use direct test seams (`_advance_turn`, `declare_action`, `_seed_unit_state_for_test`) and never exercise the natural deferred-chain progression. S15-D was designed to CLOSE this gap; instead it surfaces a NEW G-30 instance (the meta-pattern: even the test designed to close G-30 hits a G-30 territory issue).

**Defer to sprint-16** with reframed scope. Possible sprint-16 paths:
1. Debug instrumentation: spawn agent to trace every signal/handler/CONNECT_DEFERRED firing in the test setup; identify where the chain breaks (~2-3h investigation; G-31 codification candidate).
2. Input simulation: synthesize `InputEventMouseButton` via `Input.parse_input_event()` to drive player turns past T5 stall. Combines G-30 mitigation gaps #3 (input dispatch) + #5 (natural loop) into single test (~2-3h infra).
3. Delayed-victory-eval mechanism: add per-unit T5 timeout to TurnOrderRunner (defensive feature; if no declare_action within N seconds, auto-WAIT). New production feature; requires ADR amendment.
4. Reframe S15-D as "verify mount + first emit only" (drop full end-to-end ACs): test asserts programmatic mount completes + round_started(1) + unit_turn_started(first unit) fires; mark AC-2/3/4 as DEFERRED; partial G-30 mitigation (~30min refactor).

**Verification gap pattern (6th invocation, escalated from 5th)**: META-pattern — the test infrastructure designed to close G-30 verification gap pattern #5 (battle-loop end-to-end) ITSELF surfaces a G-30 instance. Pattern stability advanced 5 → 6 within hours of S15-J close. Sprint-15 retro AI strongly seeded for G-30 §Discovered list update + structural review of G-30 mitigation strategy (test infra alone may not be sufficient; may need input simulation + per-unit timeouts + dedicated G-30 mitigation EPIC).

**Cross-references**:
- Surfacing source: sprint-15 S15-D /dev-story Phase 4-7 spans 3 agent spawn cycles 2026-05-10 PM late-late through PM very-late (chapter-1 stall → hybrid-fixture pivot stall → TRUE 0-player-units stall — same outcome each iteration; orchestrator confirmed stall is reproducible across fixture variants)
- Affected files: `tests/integration/feature/battle_scene/battle_scene_natural_loop_test.gd` (the failed test; deleted at sprint-15 close-out commit per "never disable failing tests" project discipline; design captured in story-013 spec for sprint-16 reauthoring)
- Story file (kept Ready for sprint-16 pickup): `production/epics/grid-battle-controller/story-013-natural-loop-integration-test.md`
- ADR cross-references: ADR-0011 §Amendment 2026-05-09 (T5 await contract), ADR-0014 §Amendment 2026-05-10 (#1+#2+#3) — all Accepted; the chain components verified at unit-scope but not end-to-end
- gate-check binding: S15-E rerun-4 verdict will weigh POLISH-013 as substrate concern; gate-check verdict CD/TD/PR pivot may be CONCERNS rather than PASS depending on S15-G windowed re-attestation outcome
- S15-J wiring test (precedent for unit-scope verification of enemy chain): `tests/integration/feature/battle_scene/battle_scene_set_action_controller_wiring_test.gd:150` Test 2

---

### POLISH-014 — BattleScene teardown leaves ~270 ObjectDB orphans across the 2 battle_scene-booting suites (full-suite exit 101 warning)

| Field | Value |
|---|---|
| **Source** | Session 7 Phase 7 production_slide test isolation fix (2026-05-13) — surfaced when exit code transitioned from 100 [error] to 101 [warning] after the 1-known-error was eliminated by SceneManager.reset_for_tests + battle-world isolation cleanup |
| **Tier** | DEFECT (LOW severity — functional pass rate unaffected: 1370/1370 tests still pass; gdUnit4 emits exit 101 = RETURN_WARNING when any suite has orphans even though all assertions hold) |
| **Closure trigger** | Pre-release CI green requirement (`exit 0` enforced by deploy pipeline) OR dedicated hygiene sweep when a sprint surfaces capacity for it |
| **Owner** | unassigned |
| **Status** | Open |
| **Added** | 2026-05-13 |
| **Resolved** | — |

**Description**: every test suite that boots `scenes/battle/battle_scene.tscn` (currently `tests/integration/feature/battle_scene/battle_scene_chapter_progression_test.gd` and `battle_scene_production_slide_test.gd`) reports 130-140 orphan ObjectDB instances on the FOLLOWING test's setup. Confirmed structural to BattleScene teardown — **the same orphan count appears when each suite runs solo**, meaning the leak originates from `_battle_scene.free()` not fully releasing the subtree, NOT from cross-test contamination. Full-suite total: ~270 orphan baseline.

The session-7 production_slide isolation fix (commit `ba4f83c` — adds `SceneManager.reset_for_tests` + sweeps `/root` ChapterVisuals before each test) eliminated the 1 known functional error baseline but did NOT address the orphan count. Result: exit code 101 (`RETURN_WARNING` per `addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd:466-468`) instead of exit 0.

**Suspected leak sources** (ordered by hypothesis priority — root cause not yet pinned):
1. **Polygon2D + Line2D + Label children of ChapterVisuals at `/root`** — spawned at runtime by `_spawn_unit_polygons_async` → `ChapterVisuals.spawn_unit_polygons(roster)`. ChapterVisuals is freed in test cleanup but its children may have detached refs via the polygon-finding loops in BattleScene handlers.
2. **HUD widget subtree** (UI-GB-01..14 elements under `_hud_layer`) — heavily nested Controls; if any Tween/Timer/Callable holds a ref, the widgets detach from the freed parent.
3. **Signal-captured Callables** holding strong refs to BattleScene children — would prevent the cascade-free from reaching those nodes.

**Mitigation hypotheses** (ordered by yield-to-effort):
- Audit `_find_unit_polygon` / `_list_polygon_names` consumers — they walk the polygon subtree, may capture refs in closures.
- Add a defensive `BattleScene._exit_tree()` body that explicitly `free()`s known suspects (currently empty per R-6 "no _exit_tree body" rule — would need an R-6 amendment if pursued).
- Run with `--verbose` to capture `Window.print_orphan_nodes()` output and identify the specific node types in the orphan set.

**Cross-refs**: TD-074 (this entry's tech-debt mirror), G-31 (Tween process_mode binding — fixed adjacent, doesn't affect orphan count), G-6 (orphan detection timing).

---

### POLISH-015 — 관우 chibi sprite 이동 시 90도 회전 (다른 4 영웅 미확인)

| Field | Value |
|---|---|
| **Source** | 사용자 windowed attestation 2026-05-21, Q5 Phase 2 Heavy hide commit `136203e` 직후. 관우만 reported — 다른 영웅 (방통/장비/유비/위연) 회전 여부 미확인 |
| **Tier** | DEFECT (LOW severity — visual quirk only; gameplay/functionality 영향 0; chibi 가 이미 mount 되고 사용자가 "잘 나오네" 만족 표한 후 발견) |
| **Closure trigger** | Q5 Phase 3 (walk 4-frame animation) 작업 진입 시점 (그때 sprite rotation 전체 path 재검토 필연) OR 사용자 explicit request |
| **Owner** | unassigned |
| **Status** | Open |
| **Added** | 2026-05-21 |
| **Resolved** | — |

**Description**: Q5 Phase 1 mount 시 `chibi_sprite.rotation = -poly.rotation` 가 spawn-time only 한 번 set (chapter_visuals.gd:498). unit 이동 후 polygon.rotation 이 새 facing 으로 update 되어도 ChibiSprite 의 rotation 은 spawn 시점 값 유지 → polygon-relative 으로 90도 어긋남. 관우만 reported 인 이유는 미확인 — 관우의 unit_class (CAVALRY 추정) 가 이동 시 facing change 가 가장 자주 발생하거나, rotation_for_facing 의 class-specific 값이 관우 case 에서만 가시한 회전 produce 가능.

**Action when picked up**:
1. unit movement 처리 코드에서 polygon.rotation update 시점 찾기 (`battle_scene.gd` 의 `_on_unit_moved` 또는 비슷한 handler 가능성)
2. 같은 시점에 자식 ChibiSprite (있을 경우) 의 rotation 도 `-poly.rotation` 으로 동기 update
3. 5 영웅 모두 (방통/관우/장비/유비/위연) 이동 시 회전 검증 — 관우만 issue 인지 universal issue 인지 확인
4. NameLabel + FrontChevron 도 동일 counter-rotation 패턴 (chapter_visuals.gd:531, 533) — 그들은 어떻게 처리되는지 참고

**Cross-references**:
- `src/feature/battle_scene/chapter_visuals.gd:498` (chibi_sprite.rotation = -poly.rotation, spawn-only)
- `src/feature/battle_scene/chapter_visuals.gd:531-533` (FrontChevron counter-rotation 패턴 참고)
- `src/feature/battle_scene/battle_scene.gd` 의 unit movement handler (정확한 line 미상)
- Q5 Phase 2 commit chain: `c9948a1` (5 breath asset) / `136203e` (Heavy hide)

---

## Index — by Status

| Status | Count | IDs |
|---|---|---|
| Open | 15 | POLISH-001 / POLISH-002 / POLISH-003 / POLISH-004 / POLISH-005 / POLISH-006 / POLISH-007 / POLISH-008 / POLISH-009 / POLISH-010 / POLISH-011 / POLISH-012 / POLISH-013 / POLISH-014 / POLISH-015 |
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
| Sprint-14 S14-03 re-attestation post-S14-02 visual fix (2026-05-09 PM late) | POLISH-011 |
| Sprint-15 S15-D /dev-story Phase 4 godot-gdscript-specialist mid-implementation investigation (2026-05-10 PM late-late) | POLISH-012 |
| Sprint-15 S15-D /dev-story 3-spawn-cycle attempt at natural-loop test (2026-05-10 PM very-late; deferred to sprint-16 with reframed scope) | POLISH-013 |
| Session 7 Phase 7 production_slide test isolation fix (2026-05-13 — surfaced when exit code transitioned 100→101 after eliminating the 1-known-error) | POLISH-014 |
| S72 사용자 windowed attestation 2026-05-21 (Q5 Phase 2 Heavy hide `136203e` 직후 관우 회전 발견) | POLISH-015 |

## Index — by Closure Trigger

| Trigger | IDs |
|---|---|
| Polish-phase doc-correction sweep | POLISH-001 / POLISH-002 / POLISH-003 |
| Localization sprint OR `/localize` first run | POLISH-004 |
| Cascade from POLISH-004 closure | POLISH-005 |
| Character-art commission sprint enters planning (forcing function) OR Polish gate (`production/stage.txt` = `Polish`) | POLISH-006 |
| Bundled at sprint-14 entry (POLISH-009 likely root cause of POLISH-010) | POLISH-009 / POLISH-010 |
| MUST resolve before production stage advancement (gate-check rerun-3 path-to-PASS) | POLISH-011 |
| MUST resolve before production stage advancement (sprint-15 S15-J mid-amendment in flight; production-wiring residual of POLISH-011 absorption arc) | POLISH-012 |
| Pre-release CI green requirement OR dedicated hygiene sweep (gdUnit4 exit 101 warning, not error) | POLISH-014 |
| Q5 Phase 3 (walk 4-frame animation) 작업 진입 시점 OR 사용자 explicit request | POLISH-015 |

---

## Amendment log

*Append future amendments below — do not rewrite the body above.*

- 2026-05-08 — Initial backlog established (sprint-11 S11-06 close-out; 5 ADVISORY entries from battle-hud epic verification summary).
- 2026-05-09 — POLISH-006 added (sprint-12 S12-08 close-out per gate-check 2026-05-08 NEW ADVISORY-CANDIDATE; Guan Yu + Zhang Fei character profile stubs DESCOPED carryover from sprint-10 S10-07 → sprint-11 S11-09 Liu Bei first-stub-shipped). Lightweight conditional path chosen (no character-art sprint scheduled in sprint-12); entry-only authoring per S12-08 spec.
- 2026-05-09 PM — POLISH-007 + POLISH-008 added (sprint-13 mid-plan amendment Production VS bug surfacing; deferred non-blocker tier).
- 2026-05-09 PM late — POLISH-009 + POLISH-010 added (S13-10 USER-OWNED attestation surfaced production main_scene visual rendering FAIL; POLISH-010 is HIGH-tier release-blocker gating gate-check rerun PASS verdict). Verification gap pattern noted for sprint-13 retro: 1288/1288 PASS automated suite gates LOGIC but does not gate VISUAL PRESENCE of production main_scene; headless-only verification cannot surface blank-window symptoms.
- 2026-05-09 PM late — POLISH-011 added (S14-03 re-attestation post-S14-02 visual fix surfaced input non-responsive in windowed mode). 3rd invocation of headless-vs-windowed verification gap pattern (POLISH-008 / POLISH-010 / POLISH-011); reinforces sprint-14 S14-06 G-30 codification target. POLISH-010 + POLISH-009 effectively closed by S14-02 implementation (visual rendering verified; `mvp_chapter_01.tscn` ERROR eliminated) — formal status flip pending sprint-14 close ceremony amendment.
- 2026-05-09 PM late-late — POLISH-011 TRIAGE FINDING amendment: tier escalated HIGH → CRITICAL after root-cause re-attribution from input non-responsive to turn-loop architectural gap (TurnOrderRunner._execute_action_budget stub + missing AISystem.ai_action_ready subscriber + missing per-action declare_action wiring in grid-click handlers). 5-hypothesis disposition documented inline (H1/H2/H4 disconfirmed; H3 secondary; H5 moot). Verification gap pattern advanced 3rd → 4th invocation (POLISH-008 / POLISH-010 / POLISH-011-input-frame / POLISH-011-turn-loop-actual). Sprint-15 absorption recommended; sprint-14 closure-mode prohibits this-sprint fix.
- 2026-05-10 PM late-late — POLISH-012 added (sprint-15 S15-D /dev-story Phase 4 godot-gdscript-specialist mid-implementation investigation BEFORE first test run): POLISH-011 absorption-arc residual surfaced — `set_action_controller` DI surface added by S15-A is never called from production `src/` (7 test sites + 0 production callers); production main_scene falls through TEST-SEAM no-op pass for T5; battle resolves to ROUND_CAP_DRAW identically with-or-without S15-A/B/C wiring. Verification gap pattern advanced 4th → 5th invocation (CLOSED-LOOP variant: even after the 3 root-cause stories absorb the verification-target, the production WIRING that activates them remains unverified). Sprint-15 R4 risk REALIZED via investigation-time catch (faster + cheaper than the anticipated test-first-run-failure path). Mid-sprint amendment vehicle: S15-J Must Have promotion → story-014 in grid-battle-controller epic; S15-D blocked on S15-J close.
- 2026-05-10 PM very-late — POLISH-013 added (sprint-15 S15-D /dev-story 3-spawn-cycle attempt at natural-loop integration test): test infrastructure surfaces a deferred-chain progression gap that exceeds achievable verification under current test framework + S15-D 2-3h estimate. 3 fixture iterations attempted (chapter-1 / hybrid 1-stub-player / TRUE 0-player-units) — all stall at unit 1 turn-start with 2 emits captured + 4000 frames consumed. Whether this indicates a test-environment-only gap (production main_scene actually works; needs windowed re-attestation S15-G to confirm) OR a real production defect (POLISH-011 absorption arc didn't close the natural-loop progression chain end-to-end) is UNRESOLVED. S15-D DEFERRED to sprint-16 with reframed scope; sprint-15 closes 4/5 Must Have (S15-A/B/C/J done; S15-D deferred). 6th invocation of headless-vs-windowed verification gap pattern (G-30) — meta-pattern: even the test designed to CLOSE G-30 surfaces a NEW G-30 instance.
- 2026-05-13 — POLISH-014 added (session 7 Phase 7 production_slide test isolation fix surfaced the BattleScene-teardown orphan baseline as the next-level CI failure mode). Exit code transitioned 100 [error] → 101 [warning] after `SceneManager.reset_for_tests` + battle-world isolation cleanup eliminated the 1-known-error: 1370/1370 tests pass functionally but the 270 ObjectDB orphan baseline (per `battle_scene_chapter_progression_test` + `battle_scene_production_slide_test`, ~130-140 each, present even when each suite runs solo) trips gdUnit4's `RETURN_WARNING` path. LOW severity (functional pass rate unaffected); closure trigger is pre-release CI green requirement or a dedicated hygiene sweep. Mirrors as TD-074 in tech-debt-register.
