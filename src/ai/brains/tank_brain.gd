extends "res://src/ai/brains/gunner_brain.gd"
var _route := PackedVector3Array()
var _route_left := 0.0


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return
	var rival := priority_rival()
	if rival < 0:
		return
	var target := predict(rival, 0.2)
	var delta := target - me.global_position
	delta.y = 0.0
	if arena.edge_distance(me.global_position) < 2.0:
		drive_to(arena.retreat_point(me.global_position))
	else:
		if _has_line_of_sight(me.global_position, target):
			drive_to(target)
		else:
			_route_left -= _delta
			if _route_left <= 0.0:
				_route = arena.get_meta("tank_world").route(me.global_position, target)
				_route_left = 1.0
			while _route.size() > 1 and me.global_position.distance_to(_route[0]) < 3.0:
				_route.remove_at(0)
			if not _route.is_empty():
				drive_to(_route[0])
	if delta.length() < 25.0 and me.facing.dot(delta.normalized()) > lerpf(0.85, 0.97, accuracy):
		if _has_line_of_sight(me.global_position, target):
			press(Btn.ATTACK)
	var crate: Vector3 = controller.crate_target(slot)
	if me.global_position.distance_to(crate) > 1.0 and _has_line_of_sight(me.global_position, crate):
		drive_to(crate)
