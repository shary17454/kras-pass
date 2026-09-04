extends Screen
## Settings: audio, gameplay, graphics, language, accessibility, controls.
##
## Every control writes straight through `UserSettings`, which persists and
## broadcasts immediately — there is no "apply" button and no way to lose a
## change by backing out.

var _rebinding := {}


func build() -> void:
	title(Loc.t("settings.title"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var v := UIKit.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	_section(v, "settings.audio")
	_volume(v, "settings.master", "volume_master")
	_volume(v, "settings.music", "volume_music")
	_volume(v, "settings.sfx", "volume_sfx")
	_volume(v, "settings.ui", "volume_ui")

	_section(v, "settings.gameplay")
	_toggle(v, "settings.vibration", "vibration")
	_toggle(v, "settings.show_hints", "show_control_hints")
	_toggle(v, "settings.replay_capture", "replay_capture")
	_slider(v, "settings.camera_sensitivity", "camera_sensitivity", 0.4, 2.0)
	_slider(v, "settings.camera_shake", "camera_shake", 0.0, 1.5)
	_slider(v, "settings.camera_distance", "camera_distance", 0.75, 1.4)

	_section(v, "settings.touch")
	var touch_values := ["auto", "on", "off"]
	var touch := UIKit.option([
		Loc.t("settings.touch.auto"), Loc.t("settings.touch.on"), Loc.t("settings.touch.off"),
	], maxi(0, touch_values.find(String(UserSettings.get_value("touch_controls")))))
	touch.item_selected.connect(func(i): UserSettings.set_value("touch_controls", touch_values[i]))
	v.add_child(UIKit.row(Loc.t("settings.touch_controls"), touch))
	_slider(v, "settings.touch_scale", "touch_scale", 0.7, 1.6)
	_slider(v, "settings.touch_opacity", "touch_opacity", 0.15, 1.0)
	_toggle(v, "settings.touch_left_handed", "touch_left_handed")

	_section(v, "settings.graphics")
	var quality := UIKit.option([
		Loc.t("settings.quality.low"), Loc.t("settings.quality.medium"), Loc.t("settings.quality.high"),
		Loc.t("settings.quality.ultra"),
	], int(UserSettings.get_value("graphics_quality")))
	quality.item_selected.connect(func(i): UserSettings.set_value("graphics_quality", i))
	v.add_child(UIKit.row(Loc.t("settings.quality"), quality))

	var fps_values := [0, 30, 60, 120, 144]
	var fps := UIKit.option([Loc.t("settings.fps.auto"), "30", "60", "120", "144"],
		maxi(0, fps_values.find(int(UserSettings.get_value("fps_limit")))))
	fps.item_selected.connect(func(i): UserSettings.set_value("fps_limit", fps_values[i]))
	v.add_child(UIKit.row(Loc.t("settings.fps"), fps))

	_section(v, "settings.language")
	var lang := UIKit.option(["العربية", "English"], 0 if Loc.locale == "ar" else 1)
	lang.item_selected.connect(func(i):
		UserSettings.set_value("language", "ar" if i == 0 else "en")
		UIKit.invalidate_theme()
		# The whole UI is direction-sensitive, so rebuild it rather than trying
		# to mirror a live tree.
		SceneRouter.go_to("settings", {}, false, 0.12))
	v.add_child(UIKit.row(Loc.t("settings.language"), lang))

	_section(v, "settings.accessibility")
	_slider(v, "settings.text_scale", "text_scale", 0.8, 1.6, 0.1, true)
	_toggle(v, "settings.high_contrast", "high_contrast", true)
	_toggle(v, "settings.reduce_flashes", "reduce_flashes")
	_toggle(v, "settings.reduce_effects", "reduce_effects")
	var cb := UIKit.option([
		Loc.t("settings.colorblind.off"), Loc.t("settings.colorblind.prot"),
		Loc.t("settings.colorblind.deut"), Loc.t("settings.colorblind.trit"),
	], int(UserSettings.get_value("colorblind_mode")))
	cb.item_selected.connect(func(i): UserSettings.set_value("colorblind_mode", i))
	v.add_child(UIKit.row(Loc.t("settings.colorblind"), cb))

	_section(v, "settings.controls")
	for profile in 2:
		v.add_child(UIKit.label(Loc.t("keyboard.profile.%d" % (profile + 1)), UIKit.SIZE_SMALL, UIKit.ACCENT))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		v.add_child(grid)
		for action in ["up", "down", "left", "right", "jump", "attack", "action", "dash", "ability"]:
			grid.add_child(_binding_button(profile, action))

	var reset_binds := UIKit.button(Loc.t("settings.reset_bindings"), UIKit.SIZE_SMALL)
	reset_binds.pressed.connect(func():
		InputRouter.reset_bindings()
		SceneRouter.go_to("settings", {}, false, 0.1))
	v.add_child(reset_binds)

	_section(v, "common.default")
	var reset := UIKit.button(Loc.t("settings.reset_defaults"), UIKit.SIZE_SMALL)
	reset.pressed.connect(func():
		UserSettings.reset_to_defaults()
		UIKit.invalidate_theme()
		SceneRouter.go_to("settings", {}, false, 0.1))
	v.add_child(reset)

	var wipe := UIKit.button(Loc.t("settings.reset_progress"), UIKit.SIZE_SMALL)
	wipe.add_theme_color_override("font_color", UIKit.DANGER)
	wipe.pressed.connect(_confirm_wipe)
	v.add_child(wipe)


func _section(parent: VBoxContainer, key: String) -> void:
	parent.add_child(UIKit.spacer(14))
	parent.add_child(UIKit.heading(Loc.t(key)))


func _volume(parent: VBoxContainer, key: String, setting: String) -> void:
	var s := UIKit.slider(float(UserSettings.get_value(setting)), 0.0, 1.0)
	s.value_changed.connect(func(v):
		UserSettings.set_value(setting, v)
		AudioManager.play_ui("ui_move"))
	parent.add_child(UIKit.row(Loc.t(key), s))
	if first_focus == null:
		first_focus = s


func _slider(parent: VBoxContainer, key: String, setting: String, lo: float, hi: float, step := 0.05, rebuild := false) -> void:
	var s := UIKit.slider(float(UserSettings.get_value(setting)), lo, hi, step)
	s.value_changed.connect(func(v):
		UserSettings.set_value(setting, v)
		if rebuild:
			UIKit.invalidate_theme())
	if rebuild:
		s.drag_ended.connect(func(changed):
			if changed:
				SceneRouter.go_to("settings", {}, false, 0.1))
	parent.add_child(UIKit.row(Loc.t(key), s))


func _toggle(parent: VBoxContainer, key: String, setting: String, rebuild := false) -> void:
	var c := UIKit.checkbox("", bool(UserSettings.get_value(setting)))
	c.toggled.connect(func(v):
		UserSettings.set_value(setting, v)
		if rebuild:
			UIKit.invalidate_theme()
			SceneRouter.go_to("settings", {}, false, 0.1))
	parent.add_child(UIKit.row(Loc.t(key), c))


func _binding_button(profile: int, action: String) -> Button:
	var b := UIKit.button("%s: %s" % [Loc.t("controls." + action) if Loc.has("controls." + action) else action,
		InputRouter.binding_label(profile, action)], UIKit.SIZE_TINY)
	b.pressed.connect(func():
		b.text = Loc.t("settings.rebind")
		_rebinding = {"profile": profile, "action": action, "button": b})
	return b


func _input(event: InputEvent) -> void:
	if _rebinding.is_empty() or not (event is InputEventKey) or not event.pressed:
		return
	var key: InputEventKey = event
	var profile: int = _rebinding["profile"]
	var action: String = _rebinding["action"]
	var b: Button = _rebinding["button"]
	_rebinding = {}
	accept_event()
	if key.keycode == KEY_ESCAPE:
		b.text = "%s: %s" % [Loc.t("controls." + action) if Loc.has("controls." + action) else action,
			InputRouter.binding_label(profile, action)]
		return
	InputRouter.rebind(profile, action, key.keycode)
	b.text = "%s: %s" % [Loc.t("controls." + action) if Loc.has("controls." + action) else action,
		InputRouter.binding_label(profile, action)]
	AudioManager.play_ui("ui_select")


func _confirm_wipe() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = Loc.t("settings.confirm_reset")
	dialog.title = Loc.t("settings.reset_progress")
	add_child(dialog)
	dialog.confirmed.connect(func():
		Progression.reset_progress()
		Stats.reset()
		Achievements.reset()
		SaveSystem.flush()
		EventBus.notify(Loc.t("settings.reset_progress"), "⟲")
		SceneRouter.go_to("main_menu", {}, false))
	dialog.popup_centered()
