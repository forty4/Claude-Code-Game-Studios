## chapter_visuals_hero_accent_test.gd
##
## Verifies the per-hero accent border palette in chapter_visuals.gd:
##   - Every MVP hero has a distinct accent color (no collisions within faction).
##   - Unknown hero_ids fall back to a faction-tuned highlight tone.
##   - The reserved art-bible §4.1 colors (주홍 #C0392B, 금색 #D4A017) are NOT
##     used as accents — those tones are exclusive destiny-branch reveal channels.
extends GdUnitTestSuite

const ChapterVisualsScript: GDScript = preload("res://src/feature/battle_scene/chapter_visuals.gd")

const RESERVED_VERMILION: Color = Color("c0392b")
const RESERVED_GOLD: Color = Color("d4a017")


func _new_visuals() -> ChapterVisuals:
	var cv: ChapterVisuals = ChapterVisualsScript.new()
	auto_free(cv)
	return cv


func test_each_mvp_hero_has_a_distinct_accent_color() -> void:
	var cv: ChapterVisuals = _new_visuals()
	var hero_ids: Array[StringName] = [
		&"shu_001_liu_bei",
		&"shu_002_guan_yu",
		&"shu_003_zhang_fei",
		&"wei_001_cao_cao",
		&"wei_005_xiahou_dun",
		&"wei_006_zhang_liao",
		&"wei_007_yu_jin",
		&"wei_008_xu_chu",
	]
	var seen: Dictionary = {}  # color string → first hero_id that used it
	for hid: StringName in hero_ids:
		# Lookup uses the faction the hero actually belongs to (Shu = side 0,
		# Wei = side 1) but we're reading the explicit palette, not the fallback,
		# so the side argument doesn't matter here.
		var c: Color = cv._get_hero_accent(hid, 0)
		var key: String = c.to_html(false)
		assert_bool(seen.has(key)).override_failure_message(
			"%s and %s share accent color #%s — generals are not visually distinct"
			% [String(seen.get(key, &"")), String(hid), key]
		).is_false()
		seen[key] = hid


func test_unknown_hero_id_falls_back_to_faction_tone() -> void:
	var cv: ChapterVisuals = _new_visuals()
	var p: Color = cv._get_hero_accent(&"shu_999_phantom", 0)
	var e: Color = cv._get_hero_accent(&"wei_999_phantom", 1)
	assert_str(p.to_html(false)).is_not_equal(e.to_html(false))
	# Both fallbacks are pale highlights, distinct from the saturated palette
	# entries — they should be unique within the seen-color set.
	for hid: StringName in [
		&"shu_001_liu_bei", &"shu_002_guan_yu", &"shu_003_zhang_fei",
		&"wei_001_cao_cao", &"wei_005_xiahou_dun", &"wei_006_zhang_liao",
		&"wei_007_yu_jin", &"wei_008_xu_chu",
	]:
		var explicit: Color = cv._get_hero_accent(hid, 0)
		assert_str(p.to_html(false)).override_failure_message(
			"player fallback collides with explicit accent for %s" % String(hid)
		).is_not_equal(explicit.to_html(false))


func test_no_hero_accent_uses_reserved_palette() -> void:
	# Art-bible §4.1: 주홍 #C0392B and 금색 #D4A017 are reserved destiny-branch
	# reveal tones — using them as routine accent borders would conflict with
	# the "역전 성공" / canonical seal visual signal channels.
	var cv: ChapterVisuals = _new_visuals()
	var palette: Dictionary = ChapterVisualsScript.HERO_ACCENT_BY_HERO_ID
	for hid: Variant in palette.keys():
		var c: Color = palette[hid] as Color
		assert_str(c.to_html(false)).override_failure_message(
			"hero %s uses reserved 주홍 #C0392B" % String(hid)
		).is_not_equal(RESERVED_VERMILION.to_html(false))
		assert_str(c.to_html(false)).override_failure_message(
			"hero %s uses reserved 금색 #D4A017" % String(hid)
		).is_not_equal(RESERVED_GOLD.to_html(false))
	# Fallbacks too.
	assert_str(cv._get_hero_accent(&"shu_zzz", 0).to_html(false)) \
		.is_not_equal(RESERVED_VERMILION.to_html(false))
	assert_str(cv._get_hero_accent(&"shu_zzz", 0).to_html(false)) \
		.is_not_equal(RESERVED_GOLD.to_html(false))
	assert_str(cv._get_hero_accent(&"wei_zzz", 1).to_html(false)) \
		.is_not_equal(RESERVED_VERMILION.to_html(false))
	assert_str(cv._get_hero_accent(&"wei_zzz", 1).to_html(false)) \
		.is_not_equal(RESERVED_GOLD.to_html(false))
