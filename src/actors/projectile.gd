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
	set_deferred("monitoring", true)
	look_at(from + direction, Vector3.UP)


func tick(delta: float) -> void:
	if not active:
		return
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
	set_deferred("monitoring", false)
