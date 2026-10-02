extends RefCounted
## Visual state only: guests never choose a target, scrub tiles or hit fighters.
const Paint = preload("res://src/net/paint_replica.gd")
var warning_sequence := -1
var scrub_sequence := -1


static func capture(game: Node) -> Dictionary:
	var world := Paint.capture(game)
	var position: Vector3 = game._drone.global_position
	world["drone"] = [position.x, position.y, position.z]
	world["rotor"] = fposmod(game._rotor.rotation.y, TAU)
	world["target"] = Paint._index(game._target) if is_instance_valid(game._target) else -1
	world["mark"] = maxf(0.0, game._mark) if world.target >= 0 else 0.0
	world["cycle"] = maxf(0.0, game._cycle)
	world["warning_sequence"] = game._warning_sequence
	world["scrub_sequence"] = game._scrub_sequence
	world["scrub_position"] = [game._last_scrub.x, game._last_scrub.y, game._last_scrub.z]
	return world


static func valid(world: Variant, count: int) -> bool:
	if not Paint.valid(world, count) or not world.get("drone") is Array or world.drone.size() != 3:
		return false
	for value in world.drone:
		if not _bounded(value, -10000.0, 10000.0):
			return false
	if not world.get("scrub_position") is Array or world.scrub_position.size() != 3:
		return false
	for value in world.scrub_position:
		if not _bounded(value, -10000.0, 10000.0):
			return false
	for key in ["warning_sequence", "scrub_sequence"]:
		if not _bounded(world.get(key), 0, 1000000) or world[key] != floorf(float(world[key])):
			return false
	if not _bounded(world.get("rotor"), 0.0, TAU) or not _bounded(world.get("target"), -1.0, 168.0):
		return false
	if world.target != floorf(float(world.target)) or not _bounded(world.get("mark"), 0.0, 1.5) \
			or not _bounded(world.get("cycle"), 0.0, 3.4):
		return false
	return world.target >= 0 or world.mark == 0


func render(game: Node, world: Dictionary, play_events: bool) -> void:
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
	if play_events and warning_sequence >= 0 and int(world.warning_sequence) > warning_sequence and centre != null:
		AudioManager.play_sfx("countdown", centre.global_position)
	if play_events and scrub_sequence >= 0 and int(world.scrub_sequence) > scrub_sequence:
		game.present_scrub(Vector3(world.scrub_position[0], world.scrub_position[1], world.scrub_position[2]))
	warning_sequence = maxi(warning_sequence, int(world.warning_sequence))
	scrub_sequence = maxi(scrub_sequence, int(world.scrub_sequence))


static func _bounded(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high
