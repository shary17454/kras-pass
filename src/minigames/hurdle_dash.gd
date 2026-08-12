extends MiniGameController
## Hurdle Dash — a straight sprint with things in the way.
##
## Scored by time, so `MatchResult` ranks *low* values first. Unfinished runners
## get a sentinel time rather than being excluded, which keeps placement
## well-defined even if nobody reaches the line.

const UNFINISHED := 99999

var finish_times: Array[int] = []
var _finished := 0
var _elapsed := 0.0
var _line_z := 0.0
var _banner := ""


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	finish_times.resize(ctx.player_count())
	finish_times.fill(UNFINISHED)
	var arena := ctx.arena as Arena
	if arena != null:
		_line_z = arena.global_position.z + arena.finish_z
		for i in ctx.player_count():
			var f := ctx.fighter(i)
			if f != null and is_instance_valid(f):
				var p := arena.global_position + Vector3(arena.lane_x(i), 1.3, arena.start_z + 1.5)
				f.global_position = p
				f.set_spawn(p)
				f.facing = Vector3.FORWARD * -1.0


func on_round_start() -> void:
	_elapsed = 0.0
	_finished = 0
	finish_times.fill(UNFINISHED)


func camera_mode() -> int:
	return ArenaCamera.Mode.RACE


func tick(delta: float) -> void:
	_elapsed += delta
	for i in ctx.fighters.size():
		if finish_times[i] != UNFINISHED:
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		if f.global_position.z <= _line_z:
			finish_times[i] = int(round(_elapsed * 100.0))
			_finished += 1
			f.control_enabled = false
			ctx.set_detail(i, "time", finish_times[i])
			AudioManager.play_sfx("score")
			EventBus.notify(Loc.t("results.stat.time") + ": %.2fs" % _elapsed, "⏱")
	_banner = "%.2f" % _elapsed


## Fallen runners restart at their lane rather than being removed — a race with
## three players standing still is not a race.
func on_fighter_fell(slot: int) -> void:
	var arena := ctx.arena as Arena
	var f := ctx.fighter(slot)
	if f != null and is_instance_valid(f) and arena != null:
		f.respawn_at(arena.global_position + Vector3(arena.lane_x(slot), 1.4, f.global_position.z - arena.global_position.z + 2.0))


func is_round_over() -> bool:
	return ctx.early_finish or _finished >= ctx.player_count()


func compute_scores() -> Array[int]:
	return finish_times.duplicate()


func is_tied() -> bool:
	var seen := {}
	for t in finish_times:
		if t == UNFINISHED:
			continue
		if seen.has(t):
			return true
		seen[t] = true
	return false


func hud_value(slot: int) -> String:
	if finish_times[slot] == UNFINISHED:
		return "—"
	return "%.2f" % (finish_times[slot] / 100.0)


func hud_banner() -> String:
	return _banner


func ai_script() -> Script:
	return load("res://src/ai/brains/runner_brain.gd")


func uses_powerups() -> bool:
	return false


func detail_rows() -> Array:
	return [{"key": "results.stat.time", "field": "time"}]


func finish_line_z() -> float:
	return _line_z
