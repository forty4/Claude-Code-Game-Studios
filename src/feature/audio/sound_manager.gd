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
## Session-16: hero active skill activation — bright two-note sting that's
## clearly distinct from SFX_HIT (low thud) and SFX_VICTORY (full chord).
## Generic fallback for unwired skill_ids per _sfx_for_skill in battle_scene.
const SFX_SKILL: StringName = &"skill"
## Session-20: per-skill variants. Each maps to one of the 7 wired hero
## skills so the audio sells the distinction at a glance (offensive = sharper
## & lower; support = warmer & rising; utility = ethereal & pulsing).
const SFX_SKILL_DRAGON_BLADE: StringName    = &"skill_dragon_blade"    # 관우
const SFX_SKILL_THUNDER_ROAR: StringName    = &"skill_thunder_roar"    # 장비
const SFX_SKILL_INSPIRE: StringName         = &"skill_inspire"         # 유비
const SFX_SKILL_PIERCING_VOLLEY: StringName = &"skill_piercing_volley" # 황충
const SFX_SKILL_CHARM: StringName           = &"skill_charm"           # 초선
const SFX_SKILL_STRATEGIST: StringName      = &"skill_strategist"      # 조조
const SFX_SKILL_NAVAL_STRATEGY: StringName  = &"skill_naval_strategy"  # 주유
## Session-16: critical hit (REAR-direction strike). Sharp descending two-note
## "thwack" — a punctuation distinct from SFX_HIT, paired with camera shake +
## "치명타!" popup in battle_scene.
const SFX_CRITICAL: StringName = &"critical"
## Session-16: mid-battle kill notification. Bright rising flourish cue paired
## with the "X 처치!" popup so the player feels the achievement of finishing
## an enemy. Shorter than SFX_VICTORY (the chapter end chord) so it doesn't
## clash with subsequent action.
const SFX_KILL: StringName = &"kill"
## Session-26: FIRE-tile round-start damage cue. Brief noise-burst "tssss" hiss
## — distinct from SFX_HIT (which is a tonal thud) so the player reads
## "environmental tick, not a swing." Quiet amplitude so it slips under the
## round-start fanfare/turn-roll/AI-deferred handler cue stack without
## competing for attention (session-23 originally deferred this for that
## reason; session-26 ships at low amp to honour the budget).
const SFX_FIRE_TICK: StringName = &"fire_tick"

## Music slugs — separate stream pool from SFX so they can be muted
## independently (player may want music off but SFX on, or vice versa).
const MUSIC_BATTLE_AMBIENT: StringName = &"battle_ambient"
## S60 — chapter-specific BGM. Distinct keys + LFO speeds + per-partial gains
## per chapter mood. Same procedural-drone structure as MUSIC_BATTLE_AMBIENT
## but tuned so each chapter reads audibly distinct on chapter entry:
##   ch01 장판파       — D minor, urgent (2 LFO cycles / 16s loop)
##   ch02 장판교       — A power chord, stoic (1 LFO cycle, low octave)
##   ch03 하구 외곽    — C major, traveling (1.5 LFO cycles)
##   ch04 적벽 prelude — E major, warm hope (1 LFO cycle, brighter)
##   ch05 적벽 본전    — F minor, climax (2.5 LFO cycles, denser)
const MUSIC_CH01_CHANGBANPO: StringName       = &"music_ch01"
const MUSIC_CH02_CHANGBAN_BRIDGE: StringName  = &"music_ch02"
const MUSIC_CH03_XIAKOU: StringName           = &"music_ch03"
const MUSIC_CH04_CHIBI_PRELUDE: StringName    = &"music_ch04"
const MUSIC_CH05_CHIBI_MAIN: StringName       = &"music_ch05"


# ─── Synthesis params ─────────────────────────────────────────────────────────

const _MIX_RATE: int = 22050
const _MASTER_VOLUME_DB: float = -8.0  # placeholder beeps shouldn't be loud
## Music sits well below SFX so combat cues stay legible. S60 — bumped from
## -22dB ("거의 웅 소리 정도밖에 안 들려" user feedback) to -14dB; combined with
## the new melodic chapter themes (vs. pre-S60 ambient drone) the music now
## reads as actual composition without overwhelming combat SFX.
const _MUSIC_VOLUME_DB: float = -14.0
## Loop length in seconds. 16s is long enough that the listener loses track
## of the seam, short enough to fit in memory at 22.05 kHz mono 16-bit
## (16 × 22050 × 2 = 706 KB).
const _MUSIC_LOOP_SECONDS: float = 16.0


