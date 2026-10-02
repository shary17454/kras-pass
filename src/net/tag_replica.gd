extends RefCounted
## Replicate the hunter role without contact detection or score simulation.

static func capture(game: Node) -> Dictionary:
	return {"hunter": game.hunter(), "grace": game.handover_grace()}


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary:
		return false
	var hunter: Variant = world.get("hunter")
	var grace: Variant = world.get("grace")
	return _number(hunter) and hunter == floorf(float(hunter)) and hunter >= -1 and hunter < count \
		and _number(grace) and grace >= 0.0 and grace <= 1.31


static func render(game: Node, world: Dictionary, delta: float) -> void:
	var hunter := int(world.hunter)
	if hunter != game.hunter():
		game._set_hunter(hunter)
	game._grace = float(world.grace)
	if hunter >= 0 and is_instance_valid(game._mark):
		game._mark.global_position = game.ctx.fighter(hunter).global_position + Vector3(0, 2.35, 0)
		game._mark.rotation.y += delta * 3.4


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
