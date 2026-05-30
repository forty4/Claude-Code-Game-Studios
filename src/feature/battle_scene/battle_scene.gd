## BattleScene — scene-root orchestrator for the battle screen.
##
## Per ADR-0016 §1: NEW pattern — scene-root-as-orchestrator. Distinct from the
## 5-precedent battle-scoped Node setup() pattern (Camera + HP/Status + Turn Order
## + Grid Battle + Battle HUD) because BattleScene IS the scene root, not a child.
##
## Mounts 6 battle-scoped child Nodes (MapGrid → BattleCamera → HPStatusController
## → TurnOrderRunner → GridBattleController → BattleHUD) in DI dependency order.
## Setup-before-add_child is enforced for all 5 systems that mandate it.
##
## Lifecycle: created and freed by ADR-0002 SceneManager (Overworld↔BattleScene
## transition flow) OR by Godot's main_scene config (sprint-6 standalone launch
## only — see ADR-0016 §5 + §Migration Plan revert path).
##
## R-7: NO GameBus subscriptions on BattleScene root.
## R-6: NO _exit_tree() body — auto-tree-free + each child's own _exit_tree().
## R-10: No static state. Not an autoload. No parameter-on-instantiate.
##
## IN-6 (implementation drift): ADR-0016 §3 shows _map_grid.load_map_resource();
##   shipped MapGrid API is load_map(res: MapResource) -> bool. Using load_map().
## IN-7 (implementation drift): ADR-0016 §4 shows MapResource.width/height/tile_data;
##   shipped MapResource fields are map_cols/map_rows/tiles: Array[MapTileData].
##   Mock builder updated to match.
## IN-8 (implementation drift): ADR-0016 §3 shows _unit_role.get_class_for_hero();
##   UnitRole has no such method (static-only class, no per-hero-class lookup at this
##   API level). Mock uses unit.unit_class (already set on BattleUnit) to call
##   HPStatusController.initialize_unit(). Sprint-7+ when real BattleConfig lands,
##   class is provided per hero definition — no code change to signature needed.
## IN-9 (implementation drift): ADR-0016 §4 shows mock tiles as Array[StringName];
##   MapResource.tiles is Array[MapTileData]. _make_uniform_grass_tiles() builds
##   properly typed Array[MapTileData] with is_passable_base=true + coord set.
## IN-10 (sprint-7 S7-02 ScenarioRunner integration 2026-05-05): mock encoder
##   block + 4 helpers DELETED. BattlePayload + ChapterDefinition now sourced
##   from ScenarioRunner.get_active_battle_config() / get_current_chapter() per
##   ADR-0017 §BattleConfig + ADR-0016 Migration Plan §1. IN-6/7/8/9 drift
##   notes preserved for traceability to grid_battle_controller / unit-role /
##   map-grid contracts. In standalone-launch mode (no SceneManager), BattleScene
##   bootstraps shu_canon_main.json scenario itself for sprint-7 +1 playable-surface delta.

class_name BattleScene
extends Node2D


# ─── Scene tree references ────────────────────────────────────────────────────

## Populated by @onready after the 3-node skeleton's _ready() fires.
## Grid-space overlays (UI-GB-12/13/14) mount under _grid_layer at runtime
## per ADR-0015 §2. HUDLayer layer=1 ensures screen-space HUD renders above all
## world-space siblings regardless of sibling order.
@onready var _grid_layer: Node2D = $GridLayer
@onready var _hud_layer: CanvasLayer = $HUDLayer


# ─── DI'd backend references (autoloads — already booted before _ready) ──────

## All 5 accessed as their class_name identifiers. Stored as fields for
## inspection and future test seam compatibility. _input_router post-S8-02
## (input-handling story-001) is typed `Node` because InputRouter graduated to
## autoload and dropped `class_name` per G-3 — see input_router.gd header.
var _hero_db: HeroDatabase
var _balance_constants: BalanceConstants
var _terrain_effect: TerrainEffect
var _unit_role: UnitRole
var _input_router: Node


# ─── Battle-scoped child Node references ─────────────────────────────────────

var _map_grid: MapGrid
var _battle_camera: BattleCamera
var _hp_controller: HPStatusController
var _turn_runner: TurnOrderRunner
var _grid_controller: GridBattleController
var _ai_system: AISystem
var _battle_hud: BattleHUD
## Bridges the controller's LOCAL battle_outcome_resolved → GameBus.battle_outcome_resolved
## (which ScenarioRunner + SceneManager consume) — see battle_outcome_bridge.gd for why
## this hop needs a dedicated child rather than being done on the scene root.
var _outcome_bridge: BattleOutcomeBridge = null
var _chapter_visuals: Node = null
## Single TurnIndicator instance, reparented under the active unit's polygon
## on each grid_controller.active_unit_changed emit. Lazy-init on first emit
## so we don't allocate before ChapterVisuals' unit polygons are spawned.
var _turn_indicator: TurnIndicator = null
## ADR-0022 civilian visualization — mounted as child of ChapterVisuals after
## unit polygons spawn. Refreshed on _on_unit_turn_ended_visual + _on_unit_died_visual
## (the only events where civilian state can change). Null when chapter has no
## civilian_config (controller short-circuits in that case anyway).
var _civilian_visuals: CivilianTokensVisuals = null

## Slide tween reference held to prevent local-scope GC from dropping the
## completion callback under certain windowed scheduler timings. Overwritten
## on every move; the previous Tween auto-cleans if already finished.
var _slide_tween_keepalive: Tween = null

## Set true when battle_outcome_resolved fires. Gates the post-battle restart
## keyboard handler (R = reload scene, ESC = quit).
var _battle_resolved: bool = false

## B1.2 — cascade 합류 pulse one-shot flag. `_collect_pre_battle_beats` 가
## cascade announcement 를 consume 할 때 true 로 set; `_mount_signature_count_badge`
## 가 사용 후 false 로 리셋. consume 이 mount 보다 먼저 실행되므로 peek 의존이
## 불가능 (영원히 empty) — 플래그로 의도 전달. retry-reload (consume 미발생) 는
## 자연스럽게 false 유지 → pulse 없음, badge 만 표시.
var _pulse_signature_badge_next_mount: bool = false


## Diagnostic-trace gate. Sessions 4-5 used inline raw `print(...)` calls (SLIDE
## / SLIDE-DONE / BATTLE-END / POST-BATTLE-WAIT categories) to debug windowed-env
## quirks (Tween scheduler, keyboard poll, scene reload paths). The user confirmed
## the windowed env now mostly works, so they're routed through `_trace()` and
## silenced by default. Flip this constant to `true` (then re-import) to surface
## the full event-stream again.
const _TRACE_ENABLED: bool = false


func _trace(msg: String) -> void:
	if _TRACE_ENABLED:
		print(msg)


## Movement-tween duration on unit_moved. Short enough to feel responsive
## (player still perceives the action as instant) but long enough that the
## slide reads as "moved to here" rather than a teleport jump.
const MOVE_ANIM_DURATION: float = 0.6

## S73 Bounce hero-specific tuning — per-hero {amplitude_px, hop_count} dict.
## Total bounce duration normalized to MOVE_ANIM_DURATION (each up/down quarter
## = MOVE_ANIM_DURATION / (hop_count * 2)). 5 cascade chibi 영웅 별 personality:
##   관우 = 묵직 (shallow hop, 2 count) — heavy stride
##   방통 = 통통 (taller hop, 3 count fast cadence) — light agile
##   위연 = sharp (tallest hop, 2 count) — sudden up/down
##   유비 = steady standard (5px × 2)
##   장비 = 호쾌 (taller hop, 2 count) — boisterous
## Heroes without entry → default 5px × 2 (matches pre-S73 behavior).
const _BOUNCE_AMP_DEFAULT: float = 5.0
const _BOUNCE_COUNT_DEFAULT: int = 2
const _BOUNCE_PROFILE_BY_HERO: Dictionary = {
	&"shu_002_guan_yu":   {"amp": 3.0, "count": 2},  # heavy / shallow
	&"shu_007_pang_tong": {"amp": 6.0, "count": 3},  # light / fast cadence
	&"shu_009_wei_yan":   {"amp": 7.0, "count": 2},  # sharp / tall
	&"shu_001_liu_bei":   {"amp": 5.0, "count": 2},  # steady
	&"shu_003_zhang_fei": {"amp": 6.0, "count": 2},  # 호쾌 / taller
}

## Attack-lunge tuning. On damage_applied, the attacker polygon nudges
## LUNGE_DISTANCE px toward the defender over LUNGE_HALF_DURATION seconds,
## then returns to origin over another LUNGE_HALF_DURATION seconds. Total
## ~0.15s feels snappy without competing with the defender's red-flash +
## HP-bar refresh that run in parallel.
const LUNGE_DISTANCE: float = 12.0
const LUNGE_HALF_DURATION: float = 0.075

## Death-fade duration. Polygon's modulate:a tweens to 0 then visible is set
## false. Long enough to read as "this unit just died" rather than a cut,
## short enough to keep combat pacing tight.
const DEATH_FADE_DURATION: float = 0.3

## On battle_outcome_resolved, ChapterVisuals modulate tweens to this color
## over OUTCOME_DIM_DURATION seconds so the grid recedes and the outcome
## banner pops. Slight blue cast (B 0.50 > R/G 0.45) reads as "scene cooling
## down" rather than just gray.
const OUTCOME_DIM_COLOR: Color = Color(0.45, 0.45, 0.50, 1.0)
const OUTCOME_DIM_DURATION: float = 0.4

## S17 macro-loop — chapter selection scene path. After the post-battle
## ceremonial sequence (OutcomeBanner + Beat 8 + ConsequenceScreen + Beat 9),
## scene transitions back here instead of auto-loading the next chapter.
## Lets the player explicitly choose what to play next, matching the
## "DEV menu 졸업" → user-driven chapter pacing of mvp-demo-16ch milestone.
## SCENARIO_END (last chapter walked off) still routes to _show_ending_screen
## first; that screen offers a "챕터 선택으로" button as its primary return.
const _CHAPTER_SELECT_SCENE_PATH: String = "res://scenes/chapter_select/chapter_select.tscn"

## End-of-turn polygon dim. A unit's polygon modulate fades to this alpha when
## the unit finishes its turn having spent at least one token (acted=true);
## reset back to WHITE when the next round starts. Reads as "this unit is
## done for the round" alongside the chevron on the active unit.
const END_OF_TURN_DIM_ALPHA: float = 0.55
const END_OF_TURN_DIM_DURATION: float = 0.15

## Camera top-padding (pixels). The HUD ribbon (initiative queue / round counter
## / victory condition) sits in screen-space along the top edge; the camera's
## `offset.y` is shifted negative by this much so the rendered world slides DOWN
## by the same amount, leaving an empty band at top for the ribbon to overlay
## without covering any map tiles. Using `offset` (not `position`) keeps the
## camera's clamp-to-map limits behaving normally regardless of viewport size —
## the prior `position.y -= 60` hack worked at 1920×1080 but degraded on smaller
## windows because the limits would clamp the shifted position back. ~80 px
## matches the BattleHUD top-ribbon footprint with a few px of breathing room.
const HUD_TOP_RIBBON_PAD_PX: float = 80.0

## Per-chapter title-card flavor. Keyed by ChapterDefinition.chapter_id. Shown
## briefly at battle start so the fight has narrative framing. Fallback (unknown
## id) uses the chapter number alone. Placeholder copy — the eventual string
## table (assets/locale/*.po, beat_*_text_key) supersedes this when authored.
const CHAPTER_FLAVOR: Dictionary = {
	# 영걸전식 25챕터 캠페인 기준 정식 챕터 번호.
	# Phase A prequel (ch01~ch05) — 황건적~신야.
	"ch01_taoyuan_yellow_turban": {
		"title": "제1장 · 도원결의 (桃園結義)",
		"tagline": "탁군 누상촌 — 의로 결의한 세 형제, 첫 무기로 황건적의 진을 깨뜨려라.",
	},
	"ch02_hulao_gate": {
		"title": "제2장 · 호뢰관 (虎牢關)",
		"tagline": "삼영전여포 — 세 사람의 무기로 천하무쌍의 방천화극을 막아라.",
	},
	"ch03_xuzhou_rescue": {
		"title": "제3장 · 서주 (徐州) · 도겸 구원",
		"tagline": "조운 합류 — 학살당하는 백성과 늙은 군주를 지켜내라.",
	},
	"ch04_bowang_slope": {
		"title": "제4장 · 박망파 (博望坡) · 공명의 첫 출진",
		"tagline": "와룡의 첫 화공 — 좁은 협곡에서 하후돈의 정예를 함정에 가두어라.",
	},
	"ch05_xinye_fire": {
		"title": "제5장 · 신야 화공 (新野)",
		"tagline": "백성을 한진으로 보내고 — 불타는 도시 안에서 5라운드를 버텨내라.",
	},
	# Main campaign (ch06~ch10) — 장판~적벽.
	"ch06_changbanpo": {
		"title": "제6장 · 장판파 (長坂坡)",
		"tagline": "유비, 피난민을 등지고 조조의 추격을 막아내라.",
	},
	"ch07_changban_bridge": {
		"title": "제7장 · 장판교 (長坂橋)",
		"tagline": "장비, 다리 하나로 적의 전군을 멈춰 세워라.",
	},
	"ch08_xiakou_outskirts": {
		"title": "제8장 · 강하 외곽 · 적벽의 서막",
		"tagline": "관우 합류 — 강을 건너기까지 마지막 후위를 막아내라.",
	},
	"ch09_chibi_prelude": {
		"title": "제9장 · 적벽의 서막 (赤壁前夜)",
		"tagline": "동맹의 길 — 손권에게 닿기 전 마지막 추격을 끊어라.",
	},
	"ch10_chibi_main": {
		"title": "제10장 · 적벽 본전 (赤壁) · 동남풍을 기다리며",
		"tagline": "화공의 바람이 불기까지 — 전선을 사수하고 백만 대군을 견뎌라.",
	},
	# Phase B (ch11~ch14) — 형주 4군 평정 + 통합. 위연 합류 (ch13 hidden destiny).
	"ch11_jingzhou_pacify": {
		"title": "제11장 · 형주 평정 (영릉·계양)",
		"tagline": "분진 평정 — 영릉과 계양을 동시에. 두 길 어느 쪽도 늦으면 분진의 함정이 된다.",
	},
	"ch12_wuling_marsh": {
		"title": "제12장 · 무릉 늪지 (武陵) · 사마가",
		"tagline": "단 하나의 다리 — 그 다리를 빼앗고, 만족의 신뢰를 한 번에 얻어라.",
	},
	"ch13_changsha_veteran": {
		"title": "제13장 · 장사 (長沙) · 황충과 위연",
		"tagline": "반골(反骨)의 칼 — 위연을 3턴 살려두면, 한현은 그 칼에 쓰러진다 (영걸전 시그니처).",
	},
	"ch14_jingzhou_consolidate": {
		"title": "제14장 · 형주 통합 (4군 안정)",
		"tagline": "도로망의 십자로 — 4군을 한 흐름으로 묶는 마지막 작전. 다음은 익주(蜀).",
	},
	# Phase C (ch15~ch17) — 익주 입성. 방통 합류 (ch15) + 낙봉파 시그니처 hidden destiny (ch16).
	"ch15_fushui_pass": {
		"title": "제15장 · 부수관 (涪水關) · 입촉의 길",
		"tagline": "봉추 방통 합류 — 유비 본인이 관문 [14,4]에 닿아야 익주의 길이 열린다.",
	},
	"ch16_luofeng_slope": {
		"title": "제16장 · 낙봉파 (落鳳坡) · 봉추의 위기",
		"tagline": "정찰을 먼저, 본진을 그 다음에 — 봉(鳳)을 떨어뜨리지 마라 (영걸전 시그니처).",
	},
	"ch17_chengdu_gates": {
		"title": "제17장 · 성도 (成都) · 익주의 새 주인",
		"tagline": "유장의 항복 — 같은 한실 종친에게 인수를 건네는 모양으로. 다음은 한중(漢中).",
	},
	# Phase D (ch18~ch22) — 한중/이릉. 마초 합류 (ch18) + 영걸전 시그니처 분기 3개 (관우/장비/유비 생환).
	"ch18_hanzhong_advance": {
		"title": "제18장 · 한중 (漢中) · 마초의 합류",
		"tagline": "가맹관 — 마초의 백마가 자기 부장들을 베고 우리 진영으로 달려온다. 합류의 칼.",
	},
	"ch19_dingjun_peak": {
		"title": "제19장 · 정군산 (定軍山) · 노장의 결전",
		"tagline": "황충이 자기 손으로 하후연을 베는 자리 — 다섯 호랑이 장수의 마지막 인증.",
	},
	"ch20_fancheng_pursuit": {
		"title": "제20장 · 번성 (樊城) · 관우의 마지막",
		"tagline": "후퇴로를 3턴 사수하라 — 형주는 잃지만, 관우는 살린다 (영걸전 시그니처 #3).",
	},
	"ch21_zhangfei_avenge": {
		"title": "제21장 · 장비 (張飛) · 출병의 밤",
		"tagline": "낭중의 군영에서 규율 4턴 — 자객의 칼이 막사 문에 닿기 전에 (영걸전 시그니처).",
	},
	"ch22_yiling_burn": {
		"title": "제22장 · 이릉 (夷陵) · 화공의 강",
		"tagline": "맞불 2턴 — 유비 본인이 백제성이 아닌 한중으로 돌아간다 (영걸전 시그니처 #4).",
	},
	# Phase E (ch23~ch25) — 남만~오장원·영걸전 finale. 강유 합류 + 마속 생존 + 제갈량 회생.
	"ch23_southern_pacify": {
		"title": "제23장 · 남만 (南蠻) · 칠종칠금",
		"tagline": "맹획을 일곱 번 잡고 일곱 번 풀어주어라 — 칼이 아니라 마음으로 잡는 자리.",
	},
	"ch24_jieting_pass": {
		"title": "제24장 · 가정 (街亭) · 1차 북벌·강유 합류",
		"tagline": "공명 본진 [12,5] 도달 — 마속이 명령을 자기 자존심보다 먼저 두면 (영걸전 시그니처).",
	},
	"ch25_wuzhang_plains": {
		"title": "제25장 · 오장원 (五丈原) · 제갈량의 자리",
		"tagline": "칠성단 8라운드 사수 — 6턴 이상 본명등을 지키면 별이 꺼지지 않는다 (영걸전 최종 시그니처).",
	},
}
## How long the title card stays on screen before auto-removing (seconds).
const TITLE_CARD_DURATION: float = 3.5

## Player unit_id → hero_id. Stable across chapters (see _build_battle_units_from_chapter).
## Hero IDs MUST exist in assets/data/heroes/heroes.json. Placeholder until a
## data-driven player_hero_ids ChapterDefinition field lands (post-MVP scope).
const PLAYER_HERO_BY_UNIT_ID: Dictionary = {
	0: &"shu_001_liu_bei",   # 유비 — ch1 commander / rear-guard
	1: &"shu_003_zhang_fei", # 장비 — ch1 vanguard, ch2 bridge-holder
}


# ─── Built-in virtual methods ─────────────────────────────────────────────────

## _ready() — scenario bootstrap, then either present the chapter's pre-battle
## story (windowed only) and start the battle when the player dismisses it, or
## start the battle immediately (headless, or a retry-reload where the pre-battle
## beats were already shown). The story-presentation branch is fire-and-forget;
## battle setup runs in _start_battle() either way.
##
## Idempotent under all 3 launch sources per R-8:
##   (a) SceneManager-driven (ADR-0002 deferred packed-scene instantiation)
##   (b) project.godot main_scene config
##   (c) godot --main-scene CLI override
func _ready() -> void:
	if not _bootstrap_scenario_if_needed():
		return
	# Present the pre-battle story (Beat 1 anchor + Beat 3 brief) only in windowed
	# runs, and only when the scenario is fresh at the chapter's first beat (a
	# retry-reload lands at BEAT_4_PREP with the beats already seen → skip).
	if _should_present_story() \
			and ScenarioRunner.get_state() == ScenarioRunner.State.BEAT_1_ANCHOR:
		_present_pre_battle_story_then_start()
	else:
		_start_battle()


## Mounts a StoryBeatScreen with the chapter's pre-battle beats, waits for the
## player to advance past them, then starts the battle. Fire-and-forget coroutine
## from _ready() — battle systems are not created until this returns.
func _present_pre_battle_story_then_start() -> void:
	var chapter: ChapterDefinition = ScenarioRunner.get_current_chapter()
	if chapter != null:
		var beats: Array = _collect_pre_battle_beats(chapter)
		if not beats.is_empty():
			await _present_story_beats(beats)
	_start_battle()


