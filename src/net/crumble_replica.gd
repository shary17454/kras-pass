extends RefCounted
## Canonical authored circle: integer coordinates -6..6 with x*x+z*z <= 36.
## Each row is [state, timer, local height, collapse sequence]. No guest rules.
const TILE_COUNT := 113
const Number = preload("res://src/net/goal_guard_replica.gd")
var sequences: Array = []


static func capture(game: Node) -> Dictionary:
	var rows: Array = []
	for tile: ArenaTile in game.ctx.arena.tiles:
		# Hidden tiles need no unbounded height after a delayed simulation tick.
		var height := -12.0 if tile.state == ArenaTile.State.GONE else tile.position.y
		rows.append([tile.state, maxf(0.0, tile._timer), height, tile.collapse_sequence])
	return {"tiles": rows}


static func valid(world: Variant) -> bool:
	if not world is Dictionary or not world.get("tiles") is Array or world.tiles.size() != TILE_COUNT:
		return false
	for row in world.tiles:
		if not row is Array or row.size() != 4:
			return false
		for value in row:
			if not Number._number(value):
				return false
		if row[0] != floorf(row[0]) or row[0] < 0 or row[0] > 3 \
				or row[1] < 0 or row[1] > 10 or row[2] < -32 or row[2] > 0 \
				or row[3] != floorf(row[3]) or row[3] < 0 or row[3] > 1000000:
			return false
		if row[0] == ArenaTile.State.SOLID and (row[1] != 0 or row[2] != 0):
			return false
		if row[0] == ArenaTile.State.WARNING and (row[1] > 0.9 or row[2] != 0):
			return false
	return true


func render(game: Node, world: Dictionary, play_events: bool) -> void:
	if sequences.is_empty():
		sequences.resize(TILE_COUNT)
		sequences.fill(-1)
	for i in game.ctx.arena.tiles.size():
		var tile: ArenaTile = game.ctx.arena.tiles[i]
		var row: Array = world.tiles[i]
		var changed := tile.state != int(row[0])
		tile.state = int(row[0])
		tile._timer = float(row[1])
		tile.position.y = float(row[2])
		tile.collision_layer = 0
		tile.visible = tile.state != ArenaTile.State.GONE
		if tile.state == ArenaTile.State.WARNING:
			tile._update_warning_visual()
		else:
			tile._mesh.position.x = 0.0
			if changed:
				tile._mesh.material_override = MeshFactory.toon(tile.base_color)
		if play_events and sequences[i] >= 0 and int(row[3]) > sequences[i]:
			AudioManager.play_sfx("crate_break", tile.global_position)
		sequences[i] = maxi(sequences[i], int(row[3]))
