extends "res://src/ai/brains/generic_brain.gd"
## Rising Tide: go up, and push whoever is above you back down.

var _ledge_target := Vector3.INF
var _ground_history := {}
var _prepare_jump := true
var _was_airborne := false


func on_configured() -> void:
	super.on_configured()
	_ledge_target = Vector3.INF
	_ground_history.clear()
	_prepare_jump = true
	_was_airborne = false


func on_round_start() -> void:
	super.on_round_start()
	_ledge_target = Vector3.INF
	_ground_history.clear()
	_prepare_jump = true
	_was_airborne = false


func _perceived_ground(node: Node3D) -> Vector3:
	if not can_observe(node):
		return Vector3.INF
	var id := node.get_instance_id()
	var history: Array = _ground_history.get(id, [])
	if history.is_empty() or float(history.back().time) < _time:
		history.append({"time": _time, "position": _visible_surface(node)})
		if history.size() > HISTORY_CAP:
			history.pop_front()
	_ground_history[id] = history
	for index in range(history.size() - 1, -1, -1):
		if float(history[index].time) <= _time - reaction_time + 0.000001:
			return history[index].position
	return Vector3.INF


func _visible_surface(node: Node3D) -> Vector3:
	for child in node.get_children():
		if child is CollisionShape3D and not child.disabled:
			var height := 0.0
			if child.shape is BoxShape3D:
				height = child.shape.size.y * 0.5
			elif child.shape is CylinderShape3D:
				height = child.shape.height * 0.5
			else:
				continue
			return child.to_global(Vector3.UP * height)
	return node.global_position + Vector3.UP


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return
	var water := arena.water_level()
	var urgency := clampf(3.0 / maxf(0.4, me.global_position.y - water), 0.2, 1.0)

	# A rival directly above is worth attacking: knocking them down costs them
	# far more than the detour costs us.
	var above := _rival_above()
	if above >= 0 and rng.randf() < aggression * 0.8:
		steer_to(predict(above, 0.25))
		maybe_attack(above, 2.5)
		maybe_jump(0.5)
		return

	if _was_airborne and me.is_on_floor():
		_prepare_jump = true
		_ledge_target = Vector3.INF
	_was_airborne = not me.is_on_floor()
	if _ledge_target == Vector3.INF and not me.is_on_floor():
		move = Vector2.ZERO
		return
	if _ledge_target == Vector3.INF or (me.is_on_floor() and me.global_position.distance_to(_ledge_target) < 0.8):
		_ledge_target = _find_higher_ground(me.global_position)
		_prepare_jump = true
	var flat := Vector2(_ledge_target.x - me.global_position.x, _ledge_target.z - me.global_position.z).length()
	# Leave room to rise before reaching the solid side of the next ledge.
	if me.is_on_floor() and _ledge_target.y > me.global_position.y + 0.4 and _prepare_jump:
		if flat < 3.1:
			var away := me.global_position - _ledge_target
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = Vector3(me.global_position.x, 0, me.global_position.z).normalized()
			steer_to(me.global_position + away.normalized() * 4.0, urgency)
			return
		move = Vector2.ZERO
		if Vector2(me.velocity.x, me.velocity.z).length() > 0.25:
			return
		_prepare_jump = false
	steer_to(_ledge_target, 1.0 if _ledge_target.y > me.global_position.y + 0.4 or not me.is_on_floor() else urgency)
	if flat < 1.0:
		move *= flat
	if me.is_on_floor() and _ledge_target.y > me.global_position.y + 0.4 and flat < 3.4:
		press(Btn.JUMP)
	if flat > 6.0:
		maybe_dash(0.6)


func _rival_above() -> int:
	var me := self_body()
	if me == null:
		return -1
	for i in ctx.fighters.size():
		if i == slot or not can_target(i):
			continue
		var p := perceive(i)
		if p.y > me.global_position.y + 0.8 and Vector2(p.x - me.global_position.x, p.z - me.global_position.z).length() < 4.0:
			return i
	return -1


## Nearest static body whose top is above us. Uses the same visible geometry a
## player reads, not a hand-authored path.
func _find_higher_ground(from: Vector3) -> Vector3:
	var arena := ctx.arena as Arena
	if arena == null:
		return from
	var best := from
	var best_score := -INF
	var me := self_body()
	if me == null or not me.can_jump:
		return from
	var impulse := me.jump_velocity * float(me.mods["jump"])
	var jump_height := impulse * impulse / (2.0 * me._gravity()) - 0.08
	for node in arena.get_node_or_null("Static").get_children() if arena.has_node("Static") else []:
		if not node is StaticBody3D:
			continue
		var p := _perceived_ground(node)
		if p == Vector3.INF:
			continue
		if p.y <= from.y + 0.4 or p.y - from.y > jump_height:
			continue
		var dist := Vector2(p.x - from.x, p.z - from.z).length()
		if dist > 14.0:
			continue
		var score := -(p.y - from.y) * 2.0 - dist * 0.5
		if score > best_score:
			best_score = score
			best = p
	return best
