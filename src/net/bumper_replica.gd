extends RefCounted

const Number = preload("res://src/net/goal_guard_replica.gd")
const COUNT := 5
var _round := -1
var _hits: Array = []


static func capture(game: Node) -> Dictionary:
	var scales: Array = []
	var hits: Array = []
	for hazard in game.ctx.arena._hazards:
		if hazard is ArenaHazards.Bumper:
			var s: Vector3 = hazard._mesh.scale
			scales.append([s.x, s.y, s.z])
			hits.append(hazard.hit_serial)
	return {"scales": scales, "hits": hits}


static func valid(world: Variant) -> bool:
	if not world is Dictionary or world.size() != 2:
		return false
	for key in ["scales", "hits"]:
		if not world.get(key) is Array or world[key].size() != COUNT:
			return false
	for i in COUNT:
		var serial: Variant = world.hits[i]
		if not Number._number(serial) or serial != floorf(serial) or serial < 0 or serial > 1000000:
			return false
		var scale: Variant = world.scales[i]
		if not scale is Array or scale.size() != 3:
			return false
		for axis in 3:
			if not Number._number(scale[axis]):
				return false
			var value := float(scale[axis])
			if value < (0.8 if axis == 1 else 1.0) - 0.00001 or value > (1.0 if axis == 1 else 1.25) + 0.00001:
				return false
	return true


func render(game: Node, world: Dictionary, round_index: int, feedback: bool) -> void:
	var baseline := _round != round_index or _hits.size() != COUNT
	var index := 0
	for hazard in game.ctx.arena._hazards:
		if hazard is ArenaHazards.Bumper:
			var s: Array = world.scales[index]
			hazard._mesh.scale = Vector3(float(s[0]), float(s[1]), float(s[2]))
			if feedback and not baseline and int(world.hits[index]) > int(_hits[index]):
				AudioManager.play_sfx("bounce", hazard.global_position)
			index += 1
	_hits = world.hits.duplicate()
	_round = round_index