## _start_battle() — 6-step mount sequence per ADR-0016 §3.
##
## Walks ScenarioRunner forward to BEAT_5_BATTLE (a no-op when already there),
## then: instantiate system → call setup() / initialize() → add_child() for each
## of the 6 battle-scoped children. The setup-before-add_child ordering is
## MANDATORY for all 5 system ADRs (ADR-0010/0011/0013/0014/0015 R-N).
func _start_battle() -> void:
	# === DI: 5 backends per ADR-0016 IN-10 + G-22 reflective bypass for @abstract ===
	# HeroDatabase + UnitRole are @abstract — direct .new() blocks at parse time
	# on typed reference (per G-22). Reflective load(path).new() path bypasses
	# @abstract enforcement and returns a live RefCounted instance assignable
	# to typed fields. BalanceConstants + TerrainEffect are not @abstract — direct
	# .new() works. InputRouter graduated to autoload at S8-02 (input-handling
	# story-001 2026-05-06) — reference via /root/InputRouter directly per
	# ADR-0005 §1 + ADR-0020 §Decision §6 (boot pos 9). Closes prior TD-058
	# placeholder + supersedes the "sprint-7+ autoload graduation" pointer.
	_hero_db = (load("res://src/foundation/hero_database.gd") as GDScript).new()
	_unit_role = (load("res://src/foundation/unit_role.gd") as GDScript).new()
	_balance_constants = BalanceConstants.new()
	_terrain_effect = TerrainEffect.new()
	_input_router = get_node("/root/InputRouter")
	# InputRouter needs Camera + MapGrid refs to resolve mouse pixel → grid coord →
	# unit_id at click time. Without these, _make_context_from_event leaves
	# ctx.target_unit_id = -1 and _handle_action_in_s0 silently drops every
	# unit_select click (POLISH-011 production-wiring residual #2).
	# Wired here AFTER _battle_camera + _map_grid are created (see STEPs 1 + 2 below).

	# === SCENARIO ADVANCE ===
	# Drive ScenarioRunner to BEAT_5_BATTLE for whatever chapter it's currently
	# on (the scenario was already loaded in _bootstrap_scenario_if_needed; this
	# walks the pre-battle beats). A reload after a chapter transition
	# (_proceed_scenario / _retry_chapter / _restart_scenario) finds ScenarioRunner
	# already at that chapter's pre-battle beats and walks them. SceneManager-driven
	# mode (post-Main-Menu, post-MVP): ScenarioRunner is already in BEAT_5_BATTLE; no-op.
	_advance_scenario_to_battle()
	var chapter: ChapterDefinition = ScenarioRunner.get_current_chapter()
	if chapter == null:
		push_error("BattleScene: no active chapter from ScenarioRunner")
		return
	var roster: Array[BattleUnit] = _build_battle_units_from_chapter(chapter)
	var map_resource: MapResource = _build_map_resource_for_chapter(chapter)

	# === STEP 1: MapGrid (ADR-0004) ===
	# load_map() returns bool — warnings logged per IN-6 + IN-7.
	_map_grid = MapGrid.new()
	_map_grid.name = "MapGrid"
	var map_ok: bool = _map_grid.load_map(map_resource)
	if not map_ok:
		push_warning("BattleScene: MapGrid.load_map() returned false — check map_resource validation")
		for err: String in _map_grid.get_last_load_errors():
			push_warning("BattleScene: MapGrid error: %s" % err)
	add_child(_map_grid)

	# === STEP 1.1: Populate MapGrid occupants from roster deployment positions.
	# Without this, every InputRouter click resolves to unit_id = -1 because
	# MapGrid.get_unit_at(coord) returns -1 for tiles whose tile_state is still EMPTY
	# (POLISH-011 production-wiring residual #3).
	for unit: BattleUnit in roster:
		var faction: int = MapGrid.FACTION_ALLY if unit.side == 0 else MapGrid.FACTION_ENEMY
		_map_grid.set_occupant(unit.position, unit.unit_id, faction)

	# === STEP 1.5 REMOVED: SceneManager._instantiate_and_enter_battle already
	# mounts res://scenes/battle/<map_id>.tscn at /root via the
	# battle_launch_requested signal path (ADR-0002 §_instantiate_and_enter_battle).
	# Mounting it again here under GridLayer was producing a dual-mount: the
	# visible instance was SceneManager's at /root, but BattleScene wired its own
	# (invisible) GridLayer instance, so selection-highlight overlays never reached
	# the rendered scene. Selection now resolves the live instance via /root lookup
	# in _on_unit_selected_changed.

	# === STEP 2: BattleCamera (ADR-0013) — depends on MapGrid ===
	_battle_camera = BattleCamera.new()
	_battle_camera.name = "BattleCamera"
	_battle_camera.setup(_map_grid)
	add_child(_battle_camera)
	# Windowed-play camera: keep zoom at 1.0 (matches balance constant + tests)
	# and shift the rendered world DOWN via Camera2D.offset so the HUD ribbon at
	# the top edge overlays empty space above the map rather than the top row
	# of tiles. Using `offset` (NOT `position`) so the camera's clamp-to-map
	# limits keep working at every viewport size — see HUD_TOP_RIBBON_PAD_PX.
	_battle_camera.offset.y = -HUD_TOP_RIBBON_PAD_PX

	# === STEP 2.5: InputRouter DI for screen→grid coord + grid→unit_id resolution.
	# Without these, every mouse click resolves to ctx.target_unit_id = -1 and
	# unit_select silently drops in InputRouter._handle_action_in_s0
	# (POLISH-011 production-wiring residual #2).
	_input_router.set_camera(_battle_camera)
	_input_router.set_map_grid(_map_grid)

	# === STEP 3: HPStatusController (ADR-0010) — depends on roster + MapGrid ===
	# initialize_unit(unit_id, hero, unit_class) per shipped ADR-0010 API.
	# IN-8 drift: no UnitRole.get_class_for_hero(); use unit.unit_class directly.
	# set_map_grid plumbs the MapGrid reference used by the CR-8c commander-death
	# DEMORALIZED-radius propagation (asserts non-null at use site). Missing this
	# wire-up was a session-8 user-reported crash on 유비 death.
	_hp_controller = HPStatusController.new()
	_hp_controller.name = "HPStatusController"
	_hp_controller.set_map_grid(_map_grid)
	for unit: BattleUnit in roster:
		var hero: HeroData = HeroDatabase.get_hero(unit.hero_id)
		_hp_controller.initialize_unit(unit.unit_id, hero, unit.unit_class)
	add_child(_hp_controller)

	# === STEP 4: TurnOrderRunner (ADR-0011) — depends on roster ===
	_turn_runner = TurnOrderRunner.new()
	_turn_runner.name = "TurnOrderRunner"
	# S59 production gate: GridBattleController._check_battle_end +
	# _on_round_started own the chapter-aware victory dispatch (REACH_TILE /
	# SURVIVE / ESCORT no-shortcut semantics). Without this, the runner fires
	# PLAYER_WIN naively when enemy_alive==0, flipping _round_state to
	# BATTLE_ENDED → all subsequent _advance_to_next_queued_unit calls become
	# no-ops → the player can no longer end a turn. User-visible symptom on
	# ch03: clear all 4 enemies, then game freezes at "Turn: 관우" with no
	# battle-end screen (REACH_TILE intent — must move 유비 to [13,4]).
	_turn_runner.set_victory_check_suppressed(true)
	_turn_runner.initialize_battle(roster)
	add_child(_turn_runner)

	# === STEP 5: GridBattleController (ADR-0014) — depends on all 4 prior ===
	_grid_controller = GridBattleController.new()
	_grid_controller.name = "GridBattleController"
	_grid_controller.setup(
		roster,
		_map_grid,
		_battle_camera,
		_hero_db,
		_turn_runner,
		_hp_controller,
		_terrain_effect,
		_unit_role,
	)
	# S7-05: plumb chapter-authored chokepoints to AISystem holder-archetype scoring.
	_grid_controller.set_chokepoints(chapter.chokepoints)
	# ADR-0022: plumb chapter-authored civilian_config (ch05 only; empty Dictionary
	# = no civilian system active for this chapter).
	_grid_controller.set_civilian_config(chapter.civilian_config)
	# Session-28: plumb chapter-authored victory_conditions for the
	# _check_battle_end + _on_round_started SURVIVE dispatchers. Null is
	# valid (chapter omitted the resource) and falls through to the
	# default ANNIHILATION path.
	_grid_controller.set_victory_conditions(chapter.victory_conditions)
	# S15-J: wire NATURAL-LOOP mode per ADR-0011 §Amendment 2026-05-09 + ADR-0014 §Amendment 2026-05-10 (#1+#2+#3).
	# Without this call, T5 _execute_action_budget falls through TEST-SEAM no-op pass; production
	# battle loop runs to ROUND_CAP_DRAW in ~2-3 seconds without natural input/AI dispatch.
	_turn_runner.set_action_controller(_grid_controller._on_turn_runner_action_request)
	add_child(_grid_controller)

	# Wire unit-selection signal to chapter visuals selection-highlight overlay.
	# Instance lookup is dynamic (in handler) because SceneManager mounts the
	# chapter visuals AFTER battle_launch_requested fires (post-_ready boundary).
	_grid_controller.unit_selected_changed.connect(_on_unit_selected_changed)
	_grid_controller.unit_moved.connect(_on_unit_moved)
	_grid_controller.damage_applied.connect(_on_damage_applied)
	# Session-23 — FIRE tile round-start damage gets its own visual channel.
	_grid_controller.fire_damage_applied.connect(_on_fire_damage_applied)
	_grid_controller.unit_visual_died.connect(_on_unit_died_visual)
	_grid_controller.active_unit_changed.connect(_on_active_unit_changed)
	_grid_controller.unit_turn_ended_visual.connect(_on_unit_turn_ended_visual)
	_grid_controller.round_started_visual.connect(_on_round_started_visual)
	_grid_controller.battle_outcome_resolved.connect(_on_battle_outcome_resolved)
	# Session-13: defend stance badge — toggle on when applied, off on round
	# rollover (next round = fresh turn = stance consumed).
	_grid_controller.unit_defend_stance_applied.connect(_on_unit_defend_stance_applied)
	# Session-16: hero skill SFX cue. One sound covers all 6 skills for v1;
	# per-skill variants are a future iteration.
	if _grid_controller.has_signal(&"unit_skill_used"):
		_grid_controller.unit_skill_used.connect(_on_unit_skill_used)
	# Session-16: critical-hit (REAR-direction) visual feedback. Spawns the
	# "치명타!" popup + triggers camera shake + plays SFX_CRITICAL so the player
	# feels the flank payoff immediately rather than just seeing a bigger
	# damage number on the standard popup.
	if _grid_controller.has_signal(&"critical_hit_landed"):
		_grid_controller.critical_hit_landed.connect(_on_critical_hit_landed)
	# Session-16: mid-battle kill notification. Spawns "X 처치!" popup at victim
	# position + plays SFX_KILL flourish — defers the "did I get the kill?"
	# confirmation moment so the player doesn't have to wait until the result
	# screen to feel it.
	if _grid_controller.has_signal(&"unit_killed"):
		_grid_controller.unit_killed.connect(_on_unit_killed_mid_battle)
	# Session-16: status effect badges (독 / 슬). Mirrors the defend_stance 방
	# badge channel so multiple status types can stack visually on one polygon.
	if _grid_controller.has_signal(&"unit_status_applied"):
		_grid_controller.unit_status_applied.connect(_on_unit_status_applied)
	# S91+ Phase B step 9 — UI-GB-17 Item Target Selection Overlay routing.
	# Controller emits valid tile set + palette → BattleScene forwards to
	# ChapterVisuals.set_item_target_tiles for the per-tile tint render.
	# Defensive has_signal: stub controllers without the signal stay green.
	if _grid_controller.has_signal(&"item_target_selection_updated"):
		_grid_controller.item_target_selection_updated.connect(_on_item_target_selection_updated)
	# S91+ Phase B step 9 follow-up — UI-GB-16 per-polygon multi-unit
	# attachment. Subscribe to unit_pending_buff_changed so the polygon-level
	# BuffBadge glyph can appear/disappear per unit (in addition to the
	# HUD-level single active-unit glyph in BattleHUD). Strategy-systems v0.3
	# §3.5.7 + battle-hud.md §3 UI-GB-16 — multiple units can carry buffs
	# simultaneously (strength_scroll on hero A + strength_scroll on hero B);
	# per-polygon attachment is the spec design.
	if _grid_controller.has_signal(&"unit_pending_buff_changed"):
		_grid_controller.unit_pending_buff_changed.connect(_on_unit_pending_buff_changed)
	# S97 — ENEMY-disrupt debuff (intimidate_scroll). Distinct red ▼ DebuffBadge
	# so an intimidated enemy doesn't show the gold ▶ buff glyph (misreads as
	# "enemy got stronger"). Mirrors the buff subscription above.
	if _grid_controller.has_signal(&"unit_pending_debuff_changed"):
		_grid_controller.unit_pending_debuff_changed.connect(_on_unit_pending_debuff_changed)

	# === STEP 5.5: AISystem (ADR-0019) — battle-scoped Node 6th invocation ===
	# Inserted via /architecture-review delta #14 2026-05-05 per ADR-0016 §3 R-3
	# Path A (preserves existing 1-6 numbering; full 1-7 renumber deferred).
	# Subscribes to GridBattleController.ai_action_requested with CONNECT_DEFERRED.
	_ai_system = AISystem.new()
	_ai_system.name = "AISystem"
	_ai_system.setup(_grid_controller)
	add_child(_ai_system)
	# Wire reverse direction: GridBattleController subscribes to AISystem.ai_action_ready
	# so AI commands actually execute. Without this, ai_action_ready emits into the void
	# and AI turns hang forever (POLISH-013 production-wiring residual).
	_grid_controller.set_ai_system(_ai_system)

	# === STEP 5.6: BattleOutcomeBridge — battle-scoped GameBus publisher ===
	# Without this, GridBattleController's LOCAL battle_outcome_resolved never
	# reaches GameBus, so ScenarioRunner stays in BEAT_5_BATTLE forever and the
	# scenario never advances past chapter 1 (R-7 forbids the scene root from
	# emitting; ADR-0014 §8 forbids the controller from emitting on GameBus).
	_outcome_bridge = BattleOutcomeBridge.new()
	_outcome_bridge.name = "BattleOutcomeBridge"
	_outcome_bridge.setup(chapter.chapter_id)
	add_child(_outcome_bridge)
	_grid_controller.battle_outcome_resolved.connect(_outcome_bridge.on_local_outcome)

	# === STEP 6: BattleHUD (ADR-0015) — depends on all 5 prior ===
	_battle_hud = BattleHUD.new()
	_battle_hud.name = "BattleHUD"
	_battle_hud.setup(
		_battle_camera,
		_hp_controller,
		_turn_runner,
		_grid_controller,
		_input_router,
		_map_grid,
		_terrain_effect,
		_unit_role,
		_hero_db,
	)
	_hud_layer.add_child(_battle_hud)
	# Victory condition surfaces at battle init — without this UI-GB-08 stays
	# visible=false and the top-right ribbon slot is empty.
	# Session-29 — chapter-aware label. SURVIVE_N_ROUNDS shows the round target
	# ("N라운드 버티기"); everything else (ANNIHILATION default, null vc) keeps
	# the pre-S29 enemy-defeat phrasing.
	_battle_hud.set_victory_condition(_resolve_victory_condition_label(chapter))
	# S65+ — 시그니처 카운트 badge: top-right corner small label. Visible only
	# when at least one signature has been resolved (cascade in progress).
	# Mounted at every chapter so the badge surfaces immediately on the chapter
	# AFTER the first signature lands (위연 ch13 → ch14 진입 시 1/5 표시).
	_mount_signature_count_badge()
	# Persistent controls hint at the bottom edge — a first-time player has no
	# way to discover the click flow otherwise. Static label; no _process needed
	# (which matters: _pause_overworld() disables _process on this scene, see
	# _on_battle_outcome_resolved). Lives in HUDLayer (CanvasLayer) so it stays
	# visible regardless of the Node2D-parent visibility cascade.
	_mount_controls_hint()
	# Session-53 — mount the ALWAYS-mode cancel/undo polling helper. Without
	# this, ESC + right-click polling never fires mid-battle (BattleScene's
	# own _process is gated by process_mode, which SceneManager flips to
	# DISABLED in the "battle treated as overworld" pattern documented at
	# line 1601). The helper runs PROCESS_MODE_ALWAYS so polling survives
	# any parent pause/disable. Mount BEFORE title_card so its _process is
	# active throughout the title-card window too.
	_mount_cancel_poller()
	# Brief title card so the battle has narrative framing. Auto-removes via a
	# SceneTreeTimer (fires regardless of process_mode — unlike _process).
	_mount_title_card(chapter, roster)

	# ChapterVisuals is mounted at /root by SceneManager AFTER BattleScene._ready
	# returns (async load + deferred instantiate per ADR-0002). Spawn runtime
	# unit polygons once the visuals node appears — this replaces .tscn-baked
	# polygons with roster-driven ones so deployment branch overrides (e.g.
	# WIN_changbanpo_default placing 유비 at [2,3]) actually render.
	_spawn_unit_polygons_async(roster)

	# S60 — chapter-specific BGM. Pre-S60 the generic MUSIC_BATTLE_AMBIENT was
	# disabled (S50 "system-noise 웅~ hum" feedback). S60 replaces with 5
	# chapter-tuned drones (D minor urgency / A power stoic / C major travel /
	# E major alliance warmth / F minor climax) so each chapter has its own
	# audible "place" — distinct enough that ch01→ch02 transition reads as a
	# scene change even before the title card fades. Silent no-op when music
	# muted; stops in _exit_tree on chapter teardown.
	if SoundManager.has_method("music_id_for_chapter") and SoundManager.has_method("play_music"):
		var music_id: StringName = SoundManager.music_id_for_chapter(chapter.chapter_id)
		SoundManager.play_music(music_id)


## _exit_tree — stops battle music when the scene tears down. Without this
## the music would continue across the brief gap before the next BattleScene
## mounts (or the main menu shows). Safe no-op when nothing is playing.
func _exit_tree() -> void:
	if SoundManager.has_method("stop_music"):
		SoundManager.stop_music()


# ─── Scenario driving (standalone-launch only) ───────────────────────────────

## Walks ScenarioRunner forward to BEAT_5_BATTLE for the chapter it's currently on.
##
## - First launch ever (also after _restart_scenario): no scenario loaded
##   (index == -1) → load shu_canon_main.json (→ CHAPTER_START → BEAT_1_ANCHOR), then walk.
##   (load_scenario in _restart_scenario re-loads, so index is briefly -1-equivalent —
##    actually load_scenario resets directly to CHAPTER_START; covered below.)
## - Reload after a chapter transition: _proceed_scenario already advanced
##   ScenarioRunner to the next chapter's BEAT_1_ANCHOR → just walk the beats.
## - Reload after _retry_chapter: ScenarioRunner is in BEAT_4_PREP → confirm.
## - Already in BEAT_5_BATTLE (SceneManager-driven mode / test fixture): no-op.
## - Any other (stale post-battle) state: leave it; get_current_chapter() handles null.
##
## This only DRIVES the beat state machine — the pre-battle beat *presentation*
## (Beat 1 anchor + Beat 3 brief) happens beforehand in
## _present_pre_battle_story_then_start() (windowed only); a retry-reload or a
## headless run walks the beats here without any UI dwell.
func _advance_scenario_to_battle() -> void:
	if ScenarioRunner.get_current_chapter_index() == -1:
		var scenario_path: String = ScenarioRunner.get_active_scenario_path()
		if not ScenarioRunner.load_scenario(scenario_path):
			push_error("BattleScene: failed to load scenario at %s" % scenario_path)
			return
	# Bounded walk — 8 iterations is far more than the longest pre-battle path
	# (CHAPTER_START is auto-advanced inside ScenarioRunner; we only ever see
	# BEAT_1 → BEAT_2 → BEAT_3 → BEAT_4 → confirm).
	for _i: int in 8:
		match ScenarioRunner.get_state():
			ScenarioRunner.State.BEAT_1_ANCHOR, \
			ScenarioRunner.State.BEAT_2_ECHO, \
			ScenarioRunner.State.BEAT_3_BRIEF:
				ScenarioRunner.advance_beat()
			ScenarioRunner.State.BEAT_4_PREP:
				ScenarioRunner.confirm_deployment()  # -> BATTLE_LOADING -> BEAT_5_BATTLE
				return
			_:
				return  # BEAT_5_BATTLE (already in battle) or a stale state (leave it)


# ─── Story beat presentation (windowed; headless skips it) ───────────────────

## Story beat narrative content, keyed by beat_*_text_key (mirrors the keys in
## assets/data/scenarios/shu_canon_main.json). Loaded once and cached; {} if the file
## is missing or malformed (in which case no story screen is shown — the battle
## still plays). See assets/data/story/story_content.json.
var _story_content_cache: Dictionary = {}
var _story_content_loaded: bool = false


## Ensures a scenario is loaded so get_current_chapter() works. The very first
## launch (and a "처음부터" restart) finds no scenario (index == -1) and loads
## shu_canon_main.json (→ CHAPTER_START → BEAT_1_ANCHOR). Returns false on load failure.
func _bootstrap_scenario_if_needed() -> bool:
	if ScenarioRunner.get_current_chapter_index() == -1:
		var scenario_path: String = ScenarioRunner.get_active_scenario_path()
		if not ScenarioRunner.load_scenario(scenario_path):
			push_error("BattleScene: failed to load scenario at %s" % scenario_path)
			return false
	return true


## True only in windowed runs. Headless runs (CI, GdUnit4, the natural-turn-loop
## smoke) must NOT mount the StoryBeatScreen — it waits forever for player input.
func _should_present_story() -> bool:
	return DisplayServer.get_name() != "headless"


func _load_story_content() -> Dictionary:
	if _story_content_loaded:
		return _story_content_cache
	_story_content_loaded = true
	var path: String = "res://assets/data/story/story_content.json"
	var raw: String = FileAccess.get_file_as_string(path)
	if raw.is_empty():
		push_warning("BattleScene: story content file missing or empty: %s" % path)
		return _story_content_cache
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		push_warning("BattleScene: story content failed to parse as JSON object: %s" % path)
		return _story_content_cache
	_story_content_cache = parsed as Dictionary
	return _story_content_cache


## Resolves a beat text key to its { title, body, speaker?, line? } content
## Dictionary, or {} if the key is empty / unknown / has no usable prose.
func _beat_content(text_key: String) -> Dictionary:
	if text_key.is_empty():
		return {}
	var entry: Variant = _load_story_content().get(text_key, null)
	if not (entry is Dictionary):
		return {}
	var d: Dictionary = entry as Dictionary
	var has_body: bool = not (d.get("body", "") as String).strip_edges().is_empty()
	var has_line: bool = not (d.get("line", "") as String).strip_edges().is_empty()
	if not (has_body or has_line):
		return {}
	return d


## Pre-battle beats for `chapter`: Beat 1 anchor + Beat 3 brief (Beat 2 is a
## silent_visual fragment with no text — skipped). Filters out keys with no content.
##
## S65+ — cascade 합류 인사: ScenarioRunner has a pending cascade announcement
## (직전 챕터에서 시그니처 키가 해소되어 현재 챕터가 cascade entry first-join
## 인 상황), prepend that beat AHEAD of beat_1. Consume the announcement after
## reading so it doesn't replay on retry-reload.
func _collect_pre_battle_beats(chapter: ChapterDefinition) -> Array:
	var beats: Array = []
	var cascade: Dictionary = ScenarioRunner.consume_pending_cascade_announcement()
	if not cascade.is_empty():
		# B1.2 — signal _mount_signature_count_badge to fire one-shot pulse.
		# consume 이 mount 보다 먼저 실행되므로 peek 의존이 불가 — 플래그로 전달.
		_pulse_signature_badge_next_mount = true
		var cascade_text_key: String = cascade.get("text_key", "") as String
		var cascade_beat: Dictionary = _beat_content(cascade_text_key)
		if not cascade_beat.is_empty():
			beats.append(cascade_beat)
	var b1: Dictionary = _beat_content(chapter.beat_1_text_key)
	if not b1.is_empty():
		beats.append(b1)
	var b3: Dictionary = _beat_content(chapter.beat_3_text_key)
	if not b3.is_empty():
		beats.append(b3)
	return beats


## Post-battle beats for the just-finished `chapter`: the Beat 8 revelation for
## the resolved branch (or an outcome-based fallback if `branch_choice` is null /
## invalid), then the Beat 9 chapter transition. Filters out keys with no content.
func _collect_post_battle_beats(chapter: ChapterDefinition, branch_choice: DestinyBranchChoice) -> Array:
	var beats: Array = []
	var branch_key: String = ""
	if branch_choice != null and not branch_choice.is_invalid:
		branch_key = branch_choice.branch_key
	if branch_key.is_empty():
		branch_key = _guess_branch_key_for_outcome(chapter)
	var b8: Dictionary = _beat_content(_beat_8_text_key_for_branch(chapter, branch_key))
	if not b8.is_empty():
		beats.append(b8)
	var b9: Dictionary = _beat_content(chapter.beat_9_text_key)
	if not b9.is_empty():
		beats.append(b9)
	return beats


func _beat_8_text_key_for_branch(chapter: ChapterDefinition, branch_key: String) -> String:
	for entry: Dictionary in chapter.beat_8_revelations:
		if (entry.get("branch_key", "") as String) == branch_key:
			return entry.get("text_key", "") as String
	return ""


## Best-effort branch_key when the resolved DestinyBranchChoice is unavailable:
## WIN → the chapter's canonical branch; DRAW / LOSS → its LOSS_default branch.
func _guess_branch_key_for_outcome(chapter: ChapterDefinition) -> String:
	if _pending_outcome == BattleOutcome.Result.WIN:
		return chapter.canonical_branch_key
	return chapter.branch_table.get("LOSS_default", "") as String


## Session-42 — Looks up the OTHER branch's beat-8 title (the one the player
## did NOT take) by walking chapter.beat_8_revelations and picking the entry
## whose branch_key differs from `player_branch_key`. Returns "" when no other
## revelation exists (1-revelation chapters skip the comparison screen).
func _find_other_branch_b8_title(chapter: ChapterDefinition,
		player_branch_key: String) -> String:
	for entry: Dictionary in chapter.beat_8_revelations:
		var bk: String = entry.get("branch_key", "") as String
		if bk == player_branch_key or bk.is_empty():
			continue
		var content: Dictionary = _beat_content(entry.get("text_key", "") as String)
		return (content.get("title", "") as String).strip_edges()
	return ""


## Session-42 — Mounts a ConsequenceScreen between Beat 8 and Beat 9 showing
## "역사의 두 갈래" comparison: the OTHER branch's title (the path not taken,
## muted left) vs the player's branch title (vivid right). No-op when the
## chapter has no second branch revelation OR no HUD layer.
func _present_consequence_screen(chapter: ChapterDefinition,
		player_branch_key: String) -> void:
	if _hud_layer == null or chapter == null:
		return
	var other_title: String = _find_other_branch_b8_title(chapter, player_branch_key)
	if other_title.is_empty():
		return  # 1-revelation chapter — nothing to compare against
	var your_b8: Dictionary = _beat_content(
		_beat_8_text_key_for_branch(chapter, player_branch_key))
	var your_title: String = (your_b8.get("title", "") as String).strip_edges()
	if your_title.is_empty():
		return  # No prose for the player's branch — skip rather than render half-empty
	# Session-44 — retry-nudge footnote: the post-battle button cluster always
	# offers a path back (재시도 / 처음부터). The footnote names that path
	# explicitly while the comparison is in front of the player, so the
	# "wait, I could take the other branch too" thought lands while the two
	# titles are still visible. Single uniform line — no canonical/non-
	# canonical branching here (S42 rationale on data/prose mismatch holds).
	var footnote: String = "이 챕터를 다시 시도하면, 또 다른 결말을 경험할 수 있습니다."
	var screen: ConsequenceScreen = ConsequenceScreen.make(other_title, your_title, footnote)
	screen.name = "ConsequenceScreen"
	_hud_layer.add_child(screen)
	await screen.sequence_finished
	if is_instance_valid(screen):
		screen.queue_free()


