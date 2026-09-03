extends "res://src/minigames/ring_rumble.gd"
## Fawda — Ring Rumble with live ordnance on the floor.
##
## Bombs keep dropping onto the ring with their fuses already lit. Walk over one
## to scoop it up; press attack to hurl it. Holding it is how you aim it, and
## holding it is also how you die: the fuse does not care whose hands it is in,
## and a bomb that goes off in yours throws you further than any shove in the
## game. Two rules make it a game of nerve rather than luck — you cannot swing
## while carrying, so picking one up disarms you, and the blast is credited to
## whoever last threw it, so a well-timed hot potato scores like a ring-out.

const DROP_PERIOD := 4.5
const FUSE_TIME := 5.0
const BLAST_RADIUS := 6.0
const BLAST_POWER := 30.0
const MAX_LIVE := 4

var _bombs: Array = []
var _drop_timer := 2.0


func configure() -> void:
	super.configure()
	arctic_ordnance_enabled = false


func build() -> void:
	super.build()
	_bombs.clear()
	_drop_timer = 2.0


func on_round_start() -> void:
	super.on_round_start()
	_clear_bombs()
	_drop_timer = 2.0


func tick(delta: float) -> void:
	super.tick(delta)
	_drop_timer -= delta
	if _drop_timer <= 0.0 and _bombs.size() < MAX_LIVE:
		_drop_timer = DROP_PERIOD
		_drop_bomb()
	_tick_bombs(delta)
	_read_throws()


func _drop_bomb() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	var node := Node3D.new()
	node.add_child(MeshFactory.sphere(0.55, Color("#2b2438"), 0.2))
	var wick := MeshFactory.cylinder(0.07, 0.5, Color("#ff8a3d"), 2.4, 8)
	wick.position.y = 0.6
	node.add_child(wick)
	ctx.world_root.add_child(node)
	var ang := ctx.rng.randf() * TAU
	var r := sqrt(ctx.rng.randf()) * arena.current_radius * 0.7
	node.global_position = arena.global_position + Vector3(cos(ang) * r, 0.6, sin(ang) * r)
	_bombs.append({"node": node, "fuse": FUSE_TIME, "held": -1, "thrower": -1,
		"vel": Vector3.ZERO, "wick": wick})
	AudioManager.play_sfx("tick", node.global_position, 0.7)


func _tick_bombs(delta: float) -> void:
	var idx := _bombs.size() - 1
	while idx >= 0:
		var b = _bombs[idx]
		var node: Node3D = b["node"]
		if not is_instance_valid(node):
			_bombs.remove_at(idx)
			idx -= 1
			continue
		b["fuse"] = float(b["fuse"]) - delta
		# The wick shortens and the whole bomb pulses faster as the fuse burns,
		# so "how long have I got" is answerable at a glance from across the ring.
		var t: float = clampf(float(b["fuse"]) / FUSE_TIME, 0.0, 1.0)
		var wick: Node3D = b["wick"]
		if is_instance_valid(wick):
			wick.scale.y = maxf(0.05, t)
			wick.position.y = 0.35 + 0.25 * t
		node.scale = Vector3.ONE * (1.0 + 0.12 * sin(float(b["fuse"]) * lerpf(22.0, 6.0, t)))
		if float(b["fuse"]) <= 0.0:
			_detonate(idx)
			idx -= 1
			continue
		var holder := int(b["held"])
		if holder >= 0:
			var f := ctx.fighter(holder)
			if f != null and is_instance_valid(f) and ctx.is_alive(holder) and f.carrying > 0:
				node.global_position = f.global_position + Vector3(0, 1.9, 0)
			else:
				# Dropped by a hit, an elimination, or a respawn.
				b["held"] = -1
		else:
			_move_loose(b, node, delta)
			_try_pickup(b, node)
		idx -= 1


