extends Node
## Music and SFX. Every sound in the game is synthesised at boot into
## AudioStreamWAV buffers, so the project ships with no licensed audio files.
##
## Two audio buses ("Music" and "SFX") are created at runtime and driven by the
## values stored in SaveManager settings.

const MIX_RATE := 22050
const SFX_VOICES := 14

enum Wave { SINE, SQUARE, SAW, TRIANGLE, NOISE }

var _sfx: Dictionary = {}          # StringName -> AudioStreamWAV
var _music: Dictionary = {}        # StringName -> AudioStreamWAV
var _voices: Array[AudioStreamPlayer] = []
var _voice_index: int = 0
var _music_player: AudioStreamPlayer
var _current_music: StringName = &""
var _music_bus: int = 0
var _sfx_bus: int = 0
var _rng := RandomNumberGenerator.new()
## Guards against dozens of identical hit sounds firing in the same frame.
var _last_played: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 20260907
	_setup_buses()
	_build_sfx()
	_build_music()
	_setup_players()
	apply_settings()
	SaveManager.profile_loaded.connect(apply_settings)


func _setup_buses() -> void:
	_music_bus = AudioServer.bus_count
	AudioServer.add_bus(_music_bus)
	AudioServer.set_bus_name(_music_bus, "Music")
	AudioServer.set_bus_send(_music_bus, "Master")
	_sfx_bus = AudioServer.bus_count
	AudioServer.add_bus(_sfx_bus)
	AudioServer.set_bus_name(_sfx_bus, "SFX")
	AudioServer.set_bus_send(_sfx_bus, "Master")


func _setup_players() -> void:
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_voices.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)


## A player that is still mid-playback at shutdown keeps its stream (and the
## playback the server made from it) alive past ObjectDB cleanup, which the
## engine then reports as a leak. Releasing the streams here keeps a normal
## quit silent.
func _exit_tree() -> void:
	for voice in _voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	_sfx.clear()
	_music.clear()


func apply_settings() -> void:
	var music_volume := float(SaveManager.get_setting("music_volume", 0.7))
	var sfx_volume := float(SaveManager.get_setting("sfx_volume", 0.9))
	AudioServer.set_bus_volume_db(_music_bus, linear_to_db(clampf(music_volume, 0.0, 1.0)))
	AudioServer.set_bus_mute(_music_bus, music_volume <= 0.001)
	AudioServer.set_bus_volume_db(_sfx_bus, linear_to_db(clampf(sfx_volume, 0.0, 1.0)))
	AudioServer.set_bus_mute(_sfx_bus, sfx_volume <= 0.001)


# --- Playback --------------------------------------------------------------

func play_sfx(id: StringName, pitch_variation: float = 0.08, volume_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _sfx.get(id) as AudioStreamWAV
	if stream == null:
		return
	# Rate-limit identical sounds; hundreds of enemies can be hit per second.
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(id, -999)) < 35:
		return
	_last_played[id] = now
	var p := _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	p.stream = stream
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_variation, pitch_variation)
	p.volume_db = volume_db
	p.play()


func play_music(id: StringName) -> void:
	if _current_music == id and _music_player.playing:
		return
	var stream: AudioStreamWAV = _music.get(id) as AudioStreamWAV
	if stream == null:
		return
	_current_music = id
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_current_music = &""
	_music_player.stop()


func vibrate(milliseconds: int = 30) -> void:
	if not bool(SaveManager.get_setting("vibration", true)):
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds)


# --- Synthesis -------------------------------------------------------------

func _osc(wave: Wave, phase: float) -> float:
	match wave:
		Wave.SINE:
			return sin(phase * TAU)
		Wave.SQUARE:
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		Wave.SAW:
			return fmod(phase, 1.0) * 2.0 - 1.0
		Wave.TRIANGLE:
			var t := fmod(phase, 1.0)
			return (4.0 * t - 1.0) if t < 0.5 else (3.0 - 4.0 * t)
		_:
			return _rng.randf_range(-1.0, 1.0)
	return 0.0


