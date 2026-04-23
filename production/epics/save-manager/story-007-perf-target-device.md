# Story 007: Perf baseline + target-device verification (V-11 <50ms)

> **Epic**: save-manager
> **Status**: Ready
> **Layer**: Platform
> **Type**: Integration
> **Estimate**: 2-3 hours desktop substitute + 3-4 hours target-device (requires physical Android device + export setup)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; perf target from ADR-0003 §Performance Implications + §Validation Criteria V-11)
**Requirement**: No direct TR (perf guardrail; informs TR-save-load-003 acceptance)
*(V-11 is a performance validation criterion, not a TR-registry entry; it's the enforcement of the control-manifest guardrail "Full save cycle — wall clock — <50 ms on mid-range Android — ADR-0003 (V-11)")*

**ADR Governing Implementation**: ADR-0003 — §Performance Implications + §Validation Criteria V-11 + §Engine Compatibility §Verification Required
**ADR Decision Summary**: "`duplicate_deep(SaveContext)` expected ~1 ms; `ResourceSaver.save` expected 2-10 ms for <20 KB payload; full save cycle <50 ms on mid-range Android (Snapdragon 7-gen target). Perf validated via 100 iterations, 95th percentile."

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Target device per ADR-0002 §Performance Implications — Snapdragon 7-gen mid-range Android. `Time.get_ticks_usec()` for microsecond measurement (pre-cutoff stable). Desktop substitute gives loose upper bound (desktop usually faster than mobile); real mid-range Android timing may differ by 2-5×. V-11 authoritative validation requires device.

**Control Manifest Rules (Platform layer)**:
- Required: Full save cycle wall clock <50 ms on mid-range Android (control-manifest §Performance Guardrails)
- Required: `duplicate_deep(SaveContext)` <~1 ms; `ResourceSaver.save(SaveContext)` <~10 ms
- Required: 95th percentile reporting (not mean) for perf validation

## Acceptance Criteria

*Derived from ADR-0003 §Performance Implications + §Validation Criteria V-11:*

- [ ] `tests/integration/core/save_perf_test.gd` exists
- [ ] Perf test runs 100 iterations of full save cycle: `save_checkpoint(ctx)` with representative SaveContext (5-15 KB, 10 EchoMarks, non-empty flags_to_set)
- [ ] Measures per-iteration wall clock via `Time.get_ticks_usec()` (microsecond resolution)
- [ ] Computes and asserts 95th percentile:
  - **Desktop baseline (AC-DESKTOP)**: <20 ms — substitute validation during CI (headless runner); flag if exceeds, log as info
  - **Target-device (AC-TARGET)**: <50 ms on Snapdragon 7-gen Android (ADR-0003 V-11); captured as manual evidence at `production/qa/evidence/save-v11-android-perf-[date].md`
- [ ] Breakdown per stage (each iteration timed):
  - `duplicate_deep` time
  - `ResourceSaver.save` time
  - `DirAccess.rename_absolute` time
- [ ] Target-device verification produces evidence document with:
  - Device model + Android version
  - Godot export template version
  - 100-iteration raw timings
  - 95th percentile + mean + max
  - Breakdown per stage
  - Verdict: PASS / FAIL vs 50 ms budget
- [ ] Desktop substitute status in CI is ADVISORY (not blocking) — target-device is the authoritative V-11 gate
- [ ] If target device not available this sprint, story-007 can be marked COMPLETE WITH DEFERRAL of AC-TARGET (similar to scene-manager story-007 pattern — core perf logic shipped, on-device validation in Polish phase)

## Implementation Notes

*From ADR-0003 §Performance Implications + scene-manager story-007 deferral pattern:*

1. **Desktop substitute gives loose upper bound** — x86 desktop + SSD often 3-5× faster than mid-range Android + flash. Desktop PASS at <20 ms does not guarantee mobile PASS at <50 ms; desktop FAIL >50 ms GUARANTEES mobile FAIL. Asymmetric signal.

2. **Representative SaveContext** — benchmark payload should reflect realistic late-game state:
   - 10 EchoMarks in `echo_marks_archive`
   - 5-10 entries in `flags_to_set`
   - All 12 SaveContext fields populated
   - Target serialized size 5-15 KB (matches ADR-0003 §Performance Implications expected range)

3. **100 iterations + 95th percentile** — V-11 spec. 100 iterations is enough to smooth JIT warmup, GC pauses, filesystem cache effects. 95th percentile (not mean) to catch tail-latency — mobile filesystems have occasional 10-50 ms spikes that mean-averaged metrics hide.

4. **Stage breakdown enables bottleneck isolation** — if full cycle fails V-11, per-stage timings show whether culprit is duplicate_deep (fix: reduce SaveContext size), ResourceSaver.save (fix: FLAG_COMPRESS revisit), or rename_absolute (platform filesystem issue — worth ADR revisit).

5. **Evidence document format** — mirrors scene-manager story-007 deferral pattern. Template:
   ```markdown
   # SaveManager V-11 Perf Evidence — [DATE]

   ## Device
   - Model: [e.g., Pixel 7a]
   - Android: [e.g., 14]
   - Godot export: [e.g., 4.6.0 official]

   ## Results (100 iterations)
   - 95th percentile: [X] ms
   - Mean: [Y] ms
   - Max: [Z] ms

   ## Breakdown (95th percentile per stage)
   - duplicate_deep: [A] ms
   - ResourceSaver.save: [B] ms
   - rename_absolute: [C] ms

   ## Verdict
   [PASS / FAIL] vs 50 ms V-11 budget
   ```

6. **CI integration** — desktop substitute runs in GitHub Actions as advisory (log warnings, don't fail build). Target-device is manual (human runs on real device, commits evidence doc).

7. **Deferral pattern** — if Android device not available when this story is picked, follow scene-manager story-007 closure pattern: mark AC-DESKTOP PASS, mark AC-TARGET as DEFERRED to Polish phase with evidence path TBD. Epic closes with NOTES explaining V-11 authoritative validation pending.

8. **Test placement in integration/** — not unit/, because it touches full save pipeline + filesystem. Full suite runner skips perf tests on `--filter-exclude=perf` flag if needed for fast CI; default includes it.

9. **G-10 applies** — perf test uses SaveManagerStub for temp-root isolation. Emit/handler test coverage already in story-004; this story measures performance end-to-end on the real pipeline.

## Out of Scope

- SaveContext / EchoMark classes — story 001
- Autoload skeleton — story 002
- Test stub — story 003
- Save pipeline — story 004 (being perf-measured here)
- Load pipeline — story 005 (load perf is ≤15 ms per ADR §Performance Implications; not separately validated; covered by V-7 test in story-005)
- Migration registry — story 006
- CI lint — story 008

## QA Test Cases

*Test file*: `tests/integration/core/save_perf_test.gd`

- **AC-DESKTOP** (desktop baseline under 20 ms):
  - Given: stub; representative SaveContext (10 EchoMarks, 5 flags, all fields populated); 100 iteration warmup+measure loop
  - When: run full `save_checkpoint` cycle 100× and record per-iteration `Time.get_ticks_usec()` delta
  - Then: 95th percentile < 20000 μs (20 ms); log mean + max to stdout for CI
  - Status: ADVISORY on CI; logs failure but doesn't block PR

- **AC-TARGET** (target-device <50 ms — Snapdragon 7-gen Android):
  - Given: exported Godot 4.6 APK on mid-range Android (Snapdragon 7-gen or equivalent); same test file run on-device
  - When: same 100-iteration loop
  - Then: 95th percentile < 50000 μs (50 ms); evidence at `production/qa/evidence/save-v11-android-perf-[date].md`
  - Status: BLOCKING for V-11 authoritative validation; DEFERRABLE to Polish if device unavailable

- **AC-BREAKDOWN** (per-stage timing breakdown):
  - Given: same iteration loop with nested timers around each stage (duplicate_deep, ResourceSaver.save, rename_absolute)
  - When: run 100 iterations
  - Then: stdout emits per-stage 95th percentile; values roughly match ADR-0003 §Performance Implications expectations (~1 ms duplicate_deep, 2-10 ms save, <5 ms rename)

- **AC-PAYLOAD-SIZE** (serialized payload size in expected range):
  - Given: representative SaveContext serialized to `.res`
  - When: `FileAccess.get_file_as_bytes(path).size()`
  - Then: 5-15 KB range (ADR-0003 expected); if >50 KB, flag for FLAG_COMPRESS decision review

- **AC-WARMUP** (first iteration much slower than steady state):
  - Given: 100 iterations with per-iteration timings recorded
  - When: compare iteration 1 vs iterations 10-100
  - Then: iteration 1 is within 3× of steady state (JIT warmup discipline); if >5× slower, investigate
  - Rationale: detects pathological first-call costs that might indicate autoload init or schema-parse overhead

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Desktop: `tests/integration/core/save_perf_test.gd` — test must exist and AC-DESKTOP logs pass
- Target-device: `production/qa/evidence/save-v11-android-perf-[date].md` — manual evidence from Android device
**Status**: [ ] Not yet created

**Deferral allowed**: AC-TARGET can be deferred to Polish phase if mid-range Android device not available (mirrors scene-manager story-007 pattern).

## Dependencies

- **Depends on**: story-004 (save pipeline must be complete to measure), story-005 (full load cycle is implicit prerequisite; test uses save + verify flow), story-003 (SaveManagerStub for temp-root isolation)
- **Unlocks**: Save-manager epic CORE-COMPLETE milestone (epic closure once V-11 passes OR is explicitly deferred)
