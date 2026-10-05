extends "res://src/ai/brains/keeper_brain.gd"
## Storm Heart: goalkeeping plus one extra read — the wind-up.
##
## The public wind-up cues home positioning, but an already observed incoming
## shot still needs interception before the new volley. Its bearing is unknown.

var _warning_seen_at := -1.0


func on_configured() -> void:
	super.on_configured()
	_warning_seen_at = -1.0


func on_round_start() -> void:
	super.on_round_start()
	_warning_seen_at = -1.0


func _perceives_warning() -> bool:
	# The global HUD/audio warning is public; action still waits for reaction.
	if not is_instance_valid(controller) or not controller.has_method("is_winding") \
			or not bool(controller.call("is_winding")):
		_warning_seen_at = -1.0
		return false
	if _warning_seen_at < 0.0:
		_warning_seen_at = _time
	return _time - _warning_seen_at + 0.000001 >= maxf(0.0, reaction_time)

func decide(delta: float) -> void:
	if _perceives_warning() and not _has_imminent_goal_threat() \
			and rng.randf() < strategy:
		steer_to(_goal_pos)
		maybe_dash(0.8)
		return
	super.decide(delta)


func _has_imminent_goal_threat() -> bool:
	var ball := _most_dangerous_ball()
	if ball == null:
		return false
	var observed := perceive_ball(ball)
	if observed.is_empty():
		return false
	var position: Vector3 = observed["position"]
	var velocity: Vector3 = observed["velocity"]
	var normal_speed := velocity.dot(_goal_normal)
	if normal_speed >= -0.001:
		return false
	var contact_plane := _goal_pos
	if controller.has_method("keeper_contact_offset"):
		contact_plane += _goal_normal * controller.keeper_contact_offset(float(observed.get("radius", 0.0)))
	var arrival := (contact_plane - position).dot(_goal_normal) / normal_speed
	return arrival >= 0.0 and arrival <= 1.6
