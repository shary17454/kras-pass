extends Screen
## Title card. Waits for any input, then opens the main menu.
##
## Also the place where first-launch work happens: the audio banks warm up and
## the profile is confirmed loaded before the player can reach a menu that
## reads it.

var _ready_to_continue := false


func setup(a: Dictionary) -> void:
	super.setup(a)
	AudioManager.play_music("menu")
	if SaveSystem.profile().is_empty():
		Log.i("new profile created", "Boot")
	await get_tree().create_timer(0.35).timeout
	_ready_to_continue = true


func build() -> void:
	var centre := CenterContainer.new()
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(centre)
	var v := UIKit.vbox(10)
	centre.add_child(v)
	v.add_child(UIKit.centered(Loc.t("app.title"), 128, UIKit.ACCENT, true))
	v.add_child(UIKit.centered(Loc.t("app.subtitle"), UIKit.SIZE_HEADING, UIKit.TEXT))
	v.add_child(UIKit.centered(Loc.t("app.tagline"), UIKit.SIZE_SMALL, UIKit.dim_color()))
	v.add_child(UIKit.spacer(48))
	var prompt := UIKit.centered(Loc.t("common.press_start"), UIKit.SIZE_BODY, UIKit.ACCENT_2)
	v.add_child(prompt)
	if DisplayServer.get_name() != "headless":
		var tw := create_tween().set_loops()
		tw.tween_property(prompt, "modulate:a", 0.25, 0.7)
		tw.tween_property(prompt, "modulate:a", 1.0, 0.7)
	var start := UIKit.button(Loc.t("common.start"))
	start.custom_minimum_size = Vector2(320, 64)
	start.pressed.connect(_continue)
	v.add_child(start)
	first_focus = start


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_to_continue:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_continue()
	elif event is InputEventJoypadButton and event.pressed:
		_continue()


func _continue() -> void:
	if not _ready_to_continue:
		return
	_ready_to_continue = false
	SceneRouter.go_to("main_menu", {}, false)


func go_back() -> void:
	_continue()
