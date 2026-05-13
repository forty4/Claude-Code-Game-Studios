## SoundManager — autoload providing the minimum-viable battle SFX layer.
##
## Procedural-only for now: short tones / chords are synthesized into
## AudioStreamWAV resources at boot (no .ogg / .wav files on disk to ship).
## Each tone is intentionally distinct in pitch + envelope so events are
## audibly separable even without a real sound design pass:
##   - SFX_TURN     — short E5 chirp on every turn change
##   - SFX_MOVE     — soft mid A4 on slide
##   - SFX_HIT      — low thud on damage_applied
##   - SFX_DEATH    — long low fade on unit_visual_died
##   - SFX_VICTORY  — C-major triad on chapter_completed
##
## Wiring: SoundManager subscribes to the GameBus signals it can reach (death,
## chapter_completed). Per-frame battle events (move / hit / turn change) are
## emitted as LOCAL controller signals per ADR-0014 §8 — BattleScene calls
## SoundManager.play(...) inline from the existing handlers it already wires.
##
## Replacement plan: when real SFX assets land under assets/audio/sfx/, swap
## `_build_procedural_streams()` for an asset loader keyed by the same SFX_*
## constants — call sites don't change.
##
## NO `class_name` per G-3 autoload rule. Boot pos 10 (depends on GameBus only).
extends Node


# ─── SFX slugs ────────────────────────────────────────────────────────────────

const SFX_TURN: StringName = &"turn"
const SFX_MOVE: StringName = &"move"
const SFX_HIT: StringName = &"hit"
const SFX_DEATH: StringName = &"death"
const SFX_VICTORY: StringName = &"victory"


# ─── Synthesis params ─────────────────────────────────────────────────────────

const _MIX_RATE: int = 22050
const _MASTER_VOLUME_DB: float = -8.0  # placeholder beeps shouldn't be loud


# ─── State ────────────────────────────────────────────────────────────────────

## SFX_* StringName → AudioStreamWAV. Built once in _ready, never mutated.
var _streams: Dictionary = {}

## Small player pool so overlapping events (e.g., back-to-back hits across two
## attackers) don't chop each other. Round-robin allocation.
const _PLAYER_POOL_SIZE: int = 4
var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0

## Master enable — flip false in tests / a future "audio off" setting to fully
## silence the SFX layer without touching call sites. Persisted across runs
## via user://settings.cfg (see set_enabled / _load_preferences).
@export var enabled: bool = true

## Persistent preference file (separate namespace from save games — settings
## should survive save-slot deletion). ConfigFile, not JSON, so values like
## `audio.enabled = false` are human-editable from the user's data folder.
const _SETTINGS_PATH: String = "user://settings.cfg"
const _AUDIO_SECTION: String = "audio"
const _ENABLED_KEY: String = "enabled"


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Load saved SFX preference BEFORE the headless short-circuit so windowed
	# runs honour the user's last toggle. Headless still wins for tests / CI.
	_load_preferences()
	# Headless runs (CI, GdUnit4 with --ignoreHeadlessMode) typically have no
	# audio device; AudioStreamPlayer.play() is a no-op there but the build
	# still costs a few hundred ms — skip when headless to keep the test boot
	# fast and noise-free.
	if DisplayServer.get_name() == "headless":
		enabled = false
		return
	for _i: int in _PLAYER_POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = _MASTER_VOLUME_DB
		add_child(p)
		_players.append(p)
	_build_procedural_streams()
	# GameBus subscriptions for events that aren't already handled inline by
	# BattleScene (death + victory). Per-frame battle events (move/hit/turn) are
	# called explicitly from BattleScene's existing handlers for those signals.
	GameBus.unit_died.connect(_on_unit_died, CONNECT_DEFERRED)
	GameBus.chapter_completed.connect(_on_chapter_completed, CONNECT_DEFERRED)


func _exit_tree() -> void:
	if GameBus.unit_died.is_connected(_on_unit_died):
		GameBus.unit_died.disconnect(_on_unit_died)
	if GameBus.chapter_completed.is_connected(_on_chapter_completed):
		GameBus.chapter_completed.disconnect(_on_chapter_completed)


# ─── Test seam ────────────────────────────────────────────────────────────────

## Mirrors the reset_for_tests() pattern established at BalanceConstants +
## DestinyState + StoryEvent + ScenarioRunner. Re-enables (in case a test
## flipped enabled=false) and reconnects subscriptions if a prior test bulk-
## disconnected (G-28). Safe to call when not loaded as autoload (Node check).
func reset_for_tests() -> void:
	enabled = false  # tests stay silent by default
	if GameBus == null:
		return
	if not GameBus.unit_died.is_connected(_on_unit_died):
		GameBus.unit_died.connect(_on_unit_died, CONNECT_DEFERRED)
	if not GameBus.chapter_completed.is_connected(_on_chapter_completed):
		GameBus.chapter_completed.connect(_on_chapter_completed, CONNECT_DEFERRED)


# ─── Public API ───────────────────────────────────────────────────────────────

