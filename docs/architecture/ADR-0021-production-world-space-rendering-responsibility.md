# ADR-0021: Production World-Space Rendering Responsibility

## Status

Accepted

## Date

2026-05-09

## Last Verified

2026-05-09

## Decision Makers

- technical-director (TD-PHASE-GATE rerun-2 Item 6 led; identified the
  rendering-responsibility unassigned-across-ADRs gap)
- creative-director (CD-PHASE-GATE rerun-2 Option A preferred)
- art-director (AD-PHASE-GATE rerun-2 Option B prototype-tier-fallback rejected;
  supplied tier-boundary forcing function)
- godot-specialist (cross-ADR conflict review; ADR-0014/0016 alignment)

## Summary

Production main_scene `scenes/battle/battle_scene.tscn` is intentionally a
container-only logic+HUD assembler. World-space rendering (tile sprites, unit
visuals, map background) is the responsibility of an authored chapter-scope
`.tscn` at `scenes/battle/{map_id}.tscn`, mounted as a child of `BattleScene`
under the existing `GridLayer Node2D` during the BattleScene mount sequence.
When the authored `.tscn` is missing, BattleScene logs a HIGH-tier warning and
falls back to a synthesized MapResource so headless logic remains intact, but
production-stage advancement REQUIRES at least one chapter-authored `.tscn`
shipped + verified by windowed visual evidence.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering |
| **Knowledge Risk** | MEDIUM — Camera2D + Node2D scene-tree composition + PackedScene `instantiate()` are stable since 4.x and well within training data; per-platform renderer backends (D3D12 Windows / Metal macOS-iOS / Vulkan Linux-Android) are 4.6-defaults but only relevant for bring-up, not for this ADR's interface contract |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, ADR-0004 §1-§3, ADR-0013 §1-§3, ADR-0014 §3, ADR-0016 §2 + §3, `src/feature/battle_scene/battle_scene.gd:_build_map_resource_for_chapter()`, `prototypes/chapter-prototype/chapter.gd` (tier-boundary reference) |
| **Post-Cutoff APIs Used** | None — `ResourceLoader.exists()`, `load()`, `PackedScene.instantiate()`, `Node.add_child()` are all pre-4.4 stable |
| **Verification Required** | Windowed-mode boot of `scenes/battle/battle_scene.tscn` after `mvp_chapter_01.tscn` mounts MUST render non-blank world-space; verified via screenshot evidence at `production/qa/evidence/sprint-14-polish-010-evidence.md` (S14-02 acceptance criterion) |

> **Note**: Knowledge Risk MEDIUM. If Godot upgrades from 4.6, re-validate
> PackedScene instancing semantics + Camera2D world-space compositing behavior
> against the new version's release notes.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (MapGrid data model), ADR-0013 (BattleCamera framing), ADR-0016 (BattleScene wiring + mount sequence), ADR-0017 (Scenario Progression — `ChapterDefinition.map_id`) |
| **Enables** | POLISH-010 disposition (Option A authored visuals), production stage advancement (Pre-Production → Production via gate-check rerun-3) |
| **Blocks** | Sprint-14 S14-02 (POLISH-010 fix authoring) cannot land without this contract |
| **Ordering Note** | This ADR ratifies an interface contract that all Production VS chapter implementations (sprint-7+ chapter-1 onward) must respect. Sprint-14 S14-02 is the first compliant implementation. ADR-0016 §3 mount sequence is amended at this ratification with a STEP 1.5 ChapterVisualScene mount entry (Path A precedent — Step 5.5 AISystem insertion 2026-05-05). |

## Context

### Problem Statement

Production main_scene `scenes/battle/battle_scene.tscn` boots cleanly, runs all
7 systems end-to-end, and emits 391 turn-domain signals across the full battle
loop with the headless test suite passing 1288/1288. But windowed-mode
rendering is BLANK — sprint-13 user attestation S13-10 reports "배틀화면 안
보임" against the production build. Root cause investigation (POLISH-010,
2026-05-09 PM late) confirms: `battle_scene.tscn` is container-only by design
(3 nodes: `BattleScene Node2D` + `GridLayer Node2D` + `HUDLayer CanvasLayer`);
the 7 runtime-mounted systems are LOGIC + HUD-only (none implement
`_draw()` or own world-space sprites); the world-space sprite/TileMap layer
was intended to come from authored chapter-scope `.tscn` files (e.g.
`mvp_chapter_01.tscn`) that were never created.

