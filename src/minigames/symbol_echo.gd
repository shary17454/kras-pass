extends MiniGameController
## Symbol Echo — watch a sequence, then walk it.
##
## Everyone sees the same sequence and races to reproduce it, so a slow-but-sure
## player and a fast-but-sloppy one both have a path to winning. Getting one
## wrong costs you the attempt, not the round.

enum Stage { SHOW, INPUT, RESOLVE }

const PAD_COUNT := 5
const SEQUENCE_POINTS := 2
## Finishing the sequence at all is worth `SEQUENCE_POINTS` per step, which is
## what keeps a slow-but-sure player in the game. This is the racing half: with
## a flat reward every finisher scored identically and the round tied 82% of the
## time, so being first has to be worth something on its own.
const ORDER_BONUS := [4, 2, 1, 0]
## Partial credit. Without it the only scoring event is a finished sequence, so
## a round where nobody manages a clean run ends four-way nil and produces no
## result at all — which happened in 5% of simulated rounds.
const STEP_POINTS := 1

var _pads: Array = []
var _sequence: Array[int] = []
var _progress: Array[int] = []
var _stage: Stage = Stage.SHOW
var _timer := 0.0
var _show_index := 0
var _step_time := 0.62
var _length := 3
var _last_pad: Array[int] = []
var _mistakes: Array[int] = []
var _serial := 0
var _finished: Array[int] = []


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99
	_step_time = Balance.num("tuning", "reaction.sequence_step_time", 0.62)
	_length = int(Balance.num("tuning", "reaction.sequence_start_length", 3))


func build() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	_progress.resize(ctx.player_count())
	_progress.fill(0)
	_last_pad.resize(ctx.player_count())
	_last_pad.fill(-1)
	_mistakes.resize(ctx.player_count())
	_mistakes.fill(0)
	var glyphs := ["◆", "●", "▲", "■", "★"]
	for i in PAD_COUNT:
		var ang := TAU * float(i) / float(PAD_COUNT) - PI * 0.5
		var r := arena.def.radius * 0.62
		var pos := arena.global_position + Vector3(cos(ang) * r, 0.12, sin(ang) * r)
		var pad := MeshFactory.cylinder(2.0, 0.24, UIKit.PANEL_HI, 0.0, 24)
		pad.position = pos
		ctx.world_root.add_child(pad)
		var label := Label3D.new()
		label.text = glyphs[i]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 170
		label.pixel_size = 0.006
		label.outline_size = 24
		label.position = pos + Vector3(0, 1.6, 0)
		ctx.world_root.add_child(label)
		_pads.append({"pos": pos, "mesh": pad, "label": label, "radius": 2.0})
	_new_sequence()


func _new_sequence() -> void:
	_sequence.clear()
	for i in _length:
		_sequence.append(ctx.rng.randi_range(0, PAD_COUNT - 1))
	_progress.fill(0)
	_last_pad.fill(-1)
	_finished.clear()
	_serial += 1
	_stage = Stage.SHOW
	_show_index = 0
	_timer = 0.6


func tick(delta: float) -> void:
	_timer -= delta
	match _stage:
		Stage.SHOW:
			if _timer <= 0.0:
				if _show_index < _sequence.size():
					_flash(_sequence[_show_index])
					_show_index += 1
					_timer = _step_time
				else:
					_stage = Stage.INPUT
					_timer = 3.0 + _length * 2.2
					_reset_pad_colors()
		Stage.INPUT:
			_read_inputs()
			if _all_finished():
				_timer = minf(_timer, 0.35)
			if _timer <= 0.0:
				_stage = Stage.RESOLVE
				_timer = 1.0
		Stage.RESOLVE:
			if _timer <= 0.0:
				_length = mini(9, _length + 1)
				_new_sequence()


func _flash(index: int) -> void:
	var pad = _pads[index]
	var mesh: MeshInstance3D = pad["mesh"]
	mesh.material_override = MeshFactory.toon(UIKit.ACCENT, 1.6)
	AudioManager.play_sfx("tick", pad["pos"], 0.8 + index * 0.12)
	var tw := mesh.create_tween()
	tw.tween_interval(_step_time * 0.6)
	tw.tween_callback(func():
		if is_instance_valid(mesh):
			mesh.material_override = MeshFactory.toon(UIKit.PANEL_HI))


