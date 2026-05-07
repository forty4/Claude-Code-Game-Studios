# Decision: CI Lane Gap — POSTPONE TO POST-MVP

> **Status**: BINDING (sprint-10 S10-05; closes 3-sprint deferral chain sprint-7 AI #5 → sprint-8 AI #8 → sprint-9 AI #10)
> **Decision Date**: 2026-05-07
> **Author**: claude (sprint-10 S10-05 owner; per sprint-9 retro AI #5 mandate)
> **Reactivation Owner**: producer (at next gate-check or VS-close trigger, whichever first)

---

## Decision

**Defer macOS / iOS / Android CI lane authoring to post-MVP Production-stage hardening pass.**

Linux Editor + Windows D3D12 lanes remain the active CI matrix. Manual-fallback per ADR-0018 OQ-DB-6 stays in force for the 3 deferred platforms until a reactivation trigger (below) fires.

This is a **time-bound deferral with explicit reactivation triggers** — NOT an open-ended "later." Each trigger below has a measurable signal that the producer or this author must monitor; firing any one of them re-opens this decision.

## Why postpone (and not author lanes now)

Three load-bearing reasons:

1. **The decision was deferred 3 consecutive sprints (sprint-7 AI #5 → sprint-8 AI #8 → sprint-9 AI #10) despite explicit "force decision" framing.** Per sprint-9 retro line 81 verbatim: *"S9-11 (CI lane gap) is a process smell — recurring deferral despite explicit 'force decision' framing in 3 consecutive sprints. Pattern indicates the decision is not actually time-constrained but is awaiting some implicit precondition (likely: post-MVP Production-stage hardening pass)."* The 3-sprint pattern is itself evidence that the decision's natural timing is not now.

2. **Verification value of the 3 deferred lanes is LOW until VS close.** ADR-0018 OQ-DB-6 — the only currently-codified consumer of multi-platform CI — is marked BLOCKING-for-VS (Vertical Slice) close, not BLOCKING-for-MVP-implementation. No sprint-10 (or earlier) work product currently depends on macOS Metal / iOS Metal / Android Vulkan ResourceSaver/Loader round-trip verification being automated. Authoring the lanes now produces no marginal verification gain over the 1236/1236 PASSING Linux+Windows baseline that has held since sprint-7 close.

3. **Cost-side: macOS + iOS lanes are BLOCKED on user-paid prerequisites that don't exist yet** (Apple Developer Program membership $99/yr × 2 platforms; macOS code-signing certificate; iOS provisioning profile; GitHub Actions secrets configuration). Even Android (free Android NDK) requires emulator/runner setup time that exceeds the 0.2d sprint-10 S10-05 budget. Authoring runnable lane workflow files in <0.2d is **not feasible** on the cost side; partial-authoring (broken stub workflows that always fail) would actively harm CI signal quality.

The combination of (1) low value + (2) high cost + (3) recurring-pattern-evidence-of-implicit-precondition makes the binding outcome **postpone**, not ship.

## What is NOT being decided here

This decision does NOT:

- Cancel the multi-platform CI verification requirement permanently. ADR-0018 OQ-DB-6 remains an open question with a BLOCKING-for-VS gate.
- Reduce the manual-fallback obligation. macOS / iOS / Android verification of `DestinyBranchChoice` `ResourceSaver`/`ResourceLoader` round-trip on each platform's release build remains a manual gate before VS close (per ADR-0018 §Engine Compatibility "Verification Required" item (1) + Implementation Note IN-1).
- Affect Linux Editor + Windows D3D12 CI lane operation. Both lanes continue as the active CI matrix; no regression risk to current 1236/1236 PASSING baseline.
- Touch `.github/workflows/tests.yml`. The workflow file remains unchanged this sprint.

## Reactivation Triggers

This decision **automatically re-opens** when any one of the following becomes true. The producer must monitor these at every gate-check pass:

### Trigger 1 — Pre-Production → Production gate upgrade fires

When `production/stage.txt` flips to `Production` (per `gate-check` `production/gate-checks/pre-prod-to-prod-2026-05-04.md` path-to-PASS sequence), the next sprint must re-evaluate this decision. Production-stage hardening pass is the **natural reactivation point** per sprint-9 retro line 81 implicit-precondition hypothesis.

**Signal**: `production/stage.txt` content changes from `Pre-Production` to `Production`.

**Required action when fired**: producer opens new sprint task "Re-evaluate CI lane gap post-Production-stage transition" with re-authoring as default outcome; this decision doc is referenced + appended-to with the re-eval rationale.

### Trigger 2 — VS-implementation story for destiny-branch or scenario-progression opens

When any sprint plan adds a story whose acceptance criteria explicitly require `DestinyBranchChoice` `ResourceSaver`/`ResourceLoader` round-trip verification on all 5 platforms (i.e., closing OQ-DB-6 binding gate) — either at story-readiness time OR at /create-stories invocation, the lane authoring becomes blocking-for-that-story.

**Signal**: any story file in `production/epics/` includes the literal string `OQ-DB-6` in an Acceptance Criterion AND the AC is gated on automated CI verification (not manual fallback).

**Required action when fired**: that story's /story-readiness check returns NEEDS WORK (CI infrastructure prerequisite); this decision is re-opened in the SAME sprint as the story, not deferred.

### Trigger 3 — User authorizes platform-cert prerequisites

When the user (Dowan Kim per CLAUDE.md project-instructions) provides any of:

- Apple Developer Program membership credentials (enables macOS notarization + iOS provisioning lanes)
- Android keystore (free; enables Android Vulkan lane authoring without other prerequisites)
- GitHub Actions secrets configured for any of the above

**Signal**: explicit user message stating prerequisites are in place, OR a GitHub Actions secret named `MACOS_CERT_*` / `IOS_PROFILE_*` / `ANDROID_KEYSTORE_*` is added to repo settings.

**Required action when fired**: producer adds CI lane authoring as a Should-Have story to the next sprint (Android-only authoring is feasible in 0.2-0.3d standalone; macOS+iOS together is 0.5-0.8d).

### Trigger 4 — A 5-platform certification deferral becomes a release blocker

When release-checklist or launch-checklist pass identifies a deferred verification item (currently ADR-0018 OQ-DB-6 manual-fallback + ADR-0017 V-2 JSON parse perf manual-fallback per sprint-7 R-3) as a binding release-gate item (i.e., release cannot ship without automated CI verification on the missing platform).

**Signal**: a /launch-checklist or /release-checklist run produces a FAIL verdict whose blocker line cites missing macOS / iOS / Android automated CI verification.

**Required action when fired**: emergency hotfix-style sprint priority promotion; lane authoring becomes Must-Have in the smallest containing sprint.

## Dependency on User Actions

The macOS + iOS lanes have **hard blockers on user actions** (no claude-side workaround exists):

1. **Apple Developer Program membership** ($99/yr per platform; user-paid). Without this, code-signing on macOS + provisioning on iOS cannot work; the lane workflows would only produce unsigned development builds, which is insufficient for the 5-platform serialization round-trip verification that ADR-0018 OQ-DB-6 needs (signed build behavior may differ from unsigned per Apple platform policies).
2. **GitHub Actions secrets** for the Apple credentials above.

The Android lane has **NO user-action blocker** — Android keystore can be generated by claude (free), Android NDK is free, and `actions/setup-android` is a public action. Authoring Android-only is feasible in a future 0.3d slot if the user wants the partial coverage.

If the user wants to **partially activate** this decision (Android only, deferring macOS + iOS): say so explicitly; this decision can be amended via a follow-up entry below. Otherwise, the all-or-nothing postponement holds.

## Cost-Benefit Summary

| Factor | Author lanes now (sprint-10 S10-05) | Postpone to post-MVP (this decision) |
|---|---|---|
| Sprint-10 budget impact | >0.2d (insufficient — would slip Must-Have count) | 0.05d (this doc) |
| Verification value pre-VS | LOW (no current consumers binding) | LOW (same; manual fallback continues) |
| Verification value post-VS | HIGH if reactivated at trigger 2 | HIGH (reactivation is mandatory at trigger 2) |
| CI signal quality risk | HIGH (broken-stub authoring would always-fail on macOS/iOS lacking certs) | LOW (no change to current 1236/1236 PASSING Linux+Windows lanes) |
| User-action prerequisite | macOS + iOS BLOCKED on $99/yr × 2 | Reactivation defers user-paid prerequisite to post-MVP |
| 3-sprint deferral pattern alignment | violates "force decision" intent if forced now without prerequisites | aligns with sprint-9 retro implicit-precondition hypothesis |

## Why this satisfies sprint-9 retro AI #5 mandate

Sprint-9 retro Action Item #5 verbatim: *"CI lane gap formal decision (S9-11) MUST ship in sprint-10 with binding outcome — either author at least 1 new lane workflow OR write formal post-MVP postponement rationale doc; no further deferral."*

Per the AND/OR structure of that AI (author lane OR write rationale doc), this document satisfies the OR branch. The decision is:

- **Recorded**: this file.
- **Binding**: 4 reactivation triggers above are explicit, signal-driven, and have required-action procedures. The decision automatically re-opens when any trigger fires.
- **Not deferred**: this is the binding outcome, not another "force decision next sprint."
- **No-further-deferral verifiable**: sprint-10 retrospective will validate this doc shipped + signed-off; sprint-11 plan cannot list "CI lane gap formal decision" as a fresh item.

## Cross-references

- Sprint-9 retro action item #5: `production/retrospectives/retro-sprint-9-2026-05-07.md` line 184
- Sprint-9 What-Went-Poorly #2 (process smell analysis): `production/retrospectives/retro-sprint-9-2026-05-07.md` line 81
- Sprint-10 plan §138 R8 mitigation guidance (path-of-least-resistance): `production/sprints/sprint-10.md` line 138
- ADR-0018 OQ-DB-6 BLOCKING-for-VS gate: `docs/architecture/ADR-0018-destiny-branch.md` lines 18, 74, 90, 572, 678, 700, 732-734, 763-765, 794
- Sprint-7 R-3 Linux+Windows-only mitigation precedent: `production/sprints/sprint-7.md` (Linux Editor + Windows D3D12 lanes only; manual-fallback for other platforms; full 5-platform CI deferred to release-prep sprint)
- Existing CI workflow: `.github/workflows/tests.yml` (Linux Editor + Windows D3D12 lanes — unchanged this sprint)
- Production stage marker: `production/stage.txt` (currently `Pre-Production`; trigger 1 monitors)

## Amendment log

*Append future amendments below — do not rewrite the body above.*

- 2026-05-07 — Initial binding decision recorded (S10-05 close-out).
