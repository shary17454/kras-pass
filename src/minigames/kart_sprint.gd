extends MiniGameController
## Kart Sprint — three laps around a closed loop.
##
## Progress is tracked by ordered checkpoints, not by a trigger on the line, so
## cutting across the infield does not count as a lap and a kart that spins and
## crosses backwards does not gain one either.

const UNFINISHED := 1000000000
const LAPS := 3
const RECOVERY_SECONDS := 3.0
var _recoveries := {}

var finish_times: Array[int] = []
var lap: Array[int] = []
var _next_cp: Array[int] = []
var _started: Array[bool] = []
var _elapsed := 0.0
var _finished := 0
var _checkpoints: Array[Vector3] = []
var _boost_pads: Array = []


## Overridable so a game on a longer circuit can run fewer laps. Distance is
## what has to stay comparable between race games, not lap count.
func laps() -> int:
	return clampi(int(ctx.config.rule("race_laps", LAPS)), 3, 10) if ctx != null else LAPS


func uses_round_clock() -> bool:
	return false


func hud_primary_value() -> String:
	var humans := ctx.config.human_slots()
	var slot := humans[0] if not humans.is_empty() else 0
	return "%d / %d" % [mini(lap[slot] + 1, laps()), laps()] if not lap.is_empty() else ""


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
	_started.resize(n)
	_started.fill(false)
	var arena := ctx.arena as Arena
	if arena == null:
		return
	_checkpoints = arena.checkpoints
	_build_boost_pads(arena)


## Pads go on the arena's racing line, not on a circle derived from its radius.
## For an oval those are the same point by construction, so this is unchanged
## there; on a lobed circuit a fixed circle lands the pads off the road — on
## Frost Hairpin, roughly 5.6m from a centreline whose half-width is 4.25m,
## i.e. behind the inner wall, unreachable, and pulling steering bots into it.
func _build_boost_pads(arena: Arena) -> void:
	for i in 4:
		var t := (float(i) + 0.5) / 4.0
		var here := arena.track_point(t)
		var ahead := arena.track_point(t + 0.005)
		var pos := here + Vector3(0, 0.09, 0)
		var pad := MeshInstance3D.new()
		pad.name = "GreenBoostPad%d" % i
		var plane := PlaneMesh.new()
		plane.size = Vector2(4.0, 4.0)
		pad.mesh = plane
		var material := ShaderMaterial.new()
		material.shader = load("res://src/arenas/racing_boost.gdshader")
		pad.material_override = material
		pad.position = pos
		var fwd := (ahead - here).normalized()
		if fwd.length_squared() > 0.0001:
			pad.basis = Basis.looking_at(fwd, Vector3.UP)
		ctx.world_root.add_child(pad)
		_boost_pads.append({"pos": pos, "radius": 2.0, "cooldown": {}})


func locomotion() -> int:
	return Fighter.Locomotion.DRIVE


func camera_mode() -> int:
	return ArenaCamera.Mode.ARENA


func on_round_start() -> void:
	_clear_recoveries()
	_elapsed = 0.0
	_finished = 0
	finish_times.fill(UNFINISHED)
	lap.fill(0)
	_next_cp.fill(0)
	_started.fill(false)


