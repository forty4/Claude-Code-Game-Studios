## failure_surfacing_test.gd
##
## Integration tests for save-load story-003 — failure surfacing.
## Covers ACs from design/gdd/save-load.md §8.5 Failure Surfacing (verbatim):
##   - AC-SL-15: disk-full simulation (forced ResourceSaver error) → false return +
##               save_load_failed("save", "resource_saver_error:<N>") + no partial file
##               at final_path
##   - AC-SL-16: truncated/corrupt file → null return + save_load_failed("load", "invalid_resource:...")
##   - AC-SL-17: orphan .tmp file (mid-write crash simulation) → loader skips orphan +
##               returns prior checkpoint or null
##   + failure-path sentinel: save_load_failed fires on failure; save_loaded does NOT
##     (qa-tester ADVISORY from story-002 review, folded into story-003 per AC-SL-17 scope)
##
## Test discipline (godot-4x-gotchas.md):
##   G-3:  no class_name in this file (test convention; autoload collision risk).
##   G-4:  signal payloads captured via Array.append (lambdas cannot reassign
##         outer primitive locals; reference-mutation via Array.append is safe).
##   G-10: emit on REAL /root/GameBus autoload identifier — SaveManager autoload
##         is bound at engine init; emitting on a stub would not reach the real
##         GameBus subscriptions. For failure-path tests we invoke _stub methods
##         directly (not via GameBus signal) to control error injection.
##   G-15: before_test() / after_test() lifecycle (not before_each — phantom hook).
##   G-28: NEVER bulk-disconnect-all on signals; track per-callable Callables and
##         disconnect ONLY the test-side captures. Production autoload subscriptions
##         (SaveManager, DestinyState) MUST remain intact.
##
## ADR ref: ADR-0003 §3.7 Failure Surfacing (CR-SL-21/22) + §Constraints +
##          ADR-0001 §9 Persistence signals (save_load_failed + save_loaded).
extends GdUnitTestSuite


# ─── Per-test state ───────────────────────────────────────────────────────────

## Captures for save_load_failed signal emissions (G-4 pattern).
var _failed_captures: Array = []

## Captures for save_loaded signal emissions (G-4 pattern, sentinel use).
var _loaded_captures: Array = []

## The test-side capture callable for save_load_failed. Stored as member for
## per-callable disconnect in after_test (G-28 discipline).
var _failed_capture_callable: Callable

## The test-side capture callable for save_loaded. Stored as member for
## per-callable disconnect in after_test (G-28 discipline).
var _loaded_capture_callable: Callable

## The active SaveManagerStub for this test function. Null if no swap_in occurred.
var _stub: Node = null  # SaveManagerStub.swap_in() returns Node (the stub instance); the class itself is RefCounted utility holder.


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func before_test() -> void:
	# G-15: canonical name is before_test(), not before_each().
	# Reset per-test capture arrays.
	_failed_captures = []
	_loaded_captures = []
	# Build and connect test-side capture callables.
	_failed_capture_callable = func(op: String, reason: String) -> void:
		_failed_captures.append({"op": op, "reason": reason})
	_loaded_capture_callable = func(ctx: SaveContext) -> void:
		_loaded_captures.append(ctx)
	GameBus.save_load_failed.connect(_failed_capture_callable)
	GameBus.save_loaded.connect(_loaded_capture_callable)


func after_test() -> void:
	# G-28: per-callable disconnect only — never bulk-disconnect-all.
	if GameBus.save_load_failed.is_connected(_failed_capture_callable):
		GameBus.save_load_failed.disconnect(_failed_capture_callable)
	if GameBus.save_loaded.is_connected(_loaded_capture_callable):
		GameBus.save_loaded.disconnect(_loaded_capture_callable)
	# G-6: idempotent safety-net cleanup; swap_out is a no-op if not active.
	SaveManagerStub.swap_out()
	_stub = null


# ─── Helpers ──────────────────────────────────────────────────────────────────

