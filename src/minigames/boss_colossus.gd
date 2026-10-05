extends "res://src/minigames/boss_controller.gd"
## Boss 2 — The Colossus.
##
## A giant that fights the way a push-out arena fights: it does not want your
## health, it wants you off the edge. It sweeps an arm across the ring, slams
## craters into the floor that never repair, and shrinks the world one tile at
## a time. It has no soft spot to shoot — the only thing that hurts it is its
## own arm, which buries itself in the floor after a slam and lies exposed for
## a moment. Greed is the whole fight: the safe play is to stay clear, and the
## safe play scores nothing.

const SLAM_PERIOD := 4.4
const SWEEP_PERIOD := 7.0
const ARM_DAMAGE := 55.0
## Carved craters require an approach around the rim, not through the fist.
## This window includes that travel while retaining one hit per player.
const EXPOSED_TIME := 2.4
## One strike per exposure, so the reward is arriving, not standing there.
const HIT_PER_WINDOW := true

var _slam_timer := 2.5
var _sweep_timer := SWEEP_PERIOD
var _exposed := 0.0
var _arm: Node3D
var _fist: Node3D
var _craters: Array = []
var _hit_this_window := {}


func boss_build() -> void:
	boss_max_health = 800.0
	boss_health = 800.0
	var arena := ctx.arena as Arena
	if arena != null:
		boss_node.global_position = arena.global_position + Vector3(0, 0.0, 0)
		arena.enable_crater_floor()
	var torso := MeshFactory.cylinder(3.2, 6.0, Color("#4a5a72"), 0.2)
	torso.position.y = 3.0
	boss_node.add_child(torso)
	var head := MeshFactory.sphere(1.8, Color("#5f7290"), 0.4)
	head.position.y = 7.0
	boss_node.add_child(head)
	_arm = Node3D.new()
	_arm.position.y = 4.6
	boss_node.add_child(_arm)
	var upper := MeshFactory.box(Vector3(9.0, 0.9, 0.9), Color("#5f7290"), 0.3)
	upper.position.x = 4.5
	_arm.add_child(upper)
	_fist = MeshFactory.sphere(1.5, Color("#8fa4c4"), 0.5)
	_fist.position.x = 9.2
	_arm.add_child(_fist)


func boss_think(delta: float) -> void:
	if presentation_only: return
	if _exposed > 0.0:
		_exposed -= delta
		if _fist != null and is_instance_valid(_fist):
			# Exposed fist glows: the invitation has to be unmistakable.
			_fist.scale = Vector3.ONE * (1.0 + 0.18 * sin(_exposed * 14.0))
		if _exposed <= 0.0:
			_hit_this_window.clear()
			if _fist != null and is_instance_valid(_fist):
				_fist.scale = Vector3.ONE
				_fist.position = Vector3(9.2, 0, 0)
		else:
			_check_arm_hits()
			return
	_slam_timer -= delta
	if _slam_timer <= 0.0:
		_slam_timer = SLAM_PERIOD * (1.0 if phase == 0 else (0.8 if phase == 1 else 0.62))
		_slam()
	_sweep_timer -= delta
	if _sweep_timer <= 0.0:
		_sweep_timer = SWEEP_PERIOD * (1.0 if phase < 2 else 0.7)
		_sweep()
	if _arm != null and is_instance_valid(_arm):
		_arm.rotate_y(0.6 * delta)


func _slam() -> void:
	if presentation_only: return
	var target := _pick_target()
	if target == Vector3.INF:
		return
	telegraph(target, 4.0, 1.15 if phase == 0 else 0.85, func(pos: Vector3, radius: float):
		strike(pos, radius, 34.0)
		_open_crater(pos, radius)
		# The fist stays buried where it landed: that is the window.
		if _arm != null and is_instance_valid(_arm) and boss_node != null:
			var to: Vector3 = pos - boss_node.global_position
			_arm.rotation.y = atan2(to.z, to.x) * -1.0
		# The fist stays where it landed, at floor level: it has to be somewhere
		# a fighter can actually stand next to, not four metres overhead.
		if _fist != null and is_instance_valid(_fist):
			_fist.global_position = pos + Vector3.UP
		_exposed = EXPOSED_TIME
		_hit_this_window.clear())


