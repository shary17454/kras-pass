extends RefCounted

const Number = preload("res://src/net/goal_guard_replica.gd")


static func capture(game: Node) -> Dictionary:
	var lives: Array = []
	var damage: Array = []
	for slot in game.ctx.player_count():
		lives.append(game.lives(slot))
		damage.append(game.ctx.fighter(slot).damage_percent)
	return {"lives": lives, "damage": damage}


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or world.size() != 2:
		return false
	for key in ["lives", "damage"]:
		if not world.get(key) is Array or world[key].size() != count:
			return false
	for slot in count:
		var life: Variant = world.lives[slot]
		var damage: Variant = world.damage[slot]
		if not Number._number(life) or life != floorf(life) or life < 0 or life > 3:
			return false
		if not Number._number(damage) or damage < 0.0 or damage > 10000.0:
			return false
	return true


static func render(game: Node, world: Dictionary) -> void:
	for slot in world.lives.size():
		game._lives[slot] = int(world.lives[slot])
		game.ctx.fighter(slot).damage_percent = float(world.damage[slot])
