class_name Fighter
extends CharacterBody3D
## The one body every player controls, in every mini-game.
##
## Locomotion has three modes — walk, drive and float — because a kart and a
## runner want different integration but identical knockback, power-ups, stun,
## elimination and presentation. Keeping them in one actor is why a new
## mini-game gets working collisions, hit reactions and AI for free.
##
## The actor reads an `InputFrame` and nothing else, so a human pad, an AI brain
## and a replay all drive it through the same door.

signal knocked_out(slot: int, by_slot: int)
signal fell_out(slot: int)
signal landed()
signal attacked(slot: int)

enum Locomotion { WALK, DRIVE, FLOAT }

const LAYER_WORLD := 1
const LAYER_PLAYER := 2

var slot := 0
var data: CharacterData
var locomotion: Locomotion = Locomotion.WALK

# --- derived stats (set in _apply_character) --------------------------------
var top_speed := 9.0
var acceleration := 55.0
var friction := 38.0
var jump_velocity := 9.0
var knock_power := 1.0
var knock_resist := 1.0
var turn_rate := 12.0
var air_control := 0.45

# --- runtime ---------------------------------------------------------------
var facing := Vector3.FORWARD
var control_enabled := true
var can_jump := true
var can_attack := true
var can_dash := true
var alive := true
var health := 100.0
var max_health := 100.0
var damage_percent := 0.0    ## combat games: higher = flies further
var lives := 1
var carrying := 0            ## generic "carried items" counter for crate/gem games

var _impulse := Vector3.ZERO
var _stun := 0.0
var _dash_cd := 0.0
var _dash_time := 0.0
var _attack_cd := 0.0
var _attack_time := 0.0
var _invuln := 0.0
var _hitstop := 0.0
var _steer := 0.0            ## drive mode heading
var _last_hit_by := -1
var _last_hit_timer := 0.0
var _visual: Node3D
var _squash := Vector3.ONE
var _was_on_floor := true
var _spawn_point := Vector3.ZERO

## Multiplicative modifiers owned by PowerUpSystem. Fighters never write these.
var mods := {
	"speed": 1.0, "push": 1.0, "weight": 1.0, "points": 1.0,
	"magnet": 0.0, "shield": 0.0, "frozen": 0.0, "jump": 1.0, "dash": 1.0,
}

## Match-wide modifiers owned by MutatorSystem. Kept separate from `mods` so a
## power-up and a mutator can both be active without either clobbering the
## other, and so re-applying a mutator set is idempotent.
var mutator := {
	"speed": 1.0, "gravity": 1.0, "friction": 1.0, "knockback_taken": 1.0, "size": 1.0,
}

var _tuning := {}


func _ready() -> void:
	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_WORLD | LAYER_PLAYER
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.4
	if get_node_or_null("Body") == null:
		_build_collision()


func setup(player_slot: int, character: CharacterData, mode: Locomotion = Locomotion.WALK) -> void:
	slot = player_slot
	data = character
	locomotion = mode
	_apply_character()
	_build_visual()


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	shape.name = "Body"
	if locomotion == Locomotion.DRIVE:
		var b := BoxShape3D.new()
		b.size = Vector3(1.4, 0.9, 2.0)
		shape.shape = b
		shape.position = Vector3(0, 0.55, 0)
	else:
		var c := CapsuleShape3D.new()
		c.radius = 0.42
		c.height = 1.5
		shape.shape = c
		shape.position = Vector3(0, 0.75, 0)
	add_child(shape)


