extends "res://src/minigames/turret_duel.gd"

const MAX_ARMOR := 100
const SHELLS := ["standard", "rapid", "heavy", "homing", "ricochet", "triple", "sticky"]
const SHELL_COLORS := [Color("ffd66b"), Color("63e6fc"), Color("ff7459"), Color("aaef71"), Color("bca4fa"), Color("ffffff"), Color("f19cb8")]
const SHELL_DAMAGE := [25.0, 15.0, 40.0, 25.0, 22.0, 14.0, 35.0]
const SHELL_SPEED := [22.0, 36.0, 17.0, 24.0, 26.0, 25.0, 18.0]
const CRATE_RESPAWN := 9.0
var armor: Array[int] = []
var cover: Array[StaticBody3D] = []
var world: Node3D
var shell_types: Array[int] = []
var ammo: Array[int] = []
var crates: Array[Dictionary] = []
var _engine: AudioStreamPlayer


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
	shell_types.resize(ctx.player_count())
	shell_types.fill(0)
	ammo.resize(ctx.player_count())
	ammo.fill(0)
	_build_weapon_crates()
	if AudioManager.enabled:
		_engine = AudioStreamPlayer.new()
		_engine.bus = "SFX"
		_engine.stream = AudioManager._ambience_stream("atv_engine")
		_engine.volume_db = -15.0
		add_child(_engine)


func on_round_start() -> void:
	cleanup()
	armor.fill(MAX_ARMOR)
	_cooldowns.fill(0.0)
	_shot_damage = 25.0
	shell_types.fill(0)
	ammo.fill(0)
	for crate in crates:
		crate.cooldown = 0.0
		crate.node.visible = true


func _build_weapon_crates() -> void:
	for id in [6, 8, 12, 16, 18]:
		var pos: Vector3 = world.roads.get_point_position(id)
		pos.y = world.ground_height(pos.x, pos.z) + 0.85
		var box := Node3D.new()
		box.name = "AmmoCrate"
		box.add_child(MeshFactory.box(Vector3.ONE * 1.3, Color("a16734")))
		for axis in 3:
			var band := Vector3.ONE * 1.36
			band[axis] = 0.14
			box.add_child(MeshFactory.box(band, Color("ffcf65")))
		var label := Label3D.new()
		label.text = "?"
		label.font_size = 80
		label.pixel_size = 0.014
		label.position.y = 1.1
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		box.add_child(label)
		add_child(box)
		box.global_position = pos
		crates.append({"node": box, "pos": pos, "cooldown": 0.0})


func tick(delta: float) -> void:
	_tick_crates(delta)
	super.tick(delta)
	if is_instance_valid(_engine):
		var speed := -1.0
		for i in ctx.player_count():
			if InputRouter.is_human(i) and ctx.is_alive(i):
				speed = ctx.fighter(i).velocity.length()
				break
		if speed < 0.0:
			_engine.stop()
		else:
			_engine.pitch_scale = lerpf(_engine.pitch_scale, 0.7 + minf(speed / 10.0, 1.4), minf(delta * 5.0, 1.0))
			if not _engine.playing:
				_engine.play()


func _tick_crates(delta: float) -> void:
	for crate in crates:
		crate.cooldown = maxf(0.0, float(crate.cooldown) - delta)
		crate.node.visible = crate.cooldown <= 0.0
		if crate.cooldown > 0.0:
			continue
		crate.node.rotation.y += delta * 0.7
		var winner := -1
		var nearest := 2.2
		for i in ctx.player_count():
			if not ctx.is_alive(i) or ammo[i] > 0:
				continue
			var distance: float = ctx.fighter(i).global_position.distance_to(crate.pos)
			if distance < nearest:
				nearest = distance
				winner = i
		if winner >= 0:
			shell_types[winner] = ctx.rng.randi_range(1, SHELLS.size() - 1)
			ammo[winner] = 6 if shell_types[winner] == 1 else 3
			crate.cooldown = CRATE_RESPAWN
			crate.node.visible = false
			AudioManager.play_sfx("crate_break", crate.pos)
			InputRouter.haptic(winner, InputRouter.Haptic.LIGHT)