func _reset_pad_colors() -> void:
	for pad in _pads:
		var mesh: MeshInstance3D = pad["mesh"]
		if is_instance_valid(mesh):
			mesh.material_override = MeshFactory.toon(UIKit.PANEL_HI)


func _read_inputs() -> void:
	for i in ctx.fighters.size():
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f) or not ctx.is_alive(i):
			continue
		var on := _pad_under(f.global_position)
		if on < 0:
			_last_pad[i] = -1
			continue
		if on == _last_pad[i]:
			continue
		_last_pad[i] = on
		if _progress[i] >= _sequence.size():
			continue
		if on == _sequence[_progress[i]]:
			_progress[i] += 1
			ctx.add_score(i, int(STEP_POINTS * ctx.powerups.point_multiplier(i)))
			AudioManager.play_sfx("correct", f.global_position)
			if _progress[i] >= _sequence.size():
				var rank := _finished.size()
				_finished.append(i)
				var base := SEQUENCE_POINTS * _sequence.size()
				var bonus: int = ORDER_BONUS[rank] if rank < ORDER_BONUS.size() else 0
				var gain := int(float(base + bonus) * ctx.powerups.point_multiplier(i))
				ctx.add_score(i, gain)
				ctx.bump_detail(i, "correct")
				if rank == 0:
					ctx.bump_detail(i, "first")
				AudioManager.play_sfx("score")
		else:
			_progress[i] = 0
			_mistakes[i] += 1
			ctx.bump_detail(i, "mistakes")
			f.stun(0.45)
			AudioManager.play_sfx("wrong", f.global_position)


## True once every player still in the round has walked the whole sequence, so
## the round can move on instead of burning the remaining seconds.
func _all_finished() -> bool:
	var alive := 0
	for i in ctx.fighters.size():
		if ctx.is_alive(i):
			alive += 1
	return alive > 0 and _finished.size() >= alive


func _pad_under(pos: Vector3) -> int:
	for i in _pads.size():
		var to: Vector3 = pos - _pads[i]["pos"]
		to.y = 0.0
		if to.length() <= float(_pads[i]["radius"]):
			return i
	return -1


func pad_position(index: int) -> Vector3:
	if index < 0 or index >= _pads.size():
		return ctx.arena_center()
	return _pads[index]["pos"]


func expected_pad(slot: int) -> int:
	if _stage != Stage.INPUT or slot >= _progress.size() or _progress[slot] >= _sequence.size():
		return -1
	return _sequence[_progress[slot]]


func is_showing() -> bool:
	return _stage == Stage.SHOW


## Bumped every time a fresh sequence is dealt. A brain keys its recall on this
## so a step it fumbled is re-rolled for the next sequence instead of staying
## wrong for the whole round.
func sequence_serial() -> int:
	return _serial


## How many steps of the current sequence this slot has already walked.
func progress_of(slot: int) -> int:
	if slot < 0 or slot >= _progress.size():
		return 0
	return _progress[slot]


## Wrong-pad count for this slot. A brain watches this to notice its own miss,
## which is the only feedback a human gets too.
func mistakes_of(slot: int) -> int:
	if slot < 0 or slot >= _mistakes.size():
		return 0
	return _mistakes[slot]


func is_round_over() -> bool:
	return ctx.early_finish


func hud_banner() -> String:
	if _stage == Stage.SHOW:
		return "%s  %d" % [Loc.t("hud.get_ready"), _sequence.size()]
	return "%d" % _sequence.size()


func ai_script() -> Script:
	return load("res://src/ai/brains/echo_brain.gd")


func camera_mode() -> int:
	return ArenaCamera.Mode.TOP_DOWN


func uses_powerups() -> bool:
	return false


func detail_rows() -> Array:
	return [
		{"key": "results.stat.correct", "field": "correct"},
		{"key": "results.stat.mistakes", "field": "mistakes"},
		{"key": "results.stat.first", "field": "first"},
	]