func _apply_character() -> void:
	var t := Balance.table("tuning").get("fighter", {})
	_tuning = t
	var base_speed := float(t.get("base_speed", 7.4))
	var speed_range := float(t.get("speed_range", 3.2))
	var base_accel := float(t.get("base_accel", 38.0))
	var accel_range := float(t.get("accel_range", 34.0))
	var base_jump := float(t.get("base_jump", 8.2))
	var jump_range := float(t.get("jump_range", 2.6))

	var d := data if data != null else CharacterData.new()
	top_speed = base_speed + speed_range * d.speed
	acceleration = base_accel + accel_range * d.accel
	friction = float(t.get("friction", 34.0))
	jump_velocity = base_jump + jump_range * d.jump
	# Heavier characters are pushed less but also push harder to land.
	knock_resist = float(t.get("resist_base", 0.7)) + float(t.get("resist_range", 0.75)) * d.weight
	knock_power = float(t.get("power_base", 0.72)) + float(t.get("power_range", 0.7)) * d.power
	turn_rate = float(t.get("turn_base", 7.0)) + float(t.get("turn_range", 10.0)) * d.control
	air_control = float(t.get("air_base", 0.28)) + float(t.get("air_range", 0.4)) * d.control
	if locomotion == Locomotion.DRIVE:
		top_speed *= float(t.get("drive_speed_mult", 1.5))
		acceleration *= float(t.get("drive_accel_mult", 0.55))
	max_health = float(t.get("base_health", 100.0))
	health = max_health


func _build_visual() -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var d := data if data != null else CharacterData.new()
	if locomotion == Locomotion.DRIVE:
		_visual.add_child(MeshFactory.kart(d.color, d.accent))
	else:
		_visual.add_child(MeshFactory.character_body(d))
	# A ground ring keeps a player findable when the camera pulls back or the
	# body is behind a wall — the single most-requested readability fix in
	# 4-player couch games.
	var ring := MeshFactory.torus(0.5, 0.68, d.color, 0.9)
	ring.position = Vector3(0, 0.06, 0)
	ring.name = "Marker"
	_visual.add_child(ring)


func set_spawn(p: Vector3) -> void:
	_spawn_point = p


# --- per-tick --------------------------------------------------------------

func tick(frame: InputFrame, delta: float) -> void:
	if not alive:
		return
	if _hitstop > 0.0:
		_hitstop -= delta
		velocity = Vector3.ZERO
		move_and_slide()
		return
	_advance_timers(delta)

	var wish := Vector3.ZERO
	if control_enabled and _stun <= 0.0 and mods["frozen"] <= 0.0:
		wish = Vector3(frame.move.x, 0.0, frame.move.y)
		if wish.length() > 1.0:
			wish = wish.normalized()
		_handle_buttons(frame)

	match locomotion:
		Locomotion.DRIVE:
			_integrate_drive(wish, delta)
		Locomotion.FLOAT:
			_integrate_float(wish, delta)
		_:
			_integrate_walk(wish, delta)

	_apply_impulse(delta)
	var was_floor := is_on_floor()
	move_and_slide()
	if not _was_on_floor and is_on_floor():
		_squash = Vector3(1.22, 0.74, 1.22)
		landed.emit()
	_was_on_floor = is_on_floor()
	_update_visual(delta, wish)


