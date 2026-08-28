extends "res://src/minigames/paint_grid.gd"
## Mnatiq — Paint Grid where geometry beats mileage.
##
## Colouring tiles one underfoot at a time is the slow way. Close a loop and
## everything inside it flips to you at once: whenever a tile changes hands the
## board floods outward from its rim, and any pocket the rim's flood cannot
## reach — because your colour walls it off — is yours. Painting well now means
## *drawing*, and the biggest scores go to the player brave enough to sketch a
## long border through contested ground.

var _by_coord := {}
var _capturing := false


func build() -> void:
	super.build()
	_by_coord.clear()
	for t in _tiles:
		_by_coord[Vector2i(t.grid_x, t.grid_z)] = t


func _on_tile_claimed(tile: ArenaTile, slot: int) -> void:
	# claim() inside the capture would re-enter this hook for every flipped
	# tile and flood once per tile of the region; one pass per real step.
	if _capturing:
		return
	_capturing = true
	_capture_enclosed(slot)
	_capturing = false


## Flood from the board's rim across every tile that is not `slot`'s. What the
## flood cannot reach is sealed off by `slot`'s colour, so it becomes theirs.
func _capture_enclosed(slot: int) -> void:
	if _tiles.is_empty():
		return
	var open := {}
	var queue: Array[Vector2i] = []
	for t in _tiles:
		if t.owner_slot == slot:
			continue
		var c := Vector2i(t.grid_x, t.grid_z)
		# Rim tile: any missing 4-neighbour means it touches the outside.
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not _by_coord.has(c + d):
				open[c] = true
				queue.append(c)
				break
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if open.has(n) or not _by_coord.has(n):
				continue
			var t: ArenaTile = _by_coord[n]
			if t.owner_slot == slot:
				continue
			open[n] = true
			queue.append(n)
	var col := UIKit.adapt(ctx.config.players[slot].color())
	var captured := 0
	for t in _tiles:
		if t.owner_slot == slot:
			continue
		if not open.has(Vector2i(t.grid_x, t.grid_z)):
			t.claim(slot, col)
			captured += 1
	if captured > 0:
		ctx.bump_detail(slot, "regions")
		AudioManager.play_sfx("score")
		EventBus.shake(minf(0.4, captured * 0.02), 0.2)


func detail_rows() -> Array:
	return [
		{"key": "results.stat.tiles", "field": "tiles"},
		{"key": "results.stat.regions", "field": "regions"},
	]
