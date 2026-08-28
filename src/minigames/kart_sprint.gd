extends MiniGameController
## Kart Sprint — three laps around a closed loop.
##
## Progress is tracked by ordered checkpoints, not by a trigger on the line, so
## cutting across the infield does not count as a lap and a kart that spins and
## crosses backwards does not gain one either.

const UNFINISHED := 99999
const LAPS := 3

var finish_times: Array[int] = []
var lap: Array[int] = []
var _next_cp: Array[int] = []
var _elapsed := 0.0
var _finished := 0
var _checkpoints: Array[Vector3] = []
var _boost_pads: Array = []


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	var n := ctx.player_count()
	finish_times.resize(n)
	finish_times.fill(UNFINISHED)
	lap.resize(n)
	lap.fill(0)
	_next_cp.resize(n)
	_next_cp.fill(0)
	var arena := ctx.arena as Arena
	if arena == null:
		return
	_checkpoints = arena.checkpoints
	_build_boost_pads(arena)


func _build_boost_pads(arena: Arena) -> void:
	var inner := arena.def.radius * 0.55
	var mid := (arena.def.radius + inner) * 0.5
	for i in 4:
		var ang := TAU * (float(i) + 0.5) / 4.0
		var pos := arena.global_position + Vector3(cos(ang) * mid, 0.09, sin(ang) * mid)
		var pad := MeshFactory.box(Vector3(2.4, 0.12, 2.4), UIKit.ACCENT_2, 1.2)
		pad.position = pos
		pad.rotation.y = -ang
		ctx.world_root.add_child(pad)
		_boost_pads.append({"pos": pos, "radius": 1.6, "cooldown": {}})


func locomotion() -> int:
	return Fighter.Locomotion.DRIVE


func camera_mode() -> int:
	return ArenaCamera.Mode.ARENA


func on_round_start() -> void:
	_elapsed = 0.0
	_finished = 0
	finish_times.fill(UNFINISHED)
	lap.fill(0)
	_next_cp.fill(0)


func tick(delta: float) -> void:
	_elapsed += delta
	if _checkpoints.is_empty():
		return
	for i in ctx.fighters.size():
		if finish_times[i] != UNFINISHED:
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var target: Vector3 = _checkpoints[_next_cp[i]]
		if f.global_position.distance_to(target) < 3.6:
			_next_cp[i] = (_next_cp[i] + 1) % _checkpoints.size()
			if _next_cp[i] == 0:
				lap[i] += 1
				AudioManager.play_sfx("score" if lap[i] >= LAPS else "tick")
				if lap[i] >= LAPS:
					finish_times[i] = int(round(_elapsed * 100.0))
					ctx.set_detail(i, "time", finish_times[i])
					ctx.set_detail(i, "laps", lap[i])
					_finished += 1
					f.control_enabled = false
		_check_boost(i, f, delta)


func _check_boost(slot: int, f, delta: float) -> void:
	for pad in _boost_pads:
		var cd: Dictionary = pad["cooldown"]
		if cd.has(slot):
			cd[slot] = float(cd[slot]) - delta
			if float(cd[slot]) <= 0.0:
				cd.erase(slot)
			continue
		var to: Vector3 = f.global_position - pad["pos"]
		to.y = 0.0
		if to.length() > float(pad["radius"]):
			continue
		cd[slot] = 2.0
		f.apply_impulse(f.facing.normalized() * Balance.num("tuning", "vehicle.boost_multiplier", 1.7) * 9.0)
		AudioManager.play_sfx("dash", f.global_position)


func on_fighter_fell(slot: int) -> void:
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f) or _checkpoints.is_empty():
		return
	# Rejoin at the last checkpoint passed, facing the right way.
	var idx := (_next_cp[slot] - 1 + _checkpoints.size()) % _checkpoints.size()
	f.respawn_at(_checkpoints[idx] + Vector3(0, 1.4, 0))


func is_round_over() -> bool:
	return ctx.early_finish or _finished >= ctx.player_count()


func compute_scores() -> Array[int]:
	# Unfinished karts are ordered behind finishers but ahead of each other by
	# how far round they got, encoded into the sentinel. Whole checkpoints are
	# ~1.7 s of driving apart, so two mid-pack karts between the same pair
	# counted as tied in 30% of simulated rounds — the metres still to the next
	# checkpoint break that tie at the resolution the race is actually run at.
	var out: Array[int] = []
	for i in finish_times.size():
		if finish_times[i] != UNFINISHED:
			out.append(finish_times[i])
		else:
			var progress := lap[i] * _checkpoints.size() + _next_cp[i]
			var toward := 0
			var f := ctx.fighter(i)
			if f != null and is_instance_valid(f) and not _checkpoints.is_empty():
				var gap := f.global_position.distance_to(_checkpoints[_next_cp[i]])
				toward = clampi(int(99.0 - minf(gap, 99.0)), 0, 99)
			out.append(UNFINISHED - progress * 100 - toward)
	return out


## Where the boost pads this kart can currently use sit, for brains that plan
## their line through them. They are big glowing squares and the recharge is
## visible on the pad, so a bot steering for one reads the same information a
## player does. Pads still cooling down for this kart are omitted — detouring
## to one costs line and pays nothing, which is exactly the mistake a planner
## must not make on the player's behalf.
func boost_pad_positions(for_slot: int) -> Array:
	var out: Array = []
	for pad in _boost_pads:
		if not pad["cooldown"].has(for_slot):
			out.append(pad["pos"])
	return out


func hud_value(slot: int) -> String:
	if finish_times[slot] != UNFINISHED:
		return "%.2f" % (finish_times[slot] / 100.0)
	return Loc.t("hud.lap", {"n": mini(lap[slot] + 1, LAPS), "total": LAPS})


func hud_banner() -> String:
	return "%.2f" % _elapsed


func ai_script() -> Script:
	return load("res://src/ai/brains/racer_brain.gd")


func next_checkpoint(slot: int) -> Vector3:
	if _checkpoints.is_empty():
		return ctx.arena_center()
	return _checkpoints[_next_cp[slot]]


func detail_rows() -> Array:
	return [
		{"key": "results.stat.time", "field": "time"},
		{"key": "results.stat.laps", "field": "laps"},
	]


func music_track() -> String:
	return "arena_b"
