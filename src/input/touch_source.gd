class_name TouchSource
extends Control
## On-screen controls that produce the ordinary `InputFrame`.
##
## This is the fourth input source, after pads, keyboards and AI brains, and it
## is deliberately the same shape as the others: it writes movement and button
## bits into `InputRouter` and nothing downstream can tell a thumb from a stick.
## There is no touch-related code in any of the 21 mini-games.
##
## Multitouch is handled centrally rather than by per-widget `_gui_input`: one
## handler owns the index→widget map, which is the only way a player can hold
## the stick, an action button and a second button at once without widgets
## stealing each other's fingers. Mouse events are handled too, so the layout
## can be exercised on a desktop without a device.

const STICK_RADIUS := 110.0
const STICK_DEAD := 0.14
const BUTTON_RADIUS := 62.0
const EDGE_MARGIN := 54.0

var slot := 0
var profile: ControlProfile.Kind = ControlProfile.Kind.MOVEMENT_ACTION
var buttons: Array[String] = []

var _scale := 1.0
var _opacity := 0.5
var _left_handed := false
var _haptics := true

## touch index -> {"kind": "move"|"aim"|"button"|"steer"|"screen", "id": …}
var _owners := {}
var _move := Vector2.ZERO
var _aim := Vector2.ZERO
var _bits := 0
var _steer := 0.0
var _throttle := 0.0
var _pressed_buttons := {}
var _move_origin := Vector2.ZERO
var _aim_origin := Vector2.ZERO
var _move_knob := Vector2.ZERO
var _aim_knob := Vector2.ZERO
var _font: Font


func setup(player_slot: int, def: MiniGameDef) -> void:
	slot = player_slot
	profile = def.control_profile
	buttons = ControlProfile.buttons_for(profile, def.control_hints)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UIKit.font_bold()
	_read_settings()
	UserSettings.changed.connect(_on_setting_changed)
	# A Control parented to a CanvasLayer is not sized by anchors — it stays at
	# zero and silently draws nothing. Size it from the viewport explicitly and
	# follow rotations and window resizes.
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	set_process_input(true)


func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func _read_settings() -> void:
	_scale = float(UserSettings.get_value("touch_scale"))
	_opacity = float(UserSettings.get_value("touch_opacity"))
	_left_handed = bool(UserSettings.get_value("touch_left_handed"))
	_haptics = bool(UserSettings.get_value("vibration"))


func _on_setting_changed(key: String, _value) -> void:
	if key.begins_with("touch") or key == "vibration" or key == "*":
		_read_settings()
		queue_redraw()


## True when the on-screen controls should exist at all.
static func should_show() -> bool:
	match String(UserSettings.get_value("touch_controls")):
		"on":
			return true
		"off":
			return false
	# "auto": show on a touchscreen device, hide everywhere else.
	return DisplayServer.is_touchscreen_available()


# --- geometry --------------------------------------------------------------

func _stick_centre() -> Vector2:
	var r := STICK_RADIUS * _scale * ControlProfile.stick_scale(profile)
	var x := EDGE_MARGIN + r
	if _left_handed:
		x = size.x - EDGE_MARGIN - r
	return Vector2(x, size.y - EDGE_MARGIN - r)


func _aim_centre() -> Vector2:
	var r := STICK_RADIUS * _scale
	var x := size.x - EDGE_MARGIN - r
	if _left_handed:
		x = EDGE_MARGIN + r
	return Vector2(x, size.y - EDGE_MARGIN - r)


## Buttons fan out in an arc away from the stick hand.
func _button_centre(index: int) -> Vector2:
	var r := BUTTON_RADIUS * _scale
	var base_x := size.x - EDGE_MARGIN - r * 1.2
	var dir := -1.0
	if _left_handed:
		base_x = EDGE_MARGIN + r * 1.2
		dir = 1.0
	var base := Vector2(base_x, size.y - EDGE_MARGIN - r * 1.2)
	var angles := [0.0, -55.0, -110.0, -165.0]
	var a := deg_to_rad(float(angles[index % angles.size()]))
	var spread := r * 2.35
	return base + Vector2(cos(a) * spread * dir, sin(a) * spread)


