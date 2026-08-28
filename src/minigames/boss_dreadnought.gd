extends "res://src/minigames/boss_controller.gd"
## Boss 3 — The Dreadnought.
##
## A war machine that fights three different fights and tells you which one it
## is in. Armoured up front and open at the vents behind, it turns to face
## whoever hurt it last, so the four of you cannot all stand in the good spot —
## somebody has to be the one it is looking at. Each phase swaps its weapon
## rather than merely speeding it up: shells you dodge, a mine field you route
## around, then a spin that makes standing still the mistake.

## Slow enough that circling it beats chasing it. At 1.3 rad/s it out-turned a
## running fighter's angular rate, so four bots converging on the vent simply
## herded it around forever and the fight measured literally zero damage.
const TURN_RATE := 0.7
const SHELL_PERIOD := 2.6
const MINE_PERIOD := 3.4
const SPIN_PERIOD := 6.0
const VENT_DAMAGE := 45.0
## cos(50 deg): you have to be genuinely round the back, not merely beside it.
const REAR_ARC := 0.64
## One bite per swing-and-reposition, not one per frame of the swing.
const VENT_COOLDOWN := 1.1

var _facing := 0.0
var _aim_at := -1
var _shell_timer := 2.0
var _mine_timer := MINE_PERIOD
var _spin_timer := SPIN_PERIOD
var _mines: Array = []
var _vent: Node3D
var _hull: Node3D
var _vent_cd := {}


func boss_build() -> void:
	boss_max_health = 1100.0
	boss_health = 1100.0
	phase_thresholds = [0.7, 0.35]
	_hull = MeshFactory.box(Vector3(5.0, 2.4, 7.0), Color("#4c4438"), 0.2)
	_hull.position.y = 1.6
	boss_node.add_child(_hull)
	var turret := MeshFactory.cylinder(1.5, 1.2, Color("#6a5f4c"), 0.3)
	turret.position.y = 3.2
	boss_node.add_child(turret)
	var barrel := MeshFactory.box(Vector3(0.6, 0.6, 4.4), Color("#8a7c64"), 0.3)
	barrel.position = Vector3(0, 3.2, 3.0)
	boss_node.add_child(barrel)
	# Vents at the back, glowing. Being behind it is the whole positional game.
	_vent = MeshFactory.box(Vector3(3.4, 1.4, 0.5), Color("#5ad6a0"), 2.2)
	_vent.position = Vector3(0, 1.7, -3.6)
	boss_node.add_child(_vent)


func boss_think(delta: float) -> void:
	_track(delta)
	_check_vent_hits(delta)
	match phase:
		0:
			_shell_timer -= delta
			if _shell_timer <= 0.0:
				_shell_timer = SHELL_PERIOD
				_fire_shells(1)
		1:
			_shell_timer -= delta
			if _shell_timer <= 0.0:
				_shell_timer = SHELL_PERIOD * 1.15
				_fire_shells(2)
			_mine_timer -= delta
			if _mine_timer <= 0.0:
				_mine_timer = MINE_PERIOD
				_drop_mine()
		_:
			_shell_timer -= delta
			if _shell_timer <= 0.0:
				_shell_timer = SHELL_PERIOD * 0.8
				_fire_shells(2)
			_spin_timer -= delta
			if _spin_timer <= 0.0:
				_spin_timer = SPIN_PERIOD
				_spin_up()
	_tick_mines(delta)


## It turns toward whoever last hurt it — so the player who just scored is the
## one who has to move, and the vent opens for somebody else.
func _track(delta: float) -> void:
	# Whoever hurt it last. Before anyone has, it commits to one opponent and
	# keeps facing them rather than re-picking the nearest every tick: chasing
	# the closest body means the vent is always pointed away from everybody at
	# once, which is not a positional puzzle, it is a locked door.
	if _aim_at < 0 or not ctx.is_alive(_aim_at):
		_aim_at = _nearest_alive()
	var target := _aim_at
	if target < 0:
		return
	var f := ctx.fighter(target)
	if f == null or not is_instance_valid(f):
		return
	var to: Vector3 = f.global_position - boss_node.global_position
	to.y = 0.0
	if to.length() < 0.2:
		return
	var want := atan2(to.x, to.z)
	_facing = wrapf(_facing + clampf(wrapf(want - _facing, -PI, PI), -TURN_RATE * delta, TURN_RATE * delta), -PI, PI)
	boss_node.rotation.y = _facing


func damage_boss(amount: float, by_slot: int) -> void:
	super.damage_boss(amount, by_slot)
	if by_slot >= 0:
		_aim_at = by_slot


