extends "res://src/ai/brains/gunner_brain.gd"
const FIRING_RANGE := 12.0
const MUZZLE_CLEARANCE := 3.0
var _route := PackedVector3Array()
var _route_refresh_at := -INF
var _crate_history := {}


func on_configured() -> void:
	super.on_configured()
	_route.clear()
	_route_refresh_at = -INF
	_crate_history.clear()


func on_round_start() -> void:
	super.on_round_start()
	_route.clear()
	_route_refresh_at = -INF
	_crate_history.clear()


func _record_history() -> void:
	super._record_history()
	_sample_visible_crates()


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return
	if arena.edge_distance(me.global_position) < 2.0:
		drive_to(arena.retreat_point(me.global_position))
		return
	var crate := _visible_weapon_crate()
	var rival := priority_rival()
	if rival < 0:
		if crate != null:
			drive_to(_perceived_crate_position(crate))
		else:
			drive_to(ctx.arena_center())
		return
	var target := _firing_target(rival)
	var delta := target - me.global_position
	delta.y = 0.0
	var clear := _has_line_of_sight(me.global_position, target)
	var close_engagement := clear and delta.length() <= FIRING_RANGE
	if clear:
		drive_to(target)
		# DRIVE can steer while stationary. Keep the muzzle clear instead of
		# continually driving through the delayed target during every shot.
		if close_engagement:
			move.y = 0.65 if delta.length() < MUZZLE_CLEARANCE else 0.0
	else:
		if _time >= _route_refresh_at:
			_route = arena.get_meta("tank_world").route(me.global_position, target)
			_route_refresh_at = _time + 1.0
		while not _route.is_empty() and me.global_position.distance_to(_route[0]) < 3.0:
			_route.remove_at(0)
		drive_to(target if _route.is_empty() else _route[0])
	if delta.length() < 25.0 and me.facing.dot(delta.normalized()) > lerpf(0.85, 0.97, accuracy):
		if clear:
			press(Btn.ATTACK)
	if crate != null and not close_engagement:
		drive_to(_perceived_crate_position(crate))


func _firing_target(rival: int) -> Vector3:
	var me := self_body()
	var velocity := _perceived_velocity(rival) * prediction
	velocity.y = 0.0
	var offset := perceive(rival) + velocity * reaction_time - me.global_position - me.facing.normalized() * 1.6
	offset.y = 0.0
	var speed := 22.0
	if controller != null and controller.has_method("projectile_speed_for"):
		speed = maxf(0.01, float(controller.projectile_speed_for(slot)))
	# Intercept uses delayed observations and the bot's own loaded shell only.
	var a := velocity.length_squared() - speed * speed
	var b := 2.0 * offset.dot(velocity)
	var c := offset.length_squared()
	var flight := offset.length() / speed
	if absf(a) < 0.000001:
		if absf(b) > 0.000001 and -c / b >= 0.0:
			flight = -c / b
	else:
		var discriminant := b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var root := sqrt(discriminant)
			var first := (-b - root) / (2.0 * a)
			var second := (-b + root) / (2.0 * a)
			if first >= 0.0:
				flight = first
			if second >= 0.0 and (first < 0.0 or second < first):
				flight = second
	return predict(rival, reaction_time + clampf(flight, 0.0, 2.0))


func _visible_weapon_crate() -> Node3D:
	var me := self_body()
	if me == null:
		return null
	_sample_visible_crates()
	var target: Node3D
	var distance := 30.0
	for id in _crate_history:
		var node := instance_from_id(int(id)) as Node3D
		var position := _perceived_crate_position(node)
		if position == Vector3.INF:
			continue
		var d := me.global_position.distance_to(position)
		if d < distance:
			distance = d
			target = node
	return target


func _sample_visible_crates() -> void:
	var me := self_body()
	if me == null or controller == null or not controller.has_method("weapon_crates"):
		_crate_history.clear()
		return
	var visible := {}
	for node in controller.weapon_crates(slot):
		if not can_observe(node) or not _has_line_of_sight(me.global_position, node.global_position):
			continue
		var id: int = node.get_instance_id()
		visible[id] = true
		var history: Array = _crate_history.get(id, [])
		if history.is_empty() or float(history.back().time) < _time:
			history.append({"time": _time, "position": node.global_position})
			if history.size() > HISTORY_CAP:
				history.pop_front()
		_crate_history[id] = history
	# Disappearing, collected or occluded crates earn fresh observation credit.
	for id in _crate_history.keys():
		if not visible.has(id):
			_crate_history.erase(id)


func _perceived_crate_position(node: Node3D) -> Vector3:
	if not is_instance_valid(node):
		return Vector3.INF
	var history: Array = _crate_history.get(node.get_instance_id(), [])
	for index in range(history.size() - 1, -1, -1):
		if float(history[index].time) <= _time - reaction_time + 0.000001:
			return history[index].position
	return Vector3.INF
