extends Node
## Device -> player-slot routing. Autoload name: `InputRouter`.
##
## Owns one `InputFrame` per slot and refreshes it every physics tick. A slot is
## backed by exactly one source:
##   SOURCE_KEYBOARD  a rebindable key profile (two profiles share one keyboard)
##   SOURCE_PAD       a physical gamepad, addressed by Godot device id
##   SOURCE_VIRTUAL   written by the AI brain, a replay, or the network layer
##
## Because the consumer only ever sees an InputFrame, adding online play means
## feeding SOURCE_VIRTUAL slots from packets — no gameplay code changes.

const MAX_SLOTS := 4
const STICK_DEADZONE := 0.22
const Btn := InputFrame.Btn

enum Source { NONE, KEYBOARD, PAD, VIRTUAL, TOUCH }

const DEFAULT_KEY_PROFILES := [
	{
		"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D,
		"jump": KEY_SPACE, "attack": KEY_F, "action": KEY_E,
		"dash": KEY_SHIFT, "ability": KEY_Q,
	},
	{
		"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
		"jump": KEY_KP_0, "attack": KEY_KP_1, "action": KEY_KP_2,
		"dash": KEY_KP_3, "ability": KEY_KP_4,
	},
]

const PAD_BUTTONS := {
	"jump": JOY_BUTTON_A,
	"attack": JOY_BUTTON_X,
	"action": JOY_BUTTON_B,
	"dash": JOY_BUTTON_RIGHT_SHOULDER,
	"ability": JOY_BUTTON_Y,
}

const BUTTON_BITS := {
	"jump": Btn.JUMP, "action": Btn.ACTION, "attack": Btn.ATTACK,
	"dash": Btn.DASH, "ability": Btn.ABILITY,
}

var _frames: Array[InputFrame] = []
var _sources := []
var _device_ids := []
var _profiles := []
## Frames written by AI/replay/network before the next poll.
var _virtual_pending := []
## While true the router stops reading hardware; the replay player owns slots.
var playback_mode := false

signal binding_changed(profile_index: int)


func _ready() -> void:
	process_priority = -100
	for i in MAX_SLOTS:
		_frames.append(InputFrame.new())
		_sources.append(Source.NONE)
		_device_ids.append(-1)
		_profiles.append(0)
		_virtual_pending.append(InputFrame.new())
	Input.joy_connection_changed.connect(_on_joy_changed)


func _physics_process(_delta: float) -> void:
	for slot in MAX_SLOTS:
		var f: InputFrame = _frames[slot]
		match _sources[slot]:
			Source.KEYBOARD:
				_poll_keyboard(slot, f)
			Source.PAD:
				_poll_pad(slot, f)
			Source.VIRTUAL, Source.TOUCH:
				# Touch and AI publish through the same pending buffer; the only
				# difference is that touch counts as a human at the slot level.
				f.copy_from(_virtual_pending[slot])
			_:
				f.clear()


func frame(slot: int) -> InputFrame:
	if slot < 0 or slot >= MAX_SLOTS:
		return InputFrame.new()
	return _frames[slot]


func source_of(slot: int) -> Source:
	return _sources[slot]


func is_human(slot: int) -> bool:
	return _sources[slot] in [Source.KEYBOARD, Source.PAD, Source.TOUCH]


func assign_keyboard(slot: int, profile_index: int = 0) -> void:
	_sources[slot] = Source.KEYBOARD
	_profiles[slot] = clampi(profile_index, 0, DEFAULT_KEY_PROFILES.size() - 1)
	_device_ids[slot] = -1


func assign_pad(slot: int, device_id: int) -> void:
	_sources[slot] = Source.PAD
	_device_ids[slot] = device_id


func assign_virtual(slot: int) -> void:
	_sources[slot] = Source.VIRTUAL
	_device_ids[slot] = -1


## On-screen controls. Identical plumbing to a virtual slot, but reported as a
## human so pause-on-device-loss and the join flow treat it correctly.
func assign_touch(slot: int) -> void:
	_sources[slot] = Source.TOUCH
	_device_ids[slot] = -1


func clear_slot(slot: int) -> void:
	_sources[slot] = Source.NONE
	_device_ids[slot] = -1
	_frames[slot].clear()


func clear_all() -> void:
	for slot in MAX_SLOTS:
		clear_slot(slot)


## Written by AI brains and the network layer. The values are consumed on the
## next physics tick so producers and consumers never race.
func push_virtual(slot: int, move: Vector2, aim: Vector2, bits: int) -> void:
	var v: InputFrame = _virtual_pending[slot]
	v.move = move.limit_length(1.0)
	v.aim = aim
	v.bits = bits


## Devices currently able to drive a player, for the "press any button to join"
## flow on the local-play screen.
func available_devices() -> Array:
	var out: Array = [
		{"type": Source.KEYBOARD, "id": 0, "label": "keyboard.profile.1"},
		{"type": Source.KEYBOARD, "id": 1, "label": "keyboard.profile.2"},
	]
	for id in Input.get_connected_joypads():
		out.append({"type": Source.PAD, "id": id, "label": Input.get_joy_name(id)})
	return out


