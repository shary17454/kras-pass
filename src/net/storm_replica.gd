extends RefCounted
## The host owns volleys; guests render the turbine and consume feedback once.
const Goal = preload("res://src/net/goal_guard_replica.gd")
var warning_sequence := -1
var volley_sequence := -1


static func capture(game: Node) -> Dictionary:
	var world := Goal.capture(game)
	world["rotor"] = fposmod(game._blades.rotation.y, TAU)
	world["windup"] = maxf(0.0, game._windup)
	world["volley_timer"] = maxf(0.0, game._volley_timer)
	world["warning_sequence"] = game._warning_sequence
	world["volley_sequence"] = game._volley_sequence
	return world


static func valid(world: Variant, count: int) -> bool:
	if not Goal.valid(world, count, 2):
		return false
	for field in ["rotor", "windup", "volley_timer"]:
		var limit: float = {"rotor": TAU, "windup": 1.6, "volley_timer": 8.0}[field]
		if not Goal._number(world.get(field)) or world[field] < 0 or world[field] > limit:
			return false
	for field in ["warning_sequence", "volley_sequence"]:
		if not Goal._number(world.get(field)) or world[field] < 0 or world[field] > 1000000 \
				or world[field] != floorf(float(world[field])):
			return false
	return true


func render(game: Node, world: Dictionary, delta: float, snap: bool, play_events: bool) -> void:
	Goal.render(game, world, delta, snap)
	game._blades.rotation.y = float(world.rotor)
	game._windup = float(world.windup)
	game._volley_timer = float(world.volley_timer)
	if play_events and warning_sequence >= 0 and int(world.warning_sequence) > warning_sequence:
		game.present_warning()
	if play_events and volley_sequence >= 0 and int(world.volley_sequence) > volley_sequence:
		game.present_volley()
	warning_sequence = maxi(warning_sequence, int(world.warning_sequence))
	volley_sequence = maxi(volley_sequence, int(world.volley_sequence))