## Builds a minimal valid SaveContext suitable for a save_checkpoint call.
## Uses chapter 1 / cp 1 so it maps to slot_1/ch_01_cp_1.res.
func _build_valid_source() -> SaveContext:
	var ctx: SaveContext = SaveContext.new()
	ctx.schema_version = 1
	ctx.slot_id = 1
	ctx.chapter_id = &"ch01_test"
	ctx.chapter_number = 1
	ctx.last_cp = 1
	ctx.outcome = 0
	ctx.branch_key = &""
	ctx.echo_count = 0
	ctx.echo_marks_archive = []
	ctx.flags_to_set = PackedStringArray()
	ctx.saved_at_unix = 0
	ctx.play_time_seconds = 0
	return ctx


## Returns the expected final_path for the default source context.
## Mirrors SaveManager._path_for(1, 1, 1) logic using the stub's temp root.
func _final_path_for_stub() -> String:
	if _stub == null:
		return ""
	var root: String = _stub._save_root_override.rstrip("/")
	return "%s/slot_1/ch_01_cp_1.res" % root


## Returns the expected tmp_path for the default source context.
## Mirrors SaveManager's tmp_path derivation from _path_for.
func _tmp_path_for_stub() -> String:
	var final_path: String = _final_path_for_stub()
	if final_path.is_empty():
		return ""
	return final_path.get_basename() + ".tmp.res"


# ═══════════════════════════════════════════════════════════════════════════════
# AC-SL-15: disk full — forced ResourceSaver error
# ═══════════════════════════════════════════════════════════════════════════════


## AC-SL-15 core: with _test_force_save_error = ERR_FILE_CANT_WRITE,
## save_checkpoint returns false AND emits save_load_failed with op="save"
## and reason starting with "resource_saver_error:".
func test_ac_sl15_disk_full_returns_false_emits_save_load_failed_with_resource_saver_error_reason() -> void:
	# Arrange — swap in stub; inject save error.
	_stub = SaveManagerStub.swap_in()
	_stub._test_force_save_error = ERR_FILE_CANT_WRITE
	var source: SaveContext = _build_valid_source()
	# Act
	var result: bool = _stub.save_checkpoint(source)
	await get_tree().process_frame
	# Assert — save returned false.
	assert_bool(result).override_failure_message(
		"AC-SL-15: save_checkpoint must return false when ResourceSaver fails with ERR_FILE_CANT_WRITE."
	).is_false()
	# Assert — exactly one save_load_failed emission with correct op + reason prefix.
	assert_int(_failed_captures.size()).override_failure_message(
		("AC-SL-15: expected 1 save_load_failed emission; got %d. "
		+ "Captures: %s") % [_failed_captures.size(), str(_failed_captures)]
	).is_equal(1)
	var capture: Dictionary = _failed_captures[0]
	assert_str(capture.get("op", "")).override_failure_message(
		"AC-SL-15: save_load_failed op must be 'save'."
	).is_equal("save")
	var reason: String = capture.get("reason", "")
	assert_bool(reason.begins_with("resource_saver_error:")).override_failure_message(
		("AC-SL-15: save_load_failed reason must start with 'resource_saver_error:'; "
		+ "got '%s'.") % reason
	).is_true()
	# G-6 in-body cleanup.
	SaveManagerStub.swap_out()


## AC-SL-15: no partial file left at final_path after disk full error.
## The .tmp file may or may not persist (best-effort cleanup); but final_path
## MUST NOT exist because the atomic rename step never ran.
func test_ac_sl15_no_partial_file_left_at_final_path_after_disk_full_error() -> void:
	# Arrange
	_stub = SaveManagerStub.swap_in()
	_stub._test_force_save_error = ERR_FILE_CANT_WRITE
	var source: SaveContext = _build_valid_source()
	var final_path: String = _final_path_for_stub()
	# Act
	var result: bool = _stub.save_checkpoint(source)
	# Assert — final_path must not exist (ResourceSaver error occurred before rename).
	assert_bool(result).is_false()
	assert_bool(FileAccess.file_exists(final_path)).override_failure_message(
		("AC-SL-15: final_path '%s' must NOT exist after ResourceSaver failure "
		+ "(atomic rename never ran).") % final_path
	).is_false()
	# G-6 in-body cleanup.
	SaveManagerStub.swap_out()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-SL-16: truncated / corrupt file
