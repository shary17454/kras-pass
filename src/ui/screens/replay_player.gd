extends Screen
## Watches a recorded match.
##
## Hosts an ordinary `MatchScene` in playback mode — the same runtime, the same
## rules, the same physics — and feeds it the recorded input frames. Nothing in
## the match layer knows it is being replayed except the input source, which is
## exactly the property that makes this cheap.

var replay: ReplayData
var match_scene: Node

var _scrub: HSlider
var _play_button: Button
var _speed_button: Button
var _status: Label
var _hud_visible := true
var _scrubbing := false
var _speeds := [0.5, 1.0, 2.0]
var _speed_index := 1
var _camera_modes := [ArenaCamera.Mode.ARENA, ArenaCamera.Mode.TOP_DOWN, ArenaCamera.Mode.ISOMETRIC]
var _camera_index := 0


func setup(a: Dictionary) -> void:
	replay = a.get("replay")
	if replay == null:
		var id := String(a.get("id", ""))
		replay = Replays.load_replay(id)
	super.setup(a)
	if replay == null:
		return
	_start()


func build() -> void:
	if replay == null:
		title(Loc.t("replay.title"))
		body.add_child(UIKit.centered(Loc.t("replay.missing"), UIKit.SIZE_HEADING, UIKit.DANGER))
		return
	# The transport bar sits at the bottom; the match renders behind everything.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(spacer)
	body.add_child(_transport())
	root.get_child(0).color = Color(0, 0, 0, 0)   # let the 3D scene show through


func _transport() -> Control:
	var card := UIKit.panel(Color(UIKit.PANEL.r, UIKit.PANEL.g, UIKit.PANEL.b, 0.88), 18)
	var v := UIKit.vbox(8)
	card.add_child(v)

	var header := UIKit.hbox(14)
	header.add_child(UIKit.label("%s · %s" % [replay.display_name(), replay.date_string()],
		UIKit.SIZE_SMALL, UIKit.ACCENT, true))
	_status = UIKit.label("", UIKit.SIZE_TINY, UIKit.dim_color())
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_status)
	v.add_child(header)

	_scrub = UIKit.slider(0.0, 0.0, float(maxi(1, replay.tick_count())), 1.0)
	_scrub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scrub.drag_started.connect(func(): _scrubbing = true)
	_scrub.drag_ended.connect(func(changed):
		_scrubbing = false
		if changed and match_scene != null:
			match_scene.pb_seek(int(_scrub.value)))
	v.add_child(_scrub)

	var row := UIKit.hbox(10)
	_play_button = UIKit.button("⏸", UIKit.SIZE_BODY)
	_play_button.pressed.connect(_toggle_play)
	row.add_child(_play_button)

	_speed_button = UIKit.button("1×", UIKit.SIZE_BODY)
	_speed_button.pressed.connect(_cycle_speed)
	row.add_child(_speed_button)

	var restart := UIKit.button(Loc.t("replay.restart"), UIKit.SIZE_SMALL)
	restart.pressed.connect(func():
		if match_scene != null:
			match_scene.pb_seek(0))
	row.add_child(restart)

	for h in replay.highlights:
		var kind := String(h["kind"])
		var b := UIKit.button(Loc.t(ReplayHighlights.label_key(kind)), UIKit.SIZE_TINY)
		b.pressed.connect(func():
			if match_scene != null:
				match_scene.pb_seek(int(h["tick"])))
		row.add_child(b)

	var hud := UIKit.button(Loc.t("replay.hud"), UIKit.SIZE_SMALL)
	hud.pressed.connect(_toggle_hud)
	row.add_child(hud)

	var cam := UIKit.button(Loc.t("replay.camera"), UIKit.SIZE_SMALL)
	cam.pressed.connect(_cycle_camera)
	row.add_child(cam)

	var quit := UIKit.button(Loc.t("common.back"), UIKit.SIZE_SMALL)
	quit.pressed.connect(go_back)
	row.add_child(quit)
	v.add_child(row)
	first_focus = _play_button
	return card


func _start() -> void:
	var script: Script = load("res://src/match/match_scene.gd")
	match_scene = script.new()
	match_scene.name = "Playback"
	add_child(match_scene)
	move_child(match_scene, 0)
	match_scene.setup({"replay": replay})
	match_scene.playback_progress.connect(_on_progress)
	match_scene.desync_detected.connect(_on_desync)
	if not replay.verifiable():
		_status.text = Loc.t("replay.unverified")


func _on_progress(tick: int, _total: int) -> void:
	if _scrub != null and not _scrubbing:
		_scrub.set_value_no_signal(float(tick))
	if _status != null and match_scene != null and match_scene.desync_tick < 0 and replay.verifiable():
		_status.text = "%s / %s" % [
			Loc.time_mmss(float(tick) / float(maxi(replay.tick_rate, 1))),
			Loc.time_mmss(replay.length_seconds()),
		]


## A replay that stops matching is reported, not hidden. Physics is not
## bit-exact across engine builds, and pretending otherwise would mean showing
## a different match under the label of the recorded one.
func _on_desync(tick: int) -> void:
	if _status == null:
		return
	_status.text = Loc.t("replay.desync", {"t": "%.1f" % (float(tick) / float(maxi(replay.tick_rate, 1)))})
	_status.add_theme_color_override("font_color", UIKit.DANGER)


func _toggle_play() -> void:
	if match_scene == null:
		return
	match_scene.pb_toggle_pause()
	_play_button.text = "▶" if match_scene.playback_paused else "⏸"


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % _speeds.size()
	var s: float = _speeds[_speed_index]
	if match_scene != null:
		match_scene.pb_set_speed(s)
	_speed_button.text = "%s×" % ("0.5" if s == 0.5 else str(int(s)))


func _toggle_hud() -> void:
	_hud_visible = not _hud_visible
	if match_scene != null and match_scene.hud != null:
		match_scene.hud.visible = _hud_visible


func _cycle_camera() -> void:
	if match_scene == null or match_scene.camera == null:
		return
	_camera_index = (_camera_index + 1) % _camera_modes.size()
	match_scene.camera.configure(_camera_modes[_camera_index], match_scene.arena)


func teardown() -> void:
	if match_scene != null and is_instance_valid(match_scene):
		match_scene.teardown()


func go_back() -> void:
	SceneRouter.go_to("replays", {}, false)