# ─── State ────────────────────────────────────────────────────────────────────

## SFX_* StringName → AudioStreamWAV. Built once in _ready, never mutated.
var _streams: Dictionary = {}

## Small player pool so overlapping events (e.g., back-to-back hits across two
## attackers) don't chop each other. Round-robin allocation.
const _PLAYER_POOL_SIZE: int = 4
var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0

## Master SFX enable — flip false in tests / "audio off" setting to fully
## silence the SFX layer without touching call sites. Persisted across runs
## via user://settings.cfg (see set_enabled / _load_preferences).
@export var enabled: bool = true

## Master music enable — independent of SFX so the player can mute either
## independently. Persisted alongside SFX prefs in user://settings.cfg.
@export var music_enabled: bool = true

## Persistent preference file (separate namespace from save games — settings
## should survive save-slot deletion). ConfigFile, not JSON, so values like
## `audio.enabled = false` are human-editable from the user's data folder.
const _SETTINGS_PATH: String = "user://settings.cfg"
const _AUDIO_SECTION: String = "audio"
const _ENABLED_KEY: String = "enabled"
const _MUSIC_ENABLED_KEY: String = "music_enabled"

## Music stream pool — distinct from SFX pool because music loops and we want
## to be able to start/stop/swap independently. Single player is enough for now
## (no music crossfade yet); a 2nd player can be added later for crossfade.
var _music_player: AudioStreamPlayer = null
## Music streams keyed by music slug (e.g. MUSIC_BATTLE_AMBIENT → AudioStreamWAV).
var _music_streams: Dictionary = {}
## Currently-playing music slug, &"" when stopped. Read by tests + UI.
var _current_music: StringName = &""


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
	# Music player — single instance, runs on the Master bus at lower volume so
	# combat SFX stay legible. Streams are pre-built; play_music swaps them in.
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = _MUSIC_VOLUME_DB
	add_child(_music_player)
	_build_procedural_streams()
	_build_procedural_music_streams()
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
	music_enabled = false  # session-12: also silence music channel
	_current_music = &""
	if _music_player != null and _music_player.playing:
		_music_player.stop()
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


## Toggles music on/off AND persists the preference. Mirrors set_enabled for
## the music channel. Stops the currently-playing track when disabled;
## resumes the last-requested track when re-enabled (if any).
func set_music_enabled(value: bool) -> void:
	music_enabled = value
	if not music_enabled:
		# Honour the toggle immediately — if a track is playing, stop it.
		# `_current_music` is preserved so a re-enable can resume the same.
		if _music_player != null and _music_player.playing:
			_music_player.stop()
	else:
		# Re-enable: restart the cached track if one was previously requested.
		if _current_music != &"":
			play_music(_current_music)
	_save_preferences()


## Starts looping playback of the music stream registered for `music_id`.
## Silent no-op when:
##   - music_enabled is false (player has muted music; cache slug for resume),
##   - the music player isn't built (headless),
##   - music_id has no registered stream (typo / un-built track).
## Idempotent: calling with the same id while it's already playing does nothing
## (avoids loop-restart pop). Different id → smooth swap (no crossfade yet).
func play_music(music_id: StringName) -> void:
	_current_music = music_id  # cache regardless so set_music_enabled can resume
	if not music_enabled or _music_player == null:
		return
	var stream: AudioStream = _music_streams.get(music_id, null) as AudioStream
	if stream == null:
		return
	if _music_player.playing and _music_player.stream == stream:
		return  # already playing this exact stream — no restart pop
	_music_player.stream = stream
	_music_player.play()


## Stops music playback if anything is playing. Clears the cached `_current_music`
## so a subsequent set_music_enabled(true) does NOT auto-resume — call play_music
## explicitly to restart. Silent no-op when nothing is playing.
func stop_music() -> void:
	_current_music = &""
	if _music_player != null and _music_player.playing:
		_music_player.stop()


