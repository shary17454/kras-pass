extends MiniGameController
## Goal Guard — each competitor defends one wall of a square court.
##
## Balls accumulate and speed up. Conceding costs a point, so the score starts
## high and falls: the tension curve runs the opposite way to every other game
## in the collection, which is exactly why it belongs here.

const START_SCORE := 12
const SAVE_POINTS := 0     # saves are their own reward — they keep your score

var balls: Array[GameBall] = []
var _spawn_timer := 4.0
var _side_of_slot := {}
var _goal_markers: Array = []


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	# Assign each player one side: +X, -X, +Z, -Z. GameBall reports the same
	# indices, so scoring is a dictionary lookup rather than geometry.
	for i in ctx.player_count():
		_side_of_slot[i] = i % 4
	_place_players(arena)
	_build_goal_markers(arena)
	for i in ctx.player_count():
		ctx.set_score(i, START_SCORE)
	_spawn_ball()


func _place_players(arena: Arena) -> void:
	var r := arena.def.radius - 2.2
	var spots := [
		Vector3(r, 1.3, 0), Vector3(-r, 1.3, 0),
		Vector3(0, 1.3, r), Vector3(0, 1.3, -r),
	]
	for i in ctx.player_count():
		var f := ctx.fighter(i)
		if f != null:
			var p: Vector3 = arena.global_position + spots[_side_of_slot[i]]
			f.global_position = p
			f.set_spawn(p)


func _build_goal_markers(arena: Arena) -> void:
	var r := arena.def.radius
	var dirs := [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]
	for i in ctx.player_count():
		var side: int = _side_of_slot[i]
		var col := UIKit.adapt(ctx.config.players[i].color())
		var marker := MeshFactory.box(
			Vector3(0.4, 0.5, r * 2.0) if side < 2 else Vector3(r * 2.0, 0.5, 0.4), col, 0.8)
		marker.position = arena.global_position + dirs[side] * 0.98 + Vector3(0, 0.25, 0)
		ctx.world_root.add_child(marker)
		_goal_markers.append(marker)


func spawn_position(slot: int) -> Vector3:
	var arena := ctx.arena as Arena
	if arena == null:
		return Vector3(0, 1.5, 0)
	var r := arena.def.radius - 2.2
	var spots := [Vector3(r, 1.3, 0), Vector3(-r, 1.3, 0), Vector3(0, 1.3, r), Vector3(0, 1.3, -r)]
	return arena.global_position + spots[int(_side_of_slot.get(slot, slot % 4))]


func _spawn_ball(is_heavy: bool = false) -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	var b := GameBall.new()
	b.bounds = GameBall.Bounds.SQUARE
	b.bound_size = arena.def.radius
	b.arena_center = arena.global_position
	b.goals_enabled = true
	b.max_speed = Balance.num("tuning", "ball.max_speed", 26.0)
	b.ramp = Balance.num("tuning", "ball.speed_ramp", 0.35)
	ctx.world_root.add_child(b)
	b.configure(UIKit.ACCENT_2 if not is_heavy else Color("#9a7b5a"),
		Balance.num("tuning", "ball.radius", 0.55), is_heavy)
	b.scored_on.connect(_on_goal)
	var ang := ctx.rng.randf() * TAU
	b.launch(arena.global_position + Vector3(0, 0.9, 0), Vector3(cos(ang), 0, sin(ang)),
		Balance.num("tuning", "ball.base_speed", 9.0))
	b.add_to_group("balls")
	balls.append(b)


func tick(delta: float) -> void:
	for b in balls:
		if is_instance_valid(b):
			b.tick(delta)
	# A new ball every few seconds, up to one per player: the court fills up and
	# the last thirty seconds become genuinely frantic.
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and balls.size() < ctx.player_count():
		_spawn_timer = 9.0
		_spawn_ball(balls.size() >= 2)


func _on_goal(ball: GameBall, side: int) -> void:
	var conceder := -1
	for slot in _side_of_slot:
		if int(_side_of_slot[slot]) == side:
			conceder = slot
			break
	if conceder >= 0:
		ctx.set_score(conceder, maxi(0, ctx.scores[conceder] - 1))
		ctx.bump_detail(conceder, "conceded")
		if ball.last_toucher >= 0 and ball.last_toucher != conceder:
			ctx.bump_detail(ball.last_toucher, "saves")
		EventBus.shake(0.3, 0.2)
		AudioManager.play_sfx("wrong")
	_relaunch(ball)


func _relaunch(ball: GameBall) -> void:
	var arena := ctx.arena as Arena
	var ang := ctx.rng.randf() * TAU
	ball.launch(arena.global_position + Vector3(0, 0.9, 0), Vector3(cos(ang), 0, sin(ang)),
		Balance.num("tuning", "ball.base_speed", 9.0))


func is_round_over() -> bool:
	if ctx.early_finish:
		return true
	# A player on zero is out of the running; end early if only one has points.
	var alive_with_points := 0
	for s in ctx.scores:
		if s > 0:
			alive_with_points += 1
	return alive_with_points <= 1


func ai_script() -> Script:
	return load("res://src/ai/brains/keeper_brain.gd")


func camera_mode() -> int:
	return ArenaCamera.Mode.TOP_DOWN


func hud_value(slot: int) -> String:
	return str(ctx.scores[slot])


func detail_rows() -> Array:
	return [{"key": "results.stat.saves", "field": "saves"}]


func cleanup() -> void:
	for b in balls:
		if is_instance_valid(b):
			b.queue_free()
	balls.clear()