# ═══════════════════════════════════════════════════════════════════════════════


## AC-SL-16 core: a truncated SaveContext file on disk causes load_latest_checkpoint
## to return null AND emit save_load_failed with op="load" and
## reason starting with "invalid_resource:".
func test_ac_sl16_truncated_file_returns_null_emits_save_load_failed_with_invalid_resource_reason() -> void:
	# Arrange — write a valid checkpoint first, then corrupt it.
	_stub = SaveManagerStub.swap_in()
	var source: SaveContext = _build_valid_source()
	var save_ok: bool = _stub.save_checkpoint(source)
	assert_bool(save_ok).override_failure_message(
		"AC-SL-16 arrange: save_checkpoint must succeed to produce a file to corrupt."
	).is_true()
	var final_path: String = _final_path_for_stub()
	assert_bool(FileAccess.file_exists(final_path)).override_failure_message(
		"AC-SL-16 arrange: final_path must exist after successful save."
	).is_true()
	# Corrupt the file: open for writing and truncate to 4 bytes (too short for a valid .res header).
	var fa: FileAccess = FileAccess.open(final_path, FileAccess.WRITE)
	assert_object(fa).override_failure_message(
		("AC-SL-16 arrange: could not open final_path '%s' for writing. "
		+ "FileAccess error: %d.") % [final_path, FileAccess.get_open_error()]
	).is_not_null()
	if fa == null:
		SaveManagerStub.swap_out()
		return
	# Write 4 garbage bytes — too short to be a valid Godot .res binary header.
	fa.store_8(0x47)  # 'G' — partial .res header at best
	fa.store_8(0x44)  # 'D'
	fa.store_8(0x52)  # 'R'
	fa.store_8(0x53)  # 'S'
	fa.close()
	# Act — load the corrupted file.
	var loaded: SaveContext = _stub.load_latest_checkpoint()
	await get_tree().process_frame
	# Assert — load returned null.
	assert_object(loaded).override_failure_message(
		"AC-SL-16: load_latest_checkpoint must return null for a truncated file."
	).is_null()
	# Assert — exactly one save_load_failed emission with correct op + reason prefix.
	assert_int(_failed_captures.size()).override_failure_message(
		("AC-SL-16: expected 1 save_load_failed emission; got %d. "
		+ "Captures: %s") % [_failed_captures.size(), str(_failed_captures)]
	).is_equal(1)
	var capture: Dictionary = _failed_captures[0]
	assert_str(capture.get("op", "")).override_failure_message(
		"AC-SL-16: save_load_failed op must be 'load'."
	).is_equal("load")
	var reason: String = capture.get("reason", "")
	assert_bool(reason.begins_with("invalid_resource:")).override_failure_message(
		("AC-SL-16: save_load_failed reason must start with 'invalid_resource:'; "
		+ "got '%s'.") % reason
	).is_true()
	# G-6 in-body cleanup.
	SaveManagerStub.swap_out()


