## cross_chapter_continuity_test.gd
##
## Integration tests for save-load story-002 — cross-chapter continuity.
## Covers ACs from design/gdd/save-load.md §8.4 + §8.6 (verbatim AC text):
##   - AC-SL-12: Destiny State populator fills echo_count + echo_marks_archive +
##               flags_to_set on save_checkpoint_requested(ctx)
##   - AC-SL-13: Round-trip preservation through ResourceSaver → ResourceLoader
##   - AC-SL-20: Idempotent hydration — load_latest_checkpoint twice yields
##               distinct Object identities with field-equal payloads
##   + save_loaded(SaveContext) signal contract (ADR-0001 minor amendment 2026-05-08):
##     emission-on-load, deferred subscriber rehydration, null-payload guard,
##     idempotent re-invocation on same ctx (CR-SL-19/20).
##
## AC-SL-14 (scenario_path_key "::"-delimiter round-trip) is DEFERRED to
## schema_version 2 — SaveContext currently has no scenario_path_key field per
## src/core/payloads/save_context.gd; story-002 §Out of Scope confirms MVP scope
## skips this AC. Will be re-added when scenario-progression epic ships the
## SCENARIO_END epilogue populator (story-001-cross-chapter-continuity §AC-SL-14
## + §Implementation Notes #5). Documented as ADVISORY deviation in story
## Completion Notes.
##
## Test discipline (godot-4x-gotchas.md):
##   G-3:  no class_name in this file (test convention).
##   G-4:  signal payloads captured via Array.append on outer-scope var (lambdas
##         cannot reassign outer primitive locals; reference-mutation is fine).
##   G-10: emit on REAL /root/GameBus autoload identifier — never on a
##         GameBusStub, since the real /root/DestinyState autoload is bound to
##         the production GameBus identifier and stubs cannot reach its handler.
##   G-15: before_test() / after_test() lifecycle (not before_each — phantom).
##   G-27: cache state at signal-emit time when querying autoload getters in
##         deferred handlers (not needed here — payload IS the state).
##   G-28: NEVER bulk-disconnect-all on signals; track per-callable Callables
##         and disconnect ONLY the test-side captures. Production autoload
##         subscriptions (DestinyState, SaveManager) MUST remain intact.
##
## ADR ref: ADR-0003 §3.5 Cross-Chapter Continuity + ADR-0001 §9 Persistence
## (4 signals as of 2026-05-08 minor amendment) + ADR-0017 ScenarioRunner emit.
extends GdUnitTestSuite


# ─── Per-test state ───────────────────────────────────────────────────────────

## Captures for save_loaded signal emissions (G-4 pattern — Array.append from lambda).
var _save_loaded_captures: Array = []

## The test-side capture callable for save_loaded. Stored as a member so
## after_test can disconnect ONLY this callable (G-28 per-callable discipline).
var _save_loaded_capture_callable: Callable

## The active SaveManagerStub for round-trip tests (null in populator-only tests).
var _stub: Node = null


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func before_test() -> void:
	# G-15 mirror obligation — reset DestinyState so each test starts fresh.
	# reset_for_tests() also re-establishes the 5 GameBus subscriptions
	# (idempotent via is_connected guard); critical because some prior test
	# files in the suite use bulk-disconnect-all (pre-existing tech debt
	# scenario_runner_signal_contract_test.gd; G-28 anti-pattern documented
	# but not propagated into this file).
	var ds: Node = get_node_or_null("/root/DestinyState")
	if ds != null:
		ds.reset_for_tests()
	# Reset capture state.
	_save_loaded_captures = []
	_save_loaded_capture_callable = func(ctx: SaveContext) -> void:
		_save_loaded_captures.append(ctx)
	GameBus.save_loaded.connect(_save_loaded_capture_callable)


func after_test() -> void:
	# G-28 per-callable disconnect — test-side capture only; production
	# DestinyState autoload subscription to save_loaded must remain intact.
	if GameBus.save_loaded.is_connected(_save_loaded_capture_callable):
		GameBus.save_loaded.disconnect(_save_loaded_capture_callable)
	# G-6 idempotent stub cleanup safety net (no-op if no swap_in occurred).
	SaveManagerStub.swap_out()
	_stub = null