func on_round_end() -> void:
	if is_instance_valid(_engine):
		_engine.stop()


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
	var kind := shell_types[slot] if ammo[slot] > 0 else 0
	if String(ctx.config.rule("tank_variant", "normal")) == "ricochet":
		kind = 4
	var dir := fighter.facing.normalized()
	_spawn_shell(slot, kind, origin, dir)
	if kind == 5:
		_spawn_shell(slot, kind, origin, dir.rotated(Vector3.UP, -0.16))
		_spawn_shell(slot, kind, origin, dir.rotated(Vector3.UP, 0.16))
	_cooldowns[slot] = 0.25 if kind == 1 else 1.15 if kind == 2 else 0.75
	if ammo[slot] > 0 and String(ctx.config.rule("tank_variant", "normal")) != "infinite":
		ammo[slot] -= 1
		if ammo[slot] == 0:
			shell_types[slot] = 0
	AudioManager.play_sfx("cannon_fire", origin, 0.7 if kind == 2 else 1.0)


func _spawn_shell(slot: int, kind: int, origin: Vector3, dir: Vector3) -> void:
	var shot: Projectile = Pool.acquire(POOL_KEY)
	if shot == null:
		return
	if shot.get_parent() == null:
		ctx.world_root.add_child(shot)
	shot.configure(SHELL_COLORS[kind])
	if not shot.hit_fighter.is_connected(_on_hit):
		shot.hit_fighter.connect(_on_hit)
	var damage: float = SHELL_DAMAGE[kind]
	if String(ctx.config.rule("tank_variant", "normal")) == "one_shot":
		damage = MAX_ARMOR
	shot.fire(origin + dir * 1.6, dir, slot, SHELL_SPEED[kind],
		damage * (_shot_damage / 25.0), 52.0)
	shot.notify_only = true
	shot.impact_sound = "explode"
	if kind == 4:
		shot.bounces_left = 2
	elif kind == 6:
		shot.arm_sticky(ctx)
	if kind == 3:
		var target := -1
		var nearest := 40.0
		for i in ctx.player_count():
			if i == slot or not ctx.is_alive(i):
				continue
			var offset := ctx.fighter(i).global_position - origin
			if dir.dot(offset.normalized()) > 0.2 and offset.length() < nearest:
				target = i
				nearest = offset.length()
		if target >= 0:
			shot.guide(ctx, target, 1.5)
	_shots.append(shot)


func _on_hit(_projectile: Projectile, shooter: int, victim: int) -> void:
	if not ctx.is_alive(victim) or victim == shooter:
		return
	var damage := mini(armor[victim], int(_projectile.damage))
	armor[victim] -= damage
	ctx.bump_detail(shooter, "damage", damage)
	AudioManager.play_sfx("explode", ctx.fighter(victim).global_position)
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
	if not ctx.is_alive(slot):
		return Loc.t("hud.eliminated")
	if ammo[slot] > 0:
		return "%d%%\n%s %d" % [armor[slot], Loc.t("tank.shell." + SHELLS[shell_types[slot]]), ammo[slot]]
	return "%d%%\n%s" % [armor[slot], Loc.t("tank.shell.standard")]


func cleanup() -> void:
	super.cleanup()
	if is_instance_valid(_engine):
		_engine.stop()


func crate_target(slot: int) -> Vector3:
	var origin := ctx.fighter(slot).global_position
	var target := origin
	var distance := 30.0
	if ammo[slot] > 0:
		return target
	for crate in crates:
		if float(crate.cooldown) > 0.0:
			continue
		var d := origin.distance_to(crate.pos)
		if d < distance:
			distance = d
			target = crate.pos
	return target
