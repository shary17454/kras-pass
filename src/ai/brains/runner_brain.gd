extends AIBrain
## Hurdle Dash: run the lane, jump the hurdles.
##
## Jump timing is the whole game. The bot raycasts forward the way a player
## looks ahead, and its jump window is `reaction_time` wide — too early and it
## lands on the hurdle, too late and it clips it. That is why Easy runners trip.

const LOOK_AHEAD := 4.5


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return
	var finish_z: float = controller.call("finish_line_z") if controller.has_method("finish_line_z") else arena.global_position.z + arena.finish_z
	var lane_x: float = arena.global_position.x + arena.lane_x(slot)
	# Drift toward a clear lane rather than tracking one blindly.
	var target := Vector3(lane_x, me.global_position.y, finish_z)
	steer_to(target)
	move.y = -1.0  # always forward down the track

	var obstacle := _distance_to_obstacle(me)
	if obstacle >= 0.0:
		var jump_at: float = lerp(2.6, 1.5, accuracy)
		if obstacle < jump_at and obstacle > 0.5:
			press(Btn.JUMP)
	if rng.randf() < dash_chance * 0.4:
		press(Btn.DASH)


func _distance_to_obstacle(me) -> float:
	var space := controller.get_world_3d().direct_space_state if controller != null else null
	if space == null:
		return -1.0
	var from: Vector3 = me.global_position + Vector3(0, 0.5, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 0, -LOOK_AHEAD))
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return -1.0
	return from.distance_to(hit["position"])
