extends MiniGameController
## Ring Rumble — the flagship push-out game.
##
## Four competitors on a ring that shrinks as the clock runs down. No lives, no
## respawns: leaving the ring ends your round. Sudden death cuts the ring hard
## so a stalemate cannot survive.
##
## This is the smallest complete mini-game in the project, and a good template:
## it is 60 lines of rules on top of the shared match layer.

enum BombKind { SHOCK, FIRE, ICE, WATER }

const ORDNANCE_DROP_PERIOD := 5.2
const ORDNANCE_FUSE_TIME := 6.5
const ORDNANCE_BLAST_RADIUS := 4.9
const ORDNANCE_THROW_SPEED := 18.5
const ORDNANCE_MAX_LIVE := 4
const ORDNANCE_CARRY_FLAG := 2

var arctic_ordnance_enabled := true
var _ordnance: Array = []
var _ordnance_drop_timer := 2.4


func configure() -> void:
	eliminate_on_fall = true
	lives_per_player = 1


func build() -> void:
	_clear_ordnance()
	_ordnance_drop_timer = 2.4


func on_round_start() -> void:
	var arena := ctx.arena as Arena
	if arena != null:
		arena.reset_hazards()
	_clear_ordnance()
	_ordnance_drop_timer = 2.4


func tick(delta: float) -> void:
	# Award a small survival tick so a player who dominates the whole round out-
	# scores one who happened to be second-to-last in a fast round.
	_tick_ordnance(delta)


func on_sudden_death() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	# Collapse the ring toward the centre immediately; anyone loitering at the
	# rim is now standing on nothing.
	for h in arena.get_children():
		if h is ArenaHazards.ShrinkRing:
			h.start_delay = 0.0
			h.rate = maxf(h.rate, 1.2)
			# Room for one. Stopping at a 3.6 m island let every remaining
			# fighter stand inside it indefinitely once knockback stopped being
			# a catapult, and a sudden death that can stalemate is not sudden —
			# the round hung until the harness timeout. The ring now closes to
			# less than a body's width, which is a guarantee, not a pressure.
			h.min_radius = 0.9


func on_credited_knockout(attacker: int, _victim: int) -> void:
	# Ring-outs you caused are shown on the results screen even though the
	# ranking itself is survival-based.
	ctx.bump_detail(attacker, "knockouts", 0)


func hud_value(slot: int) -> String:
	var held: Variant = _held_ordnance(slot)
	if held != null:
		return _bomb_glyph(int(held["kind"]))
	if not ctx.is_alive(slot):
		return Loc.t("hud.eliminated")
	return "●"


func detail_rows() -> Array:
	return [
		{"key": "results.stat.knockouts", "field": "knockouts"},
		{"key": "results.stat.falls", "field": "falls"},
	]


func music_track() -> String:
	return "arena"


func cleanup() -> void:
	_clear_ordnance()


func _tick_ordnance(delta: float) -> void:
	if not arctic_ordnance_enabled or ctx == null or ctx.arena == null:
		return
	_ordnance_drop_timer -= delta
	if _ordnance_drop_timer <= 0.0 and _ordnance.size() < ORDNANCE_MAX_LIVE:
		_ordnance_drop_timer = ORDNANCE_DROP_PERIOD
		_drop_ordnance()
	var idx := _ordnance.size() - 1
	while idx >= 0:
		var b: Dictionary = _ordnance[idx]
		var node := b["node"] as Node3D
		if not is_instance_valid(node):
			_ordnance.remove_at(idx)
			idx -= 1
			continue
		b["fuse"] = float(b["fuse"]) - delta
		_pulse_ordnance(b, node)
		if float(b["fuse"]) <= 0.0:
			_detonate_ordnance(idx)
			idx -= 1
			continue
		var holder := int(b["held"])
		if holder >= 0:
			var f := ctx.fighter(holder)
			if f != null and is_instance_valid(f) and ctx.is_alive(holder) \
					and f.carrying == ORDNANCE_CARRY_FLAG:
				node.global_position = f.global_position + Vector3(0, 2.05, 0)
			else:
				b["held"] = -1
		else:
			_move_ordnance(b, node, delta)
			_try_take_ordnance(b, node)
		idx -= 1
	_read_ordnance_throws()


func _drop_ordnance() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	var kind := _random_bomb_kind()
	var node := MeshFactory.pickup_shell(_bomb_color(kind), 0.58)
	node.name = "RingBomb%s" % _bomb_glyph(kind)
	ctx.world_root.add_child(node)
	for attempt in 16:
		var ang := ctx.rng.randf() * TAU
		var r := sqrt(ctx.rng.randf()) * arena.current_radius * 0.72
		var p := arena.global_position + Vector3(cos(ang) * r, 0.82, sin(ang) * r)
		if arena.is_inside(p, 2.0):
			node.global_position = p
			break
	if node.global_position == Vector3.ZERO:
		node.global_position = arena.global_position + Vector3(0, 0.82, 0)
	_ordnance.append({"node": node, "kind": kind, "held": -1, "thrower": -1,
		"vel": Vector3.ZERO, "fuse": ORDNANCE_FUSE_TIME, "armed": 0.35})
	AudioManager.play_sfx("tick", node.global_position, 0.65)


func _pulse_ordnance(b: Dictionary, node: Node3D) -> void:
	var t: float = clampf(float(b["fuse"]) / ORDNANCE_FUSE_TIME, 0.0, 1.0)
	var pulse := 1.0 + 0.12 * sin(float(b["fuse"]) * lerpf(20.0, 7.0, t))
	node.scale = Vector3.ONE * pulse
	node.rotation.y += 0.055


