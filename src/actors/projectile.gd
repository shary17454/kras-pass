class_name Projectile
extends Area3D
## Pooled shot used by the vehicle games.
##
## Travels in a straight line, expires on range or on hitting a fighter or a
## wall. Wall hits use a short raycast rather than a physics body so a shot can
## never tunnel through a pillar at high speed.

signal hit_fighter(projectile: Projectile, shooter: int, victim: int)
signal expired(projectile: Projectile)

var shooter := -1
var speed := 24.0
var damage := 14.0
var knockback := 9.0
var range_left := 26.0
var direction := Vector3.FORWARD
var active := false
## Optional guidance. Zero turn rate is a dumb shot and is the default, so the
## games that fire straight are unaffected by this existing at all.
var homing_slot := -1
var turn_rate := 0.0
## When true the shot reports the hit and applies nothing itself. A game whose
## weapons have one designed reaction needs that reaction to be the *only* one:
## `Fighter.take_hit` runs before `hit_fighter` is emitted, so a listener that
## checks its own shield is deciding after the generic knockback, stun and
## hitstop have already landed. Off by default; the games that want the built-in
## hit keep it.
var notify_only := false
var _ctx: MatchContext

var _mesh: Node3D


func _init() -> void:
	collision_layer = 32
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.45
	cs.shape = s
	add_child(cs)


func configure(color: Color) -> void:
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.queue_free()
	_mesh = Node3D.new()
	add_child(_mesh)
	var core := MeshFactory.sphere(0.26, color, 2.0)
	_mesh.add_child(core)
	var tail := MeshFactory.box(Vector3(0.16, 0.16, 0.9), color, 1.4)
	tail.position = Vector3(0, 0, 0.5)
	_mesh.add_child(tail)


func fire(from: Vector3, dir: Vector3, by_slot: int, shot_speed: float, shot_damage: float, max_range: float) -> void:
	global_position = from
	direction = dir.normalized()
	shooter = by_slot
	speed = shot_speed
	damage = shot_damage
	range_left = max_range
	active = true
	visible = true
	homing_slot = -1
	turn_rate = 0.0
	notify_only = false
	set_deferred("monitoring", true)
	look_at(from + direction, Vector3.UP)


## Give the shot a target. Called after `fire`, so an unguided shot never pays
## for the lookup.
func guide(context: MatchContext, target_slot: int, rate: float) -> void:
	_ctx = context
	homing_slot = target_slot
	turn_rate = rate


func tick(delta: float) -> void:
	if not active:
		return
	if turn_rate > 0.0 and homing_slot >= 0 and _ctx != null:
		var target := _ctx.fighter(homing_slot)
		if target != null and is_instance_valid(target) and target.alive:
			var want := (target.global_position + Vector3(0, 0.7, 0) - global_position)
			if want.length_squared() > 0.01:
				# Rotate toward the target rather than snapping: a shot that
				# turns instantly is unavoidable, which is not a weapon, it is
				# a punishment.
				direction = direction.slerp(want.normalized(), clampf(turn_rate * delta, 0.0, 1.0)).normalized()
				look_at(global_position + direction, Vector3.UP)
		else:
			turn_rate = 0.0
	var step := speed * delta
	range_left -= step
	if range_left <= 0.0:
		_expire()
		return
	# Sweep for walls so a fast shot cannot pass through a pillar between ticks.
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + direction * step)
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		AudioManager.play_sfx("bounce", global_position, 0.7)
		_expire()
		return
	global_position += direction * step
	if not is_monitoring():
		return
	for body in get_overlapping_bodies():
		if body is Fighter and body.alive and body.slot != shooter:
			if not notify_only:
				body.take_hit(shooter, direction, knockback, damage)
			hit_fighter.emit(self, shooter, body.slot)
			_expire()
			return


func _expire() -> void:
	active = false
	set_deferred("monitoring", false)
	visible = false
	expired.emit(self)


func on_acquired() -> void:
	active = true
	visible = true
	set_deferred("monitoring", true)


func on_released() -> void:
	active = false
	visible = false
	homing_slot = -1
	turn_rate = 0.0
	notify_only = false
	_ctx = null
	set_deferred("monitoring", false)
