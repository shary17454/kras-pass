extends "res://src/ai/brains/gunner_brain.gd"
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
	var target := predict(rival, 0.2)
	var delta := target - me.global_position
	delta.y = 0.0
	if _has_line_of_sight(me.global_position, target):
		drive_to(target)
	else:
		if _time >= _route_refresh_at:
			_route = arena.get_meta("tank_world").route(me.global_position, target)
			_route_refresh_at = _time + 1.0
		while not _route.is_empty() and me.global_position.distance_to(_route[0]) < 3.0:
			_route.remove_at(0)
		drive_to(target if _route.is_empty() else _route[0])
	if delta.length() < 25.0 and me.facing.dot(delta.normalized()) > lerpf(0.85, 0.97, accuracy):
		if _has_line_of_sight(me.global_position, target):
			press(Btn.ATTACK)
	if crate != null:
		drive_to(_perceived_crate_position(crate))


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