## Returns the device that just pressed a confirm button and is not already
## bound to a slot, or an empty dictionary. Drives couch-join without menus.
func poll_join_request(taken: Array) -> Dictionary:
	for id in Input.get_connected_joypads():
		if _device_taken(taken, Source.PAD, id):
			continue
		if Input.is_joy_button_pressed(id, JOY_BUTTON_A) or Input.is_joy_button_pressed(id, JOY_BUTTON_START):
			return {"type": Source.PAD, "id": id}
	for p in DEFAULT_KEY_PROFILES.size():
		if _device_taken(taken, Source.KEYBOARD, p):
			continue
		var keys: Dictionary = _bindings_for(p)
		if Input.is_key_pressed(keys["jump"]):
			return {"type": Source.KEYBOARD, "id": p}
	return {}


func rebind(profile_index: int, action: String, keycode: int) -> void:
	var stored: Dictionary = UserSettings.get_value("bindings")
	var key := "kb%d" % profile_index
	var profile: Dictionary = stored.get(key, {}).duplicate()
	profile[action] = keycode
	stored = stored.duplicate()
	stored[key] = profile
	UserSettings.set_value("bindings", stored)
	binding_changed.emit(profile_index)


func reset_bindings() -> void:
	UserSettings.set_value("bindings", {})
	binding_changed.emit(-1)


func binding_label(profile_index: int, action: String) -> String:
	var code: int = _bindings_for(profile_index).get(action, 0)
	return OS.get_keycode_string(code)


func rumble(slot: int, strength: float, duration: float) -> void:
	if not bool(UserSettings.get_value("vibration")):
		return
	if _sources[slot] != Source.PAD:
		return
	Input.start_joy_vibration(_device_ids[slot], strength * 0.6, strength, duration)


func _bindings_for(profile_index: int) -> Dictionary:
	var base: Dictionary = DEFAULT_KEY_PROFILES[clampi(profile_index, 0, 1)].duplicate()
	var stored: Dictionary = UserSettings.get_value("bindings")
	var custom: Dictionary = stored.get("kb%d" % profile_index, {})
	for k in custom:
		base[k] = int(custom[k])
	return base


func _poll_keyboard(slot: int, f: InputFrame) -> void:
	var keys := _bindings_for(_profiles[slot])
	f.prev_bits = f.bits
	var mv := Vector2.ZERO
	if Input.is_key_pressed(keys["left"]):
		mv.x -= 1.0
	if Input.is_key_pressed(keys["right"]):
		mv.x += 1.0
	if Input.is_key_pressed(keys["up"]):
		mv.y -= 1.0
	if Input.is_key_pressed(keys["down"]):
		mv.y += 1.0
	f.move = mv.normalized() if mv.length_squared() > 1.0 else mv
	f.aim = Vector2.ZERO
	var bits := 0
	for action in BUTTON_BITS:
		if Input.is_key_pressed(keys[action]):
			bits |= BUTTON_BITS[action]
	f.bits = bits
	f.disconnected = false


func _poll_pad(slot: int, f: InputFrame) -> void:
	var dev: int = _device_ids[slot]
	f.prev_bits = f.bits
	if not Input.get_connected_joypads().has(dev):
		f.move = Vector2.ZERO
		f.bits = 0
		if not f.disconnected:
			f.disconnected = true
			EventBus.player_device_lost.emit(slot)
		return
	f.disconnected = false
	var mv := Vector2(
		Input.get_joy_axis(dev, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
	)
	# D-pad is additive so hat-only pads and analog pads behave identically.
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT):
		mv.x -= 1.0
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT):
		mv.x += 1.0
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP):
		mv.y -= 1.0
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN):
		mv.y += 1.0
	f.move = _apply_deadzone(mv)
	f.aim = _apply_deadzone(Vector2(
		Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y)
	))
	var bits := 0
	for action in BUTTON_BITS:
		if Input.is_joy_button_pressed(dev, PAD_BUTTONS[action]):
			bits |= BUTTON_BITS[action]
	# Triggers double as dash so both common muscle memories work.
	if Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
		bits |= Btn.DASH
	f.bits = bits


func _apply_deadzone(v: Vector2) -> Vector2:
	var len := v.length()
	if len < STICK_DEADZONE:
		return Vector2.ZERO
	# Rescale past the deadzone so the first responsive unit is a slow walk
	# rather than a jump to half speed.
	return v.normalized() * minf(1.0, (len - STICK_DEADZONE) / (1.0 - STICK_DEADZONE))


func _device_taken(taken: Array, type: Source, id: int) -> bool:
	for t in taken:
		if t.get("type") == type and int(t.get("id", -1)) == id:
			return true
	return false


func _on_joy_changed(device: int, connected: bool) -> void:
	if connected:
		EventBus.device_connected.emit(device)
		Log.i("gamepad %d connected (%s)" % [device, Input.get_joy_name(device)], "Input")
	else:
		EventBus.device_disconnected.emit(device)
		Log.w("gamepad %d disconnected" % device, "Input")
		for slot in MAX_SLOTS:
			if _sources[slot] == Source.PAD and _device_ids[slot] == device:
				_frames[slot].disconnected = true
				EventBus.player_device_lost.emit(slot)