## AC-SL-16 edge: zero-byte file causes load_latest_checkpoint to return null
## AND emit save_load_failed. Zero-byte files cannot be valid .res Resources.
func test_ac_sl16_zero_byte_file_load_returns_null_with_invalid_resource_reason() -> void:
	# Arrange — write valid checkpoint; then overwrite with empty file.
	_stub = SaveManagerStub.swap_in()
	var source: SaveContext = _build_valid_source()
	assert_bool(_stub.save_checkpoint(source)).is_true()
	var final_path: String = _final_path_for_stub()
	# Overwrite with zero bytes.
	var fa: FileAccess = FileAccess.open(final_path, FileAccess.WRITE)
	assert_object(fa).is_not_null()
	if fa == null:
		SaveManagerStub.swap_out()
		return
	fa.close()  # close immediately without writing anything → zero bytes
	assert_int(FileAccess.get_file_as_bytes(final_path).size()).override_failure_message(
		"AC-SL-16 edge: file should be 0 bytes after overwrite."
	).is_equal(0)
	# Act
	var loaded: SaveContext = _stub.load_latest_checkpoint()
	await get_tree().process_frame
	# Assert
	assert_object(loaded).override_failure_message(
		"AC-SL-16 edge: load of zero-byte file must return null."
	).is_null()
	assert_int(_failed_captures.size()).override_failure_message(
		"AC-SL-16 edge: expected 1 save_load_failed emission for zero-byte file."
	).is_equal(1)
	var reason: String = _failed_captures[0].get("reason", "")
	assert_bool(reason.begins_with("invalid_resource:")).override_failure_message(
		("AC-SL-16 edge: reason must start with 'invalid_resource:'; got '%s'.") % reason
	).is_true()
	# G-6 in-body cleanup.
	SaveManagerStub.swap_out()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-SL-17: orphan .tmp file (mid-write crash simulation)
# ═══════════════════════════════════════════════════════════════════════════════


## AC-SL-17 core: a lone .tmp.res orphan file (no matching final .res) is skipped
## by load_latest_checkpoint — it returns the prior successful checkpoint, not the
## orphan. The orphan file remains on disk (loader is read-only per CR-SL-9).
func test_ac_sl17_orphan_tmp_file_skipped_by_load_returns_prior_checkpoint() -> void:
	# Arrange — write a valid ch_01_cp_1.res (prior checkpoint).
	_stub = SaveManagerStub.swap_in()
	var source: SaveContext = _build_valid_source()
	assert_bool(_stub.save_checkpoint(source)).is_true()
	# Simulate a crash mid-write for ch_01_cp_2 by writing an orphan .tmp.res directly.
	# The final .res for ch_01_cp_2 does NOT exist — only the .tmp survives.
	var root: String = _stub._save_root_override.rstrip("/")
	var orphan_tmp: String = "%s/slot_1/ch_01_cp_2.tmp.res" % root
	# Copy the valid .res to the orphan path to give it valid-looking content.
	# (Loader rejects it via filename filter before even attempting to load.)
	var valid_bytes: PackedByteArray = FileAccess.get_file_as_bytes(_final_path_for_stub())
	var tmp_fa: FileAccess = FileAccess.open(orphan_tmp, FileAccess.WRITE)
	assert_object(tmp_fa).is_not_null()
	if tmp_fa == null:
		SaveManagerStub.swap_out()
		return
	tmp_fa.store_buffer(valid_bytes)
	tmp_fa.close()
	assert_bool(FileAccess.file_exists(orphan_tmp)).is_true()
	# Act — load; should find ch_01_cp_1.res (prior checkpoint) and skip the orphan.
	var loaded: SaveContext = _stub.load_latest_checkpoint()
	await get_tree().process_frame
	# Assert — loaded the prior checkpoint, not null.
	assert_object(loaded).override_failure_message(
		"AC-SL-17: load_latest_checkpoint must return the prior checkpoint, not null, when a .tmp orphan exists."
	).is_not_null()
	if loaded != null:
		assert_int(loaded.last_cp).override_failure_message(
			"AC-SL-17: loaded checkpoint must be cp=1 (prior), not the orphan's cp=2."
		).is_equal(1)
	# Assert — no save_load_failed emitted (prior checkpoint loaded successfully).
	assert_int(_failed_captures.size()).override_failure_message(
		"AC-SL-17: no save_load_failed should fire when a valid prior checkpoint exists."
	).is_equal(0)
	# Assert — orphan .tmp still on disk (loader is read-only; cleanup is save-side).
	assert_bool(FileAccess.file_exists(orphan_tmp)).override_failure_message(
		"AC-SL-17: orphan .tmp must remain on disk after load (loader does not delete .tmp files)."
	).is_true()
	# G-6 in-body cleanup.
	SaveManagerStub.swap_out()


