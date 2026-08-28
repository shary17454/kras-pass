extends "res://src/minigames/crate_smash.gd"
## The Lab — Crate Smash where some boxes smash back, and some fight for you.
##
## A third kind of crate joins the floor: sealed specimen boxes that pay no
## points but hand the breaker a weapon on the spot — a shockwave that throws
## every rival nearby, an eight-way volley of stunning bolts, or a heavy ingot
## of raw score. The rigged crates are still here too, so the read is richer
## than the parent's: sprint for the guaranteed two points, or gamble the swing
## on a box that might arm you, might pay double — or might be the trap.

const WEAPON_RATIO := 0.28
const SHOCKWAVE_RADIUS := 5.5
const SHOCKWAVE_POWER := 24.0
const VOLLEY_COUNT := 8
const INGOT_POINTS := 5

var _shots: Array = []


func _spawn_crate() -> void:
	super._spawn_crate()
	# Promote the crate the parent just placed, sometimes, if it is not rigged:
	# specimen boxes read pale green and unmistakably not like the loot ones.
	var entry = _crates[_crates.size() - 1]
	if bool(entry["bomb"]) or ctx.rng.randf() >= WEAPON_RATIO:
		return
	entry["weapon"] = true
	var body: Node3D = entry["node"]
	for child in body.get_children():
		if not (child is CollisionShape3D):
			child.queue_free()
	body.add_child(MeshFactory.crate(1.5, Color("#5ad6a0"), Color("#eafff3")))


func _break_crate(index: int, slot: int) -> void:
	var entry = _crates[index]
	if not bool(entry.get("weapon", false)):
		super._break_crate(index, slot)
		return
	var n: Node3D = entry["node"]
	var pos: Vector3 = n.global_position
	_crates.remove_at(index)
	n.queue_free()
	ctx.bump_detail(slot, "weapons")
	match ctx.rng.randi_range(0, 2):
		0:
			_shockwave(slot, pos)
		1:
			_volley(slot, pos)
		2:
			ctx.add_score(slot, int(INGOT_POINTS * ctx.powerups.point_multiplier(slot)))
			AudioManager.play_sfx("score", pos)
	var burst := MeshFactory.burst(Color("#5ad6a0"), 14)
	ctx.world_root.add_child(burst)
	burst.global_position = pos


## Everyone near the box is thrown off their swing — credited, so a shockwave
## that rings someone out pays its owner like any shove.
func _shockwave(slot: int, pos: Vector3) -> void:
	AudioManager.play_sfx("explode", pos)
	EventBus.shake(0.5, 0.3)
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var away: Vector3 = f.global_position - pos
		away.y = 0.0
		if away.length() > SHOCKWAVE_RADIUS:
			continue
		f.take_hit(slot, away.normalized() if away.length() > 0.1 else Vector3.FORWARD,
			SHOCKWAVE_POWER * (1.0 - away.length() / SHOCKWAVE_RADIUS * 0.5), 6.0)


func _volley(slot: int, pos: Vector3) -> void:
	AudioManager.play_sfx("shoot", pos)
	for k in VOLLEY_COUNT:
		var p := Projectile.new()
		ctx.world_root.add_child(p)
		p.configure(UIKit.adapt(ctx.config.players[slot].color()))
		var ang := TAU * float(k) / float(VOLLEY_COUNT)
		p.fire(pos + Vector3(0, 0.9, 0), Vector3(cos(ang), 0, sin(ang)), slot, 16.0, 5.0, 12.0)
		_shots.append(p)


func tick(delta: float) -> void:
	super.tick(delta)
	var idx := _shots.size() - 1
	while idx >= 0:
		var p = _shots[idx]
		if not is_instance_valid(p) or not p.active:
			if is_instance_valid(p):
				p.queue_free()
			_shots.remove_at(idx)
		else:
			p.tick(delta)
		idx -= 1


func detail_rows() -> Array:
	return [
		{"key": "results.stat.crates", "field": "crates"},
		{"key": "results.stat.weapons", "field": "weapons"},
		{"key": "results.stat.mistakes", "field": "mistakes"},
	]


func cleanup() -> void:
	super.cleanup()
	for p in _shots:
		if is_instance_valid(p):
			p.queue_free()
	_shots.clear()
