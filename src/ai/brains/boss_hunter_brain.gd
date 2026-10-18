extends "res://src/ai/brains/generic_brain.gd"
## Boss fights: hit the soft spot, leave the marked floor.
##
## Two reads, and the order between them is the whole skill. Every boss attack
## is a ring drawn on the ground before it lands, so a competent bot clears the
## ring first and returns to the weak point after; a poor one keeps swinging
## through the warning. `reaction_time` decides how late the ring is noticed and
## `edge_awareness` how reliably it is respected, so the tiers separate on the
## thing the fight is actually about.

var _danger_seen := {}
var _weak_history := {}
var _feeding_history := {}


func on_round_start() -> void:
	super.on_round_start()
	_danger_seen.clear()
	_weak_history.clear()
	_feeding_history.clear()


func perceived_weak_points() -> Array:
	if controller == null or not controller.has_method("weak_point_nodes"):
		_weak_history.clear()
		return []
	return _delayed_visible_positions(controller.call("weak_point_nodes"), _weak_history)


func perceived_feeding_targets() -> Dictionary:
	var ready := {"slag": [], "crates": []}
	if controller == null or not controller.has_method("feeding_nodes"):
		_feeding_history.clear()
		return ready
	var cues: Dictionary = controller.call("feeding_nodes")
	for group in ready:
		var history: Dictionary = _feeding_history.get(group, {})
		ready[group] = _delayed_visible_positions(cues.get(group, []), history)
		_feeding_history[group] = history
	return ready


func _delayed_visible_positions(cues: Array, history: Dictionary) -> Array:
	var observed := {}
	var ready: Array = []
	for cue in cues:
		if not cue is Node3D or not can_observe(cue):
			continue
		var id: int = cue.get_instance_id()
		var samples: Array = history.get(id, [])
		if samples.is_empty() or float(samples.back().time) < _time:
			samples.append({"time": _time, "pos": cue.global_position})
		while samples.size() > HISTORY_CAP:
			samples.pop_front()
		observed[id] = samples
		# Both target acquisition and later movement use delayed visible samples.
		for index in range(samples.size() - 1, -1, -1):
			if float(samples[index].time) <= _time - reaction_time + 0.000001:
				ready.append(samples[index].pos)
				break
	history.clear()
	history.merge(observed)
	return ready


func perceived_dangers() -> Array:
	var observed := {}
	var ready: Array = []
	if controller == null or not controller.has_method("danger_zones"):
		_danger_seen.clear()
		return ready
	for zone in controller.call("danger_zones"):
		var cue = zone.get("node")
		if not cue is Node3D or not can_observe(cue):
			continue
		var id: int = cue.get_instance_id()
		var samples: Array = _danger_seen.get(id, [])
		if samples.is_empty() or float(samples.back().time) < _time:
			samples.append({"time": _time, "zone": zone.duplicate(true)})
		while samples.size() > HISTORY_CAP:
			samples.pop_front()
		observed[id] = samples
		# Mature cues still use delayed geometry, not live controller updates.
		for index in range(samples.size() - 1, -1, -1):
			var sample: Dictionary = samples[index]
			if float(sample.time) <= _time - reaction_time + 0.000001:
				var danger: Dictionary = sample.zone.duplicate(true)
				if not bool(danger.get("persistent", false)):
					danger.left = maxf(0.0, float(danger.left) - maxf(0.0, _time - float(sample.time)))
				ready.append(danger)
				break
	# A removed or hidden cue cannot carry reaction credit into a new warning.
	_danger_seen = observed
	return ready


func decide(delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		super.decide(delta)
		return

	var dangers := perceived_dangers()
	if rng.randf() < edge_awareness:
		for z in dangers:
			var pos: Vector3 = z["pos"]
			var r: float = float(z["radius"])
			# Only bail while there is still time to be somewhere else; a tier
			# that reacts slowly discovers the ring too late to leave it.
			if float(z["left"]) > reaction_time * 0.8 and _flat(pos) < r + float(z.get("margin", 0.8)):
				var away := me.global_position - pos
				away.y = 0.0
				var direction := away.normalized() if away.length() > 0.1 else Vector3.RIGHT
				if bool(z.get("persistent", false)):
					var target := pos + direction * (r + float(z.get("margin", 0.8)) + 0.15)
					_steer_on_ground(target, clampf(_flat(target) * 0.8, 0.0, 1.0))
				else:
					_steer_on_ground(me.global_position + direction * 5.0)
					maybe_dash(1.3)
				return

	if controller.has_method("attack_plan"):
		var plan: Dictionary
		if controller.has_method("weak_point_nodes"):
			plan = controller.call("attack_plan", me.global_position, perceived_weak_points())
		else:
			plan = controller.call("attack_plan", me.global_position)
		move = Vector2.ZERO
		if not plan.is_empty():
			var target: Vector3 = plan.target
			_steer_on_ground(target, clampf(_flat(target) * 0.8, 0.0, 1.0))
			if plan.attack and rng.randf() < attack_chance:
				tap(Btn.ATTACK)
			return
		if controller.has_method("staging_point"):
			_steer_on_ground(controller.call("staging_point", _idle_phase + _time * 0.2), 0.6)
			return

	if controller.has_method("feeding_plan"):
		var plan: Dictionary
		if controller.has_method("feeding_nodes"):
			plan = controller.call("feeding_plan", me.global_position, perceived_feeding_targets())
		else:
			plan = controller.call("feeding_plan", me.global_position)
		if plan.is_empty():
			steer_to(ctx.arena_center(), 0.6)
		else:
			steer_to(plan.target, 0.65 if plan.hot else 1.0)
			if plan.attack and rng.randf() < attack_chance:
				tap(Btn.ATTACK)
		keep_off_edge(1.2)
		return

	if not controller.has_method("weak_points"):
		super.decide(delta)
		return
	var spots: Array = perceived_weak_points() if controller.has_method("weak_point_nodes") else controller.call("weak_points")
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
			tap(Btn.ATTACK)
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


func _publish_output(movement: Vector2) -> void:
	var actions := _take_actions()
	var me := self_body()
	var arena := ctx.arena as Arena
	if (actions & Btn.DASH) != 0 and me != null and arena != null and is_instance_valid(arena._crater_floor):
		var direction := Vector3(movement.x, 0.0, movement.y)
		if me.locomotion == Fighter.Locomotion.DRIVE or direction.length_squared() < 0.05:
			direction = me.facing
		var origin := me.global_position - arena.global_position
		# Match the shared dash projection; speed items only increase the guard.
		var travel := 5.0 * maxf(1.0, float(me.mods.get("speed", 1.0)))
		var landing := origin + direction.normalized() * travel
		var margin := minf(0.5, maxf(0.0, arena._crater_floor.edge_distance(origin)))
		if not arena._crater_floor.path_clear(origin, landing, margin):
			actions &= ~Btn.DASH
	InputRouter.push_virtual(slot, movement, aim, actions)


## Horizontal distance from this bot to a point.
func _flat(point: Vector3) -> float:
	var me := self_body()
	if me == null:
		return INF
	var to: Vector3 = point - me.global_position
	to.y = 0.0
	return to.length()
