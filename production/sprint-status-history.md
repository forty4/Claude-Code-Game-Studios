# Sprint Status History

> **Purpose**: Archive of long-form completion notes from `production/sprint-status.yaml` per sprint-3 retro AI #3.
>
> **Policy** (S3-05 amendment to `/story-done` skill, 2026-05-02):
> - Top-level `updated:` field in sprint-status.yaml capped at **200 chars**.
> - Per-story `#` changelog comments in sprint-status.yaml capped at **200 chars**.
> - When a /story-done update would exceed either cap, the FULL prior text is appended here under the matching sprint section before the YAML is truncated.
> - Most recent entry first within each sprint section.
> - Canonical "is it done?" state lives in sprint-status.yaml; this file is the long-form audit trail.
>
> **Cross-references**:
> - Source: `production/sprint-status.yaml`
> - Skill: `.claude/skills/story-done/SKILL.md` Phase 7 step 4
> - Origin: `production/retrospectives/retro-sprint-2-2026-05-02.md` Action Item #3

---

## Sprint 3

### Top-level `updated:` field — rolling history

#### 2026-05-02 (current after S3-06 close-out)

> S3-06 DONE: TD-042 RESOLVED. data-files.md §Entity Data File Exception +~75 LoC. Sprint-3 7/7 closed. See sprint-status-history.md (Top-level updated).

#### 2026-05-02 (rotated when S3-06 landed)

> S3-05 DONE: 200-byte cap active, sprint-status-history.md created, /story-done Phase 7 amended. See sprint-status-history.md (Top-level updated).

#### 2026-05-02 (rotated when S3-05 landed)

> S3-04 + /qa-plan input-handling DONE; pre-impl discipline closed. Full notes → sprint-status-history.md (Sprint 3 → Top-level updated history).

#### 2026-05-02 (rotated when /qa-plan input-handling landed)

> S3-04 DONE + /qa-plan input-handling DONE: 462-line plan covering 10 stories (6 Logic + 3 Integration + 1 Config/Data) + 6 verification items (4 mandatory headless + 2 Polish-defer) + smoke + DoD. Pre-implementation discipline closed; ready for /dev-story story-001 (sprint-4).

#### Earlier sprint-3 `updated:` values

(Not retained — were overwritten in-place during S3-00..S3-04 work before this hygiene refactor landed. Future updates rotate through this section.)

---

### S3-06 — TD-042 close-out: data-files.md Entity Data File Exception amendment (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.5d
**Priority**: nice-to-have

> 2026-05-02: TD-042 (LOW severity, doc drift) RESOLVED. (1) Amended `.claude/rules/data-files.md` with new §Entity Data File Exception section (~75 LoC, parallel structure to existing §Constants Registry Exception): exhaustive affected-files list (heroes.json + terrain_config.json + unit_roles.json), 4-point rationale (cross-doc grep-ability + @export discipline + domain shape + project-wide naming coherence), limited-scope clause (4 explicit non-targets), entity file format example with heroes.json excerpt, review-on-Alpha-DataRegistry trigger, origin trace. (2) Cross-linked from each of the 3 affected ADRs (ADR-0007 §3 + ADR-0008 §2 + ADR-0009 §4) — single-line "Key naming: snake_case per data-files.md §Entity Data File Exception (added 2026-05-02 per TD-042 close-out)" placed at the JSON-schema decision spot in each. (3) Marked TD-042 RESOLVED in `docs/tech-debt-register.md` with resolution-summary line at top. Cited by future entity-data ADRs as the canonical exception authority. Sprint-3 nice-to-have 1/1 done.

**Files touched**:
- `.claude/rules/data-files.md` — +~75 LoC (new §Entity Data File Exception section after existing §Constants Registry Exception)
- `docs/architecture/ADR-0007-hero-database.md` — +1 paragraph at §3 (heroes.json schema decision)
- `docs/architecture/ADR-0008-terrain-effect.md` — +1 paragraph at §2 (terrain_config.json schema decision)
- `docs/architecture/ADR-0009-unit-role.md` — +1 paragraph at §4 (unit_roles.json schema decision)
- `docs/tech-debt-register.md` — TD-042 marked RESOLVED with summary line

**Note**: `unit_roles.json` doesn't yet exist on disk (ADR-0009 unit-role epic implementation pending). Listed in affected files exhaustively so the rule applies the moment the file lands.

---

### S3-05 — sprint-status.yaml hygiene refactor + /story-done amendment (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.5d
**Priority**: should-have

> 2026-05-02: Retro AI #3 closed. (1) Created `production/sprint-status-history.md` (this file) with Sprint 3 archive section + top-level `updated:` rolling history + 5 archived per-story changelogs (S3-00..S3-04). (2) Truncated 6 over-cap lines in `production/sprint-status.yaml` from 240-1280 bytes down to ≤200 bytes each (line 10 updated + lines 26/37/48/59/70 per-story). (3) Amended `.claude/skills/story-done/SKILL.md` Phase 7 step 4 with explicit 200-byte cap discipline + archive instructions + UTF-8 multi-byte budget note (`→`/`≥`/`↔` = 3 bytes each). (4) Replaced sprint-status.yaml header comment with active-policy version (was: "capped at 200 chars per sprint-3 retro AI #3 (older context archived...after S3-05 ships)" → now: 6-line policy block including verification awk command + skill cross-reference). Verified all 91 lines of sprint-status.yaml ≤200 bytes via awk gate. Sprint-3 should-have 2/2 done.