## Mounts a StoryBeatScreen on the HUD layer, presents `beats`, and awaits the
## player advancing past the last one; frees the screen before returning. No-op
## (returns immediately) if there is nothing to show or the HUD layer is absent.
func _present_story_beats(beats: Array) -> void:
	if beats.is_empty() or _hud_layer == null:
		return
	var screen: StoryBeatScreen = StoryBeatScreen.new()
	screen.name = "StoryBeatScreen"
	_hud_layer.add_child(screen)
	screen.present(beats)
	await screen.sequence_finished
	if is_instance_valid(screen):
		screen.queue_free()


## Removes the post-battle banner / button / controls-hint nodes from the HUD
## layer (used before showing the post-battle story so it isn't layered over them).
func _clear_post_battle_ui() -> void:
	if _hud_layer == null:
		return
	for nm: String in ["OutcomeBanner", "PostBattleButtons", "ControlsHint"]:
		var n: Node = _hud_layer.get_node_or_null(nm)
		if n != null:
			n.queue_free()


# ─── Chapter-driven helpers (sprint-7 S7-02 — replaces deleted mock encoder) ──


## Builds Array[BattleUnit] from ChapterDefinition.player_unit_ids + enemy_roster.
## Player units use chapter.player_unit_ids + chapter.deployment_positions_default.
## Enemy units use chapter.enemy_roster (Dictionary entries with unit_id/hero_id/archetype).
## Hero IDs MUST exist in assets/data/heroes/heroes.json.
func _build_battle_units_from_chapter(chapter: ChapterDefinition) -> Array[BattleUnit]:
	var roster: Array[BattleUnit] = []
	# Per-prior-branch override view (player_unit_ids / player_hero_ids /
	# deployment_positions_default). Empty Dict when no override applies.
	# Pillar 2 surface: hidden-branch + LOSS-branch deployment differences
	# must be visible on the actual grid, not just shaped in BattlePayload.
	var override: Dictionary = {}
	if ScenarioRunner.has_method("get_active_branch_override"):
		override = ScenarioRunner.get_active_branch_override()
	var player_uids: PackedInt64Array = chapter.player_unit_ids
	if override.has("player_unit_ids"):
		player_uids = PackedInt64Array()
		for uid_var in (override["player_unit_ids"] as Array):
			player_uids.append(int(uid_var))
	var override_hero_ids: Dictionary = {}
	if override.has("player_hero_ids"):
		var raw_heroes: Dictionary = override["player_hero_ids"] as Dictionary
		for k in raw_heroes.keys():
			# JSON keys come in as String; normalize to int per chapter convention.
			override_hero_ids[int(k as String)] = raw_heroes[k] as String
	var override_dep: Dictionary = {}
	if override.has("deployment_positions_default"):
		var raw_dep: Dictionary = override["deployment_positions_default"] as Dictionary
		for k in raw_dep.keys():
			var v: Variant = raw_dep[k]
			if v is Array and (v as Array).size() >= 2:
				var arr: Array = v as Array
				override_dep[int(k as String)] = Vector2i(int(arr[0]), int(arr[1]))
	# Player units — bind player unit_ids to narrative-fitting heroes via a 3-tier
	# fallback chain: (1) chapter.player_hero_ids (data-driven, scales to any uid
	# in any chapter — preferred); (2) PLAYER_HERO_BY_UNIT_ID const (covers uids
	# 0/1 = 유비/장비 from the legacy hardcoded mapping); (3) 장비 (a sensible
	# default front-liner for unknown uids — keeps the battle bootable even when
	# new chapters forget to author the mapping).
	for i in player_uids.size():
		var uid: int = int(player_uids[i])
		var hero: StringName = _resolve_player_hero_id_with_override(chapter, uid, override_hero_ids)
		var pos: Vector2i
		if override_dep.has(uid):
			pos = override_dep[uid] as Vector2i
		else:
			pos = chapter.deployment_positions_default.get(uid, Vector2i(1 + i, 2)) as Vector2i
		var tag: StringName = &"tank" if i == 0 else &"assassin"
		# Player units default to &"aggressor" archetype (S13-12); chapter fixtures
		# do not currently author player_unit archetypes — extend ChapterDefinition
		# if AI-driven player units are introduced post-MVP.
		var pu: BattleUnit = _make_battle_unit(uid, hero, true, pos, tag, &"aggressor")
		# S91 Phase B step 8 — apply chapter starting inventory to player units.
		# Key the lookup by BattleUnit.hero_id (already a StringName) against the
		# hydrated Dictionary[StringName, Array[StringName]] on the chapter.
		# Enemy units do NOT consume starting_inventory_by_hero (MVP enemy =
		# no inventory per strategy-systems §3.1 OQ-SS-2).
		_apply_starting_inventory(pu, chapter)
		roster.append(pu)
	# Enemy units from chapter.enemy_roster Dictionary entries.
	for entry in chapter.enemy_roster:
		var d: Dictionary = entry as Dictionary
		var uid: int = int(d.get("unit_id", 0))
		var hero: StringName = StringName(d.get("hero_id", "wei_001_cao_cao") as String)
		var archetype: StringName = StringName(d.get("archetype", "aggressor") as String)
		# Position fallback: spread enemies across columns 4+ at row 2.
		var pos: Vector2i = chapter.deployment_positions_default.get(uid, Vector2i(4 + roster.size(), 2)) as Vector2i
		# tag carries the fate-counter role (coordinator → "boss" for fate tracking
		# per ADR-0014 §2 fate counter pattern). archetype is preserved separately
		# on the BattleUnit for AISystem dispatch (S13-12 separation).
		var tag: StringName = &"boss" if archetype == &"coordinator" else archetype
		roster.append(_make_battle_unit(uid, hero, false, pos, tag, archetype))
	return roster


## Resolves the hero_id for a player unit_id via the 3-tier fallback chain
## documented in _build_battle_units_from_chapter. Public-shaped (no underscore-
## prefixed args) so tests can drive it directly without poking the full builder.
func _resolve_player_hero_id(chapter: ChapterDefinition, uid: int) -> StringName:
	return _resolve_player_hero_id_with_override(chapter, uid, {})


## Override-aware variant: when override_hero_ids has the uid, it wins over
## chapter.player_hero_ids. Used by _build_battle_units_from_chapter to surface
## per-prior-branch hero swap-ins (e.g., ch02 WIN_changbanpo_lord_unharmed adds
## 관우 at uid=6 via branch_overrides without mutating the chapter).
func _resolve_player_hero_id_with_override(
		chapter: ChapterDefinition, uid: int, override_hero_ids: Dictionary,
) -> StringName:
	if override_hero_ids.has(uid):
		var ovr: String = override_hero_ids[uid] as String
		if not ovr.is_empty():
			return StringName(ovr)
	if chapter != null and chapter.player_hero_ids.has(uid):
		var hid: String = chapter.player_hero_ids[uid] as String
		if not hid.is_empty():
			return StringName(hid)
	if PLAYER_HERO_BY_UNIT_ID.has(uid):
		return PLAYER_HERO_BY_UNIT_ID[uid] as StringName
	return &"shu_003_zhang_fei"


## S91 Phase B step 8 — applies the chapter's per-hero starting inventory to a
## freshly-constructed player BattleUnit. Strategy Systems v0.3 §3.4 + AC-SS-2.
##
## Lookup: chapter.starting_inventory_by_hero[unit.hero_id] (StringName key).
## When the chapter authored a matching entry, the unit's `inventory` field is
## SET to a duplicate of the authored array. Otherwise unit.inventory remains
## the BattleUnit default (empty []) — strategy-systems §3.1 OQ-SS-2: enemies
## never receive inventory.
##
## Inner array is duplicated so per-battle slot mutations (use_item decrement)
## don't leak back into the chapter resource (which would corrupt the per-run
## state on retry / load).
func _apply_starting_inventory(unit: BattleUnit, chapter: ChapterDefinition) -> void:
	if chapter == null:
		return
	if not chapter.starting_inventory_by_hero.has(unit.hero_id):
		return
	var src: Array = chapter.starting_inventory_by_hero[unit.hero_id] as Array
	var copy: Array[StringName] = []
	for item_var: Variant in src:
		copy.append(item_var as StringName)
	unit.inventory = copy


## S91 Phase B step 8b follow-up — exposes the active battle's per-unit
## Strategy Systems state for SaveContext snapshot population by ScenarioRunner.
## Returns Dictionary with two sub-Dictionaries:
##   "inventory": {unit_id_int -> Array[StringName] inventory slots}
##   "pending_buff": {unit_id_int -> pending_buff Dictionary}
## Only PLAYER units (side == 0) are included — enemy inventory is Phase 4+
## per strategy-systems.md §3.1, mirroring the _apply_starting_inventory side gate.
## Returns empty sub-dicts when no grid controller / no units yet — call site
## should treat empty as "no in-flight battle state" (matches SaveContext default).
func get_per_unit_strategy_snapshot() -> Dictionary:
	var result: Dictionary = {
		"inventory": {},
		"pending_buff": {},
	}
	if _grid_controller == null:
		return result
	for unit_id_var: Variant in _grid_controller._units.keys():
		var unit: BattleUnit = _grid_controller._units[unit_id_var]
		if unit == null or unit.side != 0:
			continue
		# Inventory: only snapshot non-empty inventories so the saved size
		# matches the spec's "no permanent accumulation" rule — units with
		# empty inventories don't need a row.
		var has_any_item: bool = false
		for slot: StringName in unit.inventory:
			if slot != &"":
				has_any_item = true
				break
		if has_any_item:
			var inv_copy: Array[StringName] = []
			inv_copy.assign(unit.inventory)  # G-2 — preserves Array[StringName]
			(result["inventory"] as Dictionary)[unit.unit_id] = inv_copy
		# Pending buff: only snapshot non-empty buffs (null-sentinel rule per
		# BattleUnit.pending_buff doc).
		if not unit.pending_buff.is_empty():
			(result["pending_buff"] as Dictionary)[unit.unit_id] = unit.pending_buff.duplicate()
	return result


## S91 Phase B step 8b follow-up — applies a previously-captured snapshot back
## to the current battle's BattleUnits. Used by mid-battle save resume (future)
## OR by integration tests verifying the round-trip data path. Both arguments
## are Dictionaries with int keys (unit_id) and Array[StringName] (inventory) /
## Dictionary (pending_buff) values, matching the get_per_unit_strategy_snapshot
## return shape + SaveContext field types.
##
## Snapshot OVERRIDES chapter-authored starting_inventory (apply chapter first
## then snapshot — this is the call-order documented contract). For a fresh
## chapter-boundary load (no mid-battle save), pass empty Dictionaries and the
## chapter inventory stays untouched.
func apply_per_unit_strategy_snapshot(inventory_snapshot: Dictionary, pending_buff_snapshot: Dictionary) -> void:
	if _grid_controller == null:
		return
	for unit_id_var: Variant in inventory_snapshot.keys():
		var unit_id: int = unit_id_var as int
		if not _grid_controller._units.has(unit_id):
			continue
		var unit: BattleUnit = _grid_controller._units[unit_id]
		if unit == null or unit.side != 0:
			continue
		var saved_inv: Array = inventory_snapshot[unit_id_var] as Array
		var inv_copy: Array[StringName] = []
		for item_var: Variant in saved_inv:
			inv_copy.append(item_var as StringName)
		unit.inventory = inv_copy
	for unit_id_var: Variant in pending_buff_snapshot.keys():
		var unit_id: int = unit_id_var as int
		if not _grid_controller._units.has(unit_id):
			continue
		var unit: BattleUnit = _grid_controller._units[unit_id]
		if unit == null or unit.side != 0:
			continue
		var saved_buff: Dictionary = pending_buff_snapshot[unit_id_var] as Dictionary
		unit.pending_buff = saved_buff.duplicate()


## Constructs a single BattleUnit. Replaces the deleted _make_mock_unit helper.
## archetype param (S13-12) carries the AI behaviour bucket — distinct from `tag`
## which carries the fate-counter role. See BattleUnit.archetype docstring for the
## separation rationale (BUG #2: prior conflation leaked tag="boss" into AISystem
## dispatch as unknown archetype, triggering EC-AI-4 fallback warning).
func _make_battle_unit(
		unit_id: int,
		hero_id: StringName,
		is_player: bool,
		pos: Vector2i,
		tag: StringName,
		archetype: StringName,
) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = hero_id
	unit.is_player_controlled = is_player
	unit.side = 0 if is_player else 1
	unit.position = pos
	unit.tag = tag
	unit.archetype = archetype
	# Stats from HeroData. RE-TUNED at session 8 after the "유비 dies in 1
	# round" playtest: the original coefficients (might×1.5, command×0.05)
	# pushed every attack through BASE_CEILING=83 because eff_atk ≫ eff_def,
	# so raw_def was dead-code and 유비 fell to any 2 adjacent enemies.
	#   New target: "kill in 4-5 hits" (was the documented "2-3 hits" but
	#   with 4 enemies converging on a player the practical reality was 1
	#   round to a commander wipe). Math (적 하후돈 → 유비, FRONT, plains):
	#     eff_atk = 88 (was 132)        raw_atk  = might × 1.0
	#     eff_def = 28 (was 4)          raw_def  = command × 0.20 + 10 if COMMANDER
	#     base    = 88 − 28 = 60 (under ceiling — raw_def now matters)
	#     final  ≈ 40–55 after multiplier chain
	#     유비 226 HP / 50 ≈ 4–5 hits to drop, with command_aura buffing his
	#     adjacent retaliation. Cleaner difficulty curve at all 3 chapters.
	#   COMMANDER +10 raw_def bonus is the survivability hook that justifies
	#   "the commander is the formation anchor" — losing 유비 is supposed to
	#   be hard, not a 1-round race the AI always wins.
	# Max HP per UnitRole formula (unchanged): hp_seed × class_hp_mult × 2.0 + 50.
	# Fallback values (10 atk / 5 def) are only hit when HeroData is missing —
	# defensive against unknown hero_ids; never used by the live scenario.
	var hero_data: HeroData = HeroDatabase.get_hero(hero_id)
	if hero_data != null:
		# Coefficients data-driven via BalanceConstants — single source of truth
		# for atk/def derivation. Tune in balance_entities.json (HERO_ATK_COEFF /
		# HERO_DEF_COEFF / HERO_COMMANDER_DEF_BONUS) rather than touching code.
		var atk_coeff: float = BalanceConstants.get_const("HERO_ATK_COEFF") as float
		var def_coeff: float = BalanceConstants.get_const("HERO_DEF_COEFF") as float
		unit.raw_atk = int(hero_data.stat_might * atk_coeff)
		unit.raw_def = int(hero_data.stat_command * def_coeff)
		# Cached INT for fire_strategy / fire_scroll INT scaling (damage-calc rev
		# 2.9.4 §F-DC-8). Mirrors raw_atk/raw_def caching pattern — DamageCalc +
		# GridBattleController read from BattleUnit, not from HeroDatabase, so the
		# fire damage formula stays self-contained at attack-resolve time.
		unit.stat_intellect = hero_data.stat_intellect
		# Class from the hero's default — without this every unit defaulted to 0
		# (CAVALRY) and rendered as a triangle, hiding both the per-class shape
		# and the per-class HP/multiplier behavior. Fallback to INFANTRY (1) when
		# the hero is unknown — closest to "grunt" semantics.
		unit.unit_class = hero_data.default_class
		# COMMANDER survivability bonus — formation anchor: losing 유비 should be
		# hard, not a 1-round race. Applied AFTER unit_class assignment so the
		# conditional reads the resolved class.
		if unit.unit_class == UnitRole.UnitClass.COMMANDER:
			var cmd_bonus: int = BalanceConstants.get_const("HERO_COMMANDER_DEF_BONUS") as int
			unit.raw_def += cmd_bonus
	else:
		unit.raw_atk = 10
		unit.raw_def = 5
		unit.unit_class = UnitRole.UnitClass.INFANTRY
	# Enemy-side ATK penalty — MVP has only 3 player heroes (유비/장비/관우)
	# vs 5 enemy heroes spread across 3 chapters, which makes the player a
	# permanent minority. Without an enemy ATK throttle, even after the
	# session-8 atk/def retune ch1 is unwinnable: 4 enemies converge on
	# 유비 in ~3 turns and out-DPS the player's 2-unit retaliation budget.
	#   Resolution chain: chapter.enemy_atk_mult (per-chapter override) →
	#   BalanceConstants.ENEMY_ATK_MULT (global default). Per-chapter wins
	#   when set to a value in [0.0, 2.0]; -1.0 sentinel or out-of-range
	#   falls back to global. This lets ch1 / ch2 / ch3 carry their own
	#   difficulty curves without forcing the team to retune all chapters
	#   when one needs adjustment.
	if not is_player:
		unit.raw_atk = int(unit.raw_atk * _resolve_enemy_atk_mult())
	# Class-derived combat traits — ORDER-SENSITIVE: must follow unit_class assignment.
	# attack_range gives ARCHER 우금 actual reach (1→2). passive activates the
	# command_aura adjacency damage buff (+15% to allies adjacent to a COMMANDER)
	# that GridBattleController._has_adjacent_command_aura already implements but
	# never fired before because no unit ever had passive set. The AI hunt for
	# command_aura targets stays inactive — snapshot's `passive_id` is still
	# hardcoded to &"" (intentional asymmetry: player gets formation buff,
	# enemy AI doesn't gain a "kill the king" priority on top of it).
	unit.attack_range = _attack_range_for_class(unit.unit_class)
	unit.passive = _passive_for_class(unit.unit_class)
	# move_range derived from hero base + class delta clamped to balance range —
	# replaces a 3-everyone hardcode. Heroes.json gives 우금 (archer) 3, 장료
	# (strategist) 5 (-1 delta → 4), 관우 (cavalry) 4 (+1 delta → 5), most others 4.
	# Player now feels real class differentiation in deployment + skirmish range.
	if hero_data != null:
		unit.move_range = UnitRole.get_effective_move_range(hero_data, unit.unit_class)
	else:
		unit.move_range = 3
	# Session-15 commit 5: active skill from heroes.json innate_skill_ids[0].
	# Player-side only — enemy AI doesn't have a skill-trigger path yet, so
	# wiring the skill_id on enemies would create silently dead-stored data.
	# The controller's use_skill() refuses non-player units regardless.
	if is_player and hero_data != null and not hero_data.innate_skill_ids.is_empty():
		unit.skill_id = hero_data.innate_skill_ids[0]
	return unit


## Resolves the effective enemy_atk_mult for the current battle. Per-chapter
## override wins over BalanceConstants global; sentinel -1.0 or out-of-range
## values fall back to global. Out-of-range emits push_warning (defensive
## against JSON typos that would otherwise silently break difficulty tuning).
##   Called once per enemy unit at _make_battle_unit. Cheap (autoload getter
##   + single comparison), so no need to memoize across the build loop.
func _resolve_enemy_atk_mult() -> float:
	var global_mul: float = BalanceConstants.get_const("ENEMY_ATK_MULT") as float
	var chapter: ChapterDefinition = ScenarioRunner.get_current_chapter()
	if chapter == null:
		return global_mul
	var override: float = chapter.enemy_atk_mult
	if override < 0.0:
		return global_mul
	if override > 2.0:
		push_warning(
			"BattleScene._resolve_enemy_atk_mult: chapter '%s' enemy_atk_mult=%.3f"
			% [chapter.chapter_id, override]
			+ " is out of [0.0, 2.0] range; falling back to global %.3f" % global_mul
		)
		return global_mul
	return override


## Class → melee/ranged reach mapping. ARCHER stands off (range 2); everyone
## else is melee (range 1). 황충's `rear_specialist` ranged exception is a
## per-hero passive override authored elsewhere when that hero ships.
func _attack_range_for_class(unit_class: int) -> int:
	if unit_class == int(UnitRole.UnitClass.ARCHER):
		return 2
	return 1


## Class → default passive mapping. COMMANDER carries `command_aura` so the
## adjacent-ally damage buff (GridBattleController._has_adjacent_command_aura)
## actually fires. CAVALRY carries `passive_charge` (session-13) so the +20%
## CHARGE_BONUS in DamageCalc._charge_factor fires when the cavalry unit
## moved >= CHARGE_THRESHOLD (40 path-cost = 4 flat tiles) before attacking.
## SCOUT carries `passive_ambush` (session-14) so the +15% AMBUSH_BONUS in
## DamageCalc._ambush_factor fires when attacking a not-yet-acted target
## from round 2 onwards (target also loses counter — see GridBattleController
## _preview_counter_eligible). ARCHER carries `passive_high_ground_shot`
## (session-15) so the +15% HIGH_GROUND_BONUS in DamageCalc._high_ground_factor
## fires whenever the archer attacks while standing on HILLS terrain.
## INFANTRY's `passive_shield_wall` is consumed directly by HPStatusController
## via UnitRole.PASSIVE_TAG_BY_CLASS lookup, not through this runtime field.
## STRATEGIST `tactical_read` + COMMANDER `passive_rally` remain advisory
## tags not consumed by the damage pipeline yet.
func _passive_for_class(unit_class: int) -> StringName:
	if unit_class == int(UnitRole.UnitClass.COMMANDER):
		return &"command_aura"
	if unit_class == int(UnitRole.UnitClass.CAVALRY):
		return &"passive_charge"
	if unit_class == int(UnitRole.UnitClass.SCOUT):
		return &"passive_ambush"
	if unit_class == int(UnitRole.UnitClass.ARCHER):
		return &"passive_high_ground_shot"
	return &""


## Builds a 15×15 all-grass MapResource for the chapter. Sprint-7 S7-05 will
## load chapter-1 (장판파) authored .tres at assets/data/maps/{map_id}.tres;
## current stub fixture provides uniform grass per IN-9 + ADR-0016 IN-9.
## Session-50 — load the chapter's authored MapResource asset
## (assets/data/maps/{map_id}.tres) so the gameplay-logic MapGrid carries the
## same RIVER / BRIDGE / HILLS / MOUNTAIN terrain as the visually-mounted
## ChapterVisuals. Pre-S50 this function ignored `chapter` (note the
## underscore prefix on the param) and synthesized a 15×15 uniform grass
## fallback every call — visible map showed rivers, but the logic map said
## "every tile is passable plains". Result: S49 RIVER override had no effect
## because the gameplay MapGrid contained no RIVER tiles. User report: "유비가
## 여전히 강으로 간다." Fix: try to load the chapter's .tres; fall through to
## uniform grass only when the asset is missing or malformed (defensive —
## prevents crashes for chapters without authored maps).
##
## Comment from the pre-S50 stub: "sprint-7+ chapter map loading will replace
## this with assets/data/maps/{map_id}.tres asset loading." This commit IS
## that replacement (~9 sprints later than planned).
func _build_map_resource_for_chapter(chapter: ChapterDefinition) -> MapResource:
	if chapter != null and chapter.map_id != &"":
		var asset_path: String = "res://assets/data/maps/%s.tres" % String(chapter.map_id)
		if ResourceLoader.exists(asset_path):
			var loaded: Resource = ResourceLoader.load(asset_path)
			if loaded is MapResource:
				return loaded as MapResource
			push_warning(
				"BattleScene: asset at %s loaded but is not a MapResource" % asset_path
			)
		else:
			push_warning(
				"BattleScene: chapter '%s' map asset not found at %s — falling back to uniform grass"
					% [String(chapter.chapter_id), asset_path]
			)
	# Fallback for chapters without an authored map (or asset load failure).
	var map: MapResource = MapResource.new()
	map.map_cols = 15
	map.map_rows = 15
	map.tiles = _make_uniform_grass_tiles(15, 15)
	return map