The **rendering-responsibility contract is unassigned across ADRs**. ADR-0014
(GridBattleController) and ADR-0016 (BattleScene wiring) are silent on which
Node owns world-space visual rendering, what fallback exists, and what the
prototype/production tier boundary is. Without this ADR, Production sprints
would author `mvp_chapter_01.tscn` against an undefined interface — exactly
the cross-system integration failure mode TD owns.

This ADR is the gate-blocker for `production/stage.txt` Pre-Production →
Production advancement (gate-check rerun-2 Item 6, TD-led). It must be
ratified BEFORE S14-02 implementation work begins.

### Current State

- `scenes/battle/battle_scene.tscn` — 3-node container scene (BattleScene
  Node2D + GridLayer Node2D + HUDLayer CanvasLayer) per ADR-0016 §2
- `BattleScene._ready()` mounts 7 systems via the 6-step + STEP 5.5 sequence
  (ADR-0016 §3 + AISystem insertion 2026-05-05); none render world-space
- `MapGrid` extends `Node` (NOT `Node2D`) — data + lookup only per ADR-0004
- `BattleCamera` extends `Camera2D` — viewport framing only, no `_draw()` per
  ADR-0013
- `HPStatusController`, `TurnOrderRunner`, `GridBattleController`, `AISystem`
  — pure logic
- `BattleHUD` — HUD chrome via 14 prefab `.tscn` files mounted to HUDLayer
  CanvasLayer; renders at screen edges, NOT world-space
- `_build_map_resource_for_chapter()` (battle_scene.gd:273) synthesizes a
  15×15 all-grass `MapResource` fallback when authored map data is missing,
  preserving headless logic continuity
- `prototypes/chapter-prototype/chapter.gd` (lines 183/206/251/261/329)
  builds runtime ColorRect + Label visuals — prototype-tier per
  `.claude/rules/prototype-code.md`; explicitly throwaway-tier
- Result: production main_scene = visible HUD chrome at screen edges + blank
  world-space center; "배틀화면 안 보임" experience confirmed against
  S13-10 attestation

### Constraints

- **Technical**: Godot 4.6 Forward+ Mobile renderer; per-platform backends
  (D3D12 Windows / Metal macOS-iOS / Vulkan Linux-Android) per
  `technical-preferences.md`; Node2D + Camera2D world-space compositing model
- **Process**: prototype/ vs src/ tier boundary per
  `.claude/rules/prototype-code.md` — prototype-tier ColorRect placeholders
  forbidden in production code; AD-PHASE-GATE rerun-2 explicitly rejected
  Option B (port prototype rendering into production)
- **Compatibility**: must integrate with existing 7-system mount sequence
  (ADR-0016 §3) without disrupting init-order DI dependencies; existing
  1288/1288 PASS test baseline must not regress
- **Scope**: this ADR is 1-2hr scoped per gate-check rerun-2 estimate; full
  visual-tier production epic (sprite asset specs, animation pipeline, shader
  strategy) deferred to a dedicated future epic
- **Resource**: technical-artist + godot-gdscript-specialist available as
  named owners for S14-02 authoring of the first compliant chapter `.tscn`

### Requirements

- **R-1**: Define the responsible Node for world-space tile + unit rendering
- **R-2**: Define the canonical asset path convention for map visuals + map
  data, integrated with `ChapterDefinition.map_id` (ADR-0017)
- **R-3**: Define behavior when the authored `.tscn` is missing (fallback
  path, severity, gate-check implications)
- **R-4**: Define the prototype/production tier boundary explicitly so
  prototype-tier ColorRect rendering is mechanically forbidden as a
  sanctioned production fallback
- **R-5**: Headless logic continuity preserved — 1288/1288 PASS baseline must
  not regress after S14-02 implementation lands
- **R-6**: Visual evidence requirement codified — production stage
  advancement requires manual screenshot evidence at
  `production/qa/evidence/` per AD's "world-space visual presence" gate
  criterion (sprint-14 S14-07)

## Decision

### §0. Scope Statement