func _advance_timers(delta: float) -> void:
	_stun = maxf(0.0, _stun - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_dash_time = maxf(0.0, _dash_time - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_attack_time = maxf(0.0, _attack_time - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_last_hit_timer = maxf(0.0, _last_hit_timer - delta)
	if _last_hit_timer <= 0.0:
		_last_hit_by = -1


func _handle_buttons(frame: InputFrame) -> void:
	if can_jump and frame.just_pressed(InputFrame.Btn.JUMP) and is_on_floor():
		velocity.y = jump_velocity * float(mods["jump"])
		_squash = Vector3(0.78, 1.3, 0.78)
	if can_dash and frame.just_pressed(InputFrame.Btn.DASH) and _dash_cd <= 0.0:
		_do_dash(frame)
	if can_attack and frame.just_pressed(InputFrame.Btn.ATTACK) and _attack_cd <= 0.0:
		_do_attack()


func _do_dash(frame: InputFrame) -> void:
	var dir := Vector3(frame.move.x, 0, frame.move.y)
	if dir.length_squared() < 0.05:
		dir = facing
	dir = dir.normalized()
	var t := _tuning
	_impulse += dir * float(t.get("dash_impulse", 15.0)) * float(mods["speed"])
	_dash_cd = float(t.get("dash_cooldown", 0.85)) / maxf(0.2, float(mods["dash"]))
	_dash_time = float(t.get("dash_duration", 0.22))
	_invuln = maxf(_invuln, float(t.get("dash_invuln", 0.1)))
	facing = dir
	AudioManager.play_sfx("dash", global_position)


func _do_attack() -> void:
	var t := _tuning
	_attack_cd = float(t.get("attack_cooldown", 0.55))
	_attack_time = float(t.get("attack_duration", 0.2))
	attacked.emit(slot)
	AudioManager.play_sfx("swing", global_position)
	var range_ := float(t.get("attack_range", 2.1))
	var arc := cos(deg_to_rad(float(t.get("attack_arc_deg", 100.0)) * 0.5))
	var strength := float(t.get("attack_knockback", 11.0)) * knock_power * float(mods["push"])
	for other in get_tree().get_nodes_in_group("fighters"):
		if other == self or not (other is Fighter) or not other.alive:
			continue
		var to: Vector3 = other.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > range_ or dist < 0.01:
			continue
		if facing.normalized().dot(to / dist) < arc:
			continue
		other.take_hit(slot, to.normalized(), strength, float(t.get("attack_damage", 9.0)))


## Central damage/knockback entry point. Everything that pushes a player —
## melee, explosions, hazards, karts, balls — goes through here so shields,
## invulnerability and weight are applied exactly once.
func take_hit(from_slot: int, direction: Vector3, strength: float, damage: float = 0.0, ignore_shield: bool = false) -> bool:
	if not alive or _invuln > 0.0:
		return false
	if mods["shield"] > 0.0 and not ignore_shield:
		mods["shield"] = 0.0
		_invuln = 0.4
		EventBus.player_hit.emit(from_slot, slot, 0.0)
		AudioManager.play_sfx("shield_break", global_position)
		_spawn_burst(Color(0.6, 0.9, 1.0), 8)
		return false
	direction.y = 0.0
	direction = direction.normalized()
	# Damage scales knockback the way arcade fighters do: the longer you last
	# without being reset, the further each hit sends you.
	var scale := 1.0 + damage_percent * float(_tuning.get("damage_knock_scale", 0.011))
	var push := strength * scale * float(mutator["knockback_taken"]) / maxf(0.3, knock_resist * float(mods["weight"]))
	_impulse += direction * push
	_impulse.y += push * float(_tuning.get("knock_lift", 0.22))
	damage_percent += damage
	health -= damage
	_stun = maxf(_stun, float(_tuning.get("hit_stun", 0.16)))
	_invuln = maxf(_invuln, float(_tuning.get("hit_invuln", 0.12)))
	_hitstop = float(_tuning.get("hitstop", 0.05))
	# An environmental knock — bumper, sweeper, blast — has no owner, and
	# claiming the victim for nobody erases the shove that put them there. In
	# Bumper Bowl the bumpers cause nearly every ring-out, so a rival could set
	# up a launch perfectly and the point went nowhere: 34 of 40 simulated
	# rounds ended with all four players on zero. A hazard now leaves an
	# in-window credit standing; only another player can take it over.
	if from_slot >= 0:
		_last_hit_by = from_slot
		_last_hit_timer = float(_tuning.get("assist_window", 5.0))
	_squash = Vector3(1.3, 0.7, 1.3)
	EventBus.player_hit.emit(from_slot, slot, push)
	EventBus.shake(minf(0.5, push * 0.03), 0.18)
	InputRouter.rumble(slot, clampf(push * 0.05, 0.15, 0.8), 0.16)
	AudioManager.play_sfx("hit", global_position)
	_spawn_burst(data.accent if data != null else Color.WHITE, 7)
	if health <= 0.0:
		_on_defeated(from_slot)
	return true


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)


func reset_damage() -> void:
	damage_percent = 0.0
	health = max_health


func apply_impulse(v: Vector3) -> void:
	_impulse += v


func stun(seconds: float) -> void:
	_stun = maxf(_stun, seconds)


func freeze(seconds: float) -> void:
	mods["frozen"] = maxf(float(mods["frozen"]), seconds)


func last_attacker() -> int:
	return _last_hit_by


func is_dashing() -> bool:
	return _dash_time > 0.0


func is_attacking() -> bool:
	return _attack_time > 0.0


func speed_ratio() -> float:
	return clampf(Vector2(velocity.x, velocity.z).length() / maxf(top_speed, 0.1), 0.0, 1.5)


## Called by the mini-game when the body left the play area.
func on_fell_out() -> void:
	if not alive:
		return
	fell_out.emit(slot)
	AudioManager.play_sfx("fall", global_position)


func respawn_at(p: Vector3) -> void:
	global_position = p
	velocity = Vector3.ZERO
	_impulse = Vector3.ZERO
	_stun = 0.0
	_invuln = 1.0
	alive = true
	visible = true
	set_physics_process(true)
	_spawn_burst(data.color if data != null else Color.WHITE, 12)
	EventBus.player_respawned.emit(slot)


func on_eliminated() -> void:
	alive = false
	velocity = Vector3.ZERO
	_impulse = Vector3.ZERO
	visible = false
	_spawn_burst(data.color if data != null else Color.WHITE, 16)
	AudioManager.play_sfx("eliminate", global_position)


func celebrate(win: bool) -> void:
	control_enabled = false
	if _visual == null or not is_instance_valid(_visual):
		return
	var tween := create_tween().set_loops(3)
	if win:
		match (data.celebration if data != null else "spin"):
			"leap":
				tween.tween_property(_visual, "position:y", 1.1, 0.24).set_trans(Tween.TRANS_QUAD)
				tween.tween_property(_visual, "position:y", 0.0, 0.24).set_trans(Tween.TRANS_BOUNCE)
			"flex":
				tween.tween_property(_visual, "scale", Vector3(1.3, 0.85, 1.3), 0.2)
				tween.tween_property(_visual, "scale", Vector3.ONE, 0.2)
			"bow":
				tween.tween_property(_visual, "rotation:x", -0.5, 0.3)
				tween.tween_property(_visual, "rotation:x", 0.0, 0.3)
			"shimmer":
				tween.tween_property(_visual, "scale", Vector3(1.1, 1.1, 1.1), 0.16)
				tween.tween_property(_visual, "scale", Vector3(0.92, 0.92, 0.92), 0.16)
			_:
				tween.tween_property(_visual, "rotation:y", TAU, 0.5)
				tween.tween_property(_visual, "rotation:y", 0.0, 0.0)
	else:
		tween.tween_property(_visual, "rotation:z", 0.35, 0.3)
		tween.tween_property(_visual, "rotation:z", -0.35, 0.3)


# --- integration -----------------------------------------------------------

func _integrate_walk(wish: Vector3, delta: float) -> void:
	var speed := top_speed * float(mods["speed"]) * float(mutator["speed"])
	var target := wish * speed
	var control := 1.0 if is_on_floor() else air_control
	var a := acceleration * control * delta
	velocity.x = move_toward(velocity.x, target.x, a if wish.length_squared() > 0.01 else friction * control * delta)
	velocity.z = move_toward(velocity.z, target.z, a if wish.length_squared() > 0.01 else friction * control * delta)
	if not is_on_floor():
		velocity.y -= _gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = -1.0
	if wish.length_squared() > 0.02:
		facing = facing.slerp(wish.normalized(), clampf(turn_rate * delta, 0.0, 1.0))


func _integrate_drive(wish: Vector3, delta: float) -> void:
	# Karts steer rather than strafe: the stick's X turns, its Y drives. This is
	# what makes a vehicle arena feel different from a walking one even though
	# both use the same actor.
	var t := _tuning
	var steer_rate := float(t.get("drive_steer", 3.0)) * (0.35 + 0.65 * clampf(speed_ratio(), 0.0, 1.0))
	_steer -= wish.x * steer_rate * delta
	var forward := Vector3(sin(_steer), 0.0, cos(_steer))
	var throttle := -wish.z
	var target := forward * throttle * top_speed * float(mods["speed"]) * float(mutator["speed"])
	var a := acceleration * delta
	velocity.x = move_toward(velocity.x, target.x, a if absf(throttle) > 0.05 else friction * 0.7 * delta)
	velocity.z = move_toward(velocity.z, target.z, a if absf(throttle) > 0.05 else friction * 0.7 * delta)
	if not is_on_floor():
		velocity.y -= _gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = -1.0
	facing = forward


func _integrate_float(wish: Vector3, delta: float) -> void:
	var speed := top_speed * float(mods["speed"]) * float(mutator["speed"]) * 0.85
	var target := wish * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * 0.7 * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * 0.7 * delta)
	velocity.y = move_toward(velocity.y, 0.0, 6.0 * delta)
	if wish.length_squared() > 0.02:
		facing = facing.slerp(wish.normalized(), clampf(turn_rate * delta, 0.0, 1.0))


func _apply_impulse(delta: float) -> void:
	if _impulse.length_squared() < 0.0004:
		_impulse = Vector3.ZERO
		return
	velocity += _impulse
	var damp := float(_tuning.get("impulse_damping", 9.0))
	_impulse = _impulse.move_toward(Vector3.ZERO, damp * delta * maxf(1.0, _impulse.length() * 0.35))


func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 26.0)) * float(mutator["gravity"])


