extends RefCounted
## Visual state only: guests never choose a target, scrub tiles or hit fighters.
const Paint = preload("res://src/net/paint_replica.gd")


static func capture(game: Node) -> Dictionary:
	var world := Paint.capture(game)
	var position: Vector3 = game._drone.global_position
	world["drone"] = [position.x, position.y, position.z]
	world["rotor"] = fposmod(game._rotor.rotation.y, TAU)
	world["target"] = Paint._index(game._target) if is_instance_valid(game._target) else -1
	world["mark"] = maxf(0.0, game._mark) if world.target >= 0 else 0.0
	world["cycle"] = maxf(0.0, game._cycle)
	return world


static func valid(world: Variant, count: int) -> bool:
	if not Paint.valid(world, count) or not world.get("drone") is Array or world.drone.size() != 3:
		return false
	for value in world.drone:
		if not _bounded(value, -10000.0, 10000.0):
			return false
	if not _bounded(world.get("rotor"), 0.0, TAU) or not _bounded(world.get("target"), -1.0, 168.0):
		return false
	if world.target != floorf(float(world.target)) or not _bounded(world.get("mark"), 0.0, 1.5) \
			or not _bounded(world.get("cycle"), 0.0, 3.4):
		return false
	return world.target >= 0 or world.mark == 0


static func render(game: Node, world: Dictionary) -> void:
	Paint.render(game, world)
	game._drone.global_position = Vector3(world.drone[0], world.drone[1], world.drone[2])
	game._rotor.rotation.y = float(world.rotor)
	var centre: ArenaTile = null
	if int(world.target) >= 0:
		for tile: ArenaTile in game._tiles:
			if Paint._index(tile) == int(world.target):
				centre = tile
				break
	if game._target != centre:
		game._target = centre
		if centre == null:
			game._clear_markers()
		else:
			game._show_markers(centre)
	game._mark = float(world.mark)
	game._cycle = float(world.cycle)


static func _bounded(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high