## Selection-highlight handler. Looks up the SceneManager-mounted ChapterVisuals
## instance at /root (by class) at call-time, since the mount happens after
## BattleScene._ready returns (via battle_launch_requested → SceneManager).
func _on_unit_selected_changed(unit_id: int, _was_selected: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	if unit_id == -1:
		visuals.set_selected_coord(Vector2i(-1, -1))
		visuals.set_movable_tiles(PackedVector2Array())
		visuals.set_attackable_tiles(PackedVector2Array())
		_clear_verb_feedback_overlays(visuals)
		_clear_tactical_read_overlay(visuals)
		return
	var unit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
	if unit == null:
		visuals.set_selected_coord(Vector2i(-1, -1))
		visuals.set_movable_tiles(PackedVector2Array())
		visuals.set_attackable_tiles(PackedVector2Array())
		_clear_verb_feedback_overlays(visuals)
		_clear_tactical_read_overlay(visuals)
		return
	visuals.set_selected_coord(unit.position)
	var movable: PackedVector2Array = _grid_controller.get_movable_tiles(unit_id)
	visuals.set_movable_tiles(movable)
	# Session-55 — push per-tile favor tint alongside movable preview.
	# Forward-compat: skip if older ChapterVisuals doesn't expose the setter.
	if visuals.has_method("set_movable_favors"):
		visuals.set_movable_favors(_grid_controller.get_movable_favors(unit_id, movable))
	visuals.set_attackable_tiles(_grid_controller.get_attackable_tiles(unit_id))
	_apply_verb_feedback_overlays(visuals, unit_id, unit.position)
	_apply_tactical_read_overlay(visuals, unit)


## Session-15: pushes AMBUSH / CHARGE / HIGH GROUND feedback overlays for the
## given unit. Ambush set = subset of attackable tiles where SCOUT + round >= 2
## + defender unacted; charge coord = the unit's own tile when CAVALRY +
## passive_charge + accumulated_move >= CHARGE_THRESHOLD; high-ground coord =
## the unit's own tile when ARCHER + passive_high_ground_shot + standing on
## HILLS terrain. Class mutex guarantees charge and high-ground never both
## fire for the same unit, so they appear as one halo color per selection.
func _apply_verb_feedback_overlays(visuals: Node, unit_id: int, position: Vector2i) -> void:
	if visuals.has_method("set_ambush_target_tiles"):
		visuals.set_ambush_target_tiles(
			_grid_controller.get_ambush_eligible_target_tiles(unit_id))
	if visuals.has_method("set_charge_ready_coord"):
		var charge_coord: Vector2i = position if _grid_controller.is_charge_ready(unit_id) \
			else Vector2i(-1, -1)
		visuals.set_charge_ready_coord(charge_coord)
	if visuals.has_method("set_high_ground_ready_coord"):
		var hg_coord: Vector2i = position if _grid_controller.is_high_ground_ready(unit_id) \
			else Vector2i(-1, -1)
		visuals.set_high_ground_ready_coord(hg_coord)


## Session-15: clears AMBUSH / CHARGE / HIGH GROUND feedback overlays.
## Called on deselect and stale-selection branches so the indigo wash, cyan
## halo, and green halo don't linger past the selection they belonged to.
func _clear_verb_feedback_overlays(visuals: Node) -> void:
	if visuals.has_method("set_ambush_target_tiles"):
		visuals.set_ambush_target_tiles(PackedVector2Array())
	if visuals.has_method("set_charge_ready_coord"):
		visuals.set_charge_ready_coord(Vector2i(-1, -1))
	if visuals.has_method("set_high_ground_ready_coord"):
		visuals.set_high_ground_ready_coord(Vector2i(-1, -1))


## Session-19 — STRATEGIST `passive_tactical_read` activation (information
## advantage facet). When a player-side STRATEGIST is selected, attach a
## directional arrow glyph ("↑→↓←") on every alive enemy polygon so the
## player can read facing direction without entering an attack preview.
## Pairs with the existing direction-multiplier rendering in
## ui_gb_04_combat_forecast — selecting 주유 lets the player plan flank/rear
## angles BEFORE committing another unit's attack.
##
## Idempotent: clears any prior FacingArrow children first; safe to call
## back-to-back as the player cycles selections.
##
## Non-STRATEGIST or enemy-side selections silently clear the overlay so
## the arrows disappear when the player picks a different class.
func _apply_tactical_read_overlay(visuals: Node, selected: BattleUnit) -> void:
	_clear_tactical_read_overlay(visuals)
	if selected == null:
		return
	if selected.side != 0:
		return  # player STRATEGIST only — enemy classes don't get the affordance
	if selected.unit_class != UnitRole.UnitClass.STRATEGIST:
		return
	# Iterate enemy polygons directly — extract unit_id from polygon name
	# ("Unit{id}_*") rather than reaching into _grid_controller._units. Keeps
	# the read path scoped to the visual tree we already own.
	var enemies_parent: Node = visuals.get_node_or_null("EnemyUnits")
	if enemies_parent == null:
		return
	for child: Node in enemies_parent.get_children():
		if not (child is Node2D):
			continue
		var poly: Node2D = child as Node2D
		if not poly.visible:
			continue  # dead units snap-hide; skip
		var uid: int = _extract_unit_id_from_polygon_name(poly.name)
		if uid == -1:
			continue
		var enemy: BattleUnit = _grid_controller.get_battle_unit(uid)
		if enemy == null:
			continue
		if not _hp_controller.is_alive(uid):
			continue
		# Idempotent — _clear_tactical_read_overlay already ran above; this
		# double-checks against any race where the prior arrow lingered.
		if poly.get_node_or_null("FacingArrow") != null:
			continue
		var arrow: Label = Label.new()
		arrow.name = "FacingArrow"
		arrow.text = _facing_arrow_glyph(enemy.facing)
		# Tactical indigo — distinct from the ambush wash so it reads as
		# "info marker" rather than "attack target highlight".
		arrow.add_theme_color_override("font_color", Color(0.61, 0.48, 0.85, 1.0))
		arrow.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1.0))
		arrow.add_theme_constant_override("outline_size", 6)
		arrow.add_theme_font_size_override("font_size", 22)
		arrow.rotation = -poly.rotation  # always upright
		arrow.position = Vector2(-10, -52)  # above polygon
		arrow.size = Vector2(20, 20)
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		poly.add_child(arrow)


## Removes any FacingArrow child Labels from every enemy polygon. Called on
## deselect, on stale-selection branches, and as the first step of
## _apply_tactical_read_overlay (idempotence guarantee).
func _clear_tactical_read_overlay(visuals: Node) -> void:
	for parent_name: String in ["PlayerUnits", "EnemyUnits"]:
		var parent: Node = visuals.get_node_or_null(parent_name)
		if parent == null:
			continue
		for child: Node in parent.get_children():
			if not (child is Node2D):
				continue
			var arrow: Node = (child as Node2D).get_node_or_null("FacingArrow")
			if arrow != null:
				arrow.queue_free()


## Maps BattleUnit.facing (0=N, 1=E, 2=S, 3=W) to a directional arrow glyph.
## Defaults to "→" (east) for any out-of-range facing value.
func _facing_arrow_glyph(facing: int) -> String:
	match facing:
		0: return "↑"
		1: return "→"
		2: return "↓"
		3: return "←"
		_: return "→"


## Extracts the integer unit_id from a polygon name in the "Unit{id}_*" format
## used by ChapterVisuals.spawn_unit_polygons (e.g. "Unit3_Triangle" → 3).
## Returns -1 if the name doesn't match the expected pattern.
func _extract_unit_id_from_polygon_name(node_name: StringName) -> int:
	var name_str: String = String(node_name)
	if not name_str.begins_with("Unit"):
		return -1
	var underscore_idx: int = name_str.find("_", 4)
	if underscore_idx <= 4:
		return -1
	var id_str: String = name_str.substr(4, underscore_idx - 4)
	if not id_str.is_valid_int():
		return -1
	return id_str.to_int()


func _find_chapter_visuals() -> Node:
	for child: Node in get_tree().root.get_children():
		# Skip a previous chapter's ChapterVisuals that SceneManager has queued
		# for deletion but the tree hasn't reaped yet (chapter-transition window).
		if child is ChapterVisuals and not child.is_queued_for_deletion():
			return child
	return null


## Polls /root for ChapterVisuals across up to ~0.5s (30 frames @ 60fps) and
## calls spawn_unit_polygons(roster) once it appears. Required because the
## chapter visuals scene is async-loaded by SceneManager and mounts after
## BattleScene._ready returns. Fire-and-forget coroutine from _ready.
func _spawn_unit_polygons_async(roster: Array[BattleUnit]) -> void:
	# Was 30 (~0.5s @ 60fps) — too tight for cold boots on Apple Silicon where
	# SceneManager's async .tscn load + instantiation can exceed 0.5s. 300 frames
	# (~5s) gives generous headroom without indefinite wait.
	for attempt: int in 300:
		var visuals: Node = _find_chapter_visuals()
		if visuals != null and visuals.has_method("spawn_unit_polygons"):
			# A prior battle (before reload_current_scene) may have left the
			# /root ChapterVisuals dimmed via OUTCOME_DIM_COLOR — it survives
			# the scene reload because SceneManager mounted it at /root, not
			# under current_scene. Reset to full brightness on every battle start.
			if visuals is CanvasItem:
				(visuals as CanvasItem).modulate = Color.WHITE
			visuals.spawn_unit_polygons(roster)
			_mount_hp_bars(visuals, roster)
			_mount_civilian_tokens_visuals(visuals)
			_refresh_synergy_badges()
			# S59 windowed UX — when chapter is REACH_TILE, mark the target
			# tile with a persistent gold-flag overlay so the player can see
			# WHERE to go. User stuck on ch03 after enemy wipeout because
			# REACH_TILE doesn't shortcut on annihilation + target tile had
			# no in-grid indicator (HUD label alone was insufficient).
			var chapter: ChapterDefinition = ScenarioRunner.get_current_chapter()
			if chapter != null and chapter.victory_conditions != null \
					and chapter.victory_conditions.primary_condition_type \
						== VictoryConditions.ConditionType.REACH_TILE \
					and visuals.has_method("set_reach_tile_target"):
				visuals.set_reach_tile_target(chapter.victory_conditions.target_tile)
			elif visuals.has_method("set_reach_tile_target"):
				visuals.set_reach_tile_target(Vector2i(-1, -1))
			return
		await get_tree().process_frame
	var root_names: Array = []
	for c: Node in get_tree().root.get_children():
		root_names.append(c.name)
	push_warning("BattleScene: ChapterVisuals not mounted within 300 frames; "
		+ "root children: " + str(root_names))


## ADR-0022 — mounts CivilianTokensVisuals as child of ChapterVisuals (inherits
## grid-space transform). First refresh() spawns polygon-per-token from the
## controller's get_civilian_tokens() snapshot. No-op chapters (empty
## civilian_config) get an empty visualization node — cheap, safe to mount
## unconditionally. Subsequent refresh()es fire from _on_unit_turn_ended_visual
## and _on_unit_died_visual hooks (the only events where civilian state changes).
func _mount_civilian_tokens_visuals(visuals: Node) -> void:
	if _grid_controller == null:
		return
	if _civilian_visuals != null and is_instance_valid(_civilian_visuals):
		_civilian_visuals.queue_free()
	_civilian_visuals = CivilianTokensVisuals.new()
	_civilian_visuals.name = "CivilianTokensVisuals"
	visuals.add_child(_civilian_visuals)
	_civilian_visuals.set_controller(_grid_controller, visuals)


## Attaches a UnitHpBar Node2D child to each spawned unit polygon, seeded from
## HPStatusController. Polygon transform inheritance gives free repositioning on
## move; CanvasItem visibility cascade gives free hide-on-death. Per-unit refresh
## happens in _on_damage_applied.
func _mount_hp_bars(visuals: Node, roster: Array[BattleUnit]) -> void:
	if _hp_controller == null:
		return
	for unit: BattleUnit in roster:
		var polygon: Node2D = _find_unit_polygon(visuals, unit.unit_id)
		if polygon == null:
			continue
		var bar: UnitHpBar = UnitHpBar.new()
		bar.name = "HpBar"
		polygon.add_child(bar)
		bar.set_hp(
			_hp_controller.get_current_hp(unit.unit_id),
			_hp_controller.get_max_hp(unit.unit_id),
		)


