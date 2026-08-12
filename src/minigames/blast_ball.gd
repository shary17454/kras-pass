extends MiniGameController
## Blast Ball — an armed ball with a visible fuse.
##
## The ball drifts toward whoever is nearest. Touching it sends it away and
## speeds it up, but the fuse keeps running. When it detonates, the competitor
## closest to the blast is eliminated and a fresh ball is armed.

var ball: GameBall
var _fuse_max := 5.0
var _blast_radius := 5.0


func configure() -> void:
	eliminate_on_fall = true
	lives_per_player = 1
	_fuse_max = Balance.num("tuning", "ball.explosive_fuse", 5.0)
	_blast_radius = Balance.num("tuning", "ball.explosive_radius", 5.0)


func build() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	ball = GameBall.new()
	ball.bounds = GameBall.Bounds.DISC
	ball.bound_size = arena.def.radius
	ball.arena_center = arena.global_position
	ball.explosive = true
	ball.fuse_max = _fuse_max
	ball.max_speed = 18.0
	ball.ramp = 0.5
	ctx.world_root.add_child(ball)
	ball.configure(Color("#ff5f8d"), 0.62, false, true)
	ball.exploded.connect(_on_exploded)
	ball.add_to_group("balls")
	_arm()


func _arm() -> void:
	var arena := ctx.arena as Arena
	var ang := ctx.rng.randf() * TAU
	ball.fuse_max = maxf(2.2, _fuse_max - 0.4 * float(ctx.player_count() - ctx.alive_count()))
	ball.launch(arena.global_position + Vector3(0, 0.9, 0), Vector3(cos(ang), 0, sin(ang)), 7.0)


func tick(delta: float) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	ball.tick(delta)
	# Homing drift: the ball leans toward the nearest live competitor, so
	# standing still is never the safe option.
	var target := _nearest_alive_to(ball.global_position)
	if target >= 0:
		var f := ctx.fighter(target)
		if f != null and is_instance_valid(f):
			var to: Vector3 = f.global_position - ball.global_position
			to.y = 0.0
			if to.length() > 0.1:
				ball.velocity = (ball.velocity.normalized() * 0.88 + to.normalized() * 0.12).normalized() * ball.speed


func _nearest_alive_to(p: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var d: float = f.global_position.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func _on_exploded(_b: GameBall, position: Vector3) -> void:
	AudioManager.play_sfx("explode", position)
	EventBus.shake(0.8, 0.5)
	var victim := _nearest_alive_to(position)
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var to: Vector3 = f.global_position - position
		to.y = 0.0
		var dist := to.length()
		if dist > _blast_radius:
			continue
		if i == victim:
			ctx.bump_detail(i, "falls")
			var credit: int = ball.last_toucher
			if credit >= 0 and credit != i:
				ctx.bump_detail(credit, "knockouts")
			ctx.eliminate(i)
		else:
			f.take_hit(-1, to.normalized(), 14.0, 0.0)
	if ctx.alive_count() > 1:
		_arm()


func on_sudden_death() -> void:
	_fuse_max = 2.4
	_arm()


func hud_value(slot: int) -> String:
	return Loc.t("hud.eliminated") if not ctx.is_alive(slot) else "●"


func hud_banner() -> String:
	if ball == null or not is_instance_valid(ball):
		return ""
	return "%.1f" % maxf(0.0, ball.fuse)


func ai_script() -> Script:
	return load("res://src/ai/brains/ball_brain.gd")


func detail_rows() -> Array:
	return [{"key": "results.stat.knockouts", "field": "knockouts"}]


func music_track() -> String:
	return "tension"


func cleanup() -> void:
	if ball != null and is_instance_valid(ball):
		ball.queue_free()
