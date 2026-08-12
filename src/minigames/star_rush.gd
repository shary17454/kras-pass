extends MiniGameController
## Star Rush — carry it home or lose it.
##
## Stars are worthless until deposited at your own base, and a hit drops
## everything you are carrying. The risk/reward dial is "one more star before I
## bank", which is the most re-playable decision in the whole collection.

const POOL_KEY := "star"
const MAX_CARRY := 8

var _items: Array[Collectible] = []
var _bases: Array = []
var _spawn_timer := 0.0


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	Pool.define(POOL_KEY, func(): return Collectible.new(), 14)
	var arena := ctx.arena as Arena
	for i in ctx.player_count():
		_bases.append(_make_base(arena, i))
	for i in 6:
		_spawn_star()


func _make_base(arena: Arena, slot: int) -> Dictionary:
	var ang := TAU * float(slot) / float(maxi(1, ctx.player_count())) - PI * 0.5
	var r := arena.def.radius * 0.82
	var pos := arena.global_position + Vector3(cos(ang) * r, 0.06, sin(ang) * r)
	var col := UIKit.adapt(ctx.config.players[slot].color())
	var pad := MeshFactory.cylinder(2.1, 0.16, col, 0.8, 24)
	pad.position = pos
	ctx.world_root.add_child(pad)
	var ring := MeshFactory.torus(2.0, 2.3, col, 1.2)
	ring.position = pos + Vector3(0, 0.1, 0)
	ctx.world_root.add_child(ring)
	return {"slot": slot, "pos": pos, "radius": 2.3}


func _spawn_star() -> void:
	var arena := ctx.arena as Arena
	var item: Collectible = Pool.acquire(POOL_KEY)
	if item == null:
		return
	if item.get_parent() == null:
		ctx.world_root.add_child(item)
	item.configure("star", Color("#ffe066"), 1, 0.34)
	if not item.taken.is_connected(_on_taken):
		item.taken.connect(_on_taken)
	item.add_to_group("pickups")
	var ang := ctx.rng.randf() * TAU
	var r := sqrt(ctx.rng.randf()) * arena.def.radius * 0.6
	item.place(arena.global_position + Vector3(cos(ang) * r, 1.1, sin(ang) * r))
	if not _items.has(item):
		_items.append(item)


func tick(delta: float) -> void:
	for item in _items:
		if is_instance_valid(item):
			item.tick(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 1.3
		if _live_count() < 8:
			_spawn_star()
	_check_deposits()


func _live_count() -> int:
	var n := 0
	for i in _items:
		if is_instance_valid(i) and i.available:
			n += 1
	return n


func _check_deposits() -> void:
	for base in _bases:
		var slot: int = base["slot"]
		var f := ctx.fighter(slot)
		if f == null or not is_instance_valid(f) or f.carrying <= 0:
			continue
		var to: Vector3 = f.global_position - base["pos"]
		to.y = 0.0
		if to.length() > float(base["radius"]):
			continue
		var gain := int(maxf(1.0, f.carrying * ctx.powerups.point_multiplier(slot)))
		ctx.add_score(slot, gain)
		ctx.bump_detail(slot, "deposits", f.carrying)
		f.carrying = 0
		AudioManager.play_sfx("score")
		EventBus.shake(0.15, 0.15)


func _on_taken(item: Collectible, slot: int) -> void:
	Pool.release(POOL_KEY, item)
	_items.erase(item)
	var f := ctx.fighter(slot)
	if f != null and is_instance_valid(f):
		f.carrying = mini(MAX_CARRY, f.carrying + item.value)
	AudioManager.play_sfx("pickup")


func on_fighter_knocked_out(slot: int, by_slot: int) -> void:
	_spill(slot, by_slot)


func on_credited_knockout(attacker: int, victim: int) -> void:
	_spill(victim, attacker)


func _spill(slot: int, by_slot: int) -> void:
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f) or f.carrying <= 0:
		return
	var dropped: int = f.carrying
	f.carrying = 0
	if by_slot >= 0 and by_slot != slot:
		ctx.bump_detail(by_slot, "knockouts")
	for i in mini(dropped, 6):
		var item: Collectible = Pool.acquire(POOL_KEY)
		if item == null:
			break
		if item.get_parent() == null:
			ctx.world_root.add_child(item)
		item.configure("star", Color("#ffe066"), maxi(1, dropped / 6), 0.34)
		if not item.taken.is_connected(_on_taken):
			item.taken.connect(_on_taken)
		item.add_to_group("pickups")
		item.scatter_from(f.global_position, slot, ctx.rng)
		if not _items.has(item):
			_items.append(item)
	AudioManager.play_sfx("crate_break", f.global_position)


func is_round_over() -> bool:
	return ctx.early_finish


func hud_value(slot: int) -> String:
	var f := ctx.fighter(slot)
	var carried: int = f.carrying if f != null and is_instance_valid(f) else 0
	return "%d  (+%d)" % [ctx.scores[slot], carried] if carried > 0 else str(ctx.scores[slot])


func ai_script() -> Script:
	return load("res://src/ai/brains/courier_brain.gd")


func base_position(slot: int) -> Vector3:
	for base in _bases:
		if int(base["slot"]) == slot:
			return base["pos"]
	return ctx.arena_center()


func detail_rows() -> Array:
	return [
		{"key": "results.stat.deposits", "field": "deposits"},
		{"key": "results.stat.knockouts", "field": "knockouts"},
	]


func cleanup() -> void:
	for item in _items:
		if is_instance_valid(item):
			Pool.release(POOL_KEY, item)
	_items.clear()
