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


class BreakableIceBarrier extends StaticBody3D:
	## A rim chunk that guards the edge until it is broken through.
	##
	## The spec wants these to take damage and crack progressively rather than
	## pop on contact — which is also what makes them a mechanic: for the first
	## half of a round the rim is protected, and every exchange near the edge
	## spends a little of that protection, so the arena gets more lethal as the
	## match goes on. Leaning on a barrier costs nothing; charging it costs a
	## crack, and a dash costs two.
	var broken := false
	var strength := 3
	var _hp := 3
	var _size := 1.0
	var _base_color := Color.WHITE
	var _area: Area3D
	var _solid_shape: CollisionShape3D
	var _visual: Node3D
	var _cracks: Node3D
	var _cooldown := 0.0
	var _break_tween: Tween

	func build(size: float, color: Color) -> void:
		collision_layer = 1
		collision_mask = 0
		_size = size
		_base_color = color
		_hp = strength
		_visual = MeshFactory.ice_chunk(size, color)
		add_child(_visual)
		_cracks = Node3D.new()
		_cracks.name = "Cracks"
		_visual.add_child(_cracks)

		_solid_shape = CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size * 1.55, size * 0.72, size * 0.92)
		_solid_shape.shape = box
		_solid_shape.position = Vector3(0, size * 0.34, 0)
		add_child(_solid_shape)

		_area = Area3D.new()
		_area.collision_layer = 8
		_area.collision_mask = 2
		var acs := CollisionShape3D.new()
		var area_box := BoxShape3D.new()
		area_box.size = Vector3(size * 1.9, size * 1.05, size * 1.35)
		acs.shape = area_box
		acs.position = Vector3(0, size * 0.45, 0)
		_area.add_child(acs)
		add_child(_area)

	func tick(delta: float) -> void:
		if broken:
			return
		_cooldown = maxf(0.0, _cooldown - delta)
		if _cooldown > 0.0 or _area == null:
			return
		for body in _area.get_overlapping_bodies():
			if not (body is Fighter) or not body.alive:
				continue
			var fighter: Fighter = body
			# A contact costs a crack; a charge costs two. The predicate is
			# deliberately coarse: physics is not bit-exact between a recorded
			# match and its replay, and a fine speed threshold right where
			# bodies actually travel flips on a rounding difference — one
			# barrier standing instead of broken diverged a replay by four
			# metres and a whole point. Standing speeds cluster near zero and
			# playing speeds near seven, so a gate at 1.2 is almost never
			# straddled, and the 1-vs-2 split can only shift a break by a
			# contact rather than deciding whether it ever happens.
			if fighter.impact_speed < 1.2:
				continue
			var damage := 2 if (fighter.is_dashing() or fighter.impact_speed >= 5.6) else 1
			_cooldown = 0.55
			_hp -= damage
			if _hp <= 0:
				_break(fighter)
			else:
				_crack(fighter)
			return

	## Damaged but standing: a fracture appears, the chunk rings, and the
	## fighter gets a small shove back so a wall hit reads as a hit.
	func _crack(fighter: Fighter) -> void:
		var away := fighter.global_position - global_position
		away.y = 0.0
		if away.length_squared() > 0.01:
			fighter.apply_impulse(away.normalized() * 1.6)
		AudioManager.play_sfx("ice_crack", global_position, 1.0 + 0.12 * float(strength - _hp))
		InputRouter.rumble(fighter.slot, 0.3, 0.1)
		if _visual == null or not is_instance_valid(_visual):
			return
		# Paler and more fractured with every hit, so the state of the rim is
		# readable at a glance from the arena camera.
		var wear := 1.0 - float(_hp) / float(maxi(strength, 1))
		if _cracks != null and is_instance_valid(_cracks):
			var line := MeshFactory.box(Vector3(_size * 1.5, 0.03, 0.04),
				Color(0.3, 0.52, 0.68))
			line.position = Vector3(0, _size * (0.15 + 0.25 * wear), _size * 0.42)
			line.rotation = Vector3(0, 0.4 * wear - 0.2, 0.35 * sin(wear * 6.0))
			line.material_override = MeshFactory.transparent(Color(0.22, 0.45, 0.62), 0.75)
			_cracks.add_child(line)
		var tween := _visual.create_tween()
		tween.tween_property(_visual, "scale", Vector3(1.0 + 0.12 * wear, 1.0 - 0.1 * wear, 1.0), 0.07)
		tween.tween_property(_visual, "scale", Vector3.ONE, 0.14)
		if not DisplayServer.get_name() == "headless":
			add_child(MeshFactory.burst(Color(0.8, 0.95, 1.0), 5, 1.6, 0.3))

	func _break(fighter: Fighter) -> void:
		broken = true
		collision_layer = 0
		collision_mask = 0
		for child in get_children():
			if child is CollisionShape3D:
				child.disabled = true
		if _area != null and is_instance_valid(_area):
			_area.monitoring = false
		var away := fighter.global_position - global_position
		away.y = 0.0
		if away.length_squared() < 0.05:
			away = Vector3(global_position.x, 0, global_position.z)
		fighter.apply_impulse(away.normalized() * 2.4)
		AudioManager.play_sfx("crate_break", global_position, 0.75)
		add_child(MeshFactory.burst(Color(0.78, 0.94, 1.0), 14, 2.8, 0.45))
		if _visual != null and is_instance_valid(_visual):
			_break_tween = _visual.create_tween()
			_break_tween.tween_property(_visual, "scale", Vector3(1.18, 0.55, 1.18), 0.06)
			_break_tween.tween_property(_visual, "scale", Vector3.ZERO, 0.18)
			_break_tween.tween_callback(_visual.hide)

	func reset() -> void:
		broken = false
		_hp = strength
		if _cracks != null and is_instance_valid(_cracks):
			for c in _cracks.get_children():
				c.queue_free()
		_cooldown = 0.18
		collision_layer = 1
		collision_mask = 0
		if _solid_shape != null and is_instance_valid(_solid_shape):
			_solid_shape.disabled = false
		if _area != null and is_instance_valid(_area):
			_area.monitoring = true
		if _break_tween != null and _break_tween.is_valid():
			_break_tween.kill()
		if _visual != null and is_instance_valid(_visual):
			_visual.show()
			_visual.scale = Vector3.ONE


