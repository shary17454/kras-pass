class_name ArenaHazards
extends RefCounted
## Moving arena furniture: sweepers, bumpers, the shrinking edge, rising water.
##
## Hazards are arena-owned, not game-owned, so any mini-game placed in an arena
## inherits its dangers. They are declared in `data/arenas.json` and never
## referenced by id from gameplay code.


class Sweeper extends Node3D:
	## A rotating arm that knocks anything it touches outward. The classic
	## party-game obstacle: readable, avoidable, and lethal if ignored.
	var speed := 1.0
	var length := 9.0
	var power := 15.0
	var accel_over_time := 0.06
	var _area: Area3D
	var _age := 0.0

	func build(color: Color, arm_length: float, arm_height: float) -> void:
		length = arm_length
		var arm := MeshFactory.box(Vector3(length, 0.45, 0.7), color, 0.5)
		arm.position = Vector3(length * 0.5, arm_height, 0)
		add_child(arm)
		var hub := MeshFactory.cylinder(0.6, arm_height * 1.6, color.darkened(0.3))
		hub.position = Vector3(0, arm_height * 0.5, 0)
		add_child(hub)
		_area = Area3D.new()
		_area.collision_layer = 8
		_area.collision_mask = 2
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(length, 0.9, 0.8)
		cs.shape = box
		cs.position = Vector3(length * 0.5, arm_height, 0)
		_area.add_child(cs)
		add_child(_area)

	## The rate the arm is turning *right now*, acceleration included. This is
	## what a player reads off the screen, so it is also what a bot is allowed
	## to use when judging whether the arm will reach it in time.
	func current_speed() -> float:
		return speed * (1.0 + _age * accel_over_time)

	func tick(delta: float) -> void:
		_age += delta
		rotate_y(current_speed() * delta)
		if _area == null:
			return
		for body in _area.get_overlapping_bodies():
			if body is Fighter and body.alive:
				var dir: Vector3 = body.global_position - global_position
				dir.y = 0.0
				if dir.length_squared() < 0.01:
					dir = Vector3.FORWARD
				# Push along the arm's tangent so the hit reads as "swept",
				# not "shoved from the centre".
				var tangent := global_transform.basis.z
				var push := (dir.normalized() * 0.55 + tangent.normalized() * 0.75).normalized()
				body.take_hit(-1, push, power, 0.0)


class Bumper extends Node3D:
	## Static post that flings anything touching it. Zero cooldown per victim
	## would machine-gun a cornered player, so each has a short refractory time.
	var power := 17.0
	var _area: Area3D
	var _cooldowns := {}
	var _mesh: Node3D

	func build(color: Color, radius: float) -> void:
		_mesh = MeshFactory.cylinder(radius, 1.5, color, 0.6)
		_mesh.position = Vector3(0, 0.75, 0)
		add_child(_mesh)
		var cap := MeshFactory.sphere(radius * 0.95, color.lightened(0.2), 0.9)
		cap.position = Vector3(0, 1.5, 0)
		add_child(cap)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = radius
		cyl.height = 1.6
		cs.shape = cyl
		cs.position = Vector3(0, 0.8, 0)
		body.add_child(cs)
		add_child(body)
		_area = Area3D.new()
		_area.collision_layer = 8
		_area.collision_mask = 2
		var acs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = radius + 0.55
		acs.shape = sph
		acs.position = Vector3(0, 0.8, 0)
		_area.add_child(acs)
		add_child(_area)

	func tick(delta: float) -> void:
		for k in _cooldowns.keys():
			_cooldowns[k] = float(_cooldowns[k]) - delta
			if float(_cooldowns[k]) <= 0.0:
				_cooldowns.erase(k)
		if _area == null:
			return
		for body in _area.get_overlapping_bodies():
			if not (body is Fighter) or not body.alive:
				continue
			if _cooldowns.has(body.slot):
				continue
			_cooldowns[body.slot] = 0.4
			var dir: Vector3 = body.global_position - global_position
			dir.y = 0.0
			body.take_hit(-1, dir.normalized(), power, 0.0, true)
			AudioManager.play_sfx("bounce", global_position)
			if _mesh != null and is_instance_valid(_mesh):
				var tw := _mesh.create_tween()
				tw.tween_property(_mesh, "scale", Vector3(1.25, 0.8, 1.25), 0.06)
				tw.tween_property(_mesh, "scale", Vector3.ONE, 0.18)


class RisingWater extends Node3D:
	## A plane that climbs and eliminates whoever it reaches. Drives Rising Tide
	## and doubles as the "floor is lava" primitive for future games.
	signal submerged(fighter)

	var speed := 0.4
	var level := -6.0
	var accel := 0.012
	var _mesh: MeshInstance3D
	var _age := 0.0
	var _hit := {}

	func build(color: Color, radius: float, start_y: float) -> void:
		level = start_y
		_mesh = MeshFactory.plane(Vector2(radius * 3.0, radius * 3.0), color)
		_mesh.material_override = MeshFactory.transparent(color, 0.55)
		add_child(_mesh)
		position.y = level

	func tick(delta: float) -> void:
		_age += delta
		level += (speed + _age * accel) * delta
		position.y = level
		if _mesh != null and is_instance_valid(_mesh):
			_mesh.position.y = sin(_age * 2.0) * 0.08

	func check(fighters: Array) -> void:
		for f in fighters:
			if f == null or not is_instance_valid(f) or not f.alive:
				continue
			if f.global_position.y < level and not _hit.has(f.slot):
				_hit[f.slot] = true
				submerged.emit(f)

	func reset(start_y: float) -> void:
		level = start_y
		_age = 0.0
		_hit.clear()
		position.y = level


class ShrinkRing extends Node3D:
	## Progressive arena shrink. Rather than deleting geometry it scales the
	## visible ring and reports the live radius; the arena's `is_inside()` and
	## the fall check do the rest, so every push-out game shrinks for free.
	signal radius_changed(r: float)

	var start_delay := 18.0
	var rate := 0.3
	var min_radius := 5.0
	var radius := 12.0
	var _base_radius := 12.0
	var _elapsed := 0.0
	var _ring: MeshInstance3D

	func build(color: Color, r: float) -> void:
		_base_radius = r
		radius = r
		_ring = MeshFactory.torus(r - 0.45, r + 0.15, color, 0.9)
		_ring.position = Vector3(0, 0.12, 0)
		add_child(_ring)

	func tick(delta: float) -> void:
		_elapsed += delta
		if _elapsed < start_delay or radius <= min_radius:
			return
		var before := radius
		radius = maxf(min_radius, radius - rate * delta)
		if not is_equal_approx(before, radius):
			var k := radius / maxf(_base_radius, 0.001)
			if _ring != null and is_instance_valid(_ring):
				_ring.scale = Vector3(k, 1.0, k)
			radius_changed.emit(radius)

	func reset() -> void:
		_elapsed = 0.0
		radius = _base_radius
		if _ring != null and is_instance_valid(_ring):
			_ring.scale = Vector3.ONE
		radius_changed.emit(radius)
