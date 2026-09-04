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
## Dash energy, 0..1. A shove is a resource, not a cooldown: the charge drains
## per dash and trickles back, so the strong dash cannot be held down. Karts are
## exempt — a vehicle boost is a different verb, it comes from pads and the
## boost power-up, and putting it on the brawler's meter would silently rewrite
## every race.
var charge := 1.0
var ram_enabled := true      ## body-to-body impacts; a game may switch them off
## Slots this body refuses to be hurt by. Team games fill it in; a free-for-all
## leaves it empty. Teammates still collide physically — they just cannot shove
## each other into the water.
var teammates := {}
## Flat speed carried into this frame's collisions, sampled before the solver
## has had a chance to cancel it. Ice barriers read it to tell a lean from a
## charge: after `move_and_slide` the component into a wall is already gone, so
## anything measured afterwards says every impact was gentle.
var impact_speed := 0.0
## Surface grip under the body, fed by the match layer. 1.0 is normal ground,
## lower is a slick patch.
var surface_grip := 1.0

## Body-to-body contacts waiting to be resolved this tick, keyed "low:high" so a
## pair seen by both bodies is resolved once, and the per-pair cooldown that
## stops a grind from firing sixty times a second.
##
## Static, and deferred until every body has moved, because resolving inside
## each body's own tick handed the lower slot a real advantage: it shoved first,
## its victim was already flying by the time it ticked, and the retaliation was
## measured against a velocity the first hit had changed — or the contact was
## gone entirely. The balance simulator caught it as an 18% spawn-slot
## advantage in Ring Rumble at forty runs.
static var _contacts := {}
static var _pair_cooldown := {}
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
var _visual_theme := ""
var _mount_intact := false
var _squash := Vector3.ONE
var _was_on_floor := true
var _spawn_point := Vector3.ZERO
var _pre_vel := Vector3.ZERO ## velocity carried into this tick: the approach
var _fx_time := 0.0          ## advanced by delta, so replays stay reproducible
var _edge_margin := 99.0     ## fed by the match layer; drives the panic pose
var _spin_time := 0.0        ## cartoon spin-out after a heavy hit
var _rig := CharacterRig.new()   ## limbs and face, when this body has them
var _shocked := 0.0         ## sparks + lost control from an electric hit
var _state_fx: Node3D       ## persistent status visuals, built on first need
var _size_mutator := 1.0
var _size_power := 1.0
var _wish_smooth := Vector3.ZERO
var _snow_timer := 0.0

