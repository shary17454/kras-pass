extends "res://src/ai/brains/generic_brain.gd"
## Zone Hold: get in the circle, and be the only one in it.


func decide(_delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		return
	var zone: Vector3 = controller.get("zone_position")
	var radius: float = float(controller.get("zone_radius"))
	var inside := me.global_position.distance_to(zone) <= radius

	var intruder := _rival_in_zone(zone, radius)
	if inside and intruder >= 0:
		# Someone is sharing the zone: nothing scores until one of us leaves.
		steer_to(predict(intruder, 0.2))
		maybe_attack(intruder, 2.6)
		if rng.randf() < aggression:
			maybe_dash(1.2)
		return
	if inside:
		# Hold near the middle of the circle so a shove does not eject us.
		steer_to(zone, 0.55)
		var near := nearest_rival()
		if near >= 0 and distance_to(perceive(near)) < 3.2:
			maybe_attack(near, 2.6)
		return
	steer_to(zone)
	if distance_to(zone) > 6.0:
		maybe_dash(0.9)
	keep_off_edge()


func _rival_in_zone(zone: Vector3, radius: float) -> int:
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i):
			continue
		if perceive(i).distance_to(zone) <= radius:
			return i
	return -1
