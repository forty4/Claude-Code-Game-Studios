## Palette — single source of truth for all named colour tokens.
##
## Palette tokens — see design/art/art-bible-v1-distilled.md §1
##
## Six base tones + three faction reads, as defined in the distilled art bible.
## Use these consts everywhere a named colour is needed in GDScript code,
## ColorRect.color assignments, and add_theme_color_override() calls.
##
## Godot Theme .tres resources cannot reference autoloads or class consts, so
## any theme file must be kept in sync with the hex values here manually.
## This file is the authoritative source — theme files are downstream.
##
## NO class_name collision with built-ins (G-12 verified).
## NO autoload — pure static consts, zero runtime state.
## Run `godot --headless --import --path .` after first creating this file (G-14).

class_name Palette


# ─── Six named palette tokens (art-bible-v1-distilled.md §1) ─────────────────

## 묵 (Ink) #1C1A17 — Outlines, history's weight, defeat.
## Never use as sole background fill.
const MUK: Color = Color(0.109, 0.102, 0.090, 1.0)  # #1C1A17

## 지백 (Paper White) #F2E8D4 — Negative space, undecided fate.
## Never use for warnings.
const JI_BAEK: Color = Color(0.949, 0.910, 0.831, 1.0)  # #F2E8D4

## 황토 (Ochre Earth) #C8874A — The land of the Central Plains.
## Backgrounds, UI panels, Shu faction accents.
const HWANG_TO: Color = Color(0.784, 0.529, 0.290, 1.0)  # #C8874A

## 청회 (Blue-Grey) #5C7A8A — Cold armour, tactical UI, player control.
## Never use for destiny-branch moments.
const CHEONG_HOE: Color = Color(0.361, 0.478, 0.541, 1.0)  # #5C7A8A

## 주홍 (Vermillion) #C0392B — Destiny-branch ONLY. The colour of irreversible choice.
## Appears nowhere else. Its absence in Phases A–D is what makes Phase E land.
const JU_HONG: Color = Color(0.753, 0.224, 0.169, 1.0)  # #C0392B

## 금색 (Gold) #D4A017 — Legendary / destiny-reversed ONLY. Five-star cascade dawn.
## The legendary SFX and gold ColorRect tween are this colour's only
## current in-engine expressions. B1.2 signature VFX must use this token.
const GEUM_SAEK: Color = Color(0.831, 0.627, 0.090, 1.0)  # #D4A017


# ─── Faction identity colours (art-bible-v1-distilled.md §1) ─────────────────

## Shu faction #2E5F7A — deep blue, justice. Identity marker only.
## Never substitute for 주홍 or 금색.
const FACTION_SHU: Color = Color(0.180, 0.373, 0.478, 1.0)  # #2E5F7A

## Wei faction #4A4A4A — iron grey, dominance. Identity marker only.
const FACTION_WEI: Color = Color(0.290, 0.290, 0.290, 1.0)  # #4A4A4A

## Wu faction #2D6B4A — deep green, adaptive. Identity marker only.
const FACTION_WU: Color = Color(0.176, 0.420, 0.290, 1.0)  # #2D6B4A


# ─── UI utility token (not a named art-bible tone) ────────────────────────────

## UI_GOLD #E8D68A — soft warm gold for UI text (victory, vivid labels, archive headers).
## Deliberately NOT #D4A017 (GEUM_SAEK). Multiple files note this distinction:
## "warm yellow, NOT #D4A017". This is a UI-hierarchy colour, not the reserved
## legendary emotional punctuation. B1.2/B1.5 should keep GEUM_SAEK for VFX
## and reserve UI_GOLD for text-only vivid states.
const UI_GOLD: Color = Color(0.910, 0.839, 0.541, 1.0)  # #E8D68A

## MUK_OUTLINE — canonical dark ink for font outlines. Identical to MUK but
## named separately so call sites document their intent (outline vs fill).
## Alpha always 1.0 — outlines at partial alpha wash out against light backgrounds.
const MUK_OUTLINE: Color = MUK

## BACKDROP_DARK — near-black backdrop for full-screen overlays (StoryBeatScreen,
## ConsequenceScreen, PauseMenu, SignatureArchivePopup). Near-묵 with strong
## alpha so the world shows through slightly, signalling "world is still there".
## Slight cool cast (blue channel > red) reads as "tactical pause" not "death".
const BACKDROP_DARK: Color = Color(0.035, 0.045, 0.065, 0.94)
