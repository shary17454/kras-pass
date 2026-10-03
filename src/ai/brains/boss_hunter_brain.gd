extends "res://src/ai/brains/generic_brain.gd"
## Boss fights: hit the soft spot, leave the marked floor.
##
## Two reads, and the order between them is the whole skill. Every boss attack
## is a ring drawn on the ground before it lands, so a competent bot clears the
## ring first and returns to the weak point after; a poor one keeps swinging
## through the warning. `reaction_time` decides how late the ring is noticed and
## `edge_awareness` how reliably it is respected, so the tiers separate on the
## thing the fight is actually about.

func decide(delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		super.decide(delta)
		return

	if controller.has_method("danger_zones") and rng.randf() < edge_awareness:
		for z in controller.call("danger_zones"):
			var pos: Vector3 = z["pos"]
			var r: float = float(z["radius"])
			# Only bail while there is still time to be somewhere else; a tier
			# that reacts slowly discovers the ring too late to leave it.
			if float(z["left"]) > reaction_time * 0.8 and _flat(pos) < r + float(z.get("margin", 0.8)):
				var away := me.global_position - pos
				away.y = 0.0
				_steer_on_ground(me.global_position + (away.normalized() if away.length() > 0.1 else Vector3.RIGHT) * 5.0)
				maybe_dash(1.3)
				return

	if controller.has_method("attack_plan"):
		var plan: Dictionary = controller.call("attack_plan", me.global_position)
		move = Vector2.ZERO
		if not plan.is_empty():
			var target: Vector3 = plan.target
			_steer_on_ground(target, clampf(_flat(target) * 0.8, 0.0, 1.0))
			if plan.attack and rng.randf() < attack_chance:
				press(Btn.ATTACK)
			return

	if controller.has_method("feeding_plan"):
		var plan: Dictionary = controller.call("feeding_plan", me.global_position)
		if plan.is_empty():
			steer_to(ctx.arena_center(), 0.6)
		else:
			steer_to(plan.target, 0.65 if plan.hot else 1.0)
			if plan.attack and rng.randf() < attack_chance:
				press(Btn.ATTACK)
		keep_off_edge(1.2)
		return

	if not controller.has_method("weak_points"):
		super.decide(delta)
		return
	var spots: Array = controller.call("weak_points")
	if spots.is_empty():
		super.decide(delta)
		return
	var best: Vector3 = spots[0]
	for s in spots:
		if _flat(s) < _flat(best):
			best = s
	steer_to(best)
	# Flat distance, always. A weak point mounted on a boss sits metres above
	# the fighter's head, so a 3D measurement never drops below that vertical
	# offset: against the Dreadnought's 2.7 m vent the closest reading a bot
	# could ever take was 2.7, its swing threshold was 2.6, and the fight
	# measured zero damage across every run. Reach is a floor-plan question.
	var d := _flat(best)
	if d < Balance.num("tuning", "fighter.attack_range", 2.15) + 0.6:
		if rng.randf() < attack_chance:
			press(Btn.ATTACK)
	elif d < 9.0:
		maybe_dash(0.8)
	keep_off_edge(3.0)


func _steer_on_ground(target: Vector3, urgency := 1.0) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null or not is_instance_valid(arena._crater_floor):
		steer_to(target, urgency)
		return
	var origin := me.global_position - arena.global_position
	var direction: Vector3 = arena._crater_floor.steering_direction(origin, target - arena.global_position)
	if direction.is_zero_approx():
		move = Vector2.ZERO
		return
	# Keep difficulty's aim error, but never accept a resulting step into a hole.
	steer_to(me.global_position + direction, urgency)
	var next := origin + Vector3(move.x, 0, move.y) * 1.2
	if not arena._crater_floor.path_clear(origin, next, minf(0.5, maxf(0.0, arena._crater_floor.edge_distance(origin)))):
		move = Vector2.ZERO


## Horizontal distance from this bot to a point.
func _flat(point: Vector3) -> float:
	var me := self_body()
	if me == null:
		return INF
	var to: Vector3 = point - me.global_position
	to.y = 0.0
	return to.length()