## A thrown bomb flies flat, slows down, and goes off the moment it reaches
## anyone. Letting it ride out its own fuse instead made the throw a lottery:
## it left at 17 m/s, coasted its ten metres, then sat there ticking while
## everyone strolled away — six matches produced dozens of detonations and
## almost none of them near a victim. Impact-fusing is what turns the bomb from
## a hazard that happens to you into a weapon you aim, and it puts the outcome
## on `accuracy` and `prediction`, where a difficulty tier can express itself.
func _move_loose(b: Dictionary, node: Node3D, delta: float) -> void:
	var vel: Vector3 = b["vel"]
	if vel.length_squared() < 0.01:
		return
	node.global_position += vel * delta
	b["vel"] = vel.move_toward(Vector3.ZERO, 14.0 * delta)
	if vel.length_squared() < 9.0:
		return
	var thrower := int(b["thrower"])
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		# The thrower is spared only while the bomb is still leaving their
		# hands, so lobbing one at your own feet is still a mistake.
		if i == thrower and node.global_position.distance_to(f.global_position) < 2.2 \
				and vel.length() > 12.0:
			continue
		if node.global_position.distance_to(f.global_position) < 1.5:
			b["fuse"] = 0.0
			return
	var arena := ctx.arena as Arena
	if arena != null and not arena.is_inside(node.global_position, -1.0):
		# Off the ring: it falls, and it still goes off down there.
		node.global_position.y -= 12.0 * delta


func _try_pickup(b: Dictionary, node: Node3D) -> void:
	if Vector3(b["vel"]).length_squared() > 4.0:
		return
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f) or f.carrying > 0:
			continue
		if f.global_position.distance_to(node.global_position) > 1.6:
			continue
		f.carrying = 1
		b["held"] = i
		b["thrower"] = i
		AudioManager.play_sfx("pickup", node.global_position)
		return


func _read_throws() -> void:
	for b in _bombs:
		var holder := int(b["held"])
		if holder < 0:
			continue
		if not InputRouter.frame(holder).just_pressed(InputFrame.Btn.ATTACK):
			continue
		var f := ctx.fighter(holder)
		if f == null or not is_instance_valid(f):
			continue
		f.carrying = 0
		b["held"] = -1
		b["thrower"] = holder
		b["vel"] = f.facing.normalized() * 17.0
		AudioManager.play_sfx("swing", f.global_position)


func _detonate(index: int) -> void:
	var b = _bombs[index]
	var node: Node3D = b["node"]
	var pos: Vector3 = node.global_position
	var thrower := int(b["thrower"])
	var holder := int(b["held"])
	_bombs.remove_at(index)
	if holder >= 0:
		var carrier := ctx.fighter(holder)
		if carrier != null and is_instance_valid(carrier):
			carrier.carrying = 0
	node.queue_free()
	var burst := MeshFactory.burst(Color("#ff8a3d"), 20, 3.4)
	ctx.world_root.add_child(burst)
	burst.global_position = pos
	AudioManager.play_sfx("explode", pos)
	EventBus.shake(0.7, 0.4)
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var away: Vector3 = f.global_position - pos
		away.y = 0.0
		var d := away.length()
		if d > BLAST_RADIUS:
			continue
		# Credit the last thrower, but never for blowing themselves up: a bomb
		# you were still holding is your own mistake, not your own knockout.
		var by: int = thrower if thrower != i else -1
		f.take_hit(by, away.normalized() if d > 0.1 else Vector3.FORWARD,
			BLAST_POWER * (1.0 - d / BLAST_RADIUS * 0.55), 0.0, true)


func _clear_bombs() -> void:
	for b in _bombs:
		if is_instance_valid(b["node"]):
			b["node"].queue_free()
	_bombs.clear()
	for i in ctx.fighters.size():
		var f := ctx.fighter(i)
		if f != null and is_instance_valid(f):
			f.carrying = 0


func hud_value(slot: int) -> String:
	var f := ctx.fighter(slot)
	if f != null and is_instance_valid(f) and f.carrying > 0 and ctx.is_alive(slot):
		return "✸"
	return super.hud_value(slot)


func ai_script() -> Script:
	return load("res://src/ai/brains/bomber_brain.gd")


## Live bombs the AI can see: position, fuse and whether it is in someone's
## hands. All of it is on screen — the wick length is the fuse.
func bomb_states() -> Array:
	var out: Array = []
	for b in _bombs:
		if is_instance_valid(b["node"]):
			out.append({"pos": b["node"].global_position, "fuse": float(b["fuse"]),
				"held": int(b["held"])})
	return out


func cleanup() -> void:
	_clear_bombs()
