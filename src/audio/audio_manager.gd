extends Node
## Sound and music. Autoload name: `AudioManager`.
##
## Owns three buses (Music / SFX / UI) wired to the volume sliders, a pool of
## reusable players so a busy arena never allocates, and a bank of synthesized
## sounds built on first request. Music cross-fades between tracks and ducks
## under stingers.

const SFX_VOICES := 16
const W := Synth.Wave

var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_player: AudioStreamPlayer
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _bank := {}
var _tracks := {}
var _current_track := ""
var _next_voice := 0
var _fade_tween: Tween
var enabled := true
var _suspended := false

## Minimum gap between two triggers of the same sfx, in seconds. Stops a
## four-way pile-up from producing a wall of identical hit sounds.
const RETRIGGER_GUARD := 0.035
var _last_played := {}


func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	_ensure_buses()
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "UI"
	add_child(_ui_player)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_music_active = _music_a
	UserSettings.changed.connect(_on_setting_changed)
	_apply_volumes()


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	add_child(p)
	return p


func _ensure_buses() -> void:
	for name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")


func _on_setting_changed(key: String, _value) -> void:
	if key.begins_with("volume") or key == "*":
		_apply_volumes()


## Silence everything while backgrounded without touching the player's
## settings, so resuming restores exactly what they had.
func set_suspended(value: bool) -> void:
	if _suspended == value:
		return
	_suspended = value
	_apply_volumes()
	if value:
		for p in _sfx_players:
			p.stop()
		_ui_player.stop()


func is_suspended() -> bool:
	return _suspended


func _apply_volumes() -> void:
	if _suspended:
		for name in ["Master", "Music", "SFX", "UI"]:
			_set_bus_db(name, 0.0)
		return
	_set_bus_db("Master", 1.0)
	_set_bus_db("Music", UserSettings.volume_linear("music"))
	_set_bus_db("SFX", UserSettings.volume_linear("sfx"))
	_set_bus_db("UI", UserSettings.volume_linear("ui"))


func _set_bus_db(name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


# --- playback --------------------------------------------------------------

func play_sfx(id: String, _position: Vector3 = Vector3.ZERO, pitch := 1.0) -> void:
	if not enabled:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -10.0)) < RETRIGGER_GUARD:
		return
	_last_played[id] = now
	var stream := _sound(id)
	if stream == null:
		return
	var p := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.4, 2.4)
	p.play()


func play_ui(id: String, pitch := 1.0) -> void:
	if not enabled:
		return
	var stream := _sound(id)
	if stream == null:
		return
	_ui_player.stream = stream
	_ui_player.pitch_scale = pitch
	_ui_player.play()


func play_music(track: String, fade := 1.2) -> void:
	if not enabled or track == _current_track:
		return
	var stream := _track(track)
	if stream == null:
		return
	_current_track = track
	var incoming := _music_b if _music_active == _music_a else _music_a
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(incoming, "volume_db", 0.0, fade)
	_fade_tween.tween_property(_music_active, "volume_db", -40.0, fade)
	var outgoing := _music_active
	_fade_tween.chain().tween_callback(func(): outgoing.stop())
	_music_active = incoming


func stop_music(fade := 0.8) -> void:
	_current_track = ""
	if not enabled:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_music_active, "volume_db", -40.0, fade)
	_fade_tween.tween_callback(_music_active.stop)


func current_track() -> String:
	return _current_track


## Temporarily lower the music, e.g. under a victory stinger.
func duck(amount_db := -10.0, duration := 1.5) -> void:
	if not enabled:
		return
	var idx := AudioServer.get_bus_index("Music")
	var base := AudioServer.get_bus_volume_db(idx)
	AudioServer.set_bus_volume_db(idx, base + amount_db)
	await get_tree().create_timer(duration).timeout
	AudioServer.set_bus_volume_db(idx, base)


# --- banks -----------------------------------------------------------------