class Snowball extends Node3D:
	## A boulder of packed snow that rolls a chord across the arena and flattens
	## whoever it meets.
	##
	## The spec lists rolling hazards among the things an arena should throw at
	## the players. Unlike the sweeper — which pivots around the middle and is
	## therefore always the same threat — this crosses, so where it is safe
	## changes every pass, and the safe side is readable a second before it
	## arrives.
	##
	## Deterministic by construction: entry angles advance by a fixed irrational
	## step rather than being drawn, so no generator is consumed and a replay
	## rolls the same boulders down the same lines.

	const ANGLE_STEP := 2.39996323   # golden angle, so passes never repeat a lane

	var speed := 9.0
	var power := 18.0
	var radius := 1.15
	var arena_radius := 12.0
	var period := 6.0

	var _dir := Vector3.FORWARD
	var _timer := 0.0
	var _rolling := false
	var _angle := 0.0
	var _mesh: Node3D
	var _hit := {}

	func build(color: Color, r: float, arena_r: float) -> void:
		radius = r
		arena_radius = arena_r
		_mesh = MeshFactory.sphere(radius, color, 0.06)
		_mesh.material_override = MeshFactory.ice(color, 0.99)
		add_child(_mesh)
		visible = false
		_timer = period * 0.5

	func tick(delta: float) -> void:
		if not _rolling:
			_timer -= delta
			if _timer <= 0.0:
				_launch()
			return
		position += _dir * speed * delta
		if _mesh != null and is_instance_valid(_mesh):
			# Rolling, not sliding: the spin matches the travel so it reads as
			# weight rather than as a floating ball.
			_mesh.rotate(_dir.cross(Vector3.UP).normalized(), -speed / maxf(radius, 0.1) * delta)
		_check_fighters()
		if position.length() > arena_radius * 1.25:
			_rolling = false
			visible = false
			_timer = period

	func _launch() -> void:
		_angle += ANGLE_STEP
		var entry := Vector3(cos(_angle), 0.0, sin(_angle)) * arena_radius * 1.15
		# A chord, not a diameter: offset the exit so the line across the arena
		# is different every pass.
		var exit_ang := _angle + PI + sin(_angle * 3.0) * 0.7
		var exit := Vector3(cos(exit_ang), 0.0, sin(exit_ang)) * arena_radius * 1.15
		position = Vector3(entry.x, radius * 0.75, entry.z)
		_dir = (exit - entry).normalized()
		_rolling = true
		visible = true
		_hit.clear()
		AudioManager.play_sfx("rumble", position, 1.0)

	func _check_fighters() -> void:
		var tree := get_tree()
		if tree == null:
			return
		for body in tree.get_nodes_in_group("fighters"):
			var f := body as Fighter
			if f == null or not f.alive or _hit.has(f.slot):
				continue
			var to: Vector3 = f.global_position - global_position
			to.y = 0.0
			if to.length() > radius + 0.7:
				continue
			_hit[f.slot] = true
			# Pushed along the roll, not away from the centre of the ball: a
			# boulder shoves you where it is going.
			f.take_hit(-1, _dir, power, 6.0)
			AudioManager.play_sfx("hit", f.global_position)

	func reset() -> void:
		_rolling = false
		visible = false
		_timer = period * 0.5
		_hit.clear()


