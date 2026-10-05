extends AIBrain
## Colour Stand: move to a safe tile — after noticing the call.
##
## The delay before the bot starts moving is its reaction time plus a random
## dither, so on Easy it genuinely gets caught out. It also cannot see the call
## before it is announced: it polls the controller, which only reports the
## current call.

var _committed: Node3D
var _react_at := 0.0
var _last_call := ""
var _last_call_serial := -1


func on_round_start() -> void:
	super.on_round_start()
	_committed = null
	_react_at = 0.0
	_last_call = ""
	_last_call_serial = -1


func decide(_delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		return
	var call_tag: String = String(controller.call("called_tag")) if controller.has_method("called_tag") else ""
	var serial: int = int(controller.call("called_serial")) if controller.has_method("called_serial") else -1
	if call_tag != _last_call or serial != _last_call_serial:
		_last_call = call_tag
		_last_call_serial = serial
		_committed = null
		_react_at = _time + reaction_time * rng.randf_range(0.8, 1.6)

	if _time < _react_at:
		# Still processing the call: keep doing whatever we were doing.
		return

	if _committed == null or not is_instance_valid(_committed) or not _committed.is_standable() or _committed.tag != call_tag:
		_committed = controller.call("safe_tile_near", me.global_position) if controller.has_method("safe_tile_near") else null
	if _committed == null or not is_instance_valid(_committed):
		return
	steer_to(_committed.global_position)
	var dist := distance_to(_committed.global_position)
	if dist > 3.0:
		maybe_dash(1.5)