func _sound(id: String) -> AudioStreamWAV:
	if _bank.has(id):
		return _bank[id]
	var buf = _render_sfx(id)
	if buf == null:
		Log.w("unknown sfx '%s'" % id, "Audio")
		_bank[id] = null
		return null
	var stream := Synth.to_stream(buf)
	_bank[id] = stream
	return stream


func _render_sfx(id: String):
	match id:
		"ui_move":
			return Synth.voice({"freq": 620, "freq_to": 720, "dur": 0.06, "wave": W.SQUARE, "gain": 0.28, "release": 0.03})
		"ui_select":
			return Synth.mix([
				Synth.voice({"freq": 540, "freq_to": 900, "dur": 0.11, "wave": W.SQUARE, "gain": 0.4}),
				Synth.voice({"freq": 1080, "dur": 0.09, "wave": W.SINE, "gain": 0.2}),
			])
		"ui_back":
			return Synth.voice({"freq": 500, "freq_to": 260, "dur": 0.12, "wave": W.SQUARE, "gain": 0.32})
		"ui_error":
			return Synth.voice({"freq": 200, "freq_to": 150, "dur": 0.2, "wave": W.SAW, "gain": 0.35, "drive": 0.4})
		"countdown":
			return Synth.voice({"freq": 660, "dur": 0.18, "wave": W.TRIANGLE, "gain": 0.5, "decay": 0.1, "sustain": 0.4})
		"go":
			return Synth.mix([
				Synth.voice({"freq": 880, "freq_to": 1320, "dur": 0.35, "wave": W.SQUARE, "gain": 0.5}),
				Synth.voice({"freq": 440, "dur": 0.4, "wave": W.TRIANGLE, "gain": 0.3}),
			])
		"hit":
			return Synth.mix([
				Synth.voice({"freq": 240, "freq_to": 70, "dur": 0.16, "wave": W.SQUARE, "gain": 0.55, "drive": 0.5}),
				Synth.voice({"freq": 800, "dur": 0.06, "wave": W.NOISE, "gain": 0.35}),
			])
		"swing":
			return Synth.voice({"freq": 900, "freq_to": 300, "dur": 0.13, "wave": W.NOISE, "gain": 0.22, "release": 0.08})
		"dash":
			return Synth.voice({"freq": 300, "freq_to": 1200, "dur": 0.18, "wave": W.NOISE, "gain": 0.3, "attack": 0.02})
		"fall":
			return Synth.voice({"freq": 520, "freq_to": 90, "dur": 0.7, "wave": W.TRIANGLE, "gain": 0.42, "vibrato": 0.03, "curve": 1.8})
		"splash":
			return Synth.mix([
				Synth.voice({"freq": 170, "freq_to": 60, "dur": 0.38, "wave": W.NOISE, "gain": 0.44, "curve": 1.5}),
				Synth.voice({"freq": 620, "freq_to": 260, "dur": 0.16, "wave": W.TRIANGLE, "gain": 0.22}),
			])
		"burn":
			return Synth.mix([
				Synth.voice({"freq": 900, "freq_to": 260, "dur": 0.28, "wave": W.NOISE, "gain": 0.28, "drive": 0.35}),
				Synth.voice({"freq": 180, "freq_to": 95, "dur": 0.2, "wave": W.SAW, "gain": 0.18, "drive": 0.45}),
			])
		"eliminate":
			return Synth.mix([
				Synth.voice({"freq": 420, "freq_to": 110, "dur": 0.5, "wave": W.SAW, "gain": 0.45, "drive": 0.3}),
				Synth.voice({"freq": 180, "dur": 0.3, "wave": W.NOISE, "gain": 0.25}),
			])
		"pickup":
			return Synth.mix([
				Synth.voice({"freq": Synth.note(4), "dur": 0.07, "wave": W.SQUARE, "gain": 0.35}),
				Synth.voice({"freq": Synth.note(11), "dur": 0.12, "wave": W.SQUARE, "gain": 0.3}),
			])
		"powerup":
			var layers := []
			for i in 4:
				var b := Synth.silence(0.36)
				Synth.place(b, Synth.voice({"freq": Synth.note(i * 4), "dur": 0.1, "wave": W.SQUARE, "gain": 0.32}), i * 0.06)
				layers.append(b)
			return Synth.mix(layers)
		"score":
			return Synth.mix([
				Synth.voice({"freq": Synth.note(7), "dur": 0.14, "wave": W.TRIANGLE, "gain": 0.4}),
				Synth.voice({"freq": Synth.note(14), "dur": 0.18, "wave": W.SINE, "gain": 0.25}),
			])
		"crate_break":
			return Synth.mix([
				Synth.voice({"freq": 400, "freq_to": 120, "dur": 0.22, "wave": W.NOISE, "gain": 0.45, "drive": 0.6}),
				Synth.voice({"freq": 160, "dur": 0.14, "wave": W.SQUARE, "gain": 0.3}),
			])
		"explode":
			return Synth.mix([
				Synth.voice({"freq": 220, "freq_to": 40, "dur": 0.55, "wave": W.NOISE, "gain": 0.6, "drive": 0.8, "curve": 1.6}),
				Synth.voice({"freq": 90, "freq_to": 30, "dur": 0.4, "wave": W.SQUARE, "gain": 0.4}),
			])
		"shield_break":
			return Synth.voice({"freq": 1400, "freq_to": 500, "dur": 0.24, "wave": W.TRIANGLE, "gain": 0.4, "vibrato": 0.08})
		"bounce":
			return Synth.voice({"freq": 380, "freq_to": 620, "dur": 0.08, "wave": W.SINE, "gain": 0.35})
		"tick":
			return Synth.voice({"freq": 1200, "dur": 0.035, "wave": W.SQUARE, "gain": 0.25})
		"whistle":
			return Synth.voice({"freq": 1500, "freq_to": 1900, "dur": 0.5, "wave": W.SINE, "gain": 0.35, "vibrato": 0.05, "vibrato_hz": 9})
		"win":
			return _fanfare([0, 4, 7, 12, 16], 0.13, 0.5)
		"lose":
			return _fanfare([4, 2, -1, -5], 0.19, 0.42)
		"unlock":
			return _fanfare([0, 7, 12, 19], 0.1, 0.45)
		"trophy":
			return _fanfare([0, 4, 7, 12, 7, 12, 16], 0.11, 0.5)
		"engine":
			return Synth.voice({"freq": 120, "dur": 0.3, "wave": W.SAW, "gain": 0.18, "drive": 0.5, "vibrato": 0.02, "vibrato_hz": 24})
		"correct":
			return _fanfare([7, 12], 0.09, 0.4)
		"wrong":
			return Synth.voice({"freq": 220, "freq_to": 140, "dur": 0.26, "wave": W.SQUARE, "gain": 0.4, "drive": 0.3})
	return null