**Files touched**:
- `production/sprint-status.yaml` — header rewrite + 6 line truncations + S3-05 status done + top-level `updated:` rotation
- `production/sprint-status-history.md` — created (~120 lines after S3-05 entry added)
- `.claude/skills/story-done/SKILL.md` — Phase 7 step 4 expanded with cap discipline (~25 new lines)

---

### S3-04 — input-handling /create-epics + /create-stories + /qa-plan (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.75d
**Priority**: should-have

> 2026-05-02: /create-epics + /create-stories input-handling DONE + /qa-plan input-handling DONE. EPIC.md (~310 LoC) + 10 stories scaffolded (6 Logic + 3 Integration + 1 Config/Data) + qa-plan-input-handling-2026-05-02.md (462 lines / 41 KB — largest plan in project; precedent: hp-status 38 KB). Plan covers 10 automated test paths (9 unit/integration at tests/unit/foundation/input_router_*_test.gd + 1 perf at tests/performance/foundation/) + 6 mandatory verification items (4 headless: #3 emulate_mouse_from_touch / #4 recursive Control disable / #5a screen_get_size macOS / #5b safe-area API; 2 Polish-defer: #1 dual-focus / #2 SDL3 gamepad / #6 touch event index — and #5a Android Polish-defer split) + 8 smoke critical paths + 16-item DoD. Test growth trajectory: 743 → ≥837 (+94). 5 cross-system stubs schedule: grid_battle (story-003) + battle_hud + camera (story-008) + map_grid extension (story-008). 9 CI lint scripts schedule (story-010): no_input_override / input_blocked_drop / signal_emission_outside_input / hardcoded_bindings / emulate_mouse_from_touch / balance_entities_input_handling / g15_reset / 2 carried. Pre-implementation discipline closed; ready for /dev-story story-001 (sprint-4 work — implementation NOT in sprint-3 scope per EPIC.md).

**Original char count**: 1280 (over 200-char cap).

---

### S3-03 — Admin: refresh production/epics/index.md post-sprint-3 (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.25d
**Priority**: must-have

> 2026-05-02: minimal admin pass — header + layer coverage line + Note line + hp-status row (Status Ready→Complete + Stories 8/8) + Core-pending heading + new changelog entry for S3-02 close-out. Deeper rewrite (Implementation Order historical list, Outstanding ADRs section, Next Steps Sprint-1→Sprint-3, Gate Readiness re-check) deferred per S2-04 close-out note (still scoped as dedicated follow-up story).

**Original char count**: 419 (over 200-char cap).

---

### S3-02 — Implement hp-status epic to Complete (8 stories, greenfield) (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 2.0d
**Priority**: must-have

> 2026-05-02: story-008 Complete (epic terminal Config/Data; +44KB bundle: 4 test files at tests/unit/core/hp_status_*_test.gd [perf=8412B + consumer_mutation=5364B + determinism=9204B + no_counter_attack=5782B; 8 tests total]; 5 lint scripts at tools/ci/lint_hp_status_*.sh chmod +x; 3 doc edits [architecture.yaml lint_script field appends + 1 new entry / tests.yml 5 lint steps inserted lines 84-92 / tech-debt-register.md TD-050/051/052]; 735→743/0/0/0/0 Exit 0; 8th consecutive failure-free baseline; 13th lean-mode review APPROVED WITH SUGGESTIONS 0 required changes; 1 MINOR scope-strengthening deviation verified benign in external_current_hp_write lint). EPIC TERMINAL CLOSED — hp-status 8/8 Complete; sprint-3 S3-02 must-have done.

**Inline-comment supplement** (line 47 of YAML): `# ALL 8/8 stories Complete (001-008 + epic-terminal closed)`

**Original char count**: 749 (over 200-char cap).

---

### S3-01 — /create-epics + /create-stories hp-status + /qa-plan hp-status (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.5d
**Priority**: must-have

> 2026-05-02: hp-status Core epic created (18/18 TRs traced, 0 untraced); 8 stories decomposed (4 Logic + 2 Integration + 1 borderline-skeleton + 1 Config/Data; ~22-30h total est); qa-plan-hp-status-2026-05-02.md authored covering all 8 stories.

**Original char count**: 249 (over 200-char cap by 49 chars).

---

### S3-00 — Carry-fix turn-order test_round_lifecycle_emit_order_two_units (2026-05-02)

**Completed**: 2026-05-02
**Estimate**: 0.25d
**Priority**: must-have

> 2026-05-02: test adapted to story-006 RE3 chain reality (size==5 → ≥5; round_state==ROUND_ENDING assertion dropped — chain auto-loops to ROUND_CAP=30 DRAW). Test-side only; production unchanged. Full regression 648/0/0/0/0 PASS.

**Original char count**: 240 (over 200-char cap by 40 chars).

---

## Sprint 2 and earlier

Pre-S3-05 sprint changelogs were not retroactively imported here. The full audit trail for sprints 1 and 2 lives in:

- `production/retrospectives/retro-sprint-2-2026-05-02.md`
- `production/sprints/sprint-1.md` and `production/sprints/sprint-2.md`
- Git history (commits `66144d9` for sprint-2 close-out + earlier)

Future sprint sections will be appended above the "Sprint 2 and earlier" header as each new sprint runs through this hygiene policy.