## Unit-moved handler. Re-positions the unit's Polygon2D inside the chapter
## visuals (.tscn-authored as `Unit{unit_id}_*` under PlayerUnits/EnemyUnits)
## and updates the selection highlight if the moved unit is the current
## selection. Without this, BattleUnit.position mutates but the on-screen
## silhouette stays at its authored deployment coord.
func _on_unit_moved(unit_id: int, _from: Vector2i, to: Vector2i) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		_trace("[SLIDE] unit=%d visuals=NULL — slide skipped" % unit_id)
		return
	var tile_size: int = ChapterVisuals.TILE_SIZE
	var world_pos: Vector2 = Vector2(
		to.x * tile_size + tile_size / 2.0,
		to.y * tile_size + tile_size / 2.0,
	)
	var unit_node: Node2D = _find_unit_polygon(visuals, unit_id)
	if unit_node == null:
		_trace("[SLIDE] unit=%d polygon=NULL (children: %s) — slide skipped" %
			[unit_id, _list_polygon_names(visuals)])
		return
	_trace("[SLIDE] unit=%d from=%s to=%s (polygon now at %s, target %s)" %
		[unit_id, str(_from), str(to), str(unit_node.position), str(world_pos)])
	# G-30b ROOT CAUSE HYPOTHESIS (session 7): SceneManager._pause_overworld
	# sets BattleScene.process_mode = PROCESS_MODE_DISABLED on
	# battle_launch_requested, and `get_tree().create_tween()` called from a BattleScene
	# method binds the Tween to `self` (BattleScene) — disabled-mode parents
	# pause their tweens, so tween_property writes never fire in windowed mode.
	# Fix: bind the slide tween to the SceneTree itself via
	# `get_tree().create_tween()` — SceneTree is the root scheduler, immune to
	# parent process_mode. Failsafe instant-set at duration+buffer survives
	# either way (covers headless tests that don't run the tween scheduler
	# loop AND any remaining windowed-env edge cases).
	var start_pos: Vector2 = unit_node.position
	# Q5 Phase 3 — Switch ChibiSprite to "walk" animation if present. Reverts
	# to "default" (idle/breath) at slide end via the deferred timer callback.
	# Graceful: chibi 미-mount 영웅 (asset 없음) 은 ChibiSprite 자체 없어 skip.
	# Either walk frame 미배포 시 walk animation 등록 안 되어 has_animation
	# false → play("walk") skip.
	var chibi_at_start: Node = unit_node.get_node_or_null("ChibiSprite")
	if chibi_at_start is AnimatedSprite2D:
		var anim_at_start: AnimatedSprite2D = chibi_at_start as AnimatedSprite2D
		# Q5 Phase 3 — code-side vertical bounce during slide. Frame-swap
		# (walk_0/walk_1 PNG) approach was 폐기 — chibi 짧은 다리 비례 +
		# TILE_SIZE=64 scale_crush 로 sub-pixel motion. Bound to SceneTree per
		# G-31 (BattleScene gets PROCESS_MODE_DISABLED during battle).
		# S73 — per-hero amplitude + hop count (_BOUNCE_PROFILE_BY_HERO).
		# Total normalized to MOVE_ANIM_DURATION so all heroes still end at y=0
		# when slide ends. Heroes without entry fall back to default (5px × 2).
		var bounce_amp: float = _BOUNCE_AMP_DEFAULT
		var bounce_count: int = _BOUNCE_COUNT_DEFAULT
		if _grid_controller != null:
			var bunit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
			if bunit != null and _BOUNCE_PROFILE_BY_HERO.has(bunit.hero_id):
				var profile: Dictionary = _BOUNCE_PROFILE_BY_HERO[bunit.hero_id]
				bounce_amp = profile.get("amp", _BOUNCE_AMP_DEFAULT) as float
				bounce_count = profile.get("count", _BOUNCE_COUNT_DEFAULT) as int
		var hop_quarter: float = MOVE_ANIM_DURATION / float(bounce_count * 2)
		var bounce_tween: Tween = get_tree().create_tween()
		for _i: int in bounce_count:
			bounce_tween.tween_property(anim_at_start, "position:y", -bounce_amp, hop_quarter) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			bounce_tween.tween_property(anim_at_start, "position:y", 0.0, hop_quarter) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var slide_tween: Tween = get_tree().create_tween()
	slide_tween.tween_property(unit_node, "position", world_pos, MOVE_ANIM_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(MOVE_ANIM_DURATION + 0.05).timeout.connect(func() -> void:
		# Re-resolve the polygon at fire time — ChapterVisuals may have been
		# freed mid-slide (battle end during animation).
		var v: Node = _find_chapter_visuals()
		if v == null:
			return
		var n: Node2D = _find_unit_polygon(v, unit_id)
		if is_instance_valid(n):
			n.position = world_pos
			# Safety-reset ChibiSprite bounce y in case bounce_tween was
			# interrupted (battle end / scene transition mid-slide). Default
			# animation (idle/breath) never stopped — no play() needed.
			var chibi_at_end: Node = n.get_node_or_null("ChibiSprite")
			if chibi_at_end is AnimatedSprite2D:
				(chibi_at_end as AnimatedSprite2D).position.y = 0.0)
	SoundManager.play(SoundManager.SFX_MOVE)
	_trace("[SLIDE-DONE] unit=%d polygon.position now %s (start %s → target %s)" %
		[unit_id, str(unit_node.position), str(start_pos), str(world_pos)])
	# Rotation tween: catch directional polygons (CAVALRY/ARCHER/SCOUT) up to
	# the post-move facing. Non-directional classes return 0 from
	# rotation_for_facing, so the tween is a no-op for them.
	if _grid_controller == null:
		return  # test mode without controller — slide handles position; rotation/active skipped
	var unit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
	if unit != null:
		var target_rotation: float = (visuals as ChapterVisuals) \
			.rotation_for_facing(unit.facing, unit.unit_class)
		var rot_tween: Tween = get_tree().create_tween().set_parallel(true)
		rot_tween.tween_property(unit_node, "rotation", target_rotation, MOVE_ANIM_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Counter-rotate the name label so it stays upright through the slide.
		var label_node: Node = unit_node.get_node_or_null("NameLabel")
		if label_node is Label:
			rot_tween.tween_property(label_node, "rotation", -target_rotation, MOVE_ANIM_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# POLISH-015 fix — Counter-rotate the ChibiSprite so it stays upright
		# through the slide (Q5 Phase 1 mount sets rotation=-poly.rotation at
		# spawn-time only; without this tween the chibi co-rotates with polygon
		# when directional classes (CAVALRY/관우 etc.) change facing → 90° drift).
		# Pattern mirrors NameLabel counter-rotation above. Heavy hide ensures
		# NameLabel and ChibiSprite are mutually exclusive — only one is present.
		var chibi_node: Node = unit_node.get_node_or_null("ChibiSprite")
		if chibi_node is AnimatedSprite2D:
			rot_tween.tween_property(chibi_node, "rotation", -target_rotation, MOVE_ANIM_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Counter-rotate the chevron if it's parented to this unit.
		if is_instance_valid(_turn_indicator) and _turn_indicator.get_parent() == unit_node:
			rot_tween.tween_property(_turn_indicator, "rotation", -target_rotation, MOVE_ANIM_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Q5 1차 revert — HeroPortrait Sprite2D 제거됨. on-grid 표현은 chibi
		# sprite pipeline 으로 별도 (포트레잇 = HUD 자리만).
		# Q4 facing chevron pose update — for symmetric classes (poly.rotation
		# stays 0) the chevron's LOCAL pose carries the facing cue. Recompute
		# position + rotation from the post-move facing so the front indicator
		# tracks correctly. For directional classes the math also works (chevron
		# stays at local (radius, 0) rotation 0).
		var chevron: Node = unit_node.get_node_or_null("FrontChevron")
		if chevron is Polygon2D:
			var facing_vec: Vector2 = ChapterVisuals.facing_to_vector(unit.facing)
			var chevron_radius: float = float(ChapterVisuals.TILE_SIZE) * 0.42
			var new_chevron_pos: Vector2 = facing_vec.rotated(-target_rotation) * chevron_radius
			var new_chevron_rot: float = atan2(facing_vec.y, facing_vec.x) - target_rotation
			rot_tween.tween_property(chevron, "position", new_chevron_pos, MOVE_ANIM_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			rot_tween.tween_property(chevron, "rotation", new_chevron_rot, MOVE_ANIM_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Active-turn highlight follows the moving unit so the gold border sits on
	# the new tile by the time the slide finishes.
	if _grid_controller.get_selected_unit_id() == unit_id:
		visuals.set_selected_coord(to)
	if visuals.has_method("set_active_turn_coord"):
		var active_id: int = _grid_controller.get_active_turn_unit_id() \
			if _grid_controller.has_method("get_active_turn_unit_id") else -1
		if active_id == unit_id:
			visuals.set_active_turn_coord(to)
	# Unit just consumed its move action; clear the move preview so stale
	# "can move here" tiles don't linger. If the unit is still selected,
	# recompute attack reach from its new position so the player sees what
	# they can now hit; otherwise clear attack preview too.
	visuals.set_movable_tiles(PackedVector2Array())
	if _grid_controller.get_selected_unit_id() == unit_id:
		visuals.set_attackable_tiles(_grid_controller.get_attackable_tiles(unit_id))
		# Session-15: a CAVALRY that just crossed CHARGE_THRESHOLD on this slide
		# now has the cyan halo eligible; a SCOUT whose new range overlaps an
		# unacted enemy now has indigo targets. Recompute both from the new
		# position so the verb-feedback cue appears the instant the slide ends.
		_apply_verb_feedback_overlays(visuals, unit_id, to)
	else:
		visuals.set_attackable_tiles(PackedVector2Array())
		_clear_verb_feedback_overlays(visuals)
	# S73 Synergy v2 — adjacency may have shifted; refresh badges. Controller
	# already updated unit.position before unit_moved.emit, so compute uses
	# post-move state. Visually the slide tween animates over 0.6s, but badge
	# text snaps to the new state at slide-start (synergy is logical).
	_refresh_synergy_badges()


## Damage feedback: brief red flash on the defender's polygon so the player
## perceives "the attack landed" even when the defender survives. Without this,
## damage_applied is HUD-only and the grid view shows no change after attack.
func _on_damage_applied(attacker_id: int, defender_id: int, damage: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var unit_node: Node2D = _find_unit_polygon(visuals, defender_id)
	if unit_node == null:
		return
	# Camera shake on every confirmed hit. Gated by the visuals check above so
	# tests without ChapterVisuals don't perturb camera offset.
	if _battle_camera != null and damage > 0:
		_battle_camera.shake()
	if damage > 0:
		SoundManager.play(SoundManager.SFX_HIT)
	var original_modulate: Color = unit_node.modulate
	unit_node.modulate = Color(2.0, 0.4, 0.4, 1.0)  # bright red flash
	# Failsafe: ensure the defender goes back to its non-flash color even if
	# the Tween writes don't advance. Use a timer rather than tween_callback
	# (which also can drop in the same windowed scenarios). Re-resolve the
	# polygon at fire time instead of capturing it — the ChapterVisuals (and its
	# polygons) gets freed by SceneManager the moment the battle ends, and a
	# captured-then-freed node makes Godot spam "Lambda capture freed" warnings.
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		var v: Node = _find_chapter_visuals()
		if v == null:
			return
		var n: Node2D = _find_unit_polygon(v, defender_id)
		if is_instance_valid(n):
			n.modulate = original_modulate)
	# Refresh the defender's HP bar to reflect the new HP. HPStatusController
	# applied the damage synchronously before damage_applied was emitted (grid
	# controller line ~1233-1236), so get_current_hp returns the post-hit value.
	var bar: Node = unit_node.get_node_or_null("HpBar")
	if bar is UnitHpBar and _hp_controller != null:
		(bar as UnitHpBar).set_hp(
			_hp_controller.get_current_hp(defender_id),
			_hp_controller.get_max_hp(defender_id),
		)
	# Floating damage number. Parented to ChapterVisuals (NOT the polygon) so
	# the popup persists if the hit kills the defender — _on_unit_died_visual
	# hides the polygon and its children, but the popup needs to remain visible
	# for the player to read what just happened.
	if damage > 0:
		var popup: DamagePopup = DamagePopup.make(damage)
		popup.position = unit_node.position + Vector2(0.0, -36.0)
		visuals.add_child(popup)
	# Phase 3 Step B — Low-HP danger. Player unit 이 이번 hit 로 25% 경계선
	# 을 cross 한 순간 (pre >= 25% AND post < 25%) 1회용 "위급!" + audio cue
	# + HP bar pulse. 적은 skip — 적 위급은 player 의 momentum 이지 tension
	# 이 아님. Heal 로 복귀 시 다시 cross 가능하면 재발화 — natural design.
	if damage > 0 and _grid_controller != null and _hp_controller != null:
		var defender_unit: BattleUnit = _grid_controller.get_battle_unit(defender_id)
		if defender_unit != null and defender_unit.side == 0:
			var max_hp: int = _hp_controller.get_max_hp(defender_id)
			var post_hp: int = _hp_controller.get_current_hp(defender_id)
			var pre_hp: int = post_hp + damage
			var threshold: float = float(max_hp) * 0.25
			if float(pre_hp) >= threshold and float(post_hp) < threshold and post_hp > 0:
				_trigger_low_hp_danger(unit_node)
				_spawn_banter(defender_id, "low_hp")
	# Attack lunge: nudge attacker toward defender then return. Sells the
	# swing without requiring per-class attack animations. Adjacent attackers
	# get the full distance; ranged attackers (황충 attack_range=2) get the
	# same px distance projected along the line — reads as "leans into the shot".
	var attacker_node: Node2D = _find_unit_polygon(visuals, attacker_id)
	if attacker_node != null:
		var origin: Vector2 = attacker_node.position
		var to_defender: Vector2 = unit_node.position - origin
		if to_defender.length_squared() > 0.0:
			var lunge_target: Vector2 = origin + to_defender.normalized() * LUNGE_DISTANCE
			var lunge_tween: Tween = get_tree().create_tween()
			lunge_tween.tween_property(attacker_node, "position", lunge_target, LUNGE_HALF_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			lunge_tween.tween_property(attacker_node, "position", origin, LUNGE_HALF_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Attack line from attacker to defender. Parented to ChapterVisuals so
		# the line persists if the hit kills the defender or the attacker is
		# repositioned mid-animation. Session-16: pass attacker_class so the
		# line picks a per-class style (spear / bow-arc / scroll-zap / etc.).
		var attacker_class: int = -1
		if _grid_controller != null and _grid_controller.has_method("get_unit_class"):
			attacker_class = _grid_controller.get_unit_class(attacker_id)
		var line: AttackLine = AttackLine.make_for_class(origin, unit_node.position,
			attacker_class)
		visuals.add_child(line)
		# Session-89 — Phase 4 hero attack frame. Hero-specific visual signature
		# overlaying the class line. Currently 5 supported heroes (Shu trio +
		# Zhao Yun + Zhuge Liang); make_for_hero returns null for the rest so
		# the visual stack stays intact. Frame is parented at defender position
		# with attacker offset in node-local space.
		var attacker_unit: BattleUnit = _grid_controller.get_battle_unit(attacker_id)
		if attacker_unit != null:
			var frame: HeroAttackFrame = HeroAttackFrame.make_for_hero(
				origin - unit_node.position, attacker_unit.hero_id)
			if frame != null:
				frame.position = unit_node.position
				visuals.add_child(frame)


## Session-23 — FIRE tile round-start damage view feedback. Distinct from
## attack hits: orange flash + orange popup, no camera shake, no SFX_HIT.
## The round-start tick is environmental — we don't want it to feel like a
## confirmed swing. Reused HP-bar refresh + 0.25s revert-via-timer pattern
## from _on_damage_applied (G-31: timer-on-tree, not on the polygon).
## Session-26 — added SFX_FIRE_TICK (quiet noise-burst hiss) so the tick has
## an audio channel without crossing into SFX_HIT territory.
func _on_fire_damage_applied(defender_id: int, damage: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var unit_node: Node2D = _find_unit_polygon(visuals, defender_id)
	if unit_node == null:
		return
	SoundManager.play(SoundManager.SFX_FIRE_TICK)
	var original_modulate: Color = unit_node.modulate
	# Orange-burn flash — distinct from the red attack flash so the player
	# reads "this was the fire tile, not a hit".
	unit_node.modulate = Color(2.0, 1.2, 0.4, 1.0)
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		var v: Node = _find_chapter_visuals()
		if v == null:
			return
		var n: Node2D = _find_unit_polygon(v, defender_id)
		if is_instance_valid(n):
			n.modulate = original_modulate)
	# Refresh the unit's HP bar — apply_damage ran synchronously before this
	# signal fired so get_current_hp returns the post-tick value.
	var bar: Node = unit_node.get_node_or_null("HpBar")
	if bar is UnitHpBar and _hp_controller != null:
		(bar as UnitHpBar).set_hp(
			_hp_controller.get_current_hp(defender_id),
			_hp_controller.get_max_hp(defender_id),
		)
	if damage > 0:
		var popup: DamagePopup = DamagePopup.make(damage, DamagePopup.COLOR_FIRE)
		popup.position = unit_node.position + Vector2(0.0, -36.0)
		visuals.add_child(popup)


## Death feedback: fade the dead unit's polygon to transparent over
## DEATH_FADE_DURATION, then hide it. Without this, the killed unit either
## stays on screen (no handler) or vanishes instantly (snap-hide), both of
## which read worse than a brief fade.
##
## Tween ordering note: the flash tween from _on_damage_applied is created
## first (same-frame deferred chain damage_applied → unit_died → handler),
## so the fade tween's modulate:a writes overlay on top of the flash's full
## modulate writes per frame — the unit fades to transparent while the red
## flash recedes. Final visible=false guards via is_instance_valid in case
## the polygon is freed mid-tween (scene transition).
func _on_unit_died_visual(unit_id: int) -> void:
	# ADR-0022 civilian visualization — controller's _civilian_recover_on_carrier_death
	# fires BEFORE unit_visual_died.emit (see grid_battle_controller.gd:1276), so by
	# the time this handler runs, any ESCORTED token bound to `unit_id` is already
	# IDLE at the death cell. Refresh repaints the recovered token + clears the
	# stale EscortMarker overlay on the (about-to-be-hidden) carrier polygon.
	if _civilian_visuals != null and is_instance_valid(_civilian_visuals):
		_civilian_visuals.refresh()
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var unit_node: Node2D = _find_unit_polygon(visuals, unit_id)
	if unit_node == null:
		return
	# G1 polish (battle-camera-work.md §3 M-2 Defeat tier): player-side death
	# gets a stronger camera shake — marks "지키지 못함" emotional beat.
	# Enemy-side deaths keep the standard Medium shake from _on_damage_applied
	# (no additive shake — repeated death feedback would desensitize).
	if _battle_camera != null and _grid_controller != null:
		var unit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
		if unit != null and unit.side == 0:
			_battle_camera.shake(10.0, 0.45)
	# Failsafe pattern (windowed Tween-writes can stall): set the final state
	# via a SceneTreeTimer that fires unconditionally regardless of tween
	# scheduler behaviour. Re-resolve the polygon at fire time (don't capture it)
	# — see _on_damage_applied for the "Lambda capture freed" rationale.
	get_tree().create_timer(DEATH_FADE_DURATION + 0.05).timeout.connect(func() -> void:
		var v: Node = _find_chapter_visuals()
		if v == null:
			return
		var n: Node2D = _find_unit_polygon(v, unit_id)
		if is_instance_valid(n):
			n.modulate.a = 0.0
			n.visible = false)
	# S73 Synergy v2 — a unit death may activate Lone Wolf (위연's last neighbor
	# fell) or break Peach Garden (a brother died). Recompute now; controller
	# already marked the unit dead before unit_visual_died.emit.
	_refresh_synergy_badges()


## Mounts a brief centered title card (chapter title + tagline) at battle start.
## Auto-removes after TITLE_CARD_DURATION via SceneTreeTimer — chosen over a
## _process countdown because _pause_overworld() disables _process on this scene
## (see _on_battle_outcome_resolved) while SceneTreeTimer.timeout still fires.
## No fade-out tween: Tween property writes are unreliable in the windowed env
## (G-30b), so the card just snaps away when the timer fires.
func _mount_title_card(chapter: ChapterDefinition, roster: Array[BattleUnit]) -> void:
	if _hud_layer == null or chapter == null:
		return
	var flavor: Dictionary = CHAPTER_FLAVOR.get(chapter.chapter_id, {}) as Dictionary
	var title_text: String = flavor.get("title", "제%d장" % chapter.chapter_number) as String
	var tagline_text: String = flavor.get("tagline", "") as String
	var roster_text: String = _format_player_roster_line(roster)

	# CenterContainer (full-rect) centers its single child — clean, no offset math.
	var card: CenterContainer = CenterContainer.new()
	card.name = "TitleCard"
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var title: Label = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", Palette.JI_BAEK)
	title.add_theme_color_override("font_outline_color", Palette.MUK_OUTLINE)
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)

	if not tagline_text.is_empty():
		var tagline: Label = Label.new()
		tagline.text = tagline_text
		tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tagline.add_theme_color_override("font_color", Palette.JI_BAEK_DIM)
		tagline.add_theme_color_override("font_outline_color", Palette.MUK_OUTLINE)
		tagline.add_theme_constant_override("outline_size", 6)
		tagline.add_theme_font_size_override("font_size", 22)
		box.add_child(tagline)

	# Session-39 — tactical objective line (영걸전식 mission briefing). Composed
	# from the resolver so it stays in sync with the in-battle UI-GB-08 label.
	# UI_GOLD reads as "must-do" without colliding with the art-bible reserved
	# 주홍/금색 (운명 분기 / Legendary VFX only — see distilled bible §1).
	var objective_text: String = String(_resolve_victory_condition_label(chapter))
	if not objective_text.is_empty():
		var objective_label: Label = Label.new()
		objective_label.text = "▶  %s" % objective_text
		objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		objective_label.add_theme_color_override("font_color", Palette.UI_GOLD)
		objective_label.add_theme_color_override("font_outline_color", Palette.MUK_OUTLINE)
		objective_label.add_theme_constant_override("outline_size", 6)
		objective_label.add_theme_font_size_override("font_size", 24)
		box.add_child(objective_label)

	if not roster_text.is_empty():
		var roster_label: Label = Label.new()
		roster_label.text = roster_text
		roster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		roster_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Cool tint so the roster reads as "your forces" — distinct from the
		# warm tagline (situation prose) above it.
		roster_label.add_theme_color_override("font_color", Palette.CHEONG_HOE_LIFT)
		roster_label.add_theme_color_override("font_outline_color", Palette.MUK_OUTLINE)
		roster_label.add_theme_constant_override("outline_size", 5)
		roster_label.add_theme_font_size_override("font_size", 18)
		box.add_child(roster_label)

	# Phase 3 Step C (rev 2) — Hidden condition hint as a SEPARATE moment AFTER
	# title card disappears. v1 buried the hint inside the title card stack and
	# user attestation: "그런게 있었는지 눈치를 못 챘어". Now: title card runs
	# its normal duration → fades → 0.2s gap → hint label appears center-screen
	# alone, dwells 2.0s with pulse animation, self-frees.
	if not chapter.hidden_branch_key.is_empty() and not chapter.hidden_condition.is_empty():
		var hint_text: String = _resolve_hidden_condition_hint(chapter.hidden_condition)
		# Schedule the hint to appear AFTER the title card lifecycle.
		# ignore_time_scale=true so Engine.time_scale (Phase 3 Step A crit
		# hit-stop) doesn't shift the schedule.
		get_tree().create_timer(TITLE_CARD_DURATION + 0.2, true, false, true) \
			.timeout.connect(func() -> void: _mount_hidden_hint_moment(hint_text))

	# Session-46 — process_mode ALWAYS on both card + Timer. BattleScene flips
	# PROCESS_MODE_DISABLED when SceneManager pauses the "overworld" (the battle
	# itself is treated as that), which would freeze the title card's Timer
	# along with it → card never disappears (user-reported S45 windowed bug:
	# title card persisting from Round 1 through Round 2). ALWAYS makes the
	# Timer fire regardless of ancestor pause state. Same pattern as
	# StoryBeatScreen.process_mode (line 95 of story_beat_screen.gd).
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	_hud_layer.add_child(card)
	# Self-destruct via a child Timer (not a SceneTreeTimer): if the scene reloads
	# before TITLE_CARD_DURATION elapses, the Timer is freed along with `card`, so
	# there's no dangling callback referencing a freed node.
	var life: Timer = Timer.new()
	life.process_mode = Node.PROCESS_MODE_ALWAYS  # belt-and-suspenders per S46
	life.one_shot = true
	life.autostart = true
	life.wait_time = TITLE_CARD_DURATION
	# Guarded callback per G-11 — if `card` somehow got freed via another path
	# (scene reload mid-countdown), the direct `card.queue_free` would error.
	life.timeout.connect(func() -> void:
		if is_instance_valid(card):
			card.queue_free())
	card.add_child(life)


## Phase 3 Step C (rev 2) helper. Spawns the hidden hint as a separate
## center-screen moment. 24pt JU_HONG label + MUK outline + pulse animation
## (modulate.a 1.0 → 0.7 → 1.0 over 0.6s, repeats twice) + 2.0s total dwell.
## Self-frees on dwell expiry. process_mode ALWAYS so PROCESS_MODE_DISABLED
## (BattleScene's overworld-pause state) doesn't freeze the timer.
func _mount_hidden_hint_moment(hint_text: String) -> void:
	if _hud_layer == null or hint_text.is_empty():
		return
	var center: CenterContainer = CenterContainer.new()
	center.name = "HiddenHintMoment"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.process_mode = Node.PROCESS_MODE_ALWAYS

	var hint: Label = Label.new()
	hint.text = hint_text
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_color", Palette.JU_HONG)
	hint.add_theme_color_override("font_outline_color", Palette.MUK_OUTLINE)
	hint.add_theme_constant_override("outline_size", 6)
	hint.add_theme_font_size_override("font_size", 24)
	center.add_child(hint)
	_hud_layer.add_child(center)

	# 2-channel animation: pulse modulate.a + self-destruct after dwell.
	var pulse: Tween = get_tree().create_tween()
	pulse.set_loops(2)
	pulse.tween_property(hint, "modulate:a", 0.6, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pulse.tween_property(hint, "modulate:a", 1.0, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Self-destruct timer, separate from the pulse loop. 2.0s total dwell.
	get_tree().create_timer(2.0, true, false, true).timeout.connect(
		func() -> void:
			if is_instance_valid(center):
				center.queue_free()
	)


## Phase 3 Step C helper. Translates a hidden_condition Dictionary into a vague
## Korean hint line for the title card. Strong spoiler 회피 — condition 의
## *방향* 만 시사 (rear_attacks → "후방", no_player_deaths → "한 명도", etc).
## Unknown condition types fall through to a generic destiny-stirring line.
##
## hidden_condition schema (HiddenConditionEvaluator 와 일치):
##   {"type": "fate_threshold", "field": <name>, "op": ">=" / ">" / "==" / "<=" / "<", "value": Number, ...}
func _resolve_hidden_condition_hint(condition: Dictionary) -> String:
	var cond_type: String = condition.get("type", "") as String
	if cond_type != "fate_threshold":
		return "운명은 아직 결정되지 않았다..."
	var field: String = condition.get("field", "") as String
	# Per-field 직관적 hint. Coverage 는 production scenario 의 실제 fate
	# fields 만 — 새 field 추가 시 이 표 도 늘리거나 default 사용.
	match field:
		"rear_attacks":
			return "적의 후방을 노려라"
		"player_deaths", "no_player_deaths":
			return "한 명도 잃지 마라"
		"formation_turns", "fate_formation_turns":
			return "진형을 유지하라"
		"kills", "total_kills":
			return "신속히 격파하라"
		"dmg_to_lubu":
			return "여포에게 결정타를 내려라"
		"signature_relief", "active_signature_count":
			return "전설의 끝자락을 잡아라"
		_:
			return "운명은 아직 결정되지 않았다..."


## Builds the "출진: 유비 (지휘) · 장비 (보병)" line shown under the chapter
## tagline so the player sees who they're commanding before the fight starts.
## Player-side units only — enemies are revealed via the units themselves.
## Returns "" when the roster has no player units (no line rendered).
func _format_player_roster_line(roster: Array[BattleUnit]) -> String:
	var parts: Array[String] = []
	for unit: BattleUnit in roster:
		if unit.side != 0:
			continue
		var hero: HeroData = HeroDatabase.get_hero(unit.hero_id)
		var name_ko: String = hero.name_ko if hero != null and hero.name_ko != "" else String(unit.hero_id)
		var class_name_ko: String = _class_label_ko(unit.unit_class)
		parts.append("%s (%s)" % [name_ko, class_name_ko])
	if parts.is_empty():
		return ""
	return "출진: " + "  ·  ".join(parts)


## Korean short label for the 6 UnitRole classes. Kept inline so the title card
## doesn't pull on the BattleHUD's i18n stack (which is en.po only).
func _class_label_ko(unit_class: int) -> String:
	match unit_class:
		int(UnitRole.UnitClass.CAVALRY):    return "기병"
		int(UnitRole.UnitClass.INFANTRY):   return "보병"
		int(UnitRole.UnitClass.ARCHER):     return "궁병"
		int(UnitRole.UnitClass.STRATEGIST): return "책사"
		int(UnitRole.UnitClass.COMMANDER):  return "지휘"
		int(UnitRole.UnitClass.SCOUT):      return "척후"
		_:                                  return "?"


## Mounts a small always-on controls hint at the bottom of the viewport.
## A first-time player otherwise has no cue for the click flow (select → move/
## attack tile → re-click to end turn). Bottom-anchored Label inside HUDLayer.
func _mount_controls_hint() -> void:
	if _hud_layer == null:
		return
	var hint: Label = Label.new()
	hint.name = "ControlsHint"
	# Session-49 — hint text corrected to reflect ACTUAL ESC binding (per
	# assets/data/input/default_bindings.json): ESC maps to move_cancel +
	# attack_cancel + close_menu, NOT to open_game_menu. Pre-S49 text said
	# "[Esc] 일시정지" — misleading, so user gave up trying ESC to cancel
	# misclicks. Right-click (mouse button 2) also cancels per same binding
	# file; now surfaced too. 일시정지 is on a separate key (P, 4194346).
	# Session-52 — hint clarified. ESC / right-click now have a priority
	# dispatcher: undo move (if MOVEd this turn) → cancel selection → pause.
	hint.text = "유닛 클릭 → 빈 칸 = 이동 · 적 클릭 1회 = 미리보기 · 2회 = 공격 · [D] 방어 · 재클릭 = 턴 종료    [Esc / 우클릭] 이동 취소 → 선택 취소 → 일시정지  [H] 도움말"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86, 0.92))
	hint.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1.0))
	hint.add_theme_constant_override("outline_size", 5)
	hint.add_theme_font_size_override("font_size", 18)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -34.0
	hint.offset_bottom = -8.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(hint)


## Battle-outcome handler (connected to GridBattleController's LOCAL signal).
## Dims the grid, shows the OutcomeBanner, and mounts outcome-aware post-battle
## buttons. The ScenarioRunner-side advance (BEAT_6→9, chapter transition) is
## driven by _proceed_scenario() when the player chooses to move on — the
## GameBus emit that wakes ScenarioRunner here is done by BattleOutcomeBridge,
## which is also connected to the controller's signal (R-7: scene root never
## emits GameBus). The HUD's UI-GB-09 results panel renders in parallel.
func _on_battle_outcome_resolved(outcome: StringName, _fate_data: Dictionary) -> void:
	_trace("[BATTLE-END] outcome=%s — showing banner + post-battle options" % outcome)
	_battle_resolved = true
	_pending_outcome = _outcome_result(outcome)
	# Root cause of "restart hotkey doesn't fire" (session 4): in standalone
	# launch, SceneManager treats this BattleScene as the "overworld" and calls
	# _pause_overworld() on it (process_mode = DISABLED + set_process_input(false)
	# + set_process_unhandled_input(false)). That stops _process() — so the
	# restart-key polling loop below never runs. This signal handler fires
	# regardless of process_mode (direct signal callback), so we re-arm our own
	# processing here, the moment the battle ends. PROCESS_MODE_ALWAYS also
	# survives any future pause. Re-enable _input/_unhandled_input too for parity.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	var visuals: Node = _find_chapter_visuals()
	if is_instance_valid(visuals) and visuals is CanvasItem:
		# Instant-set the final dim color so the visual change is guaranteed
		# even if Tween writes don't advance (observed in user windowed env).
		# (SceneManager may free this node a frame or two later on its own
		# battle_outcome_resolved subscription — guard with is_instance_valid.)
		(visuals as CanvasItem).modulate = OUTCOME_DIM_COLOR
	if _hud_layer != null:
		# Drop the controls hint — the screen now belongs to the outcome banner.
		var hint: Node = _hud_layer.get_node_or_null("ControlsHint")
		if hint != null:
			hint.queue_free()
		var banner: OutcomeBanner = OutcomeBanner.make(outcome)
		banner.name = "OutcomeBanner"
		_hud_layer.add_child(banner)
		_mount_post_battle_buttons(_pending_outcome)
		# Phase 3 Step F — Battle outcome 모먼트. 결과별 결 분리:
		#   WIN  → 환희 (gold flash + camera slow zoom-out)
		#   LOSS → 무게 (MUK darken 길게 + 깊은 호흡)
		#   DRAW → 조용 (시각 효과 0, banner 만으로 충분)
		# 1/battle 발화 — climax 라 강도 가장 높은 family.
		var result_kind: int = _pending_outcome
		if result_kind == BattleOutcome.Result.WIN:
			_trigger_outcome_victory_drama()
			_fire_player_roster_banter("outcome_win")
			# S18 — enemy commander's defeat line voices the loser's side of
			# the same moment. 2.0s start_delay defers enemy voice until after
			# player celebration banter window.
			_fire_enemy_roster_banter("outcome_loss", 2.0)
		elif result_kind == BattleOutcome.Result.LOSS:
			_trigger_outcome_defeat_drama()
			_fire_player_roster_banter("outcome_loss")


## Maps a controller outcome StringName to a BattleOutcome.Result int.
func _outcome_result(outcome: StringName) -> int:
	match outcome:
		&"VICTORY_ANNIHILATION": return BattleOutcome.Result.WIN
		&"VICTORY_SURVIVE": return BattleOutcome.Result.WIN  # Session-28
		&"VICTORY_ESCORT": return BattleOutcome.Result.WIN  # Session-30
		&"VICTORY_REACH_TILE": return BattleOutcome.Result.WIN  # Session-31
		&"DEFEAT_ANNIHILATION": return BattleOutcome.Result.LOSS
		&"DEFEAT_ESCORT_LOST": return BattleOutcome.Result.LOSS  # Session-30
		&"DEFEAT_REACH_FAILED": return BattleOutcome.Result.LOSS  # Session-31
		&"TURN_LIMIT_REACHED": return BattleOutcome.Result.DRAW
		_: return BattleOutcome.Result.DRAW


## Session-29 — chapter-aware victory condition label for UI-GB-08. Reads
## chapter.victory_conditions and returns the appropriate Korean label.
## Falls through to the pre-S29 "적 부대 전멸" (defeat all enemies) phrasing
## for ANNIHILATION default + null vc — keeping chapters 1-4 unchanged.
## Session-30 — ESCORT branch added: "호위 + 적 전멸".
## Session-31 — REACH_TILE branch added: pre-S37 was hardcoded
## "특정 위치 도달"; post-S37 interpolates the target_tile coordinate so the
## player sees WHERE to go in-battle (e.g., "지정 타일 (13, 4) 도달").
func _resolve_victory_condition_label(chapter: ChapterDefinition) -> StringName:
	if chapter == null or chapter.victory_conditions == null:
		return &"적 부대 전멸"
	var vc: VictoryConditions = chapter.victory_conditions
	match vc.primary_condition_type:
		VictoryConditions.ConditionType.SURVIVE_N_ROUNDS:
			return StringName("%d라운드 버티기" % vc.survive_rounds)
		VictoryConditions.ConditionType.ESCORT:
			return &"호위 + 적 부대 전멸"
		VictoryConditions.ConditionType.REACH_TILE:
			return StringName("지정 타일 (%d, %d) 도달" % [vc.target_tile.x, vc.target_tile.y])
		_:
			return &"적 부대 전멸"


## Outcome-aware post-battle button cluster below the OutcomeBanner.
## WIN → 챕터 선택으로 / 처음부터 / 종료.   DRAW or LOSS → 재시도 / 챕터 선택으로 / 종료.
## (S17 macro-loop — primary "advance" button now routes to chapter_select
## instead of auto-loading the next chapter; player chooses pace explicitly.)
## Buttons go through the Viewport GUI path, so they work even if the keyboard
## poll in _process doesn't register in the windowed env (session 4). The first
## button grabs focus so Enter activates it.
func _mount_post_battle_buttons(result: int) -> void:
	if _hud_layer == null:
		return
	var bar: CenterContainer = CenterContainer.new()
	bar.name = "PostBattleButtons"
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.offset_top = 150.0  # push the cluster below the outcome glyph
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE  # only the buttons capture clicks
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	# S17 macro-loop — primary "advance" button now leads back to chapter_select
	# (via _proceed_scenario tail change), not the next-chapter auto-load. Button
	# label renamed to "챕터 선택으로 ▶" to match the new flow semantics.
	var first_btn: Button = null
	if result == BattleOutcome.Result.WIN:
		first_btn = _add_post_battle_button(row, "챕터 선택으로 ▶  (Enter)", _proceed_scenario)
		_add_post_battle_button(row, "처음부터", _restart_scenario)
	else:
		first_btn = _add_post_battle_button(row, "재시도  (Enter)", _retry_chapter)
		_add_post_battle_button(row, "챕터 선택으로 ▶", _proceed_scenario)
	_add_post_battle_button(row, "종료 (Esc)", func() -> void: get_tree().quit())

	_hud_layer.add_child(bar)
	if first_btn != null:
		first_btn.grab_focus()


func _add_post_battle_button(row: HBoxContainer, label: String, on_press: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(200, 50)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(func() -> void:
		_trace("[BATTLE-END] button pressed: %s" % label)
		on_press.call())
	row.add_child(btn)
	return btn


## Re-fight the current chapter. On LOSS/DRAW the scenario is in BEAT_6_RESULT;
## retry_outcome() bounces it back to BEAT_4_PREP (bumping echo_count), then the
## scene reload re-runs _ready() → _start_battle() → confirm.
func _retry_chapter() -> void:
	_battle_resolved = false  # neutralize the post-battle key poll during the awaits
	if await _wait_for_scenario_state(ScenarioRunner.State.BEAT_6_RESULT):
		ScenarioRunner.retry_outcome()  # -> BEAT_4_PREP
	else:
		push_warning("BattleScene: retry — ScenarioRunner not in BEAT_6_RESULT; reloading anyway")
	await _reload_via_scenario()


## Re-start the whole scenario from chapter 1. load_scenario resets ScenarioRunner
## to CHAPTER_START → BEAT_1_ANCHOR; the scene reload then drives it to battle.
func _restart_scenario() -> void:
	_battle_resolved = false
	ScenarioRunner.load_scenario(ScenarioRunner.get_active_scenario_path())
	await _reload_via_scenario()


## Accept the outcome and move the scenario forward: BEAT_6 → 7 → 8 → 9 → either
## the next chapter (reload this scene — _ready picks it up via ScenarioRunner)
## or SCENARIO_END (show the ending screen, no reload). In windowed runs, the
## Beat 8 revelation + Beat 9 transition are presented via StoryBeatScreen before
## the chapter is walked off (BEAT_8 → BEAT_9 advances the chapter index).
func _proceed_scenario() -> void:
	_battle_resolved = false  # neutralize the post-battle key poll during the awaits
	if not await _wait_for_scenario_state(ScenarioRunner.State.BEAT_6_RESULT):
		push_warning("BattleScene: proceed — ScenarioRunner never reached BEAT_6_RESULT")
		return
	ScenarioRunner.accept_outcome()  # -> BEAT_7_JUDGMENT -> BEAT_8_REVEAL (auto)
	# Post-battle story (windowed only). Capture the just-finished chapter + its
	# branch choice NOW — advance_beat() below pushes BEAT_8 -> BEAT_9, which
	# advances the chapter index and clears _last_branch_choice.
	if _should_present_story() \
			and ScenarioRunner.get_state() == ScenarioRunner.State.BEAT_8_REVEAL:
		var finished_chapter: ChapterDefinition = ScenarioRunner.get_current_chapter()
		var branch_choice: DestinyBranchChoice = ScenarioRunner.get_last_branch_choice()
		if finished_chapter != null:
			# Session-42 — post-battle sequence split into 3 acts so the
			# ConsequenceScreen ("역사의 두 갈래") slots between Beat 8 (this
			# chapter's resolved ending) and Beat 9 (transition to next chapter).
			# Pre-S42 the whole [b8, b9] array fed a single StoryBeatScreen mount.
			var branch_key: String = ""
			if branch_choice != null and not branch_choice.is_invalid:
				branch_key = branch_choice.branch_key
			if branch_key.is_empty():
				branch_key = _guess_branch_key_for_outcome(finished_chapter)
			var b8: Dictionary = _beat_content(
				_beat_8_text_key_for_branch(finished_chapter, branch_key))
			var b9: Dictionary = _beat_content(finished_chapter.beat_9_text_key)
			_clear_post_battle_ui()
			# Act 0.5 (S65+) — legendary cue: 5 시그니처 + ch25 hidden 동시
			# 달성 시 별빛 fade overlay + victory sfx 로 "전설의 새벽" 도달을
			# 강조. visual cue 끝나야 b8 prose 표시 (~1.2초 await).
			# B1.2 — hidden branch (legendary 가 아닌) 일 경우 JU_HONG edge
			# vignette 로 "역사가 갈라진다" 운명 분기 punctuation. legendary
			# 와 hidden 동시 fire 방지 위해 elif (legendary 우선).
			if branch_key == "WIN_wuzhang_legendary_dawn":
				await _show_legendary_visual_cue()
			elif not branch_key.is_empty() \
					and branch_key == finished_chapter.hidden_branch_key:
				await _show_hidden_branch_vignette()
			# Act 1 — Beat 8 (your branch's resolved prose).
			if not b8.is_empty():
				await _present_story_beats([b8])
			# Act 2 (S42) — ConsequenceScreen comparison. Mounted only when an
			# OTHER branch exists in beat_8_revelations; chapters with only one
			# authored revelation skip silently.
			await _present_consequence_screen(finished_chapter, branch_key)
			# Act 3 — Beat 9 (transition to next chapter).
			if not b9.is_empty():
				await _present_story_beats([b9])
	if ScenarioRunner.get_state() == ScenarioRunner.State.BEAT_8_REVEAL:
		ScenarioRunner.advance_beat()  # -> BEAT_9_TRANSITION -> next chapter BEAT_1_ANCHOR | SCENARIO_END
	await get_tree().process_frame
	if ScenarioRunner.get_state() == ScenarioRunner.State.SCENARIO_END:
		_show_ending_screen()
		return
	# S17 macro-loop — instead of auto-reloading the next chapter (pre-S17
	# behaviour), return to the chapter-selection screen so the player picks
	# what to play next. The ScenarioRunner state machine has already advanced
	# to BEAT_1_ANCHOR of the next chapter via BEAT_8 → BEAT_9 → LOADING →
	# CHAPTER_START; that state is fine to leave because chapter_select's
	# click handler calls reset_for_tests + jump_to_chapter, which re-seeds
	# state from scratch. The next chapter "queued" by the state machine is
	# silently discarded when this scene tears down.
	get_tree().change_scene_to_file(_CHAPTER_SELECT_SCENE_PATH)


## Reloads this scene once SceneManager has settled to IDLE (it's tearing down
## the just-finished chapter's ChapterVisuals after battle_outcome_resolved). The
## extra trailing frame lets SceneManager's queue_free() actually land before the
## reloaded _ready() re-runs _spawn_unit_polygons_async. No-op (warns) if this
## scene isn't the current scene (non-standalone mode — post-MVP).
func _reload_via_scenario() -> void:
	for _i: int in 30:
		if SceneManager.state == SceneManager.State.IDLE:
			break
		await get_tree().process_frame
	await get_tree().process_frame
	_battle_resolved = false
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()
	else:
		push_warning("BattleScene: scenario-driven reload outside standalone mode not implemented")


## Awaits (up to ~1s) until ScenarioRunner reaches `target`. Returns true on
## success, false on timeout. ScenarioRunner advances via a CONNECT_DEFERRED
## GameBus subscription, so we may need to wait a frame or two after the battle
## ends before BEAT_6_RESULT is reached.
func _wait_for_scenario_state(target: int) -> bool:
	for _i: int in 60:
		if ScenarioRunner.get_state() == target:
			return true
		await get_tree().process_frame
	return ScenarioRunner.get_state() == target


## Scenario-complete screen. Replaces the post-battle buttons with an ending
## card + 처음부터 / 종료. Shown when _proceed_scenario walks the last chapter
## off the end (ScenarioRunner state == SCENARIO_END).
func _show_ending_screen() -> void:
	_trace("[BATTLE-END] scenario complete — showing ending screen")
	if _hud_layer == null:
		return
	var old_buttons: Node = _hud_layer.get_node_or_null("PostBattleButtons")
	if old_buttons != null:
		old_buttons.queue_free()
	var old_banner: Node = _hud_layer.get_node_or_null("OutcomeBanner")
	if old_banner != null:
		old_banner.queue_free()
	# S65+ — 3-tier ending resolution. Final chapter's ending_screen_text_keys
	# map + last branch_path_id → epilogue prose. Fallback to generic title/sub
	# when scenario doesn't author per-branch endings (mvp_wei + future lines).
	var ending: Dictionary = _resolve_ending_screen_content()
	var card: CenterContainer = CenterContainer.new()
	card.name = "EndingCard"
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the epilogue body width readable on narrow viewports.
	box.custom_minimum_size = Vector2(820.0, 0.0)
	card.add_child(box)
	var title: Label = Label.new()
	title.text = ending.get("title", "시나리오 클리어") as String
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(820.0, 0.0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", Palette.UI_GOLD)  # warm gold UI-hierarchy, NOT reserved GEUM_SAEK
	title.add_theme_color_override("font_outline_color", Palette.MUK_OUTLINE)
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	var sub: Label = Label.new()
	sub.text = ending.get(
		"body", "장판파에서 강하 외곽까지 — 촉한은 살아남았고, 적벽이 기다린다."
	) as String
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(820.0, 0.0)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78, 1.0))  # off-cream subtitle — not a palette role
	sub.add_theme_color_override("font_outline_color", Palette.MUK_OUTLINE)
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_font_size_override("font_size", 18)
	box.add_child(sub)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	# S17 macro-loop — primary action returns to chapter_select; "처음부터"
	# (full ch01 restart) stays as a secondary option for full-replay desire.
	var return_btn: Button = _add_post_battle_button(
		row, "챕터 선택으로  (Enter)",
		func() -> void: get_tree().change_scene_to_file(_CHAPTER_SELECT_SCENE_PATH)
	)
	_add_post_battle_button(row, "처음부터", _restart_scenario)
	_add_post_battle_button(row, "종료 (Esc)", func() -> void: get_tree().quit())
	_hud_layer.add_child(card)
	return_btn.grab_focus()


## S65+ — Legendary cue: 별빛 fade overlay + dedicated Legendary fanfare.
## Awaited from _proceed_scenario between Beat 8 prose and outcome banner
## when the resolved branch_path_id is WIN_wuzhang_legendary_dawn. Gold
## ColorRect overlay + S66 SFX_LEGENDARY (3s ascending C-major arpeggio,
## distinct from the standard SFX_VICTORY chapter-close triad) mark the
## "전설의 새벽" moment with a clearly bigger gesture.
##
## Headless callers (_should_present_story == false) are NOT routed through
## _proceed_scenario's b8 path, so this cue never fires in tests by default.
func _show_legendary_visual_cue() -> void:
	if _hud_layer == null:
		return
	# Try the SFX channel first — non-blocking. Skipped if SoundManager autoload
	# is missing or its API differs (defensive).
	if Engine.has_singleton("SoundManager") \
			or get_node_or_null("/root/SoundManager") != null:
		var sm: Node = get_node_or_null("/root/SoundManager")
		if sm != null and sm.has_method("play_sfx"):
			sm.call("play_sfx", &"legendary")
	# Visual: full-screen gold ColorRect that fades from 0 → 0.6 alpha and back.
	# G-31: bind tween to SceneTree (NOT self) so SceneManager.pause_overworld
	# during cue presentation doesn't stall the animation.
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "LegendaryCueOverlay"
	overlay.color = Color(Palette.GEUM_SAEK.r, Palette.GEUM_SAEK.g, Palette.GEUM_SAEK.b, 0.0)  # 금색 — legendary cue per bible §1
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(overlay)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(overlay, "color:a", 0.6, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "color:a", 0.0, 0.65) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(overlay):
		overlay.queue_free()


## B1.2 — hidden branch resolution 시 "역사가 갈라진다" punctuation.
## branch_key 가 chapter.hidden_branch_key 와 일치할 때만 fire — legendary 분기는
## 별도 cue (_show_legendary_visual_cue) 가 우선 처리하므로 caller 가 elif 로
## 분기. JU_HONG (`#C0392B`) 의 첫 적용 site — distilled bible §1 "운명 분기
## ONLY" reservation. Top + bottom 60px edge strips 가 0 → 0.5 alpha 로 brackets
## 처럼 fade-in (0.30s), 0 alpha 로 fade-out (0.55s). full-screen GEUM_SAEK
## legendary wash 와 명확히 다른 gesture (edge bracket vs full overlay).
##
## Headless callers 는 _proceed_scenario's b8 path 를 거치지 않아 이 cue 도 fire 안 됨.
func _show_hidden_branch_vignette() -> void:
	if _hud_layer == null:
		return
	# Phase 3 Step G — Hidden branch trigger 드라마 강화. 기존 edge strip 만
	# 으로는 "역사가 갈라진다" 의 정점 체감 약함 — hit-stop + 중심 텍스트
	# "운명이 바뀐다" 추가. JU_HONG reservation site (art-bible §1) 유일한
	# vignette 발화점이라 inflation 0.
	Engine.time_scale = 0.5
	get_tree().create_timer(0.35, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0
	)
	# 중심 텍스트 — 별도 Label, 0.85s dwell + drift up + fade out
	var caption: Label = Label.new()
	caption.text = "운명이 바뀐다"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 32)
	caption.add_theme_color_override("font_color", Palette.JU_HONG)
	caption.add_theme_color_override("font_outline_color", Palette.MUK_OUTLINE)
	caption.add_theme_constant_override("outline_size", 8)
	var caption_wrap: CenterContainer = CenterContainer.new()
	caption_wrap.name = "HiddenVignetteCaption"
	caption_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_wrap.add_child(caption)
	_hud_layer.add_child(caption_wrap)
	var caption_tween: Tween = get_tree().create_tween()
	caption_tween.tween_property(caption, "modulate:a", 1.0, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	caption_tween.tween_interval(0.30)
	caption_tween.tween_property(caption, "modulate:a", 0.0, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	caption_tween.tween_callback(caption_wrap.queue_free)
	caption.modulate.a = 0.0  # fade-in 시작점
	var top_strip: ColorRect = ColorRect.new()
	top_strip.name = "HiddenVignetteTop"
	top_strip.color = Color(Palette.JU_HONG.r, Palette.JU_HONG.g, Palette.JU_HONG.b, 0.0)
	top_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_strip.offset_bottom = 60.0
	top_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(top_strip)
	var bottom_strip: ColorRect = ColorRect.new()
	bottom_strip.name = "HiddenVignetteBottom"
	bottom_strip.color = Color(Palette.JU_HONG.r, Palette.JU_HONG.g, Palette.JU_HONG.b, 0.0)
	bottom_strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_strip.offset_top = -60.0
	bottom_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(bottom_strip)
	# G-31: SceneTree-bound tween (BattleScene PROCESS_MODE_DISABLED 우회).
	var tween: Tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(top_strip, "color:a", 0.5, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(bottom_strip, "color:a", 0.5, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(top_strip, "color:a", 0.0, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.30)
	tween.tween_property(bottom_strip, "color:a", 0.0, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.30)
	await tween.finished
	if is_instance_valid(top_strip):
		top_strip.queue_free()
	if is_instance_valid(bottom_strip):
		bottom_strip.queue_free()


## Mounts the 시그니처 카운트 badge on _hud_layer top-right when at least one
## persistent signature flag is active. Skipped silently on scenarios that
## don't author any signature_branches (mvp_wei, prototype lines) — guarded
## via ScenarioRunner.get_total_signature_count() == 0 OR active count == 0.
##
## Format: "✦ N/총 시그니처". Re-mounted on every chapter (the previous badge
## is removed in _start_battle's MapGrid step where stale Hud children are
## already cleared on scene reload).
func _mount_signature_count_badge() -> void:
	if _hud_layer == null:
		return
	# Clear any stale badge from a previous reload (defense — _hud_layer is
	# a fresh CanvasLayer per scene instance, but reload paths may differ).
	var stale: Node = _hud_layer.get_node_or_null("SignatureBadge")
	if stale != null:
		stale.queue_free()
	var active_count: int = ScenarioRunner.get_active_signature_count()
	var total_count: int = ScenarioRunner.get_total_signature_count()
	if total_count <= 0 or active_count <= 0:
		return
	var badge: Label = Label.new()
	badge.name = "SignatureBadge"
	badge.text = "✦ %d/%d 시그니처" % [active_count, total_count]
	badge.add_theme_color_override("font_color", Palette.GEUM_SAEK)       # 금색 — signature badge
	badge.add_theme_color_override("font_outline_color", Palette.MUK_OUTLINE)
	badge.add_theme_constant_override("outline_size", 5)
	badge.add_theme_font_size_override("font_size", 18)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor top-right with a small inset so it doesn't overlap the corner.
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	badge.offset_right = -16.0
	badge.offset_top = 12.0
	badge.offset_left = -220.0
	badge.offset_bottom = 40.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_layer.add_child(badge)
	# B1.2 — cascade 합류 챕터 (위연 ch14 / 방통 ch17 / 관우 ch21 / 장비 ch22 /
	# 유비 ch23) 진입 시 badge 가 "방금 N+1/5 으로 증가" 시점에 강조 pulse.
	# `_collect_pre_battle_beats` 가 consume 시 _pulse_signature_badge_next_mount
	# 을 true 로 set — 헬퍼에서 await 한 프레임 후 layout 안정된 badge.size 로
	# pivot 보정 + 다중 채널 (scale + color + outline) pulse. S68 race + S69
	# 가시성 polish 결합 (사용자 attestation: "subtle 의도가 plays-too-quiet").
	if _pulse_signature_badge_next_mount:
		_pulse_signature_badge_next_mount = false
		_trigger_signature_badge_pulse(badge)


## B1.2 pulse 헬퍼 — `_mount_signature_count_badge` 에서 분리. mount 직후엔
## badge.size 가 (0, 0) (layout 아직 propagate 안 됨) — await 한 프레임 후
## pivot 계산 → scale 1.0 → 1.5 → 1.0 + font_color GEUM_SAEK → UI_GOLD →
## GEUM_SAEK + outline_size 5 → 10 → 5 동시 진행. 총 ~0.90s. G-31: tween 은
## SceneTree 바인딩 (BattleScene PROCESS_MODE_DISABLED 우회).
func _trigger_signature_badge_pulse(badge: Label) -> void:
	await get_tree().process_frame
	if not is_instance_valid(badge):
		return
	badge.pivot_offset = badge.size * 0.5
	var pulse: Tween = get_tree().create_tween().set_parallel(true)
	# Scale: 1.0 → 1.5 (0.20s ease-out) → 1.0 (0.70s ease-in).
	pulse.tween_property(badge, "scale", Vector2(1.5, 1.5), 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pulse.tween_property(badge, "scale", Vector2.ONE, 0.70) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN) \
		.set_delay(0.20)
	# Color flash: GEUM_SAEK → UI_GOLD (soft warm) → GEUM_SAEK.
	pulse.tween_method(
		func(c: Color) -> void:
			if is_instance_valid(badge):
				badge.add_theme_color_override("font_color", c),
		Palette.GEUM_SAEK, Palette.UI_GOLD, 0.20)
	pulse.tween_method(
		func(c: Color) -> void:
			if is_instance_valid(badge):
				badge.add_theme_color_override("font_color", c),
		Palette.UI_GOLD, Palette.GEUM_SAEK, 0.70).set_delay(0.20)
	# Outline thickness: 5 → 10 → 5 (시각 무게감 증폭).
	pulse.tween_method(
		func(s: float) -> void:
			if is_instance_valid(badge):
				badge.add_theme_constant_override("outline_size", int(s)),
		5.0, 10.0, 0.20)
	pulse.tween_method(
		func(s: float) -> void:
			if is_instance_valid(badge):
				badge.add_theme_constant_override("outline_size", int(s)),
		10.0, 5.0, 0.70).set_delay(0.20)


## Resolves the final-chapter ending screen content (title + body) from the
## final chapter's ending_screen_text_keys map indexed by the last resolved
## branch_path_id. Returns empty {} when no per-branch entry exists — caller
## falls back to its hardcoded generic strings.
func _resolve_ending_screen_content() -> Dictionary:
	var final_chapter: ChapterDefinition = ScenarioRunner.get_final_chapter()
	if final_chapter == null:
		return {}
	if final_chapter.ending_screen_text_keys.is_empty():
		return {}
	var last_outcome: Dictionary = ScenarioRunner.get_last_chapter_outcome()
	var branch_path_id: String = last_outcome.get("branch_path_id", "") as String
	if branch_path_id.is_empty():
		return {}
	if not final_chapter.ending_screen_text_keys.has(branch_path_id):
		return {}
	var text_key: String = final_chapter.ending_screen_text_keys[branch_path_id] as String
	if text_key.is_empty():
		return {}
	return _beat_content(text_key)


## Mid-/post-battle keyboard polling. Polling sidesteps InputRouter (autoload),
## which binds Esc to move_cancel and consumes events before BattleScene's
## _unhandled_input would see them. ESC opens the pause menu in both phases;
## Enter/R/Space drive the primary post-battle action when _battle_resolved.
var _process_tick: int = 0
## BattleOutcome.Result of the just-finished battle (-1 until battle_outcome_resolved).
var _pending_outcome: int = -1
## Edge-detect latch for the ESC pause-toggle.
var _esc_was_held: bool = false
## Edge-detect latch for the H help-toggle.
var _h_was_held: bool = false
## Session-52 — edge-detect latch for right-click cancel. Mirrors ESC's
## polling-based bypass when InputRouter's event-driven cancel isn't
## reaching the controller (user-reported S51 windowed regression).
var _rclick_was_held: bool = false
## Session-53 — separate edge-detect latches owned by the ALWAYS-mode
## polling helper (line 1700-ish). BattleScene's own _process runs in
## PROCESS_MODE_INHERIT (gets DISABLED when SceneManager treats this scene
## as the overworld), so its ESC/RMB polling above doesn't fire mid-battle.
## The helper polls on these latches instead and they're independent so
## both poll paths can coexist without consuming each other's edge events.
var _esc_was_held_always: bool = false
var _rclick_was_held_always: bool = false

func _process(_delta: float) -> void:
	# ESC opens the pause menu mid- AND post-battle. Edge-detected so a held key
	# doesn't spawn-and-close the menu every frame.
	#
	# Session-51 — ESC routing fixed. Pre-S51 this handler ALWAYS opened the
	# pause menu on ESC, intercepting the key before InputRouter could route
	# it to move_cancel / attack_cancel (per default_bindings.json:
	# 4194305 → cancel). User report: "선택 취소는 안 되" — ESC was meant
	# per the controls hint to cancel a selection, but pause menu opened
	# instead. Post-S51: when a unit is selected, defer ESC entirely to
	# InputRouter (the polling poll just skips, no consumption — InputRouter
	# receives the event via the normal _unhandled_input path). When nothing
	# is selected (true OBSERVATION state), ESC keeps its pause-menu role.
	var esc_held: bool = (
		Input.is_physical_key_pressed(KEY_ESCAPE)
		or Input.is_key_pressed(KEY_ESCAPE)
	)
	if esc_held and not _esc_was_held:
		_handle_cancel_or_pause()
	_esc_was_held = esc_held

	# Session-52 — right-click polling for selection cancel / move undo.
	# Mirrors the ESC polling path; bypasses InputRouter (whose event-driven
	# cancel isn't reaching the controller in windowed runs per user report).
	var rclick_held: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if rclick_held and not _rclick_was_held:
		_handle_cancel_or_pause()
	_rclick_was_held = rclick_held

	# H opens the help overlay. Distinct from pause — does NOT freeze the tree;
	# the player can read while AI-turn animations keep playing in the background.
	var h_held: bool = (
		Input.is_physical_key_pressed(KEY_H)
		or Input.is_key_pressed(KEY_H)
	)
	if h_held and not _h_was_held:
		_toggle_help_overlay()
	_h_was_held = h_held

	if not _battle_resolved:
		return
	_process_tick += 1
	if _process_tick % 60 == 1:
		# Once per second while waiting for input — confirms _process is firing.
		_trace("[POST-BATTLE-WAIT] _process firing; ENTER=%s R=%s SPACE=%s ESC=%s" %
			[Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER),
			Input.is_physical_key_pressed(KEY_R),
			Input.is_physical_key_pressed(KEY_SPACE),
			Input.is_physical_key_pressed(KEY_ESCAPE)])
	if (Input.is_physical_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_ENTER)
			or Input.is_physical_key_pressed(KEY_KP_ENTER)
			or Input.is_physical_key_pressed(KEY_R) or Input.is_key_pressed(KEY_R)
			or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SPACE)):
		_trace("[BATTLE-END] forward key pressed — invoking primary post-battle action")
		_battle_resolved = false  # gate further key handling until the next battle
		set_process(false)
		_invoke_primary_post_battle_action()


## Session-52 / S54 — cancel priority dispatcher shared by ESC + right-click
## polling. Priority order (영걸전식 undo-friendly):
##   1) If the ACTIVE TURN unit has MOVEd this turn (no ATTACK yet) → undo
##      the move, restore position, re-select. Checked against active turn
##      unit_id (NOT selection state) per S54 — user-reported regression
##      where ESC opened pause-menu post-move because selection had been
##      cleared somewhere between the move commit and the ESC press.
##      Only the active turn unit can have a cached move anyway (others
##      can't act on someone else's turn), so this matches "find the unit
##      that just moved" semantics without depending on selection sync.
##   2) Else if a unit is selected → cancel the selection (clear movable
##      preview, return to OBSERVATION).
##   3) Else → open the pause menu (the original ESC behaviour pre-S52).
## InputRouter._state is synced to OBSERVATION after the cancel-selection
## path so its FSM stays consistent with the controller.
func _handle_cancel_or_pause() -> void:
	if _grid_controller == null:
		_open_pause_menu()
		return
	# Step 1 — try move-undo via the active turn unit (selection-independent).
	var active_unit_id: int = -1
	if _grid_controller.has_method("get_active_turn_unit_id"):
		active_unit_id = _grid_controller.get_active_turn_unit_id()
	if active_unit_id != -1 and _grid_controller.has_method("cancel_last_move"):
		if _grid_controller.cancel_last_move(active_unit_id):
			return
	# Step 2 — cancel selection if any.
	var selected_unit_id: int = -1
	if _grid_controller.has_method("get_selected_unit_id"):
		selected_unit_id = _grid_controller.get_selected_unit_id()
	if selected_unit_id != -1 and _grid_controller.has_method("cancel_selection"):
		_grid_controller.cancel_selection()
		if _input_router != null and "_state" in _input_router:
			_input_router._state = 0  # InputState.OBSERVATION
		return
	# Step 3 — nothing to undo, nothing selected → pause menu.
	_open_pause_menu()


## Mounts a PauseMenu on the HUD layer (idempotent — does nothing if already
## mounted) and pauses the tree. Used by the ESC poll above. The pause menu
## owns its own resume / main-menu / quit handlers.
func _open_pause_menu() -> void:
	if _hud_layer == null:
		return
	if _hud_layer.get_node_or_null("PauseMenu") != null:
		return  # already paused — let the menu handle its own close
	var menu: PauseMenu = PauseMenu.new()
	menu.name = "PauseMenu"
	menu.resume_requested.connect(_on_pause_menu_resumed)
	_hud_layer.add_child(menu)
	menu.show_paused()


func _on_pause_menu_resumed() -> void:
	var menu: Node = _hud_layer.get_node_or_null("PauseMenu") if _hud_layer != null else null
	if menu != null:
		menu.queue_free()


## Toggles the HelpOverlay on the HUD layer. Mid- AND post-battle. Unlike
## the pause menu this does NOT freeze the tree — the player can read the
## reference card while the AI keeps acting. Same edge-detection pattern as
## PauseMenu so a single H tap toggles cleanly without flicker.
func _toggle_help_overlay() -> void:
	if _hud_layer == null:
		return
	var existing: Node = _hud_layer.get_node_or_null("HelpOverlay")
	if existing != null:
		# Already shown — let the overlay's own close handler tear it down so
		# its close_requested signal still fires (keeps the flow symmetric).
		if existing.has_method("_on_close_pressed"):
			existing._on_close_pressed()
		return
	var overlay: HelpOverlay = HelpOverlay.new()
	overlay.name = "HelpOverlay"
	overlay.close_requested.connect(_on_help_overlay_closed)
	_hud_layer.add_child(overlay)
	overlay.show_help()


func _on_help_overlay_closed() -> void:
	var overlay: Node = _hud_layer.get_node_or_null("HelpOverlay") if _hud_layer != null else null
	if overlay != null:
		overlay.queue_free()


## Runs the same action as the focused post-battle button: on WIN that's
## _proceed_scenario; on DRAW/LOSS that's _retry_chapter.
func _invoke_primary_post_battle_action() -> void:
	if _pending_outcome == BattleOutcome.Result.WIN:
		_proceed_scenario()
	else:
		_retry_chapter()


## Turn-indicator handler. Lazy-creates the indicator on first call and
## reparents it under the active unit's polygon on every subsequent emit.
## ChapterVisuals may not be mounted yet on the first emit (async load) — in
## that case the call is a graceful no-op; the next emit will land it.
func _on_active_unit_changed(unit_id: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	# Tile-level active-turn highlight — bright gold border so the active unit
	# is visible even at zoomed-out scales where the chevron is too small to spot.
	var unit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
	if unit != null and visuals.has_method("set_active_turn_coord"):
		visuals.set_active_turn_coord(unit.position)
	var polygon: Node2D = _find_unit_polygon(visuals, unit_id)
	# Audio cue split by side:
	#   - player turn  → SFX_TURN chirp (E5)
	#   - enemy turn   → SFX_TURN_ENEMY chirp (E4 — one octave lower)
	# Camera focus pan on enemy turn was reverted (2026-05-20 attestation —
	# the rapid pans between consecutive enemy turns read as 산만함 rather than
	# as anticipation cue). Tile highlight + chevron + chirp + 0.35s thinking
	# pause (grid_battle_controller.AI_THINKING_PAUSE_SEC) carry the "who is
	# acting" signal without camera movement.
	if unit != null and unit.is_player_controlled:
		SoundManager.play(SoundManager.SFX_TURN)
	elif unit != null:
		SoundManager.play(SoundManager.SFX_TURN_ENEMY)
	if polygon == null:
		return
	if not is_instance_valid(_turn_indicator):
		_turn_indicator = TurnIndicator.new()
		_turn_indicator.name = "TurnIndicator"
	if _turn_indicator.get_parent() == polygon:
		return
	if _turn_indicator.get_parent() != null:
		_turn_indicator.get_parent().remove_child(_turn_indicator)
	polygon.add_child(_turn_indicator)
	# Counter the polygon's facing rotation so the chevron always points down
	# regardless of which direction the unit is facing.
	_turn_indicator.rotation = -polygon.rotation


## End-of-turn dim cue. Fired by GridBattleController as a re-emit of
## GameBus.unit_turn_ended. Skips passes (acted=false) so units that just
## advance without action keep full brightness, and skips dead units whose
## death-fade tween owns modulate.a — running this on a corpse would lift
## alpha back up mid-fade.
func _on_unit_turn_ended_visual(unit_id: int, acted: bool) -> void:
	# ADR-0022 civilian visualization refresh — pickup/save state may have
	# changed inside controller._on_unit_turn_ended (which runs BEFORE this
	# visual re-emit). Fires regardless of `acted` because civilian hooks run
	# on any turn-end (carrier ending turn in evacuate-zone still triggers a
	# SAVED transition even if the player didn't spend an action this turn).
	if _civilian_visuals != null and is_instance_valid(_civilian_visuals):
		_civilian_visuals.refresh()
	if not acted:
		return
	if _hp_controller != null and not _hp_controller.is_alive(unit_id):
		return
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var polygon: Node2D = _find_unit_polygon(visuals, unit_id)
	if polygon == null:
		return
	var target: Color = Color(1.0, 1.0, 1.0, END_OF_TURN_DIM_ALPHA)
	# Instant-set so the dim shows even when Tween writes don't advance.
	polygon.modulate = target


## Round-rollover undim. Iterates every spawned unit polygon under PlayerUnits
## and EnemyUnits and tweens modulate back to WHITE. Skips invisible polygons
## (dead units snap-hidden by _on_unit_died_visual) so a corpse doesn't get
## its alpha briefly lifted before staying invisible.
func _on_round_started_visual(round_num: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	# S72 Hero banter — battle_start event fires on round 1 only (per-battle
	# climax). Later rounds run round-start visual cleanup only.
	# S18 — also fires enemy roster battle_start 2.0s after player roster
	# starts (~post player stagger window for 4-hero rosters) so enemy voices
	# land cleanly after the player commander's opening line.
	if round_num == 1:
		_fire_player_roster_banter("battle_start")
		_fire_enemy_roster_banter("battle_start", 2.0)
	for parent_name: String in ["PlayerUnits", "EnemyUnits"]:
		var parent: Node = visuals.get_node_or_null(parent_name)
		if parent == null:
			continue
		for child: Node in parent.get_children():
			if not (child is Node2D):
				continue
			var poly: Node2D = child as Node2D
			if not poly.visible:
				continue
			# Instant-set so units brighten back to full alpha at round start
			# even if Tween writes don't advance.
			poly.modulate = Color.WHITE
			# Session-13: clear any defend stance badge — the new round means
			# every unit's stance was consumed (or not used) and starts fresh.
			var badge: Node = poly.get_node_or_null("DefendBadge")
			if badge != null:
				badge.queue_free()
			# Session-16: status badges (poison / slow) are TURN-BASED — they
			# tick down via HPStatusController._apply_turn_start_tick. The
			# visual badge is shown per-application; we leave it on the polygon
			# until the unit's NEXT turn start (where tick removes the effect).
			# For simplicity v1: clear all status badges at round start. The
			# next turn's apply_turn_start_tick will re-fire signals if the
			# effect persists (a TODO — for now badge accuracy is "applied
			# this round" which is close enough).
			for badge_name: String in ["PoisonBadge", "SlowBadge", "StunBadge"]:
				var status_badge: Node = poly.get_node_or_null(badge_name)
				if status_badge != null:
					status_badge.queue_free()
			# Session-19: tactical_read FacingArrow is selection-scoped, not
			# round-scoped — selection change clears it. But if a round starts
			# while a STRATEGIST is selected, the arrows should refresh based on
			# fresh facing state. Easiest: clear them and let next selection
			# re-attach via _on_unit_selected_changed (the next turn-start fires
			# unit_turn_started which deselects, then re-selects active unit).
			var facing_arrow: Node = poly.get_node_or_null("FacingArrow")
			if facing_arrow != null:
				facing_arrow.queue_free()


## Session-13 — defend stance applied. Adds a small "방" Label to the unit's
## polygon so the player can see at a glance that the unit will take 50% less
## damage on the next incoming attack. Removed at round_started_visual.
func _on_unit_defend_stance_applied(unit_id: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var poly: Node2D = _find_unit_polygon(visuals, unit_id)
	if poly == null:
		return
	# Idempotent — if the badge is already there (e.g., AI defends twice in a
	# round somehow), don't stack duplicates.
	if poly.get_node_or_null("DefendBadge") != null:
		return
	var badge: Label = Label.new()
	badge.name = "DefendBadge"
	badge.text = "방"
	# High-contrast on the faction fill — gold border with white inner.
	badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78, 1.0))
	badge.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1.0))
	badge.add_theme_constant_override("outline_size", 6)
	badge.add_theme_font_size_override("font_size", 18)
	# Counter polygon facing rotation so the glyph stays upright.
	badge.rotation = -poly.rotation
	# Top-right corner of the polygon (positive X, negative Y in local coords).
	badge.position = Vector2(18, -34)
	badge.size = Vector2(20, 20)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	poly.add_child(badge)


## Session-16: status effect (poison / slow) badge. Adds a colored "독" or "슬"
## Label to the affected unit's polygon mirroring the 방 defend_stance badge.
## Different badge_name + position per effect_id so multiple statuses stack
## visually without overlapping. Cleared at round_started_visual (TURN-BASED
## effects re-emit if they persist via apply_turn_start_tick).
## S91+ Phase B step 9 — UI-GB-17 Item Target Selection Overlay router.
## Forwards the controller signal to ChapterVisuals' per-tile draw block.
## Empty tile array + empty palette = clear overlay (caller pattern, mirrors
## the existing set_movable_tiles(empty) clear convention).
func _on_item_target_selection_updated(tiles: PackedVector2Array, palette: StringName) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	if visuals.has_method("set_item_target_tiles"):
		visuals.set_item_target_tiles(tiles, palette)


## S91+ Phase B step 9 follow-up — UI-GB-16 per-polygon Active Buff Indicator.
## Mirrors _on_unit_defend_stance_applied / _on_unit_status_applied pattern:
## add/remove a named child Label ("BuffBadge") on the unit's polygon when the
## controller signals a pending_buff transition. Idempotent — multiple
## emissions for the same unit don't stack duplicate badges. Glyph: ▶ chevron
## (matches the HUD-level UI-GB-16 scene), upper-right corner of the polygon
## (status seals own upper-left per §2.8, so upper-right is the open slot).
##
## Position: Vector2(18, -34) matches the DefendBadge top-right slot in
## _on_unit_defend_stance_applied. Counter-rotates polygon rotation so the
## glyph stays upright.
func _on_unit_pending_buff_changed(unit_id: int, has_buff: bool) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var poly: Node2D = _find_unit_polygon(visuals, unit_id)
	if poly == null:
		return
	var existing: Node = poly.get_node_or_null("BuffBadge")
	if has_buff:
		if existing != null:
			return  # idempotent — badge already shown
		var badge: Label = Label.new()
		badge.name = "BuffBadge"
		badge.text = "▶"
		# High-contrast on the faction fill — gold border with white inner,
		# same palette family as DefendBadge for HUD vocabulary consistency.
		badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78, 1.0))
		badge.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1.0))
		badge.add_theme_constant_override("outline_size", 6)
		badge.add_theme_font_size_override("font_size", 16)
		# Counter polygon facing rotation so the glyph stays upright.
		badge.rotation = -poly.rotation
		# Upper-right corner — DefendBadge owns Vector2(18, -34); buff badge
		# offsets slightly inward to allow co-existence on the same polygon
		# (a unit could be both defending AND carrying a buff after move).
		badge.position = Vector2(18, -18)
		badge.size = Vector2(16, 16)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		poly.add_child(badge)
	else:
		if existing != null:
			existing.queue_free()


## S97 — ENEMY-disrupt DebuffBadge (intimidate_scroll). Mirrors
## _on_unit_pending_buff_changed but renders a RED ▼ "DebuffBadge" so an
## intimidated enemy reads as weakened (the gold ▶ BuffBadge would misread as
## "stronger"). Upper-right slot offset slightly below the buff badge so a unit
## carrying both (rare cross-side edge) keeps them distinguishable.
func _on_unit_pending_debuff_changed(unit_id: int, has_debuff: bool) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var poly: Node2D = _find_unit_polygon(visuals, unit_id)
	if poly == null:
		return
	var existing: Node = poly.get_node_or_null("DebuffBadge")
	if has_debuff:
		if existing != null:
			return  # idempotent — badge already shown
		var badge: Label = Label.new()
		badge.name = "DebuffBadge"
		badge.text = "▼"
		# Red glyph with dark outline — danger/weakened vocabulary, distinct from
		# the gold BuffBadge.
		badge.add_theme_color_override("font_color", Color(0.92, 0.30, 0.26, 1.0))
		badge.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1.0))
		badge.add_theme_constant_override("outline_size", 6)
		badge.add_theme_font_size_override("font_size", 16)
		badge.rotation = -poly.rotation
		badge.position = Vector2(18, 0)  # below BuffBadge (-18) / DefendBadge (-34)
		badge.size = Vector2(16, 16)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		poly.add_child(badge)
	else:
		if existing != null:
			existing.queue_free()


