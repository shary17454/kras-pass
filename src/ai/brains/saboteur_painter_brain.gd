extends "res://src/ai/brains/painter_brain.gd"
## Mukharrib: paint, but never paint into the drone's shadow.
##
## One extra read on top of the painter: while a patch is marked, painting it is
## wasted effort and standing on it is a shove. High tiers steer clear and spend
## those seconds elsewhere; low tiers keep colouring squares that are about to
## be scrubbed, which is exactly the mistake a new player makes.

const AVOID_RADIUS := 3.4

var _warning_serial := -1
var _warning_position := Vector3.INF
var _warning_seen_at := 0.0


func on_round_start() -> void:
	super.on_round_start()
	_clear_warning()


func _clear_warning() -> void:
	_warning_serial = -1
	_warning_position = Vector3.INF
	_warning_seen_at = 0.0


func decide(delta: float) -> void:
	if controller != null and controller.has_method("scrub_warning"):
		var warning: Dictionary = controller.call("scrub_warning", can_observe)
		if warning.is_empty():
			_clear_warning()
		else:
			var serial: int = warning.serial
			var position: Vector3 = warning.position
			if serial != _warning_serial or position != _warning_position:
				_warning_serial = serial
				_warning_position = position
				_warning_seen_at = _time
		var mark := _warning_position
		var me := self_body()
		var reacted := _time - _warning_seen_at + 0.000001 >= reaction_time
		if mark != Vector3.INF and reacted and me != null and rng.randf() < edge_awareness:
			if me.global_position.distance_to(mark) < AVOID_RADIUS:
				steer_away(mark, 1.0)
				maybe_dash(0.7)
				return
	super.decide(delta)