func _steer_rects() -> Array:
	var w := size.x * 0.22
	var h := size.y * 0.34
	var y := size.y - EDGE_MARGIN - h
	var left := Rect2(EDGE_MARGIN, y, w, h)
	var right := Rect2(EDGE_MARGIN + w + 18.0, y, w, h)
	var throttle := Rect2(size.x - EDGE_MARGIN - w, y, w, h)
	if _left_handed:
		throttle = Rect2(EDGE_MARGIN, y, w, h)
		left = Rect2(size.x - EDGE_MARGIN - w * 2.0 - 18.0, y, w, h)
		right = Rect2(size.x - EDGE_MARGIN - w, y, w, h)
	return [left, right, throttle]


func _button_hit(pos: Vector2) -> int:
	var r := BUTTON_RADIUS * _scale
	for i in buttons.size():
		if pos.distance_to(_button_centre(i)) <= r * 1.15:
			return i
	return -1


# --- input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_press(event.index, event.position, event.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_handle_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_press(-1, event.position, event.pressed)
	elif event is InputEventMouseMotion and _owners.has(-1):
		_handle_drag(-1, event.position)


func _handle_press(index: int, pos: Vector2, pressed: bool) -> void:
	if not pressed:
		_release(index)
		return
	var full := ControlProfile.full_screen_tap(profile)
	if full != 0:
		_owners[index] = {"kind": "screen", "bit": full}
		_bits |= full
		_pulse()
		queue_redraw()
		return

	var button := _button_hit(pos)
	if button >= 0:
		_owners[index] = {"kind": "button", "id": button}
		_press_button(button, true)
		return

	if ControlProfile.shows_steering(profile):
		var rects := _steer_rects()
		for i in 3:
			if (rects[i] as Rect2).has_point(pos):
				_owners[index] = {"kind": "steer", "id": i}
				_apply_steer(i, true)
				queue_redraw()
				return
		return

	# Sticks claim their half of the screen, not just their drawn circle: a
	# thumb that lands slightly off should still grab the stick.
	var mid := size.x * 0.5
	var on_stick_side := (pos.x < mid) != _left_handed
	if ControlProfile.shows_move_stick(profile) and on_stick_side:
		_owners[index] = {"kind": "move"}
		_move_origin = pos
		_move_knob = pos
		queue_redraw()
		return
	if ControlProfile.shows_aim_stick(profile) and not on_stick_side:
		_owners[index] = {"kind": "aim"}
		_aim_origin = pos
		_aim_knob = pos
		queue_redraw()


func _handle_drag(index: int, pos: Vector2) -> void:
	var owner = _owners.get(index)
	if owner == null:
		return
	match String(owner["kind"]):
		"move":
			_move_knob = pos
			_move = _stick_vector(_move_origin, pos)
			queue_redraw()
		"aim":
			_aim_knob = pos
			_aim = _stick_vector(_aim_origin, pos)
			queue_redraw()
		"button":
			# Sliding off a button releases it, which is what a player expects.
			if _button_hit(pos) != int(owner["id"]):
				_press_button(int(owner["id"]), false)
				_owners.erase(index)


func _release(index: int) -> void:
	var owner = _owners.get(index)
	if owner == null:
		return
	_owners.erase(index)
	match String(owner["kind"]):
		"move":
			_move = Vector2.ZERO
			_move_knob = _move_origin
		"aim":
			_aim = Vector2.ZERO
			_aim_knob = _aim_origin
		"button":
			_press_button(int(owner["id"]), false)
		"steer":
			_apply_steer(int(owner["id"]), false)
		"screen":
			_bits &= ~int(owner["bit"])
	queue_redraw()


func _stick_vector(origin: Vector2, pos: Vector2) -> Vector2:
	var r := STICK_RADIUS * _scale * ControlProfile.stick_scale(profile)
	var v := (pos - origin) / r
	if v.length() < STICK_DEAD:
		return Vector2.ZERO
	return v.limit_length(1.0)


