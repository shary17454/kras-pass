extends "res://src/ai/brains/generic_brain.gd"
## Zone Hold: get in the circle, and be the only one in it.

var _zone_history: Array[Dictionary] = []
var _zone_id := 0


func on_round_start() -> void:
	super.on_round_start()
	_zone_history.clear()
	_zone_id = 0


func _perceived_zone() -> Dictionary:
	var observed: Dictionary = controller.call("zone_observation", can_observe)
	if observed.is_empty():
		_zone_history.clear()
		_zone_id = 0
		return {}
	if int(observed.id) != _zone_id:
		_zone_history.clear()
		_zone_id = int(observed.id)
	if _zone_history.is_empty() or float(_zone_history.back().time) < _time:
		observed["time"] = _time
		_zone_history.append(observed)
	while _zone_history.size() > HISTORY_CAP:
		_zone_history.pop_front()
	for index in range(_zone_history.size() - 1, -1, -1):
		if float(_zone_history[index].time) <= _time - reaction_time + 0.000001:
			return _zone_history[index]
	return {}


func steer_to(target: Vector3, urgency: float = 1.0) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me != null and arena != null:
		target = arena.annular_waypoint(me.global_position, target)
	super.steer_to(target, urgency)


func _publish_output(movement: Vector2) -> void:
	var actions := bits
	var me := self_body()
	var arena := ctx.arena as Arena
	if (actions & Btn.DASH) != 0 and me != null and arena != null:
		var direction := Vector3(movement.x, 0, movement.y)
		if direction.length_squared() < 0.05:
			direction = me.facing
		var travel := 5.0 * maxf(1.0, float(me.mods.get("speed", 1.0)))
		var landing := me.global_position + direction.normalized() * travel
		if not arena.annular_path_clear(me.global_position, landing, 0.6):
			actions &= ~Btn.DASH
	InputRouter.push_virtual(slot, movement, aim, actions)


func decide(_delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		return
	var observation := _perceived_zone()
	if observation.is_empty():
		move = Vector2.ZERO
		keep_off_edge()
		return
	var zone: Vector3 = observation.position
	var radius: float = observation.radius
	var inside := me.global_position.distance_to(zone) <= radius

	var intruder := _rival_in_zone(zone, radius)
	if inside and intruder >= 0:
		# Someone is sharing the zone and nothing scores until one of us
		# leaves — so the swing has to *eject* them, not merely land. Take the
		# angle that puts them between you and the rim: a hit from the inside
		# pushes them out, the same hit from the outside pushes them into the
		# middle and buys the rival another two seconds of stalemate. Every
		# profile knob measured identical here (0.50 across the board) because
		# the brain was throwing hits with no thought to which way they sent
		# anyone; `strategy` now decides who takes the angle and who just
		# swings.
		var spot := predict(intruder, 0.2)
		if rng.randf() < strategy:
			var outward: Vector3 = spot - zone
			outward.y = 0.0
			if outward.length() > 0.4:
				steer_to(spot - outward.normalized() * 1.7)
			else:
				steer_to(spot)
		else:
			steer_to(spot)
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
		if i == slot or not can_target(i):
			continue
		if perceive(i).distance_to(zone) <= radius:
			return i
	return -1