This ADR defines the **interface contract** between
`scenes/battle/battle_scene.tscn` (container scene) and chapter-scope authored
`.tscn` assets (visual layer). It does NOT codify sprite asset specifications,
animation pipelines, shader strategies, or TileSet authoring conventions —
those belong to the art-bible + a future visual-tier production epic.
ADR-0021 ONLY answers three questions:

1. Which Node owns world-space visual rendering responsibility?
2. Where do the visual assets live (canonical path)?
3. What happens when the authored visual asset is absent?

Anything beyond these three answers is out-of-scope and explicitly deferred.

### §1. Responsible Node — Authored Chapter-Scope `.tscn` Mounted Under GridLayer

**Rule**: world-space rendering responsibility belongs to a chapter-scope
authored `.tscn` at `scenes/battle/{map_id}.tscn`, instanced by
`battle_scene.gd._ready()` and mounted as a CHILD of the existing
`GridLayer Node2D` (the world-space scope anchor per ADR-0016 §2 line 164).

**Why GridLayer parent (not BattleScene root)**: ADR-0016 §2 line 164 already
designates GridLayer as the "world-space scope" anchor and explicitly
contrasts it with HUDLayer/CanvasLayer (screen-space). Mounting the chapter
visual scene under GridLayer:

1. Respects the established world-space vs screen-space boundary
2. Reuses an existing structural Node (no new sibling at BattleScene root)
3. Keeps draw-order rational: chapter visuals render under any future
   UI-GB-12/13/14 grid-overlays which already mount under GridLayer per
   ADR-0015 §2

**Why authored `.tscn` (not runtime-built sprites)**: Godot's editor-authored
`.tscn` workflow is the canonical asset authoring pattern for sprite
hierarchies, TileMap layers, and structural visual composition. Runtime-built
sprite construction is prototype-tier (see §4) and forbidden in production.

### §2. Visual Asset Path Convention

| Asset | Canonical Path | Owner Role |
|-------|----------------|------------|
| Map data (terrain layout) | `assets/data/maps/{map_id}.tres` | game-designer (per ADR-0017 line 129; `chapter_definition.gd:23` docstring) |
| Map visuals (sprites + TileMap) | `scenes/battle/{map_id}.tscn` | technical-artist + godot-gdscript-specialist (NEW per this ADR) |

`{map_id}` resolves from `ChapterDefinition.map_id` (ADR-0017). For chapter-1:

- `map_id = "mvp_chapter_01"` →
  - `assets/data/maps/mvp_chapter_01.tres` (data)
  - `scenes/battle/mvp_chapter_01.tscn` (visuals)

The two assets are paired: data and visuals for the same chapter co-locate
under a shared `{map_id}` token. Authoring one without the other is permitted
at intermediate development stages but production stage advancement requires
both.

### §3. Fallback Contract — When Authored `.tscn` Is Missing

**Severity**: HIGH-tier warning at headless boot (NOT error). Production
stage advancement is GATED: at least one chapter-authored `.tscn` MUST be
shipped + verified by windowed visual evidence before `production/stage.txt`
flips Pre-Production → Production.

**Behavior** (during BattleScene mount sequence):

1. `ResourceLoader.exists("res://scenes/battle/{map_id}.tscn")` returns
   `false` → call `push_warning("ADR-0021: chapter visual scene missing at
   '%s'; running with blank world-space (headless logic intact, windowed
   mode will render void). POLISH-010-class issue." % chapter_scene_path)`
   + skip the chapter visual mount step
2. Map data fallback: existing `_build_map_resource_for_chapter()` path
   synthesizes a 15×15 all-grass `MapResource` per ADR-0016 IN-9 (preserves
   headless logic + 1288/1288 PASS baseline)
3. Windowed mode: world-space renders blank; HUD chrome remains visible at
   screen edges — equivalent to current pre-S14-02 production main_scene
   experience

**NOT permitted as fallback** (mechanically forbidden):

- Prototype-tier `ColorRect` / `Label` runtime rendering (e.g., the
  `prototypes/chapter-prototype/chapter.gd:183/206/251/261/329`
  patterns). Production code MUST mount an authored `.tscn` or render
  void. Synthetic placeholder visuals in production code violate the
  prototype/production tier boundary established in §4.
- Per-system rendering responsibility extensions (e.g., extending MapGrid
  to draw tiles or GridBattleController to instance unit Sprite2D
  children). MapGrid is data-only per ADR-0004; GridBattleController is
  controller-only per ADR-0014 §1; pushing rendering into them is a
  separation-of-concerns regression.

