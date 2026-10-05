extends "res://src/ai/brains/keeper_brain.gd"
## Storm Heart: goalkeeping plus one extra read — the wind-up.
##
## The public wind-up cues home positioning, but an already observed incoming
## shot still needs interception before the new volley. Its bearing is unknown.

func decide(delta: float) -> void:
	if controller != null and controller.has_method("is_winding") \
			and bool(controller.call("is_winding")) and not _has_imminent_goal_threat() \
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