func _press_button(index: int, down: bool) -> void:
	if index < 0 or index >= buttons.size():
		return
	var bit: int = ControlProfile.BUTTON_BITS.get(buttons[index], 0)
	if down:
		_bits |= bit
		_pressed_buttons[index] = true
		_pulse()
	else:
		_bits &= ~bit
		_pressed_buttons.erase(index)
	queue_redraw()


func _apply_steer(which: int, down: bool) -> void:
	match which:
		0: _steer = -1.0 if down else 0.0
		1: _steer = 1.0 if down else 0.0
		2: _throttle = 1.0 if down else 0.0


func _pulse() -> void:
	if _haptics:
		Input.vibrate_handheld(18)


func _physics_process(_delta: float) -> void:
	var move := _move
	if ControlProfile.shows_steering(profile):
		# Steering games read x as turn and y as throttle; forward is -y, the
		# same convention a keyboard "up" produces.
		move = Vector2(_steer, -_throttle)
	InputRouter.push_virtual(slot, move, _aim, _bits)


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	if size.x <= 0.0:
		return
	var a := clampf(_opacity, 0.05, 1.0)
	var ink := Color(1, 1, 1, a)
	var fill := Color(1, 1, 1, a * 0.14)

	if ControlProfile.full_screen_tap(profile) != 0:
		var active := _bits != 0
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, a * (0.16 if active else 0.05)))
		_label(Loc.t("touch.tap_anywhere"), size * 0.5, ink, 42)
		return

	if ControlProfile.shows_steering(profile):
		var rects := _steer_rects()
		var glyphs := ["◀", "▶", "▲"]
		var states := [_steer < -0.5, _steer > 0.5, _throttle > 0.5]
		for i in 3:
			var r: Rect2 = rects[i]
			draw_rect(r, Color(1, 1, 1, a * (0.22 if states[i] else 0.10)), true)
			draw_rect(r, ink, false, 3.0)
			_label(glyphs[i], r.get_center(), ink, 52)
	elif ControlProfile.shows_move_stick(profile):
		_draw_stick(_stick_centre() if not _owners_has("move") else _move_origin,
			_move_knob if _owners_has("move") else _stick_centre(), ink, fill,
			STICK_RADIUS * _scale * ControlProfile.stick_scale(profile))

	if ControlProfile.shows_aim_stick(profile):
		_draw_stick(_aim_centre() if not _owners_has("aim") else _aim_origin,
			_aim_knob if _owners_has("aim") else _aim_centre(), ink, fill, STICK_RADIUS * _scale)

	var br := BUTTON_RADIUS * _scale
	for i in buttons.size():
		var c := _button_centre(i)
		var down: bool = _pressed_buttons.has(i)
		draw_circle(c, br, Color(1, 1, 1, a * (0.30 if down else 0.12)))
		draw_arc(c, br, 0.0, TAU, 32, ink, 3.0, true)
		_label(_glyph(buttons[i]), c, ink, 34)


func _draw_stick(origin: Vector2, knob: Vector2, ink: Color, fill: Color, r: float) -> void:
	draw_circle(origin, r, fill)
	draw_arc(origin, r, 0.0, TAU, 40, ink, 3.0, true)
	var clamped := origin + (knob - origin).limit_length(r)
	draw_circle(clamped, r * 0.42, Color(ink.r, ink.g, ink.b, ink.a * 0.55))
	draw_arc(clamped, r * 0.42, 0.0, TAU, 24, ink, 2.5, true)


func _owners_has(kind: String) -> bool:
	for o in _owners.values():
		if String(o["kind"]) == kind:
			return true
	return false


func _label(text: String, centre: Vector2, color: Color, size_px: int) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(_font, centre + Vector2(-w * 0.5, size_px * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _glyph(action: String) -> String:
	match action:
		"jump": return "⤒"
		"attack", "shoot": return "✦"
		"action": return "◉"
		"dash", "boost": return "»"
		"ability": return "★"
	return "●"