### §4. Prototype/Production Tier Boundary (Explicit)

| Tier | Rendering Strategy | Allowed Locations | Crossover |
|------|-------------------|-------------------|-----------|
| **Prototype** | Runtime-built `ColorRect` + `Label` (e.g., `chapter.gd` lines 183-329) | `prototypes/chapter-prototype/` only | NEVER cross to `src/` |
| **Production** | Authored chapter-scope `.tscn` mounted under GridLayer per §1 | `scenes/battle/{map_id}.tscn` + mount code in `src/feature/battle_scene/battle_scene.gd` | NEVER use prototype patterns |

**Structural rule**: when prototype-tier visuals demonstrate gameplay
successfully (e.g., S13-02 chapter-prototype attestation 4-of-4 PASS), the
**mechanical insight** transfers to production but the **rendering
implementation** is re-authored from scratch in production-tier `.tscn` form.

This is not a stylistic preference; it is a forcing function. Prototype proves
*what to render*; production owns *how to render it properly* — with
art-bible-aligned palette, tile color language, unit silhouettes, and the
performance characteristics required by the 60fps + 16.6ms frame budget.

### §5. BattleUnit Field-Extension Precedent (Reference to ADR-0014 §3)

**Why referenced**: S13-12 (BattleUnit `archetype` field separation, ADR-0014
§3 DI Setup) demonstrated the canonical pattern for extending `BattleUnit`
with new fields driven by chapter data without destabilizing the existing
8-parameter `setup()` signature. ADR-0021 implementation may need analogous
`BattleUnit` extensions in future visual-tier work — for example,
`sprite_path: String` or `animation_set_id: StringName` when chapter `.tscn`
authoring requires unit-level asset binding beyond what the current 9-field
BattleUnit captures.

**The S13-12 precedent**: extend `BattleUnit` `@export` fields → populate
from chapter data via `_build_battle_units_from_chapter()` →
pass through DI without modifying existing setup signatures.

**This ADR does NOT mandate** any specific BattleUnit extension. The
reference is for downstream implementation guidance only — to alert future
sprint authors that the precedent exists and is the sanctioned path when
unit-level asset binding becomes necessary. The visual-tier epic that
introduces the first such extension will own the actual ADR amendment.

### §6. Mount Sequence Amendment — ADR-0016 §3 STEP 1.5

This ADR amends ADR-0016 §3 6-step + STEP 5.5 mount sequence with the
following insertion:

```gdscript
# === STEP 1: MapGrid (ADR-0004) === [unchanged]
_map_grid = MapGrid.new()
_map_grid.load_map(map_resource)
add_child(_map_grid)

# === STEP 1.5: ChapterVisualScene (NEW per ADR-0021 §1) ===
# Mount the chapter-scope authored .tscn under GridLayer so world-space
# visuals render. Missing .tscn is a HIGH-tier warning (POLISH-010-class)
# but not an error — headless logic continuity preserved via the
# _build_map_resource_for_chapter() fallback in this same _ready() above.
var chapter_scene_path: String = "res://scenes/battle/%s.tscn" % chapter.map_id
if ResourceLoader.exists(chapter_scene_path):
    var chapter_scene: PackedScene = load(chapter_scene_path) as PackedScene
    if chapter_scene != null:
        var chapter_visuals: Node = chapter_scene.instantiate()
        _grid_layer.add_child(chapter_visuals)
    else:
        push_warning("ADR-0021: failed to load chapter visual scene at '%s'" % chapter_scene_path)
else:
    push_warning(("ADR-0021: chapter visual scene missing at '%s'; "
        + "running with blank world-space (headless logic intact, "
        + "windowed mode will render void). POLISH-010-class issue.")
        % chapter_scene_path)

# === STEP 2: BattleCamera (ADR-0013) === [unchanged]
# ... and STEP 3+, STEP 5.5, STEP 6 unchanged ...
```

**Numbering rationale (Path A)**: STEP 1.5 preserves ADR-0016 §3 1-7
numbering (existing 1, 2, 3, 4, 5, 5.5, 6) for backward compatibility with
existing references. Full renumber to 1-8 deferred per same precedent as
the AISystem STEP 5.5 insertion (2026-05-05 /architecture-review delta #14
Path A). When sufficient renumbering pressure accumulates (3+ inserted
half-steps), a future ADR-0016 amendment can perform the full renumber as a
single transaction.