## A slam takes floor away permanently, so the ring closes as the fight runs.
func _open_crater(pos: Vector3, radius: float) -> void:
	if presentation_only: return
	var arena := ctx.arena as Arena
	if arena == null:
		return
	var hole := MeshFactory.torus(radius * 0.75 - 0.15, radius * 0.75, Color("#161a2c"), 0.0)
	hole.position = pos + Vector3(0, 0.1, 0)
	ctx.world_root.add_child(hole)
	_craters.append({"node": hole, "pos": pos, "radius": radius * 0.75})
	arena.open_crater(pos, radius * 0.75)


func _sweep() -> void:
	if presentation_only: return
	var arena := ctx.arena as Arena
	if arena == null:
		return
	# A ring of warnings at arm's length: the safe ground is close in or far
	# out, and choosing wrong is the mistake, not being unlucky.
	var r := arena.current_radius * 0.62
	for i in 8:
		var ang := TAU * float(i) / 8.0 + ctx.rng.randf() * 0.3
		var pos := arena.global_position + Vector3(cos(ang) * r, 0, sin(ang) * r)
		telegraph(pos, 3.0, 1.5, func(p: Vector3, rad: float): strike(p, rad, 30.0))


func _check_arm_hits() -> void:
	if presentation_only: return
	if _fist == null or not is_instance_valid(_fist):
		return
	for i in ctx.fighters.size():
		if not ctx.is_alive(i) or _hit_this_window.has(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f) or not f.is_attacking():
			continue
		if not in_reach(f, _fist.global_position, 1.6):
			continue
		_hit_this_window[i] = true
		damage_boss(ARM_DAMAGE, i)


## Random among the living, deliberately. Hunting the damage leader was tried
## and measured worse (0.46 against 0.45): it is a rubber band, and a rubber
## band suppresses exactly the score spread a difficulty tier is supposed to
## produce. Note for whoever tunes this next — the bot tiers do not separate
## cleanly here (0.45-0.49 against a 0.52 bar) no matter how the window is
## sized, because the fist lands beside somebody and that somebody swings.
## Making the opening contestable by everyone, rather than delivered to one
## player, is the change this fight still wants.
func _pick_target() -> Vector3:
	if presentation_only: return Vector3.INF
	var alive: Array[int] = []
	var arena := ctx.arena as Arena
	for i in ctx.fighters.size():
		var fighter := ctx.fighter(i)
		# Match-alive slots can still be falling or waiting at the respawn pose.
		# A fist outside real ground creates an opening nobody can reach.
		if ctx.is_alive(i) and is_instance_valid(fighter) and fighter.alive and fighter.visible \
			and arena != null and fighter.global_position.is_finite() \
			and fighter.global_position.y >= arena.global_position.y - 0.5 \
			and arena.is_inside(fighter.global_position, 0.5):
			alive.append(i)
	if alive.is_empty():
		return Vector3.INF
	var f := ctx.fighter(alive[ctx.rng.randi_range(0, alive.size() - 1)])
	return Vector3(f.global_position.x, arena.global_position.y, f.global_position.z)


func on_phase_changed(new_phase: int) -> void:
	if presentation_only: return
	if new_phase >= 2:
		_sweep()


## Only worth approaching while the fist is down.
func weak_points() -> Array:
	if _exposed > 0.0 and _fist != null and is_instance_valid(_fist):
		return [_fist.global_position]
	return []


func weak_point_nodes() -> Array:
	return [_fist] if _exposed > 0.0 and is_instance_valid(_fist) else []


func staging_point(heading: float) -> Vector3:
	var arena := ctx.arena as Arena
	if arena == null:
		return ctx.arena_center()
	# Spread participants around the middle without anticipating a future slam.
	var radius := minf(5.0, arena.current_radius * 0.35)
	var point := arena.global_position + Vector3(cos(heading), 0.0, sin(heading)) * radius
	return arena.retreat_point(point)