## AC-SL-17 edge: only a .tmp orphan exists (no prior final checkpoint) →
## load_latest_checkpoint returns null. The orphan is skipped by the filename filter.
func test_ac_sl17_orphan_tmp_only_no_prior_checkpoint_returns_null() -> void:
	# Arrange — no save_checkpoint call; write only the orphan .tmp directly.
	_stub = SaveManagerStub.swap_in()
	var root: String = _stub._save_root_override.rstrip("/")
	var orphan_tmp: String = "%s/slot_1/ch_01_cp_1.tmp.res" % root
	# Write a minimal file so it is non-empty (content doesn't matter; filename filter rejects it).
	var tmp_fa: FileAccess = FileAccess.open(orphan_tmp, FileAccess.WRITE)
	assert_object(tmp_fa).is_not_null()
	if tmp_fa == null:
		SaveManagerStub.swap_out()
		return
	tmp_fa.store_8(0x47)
	tmp_fa.close()
	# Act
	var loaded: SaveContext = _stub.load_latest_checkpoint()
	await get_tree().process_frame
	# Assert — no valid .res found → null return.
	assert_object(loaded).override_failure_message(
		"AC-SL-17 edge: with only a .tmp orphan, load_latest_checkpoint must return null."
	).is_null()
	# Assert — no save_load_failed emitted (empty slot is not a failure per ADR-0003).
	assert_int(_failed_captures.size()).override_failure_message(
		"AC-SL-17 edge: no save_load_failed should fire for an empty slot (only orphan .tmp)."
	).is_equal(0)
	# G-6 in-body cleanup.
	SaveManagerStub.swap_out()


# ═══════════════════════════════════════════════════════════════════════════════
# Failure-path sentinel: save_loaded must NOT emit on failure paths
# ═══════════════════════════════════════════════════════════════════════════════


## Sentinel: on a failure path (corrupt file), save_loaded is NOT emitted;
## save_load_failed IS emitted. Verifies the failure path's exclusive signal
## contract (AC-SL-16 failure path; qa-tester ADVISORY from story-002 review).
func test_save_loaded_does_not_emit_on_failure_path() -> void:
	# Arrange — write valid checkpoint; corrupt it.
	_stub = SaveManagerStub.swap_in()
	var source: SaveContext = _build_valid_source()
	assert_bool(_stub.save_checkpoint(source)).is_true()
	var final_path: String = _final_path_for_stub()
	# Truncate to corrupt.
	var fa: FileAccess = FileAccess.open(final_path, FileAccess.WRITE)
	assert_object(fa).is_not_null()
	if fa == null:
		SaveManagerStub.swap_out()
		return
	fa.store_8(0x00)  # 1 garbage byte
	fa.close()
	# Act — load the corrupt file.
	var loaded: SaveContext = _stub.load_latest_checkpoint()
	await get_tree().process_frame
	# Assert — save_loaded was NOT emitted (failure path only emits save_load_failed).
	assert_int(_loaded_captures.size()).override_failure_message(
		("Sentinel: save_loaded must NOT emit on the failure path. "
		+ "Captures: %s") % str(_loaded_captures)
	).is_equal(0)
	# Assert — save_load_failed WAS emitted exactly once.
	assert_int(_failed_captures.size()).override_failure_message(
		("Sentinel: save_load_failed MUST emit exactly once on the failure path. "
		+ "Captures: %s") % str(_failed_captures)
	).is_equal(1)
	# Sanity — load returned null.
	assert_object(loaded).is_null()
	# G-6 in-body cleanup.
	SaveManagerStub.swap_out()


# ═══════════════════════════════════════════════════════════════════════════════
# Additional edge cases (qa-tester GAPS from /code-review 2026-05-08)
# ═══════════════════════════════════════════════════════════════════════════════


