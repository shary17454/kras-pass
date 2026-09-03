extends MiniGameController
## Relic Hold — one prize, and no way to hide with it.
##
## The spec asks for a game about carrying an object and protecting it. The
## project already had carry-and-deliver (Crate Relay) and carry-and-stack
## (Star Rush); this is the third shape, and the interesting one: holding scores
## continuously, so the moment you pick the relic up you become the target and
## everybody else instantly agrees on what to do. A hit drops it, and the
## carrier cannot swing back — the only defence is distance.

const POOL_KEY := "relic_item"
const HOLD_SECONDS_PER_POINT := 0.8
const RELIC_COLOR := Color("#ffd15c")

var _relic: Collectible
var _holder := -1
var _accum := 0.0
var _mark: Node3D
var _respawn := 0.0


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	Pool.define(POOL_KEY, func(): return Collectible.new(), 3)
	_spawn_relic(ctx.arena_center() + Vector3(0, 1.2, 0))


func on_round_start() -> void:
	_holder = -1
	_accum = 0.0
	_respawn = 0.0
	_clear_mark()
	if _relic == null or not is_instance_valid(_relic):
		_spawn_relic(ctx.arena_center() + Vector3(0, 1.2, 0))
	else:
		_relic.place(ctx.arena_center() + Vector3(0, 1.2, 0))


func tick(delta: float) -> void:
	if _relic != null and is_instance_valid(_relic) and _holder < 0:
		_relic.tick(delta)
		# A relic that slid off the rim would end the game, so it comes back.
		var arena := ctx.arena as Arena
		if arena != null and not arena.is_inside(_relic.global_position, 0.4):
			_relic.place(arena.global_position + Vector3(0, 1.2, 0))
	if _respawn > 0.0:
		_respawn = maxf(0.0, _respawn - delta)
		if _respawn <= 0.0:
			_spawn_relic(ctx.arena_center() + Vector3(0, 1.2, 0))
	if _holder < 0:
		return
	if not ctx.is_alive(_holder):
		_drop(_holder, -1)
		return
	var carrier := ctx.fighter(_holder)
	if carrier == null or not is_instance_valid(carrier) or carrier.carrying <= 0:
		_drop(_holder, -1)
		return
	_accum += delta
	while _accum >= HOLD_SECONDS_PER_POINT:
		_accum -= HOLD_SECONDS_PER_POINT
		ctx.add_score(_holder, maxi(1, int(round(ctx.powerups.point_multiplier(_holder)))))
		ctx.bump_detail(_holder, "hold_ticks")
	if _mark != null and is_instance_valid(_mark):
		_mark.global_position = carrier.global_position + Vector3(0, 2.3, 0)
		_mark.rotation.y += delta * 2.4


func _spawn_relic(pos: Vector3) -> void:
	var item: Collectible = Pool.acquire(POOL_KEY)
	if item == null:
		return
	if item.get_parent() == null:
		ctx.world_root.add_child(item)
	item.configure("gem", RELIC_COLOR, 1, 0.6)
	if not item.taken.is_connected(_on_taken):
		item.taken.connect(_on_taken)
	item.add_to_group("pickups")
	item.add_to_group("relic")
	item.place(pos)
	_relic = item


func _on_taken(item: Collectible, slot: int) -> void:
	if _holder >= 0 or not ctx.is_alive(slot):
		item.available = true
		item.monitoring = true
		return
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f) or f.carrying > 0:
		item.available = true
		item.monitoring = true
		return
	Pool.release(POOL_KEY, item)
	_relic = null
	_holder = slot
	_accum = 0.0
	f.carrying = 1
	# No swinging while holding: the carrier's only answer is to run, which is
	# what turns three rivals into a coordinated chase without any of them
	# being told to cooperate.
	f.can_attack = false
	_build_mark(f)
	AudioManager.play_sfx("pickup", f.global_position)
	EventBus.notify(Loc.t("relic.taken", {"name": _name_of(slot)}), "✦")


func on_fighter_knocked_out(slot: int, by_slot: int) -> void:
	if slot == _holder:
		_drop(slot, by_slot)
	super.on_fighter_knocked_out(slot, by_slot)


func on_credited_knockout(attacker: int, victim: int) -> void:
	if victim == _holder:
		_drop(victim, attacker)


func on_fighter_fell(slot: int) -> void:
	if slot == _holder:
		_drop(slot, -1)
	super.on_fighter_fell(slot)


func _drop(slot: int, by_slot: int) -> void:
	var f := ctx.fighter(slot)
	if f != null and is_instance_valid(f):
		f.carrying = 0
		f.can_attack = true
	_clear_mark()
	if _holder == slot:
		_holder = -1
	if by_slot >= 0 and by_slot != slot:
		ctx.bump_detail(by_slot, "steals")
	var arena := ctx.arena as Arena
	var from: Vector3 = f.global_position if f != null and is_instance_valid(f) else ctx.arena_center()
	if arena != null and not arena.is_inside(from, 1.0):
		# Dropped over the edge: put it back in play rather than lose it.
		_respawn = 0.6
		return
	_spawn_relic(from + Vector3(0, 1.1, 0))
	if _relic != null and is_instance_valid(_relic):
		_relic.scatter_from(from, slot, ctx.rng)
	AudioManager.play_sfx("crate_break", from)


func _build_mark(f: Fighter) -> void:
	_clear_mark()
	if DisplayServer.get_name() == "headless":
		return
	_mark = Node3D.new()
	_mark.name = "RelicMark"
	ctx.world_root.add_child(_mark)
	var crown := MeshFactory.torus(0.3, 0.52, RELIC_COLOR, 1.8)
	_mark.add_child(crown)
	var spark := MeshFactory.sphere(0.18, Color(1.0, 0.95, 0.7), 2.4)
	spark.position = Vector3(0, 0.2, 0)
	_mark.add_child(spark)
	_mark.global_position = f.global_position + Vector3(0, 2.3, 0)


func _clear_mark() -> void:
	if _mark != null and is_instance_valid(_mark):
		_mark.queue_free()
	_mark = null


func _name_of(slot: int) -> String:
	var p := ctx.config.player_at(slot)
	return p.display_name() if p != null else "P%d" % (slot + 1)


# --- shared-layer answers --------------------------------------------------

func holder() -> int:
	return _holder


func relic_position() -> Vector3:
	if _holder >= 0:
		var f := ctx.fighter(_holder)
		if f != null and is_instance_valid(f):
			return f.global_position
	if _relic != null and is_instance_valid(_relic):
		return _relic.global_position
	return ctx.arena_center()


func hud_value(slot: int) -> String:
	return "%d%s" % [ctx.scores[slot], "  ✦" if slot == _holder else ""]


func hud_banner() -> String:
	if _holder < 0:
		return Loc.t("relic.loose")
	return Loc.t("relic.holding", {"name": _name_of(_holder)})


func max_carry() -> int:
	return 1


func ai_script() -> Script:
	return load("res://src/ai/brains/relic_brain.gd")


func detail_rows() -> Array:
	return [
		{"key": "results.stat.steals", "field": "steals"},
		{"key": "results.stat.knockouts", "field": "knockouts"},
	]


func cleanup() -> void:
	_clear_mark()
	if _relic != null and is_instance_valid(_relic):
		Pool.release(POOL_KEY, _relic)
	_relic = null