func _on_unit_status_applied(unit_id: int, effect_id: StringName) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var poly: Node2D = _find_unit_polygon(visuals, unit_id)
	if poly == null:
		return
	var badge_name: String = ""
	var glyph: String = ""
	var glyph_color: Color = Color(1.0, 0.95, 0.78, 1.0)
	var pos_offset: Vector2 = Vector2(0, 0)
	match effect_id:
		&"poison":
			badge_name = "PoisonBadge"
			glyph = "독"
			glyph_color = Color(0.55, 0.95, 0.45, 1.0)  # poison green
			pos_offset = Vector2(-32, -34)              # top-left
		&"slow":
			badge_name = "SlowBadge"
			glyph = "슬"
			glyph_color = Color(0.78, 0.62, 0.95, 1.0)  # slow purple
			pos_offset = Vector2(-32, -18)              # below poison slot
		&"stun":
			# Session-17 — 주유 책략 (STUN). Red glyph, third slot below SLOW.
			badge_name = "StunBadge"
			glyph = "기"
			glyph_color = Color(0.96, 0.40, 0.30, 1.0)  # stun red
			pos_offset = Vector2(-32, -2)               # below slow slot
		_:
			return  # unknown status — no badge for v1
	# Idempotent — don't stack duplicates on re-apply.
	if poly.get_node_or_null(badge_name) != null:
		return
	var badge: Label = Label.new()
	badge.name = badge_name
	badge.text = glyph
	badge.add_theme_color_override("font_color", glyph_color)
	badge.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1.0))
	badge.add_theme_constant_override("outline_size", 6)
	badge.add_theme_font_size_override("font_size", 18)
	badge.rotation = -poly.rotation
	badge.position = pos_offset
	badge.size = Vector2(20, 20)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	poly.add_child(badge)