func _fire_shells(count: int) -> void:
	var target := _aim_at if _aim_at >= 0 and ctx.is_alive(_aim_at) else _nearest_alive()
	if target < 0:
		return
	var f := ctx.fighter(target)
	if f == null or not is_instance_valid(f):
		return
	var muzzle: Vector3 = boss_node.global_position + Vector3(0, 2.0, 0) \
		+ Vector3(sin(_facing), 0, cos(_facing)) * 3.4
	for i in count:
		var to: Vector3 = f.global_position - muzzle
		to.y = 0.0
		var spread := 0.0 if count == 1 else lerpf(-0.22, 0.22, float(i) / float(maxi(count - 1, 1)))
		fire_shot(muzzle, to.normalized().rotated(Vector3.UP, spread), 21.0, 12.0, 30.0)
	AudioManager.play_sfx("shoot", muzzle)


func _drop_mine() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	var ang := ctx.rng.randf() * TAU
	var r := sqrt(ctx.rng.randf()) * arena.current_radius * 0.8
	var pos := arena.global_position + Vector3(cos(ang) * r, 0.25, sin(ang) * r)
	var node := MeshFactory.cylinder(0.7, 0.35, Color("#ff5f8d"), 1.4)
	node.position = pos
	ctx.world_root.add_child(node)
	_mines.append({"node": node, "pos": pos, "armed": 1.0})


func _tick_mines(delta: float) -> void:
	var i := _mines.size() - 1
	while i >= 0:
		var m = _mines[i]
		var node: Node3D = m["node"]
		if not is_instance_valid(node):
			_mines.remove_at(i)
			i -= 1
			continue
		m["armed"] = maxf(0.0, float(m["armed"]) - delta)
		node.scale.y = 1.0 + 0.3 * sin(float(m["armed"]) * 8.0 + i)
		if float(m["armed"]) <= 0.0:
			for s in ctx.fighters.size():
				if not ctx.is_alive(s):
					continue
				var f := ctx.fighter(s)
				if f == null or not is_instance_valid(f):
					continue
				if f.global_position.distance_to(node.global_position) < 1.8:
					strike(node.global_position, 3.2, 24.0)
					_mines.remove_at(i)
					node.queue_free()
					break
		i -= 1


## The one attack with no safe standing spot — you have to be moving.
func _spin_up() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	for k in 3:
		var r: float = arena.current_radius * lerpf(0.3, 0.85, float(k) / 2.0)
		for i in 6:
			var ang := TAU * float(i) / 6.0 + float(k) * 0.4
			telegraph(arena.global_position + Vector3(cos(ang) * r, 0, sin(ang) * r),
				2.6, 1.3 + float(k) * 0.35,
				func(pos: Vector3, radius: float): strike(pos, radius, 24.0))


func _check_vent_hits(delta: float) -> void:
	if _vent == null or not is_instance_valid(_vent):
		return
	for k in _vent_cd.keys():
		_vent_cd[k] = float(_vent_cd[k]) - delta
		if float(_vent_cd[k]) <= 0.0:
			_vent_cd.erase(k)
	for i in ctx.fighters.size():
		if not ctx.is_alive(i) or _vent_cd.has(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f) or not f.is_attacking():
			continue
		if not in_reach(f, _vent.global_position, 1.0):
			continue
		# Behind it, genuinely. Without the arc test the vent answered from
		# every angle and four bots melted 1100 health in 1.6 s — the
		# positional puzzle the whole boss is built around was never asked.
		var to: Vector3 = f.global_position - boss_node.global_position
		to.y = 0.0
		var back := Vector3(-sin(_facing), 0, -cos(_facing))
		if to.length() > 0.1 and back.dot(to.normalized()) < REAR_ARC:
			continue
		_vent_cd[i] = VENT_COOLDOWN
		damage_boss(VENT_DAMAGE, i)


func _nearest_alive() -> int:
	var best := -1
	var best_d := INF
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var d: float = f.global_position.distance_to(boss_node.global_position)
		if d < best_d:
			best_d = d
			best = i
	return best


func on_phase_changed(_new_phase: int) -> void:
	_mine_timer = 0.6
	_spin_timer = 1.2


func weak_points() -> Array:
	return [_vent.global_position] if _vent != null and is_instance_valid(_vent) else []


func danger_zones() -> Array:
	var out: Array = super.danger_zones()
	for m in _mines:
		if is_instance_valid(m["node"]):
			out.append({"pos": m["node"].global_position, "radius": 2.4, "left": 99.0})
	return out


func cleanup() -> void:
	super.cleanup()
	for m in _mines:
		if is_instance_valid(m["node"]):
			m["node"].queue_free()
	_mines.clear()
