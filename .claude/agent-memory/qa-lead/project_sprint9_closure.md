---
name: Sprint-9 input-handling epic closure state
description: Sprint-9 closed input-handling epic 10/10; Foundation layer 5/5 complete; 4 Polish-deferred verification items tracked TD-068; 5 cross-system contracts locked TD-069
type: project
---

Sprint-9 (2026-05-07) closed the input-handling epic 10/10 with APPROVED WITH CONDITIONS verdict.

**Why:** Epic is Foundation-layer (InputRouter autoload) with no playable runtime; all QA coverage is headless GdUnit4 + lint scripts + evidence docs. Standard 7-phase team-qa cycle collapsed to single sign-off pass per 5-prior-precedent pattern.

**How to apply:** Future Foundation-layer epic closures follow the same pattern — no manual smoke batch playthrough, single sign-off pass is sufficient when coverage is 100% headless.

Key facts at close:
- Test baseline: 1203 PASS / 0 errors / 0 failures / 0 orphans / Exit 0 (46th consecutive FFB)
- 7 CI lint scripts wired and all PASS
- 4 verification items Polish-deferred (TD-068): #1 dual-focus, #2 SDL3 gamepad, #5a-Android, #6 touch index stability
- 4 verification items headless-confirmed: #3 emulate_mouse_from_touch, #4 recursive Control disable, #5a macOS, #5b safe-area API
- 5 cross-system provisional contracts locked (TD-069): Camera, Grid Battle, Battle HUD, Settings, Tutorial — widen-not-narrow
- 6 spec-drift doc-correction items queued for sprint-9 retro sweep
- User-owned attestation gates still outstanding: S9-13 (S7-11, 3rd carry) + S9-14 (S8-15, 1st carry)
- Gate-check remains CONCERNS until S9-13 + S9-14 resolved