## Session-16/20: hero active skill fired. Dispatches three feedback channels:
##   1. Per-skill SFX cue (SFX_SKILL_<NAME>) so each skill sounds distinct.
##   2. SkillPopup at caster position showing the skill's Korean name in the
##      caster's accent color — mirror of CriticalPopup / KillPopup pattern.
##   3. Camera shake intensity scaled to skill type (offensive = strong,
##      utility = none) so the screen kicks for thunder_roar / strategist
##      but stays still for the buff/aura skills.
## View-only — damage application is handled separately via _on_damage_applied
## for the damage-dealing skills (thunder_roar / piercing_volley / strategist).
func _on_unit_skill_used(unit_id: int, skill_id: StringName) -> void:
	# Lift caster lookup ahead of SFX so we can side-bias volume (session-32).
	var caster: BattleUnit = _grid_controller.get_battle_unit(unit_id) if _grid_controller != null else null
	# (1) Per-skill SFX
	# Session-32 — AI-side skill activations play -4dB quieter than player-
	# side so the audio communicates "their skill, not mine". Cue still
	# audible — not a hidden event — just dropped slightly in the mix.
	if SoundManager != null and SoundManager.has_method("play"):
		var sfx_volume_offset: float = -4.0 if (caster != null and caster.side != 0) else 0.0
		SoundManager.play(_sfx_for_skill(skill_id), sfx_volume_offset)
	# (2) Caster position + accent → SkillPopup
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var caster_node: Node2D = _find_unit_polygon(visuals, unit_id)
	if caster_node == null:
		return
	if caster == null:
		return
	var display_name: String = _skill_display_name(skill_id)
	var accent: Color = Color(1.00, 0.85, 0.32)  # default warm gold
	if visuals.has_method("_get_hero_accent"):
		accent = visuals._get_hero_accent(caster.hero_id, caster.side)
	var popup: SkillPopup = SkillPopup.make(display_name, accent)
	popup.position = caster_node.position + Vector2(0.0, -8.0)
	visuals.add_child(popup)
	# (2b) Per-skill particle effect — caster-centered procedural flourish.
	# Session-87 — dragon_blade is the first wired candidate; further skills
	# will get their own _kind branches as they're authored. Returns null for
	# unwired skill_ids so the rest of the visual stack remains intact.
	var particle: SkillParticleEffect = _make_skill_particle(skill_id, accent)
	if particle != null:
		particle.position = caster_node.position
		visuals.add_child(particle)
	# (3) Camera shake — offensive skills kick the screen; utility skills don't.
	if _battle_camera != null and _battle_camera.has_method("shake"):
		var shake_params: Vector2 = _shake_for_skill(skill_id)
		if shake_params.x > 0.0:
			_battle_camera.shake(shake_params.x, shake_params.y)
	# Phase 3 Step E — Skill activation 드라마. "ultimate" 패턴 — 매 전투 1-2
	# 회. S73 bumped to parity with kill: CRIT ≈ kill ≈ skill (all big-tier
	# now — frequency differentiates: CRIT 빈번 / kill 4-6 / skill 1-2). player
	# side 만 발화 — 적 skill 은 popup + shake 로 충분 (적의 ultimate 가 player
	# 쪽 만족감 줄 이유 없음).
	if caster.side == 0:
		_trigger_skill_activation_drama(accent)


## Session-20 — maps skill_id → SFX constant. Falls back to generic SFX_SKILL
## for unwired skills (defensive; the 7/7 roster is covered but any future
## skill_id additions without a matching SFX_* still play the default cue).
func _sfx_for_skill(skill_id: StringName) -> StringName:
	match skill_id:
		&"skill_dragon_blade":    return SoundManager.SFX_SKILL_DRAGON_BLADE
		&"skill_thunder_roar":    return SoundManager.SFX_SKILL_THUNDER_ROAR
		&"skill_inspire":         return SoundManager.SFX_SKILL_INSPIRE
		&"skill_piercing_volley": return SoundManager.SFX_SKILL_PIERCING_VOLLEY
		&"skill_charm":           return SoundManager.SFX_SKILL_CHARM
		&"skill_strategist":      return SoundManager.SFX_SKILL_STRATEGIST
		&"skill_naval_strategy":  return SoundManager.SFX_SKILL_NAVAL_STRATEGY
		&"skill_rebel_charge":    return SoundManager.SFX_SKILL_DRAGON_BLADE  # 위연 — reuse dragon_blade SFX (offensive sharp); per-skill SFX 차후 별도 작곡
		&"skill_blunt_strategy":  return SoundManager.SFX_SKILL_STRATEGIST    # 방통 — reuse strategist (책략 톤)
		&"skill_phoenix_chick":   return SoundManager.SFX_SKILL_INSPIRE       # 방통 — reuse inspire (warm support 톤)
		_:                        return SoundManager.SFX_SKILL


## Session-20 — Korean display name per skill_id for SkillPopup banner.
## Mirrors help_overlay.gd skill list strings so they stay in sync.
func _skill_display_name(skill_id: StringName) -> String:
	match skill_id:
		&"skill_dragon_blade":    return "청룡언월도!"
		&"skill_thunder_roar":    return "호로후!"
		&"skill_inspire":         return "격려!"
		&"skill_piercing_volley": return "연사!"
		&"skill_charm":           return "매혹!"
		&"skill_strategist":      return "책략!"
		&"skill_naval_strategy":  return "책략!"
		&"skill_rebel_charge":    return "반골일도!"
		&"skill_blunt_strategy":  return "기만전략!"
		&"skill_phoenix_chick":   return "봉추!"
		_:                        return "스킬!"


## Session-20 — camera shake (magnitude, duration) tuple per skill_id.
## Offensive skills (thunder_roar / strategist) match critical-hit intensity
## (8.0 / 0.25). dragon_blade + piercing_volley get a moderate kick (5.0 /
## 0.18) — they hit hard but at one target, not the whole map. Utility
## skills (inspire / charm / naval_strategy) return Vector2.ZERO so no
## shake fires. Vector2.x ≤ 0 disables the shake call site.
func _shake_for_skill(skill_id: StringName) -> Vector2:
	match skill_id:
		&"skill_thunder_roar":    return Vector2(8.0, 0.25)
		&"skill_strategist":      return Vector2(8.0, 0.25)
		&"skill_dragon_blade":    return Vector2(5.0, 0.18)
		&"skill_piercing_volley": return Vector2(5.0, 0.18)
		&"skill_rebel_charge":    return Vector2(6.0, 0.20)  # 위연 — 압축된 충격, between dragon_blade and thunder_roar
		&"skill_blunt_strategy":  return Vector2(5.0, 0.18)  # 방통 — AoE control, moderate (dragon_blade tier)
		_:                        return Vector2.ZERO  # utility / heal — no shake (phoenix_chick included)


## Session-87 — per-skill particle effect factory dispatch. Returns null for
## skill_ids that don't yet have a particle branch (graceful fallback — popup
## + SFX + shake continue to fire). First wired: dragon_blade (관우). Further
## skills (~17 more) land one at a time per the S86 handoff queue.
func _make_skill_particle(skill_id: StringName, accent: Color) -> SkillParticleEffect:
	match skill_id:
		&"skill_dragon_blade":
			return SkillParticleEffect.make_dragon_blade(accent)
		&"skill_thunder_roar":
			return SkillParticleEffect.make_thunder_roar(accent)
		&"skill_fire_strategy":
			return SkillParticleEffect.make_fire_strategy(accent)
		&"skill_lone_lance":
			return SkillParticleEffect.make_lone_lance(accent)
		&"skill_inspire":
			return SkillParticleEffect.make_inspire(accent)
		&"skill_piercing_volley":
			return SkillParticleEffect.make_piercing_volley(accent)
		&"skill_charm":
			return SkillParticleEffect.make_charm(accent)
		&"skill_strategist":
			return SkillParticleEffect.make_strategist(accent)
		&"skill_naval_strategy":
			return SkillParticleEffect.make_naval_strategy(accent)
		&"skill_rebel_charge":
			return SkillParticleEffect.make_rebel_charge(accent)
		&"skill_blunt_strategy":
			return SkillParticleEffect.make_blunt_strategy(accent)
		&"skill_phoenix_chick":
			return SkillParticleEffect.make_phoenix_chick(accent)
		&"skill_xiliang_charge":
			return SkillParticleEffect.make_xiliang_charge(accent)
		&"skill_successor_strategy":
			return SkillParticleEffect.make_successor_strategy(accent)
		_:
			return null


