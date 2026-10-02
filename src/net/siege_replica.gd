extends RefCounted
## Fixed, roster-ordered base views; no guest damage, collisions or eliminations.

const Fields = preload("res://src/net/crate_replica.gd")
var _round := -1
var _hits: Array = []
var _health: Array = []


static func capture(game: Node) -> Dictionary:
	var bases: Array = []
	for base in game._bases:
		bases.append({"health": base.health, "cooldown": base.cooldown,
			"rotation": wrapf(base.crystal.rotation.y, -PI, PI),
			"height": base.crystal.position.y, "hits": base.hits})
	return {"bases": bases}


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or world.size() != 1 \
		or not world.get("bases") is Array or world.bases.size() != count:
		return false
	for base in world.bases:
		if not base is Dictionary or base.size() != 5 or not Fields._integer(base.get("hits"), 0, 1000000):
			return false
		for field in ["health", "cooldown", "rotation", "height"]:
			if not Fields.Number._number(base.get(field)):
				return false
		if base.health < 0.0 or base.health > 100.0 or base.cooldown < 0.0 or base.cooldown > 0.3 \
			or absf(base.rotation) > PI or base.height < 1.279 or base.height > 1.421:
			return false
	return true


func render(game: Node, world: Dictionary, round_index: int, feedback: bool) -> void:
	var baseline: bool = _round != round_index or _hits.size() != world.bases.size()
	game.presentation_only = true
	for slot in world.bases.size():
		var row: Dictionary = world.bases[slot]
		var base: Dictionary = game._bases[slot]
		base.health = float(row.health)
		base.cooldown = float(row.cooldown)
		base.hits = int(row.hits)
		base.body.collision_layer = 0
		base.node.visible = float(row.health) > 0.0
		base.crystal.rotation.y = float(row.rotation)
		base.crystal.position.y = float(row.height)
		game._refresh_base(base)
		if feedback and not baseline:
			if int(row.hits) > int(_hits[slot]):
				AudioManager.play_sfx("crate_break", base.node.global_position, 1.15)
				EventBus.shake(0.12, 0.14)
				_burst(base, 8, 2.4, 0.4)
			if float(_health[slot]) > 0.0 and float(row.health) == 0.0:
				AudioManager.play_sfx("explode", base.node.global_position)
				EventBus.shake(0.5, 0.35)
				_burst(base, 22, 4.5, 0.7)
	_hits = world.bases.map(func(base): return int(base.hits))
	_health = world.bases.map(func(base): return float(base.health))
	_round = round_index


func _burst(base: Dictionary, count: int, radius: float, lifetime: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var burst := MeshFactory.burst(base.colour, count, radius, lifetime)
	base.node.get_parent().add_child(burst)
	burst.global_position = base.node.global_position + Vector3(0, 1.35, 0)
