extends MiniGameController
## Crate Relay — one crate at a time, from the middle to your dock.
##
## You cannot fight while carrying, and a hit makes you drop it where you stand.
## The result is a constant push-and-pull along four lanes, which reads clearly
## on a cross-shaped arena even with four players moving at once.

const POOL_KEY := "relay_crate"
const DELIVER_POINTS := 3

var _items: Array[Collectible] = []
var _docks: Array = []
var _spawn_timer := 0.0
var _carry_marks := {}


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	Pool.define(POOL_KEY, func(): return Collectible.new(), 10)
	var arena := ctx.arena as Arena
	for i in ctx.player_count():
		_docks.append(_make_dock(arena, i))
	for i in 4:
		_spawn_crate()


func _make_dock(arena: Arena, slot: int) -> Dictionary:
	# Axis-aligned, matching Arena._build_cross(): the cross floor is a
	# plus-sign with no collision on the diagonals, so a dock placed off-axis
	# sits past the edge of the world. See the note in arena.gd.
	var ang := TAU * float(slot) / 4.0
	var r := arena.def.radius * 0.72
	var pos := arena.global_position + Vector3(cos(ang) * r, 0.1, sin(ang) * r)
	var col := UIKit.adapt(ctx.config.players[slot].color())
	var pad := MeshFactory.box(Vector3(3.4, 0.2, 3.4), col, 0.7)
	pad.position = pos
	ctx.world_root.add_child(pad)
	var f := ctx.fighter(slot)
	if f != null and is_instance_valid(f):
		f.global_position = pos + Vector3(0, 1.3, 0)
		f.set_spawn(pos + Vector3(0, 1.3, 0))
	return {"slot": slot, "pos": pos, "radius": 2.2}


func _spawn_crate() -> void:
	var arena := ctx.arena as Arena
	var item: Collectible = Pool.acquire(POOL_KEY)
	if item == null:
		return
	if item.get_parent() == null:
		ctx.world_root.add_child(item)
	item.configure("crate", Color("#ffc46b"), 1, 0.42)
	if not item.taken.is_connected(_on_taken):
		item.taken.connect(_on_taken)
	item.add_to_group("pickups")
	var ang := ctx.rng.randf() * TAU
	var r := ctx.rng.randf_range(0.0, 2.6)
	item.place(arena.global_position + Vector3(cos(ang) * r, 1.0, sin(ang) * r))
	if not _items.has(item):
		_items.append(item)


func tick(delta: float) -> void:
	for item in _items:
		if is_instance_valid(item):
			item.tick(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 2.2
		if _live_count() < 4:
			_spawn_crate()
	_check_deliveries()
	_update_carry_visuals()


func _live_count() -> int:
	var n := 0
	for i in _items:
		if is_instance_valid(i) and i.available:
			n += 1
	return n


func _on_taken(item: Collectible, slot: int) -> void:
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f) or f.carrying > 0:
		# Already carrying: leave the crate where it is.
		item.available = true
		item.monitoring = true
		return
	Pool.release(POOL_KEY, item)
	_items.erase(item)
	f.carrying = 1
	f.can_attack = false
	AudioManager.play_sfx("pickup", f.global_position)


func _check_deliveries() -> void:
	for dock in _docks:
		var slot: int = dock["slot"]
		var f := ctx.fighter(slot)
		if f == null or not is_instance_valid(f) or f.carrying <= 0:
			continue
		var to: Vector3 = f.global_position - dock["pos"]
		to.y = 0.0
		if to.length() > float(dock["radius"]):
			continue
		f.carrying = 0
		f.can_attack = true
		var gain := int(DELIVER_POINTS * ctx.powerups.point_multiplier(slot))
		ctx.add_score(slot, gain)
		ctx.bump_detail(slot, "deposits")
		AudioManager.play_sfx("score")


func _update_carry_visuals() -> void:
	for i in ctx.fighters.size():
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var has_mark: bool = _carry_marks.has(i)
		if f.carrying > 0 and not has_mark:
			var box := MeshFactory.crate(0.9, Color("#ffc46b"), Color("#fff0c2"))
			box.position = Vector3(0, 2.1, 0)
			f.add_child(box)
			_carry_marks[i] = box
		elif f.carrying <= 0 and has_mark:
			var mark = _carry_marks[i]
			if is_instance_valid(mark):
				mark.queue_free()
			_carry_marks.erase(i)


func on_fighter_knocked_out(slot: int, by_slot: int) -> void:
	_drop(slot, by_slot)


func on_credited_knockout(attacker: int, victim: int) -> void:
	_drop(victim, attacker)


func _drop(slot: int, by_slot: int) -> void:
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f) or f.carrying <= 0:
		return
	f.carrying = 0
	f.can_attack = true
	if by_slot >= 0 and by_slot != slot:
		ctx.bump_detail(by_slot, "knockouts")
	var item: Collectible = Pool.acquire(POOL_KEY)
	if item == null:
		return
	if item.get_parent() == null:
		ctx.world_root.add_child(item)
	item.configure("crate", Color("#ffc46b"), 1, 0.42)
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
	var carrying: bool = f != null and is_instance_valid(f) and f.carrying > 0
	return "%s%s" % [ctx.scores[slot], "  ▣" if carrying else ""]


func ai_script() -> Script:
	return load("res://src/ai/brains/courier_brain.gd")


## Only one crate at a time — `_on_taken` refuses a pickup while already
## carrying. The courier brain needs to know this exactly, or its "hold a few
## before banking" heuristic (tuned for Star Rush's stack of up to 8) never
## triggers and bots wander forever instead of delivering.
func max_carry() -> int:
	return 1


func base_position(slot: int) -> Vector3:
	for dock in _docks:
		if int(dock["slot"]) == slot:
			return dock["pos"]
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
