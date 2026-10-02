extends RefCounted

const UNFINISHED := 99999
const Number = preload("res://src/net/goal_guard_replica.gd")
var last_round := -1
var last_times: Array = []


static func capture(game: Node) -> Dictionary:
	return {"elapsed": game._elapsed, "times": Array(game.finish_times)}


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or world.size() != 2:
		return false
	if not Number._number(world.get("elapsed")) or world.elapsed < 0.0 or world.elapsed > 3600.0:
		return false
	if not world.get("times") is Array or world.times.size() != count:
		return false
	for time in world.times:
		if not Number._number(time) or time != floorf(time) or time < 0 or time > 360000:
			return false
		if time != UNFINISHED and time > roundf(float(world.elapsed) * 100.0):
			return false
	return true


func render(game: Node, world: Dictionary, round_index: int, play_events: bool) -> void:
	game._elapsed = float(world.elapsed)
	game._banner = "%.2f" % game._elapsed
	game._finished = 0
	for slot in world.times.size():
		var time := int(world.times[slot])
		game.finish_times[slot] = time
		if time != UNFINISHED:
			game._finished += 1
			if play_events and last_round == round_index and slot < last_times.size() and int(last_times[slot]) == UNFINISHED:
				AudioManager.play_sfx("score")
		# Guest fighters never accept local physics; the authoritative snapshot moves them.
		game.ctx.fighters[slot].control_enabled = false
	last_round = round_index
	last_times = world.times.duplicate()
