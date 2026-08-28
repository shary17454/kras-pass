extends "res://src/minigames/boss_controller.gd"
## Boss 4 — The Sovereign.
##
## The championship. It does not get faster between phases, it changes what
## game you are playing, and each phase is a different family of the collection
## turned against you.
##
##   I.  Pursuit — it hunts, marking the floor under whoever is closest, and
##       the only openings are the beats it needs to recover from a lunge.
##   II. Siege — it shields itself and volleys energy orbs outward; the shield
##       drops only where an orb has been sent back into it, so the way in is
##       the thing it threw at you.
##   III. Collapse — the shield is gone, the floor is going, and it throws
##       everything at once. Nothing to solve here: spend what you have left.
##
## Damage is banked per player throughout, so the four of you are cooperating
## against it and competing with each other in the same motion — which is the
## note the whole mode has been building toward.

const LUNGE_PERIOD := 3.8
const RECOVER_TIME := 2.0
const ORB_PERIOD := 3.0
const ORB_RETURN_DAMAGE := 90.0
const CORE_DAMAGE := 60.0
const COLLAPSE_PERIOD := 2.2

var _lunge_timer := 2.0
var _orb_timer := ORB_PERIOD
var _collapse_timer := COLLAPSE_PERIOD
var _recover := 0.0
var _shielded := false
var _core: Node3D
var _shield: Node3D
var _orbs: Array = []
var _hit_window := {}


func boss_build() -> void:
	boss_max_health = 1500.0
	boss_health = 1500.0
	phase_thresholds = [0.66, 0.30]
	var body := MeshFactory.cone(2.4, 5.5, Color("#3a2f52"))
	body.position.y = 2.75
	boss_node.add_child(body)
	var crown := MeshFactory.torus(2.0, 2.6, Color("#c9a227"), 1.2)
	crown.position.y = 4.8
	boss_node.add_child(crown)
	_core = MeshFactory.sphere(1.1, Color("#ff5f8d"), 2.6)
	_core.position.y = 2.4
	boss_node.add_child(_core)


func boss_think(delta: float) -> void:
	if _core != null and is_instance_valid(_core):
		_core.scale = Vector3.ONE * (1.0 + 0.08 * sin(float(Time.get_ticks_msec()) * 0.004))
	_tick_orbs(delta)
	if _recover > 0.0:
		_recover -= delta
		_check_core_hits()
		if _recover <= 0.0:
			_hit_window.clear()
		return
	match phase:
		0:
			_pursuit(delta)
		1:
			_siege(delta)
		_:
			_collapse(delta)


# --- phase I ---------------------------------------------------------------

func _pursuit(delta: float) -> void:
	var target := _closest_alive()
	if target < 0:
		return
	var f := ctx.fighter(target)
	if f == null or not is_instance_valid(f):
		return
	# It walks you down. Slow enough to outrun, fast enough that you cannot
	# stop running — the pressure is positional, not reactive.
	var to: Vector3 = f.global_position - boss_node.global_position
	to.y = 0.0
	if to.length() > 3.0:
		boss_node.global_position += to.normalized() * 3.4 * delta
	_lunge_timer -= delta
	if _lunge_timer <= 0.0:
		_lunge_timer = LUNGE_PERIOD
		telegraph(f.global_position, 4.2, 1.35, func(pos: Vector3, radius: float):
			strike(pos, radius, 30.0)
			# It over-commits and has to right itself: that is the opening.
			_recover = RECOVER_TIME
			_hit_window.clear())


# --- phase II --------------------------------------------------------------

func _siege(delta: float) -> void:
	if not _shielded:
		_raise_shield()
	_orb_timer -= delta
	if _orb_timer <= 0.0:
		_orb_timer = ORB_PERIOD
		_throw_orbs()


func _raise_shield() -> void:
	_shielded = true
	if _shield == null or not is_instance_valid(_shield):
		_shield = MeshFactory.sphere(3.6, Color("#5ad6a0"), 0.9)
		_shield.material_override = MeshFactory.transparent(Color("#5ad6a0"), 0.32)
		_shield.position.y = 2.6
		boss_node.add_child(_shield)
	_shield.visible = true
	AudioManager.play_sfx("shield_break")


## Orbs drift outward slowly enough to be met. A fighter who swings at one
## sends it back, and an orb that reaches the shield brings the shield down.
func _throw_orbs() -> void:
	for i in 4:
		var ang := TAU * float(i) / 4.0 + ctx.rng.randf() * 0.5
		var node := MeshFactory.sphere(0.7, Color("#ffd166"), 2.4)
		node.position = boss_node.global_position + Vector3(0, 2.2, 0)
		ctx.world_root.add_child(node)
		_orbs.append({"node": node, "vel": Vector3(cos(ang), 0, sin(ang)) * 7.0,
			"returned": false, "by": -1, "life": 7.0})
	AudioManager.play_sfx("shoot", boss_node.global_position)


