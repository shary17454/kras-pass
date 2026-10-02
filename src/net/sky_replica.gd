extends RefCounted
## Bank and warning are host state; presentation never applies slope forces.
const Goal = preload("res://src/net/goal_guard_replica.gd")
var warning_sequence := -1
var tilt_sequence := -1


static func capture(game: Node) -> Dictionary:
	var world := Goal.capture(game)
	world["engine"] = game._warning_engine
	world["bank"] = game._bank
	world["warning"] = maxf(0.0, game._warn)
	world["tilting"] = maxf(0.0, game._tilting)
	world["cycle"] = maxf(0.0, game._cycle)
	world["warning_sequence"] = game._warning_sequence
	world["tilt_sequence"] = game._tilt_sequence
	return world


static func valid(world: Variant, count: int) -> bool:
	if not Goal.valid(world, count):
		return false
	for field in ["bank", "warning", "tilting", "cycle"]:
		var limit: float = {"bank": 1.0, "warning": 1.2, "tilting": 4.0, "cycle": 9.0}[field]
		if not Goal._number(world.get(field)) or world[field] < 0 or world[field] > limit:
			return false
	for field in ["engine", "warning_sequence", "tilt_sequence"]:
		var low := -1 if field == "engine" else 0
		var high := 3 if field == "engine" else 1000000
		if not Goal._number(world.get(field)) or world[field] < low or world[field] > high \
				or world[field] != floorf(float(world[field])):
			return false
	return world.engine >= 0 or (world.bank == 0 and world.warning == 0 and world.tilting == 0)


func render(game: Node, world: Dictionary, delta: float, snap: bool, play_events: bool) -> void:
	Goal.render(game, world, delta, snap)
	game._warning_engine = int(world.engine)
	game._down = game.engine_direction(game._warning_engine)
	game._bank = float(world.bank)
	game._warn = float(world.warning)
	game._tilting = float(world.tilting)
	game._cycle = float(world.cycle)
	game._tick_platform(0.0)
	if play_events and warning_sequence >= 0 and int(world.warning_sequence) > warning_sequence:
		game.present_warning()
	if play_events and tilt_sequence >= 0 and int(world.tilt_sequence) > tilt_sequence:
		game.present_tilt()
	warning_sequence = maxi(warning_sequence, int(world.warning_sequence))
	tilt_sequence = maxi(tilt_sequence, int(world.tilt_sequence))