## One synth voice rendered into a float buffer.
func _render_tone(out: PackedFloat32Array, start_sample: int, duration: float,
		freq_start: float, freq_end: float, wave: Wave, amplitude: float,
		attack: float = 0.005, curve: float = 2.0) -> void:
	var count := int(duration * MIX_RATE)
	var phase := 0.0
	for i in count:
		var index := start_sample + i
		if index >= out.size():
			break
		var t := float(i) / float(maxi(1, count))
		var freq: float = lerpf(freq_start, freq_end, t)
		phase += freq / float(MIX_RATE)
		var env := 1.0
		var attack_samples := maxf(1.0, attack * MIX_RATE)
		if float(i) < attack_samples:
			env = float(i) / attack_samples
		else:
			env = pow(1.0 - t, curve)
		out[index] = clampf(out[index] + _osc(wave, phase) * amplitude * env, -1.0, 1.0)


func _make_stream(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


func _blank(duration: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(duration * MIX_RATE))
	buf.fill(0.0)
	return buf


func _build_sfx() -> void:
	var buf: PackedFloat32Array

	# Light, bright pew for the default projectile weapons.
	buf = _blank(0.14)
	_render_tone(buf, 0, 0.13, 1320.0, 420.0, Wave.SQUARE, 0.22, 0.002, 2.5)
	_render_tone(buf, 0, 0.10, 660.0, 240.0, Wave.SINE, 0.16, 0.002, 2.0)
	_sfx[&"shoot"] = _make_stream(buf)

	# Wide, airy burst for shotgun-style weapons.
	buf = _blank(0.22)
	_render_tone(buf, 0, 0.20, 900.0, 180.0, Wave.NOISE, 0.20, 0.002, 2.2)
	_render_tone(buf, 0, 0.12, 320.0, 120.0, Wave.SAW, 0.16, 0.002, 2.0)
	_sfx[&"shoot_spread"] = _make_stream(buf)

	# Short tick when a projectile connects.
	buf = _blank(0.09)
	_render_tone(buf, 0, 0.08, 2200.0, 900.0, Wave.TRIANGLE, 0.14, 0.001, 3.0)
	_sfx[&"hit"] = _make_stream(buf)

	# Meatier thud for a kill.
	buf = _blank(0.20)
	_render_tone(buf, 0, 0.18, 420.0, 90.0, Wave.SAW, 0.20, 0.002, 2.4)
	_render_tone(buf, 0, 0.14, 260.0, 60.0, Wave.NOISE, 0.12, 0.002, 2.0)
	_sfx[&"kill"] = _make_stream(buf)

	buf = _blank(0.45)
	_render_tone(buf, 0, 0.42, 220.0, 40.0, Wave.NOISE, 0.32, 0.004, 1.6)
	_render_tone(buf, 0, 0.30, 140.0, 35.0, Wave.SINE, 0.26, 0.004, 1.8)
	_sfx[&"explosion"] = _make_stream(buf)

	buf = _blank(0.14)
	_render_tone(buf, 0, 0.12, 880.0, 1760.0, Wave.SINE, 0.18, 0.002, 2.2)
	_sfx[&"pickup"] = _make_stream(buf)

	buf = _blank(0.30)
	_render_tone(buf, 0, 0.28, 520.0, 1040.0, Wave.TRIANGLE, 0.20, 0.004, 1.4)
	_render_tone(buf, int(0.06 * MIX_RATE), 0.22, 780.0, 1560.0, Wave.SINE, 0.16, 0.004, 1.6)
	_sfx[&"levelup"] = _make_stream(buf)

	buf = _blank(0.26)
	_render_tone(buf, 0, 0.24, 300.0, 120.0, Wave.SAW, 0.24, 0.004, 1.8)
	_sfx[&"hurt"] = _make_stream(buf)

	buf = _blank(0.90)
	_render_tone(buf, 0, 0.85, 110.0, 82.0, Wave.SAW, 0.26, 0.05, 0.8)
	_render_tone(buf, 0, 0.85, 55.0, 41.0, Wave.SQUARE, 0.18, 0.05, 0.8)
	_sfx[&"boss_warning"] = _make_stream(buf)

	buf = _blank(0.10)
	_render_tone(buf, 0, 0.08, 1500.0, 1500.0, Wave.SQUARE, 0.10, 0.002, 3.0)
	_sfx[&"ui_click"] = _make_stream(buf)

	buf = _blank(0.16)
	_render_tone(buf, 0, 0.14, 700.0, 1400.0, Wave.SQUARE, 0.10, 0.002, 2.4)
	_sfx[&"ui_confirm"] = _make_stream(buf)

	buf = _blank(1.10)
	_render_tone(buf, 0, 0.30, 523.0, 523.0, Wave.TRIANGLE, 0.20, 0.01, 1.2)
	_render_tone(buf, int(0.28 * MIX_RATE), 0.30, 659.0, 659.0, Wave.TRIANGLE, 0.20, 0.01, 1.2)
	_render_tone(buf, int(0.56 * MIX_RATE), 0.50, 784.0, 784.0, Wave.TRIANGLE, 0.22, 0.01, 1.0)
	_sfx[&"victory"] = _make_stream(buf)

	buf = _blank(1.20)
	_render_tone(buf, 0, 0.40, 330.0, 320.0, Wave.SAW, 0.20, 0.02, 1.2)
	_render_tone(buf, int(0.35 * MIX_RATE), 0.45, 262.0, 250.0, Wave.SAW, 0.20, 0.02, 1.2)
	_render_tone(buf, int(0.75 * MIX_RATE), 0.45, 196.0, 150.0, Wave.SAW, 0.22, 0.02, 1.0)
	_sfx[&"defeat"] = _make_stream(buf)

	buf = _blank(0.80)
	_render_tone(buf, 0, 0.75, 300.0, 1800.0, Wave.SINE, 0.22, 0.02, 0.9)
	_render_tone(buf, 0, 0.70, 150.0, 900.0, Wave.SQUARE, 0.14, 0.02, 1.0)
	_sfx[&"evolve"] = _make_stream(buf)

	buf = _blank(0.55)
	_render_tone(buf, 0, 0.50, 160.0, 640.0, Wave.SAW, 0.24, 0.01, 1.2)
	_render_tone(buf, 0, 0.45, 480.0, 1440.0, Wave.SINE, 0.16, 0.01, 1.4)
	_sfx[&"ultimate"] = _make_stream(buf)


## Builds a short looping bed per mood out of a bass pulse plus an arpeggio.
func _build_music() -> void:
	_music[&"menu"] = _compose([0, 3, 7, 10], 96.0, 0.16, Wave.TRIANGLE, 8)
	_music[&"battle"] = _compose([0, 5, 7, 3], 132.0, 0.18, Wave.SQUARE, 8)
	_music[&"boss"] = _compose([0, 1, 5, 8], 148.0, 0.20, Wave.SAW, 8)


func _compose(scale_steps: Array, bpm: float, amplitude: float, wave: Wave, bars: int) -> AudioStreamWAV:
	var beat := 60.0 / bpm
	var step := beat * 0.5
	var total := step * 8.0 * float(bars)
	var buf := _blank(total)
	var root := 196.0  # G3
	var pattern_len := 8
	for bar in bars:
		var bar_root: float = root * pow(2.0, float(scale_steps[bar % scale_steps.size()]) / 12.0)
		for i in pattern_len:
			var at := int((float(bar) * float(pattern_len) + float(i)) * step * MIX_RATE)
			# Bass on the down beats.
			if i % 4 == 0:
				_render_tone(buf, at, step * 1.8, bar_root * 0.5, bar_root * 0.5, Wave.SINE, amplitude * 1.1, 0.01, 1.6)
			# Arpeggio riding above it.
			var degree: float = [0.0, 7.0, 12.0, 7.0, 3.0, 10.0, 15.0, 10.0][i]
			var freq: float = bar_root * pow(2.0, degree / 12.0)
			_render_tone(buf, at, step * 0.9, freq, freq, wave, amplitude * 0.55, 0.005, 2.2)
			# Sparse hat.
			if i % 2 == 1:
				_render_tone(buf, at, step * 0.18, 6000.0, 3000.0, Wave.NOISE, amplitude * 0.14, 0.001, 3.0)
	return _make_stream(buf, true)