## Plays the SFX stream registered for `sfx_id`. Silent no-op when:
##   - enabled is false (tests, "audio off" setting),
##   - the pool isn't built (headless, _ready short-circuited),
##   - sfx_id has no registered stream (typo / un-built event).
##
## Session-32 — optional `volume_offset_db` shifts the player pool's
## volume_db for THIS one fire only, then restores the master baseline.
## Used by per-skill SFX side audit: AI-side skill activations pass
## -4.0 so the cue is audibly quieter than player-side ("their skill,
## not mine" cue). Default 0.0 preserves the pre-S32 behaviour.
func play(sfx_id: StringName, volume_offset_db: float = 0.0) -> void:
	if not enabled or _players.is_empty():
		return
	var stream: AudioStream = _streams.get(sfx_id, null) as AudioStream
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % _players.size()
	player.stream = stream
	player.volume_db = _MASTER_VOLUME_DB + volume_offset_db
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
	# G5 → C6 ascending sting — short, bright, clearly "ability fired". Decay
	# 7.0 keeps it punchy without dragging into the next click.
	_streams[SFX_SKILL] = _make_chord(
		[783.99, 1046.50],  # G5 + C6
		0.22, 7.0, 0.26,
	)
	# E5 + G3 descending punch — bright top + deep crunch underneath. Decay 8.5
	# is just shy of SFX_DEATH so the hit hangs a beat longer than a normal
	# attack but doesn't drag into the next move.
	_streams[SFX_CRITICAL] = _make_chord(
		[659.25, 196.00],  # E5 (bright) + G3 (low thump)
		0.28, 8.5, 0.34,
	)
	# A5 + C#6 ascending flourish — bright triumphant pair, shorter decay than
	# SFX_VICTORY (which is the full chapter close). Reads as "small win".
	_streams[SFX_KILL] = _make_chord(
		[880.00, 1108.73],  # A5 + C#6 (major third up)
		0.30, 6.0, 0.28,
	)
	# ── Session-20: per-skill SFX variants ─────────────────────────────────────
	# 관우 dragon_blade: sharp ringing strike — C6 + E6 + G6 (major triad up).
	# Decay 6.5 keeps the ring brief but resonant.
	_streams[SFX_SKILL_DRAGON_BLADE] = _make_chord(
		[1046.50, 1318.51, 1567.98],  # C6 + E6 + G6
		0.26, 6.5, 0.26,
	)
	# 장비 thunder_roar: low G2 thud + high E5 crack — earthy + sharp pair so
	# the burst reads as "thunderclap". Longer decay (4.0) lets the rumble
	# linger one beat longer.
	_streams[SFX_SKILL_THUNDER_ROAR] = _make_chord(
		[98.00, 659.25],  # G2 (rumble) + E5 (crack)
		0.32, 4.0, 0.32,
	)
	# 유비 inspire: warm major triad C5 + E5 + G5 ascending — supportive
	# resolution chord, classic "rally" feel. Same triad as SFX_VICTORY but
	# punchier decay (8.0 vs 3.0) so it doesn't muddle the chapter-end cue.
	_streams[SFX_SKILL_INSPIRE] = _make_chord(
		[523.25, 659.25, 783.99],  # C5 + E5 + G5
		0.24, 8.0, 0.24,
	)
	# 황충 piercing_volley: rapid high pizzicato — B5 alone with very fast
	# decay (12.0). Reads as "arrows flying" — staccato + sharp.
	_streams[SFX_SKILL_PIERCING_VOLLEY] = _make_chord(
		[987.77],  # B5
		0.18, 12.0, 0.30,
	)
	# 초선 charm: ethereal high pair G6 + B6 — bell-like, "spell cast" feel.
	# Slow decay (5.0) for a slight reverberant tail.
	_streams[SFX_SKILL_CHARM] = _make_chord(
		[1567.98, 1975.53],  # G6 + B6 (major third up, high register)
		0.30, 5.0, 0.22,
	)
	# 조조 strategist: dark low C3 + G3 perfect fifth — battlefield-wide
	# announcement, ominous. Decay 5.5 sits between thunder and inspire.
	_streams[SFX_SKILL_STRATEGIST] = _make_chord(
		[130.81, 196.00],  # C3 + G3 (perfect fifth, low register)
		0.34, 5.5, 0.30,
	)
	# 주유 naval_strategy: D4 + A4 with extended decay (4.5) — pulsing,
	# trance-like quality reads as "tactical disruption / stun pulse".
	_streams[SFX_SKILL_NAVAL_STRATEGY] = _make_chord(
		[293.66, 440.00],  # D4 + A4 (perfect fifth)
		0.30, 4.5, 0.26,
	)
	# Session-26: FIRE tile tick. Noise burst (not a sinusoid) with brief
	# duration + moderate decay + low amp — reads as a quiet "tssss" hiss.
	# Amp 0.18 sits comfortably below SFX_HIT (0.32) so the round-start cue
	# stack stays legible.
	_streams[SFX_FIRE_TICK] = _make_noise_burst(0.18, 6.0, 0.18)


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