func _tick_orbs(delta: float) -> void:
	var i := _orbs.size() - 1
	while i >= 0:
		var o = _orbs[i]
		var node: Node3D = o["node"]
		if not is_instance_valid(node):
			_orbs.remove_at(i)
			i -= 1
			continue
		o["life"] = float(o["life"]) - delta
		node.global_position += Vector3(o["vel"]) * delta
		node.rotate_y(6.0 * delta)
		if float(o["life"]) <= 0.0:
			_orbs.remove_at(i)
			node.queue_free()
			i -= 1
			continue
		for s in ctx.fighters.size():
			if not ctx.is_alive(s):
				continue
			var f := ctx.fighter(s)
			if f == null or not is_instance_valid(f):
				continue
			var flat: Vector3 = node.global_position - f.global_position
			flat.y = 0.0
			var d: float = flat.length()
			if not in_reach(f, node.global_position, 0.7):
				continue
			if f.is_attacking() and not bool(o["returned"]):
				# Batted back at the boss, and it is yours from here.
				var back: Vector3 = boss_node.global_position - node.global_position
				back.y = 0.0
				o["vel"] = back.normalized() * 15.0
				o["returned"] = true
				o["by"] = s
				o["life"] = 6.0
				AudioManager.play_sfx("hit", node.global_position, 1.3)
			elif not bool(o["returned"]) and d < 1.2:
				var away: Vector3 = f.global_position - node.global_position
				away.y = 0.0
				f.take_hit(-1, away.normalized() if away.length() > 0.1 else Vector3.FORWARD, 22.0, 0.0, true)
				ctx.bump_detail(s, "hits_taken")
				_orbs.remove_at(i)
				node.queue_free()
				break
		if i >= _orbs.size() or not is_instance_valid(node):
			i -= 1
			continue
		if bool(o["returned"]) and node.global_position.distance_to(boss_node.global_position) < 4.0:
			if _shielded:
				_shielded = false
				if _shield != null and is_instance_valid(_shield):
					_shield.visible = false
				_recover = RECOVER_TIME * 1.4
				_hit_window.clear()
				EventBus.shake(0.5, 0.35)
				AudioManager.play_sfx("shield_break", boss_node.global_position)
			damage_boss(ORB_RETURN_DAMAGE, int(o["by"]))
			_orbs.remove_at(i)
			node.queue_free()
		i -= 1


# --- phase III -------------------------------------------------------------

func _collapse(delta: float) -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	_collapse_timer -= delta
	if _collapse_timer > 0.0:
		return
	_collapse_timer = COLLAPSE_PERIOD
	# Everything at once, but every piece of it still announced.
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f != null and is_instance_valid(f):
			telegraph(f.global_position, 3.2, 1.0,
				func(pos: Vector3, radius: float): strike(pos, radius, 26.0))
	var ang := ctx.rng.randf() * TAU
	for k in 5:
		var r: float = arena.current_radius * lerpf(0.25, 0.9, float(k) / 4.0)
		telegraph(arena.global_position + Vector3(cos(ang + k * 0.9) * r, 0, sin(ang + k * 0.9) * r),
			2.8, 1.2 + k * 0.2, func(pos: Vector3, radius: float): strike(pos, radius, 22.0))


# --- shared ----------------------------------------------------------------

func _check_core_hits() -> void:
	if _core == null or not is_instance_valid(_core) or _shielded:
		return
	for i in ctx.fighters.size():
		if not ctx.is_alive(i) or _hit_window.has(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f) or not f.is_attacking():
			continue
		if not in_reach(f, _core.global_position, 1.2):
			continue
		_hit_window[i] = true
		damage_boss(CORE_DAMAGE, i)


func _closest_alive() -> int:
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


func on_phase_changed(new_phase: int) -> void:
	_recover = RECOVER_TIME
	_hit_window.clear()
	if new_phase >= 2:
		_shielded = false
		if _shield != null and is_instance_valid(_shield):
			_shield.visible = false


func weak_points() -> Array:
	# Phase II: the orb you can reach is the objective, not the boss.
	if phase == 1 and not _orbs.is_empty():
		var out: Array = []
		for o in _orbs:
			if is_instance_valid(o["node"]) and not bool(o["returned"]):
				out.append(o["node"].global_position)
		if not out.is_empty():
			return out
	if _shielded:
		return []
	if _recover > 0.0 or phase >= 2:
		return [_core.global_position] if _core != null and is_instance_valid(_core) else []
	return []


func cleanup() -> void:
	super.cleanup()
	for o in _orbs:
		if is_instance_valid(o["node"]):
			o["node"].queue_free()
	_orbs.clear()