func tick(delta: float) -> void:
	_elapsed += delta
	if _checkpoints.is_empty():
		return
	for i in ctx.fighters.size():
		if is_recovering(i):
			continue
		if finish_times[i] != UNFINISHED:
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var structures := ctx.arena.get_node_or_null("RaceStructures")
		if structures != null and structures.is_below_bridge(f.global_position):
			on_fighter_fell(i)
			continue
		var target: Vector3 = _checkpoints[_next_cp[i]]
		var checkpoint_radius: float = maxf(3.6, ctx.arena.track_width * 0.48)
		if f.global_position.distance_to(target) < checkpoint_radius:
			var crossed_start := _next_cp[i] == 0
			_next_cp[i] = (_next_cp[i] + 1) % _checkpoints.size()
			if crossed_start and _started[i]:
				lap[i] += 1
				AudioManager.play_sfx("score" if lap[i] >= laps() else "tick")
				if lap[i] >= laps():
					finish_times[i] = int(round(_elapsed * 100.0))
					ctx.set_detail(i, "time", finish_times[i])
					ctx.set_detail(i, "laps", lap[i])
					_finished += 1
					f.control_enabled = false
			if crossed_start:
				_started[i] = true
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
	if f == null or not is_instance_valid(f) or _checkpoints.is_empty() or is_recovering(slot) or finish_times[slot] != UNFINISHED:
		return
	var idx := (_next_cp[slot] - 1 + _checkpoints.size()) % _checkpoints.size() if _started[slot] else 0
	var target := _checkpoints[idx] + Vector3(0, 1.4, 0)
	var start: Vector3 = f.global_position
	start.y = maxf(start.y, target.y - 5.0)
	var effect := load("res://src/fx/race_recovery.gd").new() as Node3D
	ctx.world_root.add_child(effect)
	effect.global_position = start
	_recoveries[slot] = {"time": 0.0, "start": start, "target": target, "layer": f.collision_layer, "mask": f.collision_mask, "effect": effect}
	f.alive = false
	f.control_enabled = false
	f.set_physics_process(false)
	f.collision_layer = 0
	f.collision_mask = 0
	f.velocity = Vector3.ZERO
	f.global_position = start
	f.reset_physics_interpolation()
	ctx.bump_detail(slot, "falls")


func is_recovering(slot: int) -> bool:
	return _recoveries.has(slot)


func process_respawns(delta: float) -> void:
	super.process_respawns(delta)
	for slot in _recoveries.keys():
		var state: Dictionary = _recoveries[slot]
		state.time += delta
		var progress := clampf(float(state.time) / RECOVERY_SECONDS, 0.0, 1.0)
		var f := ctx.fighter(slot)
		if f == null or not is_instance_valid(f):
			state.effect.queue_free()
			_recoveries.erase(slot)
			continue
		f.global_position = (state.start as Vector3).lerp(state.target, smoothstep(0, 1, progress)) + Vector3.UP * sin(progress * PI) * 7.0
		state.effect.global_position = f.global_position
		state.effect.animate(progress)
		if progress >= 1.0:
			f.collision_layer = state.layer
			f.collision_mask = state.mask
			f.control_enabled = true
			f.respawn_at(state.target)
			f.face_direction(_checkpoints[_next_cp[slot]] - f.global_position)
			state.effect.queue_free()
			_recoveries.erase(slot)


func cleanup() -> void:
	_clear_recoveries()


func _clear_recoveries() -> void:
	for slot in _recoveries:
		var state: Dictionary = _recoveries[slot]
		var f := ctx.fighter(slot)
		if is_instance_valid(f):
			f.collision_layer = state.layer
			f.collision_mask = state.mask
			f.control_enabled = true
			f.respawn_at(state.target)
		if is_instance_valid(state.effect):
			state.effect.queue_free()
	_recoveries.clear()


func on_round_end() -> void:
	_clear_recoveries()


func is_round_over() -> bool:
	if ctx.early_finish or _finished >= ctx.player_count():
		return true
	var humans := ctx.config.human_slots()
	if humans.is_empty():
		return false
	for slot in humans:
		if finish_times[slot] == UNFINISHED:
			return false
	return true


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
			var progress := progress_steps(i)
			var toward := 0
			var f := ctx.fighter(i)
			if f != null and is_instance_valid(f) and not _checkpoints.is_empty():
				var gap := f.global_position.distance_to(_checkpoints[_next_cp[i]])
				toward = clampi(int(99.0 - minf(gap, 99.0)), 0, 99)
			out.append(UNFINISHED - progress * 100 - toward)
	return out


func progress_steps(slot: int) -> int:
	var next := _checkpoints.size() if _next_cp[slot] == 0 and _started[slot] else _next_cp[slot]
	return lap[slot] * _checkpoints.size() + next


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
	return Loc.t("hud.lap", {"n": mini(lap[slot] + 1, laps()), "total": laps()})


func hud_banner() -> String:
	return Loc.t("race.laps")


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
