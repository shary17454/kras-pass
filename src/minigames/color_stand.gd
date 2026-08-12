extends MiniGameController
## Colour Stand — get onto the called colour before the rest of the floor goes.
##
## A pure reaction game with a readable tell: the call appears, a bar of time
## runs out, then everything that is not the called colour drops. Each survived
## call shortens the next one.

enum Stage { CALL, DROP, RESTORE }

const COLORS := [
	Color("#ff5f6d"), Color("#57e0c0"), Color("#ffd23f"), Color("#7ba7ff"),
]
const COLOR_NAMES := ["red", "green", "yellow", "blue"]

var _stage: Stage = Stage.CALL
var _timer := 0.0
var _hold := 2.6
var _called := 0
var _tiles: Array[ArenaTile] = []
var _round_no := 0


func configure() -> void:
	eliminate_on_fall = true
	lives_per_player = 1
	_hold = Balance.num("tuning", "reaction.prompt_hold", 2.6)


func build() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	_tiles = arena.tiles
	_repaint()
	_begin_call()


func _repaint() -> void:
	# A blocky quilt rather than a checkerboard: players must actually cross the
	# floor rather than step one square sideways.
	for t in _tiles:
		var group := (int(floor(t.grid_x / 2.0)) + int(floor(t.grid_z / 2.0)) * 2 + int(ctx.rng.randi_range(0, 1))) % COLORS.size()
		t.tag = COLOR_NAMES[group]
		t.crumbles = false
		t.restore()
		t.set_color(COLORS[group], 0.25)


func _begin_call() -> void:
	_round_no += 1
	_called = ctx.rng.randi_range(0, COLORS.size() - 1)
	_stage = Stage.CALL
	_timer = maxf(Balance.num("tuning", "reaction.min_prompt_hold", 1.0),
		_hold * pow(Balance.num("tuning", "reaction.prompt_speedup", 0.94), _round_no))
	AudioManager.play_sfx("countdown")


func tick(delta: float) -> void:
	_timer -= delta
	match _stage:
		Stage.CALL:
			if _timer <= 0.0:
				_drop()
		Stage.DROP:
			if _timer <= 0.0:
				_stage = Stage.RESTORE
				_timer = 1.0
				_score_survivors()
		Stage.RESTORE:
			if _timer <= 0.0:
				_repaint()
				_begin_call()


func _drop() -> void:
	_stage = Stage.DROP
	_timer = 1.6
	AudioManager.play_sfx("whistle")
	for t in _tiles:
		if t.tag != COLOR_NAMES[_called]:
			t.force_collapse()


func _score_survivors() -> void:
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		ctx.bump_detail(i, "correct")


func hud_banner() -> String:
	match _stage:
		Stage.CALL:
			return "%s  %.1f" % [Loc.t("game.color_stand.name"), maxf(0.0, _timer)]
		Stage.DROP:
			return Loc.t("hud.hurry")
	return ""


func called_color() -> Color:
	return COLORS[_called]


func called_tag() -> String:
	return COLOR_NAMES[_called]


func safe_tile_near(pos: Vector3) -> ArenaTile:
	var best: ArenaTile = null
	var best_d := INF
	for t in _tiles:
		if t.tag != COLOR_NAMES[_called] or not t.is_standable():
			continue
		var d: float = t.global_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = t
	return best


func is_dropping() -> bool:
	return _stage == Stage.DROP


func ai_script() -> Script:
	return load("res://src/ai/brains/color_brain.gd")


func camera_mode() -> int:
	return ArenaCamera.Mode.TOP_DOWN


func uses_powerups() -> bool:
	return false


func hud_value(slot: int) -> String:
	return Loc.t("hud.eliminated") if not ctx.is_alive(slot) else "●"


func detail_rows() -> Array:
	return [{"key": "results.stat.correct", "field": "correct"}]


func music_track() -> String:
	return "tension"
