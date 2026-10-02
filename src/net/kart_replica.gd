extends Node3D
## Course progress and rescue presentation only; host owns laps and boosts.

const Number = preload("res://src/net/goal_guard_replica.gd")
const Kart = preload("res://src/minigames/kart_sprint.gd")
const Recovery = preload("res://src/fx/race_recovery.gd")
var rescues := {}
var _round := -1
var _laps: Array = []
var _boosts: Array = []


static func capture(game: Node) -> Dictionary:
	var recovery: Array = []
	for slot in game.ctx.player_count():
		var state: Dictionary = game._recoveries.get(slot, {})
		recovery.append(clampf(float(state.time) / Kart.RECOVERY_SECONDS, 0.0, 1.0) if not state.is_empty() else -1.0)
	var pads: Array = []
	for pad in game._boost_pads:
		var row: Array = []
		for slot in game.ctx.player_count(): row.append(clampf(float(pad.cooldown.get(slot, 0.0)), 0.0, 2.0))
		pads.append(row)
	return {"elapsed": game._elapsed, "times": Array(game.finish_times), "lap": Array(game.lap),
		"next": Array(game._next_cp), "started": Array(game._started), "laps": game.laps(),
		"checkpoints": game._checkpoints.size(), "recovery": recovery,
		"boost": {"serial": Array(game.boost_serial), "pads": pads}}


static func valid(world: Variant, count: int, expected_checkpoints: int = 0) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or world.size() != 9:
		return false
	if not Number._number(world.get("elapsed")) or world.elapsed < 0.0 or world.elapsed > 3600.0 \
		or not _integer(world.get("laps"), 1, 10) or not _integer(world.get("checkpoints"), 1, 1024):
		return false
	if expected_checkpoints > 0 and int(world.checkpoints) != expected_checkpoints: return false
	for key in ["times", "lap", "next", "started", "recovery"]:
		if not world.get(key) is Array or world[key].size() != count: return false
	for slot in count:
		var time: Variant = world.times[slot]
		if not _integer(time, 0, Kart.UNFINISHED) or (time != Kart.UNFINISHED and time > roundf(float(world.elapsed) * 100.0)) \
			or not _integer(world.lap[slot], 0, int(world.laps)) or not _integer(world.next[slot], 0, int(world.checkpoints) - 1) \
			or not world.started[slot] is bool or not Number._number(world.recovery[slot]) \
			or (world.recovery[slot] != -1.0 and (world.recovery[slot] < 0.0 or world.recovery[slot] > 1.0)):
			return false
		if (time != Kart.UNFINISHED) != (world.lap[slot] == world.laps): return false
		if time != Kart.UNFINISHED and (not world.started[slot] or world.recovery[slot] >= 0.0): return false
		if not world.started[slot] and (world.lap[slot] != 0 or world.next[slot] != 0): return false
	if not world.get("boost") is Dictionary or world.boost.size() != 2 \
		or not world.boost.get("serial") is Array or world.boost.serial.size() != count \
		or not world.boost.get("pads") is Array or world.boost.pads.size() != 4:
		return false
	for serial in world.boost.serial:
		if not _integer(serial, 0, 1000000): return false
	for pad in world.boost.pads:
		if not pad is Array or pad.size() != count: return false
		for value in pad:
			if not Number._number(value) or value < 0.0 or value > 2.0: return false
	return true


static func _integer(value: Variant, low: int, high: int) -> bool:
	return Number._number(value) and value == floorf(value) and value >= low and value <= high


func render(game: Node, world: Dictionary, round_index: int, feedback: bool) -> void:
	var baseline: bool = _round != round_index or _laps.size() != world.lap.size()
	if baseline:
		for slot in rescues.keys(): _remove_rescue(slot)
	game._elapsed = float(world.elapsed)
	game.finish_times.assign(world.times)
	game.lap.assign(world.lap)
	game._next_cp.assign(world.next)
	game._started.assign(world.started)
	game.boost_serial.assign(world.boost.serial)
	game._network_recovery.assign(world.recovery)
	game.ctx.config.rules["race_laps"] = int(world.laps)
	game.ctx.config.rules["party_short_race"] = int(world.laps) < Kart.LAPS
	game._finished = 0
	for slot in game.ctx.player_count():
		var fighter: Fighter = game.ctx.fighter(slot)
		fighter.control_enabled = false
		if int(world.times[slot]) != Kart.UNFINISHED: game._finished += 1
		if world.recovery[slot] >= 0.0:
			if not rescues.has(slot):
				var effect := Recovery.new()
				add_child(effect)
				rescues[slot] = effect
			rescues[slot].global_position = fighter.global_position
			rescues[slot].animate(float(world.recovery[slot]))
		elif rescues.has(slot): _remove_rescue(slot)
		if feedback and not baseline:
			if int(world.lap[slot]) > int(_laps[slot]):
				AudioManager.play_sfx("score" if int(world.times[slot]) != Kart.UNFINISHED else "tick")
			if int(world.boost.serial[slot]) > int(_boosts[slot]): AudioManager.play_sfx("dash", fighter.global_position)
	for index in game._boost_pads.size():
		var cooldown: Dictionary = game._boost_pads[index].cooldown
		cooldown.clear()
		for slot in game.ctx.player_count():
			if float(world.boost.pads[index][slot]) > 0.0: cooldown[slot] = float(world.boost.pads[index][slot])
	_laps = world.lap.duplicate()
	_boosts = world.boost.serial.duplicate()
	_round = round_index


func _remove_rescue(slot: int) -> void:
	rescues[slot].hide()
	rescues[slot].queue_free()
	rescues.erase(slot)
