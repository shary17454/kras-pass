extends RefCounted

const Number = preload("res://src/net/goal_guard_replica.gd")


static func capture(game: Node) -> Dictionary:
	var positions: Array = []
	for floe in game._floes:
		var p: Vector3 = floe.body.global_position
		positions.append([p.x, p.y, p.z])
	return {"positions": positions, "age": game._time}


static func valid(world: Variant) -> bool:
	if not world is Dictionary or world.size() != 2 or not Number._number(world.get("age")) or world.age < 0 or world.age > 3600:
		return false
	if not world.get("positions") is Array or world.positions.size() != 3:
		return false
	for position in world.positions:
		if not position is Array or position.size() != 3:
			return false
		for component in position:
			if not Number._number(component) or absf(float(component)) > 1000.0:
				return false
	return true


static func render(game: Node, world: Dictionary, delta: float, snap: bool) -> void:
	game._time = float(world.age)
	for index in game._floes.size():
		var body: AnimatableBody3D = game._floes[index].body
		body.sync_to_physics = false
		body.collision_layer = 0
		body.collision_mask = 0
		var row: Array = world.positions[index]
		var position := Vector3(row[0], row[1], row[2])
		body.global_position = position if snap or body.global_position.distance_to(position) > 6.0 else body.global_position.lerp(position, clampf(delta * 22.0, 0.0, 1.0))
