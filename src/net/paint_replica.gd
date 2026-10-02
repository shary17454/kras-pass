extends RefCounted
## Authored paint_grid coordinates are -6..6 on each axis. The fixed layout
## is validated in tests so ownership arrays cannot silently shift tiles.
const EXTENT := 6
const SIDE := 13
const TILE_COUNT := SIDE * SIDE


static func capture(game: Node) -> Dictionary:
	var owners: Array = []
	owners.resize(TILE_COUNT)
	owners.fill(-1)
	for tile: ArenaTile in game._tiles:
		owners[_index(tile)] = tile.owner_slot
	return {"owners": owners}


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or not world.get("owners") is Array \
			or world.owners.size() != TILE_COUNT:
		return false
	for owner in world.owners:
		if not (owner is float or owner is int) or not is_finite(float(owner)) \
				or owner != floorf(float(owner)) or owner < -1 or owner >= count:
			return false
	return true


static func render(game: Node, world: Dictionary) -> void:
	for tile: ArenaTile in game._tiles:
		var owner := int(world.owners[_index(tile)])
		if tile.owner_slot == owner:
			continue
		if owner < 0:
			tile.owner_slot = -1
			tile.set_color(tile.base_color)
		else:
			tile.claim(owner, UIKit.adapt(game.ctx.config.players[owner].color()))


static func _index(tile: ArenaTile) -> int:
	return (tile.grid_x + EXTENT) * SIDE + tile.grid_z + EXTENT
