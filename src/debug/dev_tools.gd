extends Node
## Developer overlay. Autoload name: `DevTools`.
##
## Every entry point is gated on `OS.is_debug_build()`, so an exported release
## build contains the code but can never reach it: `available()` is false, the
## F1 handler returns early and `unlock_all` is forced off.

const CHEAT_KEY := KEY_F1

var unlock_all := false:
	get:
		return _unlock_all and available()
	set(v):
		_unlock_all = v

var _unlock_all := false
var show_fps := false
var show_colliders := false
var freeze_timer := false
var time_scale := 1.0
var forced_ai_difficulty := -1
var forced_bot_count := -1

var _panel: CanvasLayer
var _visible := false
var _fps_label: Label
var _log_label: Label
var _active_match: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not available():
		return
	set_process_input(true)


func available() -> bool:
	return OS.is_debug_build()


func register_match(m: Node) -> void:
	_active_match = m


func _input(event: InputEvent) -> void:
	if not available():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == CHEAT_KEY:
		toggle()


func toggle() -> void:
	if not available():
		return
	_visible = not _visible
	if _panel == null:
		_build_panel()
	_panel.visible = _visible
	get_tree().paused = _visible


func _process(delta: float) -> void:
	if not available():
		return
	if _fps_label != null and is_instance_valid(_fps_label) and (show_fps or _visible):
		var pool := Pool.stats()
		var live := 0
		for k in pool:
			live += int(pool[k]["live"])
		_fps_label.text = "FPS %d  |  draw %d  |  nodes %d  |  pooled-live %d  |  mem %.1f MB" % [
			Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			get_tree().get_node_count(),
			live,
			OS.get_static_memory_usage() / 1048576.0,
		]
	if _fps_label != null and is_instance_valid(_fps_label):
		_fps_label.visible = show_fps or _visible


# --- panel -----------------------------------------------------------------

func _build_panel() -> void:
	_panel = CanvasLayer.new()
	_panel.layer = 120
	_panel.name = "DevPanel"
	get_tree().root.add_child(_panel)

	_fps_label = Label.new()
	_fps_label.position = Vector2(16, 8)
	_fps_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	_fps_label.add_theme_font_size_override("font_size", 18)
	var fps_layer := CanvasLayer.new()
	fps_layer.layer = 119
	get_tree().root.add_child(fps_layer)
	fps_layer.add_child(_fps_label)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(20, 40)
	panel.custom_minimum_size = Vector2(430, 0)
	_panel.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "DEV MENU  (F1)  —  debug builds only"
	title.add_theme_font_size_override("font_size", 20)
	vb.add_child(title)

	_add_toggle(vb, "Unlock everything", func(v): _unlock_all = v, func(): return _unlock_all)
	_add_toggle(vb, "Show FPS / draw calls", func(v): show_fps = v, func(): return show_fps)
	_add_toggle(vb, "Show colliders", func(v): _set_colliders(v), func(): return show_colliders)
	_add_toggle(vb, "Freeze match timer", func(v): freeze_timer = v, func(): return freeze_timer)

	_add_slider(vb, "Game speed", 0.25, 3.0, time_scale, func(v):
		time_scale = v
		Engine.time_scale = v)

	var diff := _add_option(vb, "Force AI difficulty", ["auto", "easy", "medium", "hard", "expert"], 0)
	diff.item_selected.connect(func(i): forced_ai_difficulty = i - 1)

	var bots := _add_option(vb, "Force opponent count", ["auto", "0", "1", "2", "3"], 0)
	bots.item_selected.connect(func(i): forced_bot_count = i - 1)

	_add_button(vb, "Grant 10 trophies", func(): Progression.grant_trophies(10))
	_add_button(vb, "Grant 25 gems", func(): Progression.grant_gems(25))
	_add_button(vb, "Unlock all characters", func():
		for c in Registry.characters():
			Progression.unlock_character(c.id, false))
	_add_button(vb, "Unlock all mini-games", func():
		for m in Registry.minigames():
			Progression.unlock_game(m.id, false))
	_add_button(vb, "Add 5 points to P1", func():
		if _active_match != null and is_instance_valid(_active_match):
			_active_match.debug_add_score(0, 5))
	_add_button(vb, "End round now", func():
		if _active_match != null and is_instance_valid(_active_match):
			_active_match.debug_end_round())
	_add_button(vb, "Restart round", func():
		if _active_match != null and is_instance_valid(_active_match):
			_active_match.debug_restart_round())
	_add_button(vb, "Validate content", func():
		var problems := Registry.validate()
		if problems.is_empty():
			Log.i("content validation: OK", "Dev")
		else:
			for p in problems:
				Log.e("content: %s" % p, "Dev")
		_refresh_log())
	_add_button(vb, "Reset profile", func():
		Progression.reset_progress()
		Stats.reset()
		Achievements.reset())
	_add_button(vb, "Back to main menu", func():
		get_tree().paused = false
		_visible = false
		_panel.visible = false
		SceneRouter.go_to("main_menu", {}, false))

	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(400, 120)
	_log_label.add_theme_font_size_override("font_size", 12)
	vb.add_child(_log_label)
	_refresh_log()


func _refresh_log() -> void:
	if _log_label != null and is_instance_valid(_log_label):
		_log_label.text = "\n".join(Array(Log.recent(8)))


func _set_colliders(v: bool) -> void:
	show_colliders = v
	get_tree().debug_collisions_hint = v
	# Toggling the hint only affects newly created shapes, so nudge existing ones.
	for n in get_tree().get_nodes_in_group("fighters"):
		if n is Node3D:
			n.propagate_notification(Node.NOTIFICATION_ENTER_TREE)


func _add_toggle(parent: Node, label: String, setter: Callable, getter: Callable) -> void:
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = bool(getter.call())
	cb.toggled.connect(func(v): setter.call(v))
	parent.add_child(cb)


func _add_button(parent: Node, label: String, action: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.pressed.connect(action)
	parent.add_child(b)


func _add_slider(parent: Node, label: String, lo: float, hi: float, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(220, 0)
	s.value_changed.connect(func(v): setter.call(v))
	row.add_child(s)
	parent.add_child(row)


func _add_option(parent: Node, label: String, items: Array, selected: int) -> OptionButton:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var o := OptionButton.new()
	for it in items:
		o.add_item(String(it))
	o.selected = selected
	row.add_child(o)
	parent.add_child(row)
	return o