## AC-SL-15 edge (qa-tester GAP): alternate ResourceSaver error codes
## ERR_PERMISSION_DENIED + ERR_OUT_OF_MEMORY both surface as save_load_failed
## with op="save" + reason starting "resource_saver_error:". Confirms the
## seam handles the full Error enum, not just ERR_FILE_CANT_WRITE.
func test_ac_sl15_alternate_error_codes_emit_save_load_failed_with_resource_saver_error_reason() -> void:
	var alternate_errors: Array[Error] = [ERR_FILE_NO_PERMISSION, ERR_OUT_OF_MEMORY]
	for err: Error in alternate_errors:
		# Reset capture state per iteration (before_test runs once per func, not per loop).
		_failed_captures.clear()
		_stub = SaveManagerStub.swap_in()
		_stub._test_force_save_error = err
		var source: SaveContext = _build_valid_source()
		# Act
		var result: bool = _stub.save_checkpoint(source)
		await get_tree().process_frame
		# Assert
		assert_bool(result).override_failure_message(
			"AC-SL-15 edge: save_checkpoint must return false for error code %d." % err
		).is_false()
		assert_int(_failed_captures.size()).override_failure_message(
			("AC-SL-15 edge: expected 1 save_load_failed for error %d; got %d. "
			+ "Captures: %s") % [err, _failed_captures.size(), str(_failed_captures)]
		).is_equal(1)
		var capture: Dictionary = _failed_captures[0]
		assert_str(capture.get("op", "")).is_equal("save")
		var reason: String = capture.get("reason", "")
		assert_bool(reason.begins_with("resource_saver_error:")).override_failure_message(
			("AC-SL-15 edge for error %d: reason must start with 'resource_saver_error:'; "
			+ "got '%s'.") % [err, reason]
		).is_true()
		# Per-iteration cleanup so each error code starts from a fresh stub.
		SaveManagerStub.swap_out()


## AC-SL-16 edge (qa-tester GAP): a wrong-Resource-type file at the slot path
## (e.g. a non-SaveContext .res Resource) causes load_latest_checkpoint to
## return null AND emit save_load_failed with op="load" + reason starting
## "invalid_resource:". Verifies the `not raw is SaveContext` rejection path
## at save_manager.gd:206-208.
func test_ac_sl16_wrong_resource_type_at_slot_path_returns_null_emits_save_load_failed() -> void:
	# Arrange — swap in stub; write a non-SaveContext Resource at the canonical save path.
	_stub = SaveManagerStub.swap_in()
	var final_path: String = _final_path_for_stub()
	# Build a non-SaveContext Resource (use a generic Resource).
	var wrong_type: Resource = Resource.new()
	# Persist directly via ResourceSaver — bypass SaveManager's deep_duplicate + stamp pipeline
	# so the file is well-formed but the Resource class is wrong.
	var save_err: Error = ResourceSaver.save(wrong_type, final_path)
	assert_int(save_err).override_failure_message(
		"AC-SL-16 edge arrange: ResourceSaver.save of plain Resource must succeed; got err=%d." % save_err
	).is_equal(OK)
	assert_bool(FileAccess.file_exists(final_path)).is_true()
	# Act
	var loaded: SaveContext = _stub.load_latest_checkpoint()
	await get_tree().process_frame
	# Assert — load returned null (Resource is not a SaveContext).
	assert_object(loaded).override_failure_message(
		"AC-SL-16 edge: load_latest_checkpoint must return null for a wrong-type Resource at slot path."
	).is_null()
	# Assert — save_load_failed emitted with invalid_resource reason.
	assert_int(_failed_captures.size()).override_failure_message(
		("AC-SL-16 edge: expected 1 save_load_failed for wrong-type Resource; got %d. "
		+ "Captures: %s") % [_failed_captures.size(), str(_failed_captures)]
	).is_equal(1)
	var capture: Dictionary = _failed_captures[0]
	assert_str(capture.get("op", "")).is_equal("load")
	var reason: String = capture.get("reason", "")
	assert_bool(reason.begins_with("invalid_resource:")).override_failure_message(
		("AC-SL-16 edge: reason must start with 'invalid_resource:'; got '%s'.") % reason
	).is_true()
	# G-6 in-body cleanup.
	SaveManagerStub.swap_out()
