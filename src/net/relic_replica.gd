extends Node3D
## Loose-item and carrier presentation. Never invokes pickup/drop rules.

const Items = preload("res://src/net/collectible_replica.gd")
var items: Node3D


static func capture(game: Node) -> Dictionary:
	var loose: Array = []
	if is_instance_valid(game._relic):
		loose.append(game._relic)
	return {"holder": game.holder(), "items": Items.capture(loose)}


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary:
		return false
	var holder: Variant = world.get("holder")
	if not (holder is int or holder is float) or not is_finite(float(holder)) \
			or holder != floorf(float(holder)) or holder < -1 or holder >= count:
		return false
	if not Items.valid(world.get("items"), "gem") or world.items.size() > 1:
		return false
	return holder < 0 or world.items.is_empty()


func render(game: Node, world: Dictionary, delta: float) -> void:
	if not is_instance_valid(items):
		game.cleanup()
		items = Items.new()
		add_child(items)
	items.apply(world.items)
	var holder := int(world.holder)
	if holder != game._holder:
		game._clear_mark()
		game._holder = holder
		if holder >= 0:
			game._build_mark(game.ctx.fighter(holder))
	for slot in game.ctx.player_count():
		var fighter: Fighter = game.ctx.fighter(slot)
		fighter.carrying = 1 if slot == holder else 0
		fighter.can_attack = game.allows_attack() and slot != holder
	if is_instance_valid(game._mark) and holder >= 0:
		game._mark.global_position = game.ctx.fighter(holder).global_position + Vector3(0, 2.3, 0)
		game._mark.rotation.y += delta * 2.4
