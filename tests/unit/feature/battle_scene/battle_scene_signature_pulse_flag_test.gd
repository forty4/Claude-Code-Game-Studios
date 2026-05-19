## BattleScene._pulse_signature_badge_next_mount 플래그 regression test (S69).
##
## Bug: B1.2 signature pulse 가 windowed 부팅 시 발화 안 함 (사용자 attestation).
## 원인: `_collect_pre_battle_beats` 가 cascade 를 consume 한 후에 `_mount_signature_count_badge`
## 가 peek → 항상 empty → pulse 영원히 안 뜸. peek-based 의존이 실행 순서 race.
## Fix: consume 시 BattleScene member var `_pulse_signature_badge_next_mount` 을
## true 로 set, mount 가 이 플래그로 pulse 결정 + 사용 후 reset.
##
## 기존 `scenario_runner_cascade_join_announce_test.gd::
## test_get_pending_cascade_announcement_is_non_consuming` 는 peek API 자체의
## non-consuming 동작만 검증 — 실제 BattleScene 의 consume → mount 순서를 못 잡음
## (G-30 family: 헤드리스에서 통과하는 단위 테스트가 windowed-only 통합 흐름의
## race 를 못 본 사례).

extends GdUnitTestSuite

const BattleSceneScript: GDScript = preload("res://src/feature/battle_scene/battle_scene.gd")


func before_test() -> void:
	ScenarioRunner.reset_for_tests()


func after_test() -> void:
	ScenarioRunner.reset_for_tests()


func _instantiate_battle_scene() -> BattleScene:
	var scene: BattleScene = BattleSceneScript.new()
	auto_free(scene)
	return scene


func _make_minimal_chapter() -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "ch_test"
	c.chapter_number = 2
	c.beat_1_text_key = ""
	c.beat_3_text_key = ""
	return c


# ─── 핵심 regression: consume 시 플래그 set ────────────────────────────────────


## ScenarioRunner 에 pending cascade 가 있는 상태에서 _collect_pre_battle_beats
## 호출 시 `_pulse_signature_badge_next_mount` 가 true 로 set 되어야 한다.
## 이게 windowed pulse 발화의 유일한 트리거. consume-before-mount race 차단.
func test_collect_pre_battle_beats_sets_pulse_flag_when_cascade_pending() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	ScenarioRunner._pending_cascade_announcement = {
		"signature_key": "WIN_test_signature",
		"text_key": "test.cascade_join.alpha",
	}
	assert_bool(scene._pulse_signature_badge_next_mount).override_failure_message(
		"플래그 기본값은 false 여야 한다"
	).is_false()

	scene._collect_pre_battle_beats(_make_minimal_chapter())

	assert_bool(scene._pulse_signature_badge_next_mount).override_failure_message(
		"cascade pending 상태에서 _collect_pre_battle_beats 호출 후 플래그가 true 여야 한다 — "
		+ "S69 fix 의 핵심 invariant. 이 assert 실패 = consume 시 플래그 미설정 = pulse 영원히 안 뜸."
	).is_true()


## Cascade 가 비어있을 때는 플래그가 변하지 않는다 (retry-reload, 일반 챕터 등).
func test_collect_pre_battle_beats_no_flag_when_cascade_empty() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	# ScenarioRunner._pending_cascade_announcement 은 reset_for_tests 로 비어있음.
	assert_bool(scene._pulse_signature_badge_next_mount).is_false()

	scene._collect_pre_battle_beats(_make_minimal_chapter())

	assert_bool(scene._pulse_signature_badge_next_mount).override_failure_message(
		"cascade 비어있을 때 플래그는 false 유지 (retry-reload / non-cascade chapter)"
	).is_false()


## Consume 이 실제로 일어났는지 부수 효과로 확인 — _collect_pre_battle_beats 가
## ScenarioRunner 의 pending 을 비워야 한다 (1회만 발화 보장).
func test_collect_pre_battle_beats_actually_consumes_cascade() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	ScenarioRunner._pending_cascade_announcement = {
		"signature_key": "WIN_test_signature",
		"text_key": "test.cascade_join.alpha",
	}

	scene._collect_pre_battle_beats(_make_minimal_chapter())

	assert_bool(ScenarioRunner.get_pending_cascade_announcement().is_empty()).override_failure_message(
		"_collect_pre_battle_beats 호출 후 ScenarioRunner pending 은 비워져야 한다"
	).is_true()
