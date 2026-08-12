extends MiniGameController
## Quick Draw — the nerve game.
##
## The wait before the signal is random and sometimes long. Pressing early is
## not merely useless, it locks you out of the round, so the correct play is to
## actually wait — and everyone in the room knows you cannot.

enum Stage { WAIT, SIGNAL, RESOLVE }

const PLACE_POINTS := [3, 2, 1, 0]
const FALSE_START_PENALTY := 1

var _stage: Stage = Stage.WAIT
var _timer := 0.0
var _order: Array[int] = []
var _locked := {}
var _signal_at := 0.0
var _pillar: MeshInstance3D
var _round_no := 0


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	_pillar = MeshFactory.cylinder(1.6, 5.0, UIKit.PANEL_HI, 0.0, 20)
	_pillar.position = arena.global_position + Vector3(0, 2.5, 0)
	ctx.world_root.add_child(_pillar)
	# Everyone stands on their own mark; movement is irrelevant here, so the
	# game is honest about it and locks the competitors in place.
	for i in ctx.player_count():
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var ang := TAU * float(i) / float(ctx.player_count()) - PI * 0.5
		var p := arena.global_position + Vector3(cos(ang) * 5.2, 1.3, sin(ang) * 5.2)
		f.global_position = p
		f.set_spawn(p)
		f.facing = (arena.global_position - p).normalized()
	_begin_wait()


func _begin_wait() -> void:
	_round_no += 1
	_stage = Stage.WAIT
	_order.clear()
	_locked.clear()
	_timer = ctx.rng.randf_range(1.6, 4.5)
	if _pillar != null and is_instance_valid(_pillar):
		_pillar.material_override = MeshFactory.toon(UIKit.PANEL_HI)


func tick(delta: float) -> void:
	_timer -= delta
	match _stage:
		Stage.WAIT:
			_watch_false_starts()
			if _timer <= 0.0:
				_fire_signal()
		Stage.SIGNAL:
			_watch_draws()
			if _timer <= 0.0:
				_resolve()
		Stage.RESOLVE:
			if _timer <= 0.0:
				_begin_wait()


func _fire_signal() -> void:
	_stage = Stage.SIGNAL
	_timer = 1.8
	_signal_at = Time.get_ticks_msec() / 1000.0
	if _pillar != null and is_instance_valid(_pillar):
		_pillar.material_override = MeshFactory.toon(Color("#ffd23f"), 2.4)
	AudioManager.play_sfx("go")
	EventBus.shake(0.25, 0.15)


func _watch_false_starts() -> void:
	for i in ctx.fighters.size():
		if _locked.has(i):
			continue
		if InputRouter.frame(i).just_pressed(InputFrame.Btn.ATTACK):
			_locked[i] = true
			ctx.set_score(i, maxi(0, ctx.scores[i] - FALSE_START_PENALTY))
			ctx.bump_detail(i, "mistakes")
			AudioManager.play_sfx("wrong")
			var f := ctx.fighter(i)
			if f != null and is_instance_valid(f):
				f.stun(1.2)


func _watch_draws() -> void:
	for i in ctx.fighters.size():
		if _locked.has(i) or _order.has(i):
			continue
		if InputRouter.frame(i).just_pressed(InputFrame.Btn.ATTACK):
			_order.append(i)
			ctx.set_detail(i, "reaction_ms", int((Time.get_ticks_msec() / 1000.0 - _signal_at) * 1000.0))
			AudioManager.play_sfx("correct")
	if _order.size() >= ctx.alive_count() - _locked.size():
		_timer = minf(_timer, 0.15)


func _resolve() -> void:
	_stage = Stage.RESOLVE
	_timer = 1.1
	for place in _order.size():
		var slot: int = _order[place]
		var pts: int = PLACE_POINTS[mini(place, PLACE_POINTS.size() - 1)]
		if pts > 0:
			ctx.add_score(slot, int(pts * ctx.powerups.point_multiplier(slot)))
			ctx.bump_detail(slot, "correct")
	if _order.size() > 0:
		AudioManager.play_sfx("score")
	if _pillar != null and is_instance_valid(_pillar):
		_pillar.material_override = MeshFactory.toon(UIKit.PANEL_HI)


func is_signalled() -> bool:
	return _stage == Stage.SIGNAL


func signal_age() -> float:
	return (Time.get_ticks_msec() / 1000.0) - _signal_at


func is_locked(slot: int) -> bool:
	return _locked.has(slot)


func is_round_over() -> bool:
	return ctx.early_finish


func hud_banner() -> String:
	match _stage:
		Stage.WAIT:
			return "…"
		Stage.SIGNAL:
			return Loc.t("hud.go")
	return ""


func ai_script() -> Script:
	return load("res://src/ai/brains/draw_brain.gd")


func camera_mode() -> int:
	return ArenaCamera.Mode.ISOMETRIC


func uses_powerups() -> bool:
	return false


func allows_dash() -> bool:
	return false


func detail_rows() -> Array:
	return [
		{"key": "results.stat.correct", "field": "correct"},
		{"key": "results.stat.mistakes", "field": "mistakes"},
	]


func music_track() -> String:
	return "tension"
