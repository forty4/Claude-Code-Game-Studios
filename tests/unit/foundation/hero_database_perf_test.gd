extends GdUnitTestSuite

## hero_database_perf_test.gd
## TR-hero-database-015 perf budget verification (headless CI permissive gates).
## Covers story-005 AC-1 + AC-9.
##
## Budget headlines per ADR-0007 §Performance Implications:
##   get_hero(id)                  <0.001ms (1µs)     Dictionary hash lookup
##   _load_heroes() cold-start     ~5-15ms MVP         FileAccess + JSON.parse + 9 records
##   get_mvp_roster()              <0.01ms (10µs)      linear scan over 9 heroes
##   get_heroes_by_faction()       <0.05ms (50µs)      linear scan over 9 heroes
##
## CI permissive gates (×3-25 over headline to absorb headless runner load + JIT warm-up):
##   cold-start                    <50ms (50_000µs)
##   1000 × get_hero               <5ms  (5_000µs)
##   100  × get_mvp_roster         <5ms  (5_000µs)
##   100  × get_heroes_by_faction  <25ms (25_000µs)
##
## On-device 100-hero benchmark deferred to Polish-tier per ADR-0007 §11 + N2.
## See docs/tech-debt-register.md TD-045.
##
## G-15: reset BOTH _heroes_loaded AND _heroes in before_test().
## Uses real assets/data/heroes/heroes.json (9-record MVP roster from story-003).
## No synthetic fixture — first get_hero() call triggers lazy-load _load_heroes().

const _HD_PATH: String = "res://src/foundation/hero_database.gd"
var _hd_script: GDScript = load(_HD_PATH) as GDScript

## Real hero IDs from the 9-record MVP roster (story-003 authors; verified 2026-05-01).
const _HERO_IDS: Array[StringName] = [
	&"shu_001_liu_bei",
	&"shu_002_guan_yu",
	&"shu_003_zhang_fei",
	&"wei_001_cao_cao",
	&"wei_005_xiahou_dun",
	&"wu_001_sun_quan",
	&"wu_003_zhou_yu",
	&"qun_001_lu_bu",
	&"qun_004_diao_chan",
]

## G-15 + ADR-0006 §6 obligation: reset BOTH static vars before each test.
## Does NOT pre-load — the cold-start test needs a genuinely cold cache.
func before_test() -> void:
	_hd_script.set("_heroes_loaded", false)
	var empty: Dictionary[StringName, HeroData] = {}
	_hd_script.set("_heroes", empty)


## Safety net: re-reset after each test to prevent state leaks into the next.
func after_test() -> void:
	_hd_script.set("_heroes_loaded", false)
	var empty: Dictionary[StringName, HeroData] = {}
	_hd_script.set("_heroes", empty)


# ── AC-1 / TR-hero-database-015 ───────────────────────────────────────────────


## AC-1 (cold-start): a single get_hero() call from a cold cache triggers _load_heroes()
## (FileAccess.get_file_as_string + JSON.parse + 9-record Dictionary build).
## Gate: total elapsed < 50_000µs (50ms) — generous ×25 over 2ms ADR headline
## to absorb cold-cache + GDScript JIT warm-up on headless CI runners.
func test_get_hero_first_call_lazy_load_under_50ms_median() -> void:
	# Arrange — before_test() already reset to cold cache

	# Act — single call triggers _load_heroes()
	var start_us: int = Time.get_ticks_usec()
	var _h: HeroData = HeroDatabase.get_hero(&"shu_001_liu_bei")
	var elapsed_us: int = Time.get_ticks_usec() - start_us

	# Assert
	assert_int(elapsed_us).override_failure_message(
		("AC-1 (TR-015 cold-start): lazy-load first-call cost %dus exceeds 50_000us (50ms) gate. "
		+ "Gate is ×25 over 2ms ADR headline — check CI runner load or heroes.json size growth. "
		+ "Re-run before flagging a regression (transient scheduler spike possible).")
		% elapsed_us
	).is_less(50_000)


## AC-1 (get_hero throughput): 1000 cached get_hero() calls cycling through the
## 9-record MVP roster. Cache pre-warmed by warmup call; only the loop is timed.
## Gate: sum < 5_000µs (5ms) ≈ 5µs amortised per call (×5 over 1µs ADR headline).
func test_get_hero_cached_call_throughput_1000_under_5ms() -> void:
	# Arrange — warm up to ensure cache is populated before timed window
	var _warmup: HeroData = HeroDatabase.get_hero(&"shu_001_liu_bei")

	# Act — timed window only
	var start_us: int = Time.get_ticks_usec()
	for i: int in 1000:
		var _h: HeroData = HeroDatabase.get_hero(_HERO_IDS[i % _HERO_IDS.size()])
	var elapsed_us: int = Time.get_ticks_usec() - start_us

	# Assert
	assert_int(elapsed_us).override_failure_message(
		("AC-1 (TR-015 get_hero throughput): 1000 cached calls took %dus (gate 5_000us). "
		+ "Per-call amortised: %dus (gate ~5us). "
		+ "Gate is ×5 over 1µs ADR headline — check CI runner load or unexpected _load_heroes() re-invocation.")
		% [elapsed_us, elapsed_us / 1000]
	).is_less(5_000)


## AC-1 (get_mvp_roster throughput): 100 get_mvp_roster() calls (linear scan over 9 records).
## Cache pre-warmed. Gate: sum < 5_000µs ≈ 50µs amortised per call (×5 over 10µs ADR headline).
func test_get_mvp_roster_throughput_100_under_5ms() -> void:
	# Arrange — warm up to populate cache
	var _warmup: Array[HeroData] = HeroDatabase.get_mvp_roster()

	# Act — timed window only
	var start_us: int = Time.get_ticks_usec()
	for i: int in 100:
		var _r: Array[HeroData] = HeroDatabase.get_mvp_roster()
	var elapsed_us: int = Time.get_ticks_usec() - start_us

	# Assert
	assert_int(elapsed_us).override_failure_message(
		("AC-1 (TR-015 get_mvp_roster throughput): 100 calls took %dus (gate 5_000us). "
		+ "Per-call amortised: %dus (gate ~50us). "
		+ "Gate is ×5 over 10µs ADR headline — check CI runner load or unexpected cache reset.")
		% [elapsed_us, elapsed_us / 100]
	).is_less(5_000)


## AC-1 (get_heroes_by_faction throughput): 100 get_heroes_by_faction(0) calls (faction 0 = SHU).
## Cache pre-warmed. Gate: sum < 25_000µs ≈ 250µs amortised per call (×5 over 50µs ADR headline).
func test_get_heroes_by_faction_throughput_100_under_25ms() -> void:
	# Arrange — warm up to populate cache; faction 0 = SHU per HeroData.HeroFaction enum
	var _warmup: Array[HeroData] = HeroDatabase.get_heroes_by_faction(0)

	# Act — timed window only
	var start_us: int = Time.get_ticks_usec()
	for i: int in 100:
		var _r: Array[HeroData] = HeroDatabase.get_heroes_by_faction(0)
	var elapsed_us: int = Time.get_ticks_usec() - start_us

	# Assert
	assert_int(elapsed_us).override_failure_message(
		("AC-1 (TR-015 get_heroes_by_faction throughput): 100 calls took %dus (gate 25_000us). "
		+ "Per-call amortised: %dus (gate ~250us). "
		+ "Gate is ×5 over 50µs ADR headline — check CI runner load or unexpected cache reset.")
		% [elapsed_us, elapsed_us / 100]
	).is_less(25_000)
