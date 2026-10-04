extends "res://src/ai/brains/gunner_brain.gd"
var _route := PackedVector3Array()
var _route_refresh_at := -INF


func on_round_start() -> void:
	super.on_round_start()
	_route.clear()
	_route_refresh_at = -INF


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
			drive_to(crate.global_position)
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
		drive_to(crate.global_position)


func _visible_weapon_crate() -> Node3D:
	var me := self_body()
	var target: Node3D
	var distance := 30.0
	for node in controller.weapon_crates(slot):
		if not can_observe(node):
			continue
		var d := me.global_position.distance_to(node.global_position)
		if d < distance and _has_line_of_sight(me.global_position, node.global_position):
			distance = d
			target = node
	return target