## Toggles SFX on/off AND persists the preference to user://settings.cfg so
## the choice survives a game restart. Callers that need a one-shot mute
## (tests, headless boot) can still poke `enabled` directly — set_enabled is
## the path for player-driven settings UI.
func set_enabled(value: bool) -> void:
	enabled = value
	_save_preferences()


## Plays the SFX stream registered for `sfx_id`. Silent no-op when:
##   - enabled is false (tests, "audio off" setting),
##   - the pool isn't built (headless, _ready short-circuited),
##   - sfx_id has no registered stream (typo / un-built event).
func play(sfx_id: StringName) -> void:
	if not enabled or _players.is_empty():
		return
	var stream: AudioStream = _streams.get(sfx_id, null) as AudioStream
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % _players.size()
	player.stream = stream
	player.play()


# ─── Procedural stream construction ───────────────────────────────────────────

func _build_procedural_streams() -> void:
	_streams[SFX_TURN]    = _make_tone(660.0, 0.08, 14.0, 0.18)  # E5 chirp
	_streams[SFX_MOVE]    = _make_tone(440.0, 0.10, 12.0, 0.20)  # A4 soft
	_streams[SFX_HIT]     = _make_tone(180.0, 0.12,  9.0, 0.32)  # low thud
	_streams[SFX_DEATH]   = _make_tone( 90.0, 0.45,  3.5, 0.30)  # long fade
	_streams[SFX_VICTORY] = _make_chord(
		[523.25, 659.25, 783.99],  # C5 + E5 + G5
		0.60, 3.0, 0.22,
	)


## Synthesizes a single-frequency 16-bit mono tone with exponential decay
## envelope. Returns an AudioStreamWAV ready for AudioStreamPlayer.stream.
func _make_tone(freq: float, duration: float, decay_rate: float, amp: float) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var sample_count: int = int(duration * _MIX_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)  # 16-bit = 2 bytes per sample
	var two_pi_f: float = TAU * freq
	for i: int in sample_count:
		var t: float = float(i) / float(_MIX_RATE)
		var envelope: float = exp(-t * decay_rate)
		var sample: float = sin(two_pi_f * t) * envelope * amp
		var s16: int = clampi(int(sample * 32767.0), -32767, 32767)
		# Little-endian 16-bit signed.
		data[i * 2]     = s16 & 0xff
		data[i * 2 + 1] = (s16 >> 8) & 0xff
	stream.data = data
	return stream


## Synthesizes a 16-bit mono chord (sum of sines) with shared decay envelope.
## Used for the victory cue — single tones read as alerts; a triad reads as
## resolution.
func _make_chord(freqs: Array, duration: float, decay_rate: float, amp: float) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var sample_count: int = int(duration * _MIX_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var two_pi: float = TAU
	# Normalize amplitude across N partials so the sum doesn't clip.
	var per_voice_amp: float = amp / float(maxi(freqs.size(), 1))
	for i: int in sample_count:
		var t: float = float(i) / float(_MIX_RATE)
		var envelope: float = exp(-t * decay_rate)
		var sum: float = 0.0
		for f_var: Variant in freqs:
			var f: float = f_var as float
			sum += sin(two_pi * f * t)
		var sample: float = sum * envelope * per_voice_amp
		var s16: int = clampi(int(sample * 32767.0), -32767, 32767)
		data[i * 2]     = s16 & 0xff
		data[i * 2 + 1] = (s16 >> 8) & 0xff
	stream.data = data
	return stream


# ─── GameBus handlers ─────────────────────────────────────────────────────────

func _on_unit_died(_unit_id: int) -> void:
	play(SFX_DEATH)


func _on_chapter_completed(_result: ChapterResult) -> void:
	play(SFX_VICTORY)


# ─── Preferences (user://settings.cfg) ────────────────────────────────────────

## Loads the persisted SFX preference into `enabled`. Silent no-op when the
## file is missing (first run) or unreadable — `enabled` keeps its default.
## ConfigFile.load returns Error; OK means the file existed AND parsed.
func _load_preferences() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(_SETTINGS_PATH)
	if err != OK:
		return
	if cfg.has_section_key(_AUDIO_SECTION, _ENABLED_KEY):
		enabled = bool(cfg.get_value(_AUDIO_SECTION, _ENABLED_KEY, true))


## Writes the current `enabled` flag to user://settings.cfg. Best-effort —
## a failed write (read-only filesystem, etc.) emits push_warning but does
## NOT crash the game; the in-memory toggle still works for this session.
func _save_preferences() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	# Round-trip prior keys so we don't clobber unrelated sections a future
	# settings UI may add. Missing file → empty ConfigFile is the no-op path.
	cfg.load(_SETTINGS_PATH)
	cfg.set_value(_AUDIO_SECTION, _ENABLED_KEY, enabled)
	var err: int = cfg.save(_SETTINGS_PATH)
	if err != OK:
		push_warning(
			"SoundManager._save_preferences: ConfigFile.save returned %d for %s"
			% [err, _SETTINGS_PATH]
		)
