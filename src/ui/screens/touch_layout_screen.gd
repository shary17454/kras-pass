extends Control

var preview: TouchSource
var _games: Array[MiniGameDef] = []


func setup(_args: Dictionary) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := UIKit.screen_root()
	add_child(background)
	preview = TouchSource.new()
	preview.editing = true
	add_child(preview)
	for game in Registry.minigames():
		if ControlProfile.shows_move_stick(game.control_profile):
			_games.append(game)
	preview.setup(0, _games[0])
	var toolbar := UIKit.vbox(12)
	toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_left = 30
	toolbar.offset_right = -30
	toolbar.offset_top = 30 + Platform.safe_insets().y
	add_child(toolbar)
	toolbar.add_child(UIKit.centered(Loc.t("party.edit_controls"), UIKit.SIZE_HEADING, UIKit.ACCENT))
	var names: Array = []
	for game in _games:
		names.append(game.display_name())
	var picker := UIKit.option(names, 0)
	picker.item_selected.connect(func(i):
		preview.profile = _games[i].control_profile
		preview.buttons = ControlProfile.buttons_for(preview.profile, _games[i].control_hints)
		preview._fit_to_viewport())
	toolbar.add_child(picker)
	var actions := UIKit.hbox(12)
	toolbar.add_child(actions)
	var reset := UIKit.button(Loc.t("common.default"), UIKit.SIZE_SMALL)
	reset.pressed.connect(func(): UserSettings.set_value("touch_positions", {}))
	actions.add_child(reset)
	var back := UIKit.button(Loc.t("common.back"), UIKit.SIZE_SMALL)
	back.pressed.connect(go_back)
	actions.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back") or event.is_action_pressed("ui_cancel"):
		go_back()


func go_back() -> void:
	SceneRouter.back("settings")