func attack_plan(from: Vector3, observed_spots: Variant = null) -> Dictionary:
	var spots: Array = weak_points() if observed_spots == null else observed_spots
	var arena := ctx.arena as Arena
	if spots.is_empty() or arena == null:
		return {}
	var point: Vector3 = spots[0]
	var best := Vector3.INF
	var distance := INF
	# All inputs are visible: the exposed fist and the carved arena surface.
	for step in 64:
		var angle := TAU * float(step) / 64.0
		var candidate := point + Vector3(cos(angle), 0, sin(angle)) * 3.55
		candidate.y = from.y
		if arena.is_inside(candidate, 0.5):
			var d := candidate.distance_squared_to(from)
			if d < distance:
				distance = d
				best = candidate
	if best == Vector3.INF:
		return {}
	var offset := point - from
	offset.y = 0.0
	return {"target": best, "attack": arena.is_inside(from, 0.5) and absf(point.y - from.y) <= 5.5 and offset.length() <= Balance.num("tuning", "fighter.attack_range", 2.15) + 1.6}


func danger_zones() -> Array:
	var out: Array = super.danger_zones()
	# Craters are permanent holes, so they are danger too — treat them as
	# warnings that never expire.
	for c in _craters:
		out.append({"node": c["node"], "pos": c["pos"], "radius": float(c["radius"]), "left": 99.0, "margin": 0.5, "persistent": true})
	return out


func boss_reset_round() -> void:
	if presentation_only: return
	_clear_craters()
	_slam_timer = 2.5
	_sweep_timer = SWEEP_PERIOD
	_exposed = 0.0
	_hit_this_window.clear()
	if is_instance_valid(_arm):
		_arm.rotation = Vector3.ZERO
	if is_instance_valid(_fist):
		_fist.position = Vector3(9.2, 0, 0)
		_fist.scale = Vector3.ONE


func _clear_craters() -> void:
	if ctx != null and ctx.arena is Arena:
		ctx.arena.reset_craters()
	for c in _craters:
		if is_instance_valid(c["node"]):
			c["node"].queue_free()
	_craters.clear()


func safe_respawn_position(slot: int) -> Vector3:
	if presentation_only: return spawn_position(slot)
	var arena := ctx.arena as Arena
	var preferred := spawn_position(slot)
	if arena == null:
		return preferred
	for attempt in 2:
		if arena.is_inside(preferred, 1.0) and _respawn_space_clear(slot, preferred):
			return preferred
		for ring in [0.0, 0.25, 0.5, 0.75]:
			for step in 32:
				var angle := TAU * (float(step) / 32.0 + float(slot) / 4.0)
				var point := arena.global_position + Vector3(cos(angle), 0, sin(angle)) * arena.current_radius * float(ring)
				point.y = preferred.y
				if arena.is_inside(point, 1.0) and _respawn_space_clear(slot, point):
					return point
		# Recover exhausted ground, then repeat occupancy checks on that ground.
		if attempt == 0: _clear_craters()
	var fallback := arena.global_position
	fallback.y = preferred.y
	return fallback


func _respawn_space_clear(slot: int, point: Vector3) -> bool:
	var radius := _fighter_radius(ctx.fighter(slot))
	for i in ctx.fighters.size():
		var other := ctx.fighter(i)
		if i == slot or not ctx.is_alive(i) or not is_instance_valid(other) or not other.alive or not other.visible:
			continue
		if absf(point.y - other.global_position.y) > 2.0:
			continue
		var offset := Vector2(point.x - other.global_position.x, point.z - other.global_position.z)
		if offset.length() < radius + _fighter_radius(other) + 0.1:
			return false
	return true


func _fighter_radius(fighter: Node) -> float:
	if is_instance_valid(fighter):
		var body := fighter.get_node_or_null("Body") as CollisionShape3D
		if is_instance_valid(body) and body.shape is CapsuleShape3D:
			return body.shape.radius
	return 0.42


func cleanup() -> void:
	_clear_craters()
	if ctx != null and ctx.arena is Arena:
		ctx.arena.disable_crater_floor()
	super.cleanup()
