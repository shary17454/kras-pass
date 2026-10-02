extends RefCounted
## Health and sampled collision feedback only; guests never resolve rams.

const Number = preload("res://src/net/goal_guard_replica.gd")
var _round := -1
var _ram := 0
var _wrecks: Array = []


static func capture(game: Node) -> Dictionary:
	return {"health": game.health.duplicate(), "maximum": game._max_health,
		"ram": game.ram_serial, "position": [game.ram_position.x, game.ram_position.y, game.ram_position.z],
		"wrecks": game.wrecks.duplicate()}


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or world.size() != 5:
		return false
	if not Number._number(world.get("maximum")) or world.maximum < 1.0 or world.maximum > 1000.0:
		return false
	if not _serial(world.get("ram")) or not world.get("position") is Array or world.position.size() != 3:
		return false
	for value in world.position:
		if not Number._number(value) or absf(value) > 10000.0:
			return false
	for key in ["health", "wrecks"]:
		if not world.get(key) is Array or world[key].size() != count:
			return false
	for slot in count:
		var health: Variant = world.health[slot]
		if not Number._number(health) or health < 0.0 or health > world.maximum or not _serial(world.wrecks[slot]) \
			or world.wrecks[slot] > 1 or (world.wrecks[slot] > 0 and health != 0.0):
			return false
	return true


static func _serial(value: Variant) -> bool:
	return Number._number(value) and value == floorf(value) and value >= 0 and value <= 1000000


func render(game: Node, world: Dictionary, round_index: int, feedback: bool) -> void:
	var baseline: bool = _round != round_index or _wrecks.size() != world.wrecks.size()
	game.health.assign(world.health)
	game._max_health = float(world.maximum)
	game.ram_serial = int(world.ram)
	var p: Array = world.position
	game.ram_position = Vector3(p[0], p[1], p[2])
	game.wrecks.assign(world.wrecks)
	game._refresh_bars()
	if feedback and not baseline:
		if int(world.ram) > _ram:
			AudioManager.play_sfx("hit", game.ram_position)
			EventBus.shake(0.35, 0.2)
		for slot in world.wrecks.size():
			if int(world.wrecks[slot]) > int(_wrecks[slot]):
				AudioManager.play_sfx("explode", game.ctx.fighter(slot).global_position)
	_ram = int(world.ram)
	_wrecks = world.wrecks.duplicate()
	_round = round_index