# ─── Helpers ──────────────────────────────────────────────────────────────────

## Seeds DestinyState with N EchoMarks via the live GameBus.scenario_beat_retried
## production handler. Uses ScenarioRunner.get_current_chapter() lookup which
## returns null in test mode — see destiny_state.gd::_current_chapter_id_or_empty —
## meaning _chapter_echo_counts stays at 0 even though _full_archive grows. Tests
## that need a non-zero per-chapter count must inject a chapter_id manually
## via _seed_chapter_echo_count.
func _seed_echo_marks(count: int) -> void:
	for i in count:
		var mark: EchoMark = EchoMark.new()
		mark.beat_index = 5
		mark.outcome = &"LOSS"
		mark.tag = StringName("retry_test_%d" % i)
		GameBus.scenario_beat_retried.emit(mark)
		await get_tree().process_frame


## Seeds the per-chapter echo count dictionary directly (test seam).
## Required because _current_chapter_id_or_empty() returns "" in pure unit-test
## mode without a live ScenarioRunner-managed chapter; the per-chapter dict stays
## empty. This bypasses that gap so AC-SL-12 assertions can verify the populator's
## ctx.echo_count copy semantics independent of scenario state.
func _seed_chapter_echo_count(chapter_id: String, count: int) -> void:
	var ds: Node = get_node_or_null("/root/DestinyState")
	if ds == null:
		return
	# _chapter_echo_counts is NOT private from gdscript reflection perspective;
	# this is a recognized test-seam pattern in this project (see
	# tests/unit/feature/destiny_state/destiny_state_test.gd direct field access).
	ds._chapter_echo_counts[chapter_id] = count


## Seeds DestinyState with one divergence flag via destiny_branch_chosen handler
## (production code path — exercises CR-DS-15 sentinel-flag emission).
func _seed_one_flag() -> void:
	var choice: DestinyBranchChoice = DestinyBranchChoice.new()
	choice.chapter_id = "ch01_test"
	choice.branch_key = "WIN_test_branch"
	choice.outcome = BattleOutcome.Result.WIN
	choice.is_canonical_history = false  # triggers divergence_recorded flag
	choice.is_draw_fallback = false
	choice.is_invalid = false
	GameBus.destiny_branch_chosen.emit(choice)
	await get_tree().process_frame


## Builds a SaveContext fully-populated for round-trip tests (AC-SL-13).
func _build_seeded_save_context() -> SaveContext:
	var ctx: SaveContext = SaveContext.new()
	ctx.schema_version = 1
	ctx.slot_id = 1
	ctx.chapter_id = &"ch01_test"
	ctx.chapter_number = 1
	ctx.last_cp = 2
	ctx.outcome = int(BattleOutcome.Result.WIN)
	ctx.branch_key = &"WIN_canonical"
	ctx.echo_count = 3
	# 3 EchoMarks with distinct beat/outcome/tag for bitwise round-trip check.
	var marks: Array[EchoMark] = []
	for i in 3:
		var mark: EchoMark = EchoMark.new()
		mark.beat_index = i + 5  # 5, 6, 7
		mark.outcome = &"LOSS" if (i % 2 == 0) else &"WIN"
		mark.tag = StringName("seed_mark_%d" % i)
		marks.append(mark)
	ctx.echo_marks_archive = marks
	ctx.flags_to_set = PackedStringArray(["divergence_recorded__ch01_test__WIN_canonical"])
	return ctx


# ═══════════════════════════════════════════════════════════════════════════════
# AC-SL-12: Destiny State populator on save_checkpoint_requested(ctx)
# ═══════════════════════════════════════════════════════════════════════════════