## Multiplicative modifiers owned by PowerUpSystem. Fighters never write these.
## `resist_taken` multiplies incoming knockback (tough < 1, frail > 1),
## `friction` scales ground grip (slick lowers it), `lag` smooths the stick
## instead of reading it directly (a slowed response), `scramble` rotates the
## stick over time (confused controls) and `size` is the power-up half of body
## scale — the mutator half lives in `mutator["size"]` so the two never
## clobber each other.
var mods := {
	"speed": 1.0, "push": 1.0, "weight": 1.0, "points": 1.0,
	"magnet": 0.0, "shield": 0.0, "frozen": 0.0, "jump": 1.0, "dash": 1.0,
	"resist_taken": 1.0, "friction": 1.0, "lag": 0.0, "scramble": 0.0, "size": 1.0,
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


func setup(player_slot: int, character: CharacterData, mode: Locomotion = Locomotion.WALK, visual_theme := "") -> void:
	slot = player_slot
	data = character
	locomotion = mode
	_visual_theme = visual_theme
	_mount_intact = _visual_theme == "arctic" and locomotion == Locomotion.WALK
	_apply_character()
	if _visual_theme == "arctic" and locomotion == Locomotion.WALK:
		friction *= 0.58
		acceleration *= 0.9
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
	elif _visual_theme == "arctic":
		var mount := MeshFactory.arctic_mount(slot, d.color, d.accent)
		mount.name = "Mount"
		mount.position = Vector3(0, 0.02, 0)
		_visual.add_child(mount)
		var rider := MeshFactory.character_body(d)
		rider.name = "Rider"
		rider.position = Vector3(0, 0.95, 0.03)
		rider.scale = Vector3.ONE * 0.54
		_visual.add_child(rider)
	else:
		_visual.add_child(MeshFactory.character_body(d))
	# Limbs and face, if this body has any. A kart has none and the rig simply
	# reports that once instead of searching every frame.
	_rig.bind(_visual)
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
	_pre_vel = velocity
	_advance_timers(delta)

	var wish := Vector3.ZERO
	if control_enabled and _stun <= 0.0 and mods["frozen"] <= 0.0:
		wish = Vector3(frame.move.x, 0.0, frame.move.y)
		if wish.length() > 1.0:
			wish = wish.normalized()
		wish = _condition_wish(wish, delta)
		_handle_buttons(frame)

	match locomotion:
		Locomotion.DRIVE:
			_integrate_drive(wish, delta)
		Locomotion.FLOAT:
			_integrate_float(wish, delta)
		_:
			_integrate_walk(wish, delta)

	_apply_impulse(delta)
	impact_speed = Vector2(velocity.x, velocity.z).length()
	move_and_slide()
	_collect_body_contacts()
	if not _was_on_floor and is_on_floor():
		_squash = Vector3(1.22, 0.74, 1.22)
		landed.emit()
	_was_on_floor = is_on_floor()
	_update_visual(delta, wish)
	_emit_ground_spray(delta)


func _advance_timers(delta: float) -> void:
	_fx_time += delta
	_stun = maxf(0.0, _stun - delta)
	_spin_time = maxf(0.0, _spin_time - delta)
	_shocked = maxf(0.0, _shocked - delta)
	if locomotion != Locomotion.DRIVE:
		charge = minf(1.0, charge + float(_tuning.get("charge_refill", 0.3))
			* float(mods["dash"]) * delta)

	# Freeze runs on this clock rather than through PowerUpSystem's effect list,
	# so it has to be counted down here. Nothing else ever lowers it.
	mods["frozen"] = maxf(0.0, float(mods["frozen"]) - delta)
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


## True when there is enough meter left to dash. The AI asks before pressing so
## an empty bot does not mash a button that cannot fire.
func can_afford_dash() -> bool:
	if locomotion == Locomotion.DRIVE:
		return true
	return charge >= float(_tuning.get("dash_cost", 0.34))


func _do_dash(frame: InputFrame) -> void:
	if not can_afford_dash():
		return
	if locomotion != Locomotion.DRIVE:
		charge = maxf(0.0, charge - float(_tuning.get("dash_cost", 0.34)))
	# Walking dashes go where the stick points. Driving is different: the stick
	# is (steer, throttle), not a world direction, so reading it as one sent
	# every kart boost toward world -Z regardless of heading — half the lap the
	# boost was a brake, and the tiers that boost most paid the most for it. A
	# vehicle boost goes where the nose points.
	var dir := Vector3(frame.move.x, 0, frame.move.y)
	if locomotion == Locomotion.DRIVE or dir.length_squared() < 0.05:
		dir = facing
	dir = dir.normalized()
	var t := _tuning
	_impulse += dir * float(t.get("dash_impulse", 15.0)) * float(mods["speed"])
	_dash_cd = float(t.get("dash_cooldown", 0.85)) / maxf(0.2, float(mods["dash"]))
	_dash_time = float(t.get("dash_duration", 0.22))
	_invuln = maxf(_invuln, float(t.get("dash_invuln", 0.1)))
	facing = dir
	# Stretch along the launch, the other half of squash-and-stretch: the body
	# thins and lengthens into a dash and squats on landing.
	_squash = Vector3(0.84, 0.9, 1.3)
	AudioManager.play_sfx("dash", global_position, _voice())


func _do_attack() -> void:
	var t := _tuning
	_attack_cd = float(t.get("attack_cooldown", 0.55))
	_attack_time = float(t.get("attack_duration", 0.2))
	attacked.emit(slot)
	AudioManager.play_sfx("swing", global_position, _voice())
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
	if from_slot >= 0 and teammates.has(from_slot):
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
	var push := strength * scale * float(mutator["knockback_taken"]) * float(mods["resist_taken"]) \
		/ maxf(0.3, knock_resist * float(mods["weight"]))
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
	# A heavy shove spins the body instead of only sliding it. Presentation
	# only — the spin never feeds back into the physics.
	if push > float(_tuning.get("spin_out_push", 9.0)):
		_spin_time = maxf(_spin_time, float(_tuning.get("spin_out_time", 0.45)))
	EventBus.player_hit.emit(from_slot, slot, push)
	EventBus.shake(minf(0.5, push * 0.03), 0.18)
	# Scaled by the shove that actually landed, so a graze and a launch do not
	# feel the same. InputRouter grades it and picks the right actuator.
	InputRouter.rumble(slot, clampf(push * 0.035, 0.15, 0.95), 0.16)
	AudioManager.play_sfx("hit", global_position, _voice())
	_spawn_burst(data.accent if data != null else Color.WHITE, 7)
	if health <= 0.0:
		_on_defeated(from_slot)
	return true


## This character's voice, as a pitch multiplier. `voice_pitch` has been in
## data/characters.json from the start — a boulder at 0.72 and a spark at 1.45 —
## and nothing read it, so every body swung, fell and went out in the same
## voice. The spec asks for a character to sound like itself on attack, on
## taking a hit, on falling and on going out; those are exactly the sounds this
## actor plays, so this is where the number belongs.
func _voice(base: float = 1.0) -> float:
	return base * (data.voice_pitch if data != null else 1.0)


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


## An electric jolt: control is gone for a beat, momentum is not. Being shocked
## mid-slide still carries you toward the rim you were already heading for,
## which is what makes it a penalty rather than a pause.
func shock(seconds: float) -> void:
	_shocked = maxf(_shocked, seconds)
	_stun = maxf(_stun, seconds)
	AudioManager.play_sfx("shock", global_position, _voice())


func has_mount() -> bool:
	return _mount_intact and _visual_theme == "arctic" and locomotion == Locomotion.WALK


func knock_mount_off(direction: Vector3) -> bool:
	if not has_mount() or _visual == null or not is_instance_valid(_visual):
		return false
	var mount := _visual.get_node_or_null("Mount") as Node3D
	if mount == null:
		_mount_intact = false
		return false
	_mount_intact = false
	var world_parent := get_parent()
	var start := mount.global_position
	_visual.remove_child(mount)
	if world_parent != null:
		world_parent.add_child(mount)
	mount.global_position = start
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = facing
	direction = direction.normalized()
	var tween := mount.create_tween().set_parallel(true)
	tween.tween_property(mount, "global_position", start + direction * 3.8 + Vector3(0, 1.5, 0), 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mount, "rotation", mount.rotation + Vector3(0.9, 1.8, 0.55), 0.55)
	tween.tween_property(mount, "scale", Vector3.ONE * 0.15, 0.45).set_delay(0.22)
	tween.chain().tween_callback(mount.queue_free)
	_squash = Vector3(1.4, 0.68, 1.4)
	_invuln = maxf(_invuln, 0.3)
	AudioManager.play_sfx("splash", global_position)
	_spawn_burst(data.accent if data != null else Color.WHITE, 14)
	return true


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
	AudioManager.play_sfx("fall", global_position, _voice())
	if _visual_theme == "arctic":
		AudioManager.play_sfx("splash", global_position)


func respawn_at(p: Vector3) -> void:
	global_position = p
	velocity = Vector3.ZERO
	_impulse = Vector3.ZERO
	_stun = 0.0
	mods["frozen"] = 0.0
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
	AudioManager.play_sfx("eliminate", global_position, _voice())


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
	# Grip is a modifier, not a constant: ice, the slick power-down and the
	# low-friction mutator all arrive here, and low grip is what makes a body
	# keep sliding after the stick is released.
	var grip := friction * float(mods["friction"]) * float(mutator["friction"]) \
		* surface_grip * control * delta
	velocity.x = move_toward(velocity.x, target.x, a if wish.length_squared() > 0.01 else grip)
	velocity.z = move_toward(velocity.z, target.z, a if wish.length_squared() > 0.01 else grip)
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
	# `_impulse` is the Δv a hit still owes this body, paid out over the ~0.3 s
	# the damping needs to drain it — that spread is what makes a shove read as
	# a push rather than a teleport. Pay out exactly what drains each frame.
	# The previous line here was `velocity += _impulse` with no delta: the full
	# remaining impulse re-added sixty times a second, so a tuned 11.5 shove
	# delivered ~110 m/s and threw its victim two hundred metres off a ring
	# thirteen metres wide. Every symptom traced back to this one line — rounds
	# of a 95-second game over in 4.7 s, forty-five falls per match, and every
	# skill gap erased because any exchange was a coin-flip execution.
	var damp := float(_tuning.get("impulse_damping", 9.0))
	var before := _impulse
	_impulse = _impulse.move_toward(Vector3.ZERO, damp * delta * maxf(1.0, before.length() * 0.35))
	velocity += before - _impulse


func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 26.0)) * float(mutator["gravity"])


