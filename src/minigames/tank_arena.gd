extends "res://src/minigames/turret_duel.gd"

const MAX_ARMOR := 100
var armor: Array[int] = []
var cover: Array[StaticBody3D] = []
var world: Node3D


func configure() -> void:
	super.configure()
	eliminate_on_fall = true
	lives_per_player = 1
	_shot_damage = 25.0
	_shot_speed = 22.0
	_cooldown = 0.75


func build() -> void:
	super.build()
	armor.resize(ctx.player_count())
	armor.fill(MAX_ARMOR)
	for f in ctx.fighters:
		f.ram_enabled = false
	var arena := ctx.arena as Arena
	arena._env.environment.fog_enabled = false
	arena._env.environment.volumetric_fog_enabled = false
	world = load("res://src/arenas/tank_world.gd").new()
	arena.add_child(world)
	world.build(arena)
	cover.assign(world.buildings)
	arena.set_meta("tank_world", world)


func on_round_start() -> void:
	cleanup()
	armor.fill(MAX_ARMOR)
	_cooldowns.fill(0.0)
	_shot_damage = 25.0


func wants_fire(frame: InputFrame) -> bool:
	return frame.held(InputFrame.Btn.ATTACK)


func _fire(slot: int) -> void:
	var fighter := ctx.fighter(slot)
	var origin := fighter.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(origin, origin + fighter.facing.normalized() * 1.8, 1)
	query.hit_from_inside = true
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		_cooldowns[slot] = _cooldown
		return
	var before := _shots.size()
	super._fire(slot)
	if _shots.size() > before:
		_shots.back().notify_only = true


func _on_hit(_projectile: Projectile, shooter: int, victim: int) -> void:
	if not ctx.is_alive(victim) or victim == shooter:
		return
	var damage := mini(armor[victim], int(_projectile.damage))
	armor[victim] -= damage
	ctx.bump_detail(shooter, "damage", damage)
	AudioManager.play_sfx("bounce", ctx.fighter(victim).global_position)
	InputRouter.haptic(victim, InputRouter.Haptic.HEAVY)
	if armor[victim] <= 0:
		ctx.bump_detail(shooter, "knockouts", 1)
		ctx.eliminate(victim)
		AudioManager.play_sfx("eliminate", ctx.fighter(victim).global_position)


func compute_scores() -> Array[int]:
	var scores := ctx.survival_scores()
	for i in scores.size():
		scores[i] = scores[i] * 100 + (armor[i] if ctx.is_alive(i) else 0)
	return scores


func is_round_over() -> bool:
	return ctx.alive_count() <= 1 or ctx.early_finish


func camera_mode() -> int:
	return ArenaCamera.Mode.WORLD


func on_sudden_death() -> void:
	_shot_damage = 50.0


func allows_attack() -> bool:
	return false # The cannon consumes ATTACK; a shot must not also trigger melee.


func allows_dash() -> bool:
	return false


func uses_powerups() -> bool:
	return false


func ai_script() -> Script:
	return load("res://src/ai/brains/tank_brain.gd")


func hud_value(slot: int) -> String:
	return "%d%%" % armor[slot] if ctx.is_alive(slot) else Loc.t("hud.eliminated")
