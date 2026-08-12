extends MiniGameController
## Gem Grab — collect, and defend what you collected.
##
## Gems bank instantly, but a solid hit knocks a share of your total back onto
## the floor. Leading is therefore dangerous, which keeps a runaway winner from
## deciding the round in the first twenty seconds.

const POOL_KEY := "gem"
const DROP_FRACTION := 0.35
const MAX_ON_FIELD := 14

var _items: Array[Collectible] = []
var _spawn_timer := 0.0


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	Pool.define(POOL_KEY, func(): return Collectible.new(), 16)
	for i in 8:
		_spawn_gem()


func _spawn_gem(at: Vector3 = Vector3.INF) -> void:
	if _live_count() >= MAX_ON_FIELD:
		return
	var arena := ctx.arena as Arena
	var item: Collectible = Pool.acquire(POOL_KEY)
	if item == null:
		return
	if item.get_parent() == null:
		ctx.world_root.add_child(item)
	item.configure("gem", UIKit.ACCENT, 1)
	if not item.taken.is_connected(_on_taken):
		item.taken.connect(_on_taken)
	item.add_to_group("pickups")
	var p := at
	if p == Vector3.INF:
		p = _random_spot(arena)
	item.place(p)
	if not _items.has(item):
		_items.append(item)


func _random_spot(arena: Arena) -> Vector3:
	for attempt in 16:
		var ang := ctx.rng.randf() * TAU
		var r := sqrt(ctx.rng.randf()) * arena.def.radius * 0.85
		var p := arena.global_position + Vector3(cos(ang) * r, 1.1, sin(ang) * r)
		# Islands arenas have holes; only accept a spot with ground beneath it.
		if _has_ground(p):
			return p
	return arena.global_position + Vector3(0, 1.1, 0)


func _has_ground(p: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2, 0), p - Vector3(0, 6, 0))
	q.collision_mask = 1
	return not space.intersect_ray(q).is_empty()


func _live_count() -> int:
	var n := 0
	for i in _items:
		if is_instance_valid(i) and i.available:
			n += 1
	return n


func tick(delta: float) -> void:
	for item in _items:
		if is_instance_valid(item):
			item.tick(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 1.6
		if _live_count() < 8:
			_spawn_gem()


func _on_taken(item: Collectible, slot: int) -> void:
	Pool.release(POOL_KEY, item)
	_items.erase(item)
	var gain := int(maxf(1.0, item.value * ctx.powerups.point_multiplier(slot)))
	ctx.add_score(slot, gain)
	ctx.bump_detail(slot, "collected", gain)
	AudioManager.play_sfx("pickup", Vector3.ZERO, 1.0 + minf(0.5, ctx.scores[slot] * 0.01))


func on_credited_knockout(attacker: int, victim: int) -> void:
	# A hit spills gems: the victim loses a share, and they land on the floor
	# for anyone to grab — including the victim, if they are quick.
	var loss := int(floor(ctx.scores[victim] * DROP_FRACTION))
	if loss <= 0:
		return
	ctx.set_score(victim, ctx.scores[victim] - loss)
	ctx.bump_detail(attacker, "knockouts")
	var f := ctx.fighter(victim)
	var origin: Vector3 = f.global_position if f != null and is_instance_valid(f) else ctx.arena_center()
	for i in mini(loss, 6):
		var item: Collectible = Pool.acquire(POOL_KEY)
		if item == null:
			break
		if item.get_parent() == null:
			ctx.world_root.add_child(item)
		item.configure("gem", UIKit.ACCENT, maxi(1, loss / 6))
		if not item.taken.is_connected(_on_taken):
			item.taken.connect(_on_taken)
		item.add_to_group("pickups")
		item.scatter_from(origin, victim, ctx.rng)
		if not _items.has(item):
			_items.append(item)
	AudioManager.play_sfx("crate_break", origin)


func on_fighter_knocked_out(slot: int, by_slot: int) -> void:
	# In this game a "knockout" is only a spill, never a removal.
	if by_slot >= 0 and by_slot != slot:
		on_credited_knockout(by_slot, slot)


func is_round_over() -> bool:
	return ctx.early_finish


func ai_script() -> Script:
	return load("res://src/ai/brains/collector_brain.gd")


func detail_rows() -> Array:
	return [
		{"key": "results.stat.collected", "field": "collected"},
		{"key": "results.stat.knockouts", "field": "knockouts"},
	]


func cleanup() -> void:
	for item in _items:
		if is_instance_valid(item):
			Pool.release(POOL_KEY, item)
	_items.clear()