## Scale the whole body for the tiny/giant mutators.
func set_body_scale(value: float) -> void:
	value = clampf(value, 0.4, 2.0)
	if is_equal_approx(_size_mutator, value):
		return
	_size_mutator = value
	mutator["size"] = value
	_apply_scale()


## Scale the body for the grow/shrink power-ups. Kept separate from the mutator
## scale so a giant-mutator match can still hand out a shrink without the two
## fighting over one number.
func set_powerup_scale(value: float) -> void:
	value = clampf(value, 0.45, 1.9)
	if is_equal_approx(_size_power, value):
		return
	_size_power = value
	mods["size"] = value
	_apply_scale()


func body_scale() -> float:
	return clampf(_size_mutator * _size_power, 0.4, 2.2)


## Resize the collision body. The visual half is applied every frame inside
## `_update_visual`, because squash-and-stretch owns `_visual.scale` outright:
## writing a size here as well meant the very next frame overwrote it, which is
## why the giant and tiny mutators used to change what a body *hit* without
## changing what the player *saw*.
func _apply_scale() -> void:
	var value := body_scale()
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
	var s := body_scale()
	_visual.scale = Vector3(_squash.x * s, _squash.y * bob * s, _squash.z * s)
	# A heavy shove spins the body right round before it recovers.
	if _spin_time > 0.0:
		_visual.rotation.y += TAU * delta * 2.4
	if _stun > 0.0 or mods["frozen"] > 0.0:
		_visual.rotation.z = sin(Time.get_ticks_msec() * 0.05) * 0.12
	elif _edge_margin < 2.2 and is_on_floor():
		# Panic on the brink: lean away from the drop and shudder. It reads as
		# comedy and doubles as a warning that the player is one shove from out.
		var lean := (1.0 - clampf(_edge_margin / 2.2, 0.0, 1.0)) * 0.3
		_visual.rotation.z = lerp(_visual.rotation.z, sin(_fx_time * 26.0) * lean, clampf(12.0 * delta, 0.0, 1.0))
	else:
		_visual.rotation.z = lerp(_visual.rotation.z, 0.0, clampf(10.0 * delta, 0.0, 1.0))
	_update_state_fx(delta)
	_rig.tick(delta, {
		"speed": speed_ratio(),
		"on_floor": is_on_floor(),
		"attacking": _attack_time > 0.0,
		"dashing": _dash_time > 0.0,
		"hurt": _stun,
		"frozen": float(mods["frozen"]) > 0.0 or _shocked > 0.0,
		"panic": clampf(1.0 - _edge_margin / 2.6, 0.0, 1.0) if is_on_floor() else 0.0,
	})


