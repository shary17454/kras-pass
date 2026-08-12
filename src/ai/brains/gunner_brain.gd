extends AIBrain
## Turret Duel: keep distance, break line of sight, shoot on a clean angle.
##
## The bot only fires when its own facing already lines up with the target — it
## cannot shoot around corners, and it will not fire through a pillar, because
## it checks the same collision world the player's eyes do.

const IDEAL_RANGE := 12.0


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return
	if arena.edge_distance(me.global_position) < 3.5:
		drive_to(arena.retreat_point(me.global_position))
		return

	var target := priority_rival()
	if target < 0:
		drive_to(arena.global_position)
		return
	var spot := predict(target, 0.4)
	var to := spot - me.global_position
	to.y = 0.0
	var dist := to.length()

	# Hold a firing distance: strafe-circle by aiming at a point offset from
	# the target rather than at the target itself.
	var tangent := Vector3(-to.z, 0, to.x).normalized() * (1.0 if slot % 2 == 0 else -1.0)
	var hold: Vector3 = spot - to.normalized() * IDEAL_RANGE + tangent * 5.0
	drive_to(hold if dist < IDEAL_RANGE * 1.6 else spot)

	var aligned: float = me.facing.normalized().dot(to.normalized())
	if aligned > lerp(0.93, 0.985, accuracy) and dist < 22.0 and _has_line_of_sight(me.global_position, spot):
		if rng.randf() < attack_chance + 0.25:
			press(Btn.ATTACK)
	if dist > IDEAL_RANGE * 2.0:
		maybe_dash(0.8)


func _has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	var space := controller.get_world_3d().direct_space_state if controller != null else null
	if space == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 1.0, 0), to + Vector3(0, 1.0, 0))
	q.collision_mask = 1
	return space.intersect_ray(q).is_empty()
