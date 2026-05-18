## ProgressArchive autoload tests (2026-05-18, S66).
##
## Covers cross-campaign meta-progression archive:
##   - unlock_signature records key + first-unlock metadata
##   - unlock_signature is idempotent (first-unlock metadata preserved)
##   - get_unlocked_keys / get_unlocked_count return current state
##   - get_unlock_metadata returns {} for unknown keys
##   - disk persist roundtrip — _load_from_disk recovers state
##   - reset_for_tests clears in-memory state AND deletes archive file
##   - empty key is silently rejected (defensive)
##
## Test isolation: every test starts with `ProgressArchive.reset_for_tests()`
## (G-28 5th-autoload pattern). The autoload's _ready already ran at boot, but
## reset clears any state left over from earlier tests in this run.

extends GdUnitTestSuite


# ─── Helpers ──────────────────────────────────────────────────────────────────


func before_test() -> void:
	ProgressArchive.reset_for_tests()


func after_test() -> void:
	ProgressArchive.reset_for_tests()


# ─── unlock_signature ────────────────────────────────────────────────────────


func test_unlock_signature_records_key_and_first_unlock_metadata() -> void:
	ProgressArchive.unlock_signature("WIN_changsha_wei_yan_defects", "ch13_changsha_veteran")
	var keys: PackedStringArray = ProgressArchive.get_unlocked_keys()
	assert_int(keys.size()).is_equal(1)
	assert_bool("WIN_changsha_wei_yan_defects" in keys).is_true()

	var meta: Dictionary = ProgressArchive.get_unlock_metadata("WIN_changsha_wei_yan_defects")
	assert_str(meta.get("first_chapter_id", "") as String).is_equal("ch13_changsha_veteran")
	assert_int(meta.get("first_unlocked_unix", 0) as int).is_greater(0)


func test_unlock_signature_is_idempotent_preserves_first_metadata() -> void:
	ProgressArchive.unlock_signature("WIN_luofeng_pang_tong_lives", "ch16_luofeng_slope")
	var first_meta: Dictionary = ProgressArchive.get_unlock_metadata("WIN_luofeng_pang_tong_lives")
	var first_unix: int = first_meta.get("first_unlocked_unix", 0) as int
	# Repeat unlock with a different chapter_id — must preserve original metadata.
	ProgressArchive.unlock_signature("WIN_luofeng_pang_tong_lives", "ch99_replay")
	var second_meta: Dictionary = ProgressArchive.get_unlock_metadata("WIN_luofeng_pang_tong_lives")
	assert_str(second_meta.get("first_chapter_id", "") as String).is_equal("ch16_luofeng_slope")
	assert_int(second_meta.get("first_unlocked_unix", 0) as int).is_equal(first_unix)
	# Count stays 1 — no duplicate entry.
	assert_int(ProgressArchive.get_unlocked_count()).is_equal(1)


func test_unlock_signature_empty_key_is_silently_rejected() -> void:
	ProgressArchive.unlock_signature("", "ch01_anything")
	assert_int(ProgressArchive.get_unlocked_count()).is_equal(0)


func test_get_unlock_metadata_returns_empty_when_key_unknown() -> void:
	var meta: Dictionary = ProgressArchive.get_unlock_metadata("WIN_never_unlocked")
	assert_bool(meta.is_empty()).is_true()


func test_get_unlocked_count_reflects_all_keys() -> void:
	ProgressArchive.unlock_signature("WIN_changsha_wei_yan_defects", "ch13_changsha_veteran")
	ProgressArchive.unlock_signature("WIN_luofeng_pang_tong_lives", "ch16_luofeng_slope")
	ProgressArchive.unlock_signature("WIN_fancheng_guan_yu_survives", "ch20_fancheng_pursuit")
	assert_int(ProgressArchive.get_unlocked_count()).is_equal(3)


# ─── Disk persistence ─────────────────────────────────────────────────────────


func test_disk_persist_roundtrip_recovers_state_via_load_from_disk() -> void:
	# Arrange: write two unlocks (each unlock_signature flushes to disk).
	ProgressArchive.unlock_signature("WIN_zhangfei_survives", "ch21_zhangfei_avenge")
	ProgressArchive.unlock_signature("WIN_yiling_liu_bei_survives", "ch22_yiling_burn")
	assert_int(ProgressArchive.get_unlocked_count()).is_equal(2)

	# Act: clear in-memory state (private; bypass reset_for_tests which would
	# also delete the disk file), then reload from disk.
	ProgressArchive._signature_unlocks.clear()
	assert_int(ProgressArchive.get_unlocked_count()).is_equal(0)
	ProgressArchive._load_from_disk()

	# Assert: state recovered.
	assert_int(ProgressArchive.get_unlocked_count()).is_equal(2)
	var keys: PackedStringArray = ProgressArchive.get_unlocked_keys()
	assert_bool("WIN_zhangfei_survives" in keys).is_true()
	assert_bool("WIN_yiling_liu_bei_survives" in keys).is_true()
	# Metadata also roundtripped.
	var meta: Dictionary = ProgressArchive.get_unlock_metadata("WIN_zhangfei_survives")
	assert_str(meta.get("first_chapter_id", "") as String).is_equal("ch21_zhangfei_avenge")


# ─── reset_for_tests ─────────────────────────────────────────────────────────


func test_reset_for_tests_clears_in_memory_and_disk_file() -> void:
	ProgressArchive.unlock_signature("WIN_changsha_wei_yan_defects", "ch13_changsha_veteran")
	assert_bool(FileAccess.file_exists("user://progress_archive.cfg")).is_true()
	ProgressArchive.reset_for_tests()
	assert_int(ProgressArchive.get_unlocked_count()).is_equal(0)
	assert_bool(FileAccess.file_exists("user://progress_archive.cfg")).is_false()


func test_reset_for_tests_is_idempotent_when_archive_absent() -> void:
	# No prior unlock → no file exists → reset is no-op (no crash).
	assert_bool(FileAccess.file_exists("user://progress_archive.cfg")).is_false()
	ProgressArchive.reset_for_tests()
	assert_int(ProgressArchive.get_unlocked_count()).is_equal(0)