func _fanfare(semitones: Array, step: float, gain: float) -> PackedFloat32Array:
	var total := step * semitones.size() + 0.35
	var buf := Synth.silence(total)
	for i in semitones.size():
		Synth.place(buf, Synth.voice({
			"freq": Synth.note(float(semitones[i])),
			"dur": 0.3, "wave": W.SQUARE, "gain": gain, "decay": 0.08, "sustain": 0.5, "release": 0.18,
		}), step * i)
		Synth.place(buf, Synth.voice({
			"freq": Synth.note(float(semitones[i]) - 12.0),
			"dur": 0.26, "wave": W.TRIANGLE, "gain": gain * 0.5,
		}), step * i)
	return buf


func _track(id: String) -> AudioStreamWAV:
	if _tracks.has(id):
		return _tracks[id]
	var buf = _render_track(id)
	if buf == null:
		return null
	var stream := Synth.to_stream(buf, true)
	_tracks[id] = stream
	return stream


## Music is a 4-bar loop: bass root, a chord pad, an arpeggio and a kick/hat
## pattern. Style only changes tempo, scale degrees and instrument waves, which
## is enough to make menus, arenas and finales feel distinct.
func _render_track(id: String):
	var styles := {
		"menu":    {"bpm": 104.0, "prog": [0, -3, -5, -1], "arp": [0, 7, 12, 16], "wave": W.TRIANGLE, "drums": 0.35, "gain": 0.30},
		"arena":   {"bpm": 138.0, "prog": [0, 5, -2, 3], "arp": [0, 7, 12, 19], "wave": W.SQUARE, "drums": 0.7, "gain": 0.26},
		"arena_b": {"bpm": 150.0, "prog": [-5, 0, 2, -3], "arp": [0, 3, 7, 10], "wave": W.SAW, "drums": 0.75, "gain": 0.24},
		"tension": {"bpm": 164.0, "prog": [0, 1, 0, -1], "arp": [0, 6, 12, 18], "wave": W.SQUARE, "drums": 0.9, "gain": 0.26},
		"victory": {"bpm": 120.0, "prog": [0, 5, 7, 12], "arp": [0, 4, 7, 12], "wave": W.TRIANGLE, "drums": 0.5, "gain": 0.32},
		"adventure": {"bpm": 96.0, "prog": [-7, -3, -5, 0], "arp": [0, 5, 9, 12], "wave": W.SINE, "drums": 0.3, "gain": 0.30},
	}
	if not styles.has(id):
		return null
	var st: Dictionary = styles[id]
	var beat := 60.0 / float(st["bpm"])
	var bars := 4
	var total := beat * 4.0 * bars
	var buf := Synth.silence(total)
	var prog: Array = st["prog"]
	var arp: Array = st["arp"]
	var g := float(st["gain"])
	for bar in bars:
		var root := float(prog[bar % prog.size()]) - 12.0
		var t0 := beat * 4.0 * bar
		# bass
		for b in 4:
			Synth.place(buf, Synth.voice({
				"freq": Synth.note(root - 12.0), "dur": beat * 0.85, "wave": W.TRIANGLE,
				"gain": g * 1.1, "decay": beat * 0.3, "sustain": 0.45,
			}), t0 + beat * b)
		# pad
		for iv in [0, 4, 7]:
			Synth.place(buf, Synth.voice({
				"freq": Synth.note(root + iv), "dur": beat * 3.6, "wave": W.SINE,
				"gain": g * 0.4, "attack": 0.08, "sustain": 0.7, "release": beat,
			}), t0)
		# arpeggio, eighth notes
		for s in 8:
			var iv: float = float(arp[s % arp.size()])
			Synth.place(buf, Synth.voice({
				"freq": Synth.note(root + iv + 12.0), "dur": beat * 0.42,
				"wave": int(st["wave"]), "gain": g * 0.55, "decay": beat * 0.2, "sustain": 0.4,
			}), t0 + beat * 0.5 * s)
		# drums
		var d := float(st["drums"])
		if d > 0.0:
			for b in 4:
				Synth.place(buf, Synth.voice({
					"freq": 150, "freq_to": 48, "dur": 0.16, "wave": W.SINE, "gain": g * 1.6 * d, "curve": 1.5,
				}), t0 + beat * b)
				Synth.place(buf, Synth.voice({
					"freq": 6000, "dur": 0.045, "wave": W.NOISE, "gain": g * 0.5 * d,
				}), t0 + beat * b + beat * 0.5)
			Synth.place(buf, Synth.voice({
				"freq": 900, "dur": 0.12, "wave": W.NOISE, "gain": g * 0.9 * d, "release": 0.08,
			}), t0 + beat * 2.0)
	return buf


## Preloads the sounds a match needs so the first knockout does not synthesize
## on the gameplay thread. Called during the match LOADING phase.
func warm_match_bank() -> void:
	if not enabled:
		return
	for id in ["hit", "swing", "dash", "fall", "eliminate", "pickup", "powerup",
			"score", "crate_break", "explode", "shield_break", "bounce",
			"countdown", "go", "tick", "whistle", "splash", "burn", "win", "lose"]:
		_sound(id)