## AC-SL-12: with 3 echoes + 1 flag seeded in chapter_id "ch01_test", emitting
## save_checkpoint_requested(ctx) populates ctx.echo_count == 3 (per-chapter
## lookup) AND echo_marks_archive.size() == 3 AND flags_to_set.size() == 1.
func test_ac_sl12_populator_fills_echo_count_archive_and_flags_when_state_seeded() -> void:
	# Arrange — seed DestinyState with 3 echoes + 1 flag + per-chapter count.
	await _seed_echo_marks(3)
	await _seed_one_flag()
	_seed_chapter_echo_count("ch01_test", 3)
	# Build a default ctx with chapter_id matching the seeded count key.
	var ctx: SaveContext = SaveContext.new()
	ctx.chapter_id = &"ch01_test"
	ctx.chapter_number = 1
	ctx.last_cp = 2
	# Act — emit save_checkpoint_requested through the live GameBus; production
	# DestinyState handler runs on the deferred frame and writes to ctx.
	GameBus.save_checkpoint_requested.emit(ctx)
	await get_tree().process_frame
	# Assert — populator filled 3 owned fields per CR-DS-16.
	assert_int(ctx.echo_count).is_equal(3)
	assert_int(ctx.echo_marks_archive.size()).is_equal(3)
	assert_int(ctx.flags_to_set.size()).is_equal(1)
	assert_str(ctx.flags_to_set[0]).is_equal("divergence_recorded__ch01_test__WIN_test_branch")


## AC-SL-12 edge: with empty DestinyState (0 echoes, 0 flags), populator yields
## ctx.echo_count == 0 AND echo_marks_archive empty AND flags_to_set empty.
func test_ac_sl12_populator_with_empty_destiny_state_yields_zero_count_and_empty_arrays() -> void:
	# Arrange — DestinyState was reset in before_test; no seeding here.
	var ctx: SaveContext = SaveContext.new()
	ctx.chapter_id = &"ch01_empty"
	ctx.chapter_number = 1
	ctx.last_cp = 1
	# Act
	GameBus.save_checkpoint_requested.emit(ctx)
	await get_tree().process_frame
	# Assert — empty state populator copies the empty defaults.
	assert_int(ctx.echo_count).is_equal(0)
	assert_int(ctx.echo_marks_archive.size()).is_equal(0)
	assert_int(ctx.flags_to_set.size()).is_equal(0)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-SL-13: Round-trip preservation through ResourceSaver → ResourceLoader
# ═══════════════════════════════════════════════════════════════════════════════


## AC-SL-13: a fully-populated SaveContext (3 EchoMarks + 1 flag + branch_key)
## written via SaveManager.save_checkpoint and re-read via load_latest_checkpoint
## preserves echo_marks_archive bitwise + flags_to_set bitwise + branch_key.
func test_ac_sl13_round_trip_preserves_echo_marks_archive_and_flags_to_set_bitwise() -> void:
	# Arrange — swap in stub for temp save root isolation.
	_stub = SaveManagerStub.swap_in()
	var source: SaveContext = _build_seeded_save_context()
	# Act — save then load.
	var save_ok: bool = _stub.save_checkpoint(source)
	assert_bool(save_ok).is_true()
	var loaded: SaveContext = _stub.load_latest_checkpoint()
	# Assert — non-null + field-equal.
	assert_object(loaded).is_not_null()
	if loaded == null:
		SaveManagerStub.swap_out()
		return
	assert_int(loaded.echo_count).is_equal(source.echo_count)
	assert_int(loaded.echo_marks_archive.size()).is_equal(source.echo_marks_archive.size())
	for i in source.echo_marks_archive.size():
		var sm: EchoMark = source.echo_marks_archive[i]
		var lm: EchoMark = loaded.echo_marks_archive[i]
		assert_int(lm.beat_index).is_equal(sm.beat_index)
		assert_str(String(lm.outcome)).is_equal(String(sm.outcome))
		assert_str(String(lm.tag)).is_equal(String(sm.tag))
	assert_int(loaded.flags_to_set.size()).is_equal(source.flags_to_set.size())
	for i in source.flags_to_set.size():
		assert_str(loaded.flags_to_set[i]).is_equal(source.flags_to_set[i])
	assert_str(String(loaded.branch_key)).is_equal(String(source.branch_key))
	# G-6 in-body cleanup before after_test orphan scan.
	SaveManagerStub.swap_out()