class Gust extends Node3D:
	## A wind that leans on the whole arena at once.
	##
	## Every other hazard here is local — you can stand somewhere else. A gust
	## cannot be avoided, only braced against, which is why it is telegraphed
	## for a full second and a half and why it pushes rather than launches: it
	## turns a fight near the rim into a decision instead of a coin flip.

	const ANGLE_STEP := 1.7

	var period := 13.0
	var warn := 1.6
	var duration := 2.8
	var force := 7.0
	var arena_radius := 12.0

	var _dir := Vector3.FORWARD
	var _timer := 0.0
	var _state := 0            # 0 idle, 1 warning, 2 blowing
	var _angle := 0.0
	var _streaks: Array = []

	func build(color: Color, arena_r: float) -> void:
		arena_radius = arena_r
		_timer = period
		# Long, low and dense. The first pass drew fourteen short slivers spread
		# over the whole sky, which from the arena camera read as more of the
		# scratch decor already on the ice rather than as wind — a hazard the
		# player cannot see coming is just an unexplained shove.
		var count := 26
		for i in count:
			var streak := MeshFactory.box(Vector3(4.5 + 2.2 * float(i % 3), 0.07, 0.13), color.lightened(0.45), 0.9)
			streak.material_override = MeshFactory.transparent(color.lightened(0.55), 0.7)
			streak.visible = false
			add_child(streak)
			_streaks.append({"node": streak, "offset": float(i) / float(count)})

	func tick(delta: float) -> void:
		_timer -= delta
		match _state:
			0:
				if _timer <= 0.0:
					_begin_warning()
			1:
				_animate(delta, 0.45)
				if _timer <= 0.0:
					_state = 2
					_timer = duration
					AudioManager.play_sfx("gust", global_position)
			2:
				_animate(delta, 1.0)
				_push(delta)
				if _timer <= 0.0:
					_end()

	func _begin_warning() -> void:
		_state = 1
		_timer = warn
		_angle += ANGLE_STEP
		_dir = Vector3(cos(_angle), 0.0, sin(_angle))
		AudioManager.play_sfx("machine_alert", global_position, 0.7)
		for entry in _streaks:
			var node: Node3D = entry["node"]
			if is_instance_valid(node):
				node.visible = true

	func _animate(delta: float, strength: float) -> void:
		var across: Vector3 = _dir.cross(Vector3.UP).normalized()
		for entry in _streaks:
			var node: Node3D = entry["node"]
			if not is_instance_valid(node):
				continue
			var offset := float(entry["offset"])
			entry["offset"] = fmod(offset + delta * 0.55 * strength, 1.0)
			var along: float = lerpf(-arena_radius * 1.15, arena_radius * 1.15, float(entry["offset"]))
			# Spread across the deck, not across the sky, and low enough to read
			# against the ice.
			var side: float = (fmod(offset * 7.0, 1.0) - 0.5) * arena_radius * 1.7
			node.position = _dir * along + across * side + Vector3(0, 0.45 + 0.55 * fmod(offset * 3.0, 1.0), 0)
			node.rotation.y = -atan2(_dir.z, _dir.x)
			node.scale.x = 0.6 + strength

	func _push(delta: float) -> void:
		var tree := get_tree()
		if tree == null:
			return
		for body in tree.get_nodes_in_group("fighters"):
			var f := body as Fighter
			if f == null or not f.alive:
				continue
			# Through the impulse channel, not straight onto velocity. A walking
			# body re-solves its velocity toward the stick every frame with
			# `move_toward` at 38 m/s^2 or more, so anything written onto
			# `velocity` here is erased before it is felt — the wind would be a
			# visual with no push behind it. `_impulse` is added *after* that
			# integration and drains on its own clock, which is what makes this
			# something you lean against for three seconds.
			f.apply_impulse(_dir * force * delta)

	func _end() -> void:
		_state = 0
		_timer = period
		for entry in _streaks:
			var node: Node3D = entry["node"]
			if is_instance_valid(node):
				node.visible = false

	func reset() -> void:
		_end()


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