## Session-26 — synthesizes a 16-bit mono noise-burst with exponential decay.
## Used for the FIRE tile tick (single hiss; no tonal centre). Deterministic
## LCG seeded with a fixed constant so the PCM buffer is byte-identical across
## runs and platforms — keeps tests stable (no Godot RNG state to thread).
##
## LCG params follow the glibc rand() linear congruential generator:
##   X(n+1) = (a * X(n) + c) mod 2^31, with a=1103515245, c=12345.
## The low byte alone is too patterned to read as noise (banding artifacts);
## we use bits 16..30 → centre around 0 → scale to [-1, 1] for a clean burst.
func _make_noise_burst(duration: float, decay_rate: float, amp: float) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var sample_count: int = int(duration * _MIX_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var lcg_state: int = 0x12345678  # deterministic seed; same buffer every build
	for i: int in sample_count:
		# LCG step. 0x7FFFFFFF mask = 31-bit modulus (avoid sign issues).
		lcg_state = (lcg_state * 1103515245 + 12345) & 0x7FFFFFFF
		# Pull middle 15 bits — gives 32768 distinct values, well-distributed.
		var raw: int = (lcg_state >> 16) & 0x7FFF
		# Map [0, 32767] → [-1.0, 1.0] centred at 0.
		var noise: float = (float(raw) / 16383.5) - 1.0
		var t: float = float(i) / float(_MIX_RATE)
		var envelope: float = exp(-t * decay_rate)
		var sample: float = noise * envelope * amp
		var s16: int = clampi(int(sample * 32767.0), -32767, 32767)
		# Little-endian 16-bit signed.
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

## Loads the persisted SFX + music preferences into `enabled` / `music_enabled`.
## Silent no-op when the file is missing (first run) or unreadable — flags
## keep their @export defaults. ConfigFile.load returns Error; OK = parsed.
func _load_preferences() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(_SETTINGS_PATH)
	if err != OK:
		return
	if cfg.has_section_key(_AUDIO_SECTION, _ENABLED_KEY):
		enabled = bool(cfg.get_value(_AUDIO_SECTION, _ENABLED_KEY, true))
	if cfg.has_section_key(_AUDIO_SECTION, _MUSIC_ENABLED_KEY):
		music_enabled = bool(cfg.get_value(_AUDIO_SECTION, _MUSIC_ENABLED_KEY, true))


## Writes the current `enabled` + `music_enabled` flags to user://settings.cfg.
## Best-effort — a failed write (read-only filesystem, etc.) emits push_warning
## but does NOT crash; the in-memory toggle still works for this session.
func _save_preferences() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	# Round-trip prior keys so we don't clobber unrelated sections a future
	# settings UI may add. Missing file → empty ConfigFile is the no-op path.
	cfg.load(_SETTINGS_PATH)
	cfg.set_value(_AUDIO_SECTION, _ENABLED_KEY, enabled)
	cfg.set_value(_AUDIO_SECTION, _MUSIC_ENABLED_KEY, music_enabled)
	var err: int = cfg.save(_SETTINGS_PATH)
	if err != OK:
		push_warning(
			"SoundManager._save_preferences: ConfigFile.save returned %d for %s"
			% [err, _SETTINGS_PATH]
		)


# ─── Procedural music synthesis ───────────────────────────────────────────────

## Builds the music streams. 1 generic ambient + 5 chapter-specific themes.
## Each chapter drone passes distinct (root_hz, partial_intervals, gains,
## lfo_cycles) so the listener gets an audibly different "place" cue on
## chapter entry. See `_make_drone` for the synthesis model.
func _build_procedural_music_streams() -> void:
	_music_streams[MUSIC_BATTLE_AMBIENT] = _make_battle_drone(_MUSIC_LOOP_SECONDS)
	# S60 chapter themes — bass drone + melodic phrase + rhythmic kick.
	# Each call: (bpm, beats_per_loop, bass_root_hz, melody_freqs[16], kick_freq).
	# Melody arrays are 16 eighth-notes; bass plays the root continuously.
	# Loop duration = beats × (60/bpm). At 16 beats × 80 BPM = 12s; × 100 = 9.6s.

	# ch01 장판파 — D minor descending melody. Root D2. Melody phrase moves
	# D4-F4-A4-G4-F4-D4-C♯4-D4 (descent with leading tone return), repeating —
	# 비탄/절박 mood. 100 BPM (urgent).
	_music_streams[MUSIC_CH01_CHANGBANPO] = _make_chapter_theme(
		100, 16, 73.42,
		[293.66, 349.23, 440.00, 392.00, 349.23, 293.66, 277.18, 293.66,
		 293.66, 349.23, 440.00, 523.25, 440.00, 349.23, 293.66, 293.66],
		73.42 * 0.5  # kick at D1 sub
	)

	# ch02 장판교 — A power chord, marching stand. Root A1 (low). Melody alternates
	# A3-A3-E4-A3 / A3-A3-D4-C♯4 (simple defiant motif, sustained doom). 80 BPM
	# (steady march, not running).
	_music_streams[MUSIC_CH02_CHANGBAN_BRIDGE] = _make_chapter_theme(
		80, 16, 55.00,
		[220.00, 220.00, 329.63, 220.00, 220.00, 220.00, 293.66, 277.18,
		 220.00, 220.00, 329.63, 329.63, 293.66, 277.18, 220.00, 220.00],
		55.00 * 0.5
	)

	# ch03 하구 외곽 — C pentatonic wandering. Root C2. Melody C-E-G-E-A-G-E-C
	# (pentatonic, traveling mood). 90 BPM (walking pace).
	_music_streams[MUSIC_CH03_XIAKOU] = _make_chapter_theme(
		90, 16, 65.41,
		[261.63, 329.63, 392.00, 329.63, 440.00, 392.00, 329.63, 261.63,
		 293.66, 329.63, 392.00, 440.00, 523.25, 440.00, 392.00, 329.63],
		65.41 * 0.5
	)

	# ch04 적벽 prelude — E major rising, alliance warmth. Root E2. Melody
	# E-G♯-B-G♯-A-E-F♯-G♯ — rising motif with the cardinal major-third tone
	# (G♯4 = 415.30 Hz) as the warmth anchor. 70 BPM (deliberate).
	_music_streams[MUSIC_CH04_CHIBI_PRELUDE] = _make_chapter_theme(
		70, 16, 82.41,
		[329.63, 415.30, 493.88, 415.30, 440.00, 329.63, 369.99, 415.30,
		 329.63, 415.30, 493.88, 587.33, 493.88, 440.00, 415.30, 329.63],
		82.41 * 0.5
	)

	# ch05 적벽 본전 — F minor climax, fire intensity. Root F2. Melody
	# F-A♭-C-A♭-B♭-C-D♭-C — climbing with minor third + flat 6th + flat 5th
	# tritone tension. 110 BPM (intense). Highest tempo of the 5.
	_music_streams[MUSIC_CH05_CHIBI_MAIN] = _make_chapter_theme(
		110, 16, 87.31,
		[349.23, 415.30, 523.25, 415.30, 466.16, 523.25, 554.37, 523.25,
		 349.23, 415.30, 523.25, 622.25, 523.25, 466.16, 415.30, 349.23],
		87.31 * 0.5
	)


## Maps a ChapterDefinition.chapter_id (or StringName) to the appropriate
## chapter-specific music slug. Returns MUSIC_BATTLE_AMBIENT as a structural
## fallback when chapter_id is unknown (e.g., test fixtures, future authored
## chapters that haven't been theme-tuned yet) so play_music never errors on
## unrecognized input. Public — BattleScene calls this at battle init.
func music_id_for_chapter(chapter_id: StringName) -> StringName:
	match chapter_id:
		# mvp_shu (촉) line.
		&"ch01_changbanpo":         return MUSIC_CH01_CHANGBANPO
		&"ch02_changban_bridge":    return MUSIC_CH02_CHANGBAN_BRIDGE
		&"ch03_xiakou_outskirts":   return MUSIC_CH03_XIAKOU
		&"ch04_chibi_prelude":      return MUSIC_CH04_CHIBI_PRELUDE
		&"ch05_chibi_main":         return MUSIC_CH05_CHIBI_MAIN
		# mvp_wei (위) line — reuses the existing 5 themes by thematic match:
		#   bowang_slope (ambush, urgent)  → CH01 D-minor descending
		#   xinye_fire (city ablaze)        → CH05 F-minor fire climax
		#   changban_pursuit (the bridge)   → CH02 bridge A-power-chord
		#   jiangling_conquest (Wu landing) → CH04 alliance warmth
		#   chibi_burn (Wei survives fire)  → CH05 F-minor fire climax
		&"ch01_bowang_slope":       return MUSIC_CH01_CHANGBANPO
		&"ch02_xinye_fire":         return MUSIC_CH05_CHIBI_MAIN
		&"ch03_changban_pursuit":   return MUSIC_CH02_CHANGBAN_BRIDGE
		&"ch04_jiangling_conquest": return MUSIC_CH04_CHIBI_PRELUDE
		&"ch05_chibi_burn":         return MUSIC_CH05_CHIBI_MAIN
		_:                          return MUSIC_BATTLE_AMBIENT


## S60 — chapter theme synthesizer. Renders bass drone + 16-note melodic
## phrase + per-beat kick into a single seamless loop. Replaces the original
## ambient drone (which user feedback flagged as "거의 웅 소리 정도" — too
## drone-like to read as music).
##
## Composition model:
##   - BASS: sustained low sine at `bass_root_hz`, modulated by slow LFO
##     (1 cycle per loop) so the foundation breathes.
##   - MELODY: 16 eighth-notes from `melody_freqs`. Each note has attack-decay
##     envelope (sharp attack, ~80% decay over the note duration) so each note
##     reads as distinct articulation, not a wall of pitch.
##   - KICK: short noise burst + low sub-sine at the start of every beat.
##     Provides rhythmic anchor without competing with combat SFX (very brief,
##     ~30ms decay).
##
## Loop seam: loop duration = beats × (60/bpm). Bass freq × loop_duration may
## not be integer cycles (small phase drift at seam, intentional — same model
## as the pre-S60 drone's E3 partial).
##
## Parameters:
##   bpm           — tempo in beats per minute (60-120 typical)
##   beats         — total beats in the loop (16 for the 5 chapter themes)
##   bass_root_hz  — bass drone frequency (e.g., 73.42 for D2)
##   melody_freqs  — Array of `beats` floats, one frequency per beat (Hz). 0
##                   means rest (no melody note that beat).
##   kick_hz       — fundamental of the kick sub-thump (Hz, ~30-60 typical)
func _make_chapter_theme(
	bpm: int,
	beats: int,
	bass_root_hz: float,
	melody_freqs: Array,
	kick_hz: float,
) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var seconds_per_beat: float = 60.0 / float(bpm)
	var duration: float = float(beats) * seconds_per_beat
	var sample_count: int = int(duration * _MIX_RATE)
	stream.loop_begin = 0
	stream.loop_end = sample_count
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var two_pi: float = TAU
	# Per-component gains (sum well below 1.0 to leave headroom for envelopes).
	var bass_gain: float = 0.32
	var melody_gain: float = 0.42
	var kick_gain: float = 0.55
	# Bass LFO — slow breathing, 1 cycle per loop.
	var bass_lfo_freq: float = 1.0 / duration
	# Kick envelope time-constant (decay rate; larger = faster decay).
	var kick_decay: float = 60.0
	# Melody envelope time-constant — sharp attack (first ~5% of beat) +
	# exponential decay over the rest. tau ~3 over the beat = drops to ~5%
	# by beat end so successive notes don't pile.
	var melody_decay: float = 3.0 / seconds_per_beat
	# Attack ramp duration (seconds) — sharp but not click.
	var melody_attack: float = 0.008
	for i: int in sample_count:
		var t: float = float(i) / float(_MIX_RATE)
		# Which beat are we in? (0..beats-1)
		var beat_idx: int = int(t / seconds_per_beat) % beats
		var beat_t: float = fmod(t, seconds_per_beat)  # 0..seconds_per_beat
		# Bass — sustained sine with slow LFO breathing (0.7 to 1.0 amplitude).
		var bass_lfo: float = 0.7 + 0.3 * (0.5 * (1.0 + sin(two_pi * bass_lfo_freq * t)))
		var bass_sample: float = bass_gain * bass_lfo * sin(two_pi * bass_root_hz * t)
		# Melody — current beat's note, attack-decay envelope.
		var melody_freq: float = float(melody_freqs[beat_idx])
		var melody_sample: float = 0.0
		if melody_freq > 0.0:
			var env: float = 0.0
			if beat_t < melody_attack:
				env = beat_t / melody_attack  # linear attack ramp 0→1
			else:
				env = exp(-(beat_t - melody_attack) * melody_decay)
			# Slight harmonic richness: fundamental + half-amplitude second harmonic.
			var fund: float = sin(two_pi * melody_freq * t)
			var harm2: float = 0.30 * sin(two_pi * melody_freq * 2.0 * t)
			melody_sample = melody_gain * env * (fund + harm2)
		# Kick — first ~25ms of each beat. Mix low sine + noise pulse.
		var kick_sample: float = 0.0
		if beat_t < 0.05:
			var kick_env: float = exp(-beat_t * kick_decay)
			var kick_sine: float = sin(two_pi * kick_hz * t)
			var kick_noise: float = randf_range(-1.0, 1.0) * 0.35
			kick_sample = kick_gain * kick_env * (kick_sine + kick_noise)
		var sample: float = bass_sample + melody_sample + kick_sample
		# Soft clip in case envelopes overlap at peaks.
		sample = clampf(sample, -0.98, 0.98)
		var s16: int = clampi(int(sample * 32767.0), -32767, 32767)
		data[i * 2]     = s16 & 0xff
		data[i * 2 + 1] = (s16 >> 8) & 0xff
	stream.data = data
	return stream


## Generic 3-partial drone synthesizer (S60). Used by chapter-specific themes
## + the original battle_ambient via _make_battle_drone() defaults.
##
## Parameters:
##   duration   — loop length (seconds)
##   f1, f2, f3 — partial frequencies (Hz). Conventionally root/fifth/octave or
##                root/fifth/third — see chapter-specific calls for the
##                harmonic intent per chapter.
##   g1, g2, g3 — per-partial linear gain (0..1). Sum ≤ ~1.0 to avoid clipping
##                when LFO is at peak.
##   lfo_cycles — number of amplitude-LFO cycles across the full loop. Higher
##                = more urgent breathing. Typical 1.0–2.5.
##
## All partials are pure sines. The LFO modulates the SUM amplitude between
## 0.6 and 1.0 (sine, 0.4 depth). Loop endpoints align approximately —
## non-integer cycles cause small phase drift at the seam (intentional in the
## original implementation; carried forward).
func _make_drone(
	duration: float,
	f1: float, f2: float, f3: float,
	g1: float, g2: float, g3: float,
	lfo_cycles: float,
) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var sample_count: int = int(duration * _MIX_RATE)
	stream.loop_begin = 0
	stream.loop_end = sample_count
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var lfo_freq: float = lfo_cycles / duration
	var two_pi: float = TAU
	for i: int in sample_count:
		var t: float = float(i) / float(_MIX_RATE)
		var lfo: float = 0.6 + 0.4 * (0.5 * (1.0 + sin(two_pi * lfo_freq * t)))
		var sum: float = (
			g1 * sin(two_pi * f1 * t)
			+ g2 * sin(two_pi * f2 * t)
			+ g3 * sin(two_pi * f3 * t)
		)
		var sample: float = sum * lfo
		var s16: int = clampi(int(sample * 32767.0), -32767, 32767)
		data[i * 2]     = s16 & 0xff
		data[i * 2 + 1] = (s16 >> 8) & 0xff
	stream.data = data
	return stream


## Battle ambient drone — slow, sparse, mournful. Stacks 3 partials at A2/E3/A3
## (open-fifth pad with tonic doubling) modulated by a slow LFO so the texture
## breathes across the loop. Designed to set tone without competing with combat
## SFX. Tag: 천명역전 mood = tragedy + weight + impending fate.
##
## Thin wrapper over _make_drone with the historical default params preserved
## so existing MUSIC_BATTLE_AMBIENT consumers (tests, fallback) get the exact
## stream they got pre-S60.
func _make_battle_drone(duration: float) -> AudioStreamWAV:
	# Historical A-rooted open-fifth pad. A2 + E3 (slightly off-integer cycles,
	# adds subtle beating) + A3. Slow LFO at 1 cycle per loop. Gains weighted
	# toward A2 body. Bit-identical to the pre-S60 hand-written version.
	return _make_drone(duration, 110.00, 164.81, 220.00, 0.42, 0.22, 0.20, 1.0)
