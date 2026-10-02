extends RefCounted

const Number = preload("res://src/net/goal_guard_replica.gd")
const ARM_COUNT := 3


static func capture(game: Node) -> Dictionary:
	var angles: Array = []
	for hazard in game.ctx.arena._hazards:
		if hazard is ArenaHazards.Sweeper:
			angles.append(wrapf(hazard.rotation.y, -PI, PI))
	return {"angles": angles}


static func valid(world: Variant) -> bool:
	if not world is Dictionary or world.size() != 1 or not world.get("angles") is Array or world.angles.size() != ARM_COUNT:
		return false
	for angle in world.angles:
		if not Number._number(angle) or absf(float(angle)) > PI:
			return false
	return true


static func render(game: Node, world: Dictionary) -> void:
	var index := 0
	for hazard in game.ctx.arena._hazards:
		if hazard is ArenaHazards.Sweeper:
			hazard.rotation.y = float(world.angles[index])
			index += 1