func _move_ordnance(b: Dictionary, node: Node3D, delta: float) -> void:
	var vel: Vector3 = b["vel"]
	if float(b.get("armed", 0.0)) > 0.0:
		b["armed"] = maxf(0.0, float(b["armed"]) - delta)
	if vel.length_squared() < 0.02:
		return
	node.global_position += vel * delta
	b["vel"] = vel.move_toward(Vector3.ZERO, 13.0 * delta)
	var arena := ctx.arena as Arena
	if arena != null and not arena.is_inside(node.global_position, -1.0):
		node.global_position.y -= 10.0 * delta
	if vel.length_squared() < 9.0 or float(b.get("armed", 0.0)) > 0.0:
		return
	var thrower := int(b["thrower"])
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		if i == thrower and node.global_position.distance_to(f.global_position) < 2.2:
			continue
		if node.global_position.distance_to(f.global_position) <= 1.45:
			b["fuse"] = 0.0
			return


func _try_take_ordnance(b: Dictionary, node: Node3D) -> void:
	if Vector3(b["vel"]).length_squared() > 3.0:
		return
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f) or f.carrying > 0:
			continue
		if f.global_position.distance_to(node.global_position) > 1.45:
			continue
		b["kind"] = _random_bomb_kind()
		b["held"] = i
		b["thrower"] = i
		f.carrying = ORDNANCE_CARRY_FLAG
		AudioManager.play_sfx("powerup", node.global_position)
		return


func _read_ordnance_throws() -> void:
	for b in _ordnance:
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
		b["vel"] = f.facing.normalized() * ORDNANCE_THROW_SPEED
		b["armed"] = 0.18
		AudioManager.play_sfx("swing", f.global_position)


func _detonate_ordnance(index: int) -> void:
	var b: Dictionary = _ordnance[index]
	var node := b["node"] as Node3D
	var pos := node.global_position
	var kind := int(b["kind"])
	var thrower := int(b["thrower"])
	var holder := int(b["held"])
	_ordnance.remove_at(index)
	if holder >= 0:
		var carrier := ctx.fighter(holder)
		if carrier != null and is_instance_valid(carrier):
			carrier.carrying = 0
	if is_instance_valid(node):
		node.queue_free()
	var burst := MeshFactory.burst(_bomb_color(kind), 22, 3.1)
	ctx.world_root.add_child(burst)
	burst.global_position = pos
	AudioManager.play_sfx("explode", pos)
	if kind == BombKind.FIRE:
		AudioManager.play_sfx("burn", pos)
	elif kind == BombKind.WATER:
		AudioManager.play_sfx("splash", pos)
	EventBus.shake(0.65, 0.38)
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var away: Vector3 = f.global_position - pos
		away.y = 0.0
		var d := away.length()
		if d > ORDNANCE_BLAST_RADIUS:
			continue
		var dir := away.normalized() if d > 0.08 else Vector3.FORWARD
		if f.has_mount() and i != thrower:
			f.knock_mount_off(dir)
			continue
		_apply_bomb_effect(f, i, thrower, dir, kind, d)


func _apply_bomb_effect(f: Fighter, slot: int, thrower: int, dir: Vector3, kind: int, dist: float) -> void:
	var falloff := 1.0 - clampf(dist / ORDNANCE_BLAST_RADIUS, 0.0, 1.0)
	var by := thrower if thrower != slot else -1
	match kind:
		BombKind.FIRE:
			f.take_hit(by, dir, 18.0 * (0.45 + falloff), 14.0, true)
			f.stun(0.65)
		BombKind.ICE:
			f.freeze(1.25 + 0.5 * falloff)
			f.take_hit(by, dir, 11.0 * (0.5 + falloff), 5.0, true)
		BombKind.WATER:
			f.take_hit(by, dir, 24.0 * (0.5 + falloff), 7.0, true)
			f.apply_impulse(dir * 8.0 + Vector3(0, 2.2, 0))
		_:
			f.take_hit(by, dir, 22.0 * (0.45 + falloff), 8.0, true)


func _held_ordnance(slot: int):
	for b in _ordnance:
		if int(b["held"]) == slot:
			return b
	return null


func _clear_ordnance() -> void:
	for b in _ordnance:
		if b.has("node") and is_instance_valid(b["node"]):
			b["node"].queue_free()
	_ordnance.clear()
	if ctx == null:
		return
	for i in ctx.fighters.size():
		var f := ctx.fighter(i)
		if f != null and is_instance_valid(f) and f.carrying == ORDNANCE_CARRY_FLAG:
			f.carrying = 0


func _random_bomb_kind() -> int:
	var roll := ctx.rng.randi_range(0, 3) if ctx != null else 0
	return [BombKind.SHOCK, BombKind.FIRE, BombKind.ICE, BombKind.WATER][roll]


func _bomb_glyph(kind: int) -> String:
	match kind:
		BombKind.FIRE: return "🔥"
		BombKind.ICE: return "❄"
		BombKind.WATER: return "≋"
		_: return "✺"


func _bomb_color(kind: int) -> Color:
	match kind:
		BombKind.FIRE: return Color("#ff7a2f")
		BombKind.ICE: return Color("#a6e7ff")
		BombKind.WATER: return Color("#42c8ff")
		_: return Color("#ff5f8d")