## Session-16: mid-battle kill notification. Spawns "X 처치!" popup at the
## victim's polygon position (captured BEFORE the death-fade tween hides the
## node) + plays SFX_KILL flourish. Killer/victim ids both arrive on the
## signal; only the victim's display name + accent are needed.
func _on_unit_killed_mid_battle(killer_id: int, victim_id: int,
		victim_hero_id: StringName) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var victim_node: Node2D = _find_unit_polygon(visuals, victim_id)
	if victim_node == null:
		return
	# Resolve display name + accent color (uses chapter_visuals' authoritative
	# accent dict so it stays in sync with the unit polygon's border color).
	var display_name: String = String(victim_hero_id)
	var hero: HeroData = HeroDatabase.get_hero(victim_hero_id)
	if hero != null and hero.name_ko != "":
		display_name = hero.name_ko
	var accent: Color = Color(0.96, 0.86, 0.42, 1.0)  # default warm gold
	if visuals.has_method("_get_hero_accent"):
		# Visualss internal helper — public-ish per chapter_visuals docstring.
		accent = visuals._get_hero_accent(victim_hero_id, 1)  # side=1 fallback
	# SFX cue.
	if SoundManager != null and SoundManager.has_method("play"):
		SoundManager.play(SoundManager.SFX_KILL)
	# Popup at victim position.
	var popup: KillPopup = KillPopup.make(display_name, accent)
	popup.position = victim_node.position + Vector2(0.0, -16.0)
	visuals.add_child(popup)
	# Phase 3 Step D — Killing blow drama. side 별로 결이 다른 모먼트:
	#   player kills enemy → 만족 (subtle hit-stop + zoom + white tint)
	#   enemy kills player → 상실 (slow pause + screen darken)
	# CRIT (1-2 회/전투) 보다 빈도 높음 (4-6 kills/전투) — 강도 낮춰 inflation 회피.
	if _grid_controller != null:
		var killer_unit: BattleUnit = _grid_controller.get_battle_unit(killer_id)
		if killer_unit != null:
			if killer_unit.side == 0:
				_trigger_player_kill_drama()
				_spawn_banter(killer_id, "player_kill")
			elif killer_unit.side == 1:
				_trigger_enemy_kill_drama()


## Session-16: critical-hit (REAR-direction) feedback. Spawns the "치명타!"
## popup at the defender's position + triggers camera shake + plays SFX.
## Receives the same defender_id the damage_applied handler does; uses the
## defender's polygon position so the popup tracks late-game repositioning.
func _on_critical_hit_landed(_attacker_id: int, defender_id: int, damage: int,
		_angle: StringName, chain_level: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var defender_node: Node2D = _find_unit_polygon(visuals, defender_id)
	if defender_node == null:
		return
	# S72 Critical chain — stronger shake at higher chain (chain 1 = baseline,
	# chain 2 = 1.25× shake, chain 3+ = 1.5× shake) so momentum reads kinetically.
	if _battle_camera != null and _battle_camera.has_method("shake"):
		var shake_scale: float = 1.0
		if chain_level == 2:
			shake_scale = 1.25
		elif chain_level >= 3:
			shake_scale = 1.50
		_battle_camera.shake(8.0 * shake_scale, 0.25)
	# SFX cue.
	if SoundManager != null and SoundManager.has_method("play"):
		SoundManager.play(SoundManager.SFX_CRITICAL)
	# "치명타!" popup above the defender. Offset slightly above the standard
	# DamagePopup. Chain level ≥ 2 → "치명타 ×N!" badge variant.
	var popup: CriticalPopup = CriticalPopup.make(damage, chain_level)
	popup.position = defender_node.position
	visuals.add_child(popup)
	# Phase 3 Step A — CRIT 모먼트 클라이맥스 (XCOM 류 dramatic punctuation).
	# 3 채널: (1) hit-stop 0.25s — Engine.time_scale 0.4, freeze-frame 효과.
	# (2) camera zoom punch — 1.0 → 1.10 → 1.0 over 0.30s. (3) red tint flash
	# overlay — JU_HONG 0.18 alpha → 0 over 0.40s. 1 전투 당 1~2회 발화 빈도
	# 라 inflation 없음.
	_trigger_critical_climax()


## Phase 3 Step B helper. Player unit 이 25% 경계선 cross 시 1회용 위급 cue.
## (1) "위급!" 라벨 1초 위에 spawn (CriticalPopup 스타일 mirror 가능),
## (2) JU_HONG color flash on unit polygon, (3) SFX_HIT lower-pitch 변형 또는
## 기존 SFX 재사용. 간단함 우선 — Label 직접 + JU_HONG modulate flash.
func _trigger_low_hp_danger(unit_node: Node2D) -> void:
	if not is_instance_valid(unit_node):
		return
	# Label "위급!" — JU_HONG 색, 1.0s dwell (long enough to read).
	# mouse_filter IGNORE 필수 — unit polygon 위 spawn 이라 default STOP 이면
	# 0.9s 동안 polygon 근처 grid click 흡수 (사용자 attestation: "장비 이동
	# 클릭이 안 먹고 빈 자리가 선택됨" 버그의 원인).
	var label: Label = Label.new()
	label.text = "위급!"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Palette.JU_HONG)
	label.add_theme_color_override("font_outline_color", Palette.MUK_OUTLINE)
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(-30, -52)  # 상단 hp bar 위
	unit_node.add_child(label)
	# Drift up + fade out, G-31 tree-bound tween.
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 14.0, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
	# Audio cue — reuse SFX_HIT but with negative pitch offset for "low rumble".
	if SoundManager != null and SoundManager.has_method("play"):
		SoundManager.play(SoundManager.SFX_HIT, -3.0)  # 3 semitones lower


## Phase 3 Step F — Battle outcome WIN 환희 모먼트. UI_GOLD 화면 wash + camera
## slow zoom-out (1.0 → 0.92 over 0.6s → 복귀 0.8s). hit-stop 없음 (이미
## OutcomeBanner 가 정지된 화면이라 freeze 가 redundant). UI_GOLD 선택 —
## art-bible §1 의 GEUM_SAEK reservation 회피 (legendary 가 아닌 일반 승리는
## tactical-UI gold tone).
func _trigger_outcome_victory_drama() -> void:
	if _battle_camera != null:
		var orig_zoom: Vector2 = _battle_camera.zoom
		var zoom_tween: Tween = get_tree().create_tween()
		zoom_tween.tween_property(_battle_camera, "zoom", orig_zoom * 0.92, 0.60) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		zoom_tween.tween_property(_battle_camera, "zoom", orig_zoom, 0.80) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _hud_layer != null:
		var flash: ColorRect = ColorRect.new()
		flash.name = "OutcomeVictoryFlash"
		flash.color = Color(Palette.UI_GOLD.r, Palette.UI_GOLD.g, Palette.UI_GOLD.b, 0.20)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_layer.add_child(flash)
		var flash_tween: Tween = get_tree().create_tween()
		flash_tween.tween_property(flash, "color:a", 0.0, 1.00) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		flash_tween.tween_callback(flash.queue_free)


## Phase 3 Step F — Battle outcome LOSS 상실 모먼트. MUK 화면 darken 깊고
## 길게 (kill drama 의 0.22α/0.55s → 0.32α/1.20s — 더 무거움). 카메라 zoom
## 없음 (관조). Engine.time_scale 도 안 건드림 (banner UI 응답성 보호).
func _trigger_outcome_defeat_drama() -> void:
	if _hud_layer != null:
		var darken: ColorRect = ColorRect.new()
		darken.name = "OutcomeDefeatDarken"
		darken.color = Color(Palette.MUK.r, Palette.MUK.g, Palette.MUK.b, 0.32)
		darken.set_anchors_preset(Control.PRESET_FULL_RECT)
		darken.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_layer.add_child(darken)
		var darken_tween: Tween = get_tree().create_tween()
		darken_tween.tween_property(darken, "color:a", 0.0, 1.20) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		darken_tween.tween_callback(darken.queue_free)


## Phase 3 Step E — Player skill activation 드라마. CRIT 와 kill 중간 강도:
## hit-stop 0.12s (CRIT 0.20 > skill 0.12 > kill 0.10), zoom 1.07× (CRIT 1.10
## > skill 1.07 > kill 1.05), accent tint flash (hero 컬러로 — 차별화 + 시
## 그니처 강조).
##
## accent: hero 별 색상 (chapter_visuals 가 dispatching). 매 전투 1-2회 발화
## 라 inflation 우려 없음 — kill drama 와 같은 진폭 family.
func _trigger_skill_activation_drama(accent: Color) -> void:
	# S73 ↑ — skill drama was weakest in the Phase 3 family (S71 attestation
	# "특별한 느낌 없다" residual). Bumped to parity with S72 player_kill drama
	# (0.4 time_scale / 0.16s hit-stop / 1.10× zoom / 0.08+0.20 zoom timings).
	# Accent flash alpha bumped 0.14 → 0.24 (vs kill 0.20 JI_BAEK) — colored
	# accent reads softer than near-white so +0.04 α to compensate. Fade 0.32
	# → 0.42s (longer afterglow — skill is "ultimate" rarer than kill so the
	# moment lingers). Family ranking post-S73: CRIT ≈ kill ≈ skill (all big).
	Engine.time_scale = 0.4
	get_tree().create_timer(0.16, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0
	)
	if _battle_camera != null:
		var orig_zoom: Vector2 = _battle_camera.zoom
		var zoom_tween: Tween = get_tree().create_tween()
		zoom_tween.tween_property(_battle_camera, "zoom", orig_zoom * 1.10, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		zoom_tween.tween_property(_battle_camera, "zoom", orig_zoom, 0.20) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _hud_layer != null:
		var flash: ColorRect = ColorRect.new()
		flash.name = "SkillAccentFlash"
		flash.color = Color(accent.r, accent.g, accent.b, 0.24)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_layer.add_child(flash)
		var flash_tween: Tween = get_tree().create_tween()
		flash_tween.tween_property(flash, "color:a", 0.0, 0.42) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		flash_tween.tween_callback(flash.queue_free)


## Phase 3 Step D — Player kills enemy 만족 모먼트. CRIT 동등 강도 (S72 ↑):
## hit-stop 0.16s real-time (CRIT 0.20s 의 80% — 만족 결 위해 약간 짧게),
## zoom 1.10× (CRIT 일치 — 만족 punch 의 핵심), 화이트 tint flash (JI_BAEK
## 0.20α — JI_BAEK 가 JU_HONG 보다 시각 약하므로 보정). 한 전투 4-6회 발화
## 가 가장 빈번한 family — S71 attestation "특별한 느낌 없다" 대응 ↑.
func _trigger_player_kill_drama() -> void:
	Engine.time_scale = 0.4
	get_tree().create_timer(0.16, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0
	)
	if _battle_camera != null:
		var orig_zoom: Vector2 = _battle_camera.zoom
		var zoom_tween: Tween = get_tree().create_tween()
		zoom_tween.tween_property(_battle_camera, "zoom", orig_zoom * 1.10, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		zoom_tween.tween_property(_battle_camera, "zoom", orig_zoom, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _hud_layer != null:
		var flash: ColorRect = ColorRect.new()
		flash.name = "PlayerKillFlash"
		flash.color = Color(Palette.JI_BAEK.r, Palette.JI_BAEK.g, Palette.JI_BAEK.b, 0.20)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_layer.add_child(flash)
		var flash_tween: Tween = get_tree().create_tween()
		flash_tween.tween_property(flash, "color:a", 0.0, 0.36) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		flash_tween.tween_callback(flash.queue_free)


## Phase 3 Step D — Enemy kills player 상실 모먼트. "만족" 과 결이 다른:
## 슬로우 호흡 0.35s real (player kill 0.16s 의 2× — 죽음의 무게), time_scale
## 0.35 (CRIT 0.4 보다 더 무겁게), 카메라 zoom 없음 (관조), 화면 darken
## (MUK 0.35α — 거의 ½ wash, lingering 0.80s). G1 의 Defeat shake (10.0
## /0.45s) 와 별도 channel — shake 가 운동, darken 이 mood. S72 ↑.
func _trigger_enemy_kill_drama() -> void:
	Engine.time_scale = 0.35
	get_tree().create_timer(0.35, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0
	)
	if _hud_layer != null:
		var darken: ColorRect = ColorRect.new()
		darken.name = "EnemyKillDarken"
		darken.color = Color(Palette.MUK.r, Palette.MUK.g, Palette.MUK.b, 0.35)
		darken.set_anchors_preset(Control.PRESET_FULL_RECT)
		darken.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_layer.add_child(darken)
		var darken_tween: Tween = get_tree().create_tween()
		darken_tween.tween_property(darken, "color:a", 0.0, 0.80) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		darken_tween.tween_callback(darken.queue_free)


## S72 Hero banter helpers — personality cue layer adjacent to Phase 3 drama.
## Per-unit-per-event cooldown 3s avoids inflation during rapid-fire scenarios
## (multi-kill round, low-HP cross then re-cross). Pilot scope: 관우 + 장비
## only (assets/data/heroes/hero_banter.json) — other heroes return ""
## from get_banter and the helper silently skips. Stagger 0.5s between
## multi-unit waves (battle_start, outcome_*) to avoid simultaneous overlap.
const _BANTER_COOLDOWN_MS: int = 3000
const _BANTER_STAGGER_S: float = 0.5
var _banter_cooldown: Dictionary = {}


## S18 — resolve active chapter_id for banter by_chapter override lookup.
## Returns "" when scenario is between chapters or unloaded; HeroDatabase
## treats "" as "no override, use default" so this is the safe fallback path.
func _active_chapter_id() -> String:
	var chapter: ChapterDefinition = ScenarioRunner.get_current_chapter()
	if chapter == null:
		return ""
	return chapter.chapter_id


func _spawn_banter(unit_id: int, event_key: String) -> void:
	if _grid_controller == null:
		return
	var unit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
	if unit == null:
		return
	var line: String = HeroDatabase.get_banter(unit.hero_id, event_key, _active_chapter_id())
	if line.is_empty():
		return  # graceful: unmapped hero × event (non-pilot heroes silent)
	var key: String = "%d:%s" % [unit_id, event_key]
	var now_ms: int = Time.get_ticks_msec()
	if _banter_cooldown.has(key) and now_ms < int(_banter_cooldown[key]):
		return
	_banter_cooldown[key] = now_ms + _BANTER_COOLDOWN_MS
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var unit_node: Node2D = _find_unit_polygon(visuals, unit_id)
	if unit_node == null:
		return
	var accent: Color = Color(1.00, 0.85, 0.32)
	if visuals.has_method("_get_hero_accent"):
		accent = visuals._get_hero_accent(unit.hero_id, unit.side)
	var popup: BanterPopup = BanterPopup.make(line, accent)
	popup.position = unit_node.position + Vector2(0.0, -8.0)
	visuals.add_child(popup)


## Iterate player roster polygons + fire event-specific banter staggered 0.5s
## apart. Used for multi-unit events: battle_start / outcome_win / outcome_loss.
## outcome_win skips dead heroes; battle_start / outcome_loss include all.
func _fire_player_roster_banter(event_key: String) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null or _grid_controller == null:
		return
	var parent: Node = visuals.get_node_or_null("PlayerUnits")
	if parent == null:
		return
	var stagger: float = 0.0
	for child: Node in parent.get_children():
		if not (child is Node2D):
			continue
		var poly: Node2D = child as Node2D
		var uid: int = _extract_unit_id_from_polygon_name(poly.name)
		if uid == -1:
			continue
		var unit: BattleUnit = _grid_controller.get_battle_unit(uid)
		if unit == null or unit.side != 0:
			continue
		# Skip unmapped heroes early to avoid scheduling empty timers.
		if HeroDatabase.get_banter(unit.hero_id, event_key, _active_chapter_id()).is_empty():
			continue
		# outcome_win: surviving heroes only celebrate. outcome_loss + battle_start
		# include all (dead heroes still mourn / cheer pre-fight).
		if event_key == "outcome_win" and _hp_controller != null \
				and not _hp_controller.is_alive(uid):
			continue
		var captured_uid: int = uid
		if stagger > 0.0:
			get_tree().create_timer(stagger).timeout.connect(
				func() -> void: _spawn_banter(captured_uid, event_key)
			)
		else:
			_spawn_banter(captured_uid, event_key)
		stagger += _BANTER_STAGGER_S


## S18 — Iterate enemy roster polygons + fire event-specific banter staggered.
## Sibling to _fire_player_roster_banter; only difference is the parent node
## name + side filter. Initial scope (S18): battle_start (post player roster
## fire) + outcome_loss (when player wins, enemy chibi voices "we lost").
## start_delay lets the orchestrator stagger the entire enemy roster after the
## player roster has finished its own staggered fire.
func _fire_enemy_roster_banter(event_key: String, start_delay: float = 0.0) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null or _grid_controller == null:
		return
	var parent: Node = visuals.get_node_or_null("EnemyUnits")
	if parent == null:
		return
	var stagger: float = start_delay
	for child: Node in parent.get_children():
		if not (child is Node2D):
			continue
		var poly: Node2D = child as Node2D
		var uid: int = _extract_unit_id_from_polygon_name(poly.name)
		if uid == -1:
			continue
		var unit: BattleUnit = _grid_controller.get_battle_unit(uid)
		if unit == null or unit.side != 1:
			continue
		# Skip unmapped enemies (graceful — minor enemies stay silent).
		if HeroDatabase.get_banter(unit.hero_id, event_key, _active_chapter_id()).is_empty():
			continue
		# outcome_loss is only authored for enemies, but mirror the player-side
		# discipline: skip dead enemies on celebration-style events. For the
		# initial scope (battle_start + outcome_loss) every line is "still
		# present at the table" so include all.
		var captured_uid: int = uid
		if stagger > 0.0:
			get_tree().create_timer(stagger).timeout.connect(
				func() -> void: _spawn_banter(captured_uid, event_key)
			)
		else:
			_spawn_banter(captured_uid, event_key)
		stagger += _BANTER_STAGGER_S


## Phase 3 Step A helper. 3 채널 동시 발화. Engine.time_scale 변경은 SceneTree
## 전역이므로 0.25s 후 1.0 복원 보장 (timer 단일 시점, 중첩 발화 시 마지막
## fire 가 wins — 동시 다발 crit 은 매우 드물어 무시 가능).
func _trigger_critical_climax() -> void:
	# 채널 1 — Hit-stop. ignore_time_scale=true 로 real-time 0.20s 후 복원
	# (game-time 으로 환산하면 0.08s — 인지 가능한 freeze-frame).
	Engine.time_scale = 0.4
	get_tree().create_timer(0.20, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0
	)
	# 채널 2 — Camera zoom punch. SceneTree 바인딩 (G-31 정합).
	if _battle_camera != null:
		var orig_zoom: Vector2 = _battle_camera.zoom
		var zoom_tween: Tween = get_tree().create_tween()
		zoom_tween.tween_property(_battle_camera, "zoom", orig_zoom * 1.10, 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		zoom_tween.tween_property(_battle_camera, "zoom", orig_zoom, 0.20) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 채널 3 — Full-screen red tint flash. HUDLayer 위에 ColorRect 1회용 마운트.
	if _hud_layer != null:
		var flash: ColorRect = ColorRect.new()
		flash.name = "CritTintFlash"
		flash.color = Color(Palette.JU_HONG.r, Palette.JU_HONG.g, Palette.JU_HONG.b, 0.18)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_layer.add_child(flash)
		var flash_tween: Tween = get_tree().create_tween()
		flash_tween.tween_property(flash, "color:a", 0.0, 0.40) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		flash_tween.tween_callback(flash.queue_free)


func _list_polygon_names(visuals: Node) -> String:
	var names: Array = []
	for parent_name: String in ["PlayerUnits", "EnemyUnits"]:
		var parent: Node = visuals.get_node_or_null(parent_name)
		if parent == null:
			continue
		for child: Node in parent.get_children():
			names.append("%s/%s" % [parent_name, child.name])
	return str(names)


func _find_unit_polygon(visuals: Node, unit_id: int) -> Node2D:
	var prefix: String = "Unit%d_" % unit_id
	for parent_name: String in ["PlayerUnits", "EnemyUnits"]:
		var parent: Node = visuals.get_node_or_null(parent_name)
		if parent == null:
			continue
		for child: Node in parent.get_children():
			if (child.name as String).begins_with(prefix) and child is Node2D:
				return child as Node2D
	return null


## S73 Synergy v2 — recompute per-unit synergy badges and push to ChapterVisuals.
## Called from _spawn_unit_polygons_async (initial), _on_unit_moved (adjacency
## shifts on slide), _on_unit_died_visual (Lone Wolf activates / Peach Garden
## breaks). No-op when controller or visuals missing (test mode / mid-teardown).
func _refresh_synergy_badges() -> void:
	if _grid_controller == null:
		return
	if not _grid_controller.has_method(&"compute_synergy_badges"):
		return
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	if not visuals.has_method(&"set_synergy_badges"):
		return
	visuals.set_synergy_badges(_grid_controller.compute_synergy_badges())


## Returns a flat row-major Array[MapTileData] with all tiles passable grass.
## Preserved from sprint-6 mock helpers; sprint-7+ chapter map loading will
## replace this with assets/data/maps/{map_id}.tres asset loading.
func _make_uniform_grass_tiles(w: int, h: int) -> Array[MapTileData]:
	var tiles: Array[MapTileData] = []
	for row: int in range(h):
		for col: int in range(w):
			var tile: MapTileData = MapTileData.new()
			tile.coord = Vector2i(col, row)
			tile.terrain_type = 0
			tile.is_passable_base = true
			tile.occupant_id = 0
			tile.occupant_faction = 0
			tiles.append(tile)
	return tiles


## Session-53 — mounts the ALWAYS-mode polling helper (_CancelPoller below).
## Idempotent — does nothing if already mounted (e.g., scene reload re-entry).
func _mount_cancel_poller() -> void:
	if get_node_or_null("CancelPoller") != null:
		return  # already mounted
	var poller := _CancelPoller.new()
	poller.name = "CancelPoller"
	poller.process_mode = Node.PROCESS_MODE_ALWAYS
	poller._owner_scene = self
	add_child(poller)


## Session-53 — invoked every frame by _CancelPoller (PROCESS_MODE_ALWAYS).
## Polls ESC + right-click independently of BattleScene's own _process,
## which gets suspended by SceneManager's overworld-pause pattern. Same
## priority dispatch as _handle_cancel_or_pause: undo move → cancel
## selection → pause menu. Uses separate edge-detect latches so this poll
## path doesn't fight the original _process poll above (both can coexist
## — whichever fires first wins, but typically only the ALWAYS one runs
## mid-battle since _process is paused).
func _poll_cancel_inputs_always() -> void:
	var esc_held: bool = (
		Input.is_physical_key_pressed(KEY_ESCAPE)
		or Input.is_key_pressed(KEY_ESCAPE)
	)
	if esc_held and not _esc_was_held_always:
		_handle_cancel_or_pause()
	_esc_was_held_always = esc_held
	var rclick_held: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if rclick_held and not _rclick_was_held_always:
		_handle_cancel_or_pause()
	_rclick_was_held_always = rclick_held


## Session-53 — inline helper class. Runs PROCESS_MODE_ALWAYS so its
## _process callback fires even when BattleScene is paused/disabled by
## SceneManager (the standalone-mode pattern at battle_scene.gd:1601).
## Sole responsibility: delegate to BattleScene._poll_cancel_inputs_always
## every frame. Owner reference is set at mount time; defensive
## is_instance_valid guards against the parent being freed mid-poll.
class _CancelPoller extends Node:
	var _owner_scene: Node = null

	func _process(_delta: float) -> void:
		if _owner_scene == null:
			return
		if not is_instance_valid(_owner_scene):
			return
		if not _owner_scene.has_method("_poll_cancel_inputs_always"):
			return
		_owner_scene._poll_cancel_inputs_always()