## Scale the whole body, visual and collision, for the tiny/giant mutators.
func set_body_scale(value: float) -> void:
	value = clampf(value, 0.4, 2.0)
	if is_equal_approx(float(mutator["size"]), value):
		return
	mutator["size"] = value
	if _visual != null and is_instance_valid(_visual):
		_visual.scale = Vector3.ONE * value
	var shape := get_node_or_null("Body") as CollisionShape3D
	if shape == null:
		return
	if shape.shape is CapsuleShape3D:
		var c: CapsuleShape3D = shape.shape
		c.radius = 0.42 * value
		c.height = maxf(1.5 * value, c.radius * 2.0 + 0.01)
		shape.position.y = 0.75 * value
	elif shape.shape is BoxShape3D:
		(shape.shape as BoxShape3D).size = Vector3(1.4, 0.9, 2.0) * value


func _update_visual(delta: float, wish: Vector3) -> void:
	if _visual == null or not is_instance_valid(_visual):
		return
	if facing.length_squared() > 0.001:
		var target := atan2(facing.x, facing.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target, clampf(18.0 * delta, 0.0, 1.0))
	# Squash-and-stretch is the cheapest way to make a primitive body feel alive.
	_squash = _squash.lerp(Vector3.ONE, clampf(9.0 * delta, 0.0, 1.0))
	var bob := 1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.03 * speed_ratio()
	_visual.scale = Vector3(_squash.x, _squash.y * bob, _squash.z)
	if _stun > 0.0 or mods["frozen"] > 0.0:
		_visual.rotation.z = sin(Time.get_ticks_msec() * 0.05) * 0.12
	else:
		_visual.rotation.z = lerp(_visual.rotation.z, 0.0, clampf(10.0 * delta, 0.0, 1.0))


func _on_defeated(by_slot: int) -> void:
	health = 0.0
	knocked_out.emit(slot, by_slot)


func _spawn_burst(color: Color, count: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if bool(UserSettings.get_value("reduce_effects")):
		count = maxi(3, count / 3)
	var parent := get_parent()
	if parent == null:
		return
	var b := MeshFactory.burst(color, count)
	parent.add_child(b)
	b.global_position = global_position + Vector3(0, 0.8, 0)
