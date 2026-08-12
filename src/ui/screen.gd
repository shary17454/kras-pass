class_name Screen
extends Control
## Base for every menu screen.
##
## Provides the full-rect root, the standard header with a working back button,
## gamepad focus handling and the `ui_back` shortcut. Because back navigation is
## implemented once here, "no dead ends" is a property of the base class rather
## than a thing each screen has to remember.

var args := {}
var body: VBoxContainer
var header: HBoxContainer
var root: Control
var back_target := "main_menu"
var first_focus: Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup(a: Dictionary) -> void:
	args = a
	root = UIKit.screen_root()
	add_child(root)
	var margin := UIKit.margin(UIKit.vbox(20))
	root.add_child(margin)
	var column: VBoxContainer = margin.get_child(0)
	header = UIKit.hbox(18)
	column.add_child(header)
	body = UIKit.vbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	build()
	UIKit.animate_in(column)
	call_deferred("_focus_first")


## Override to populate `body`.
func build() -> void:
	pass


func title(text: String, show_back := true) -> void:
	var label := UIKit.label(text, UIKit.SIZE_TITLE, UIKit.ACCENT, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if show_back:
		var back := UIKit.button("←" if not Loc.is_rtl() else "→", UIKit.SIZE_HEADING)
		back.custom_minimum_size = Vector2(84, 64)
		back.pressed.connect(go_back)
		header.add_child(back)
	header.add_child(label)


func go_back() -> void:
	AudioManager.play_ui("ui_back")
	SceneRouter.back(back_target)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back") or event.is_action_pressed("ui_cancel"):
		accept_event()
		go_back()


func _focus_first() -> void:
	if first_focus != null and is_instance_valid(first_focus):
		first_focus.grab_focus()
		return
	# Fall back to the first focusable control so a gamepad is never stranded
	# on a screen with no highlighted element.
	var queue: Array = [self]
	while not queue.is_empty():
		var n: Node = queue.pop_front()
		if n is Control and n.focus_mode == Control.FOCUS_ALL and n.visible:
			n.grab_focus()
			return
		for c in n.get_children():
			queue.append(c)


## Convenience for screens that are a vertical list of buttons.
func add_menu_button(text: String, action: Callable, enabled := true, subtitle := "") -> Button:
	var b := UIKit.button(text)
	b.disabled = not enabled
	if enabled:
		b.pressed.connect(action)
	body.add_child(b)
	if subtitle != "":
		var s := UIKit.label(subtitle, UIKit.SIZE_TINY, UIKit.dim_color())
		body.add_child(s)
	if first_focus == null and enabled:
		first_focus = b
	return b