## AC-SL-13 edge: round-trip with empty echo_marks_archive + empty flags_to_set
## yields equivalent empty collections (no nulls, no spurious entries).
func test_ac_sl13_round_trip_with_empty_collections() -> void:
	_stub = SaveManagerStub.swap_in()
	var source: SaveContext = SaveContext.new()
	source.chapter_id = &"ch01_empty"
	source.chapter_number = 1
	source.last_cp = 1
	source.branch_key = &""
	source.echo_count = 0
	source.echo_marks_archive = []
	source.flags_to_set = PackedStringArray()
	# Act
	var save_ok: bool = _stub.save_checkpoint(source)
	assert_bool(save_ok).is_true()
	var loaded: SaveContext = _stub.load_latest_checkpoint()
	# Assert
	assert_object(loaded).is_not_null()
	if loaded == null:
		SaveManagerStub.swap_out()
		return
	assert_int(loaded.echo_count).is_equal(0)
	assert_int(loaded.echo_marks_archive.size()).is_equal(0)
	assert_int(loaded.flags_to_set.size()).is_equal(0)
	SaveManagerStub.swap_out()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-SL-20: Idempotent hydration — load twice yields distinct identity + equal fields
# ═══════════════════════════════════════════════════════════════════════════════


## AC-SL-20: calling load_latest_checkpoint twice in succession returns
## distinct Object instances (CACHE_MODE_IGNORE re-reads from disk) AND
## both loads have field-equal payloads.
func test_ac_sl20_load_latest_checkpoint_twice_yields_distinct_objects_with_field_equality() -> void:
	_stub = SaveManagerStub.swap_in()
	var source: SaveContext = _build_seeded_save_context()
	var save_ok: bool = _stub.save_checkpoint(source)
	assert_bool(save_ok).is_true()
	# Act — load twice in succession with no intervening saves.
	var load_1: SaveContext = _stub.load_latest_checkpoint()
	var load_2: SaveContext = _stub.load_latest_checkpoint()
	# Assert — distinct object identity.
	assert_object(load_1).is_not_null()
	assert_object(load_2).is_not_null()
	if load_1 == null or load_2 == null:
		SaveManagerStub.swap_out()
		return
	assert_bool(load_1 != load_2).override_failure_message(
		"AC-SL-20: CACHE_MODE_IGNORE must produce distinct Object instances on repeat load; got identical references."
	).is_true()
	# Assert — field-equal (deep compare of the load_1 vs load_2 owned fields).
	assert_int(load_1.echo_count).is_equal(load_2.echo_count)
	assert_int(load_1.echo_marks_archive.size()).is_equal(load_2.echo_marks_archive.size())
	assert_int(load_1.flags_to_set.size()).is_equal(load_2.flags_to_set.size())
	assert_str(String(load_1.branch_key)).is_equal(String(load_2.branch_key))
	for i in load_1.echo_marks_archive.size():
		var m1: EchoMark = load_1.echo_marks_archive[i]
		var m2: EchoMark = load_2.echo_marks_archive[i]
		assert_int(m1.beat_index).is_equal(m2.beat_index)
		assert_str(String(m1.outcome)).is_equal(String(m2.outcome))
		assert_str(String(m1.tag)).is_equal(String(m2.tag))
	SaveManagerStub.swap_out()


## AC-SL-20 edge: loading from an empty slot returns null on both calls
## (no save_load_failed emit per ADR-0003 §empty-slot-not-failure rule).
func test_ac_sl20_load_twice_on_empty_slot_both_return_null() -> void:
	_stub = SaveManagerStub.swap_in()
	# Act — no save_checkpoint preceded; slot is empty.
	var load_1: SaveContext = _stub.load_latest_checkpoint()
	var load_2: SaveContext = _stub.load_latest_checkpoint()
	# Assert — empty slot returns null per the load_latest_checkpoint contract.
	assert_object(load_1).is_null()
	assert_object(load_2).is_null()
	SaveManagerStub.swap_out()


# ═══════════════════════════════════════════════════════════════════════════════
# save_loaded(SaveContext) signal contract — ADR-0001 minor amendment 2026-05-08
# ═══════════════════════════════════════════════════════════════════════════════


