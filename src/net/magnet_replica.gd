extends RefCounted
## Ball array slots are the wire identity; engine instance IDs never cross peers.
const Goal = preload("res://src/net/goal_guard_replica.gd")


static func capture(game: Node) -> Dictionary:
	var world := Goal.capture(game)
	var charge: Array = []
	var active: Array = []
	var held: Array = []
	for slot in game.ctx.player_count():
		charge.append(game._charge[slot])
		active.append(maxf(0.0, game._magnet_until[slot]))
	for ball: GameBall in game.balls:
		held.append(int(game._held.get(ball.get_instance_id(), -1)))
	world["magnet_charge"] = charge
	world["magnet_active"] = active
	world["held"] = held
	return world


static func valid(world: Variant, count: int) -> bool:
	if not Goal.valid(world, count):
		return false
	for field in ["magnet_charge", "magnet_active"]:
		if not world.get(field) is Array or world[field].size() != count:
			return false
		var limit := 1.0 if field == "magnet_charge" else 1.1
		for value in world[field]:
			if not Goal._number(value) or value < 0 or value > limit:
				return false
	if not world.get("held") is Array or world.held.size() != world.balls.size():
		return false
	for owner in world.held:
		if not Goal._number(owner) or owner != floorf(float(owner)) or owner < -1 or owner >= count:
			return false
	return true


static func render(game: Node, world: Dictionary, delta: float, snap: bool) -> void:
	Goal.render(game, world, delta, snap)
	for slot in game.ctx.player_count():
		game._charge[slot] = float(world.magnet_charge[slot])
		game._magnet_until[slot] = float(world.magnet_active[slot])
	game._held.clear()
	for i in game.balls.size():
		if int(world.held[i]) >= 0:
			game._held[game.balls[i].get_instance_id()] = int(world.held[i])