**`_grid_layer` reference**: ADR-0016 §2 already designates `GridLayer
Node2D` as a child of `BattleScene` in the editor-authored `.tscn`. The
existing `battle_scene.gd` resolves it via `@onready` or `$GridLayer` —
verify against current implementation when S14-02 lands the patch. If the
field resolution pattern needs adjustment, do it inline at the S14-02
implementation site; this ADR does not prescribe the resolution mechanism.

## Alternatives Considered

### Alternative 1: ColorRect/Label fallback in production (POLISH-010 Option B)

- **Description**: Port prototype-tier runtime visual builder into
  `battle_scene.gd` as a synthesized fallback when no authored `.tscn` exists.
  Renders placeholder grid + units via ColorRect overlays.
- **Pros**: 30-50 LoC patch; quick stop-gap; visible rendering in windowed
  mode immediately; preserves "demo-able" production state at POLISH-010
  disposition without authoring effort
- **Cons**: Blurs prototype/production tier boundary explicitly forbidden by
  `.claude/rules/prototype-code.md`; AD-PHASE-GATE rerun-2 strictly rejects
  this option ("Option B prototype-tier fallback rejected — violates tier
  boundary"); visual identity anchor (ink-wash palette + silhouettes) cannot
  be expressed via flat ColorRect; future authored-art replacement requires
  re-removing this code, generating churn; AD's "world-space visual
  presence" gate criterion (sprint-14 S14-07) would still flag this as
  non-compliant
- **Estimated Effort**: 30-50 LoC + ADR alignment (~1-2hr)
- **Rejection Reason**: AD-rejected at gate-check rerun-2; tier-boundary
  violation; does not satisfy AD-led "world-space visual presence" gate
  criterion

### Alternative 2: Mount visuals at BattleScene root (sibling to GridLayer)

- **Description**: Instance the chapter visual scene as a direct child of
  `BattleScene Node2D`, parallel to GridLayer + HUDLayer (instead of nested
  under GridLayer)
- **Pros**: Slightly flatter scene tree; conceptually simpler "chapter
  visuals live alongside structural Layers"
- **Cons**: Breaks ADR-0016 §2 line 164 GridLayer "world-space scope"
  designation; UI-GB-12/13/14 grid-overlays already mount under GridLayer
  (per ADR-0015 §2) and would render BELOW the new chapter-visual sibling
  unless reordered; visualizing relative draw order requires understanding
  CanvasLayer rendering rules, which is a needless complication when
  GridLayer is already the established world-space anchor
- **Estimated Effort**: Same as chosen approach (~30 LoC patch)
- **Rejection Reason**: Disrupts ADR-0016 §2 GridLayer contract for marginal
  flatness gain

### Alternative 3: Per-system rendering responsibility (push rendering into existing logic systems)

- **Description**: Push rendering duties INTO existing logic systems —
  `MapGrid` extends `Node2D` + draws tiles via `_draw()`;
  `GridBattleController` instances unit `Sprite2D` children directly
- **Pros**: No new infrastructure; reuses existing 7-system mount sequence
  without insertion
- **Cons**: Conflates LOGIC + VISUAL responsibility (violates separation of
  concerns); breaks "MapGrid = data + lookup only" per ADR-0004 + ADR-0014
  §1 explicit contract; would require extending BattleUnit + MapGrid public
  APIs with rendering hooks; couples visual asset paths to data-layer code;
  tests for LOGIC suddenly need rendering pipeline (1288 tests would need
  audit + likely substantial rewriting)
- **Estimated Effort**: 2-3 days (substantial refactor + test rewriting)
- **Rejection Reason**: Architectural regression; violates ADR-0004 +
  ADR-0014 contracts; massive test-baseline impact; long-term maintenance
  cost dominates short-term insertion savings

### Alternative 4: POLISH-010 Option C deferral ADR (defer rendering responsibility to Production milestone N)

- **Description**: Ratify ADR-0021 with deferral language — "Production stage
  advancement proceeds with documented risk; world-space rendering
  responsibility ratified at Production milestone N." Accept blank
  world-space as documented Pre-Production-tier state through Production.
- **Pros**: Unblocks `production/stage.txt` flip without authoring chapter
  `.tscn`; lighter-touch scoped ADR (~1hr); CD-tolerant per gate-check
  rerun-2 ("Option C deferral ADR tolerated")
- **Cons**: Defers the actual contract definition without resolving it;
  sprint-14 S14-02 still has nowhere to land Option A (which is CD + AD's
  preferred path); AD requires "world-space visual presence" gate criterion
  before AD signoff (sprint-14 S14-07); user-facing build remains visually
  broken through Production milestone N; risk of indefinite postponement
  chains (deferral compounds when no forcing function exists); does NOT
  actually address the rendering-responsibility-unassigned-across-ADRs gap
  TD identified
- **Estimated Effort**: ~1hr scoped doc
- **Rejection Reason**: Deferral does NOT resolve the contract gap. Sprint-14
  S14-02 Option A still needs the contract definition. Choosing the chosen
  approach (this ADR's primary path) defines the contract once, lets S14-02
  implement against it, and avoids needing a follow-on ADR at Production
  milestone N. Deferral is strictly worse on every dimension except
  immediate-effort.

## Consequences

### Positive

- Production sprints have a clear, contract-bound interface for chapter
  visual authoring — sprint-14 S14-02 implementation is unambiguously
  specified with named owner (technical-artist + godot-gdscript-specialist),
  asset paths, and mount integration
- POLISH-010 disposition (Option A path) has architectural footing
- Prototype/production tier boundary is reinforced explicitly (§4) —
  candidate input for sprint-13 retro AI G-30 codification + future lint
  authoring (forbid `ColorRect.new()` + visual runtime construction in
  `src/feature/battle_scene/`)
- ADR coverage gap closed for `/architecture-review` traceability matrix —
  battle-scene rendering responsibility now traces from GDD → ADR-0021 →
  S14-02 implementation
- AD's "world-space visual presence" gate criterion (sprint-14 S14-07) has a
  concrete Node + path target to assert against (chapter visuals mounted
  under GridLayer; screenshot evidence at `production/qa/evidence/`)
- 4-sprint S7-11 + 5-sprint S8-15 carry-chains terminate cleanly once S14-02
  + S14-03 land — no further deferral chain risk

### Negative

- Sprint-14 S14-02 implementation is committed to authoring
  `mvp_chapter_01.tscn` (Option A) — the only deferral path remaining is a
  formal Option C deferral ADR amendment to this ADR, which adds bookkeeping
  overhead if sprint-14 timeline slips
- `battle_scene.gd._ready()` adds a STEP 1.5 mount + missing-asset warning
  path → small surface-area increase in production code (~10-15 LoC patch)
- Future BattleUnit extensions for unit-level asset binding (`sprite_path` /
  `animation_set_id` etc.) will need ADR-0014 §3 amendment + DI signature
  evolution at the visual-tier epic
- Prototype-tier `ColorRect` rendering can NEVER be promoted to production
  (mechanically forbidden by §4) — if a future sprint needs an ultra-quick
  visual demo, the answer is "author a stripped-down `.tscn`" not "port the
  prototype rendering"

### Neutral

- Headless logic remains unaffected — `_build_map_resource_for_chapter()`
  fallback preserves 1288/1288 baseline
- Existing 7-system mount sequence (ADR-0016 §3) is untouched; STEP 1.5 is
  additive (Path A precedent)
- Per-platform renderer backend (D3D12 / Metal / Vulkan) handling is
  unchanged — Godot's renderer abstracts the chapter visual mount across all
  three platforms identically

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| ADR conflicts with future visual-tier production epic decisions | Low | Medium | This ADR is interface-only (§0 scope statement); epic-level rendering implementation details (sprite formats, TileMap configs, animation systems, shader strategy) remain open. Re-validate at epic-spawn time. |
| `mvp_chapter_01.tscn` authoring effort exceeds 2hr budget (sprint-14 R1 carry) | Medium | Medium | Time-box S14-02 to 0.5d max per sprint-14 plan §10 R1; if approaching limit, fall back to formal Option C deferral ADR amendment (1hr scoped). Both paths satisfy gate-check rerun-3 Item 5. |
| ADR-0014 / ADR-0016 amendments needed beyond STEP 1.5 codification | Low-Medium | Low | This ADR amends ADR-0016 §3 mount sequence at ratification (§6 above). ADR-0014 §3 reference (§5 above) is read-only; no amendment needed unless visual-tier epic requires BattleUnit DI signature changes. Document any cross-ADR amendments at the implementation site. |
| Visual evidence assertion (AD criterion S14-07) blocked by tooling unavailability | Low | Medium | Manual screenshot evidence is the immediate path (S14-02 acceptance criterion); automated visual smoke harness CI deferred to sprint-15+ (sprint-13 retro AI G-30 codification candidate; sprint-14 S14-06). |
| `_grid_layer` resolution pattern in existing `battle_scene.gd` conflicts with §6 STEP 1.5 patch | Low | Low | Verify resolution pattern (`@onready var _grid_layer: Node2D = $GridLayer` or analogous) at S14-02 implementation site; adjust patch inline if needed. ADR §6 does not prescribe the resolution mechanism. |
| `ResourceLoader.exists()` semantics change in future Godot version | Very Low | Low | API is pre-4.4 stable; re-verify on engine upgrade. If signature drifts (G-29-class), update fallback ladder per the G-29 pattern. |

## Performance Implications

| Metric | Before | Expected After (with mvp_chapter_01.tscn shipped) | Budget |
|--------|--------|---------------------------------------------------|--------|
| CPU (frame time) | 16.6ms target | 16.6ms target — chapter `.tscn` instance is one-time at `_ready()`, no per-frame cost | 16.6ms |
| Memory | ~150MB baseline (prototype reference) | +5-15MB (chapter `.tscn` sprite textures + TileMap data; depends on art-bible asset specs) | 512MB mobile, 1GB PC |
| Load Time | ~0.5s (battle_scene boot) | +0.1-0.3s (chapter `.tscn` instantiate + texture load) | <2s scene change budget |
| Draw Calls | <100 (HUD-only baseline) | +50-200 (TileMap layer + unit Sprite2D children; depends on art-bible specs) | <500 (mobile target) |
| Network | N/A (single-player) | N/A | N/A |

**Note**: Memory + draw-call estimates are placeholder ranges pending visual-tier epic asset specs. Formal performance budget validation belongs to the visual-tier epic, not this ADR.

## Migration Plan

This ADR ratifies an interface contract; the migration is sprint-14 S14-02
implementation. Steps:

1. **S14-01 (this ADR)**: Ratify ADR-0021 with status `Accepted`. ADR-0016
   §3 mount sequence amended via §6 above (STEP 1.5 codified at this ADR's
   §6, not requiring a separate ADR-0016 patch).
   **Verify**:
   `docs/architecture/ADR-0021-production-world-space-rendering-responsibility.md`
   exists with status `Accepted`; §6 specifies STEP 1.5 mount integration;
   cross-references to ADR-0014 §3 + ADR-0016 §3 present.
2. **S14-02 (Option A path)**: Author `assets/data/maps/mvp_chapter_01.tres`
   + `scenes/battle/mvp_chapter_01.tscn`; implement STEP 1.5 mount in
   `battle_scene.gd._ready()`; capture visual evidence at
   `production/qa/evidence/sprint-14-polish-010-evidence.md`.
   **Verify**: windowed boot renders non-blank world-space; existing
   1288/1288 PASS preserved; ERROR `Cannot open file
   'res://scenes/battle/mvp_chapter_01.tscn'` reduced to 0 occurrences in
   headless boot stderr.
3. **S14-03 (user re-attestation)**: User re-runs S8-15 §1.2/1.3/3.2
   attestation against post-S14-02 build.
   **Verify**: §1.2/§1.3/§3.2 verdicts flip MIXED → clean PASS at
   `production/qa/qa-signoff-sprint-8-2026-05-06.md` §S8-15.
4. **S14-04 (gate-check rerun-3)**: `/gate-check pre-prod-to-prod` rerun-3.
   **Verify**: verdict PASS or CONCERNS recorded; if PASS, `production/stage.txt`
   flips Pre-Production → Production.

**Rollback plan**: if S14-02's STEP 1.5 mount introduces test regressions,
revert the `battle_scene.gd` patch + retain ADR-0021 as the ratified contract
for re-attempt at sprint-15. ADR ratification itself has no code impact and
is not reverted; only the S14-02 implementation patch is reversible in
isolation. If ADR design itself proves wrong (e.g., GridLayer mount turns
out to be fundamentally incompatible with art-bible visual requirements
discovered during S14-02), supersede via ADR-0022 with status `Superseded
by ADR-0022`.

## Validation Criteria

- [ ] ADR-0021 file exists at
      `docs/architecture/ADR-0021-production-world-space-rendering-responsibility.md`
      with status `Accepted`
- [ ] §1 specifies the responsible Node (chapter-scope `.tscn` mounted under
      GridLayer)
- [ ] §2 specifies canonical asset paths (`assets/data/maps/{map_id}.tres`
      + `scenes/battle/{map_id}.tscn`)
- [ ] §3 specifies fallback behavior (warning + headless continuity, NO
      ColorRect substitution)
- [ ] §4 codifies the prototype/production tier boundary
- [ ] §5 cross-references ADR-0014 §3 BattleUnit field-extension precedent
- [ ] §6 amends ADR-0016 §3 mount sequence with STEP 1.5
      ChapterVisualScene mount entry
- [ ] Engine Compatibility section present + filled
- [ ] GDD Requirements Addressed section present + filled
- [ ] `/architecture-review` traceability matrix update queued for
      sprint-14 retro AI follow-on (post-S14-04 PASS)

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|--------------|--------|-------------|---------------------------|
| `design/gdd/battle-scene.md` (or successor) | Battle VS | "Production main_scene must render battle visuals (tiles + units) in windowed mode, not just in prototype scenes" | §1 + §2 define authored `.tscn` responsibility + canonical path; §3 defines missing-asset warning + gate-check implications; §6 codifies the mount integration into `BattleScene._ready()` |
| `design/art-bible.md` (anchor + visual identity) | Art Direction | "Production main_scene must be capable of demonstrating ink-wash palette, tile color language, and unit silhouette specs in the canonical playable build" | §1 mounts authored visuals under GridLayer (world-space scope); §4 forbids prototype-tier ColorRect substitution that would render the art-bible experientially untestable in production; AD's "world-space visual presence" gate criterion (sprint-14 S14-07) gets a concrete Node + path target |
| `design/gdd/scenario-progression.md` (ADR-0017 anchor) | Scenario Progression | "Chapter resolution must produce a playable battle scene driven by the active chapter's `map_id`" | §2 binds the visual asset path to `ChapterDefinition.map_id`, completing the data + visual pairing per chapter |

> If specific GDD section IDs differ from the entries above, the
> `/architecture-review` Phase 8 TR-registry update during sprint-14 retro
> AI follow-on will reconcile.

## Related

- ADR-0004 MapGrid Data Model — data layer; complemented by visual layer per
  this ADR §1 + §2
- ADR-0013 BattleCamera — viewport framing for the world-space scope
  containing the chapter visuals
- ADR-0014 GridBattleController §3 — BattleUnit field-extension precedent
  referenced in §5; future visual-tier epic may amend
- ADR-0015 Battle HUD §2 — UI-GB-12/13/14 grid-overlays mount under same
  GridLayer; draw-order compatible with chapter-visual sibling
- ADR-0016 BattleScene Wiring §2 + §3 — mount sequence amended via §6 above
  (STEP 1.5 ChapterVisualScene insertion); GridLayer "world-space scope"
  designation referenced in §1
- ADR-0017 Scenario Progression — `ChapterDefinition.map_id` field drives §2
  asset path resolution; line 129 + `chapter_definition.gd:23` docstring
  align with this ADR's path convention
- POLISH-010 entry at `production/polish-backlog.md:279-328` — release-blocker
  resolved by sprint-14 S14-02 Option A implementing this ADR
- POLISH-009 entry at `production/polish-backlog.md` — bundled with
  POLISH-010 fix (single chapter `.tres` + `.tscn` pair likely resolves both
  per S14-02 acceptance criteria)
- Sprint-14 plan `production/sprints/sprint-14.md` — S14-01 + S14-02 + S14-03
  + S14-04 dependency chain; this ADR is S14-01
- Gate-check rerun-2
  `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-2.md` Item 6 —
  TD-led path-to-PASS item resolved by this ADR's ratification
- `prototypes/chapter-prototype/chapter.gd` — prototype-tier reference; §4
  forbids cross to production
- `.claude/rules/prototype-code.md` — prototype-tier authoring standards;
  §4 reinforces structurally