## save_loaded must be emitted exactly once on successful load_latest_checkpoint,
## carrying the migrated SaveContext payload. DestinyState's CONNECT_DEFERRED
## subscriber rehydrates internal fields from the payload (CR-SL-19/20).
##
## Note: this test uses the production /root/SaveManager (NOT the stub) so
## DestinyState's autoload subscription fires on the real GameBus identifier
## (G-10). The stub-redirected test path verifies disk I/O; this test verifies
## signal contract reach + production-autoload rehydration.
func test_save_loaded_signal_emits_after_load_and_rehydrates_destiny_state() -> void:
	# Arrange — stub-isolated save first, so the load below is deterministic.
	_stub = SaveManagerStub.swap_in()
	var source: SaveContext = _build_seeded_save_context()
	var save_ok: bool = _stub.save_checkpoint(source)
	assert_bool(save_ok).is_true()
	# Pre-load: clear DestinyState so we can detect rehydration.
	var ds: Node = get_node_or_null("/root/DestinyState")
	assert_object(ds).is_not_null()
	ds.reset_for_tests()
	assert_int(ds.get_full_archive().size()).is_equal(0)
	# Act — load triggers save_loaded.emit on the live GameBus.
	var loaded: SaveContext = _stub.load_latest_checkpoint()
	assert_object(loaded).is_not_null()
	# Deferred-frame await for both _save_loaded_capture_callable and
	# DestinyState._on_save_loaded to fire (both CONNECT_DEFERRED).
	await get_tree().process_frame
	# Assert — capture saw the signal once with the migrated payload.
	assert_int(_save_loaded_captures.size()).is_equal(1)
	assert_object(_save_loaded_captures[0]).is_not_null()
	# Assert — DestinyState rehydrated _full_archive from the payload.
	# Per Option A mapping: ctx.echo_count → _chapter_echo_counts[ctx.chapter_id].
	assert_int(ds.get_full_archive().size()).is_equal(3)
	assert_int(ds.get_echo_count("ch01_test")).is_equal(3)
	assert_int(ds.get_flags_to_set().size()).is_equal(1)
	SaveManagerStub.swap_out()


## save_loaded null-payload guard — handler must accept null without crashing
## per CR-SL-22 never-crash invariant. Direct emit on the GameBus is the
## fast path to verify the guard (failure path normally emits save_load_failed
## instead of save_loaded; this is defense-in-depth).
func test_save_loaded_handler_null_payload_guard_is_noop() -> void:
	# Arrange — seed DestinyState so we can verify "no-op" means state unchanged.
	await _seed_echo_marks(2)
	var ds: Node = get_node_or_null("/root/DestinyState")
	var pre_archive_size: int = ds.get_full_archive().size()
	# Act — emit with null payload. Should not crash; should not mutate state.
	GameBus.save_loaded.emit(null)
	await get_tree().process_frame
	# Assert — no crash (test reaches this line) AND state unchanged.
	assert_int(ds.get_full_archive().size()).is_equal(pre_archive_size)


## save_loaded handler idempotency — invoking the handler twice with the same
## ctx produces field-identical internal state on both invocations (CR-SL-20
## idempotency contract; defense for OQ-SL-3 signal-driven dispatch case where
## the same signal could fire twice in degenerate cases).
func test_save_loaded_handler_idempotent_on_repeat_invocation() -> void:
	# Arrange — start clean DestinyState; build a payload to hydrate from.
	var ds: Node = get_node_or_null("/root/DestinyState")
	assert_object(ds).is_not_null()
	var ctx: SaveContext = _build_seeded_save_context()
	# Act — fire save_loaded twice with the same payload.
	GameBus.save_loaded.emit(ctx)
	await get_tree().process_frame
	var first_archive_size: int = ds.get_full_archive().size()
	var first_chapter_count: int = ds.get_echo_count("ch01_test")
	var first_flag_count: int = ds.get_flags_to_set().size()
	GameBus.save_loaded.emit(ctx)
	await get_tree().process_frame
	# Assert — second invocation yields field-identical state (idempotent).
	assert_int(ds.get_full_archive().size()).is_equal(first_archive_size)
	assert_int(ds.get_echo_count("ch01_test")).is_equal(first_chapter_count)
	assert_int(ds.get_flags_to_set().size()).is_equal(first_flag_count)
	# Sanity check on absolute values from the seeded payload.
	assert_int(first_archive_size).is_equal(3)
	assert_int(first_chapter_count).is_equal(3)
	assert_int(first_flag_count).is_equal(1)
