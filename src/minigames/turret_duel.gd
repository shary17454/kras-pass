extends MiniGameController
## Turret Duel — drive, aim, shoot, use cover.
##
## Points are for hits landed, never for hits taken, so trading shots is a bad
## deal and the pillars matter. Shots are pooled and swept, so nothing tunnels
## through cover at high speed.

const POOL_KEY := "turret_shot"

var _cooldowns: Array[float] = []
var _shots: Array[Projectile] = []
var _shot_speed := 24.0
var _shot_damage := 14.0
var _cooldown := 0.9


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99
	var t := Balance.table("tuning").get("vehicle", {})
	_shot_speed = float(t.get("projectile_speed", 24.0))
	_shot_damage = float(t.get("projectile_damage", 14.0))
	_cooldown = float(t.get("projectile_cooldown", 0.9))


func build() -> void:
	_cooldowns.resize(ctx.player_count())
	_cooldowns.fill(0.0)
	Pool.define(POOL_KEY, func(): return Projectile.new(),
		int(Balance.num("tuning", "performance.pool_prewarm_projectiles", 24)))


func locomotion() -> int:
	return Fighter.Locomotion.DRIVE


func allows_attack() -> bool:
	return true


func tick(delta: float) -> void:
	for i in _cooldowns.size():
		_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
		if not ctx.is_alive(i):
			continue
		var frame := InputRouter.frame(i)
		if frame.just_pressed(InputFrame.Btn.ATTACK) and _cooldowns[i] <= 0.0:
			_fire(i)
	var i := _shots.size() - 1
	while i >= 0:
		var s := _shots[i]
		if not is_instance_valid(s) or not s.active:
			if is_instance_valid(s):
				Pool.release(POOL_KEY, s)
			_shots.remove_at(i)
		else:
			s.tick(delta)
		i -= 1


func _fire(slot: int) -> void:
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f):
		return
	_cooldowns[slot] = _cooldown
	var shot: Projectile = Pool.acquire(POOL_KEY)
	if shot == null:
		return
	if shot.get_parent() == null:
		ctx.world_root.add_child(shot)
	var col := UIKit.adapt(ctx.config.players[slot].color())
	shot.configure(col)
	if not shot.hit_fighter.is_connected(_on_hit):
		shot.hit_fighter.connect(_on_hit)
	var dir := f.facing.normalized()
	shot.fire(f.global_position + Vector3(0, 1.0, 0) + dir * 1.6, dir, slot, _shot_speed, _shot_damage, 26.0)
	_shots.append(shot)
	AudioManager.play_sfx("swing", f.global_position, 0.7)


func _on_hit(_p: Projectile, shooter: int, victim: int) -> void:
	ctx.add_score(shooter, int(1 * ctx.powerups.point_multiplier(shooter)))
	ctx.bump_detail(shooter, "damage", int(_shot_damage))
	ctx.bump_detail(victim, "falls", 0)
	AudioManager.play_sfx("score")


func is_round_over() -> bool:
	return ctx.early_finish


func ai_script() -> Script:
	return load("res://src/ai/brains/gunner_brain.gd")


func hud_value(slot: int) -> String:
	return str(ctx.scores[slot])


func detail_rows() -> Array:
	return [{"key": "results.stat.damage", "field": "damage"}]


func music_track() -> String:
	return "arena_b"


func cleanup() -> void:
	for s in _shots:
		if is_instance_valid(s):
			Pool.release(POOL_KEY, s)
	_shots.clear()
