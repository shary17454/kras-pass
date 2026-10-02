extends RefCounted
## Host-owned quilt, called color and phase. Guests only present the decision.
const Floor = preload("res://src/net/crumble_replica.gd")
const Number = preload("res://src/net/goal_guard_replica.gd")
const TILE_COUNT := 121
var floor_view = Floor.new()
var call_sequence := -1
var drop_sequence := -1


static func capture(game: Node) -> Dictionary:
	var world := Floor.capture(game)
	var colors: Array = []
	for tile: ArenaTile in game.ctx.arena.tiles:
		colors.append(game.COLOR_NAMES.find(tile.tag))
	world.merge({"colors": colors, "called": game._called, "stage": game._stage,
		"timer": maxf(0.0, game._timer), "call_sequence": game.call_sequence,
		"drop_sequence": game.drop_sequence})
	return world


static func valid(world: Variant) -> bool:
	if not Floor.valid(world, TILE_COUNT) or not world.get("colors") is Array or world.colors.size() != TILE_COUNT:
		return false
	for value in world.colors:
		if not _integer(value, 3):
			return false
	if not _integer(world.get("called"), 3) or not _integer(world.get("stage"), 2):
		return false
	if not _integer(world.get("call_sequence"), 1000000) or not _integer(world.get("drop_sequence"), 1000000):
		return false
	if not Number._number(world.get("timer")) or world.timer < 0 or world.timer > 60:
		return false
	return true


static func _integer(value: Variant, limit: int) -> bool:
	return Number._number(value) and value == floorf(value) and value >= 0 and value <= limit


func render(game: Node, world: Dictionary, play_events: bool) -> void:
	for i in TILE_COUNT:
		var tile: ArenaTile = game.ctx.arena.tiles[i]
		var color: int = int(world.colors[i])
		if tile.tag != game.COLOR_NAMES[color]:
			tile.tag = game.COLOR_NAMES[color]
			tile.set_color(game.COLORS[color], 0.25)
	floor_view.render(game, world, false)
	game._called = int(world.called)
	game._stage = int(world.stage)
	game._timer = float(world.timer)
	if play_events and call_sequence >= 0 and int(world.call_sequence) > call_sequence:
		AudioManager.play_sfx("countdown")
	if play_events and drop_sequence >= 0 and int(world.drop_sequence) > drop_sequence:
		AudioManager.play_sfx("whistle")
	call_sequence = maxi(call_sequence, int(world.call_sequence))
	drop_sequence = maxi(drop_sequence, int(world.drop_sequence))
