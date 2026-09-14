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
var paddles: Array[Node3D] = []
var charges: Array[float] = []
const NORMALS := [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
const PADDLE_HALF := 1.75


func side_for(slot: int) -> int:
	return int(_side_of_slot.get(slot, [2, 1, 3, 0][slot % 4]))


func uses_powerups() -> bool:
	return false


func uses_machine() -> bool:
	return false


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
		_side_of_slot[i] = [2, 1, 3, 0][i % 4]
	_place_players(arena)
	_build_goal_markers(arena)
	for i in ctx.player_count():
		ctx.set_score(i, START_SCORE)
		charges.append(1.0)
		var f := ctx.fighter(i)
		f.top_speed *= 1.55
		f.acceleration *= 1.6
		var paddle := MeshFactory.box(Vector3(3.5, 0.8, 0.55), ctx.config.players[i].color(), 0.8)
		attach(paddle, f.global_position)
		paddles.append(paddle)
	_build_court(arena)
	_spawn_ball()


func _build_court(arena: Arena) -> void:
	var r := arena.def.radius
	for axis in 2:
		var line := MeshFactory.box(Vector3(r * 1.85, 0.035, 0.055), Color("#72d3e6"), 0.4)
		line.rotation.y = axis * PI * 0.5
		attach(line, arena.global_position + Vector3.UP * 0.12)
	var ring := MeshFactory.torus(2.0, 2.08, Color("#ffdf83"))
	attach(ring, arena.global_position + Vector3.UP * 0.13)
	for i in ctx.player_count():
		var side := side_for(i)
		var lane := MeshFactory.box(Vector3(r * 2.0 - 5.6, 0.025, 2.8), ctx.config.players[i].color().darkened(0.55))
		lane.rotation.y = PI * 0.5 if side < 2 else 0.0
		attach(lane, arena.global_position - NORMALS[side] * (r - 1.8) + Vector3.UP * 0.08)


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
		add_child(marker)
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
	b.set_monitoring(false)
	b.max_speed = Balance.num("tuning", "ball.max_speed", 26.0)
	if is_heavy:
		b.max_speed *= 0.8
	b.ramp = Balance.num("tuning", "ball.speed_ramp", 0.35)
	ctx.world_root.add_child(b)
	b.configure(Color("#fbe5a0") if not is_heavy else Color("#ff8470"), 0.72, is_heavy)
	b.scored_on.connect(_on_goal)
	var ang := ctx.rng.randf() * TAU
	b.launch(arena.global_position + Vector3(0, 0.9, 0), Vector3(cos(ang), 0, sin(ang)),
		Balance.num("tuning", "ball.base_speed", 9.0))
	b.add_to_group("balls")
	balls.append(b)


func tick(delta: float) -> void:
	var arena := ctx.arena as Arena
	for slot in ctx.player_count():
		var f := ctx.fighter(slot)
		paddles[slot].visible = f.alive
		if not f.alive:
			continue
		var side := side_for(slot)
		var n: Vector3 = NORMALS[side]
		var tangent := Vector3(-n.z, 0, n.x)
		var local := f.global_position - arena.global_position
		var along := clampf(local.dot(tangent), -arena.def.radius + 2.0, arena.def.radius - 2.0)
		f.global_position = arena.global_position - n * (arena.def.radius - 2.2) + tangent * along + Vector3.UP * maxf(local.y, 0.9)
		f.facing = n
		charges[slot] = minf(1.0, charges[slot] + delta * 0.18)
		paddles[slot].global_position = f.global_position + n * 0.8
		paddles[slot].rotation.y = PI * 0.5 if side < 2 else 0.0
		paddles[slot].scale.x = 1.25 if f.is_attacking() else 1.0
	for b in balls:
		if is_instance_valid(b):
			_defend_ball(b, delta)
			b.tick(delta)
	# A new ball every few seconds, up to one per player: the court fills up and
	# the last thirty seconds become genuinely frantic.
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and balls.size() < ctx.player_count():
		_spawn_timer = 9.0
		_spawn_ball(balls.size() >= 2)


func _defend_ball(ball: GameBall, delta: float) -> void:
	# Swept plane interception prevents fast balls tunnelling through a keeper.
	for slot in ctx.player_count():
		var f := ctx.fighter(slot)
		if not f.alive:
			continue
		var n: Vector3 = NORMALS[side_for(slot)]
		var approach := ball.velocity.dot(n)
		if approach >= -0.001:
			continue
		var offset := ball.global_position - paddles[slot].global_position
		var distance := offset.dot(n) - ball.radius
		if distance < -0.5 or distance + approach * delta > 0.0:
			continue
		var hit := offset + ball.velocity * maxf(0.0, distance / -approach)
		var tangent := Vector3(-n.z, 0, n.x)
		var width := PADDLE_HALF * (1.25 if f.is_attacking() else 1.0)
		if absf(hit.dot(tangent)) > width + ball.radius:
			continue
		var powered := f.is_attacking() and charges[slot] >= 0.99
		if powered:
			charges[slot] = 0.0
		ball.speed = minf(ball.max_speed, ball.speed * (1.5 if powered else 1.04))
		var aim := (n + tangent * clampf(hit.dot(tangent) / width, -0.85, 0.85)).normalized()
		ball.velocity = aim * ball.speed
		ball.last_toucher = slot
		ctx.bump_detail(slot, "saves")
		AudioManager.play_sfx("bounce", ball.global_position, 1.35 if powered else 1.0)
		return


func _on_goal(ball: GameBall, side: int) -> void:
	var conceder := -1
	for slot in _side_of_slot:
		if int(_side_of_slot[slot]) == side:
			conceder = slot
			break
	if conceder < 0:
		ball.global_position -= ball.velocity.normalized() * 1.5
		ball.velocity = ball.velocity.bounce(NORMALS[side])
		return
	if conceder >= 0:
		if ctx.scores[conceder] <= 0:
			ball.global_position -= ball.velocity.normalized() * 1.5
			ball.velocity = ball.velocity.bounce(NORMALS[side])
			return
		ctx.set_score(conceder, maxi(0, ctx.scores[conceder] - (2 if ball.heavy else 1)))
		ctx.bump_detail(conceder, "conceded")
		if ctx.scores[conceder] == 0:
			ctx.eliminate(conceder)
			ctx.fighter(conceder).alive = false
			ctx.fighter(conceder).visible = false
		EventBus.shake(0.3, 0.2)
		AudioManager.play_sfx("wrong")
	_relaunch(ball)


func _relaunch(ball: GameBall) -> void:
	var arena := ctx.arena as Arena
	var ang := ctx.rng.randf() * TAU
	ball.launch(arena.global_position + Vector3(0, 0.9, 0), Vector3(cos(ang), 0, sin(ang)),
		Balance.num("tuning", "ball.base_speed", 9.0))


func on_round_start() -> void:
	_spawn_timer = 4.0
	while balls.size() > 1:
		balls.pop_back().queue_free()
	for slot in ctx.player_count():
		ctx.set_score(slot, START_SCORE)
		if not ctx.is_alive(slot):
			ctx.revive(slot)
			ctx.fighter(slot).respawn_at(spawn_position(slot))
		charges[slot] = 1.0
		paddles[slot].visible = true
	_place_players(ctx.arena as Arena)
	for ball in balls:
		_relaunch(ball)


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
	return ArenaCamera.Mode.COURT


func hud_value(slot: int) -> String:
	return "%d / %d" % [ctx.scores[slot], START_SCORE]


func detail_rows() -> Array:
	return [{"key": "results.stat.saves", "field": "saves"}]


func cleanup() -> void:
	for b in balls:
		if is_instance_valid(b):
			b.queue_free()
	balls.clear()
