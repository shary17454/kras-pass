extends RefCounted

const Number = preload("res://src/net/goal_guard_replica.gd")


static func capture(game: Node) -> Dictionary:
	var water = game.ctx.arena._water
	return {"level": water.level, "age": water._age}


static func valid(world: Variant) -> bool:
	return world is Dictionary and world.size() == 2 \
		and Number._number(world.get("level")) and absf(float(world.level)) <= 1000.0 \
		and Number._number(world.get("age")) and world.age >= 0.0 and world.age <= 3600.0


static func render(game: Node, world: Dictionary) -> void:
	var water = game.ctx.arena._water
	water.level = float(world.level)
	water._age = float(world.age)
	water.position.y = water.level
	water._mesh.position.y = sin(water._age * 2.0) * 0.08