## What is happening to this body, made visible. A power-up the player cannot
## see is a power-up they cannot play around, so every state that changes the
## physics gets a silhouette: a glow for strength, an ice shell for a freeze,
## sparks for a jolt, a weight above the head for a burden.
##
## The nodes hang off the fighter rather than off `_visual`, because `_visual`
## is squashed and stretched every frame and an aura that squashed with it
## would read as a bug.
func _update_state_fx(delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var frozen := float(mods["frozen"]) > 0.0
	var empowered: bool = float(mods["push"]) > 1.05 or float(mods["speed"]) > 1.05
	var burdened: bool = float(mods["weight"]) > 1.15 or float(mods["lag"]) > 0.0
	var sparking := _shocked > 0.0
	if _state_fx == null or not is_instance_valid(_state_fx):
		if not (frozen or empowered or burdened or sparking):
			return
		_build_state_fx()
	var aura := _state_fx.get_node_or_null("Aura") as Node3D
	var shell := _state_fx.get_node_or_null("IceShell") as Node3D
	var sparks := _state_fx.get_node_or_null("Sparks") as Node3D
	var mark := _state_fx.get_node_or_null("BurdenMark") as Node3D
	var s := body_scale()
	_state_fx.scale = Vector3.ONE * s
	if aura != null:
		aura.visible = empowered
		if empowered:
			aura.rotation.y += delta * 2.2
			var pulse := 1.0 + sin(_fx_time * 7.0) * 0.09
			aura.scale = Vector3(pulse, 1.0, pulse)
	if shell != null:
		shell.visible = frozen
	if sparks != null:
		sparks.visible = sparking
		if sparking:
			sparks.rotation.y += delta * 14.0
			sparks.position.y = 0.9 + sin(_fx_time * 33.0) * 0.06
	if mark != null:
		mark.visible = burdened
		if burdened:
			mark.position.y = 1.85 + sin(_fx_time * 3.4) * 0.07
			mark.rotation.y += delta * 1.4


func _build_state_fx() -> void:
	_state_fx = Node3D.new()
	_state_fx.name = "StateFX"
	add_child(_state_fx)
	var accent := data.accent if data != null else Color.WHITE

	var aura := MeshFactory.torus(0.62, 0.9, Color(1.0, 0.78, 0.35), 2.2)
	aura.name = "Aura"
	aura.position = Vector3(0, 0.55, 0)
	aura.visible = false
	_state_fx.add_child(aura)

	var shell := MeshFactory.sphere(0.72, Color(0.72, 0.94, 1.0))
	shell.name = "IceShell"
	shell.position = Vector3(0, 0.78, 0)
	shell.material_override = MeshFactory.ice(Color(0.7, 0.93, 1.0), 0.55)
	shell.visible = false
	_state_fx.add_child(shell)

	var sparks := Node3D.new()
	sparks.name = "Sparks"
	sparks.position = Vector3(0, 0.9, 0)
	sparks.visible = false
	for i in 5:
		var ang := TAU * float(i) / 5.0
		var bolt := MeshFactory.box(Vector3(0.07, 0.3, 0.07), Color(1.0, 0.93, 0.3), 2.6)
		bolt.position = Vector3(cos(ang) * 0.52, sin(float(i) * 1.7) * 0.2, sin(ang) * 0.52)
		bolt.rotation = Vector3(0.4 * sin(float(i)), ang, 0.5 * cos(float(i)))
		sparks.add_child(bolt)
	_state_fx.add_child(sparks)

	var mark := MeshFactory.box(Vector3(0.34, 0.26, 0.34), Color(0.36, 0.3, 0.24), 0.35)
	mark.name = "BurdenMark"
	mark.position = Vector3(0, 1.85, 0)
	mark.visible = false
	var handle := MeshFactory.torus(0.1, 0.16, accent)
	handle.position = Vector3(0, 0.2, 0)
	handle.rotation.x = PI * 0.5
	mark.add_child(handle)
	_state_fx.add_child(mark)


## Stick conditioning: the confusion and slowed-response power-downs act here
## rather than inside the input pipeline, so a replay still feeds the same
## recorded frames and reproduces the same match.
func _condition_wish(wish: Vector3, delta: float) -> Vector3:
	var scramble := float(mods["scramble"])
	if scramble > 0.0:
		# A drifting rotation, not an inversion: recoverable if the player reads
		# it, punishing if they keep pushing the direction they meant.
		wish = wish.rotated(Vector3.UP, sin(_fx_time * 1.35) * PI * scramble)
	var lag := float(mods["lag"])
	if lag <= 0.0:
		_wish_smooth = wish
		return wish
	_wish_smooth = _wish_smooth.lerp(wish, clampf(delta / maxf(lag, 0.001), 0.0, 1.0))
	return _wish_smooth


## Fed by the match layer every live tick; the fighter itself has no arena.
func set_edge_margin(value: float) -> void:
	_edge_margin = value


func set_surface_grip(value: float) -> void:
	surface_grip = clampf(value, 0.1, 2.0)


## Note a body-to-body contact for this tick. Both bodies usually report the
## same pair; the key collapses them into one entry, and nothing is applied
## until `resolve_impacts()` runs after every body has moved.
func _collect_body_contacts() -> void:
	if not ram_enabled or locomotion == Locomotion.DRIVE:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider() as Fighter
		if other == null or other == self or not other.alive:
			continue
		if other.locomotion == Locomotion.DRIVE:
			continue
		var normal := c.get_normal()
		normal.y = 0.0
		if normal.length_squared() < 0.01:
			continue
		var key := "%d:%d" % [mini(slot, other.slot), maxi(slot, other.slot)]
		if _contacts.has(key):
			continue
		# Store the pair low-slot-first with the normal pointing from a into b,
		# so the resolution has no idea which body reported it.
		var into := -normal.normalized()
		if slot <= other.slot:
			_contacts[key] = {"a": self, "b": other, "into": into}
		else:
			_contacts[key] = {"a": other, "b": self, "into": -into}


## Body-to-body impact — the spec's core verb. A fast body that runs into a
## slower one shoves it; two bodies closing on each other shove harder; a
## glancing contact deflects the victim diagonally instead of straight back.
##
## Called once per tick by the match layer, after every fighter has integrated
## and moved. Both halves of a pair are paid from the same closing speed,
## measured from the velocities the two bodies carried *into* the tick — which
## is what makes the exchange independent of the order the bodies were ticked
## in, and therefore of their slot numbers. Karts are excluded: Scrap Karts
## models chassis-vs-chassis with its own flank bonus, and running both would
## double every exchange in the derby.
static func resolve_impacts(delta: float) -> void:
	for key in _pair_cooldown.keys():
		var left := float(_pair_cooldown[key]) - delta
		if left <= 0.0:
			_pair_cooldown.erase(key)
		else:
			_pair_cooldown[key] = left
	for key in _contacts:
		var contact: Dictionary = _contacts[key]
		var a := contact["a"] as Fighter
		var b := contact["b"] as Fighter
		if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
			continue
		if not a.alive or not b.alive:
			continue
		if _pair_cooldown.has(key):
			continue
		if a.teammates.has(b.slot) or b.teammates.has(a.slot):
			continue
		var t: Dictionary = a._tuning
		var into: Vector3 = contact["into"]
		var relative: Vector3 = a._pre_vel - b._pre_vel
		relative.y = 0.0
		var closing := relative.dot(into)
		if closing < float(t.get("ram_min_speed", 4.4)):
			continue
		_pair_cooldown[key] = float(t.get("ram_cooldown", 0.32))
		var tangential := relative - into * closing
		a._deal_ram(b, into, closing, tangential, t)
		b._deal_ram(a, -into, closing, -tangential, t)


## Clears the shared contact state. Called when a match is built, so nothing
## survives from the previous one.
static func clear_impact_state() -> void:
	_contacts.clear()
	_pair_cooldown.clear()


## One half of an exchange: what *this* body's weight and strength do to the
## other. Mass ratio uses `knock_resist`, which is already the weight axis of a
## character, so the heavy/light contrast the roster is built on carries into
## rams for free.
func _deal_ram(victim: Fighter, into: Vector3, closing: float, tangential: Vector3, t: Dictionary) -> void:
	var my_mass := knock_resist * float(mods["weight"])
	var their_mass := maxf(0.3, victim.knock_resist * float(victim.mods["weight"]))
	# Narrow on purpose. Weight already buys resistance through `knock_resist`
	# in `take_hit`; letting it buy the same advantage again on the delivering
	# side compounds it, and the heavy characters started winning everywhere.
	var ratio := clampf(my_mass / their_mass, 0.78, 1.35)
	var strength := closing * float(t.get("ram_scale", 1.3)) * ratio \
		* knock_power * float(mods["push"])
	if is_dashing():
		strength *= float(t.get("ram_dash_bonus", 1.7))
	# Side contact keeps its tangential half, so a clip on the shoulder sends
	# the victim off at an angle — the difference between a shove and a
	# spin-out, and the reason a near-miss on the rim still kills.
	var dir := into
	if tangential.length() > 0.25:
		dir = (into + tangential.normalized() * float(t.get("ram_side_factor", 0.55))).normalized()
	victim.take_hit(slot, dir, strength, float(t.get("ram_damage", 4.0)))


## Snow kicked up by running and a wider spray while sliding sideways. Arctic
## only, throttled, and skipped entirely when effects are reduced — this is the
## kind of flourish that costs nothing to look at and everything to spam.
func _emit_ground_spray(delta: float) -> void:
	if _visual_theme != "arctic" or DisplayServer.get_name() == "headless":
		return
	if bool(UserSettings.get_value("reduce_effects")) or not is_on_floor():
		return
	_snow_timer -= delta
	if _snow_timer > 0.0:
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	if speed < 3.2:
		return
	# Sliding — moving one way while facing another — throws far more snow than
	# running straight, which is what sells the ice underfoot.
	var slide := 1.0 - clampf(absf(flat.normalized().dot(facing.normalized())), 0.0, 1.0)
	_snow_timer = lerpf(0.22, 0.09, clampf(slide + speed / maxf(top_speed, 0.1) - 1.0, 0.0, 1.0))
	var parent := get_parent()
	if parent == null:
		return
	var puff := MeshFactory.burst(Color(0.93, 0.98, 1.0), 3 + int(slide * 4.0), 1.5 + slide * 1.8, 0.35)
	parent.add_child(puff)
	puff.global_position = global_position + Vector3(0, 0.12, 0) - flat.normalized() * 0.35


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
