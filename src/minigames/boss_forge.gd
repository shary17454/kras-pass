extends "res://src/minigames/boss_controller.gd"
## Boss 1 — The Forge Warden.
##
## A furnace on legs that will not be touched: its shell is armoured, and the
## only thing that hurts it is its own ordnance. It lobs iron crates across the
## arena; smash one and the slag inside stays hot for a few seconds, and a
## fighter who shoves that glowing slug into the Warden's intake takes a bite
## out of it. So the fight is a fetch loop with a timer, run by four people who
## all want the last hit.

const CRATE_PERIOD := 3.6
const SLAG_LIFE := 6.0
const SLAG_DAMAGE := 120.0
const STOMP_PERIOD := 5.0

var _crate_timer := 2.0
var _stomp_timer := STOMP_PERIOD
var _crates: Array = []
var _slag: Array = []
var _intake: Node3D


func boss_build() -> void:
	boss_max_health = 900.0
	boss_health = 900.0
	var body := MeshFactory.cylinder(2.6, 4.0, Color("#6b5344"), 0.25)
	body.position.y = 2.0
	boss_node.add_child(body)
	var cap := MeshFactory.cone(2.9, 1.6, Color("#8a6a52"))
	cap.position.y = 4.6
	boss_node.add_child(cap)
	# The intake glows: it is the only place a hit lands, so it has to read as
	# a target from across the arena and from any angle.
	_intake = MeshFactory.torus(1.1, 1.6, Color("#ff8a3d"), 2.4)
	_intake.position.y = 1.5
	_intake.rotation.x = PI * 0.5
	boss_node.add_child(_intake)


func boss_think(delta: float) -> void:
	if _intake != null and is_instance_valid(_intake):
		_intake.rotate_z(1.2 * delta)
	_crate_timer -= delta
	if _crate_timer <= 0.0:
		_crate_timer = CRATE_PERIOD * (1.0 if phase == 0 else 0.75)
		_lob_crate()
	_stomp_timer -= delta
	if _stomp_timer <= 0.0:
		_stomp_timer = STOMP_PERIOD * (1.0 if phase == 0 else 0.72)
		_stomp()
	_tick_slag(delta)
	_check_feeding()


func _lob_crate() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.add_child(MeshFactory.crate(1.4, Color("#7d6a55"), Color("#ff8a3d")))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.4, 1.4)
	cs.shape = box
	body.add_child(cs)
	ctx.world_root.add_child(body)
	var ang := ctx.rng.randf() * TAU
	var r := lerpf(4.0, arena.current_radius * 0.8, ctx.rng.randf())
	body.global_position = arena.global_position + Vector3(cos(ang) * r, 0.7, sin(ang) * r)
	body.add_to_group("crates")
	_crates.append(body)
	AudioManager.play_sfx("crate_break", body.global_position, 0.7)


func _stomp() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	# Aim where somebody is, not at random: a boss that never threatens anyone
	# is scenery. The warning is long enough to walk out of.
	var targets: Array[int] = []
	for i in ctx.fighters.size():
		if ctx.is_alive(i):
			targets.append(i)
	if targets.is_empty():
		return
	var pick: int = targets[ctx.rng.randi_range(0, targets.size() - 1)]
	var f := ctx.fighter(pick)
	if f == null or not is_instance_valid(f):
		return
	telegraph(f.global_position, 3.4, 1.3 if phase == 0 else 1.0,
		func(pos: Vector3, radius: float): strike(pos, radius, 26.0))


## Smashing a crate leaves slag. Slag cools, and cold slag is worthless.
func _check_feeding() -> void:
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f) or not f.is_attacking():
			continue
		var idx := _crates.size() - 1
		while idx >= 0:
			var c = _crates[idx]
			if not is_instance_valid(c):
				_crates.remove_at(idx)
				idx -= 1
				continue
			if in_reach(f, c.global_position, 0.6):
				_spawn_slag(c.global_position, i)
				_crates.remove_at(idx)
				c.queue_free()
				break
			idx -= 1


func _spawn_slag(pos: Vector3, by: int) -> void:
	var node := MeshFactory.sphere(0.6, Color("#ff8a3d"), 2.6)
	node.position = pos
	ctx.world_root.add_child(node)
	_slag.append({"node": node, "life": SLAG_LIFE, "vel": Vector3.ZERO, "by": by})
	AudioManager.play_sfx("crate_break", pos)


func _tick_slag(delta: float) -> void:
	var idx := _slag.size() - 1
	while idx >= 0:
		var s = _slag[idx]
		var node: Node3D = s["node"]
		if not is_instance_valid(node):
			_slag.remove_at(idx)
			idx -= 1
			continue
		s["life"] = float(s["life"]) - delta
		var t: float = clampf(float(s["life"]) / SLAG_LIFE, 0.0, 1.0)
		node.scale = Vector3.ONE * (0.5 + 0.5 * t)
		if float(s["life"]) <= 0.0:
			_slag.remove_at(idx)
			node.queue_free()
			idx -= 1
			continue
		# A shove sends it rolling; whoever shoved it last owns the hit.
		for i in ctx.fighters.size():
			if not ctx.is_alive(i):
				continue
			var f := ctx.fighter(i)
			if f == null or not is_instance_valid(f):
				continue
			var to: Vector3 = node.global_position - f.global_position
			to.y = 0.0
			if to.length() < 1.3 and f.is_attacking():
				s["vel"] = to.normalized() * 16.0
				s["by"] = i
		var vel: Vector3 = s["vel"]
		if vel.length_squared() > 0.01:
			node.global_position += vel * delta
			s["vel"] = vel.move_toward(Vector3.ZERO, 11.0 * delta)
		var intake_flat := Vector3(_intake.global_position.x, node.global_position.y,
			_intake.global_position.z) if _intake != null and is_instance_valid(_intake) else Vector3.INF
		if intake_flat != Vector3.INF and node.global_position.distance_to(intake_flat) < 2.6:
			damage_boss(SLAG_DAMAGE * t, int(s["by"]))
			_slag.remove_at(idx)
			node.queue_free()
		idx -= 1


func on_phase_changed(_new_phase: int) -> void:
	# It gets angry, and it says so: an immediate stomp under everyone.
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f != null and is_instance_valid(f):
			telegraph(f.global_position, 3.0, 1.1,
				func(pos: Vector3, radius: float): strike(pos, radius, 22.0))


## Bots go for hot slag first, then crates to make more of it.
func weak_points() -> Array:
	var out: Array = []
	for s in _slag:
		if is_instance_valid(s["node"]):
			out.append(s["node"].global_position)
	if out.is_empty():
		for c in _crates:
			if is_instance_valid(c):
				out.append(c.global_position)
	return out


func cleanup() -> void:
	super.cleanup()
	for c in _crates:
		if is_instance_valid(c):
			c.queue_free()
	_crates.clear()
	for s in _slag:
		if is_instance_valid(s["node"]):
			s["node"].queue_free()
	_slag.clear()
