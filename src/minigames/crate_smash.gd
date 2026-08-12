extends MiniGameController
## Crate Smash — points for breaking things, minus the ones that break you.
##
## About one crate in five is rigged. They look different, but only if you are
## paying attention while three rivals are swinging next to you — which is the
## whole joke.

const POOL_KEY := "smash_crate"
const CRATE_POINTS := 2
const BOMB_PENALTY := 3
const BOMB_RATIO := 0.2
const FIELD_TARGET := 14

var _crates: Array = []
var _spawn_timer := 0.0


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	for i in FIELD_TARGET:
		_spawn_crate()


func _spawn_crate() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	var is_bomb := ctx.rng.randf() < BOMB_RATIO
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var colour := Color("#ffc46b") if not is_bomb else Color("#3a2b3f")
	var accent := Color("#fff0c2") if not is_bomb else Color("#ff5f8d")
	body.add_child(MeshFactory.crate(1.5, colour, accent))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.5, 1.5)
	cs.shape = box
	body.add_child(cs)
	ctx.world_root.add_child(body)
	for attempt in 20:
		var ang := ctx.rng.randf() * TAU
		var r := sqrt(ctx.rng.randf()) * arena.def.radius * 0.85
		var p := arena.global_position + Vector3(cos(ang) * r, 0.75, sin(ang) * r)
		if _spot_is_free(p):
			body.global_position = p
			break
		body.global_position = arena.global_position + Vector3(cos(ang) * r, 0.75, sin(ang) * r)
	body.add_to_group("crates")
	_crates.append({"node": body, "bomb": is_bomb})


func _spot_is_free(p: Vector3) -> bool:
	for c in _crates:
		var n = c["node"]
		if is_instance_valid(n) and n.global_position.distance_to(p) < 2.2:
			return false
	return true


func tick(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 1.1
		if _crates.size() < FIELD_TARGET:
			_spawn_crate()
	_check_swings()


func _check_swings() -> void:
	var reach := Balance.num("tuning", "fighter.attack_range", 2.15)
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f) or not f.is_attacking():
			continue
		var idx := _crates.size() - 1
		while idx >= 0:
			var entry = _crates[idx]
			var n = entry["node"]
			if not is_instance_valid(n):
				_crates.remove_at(idx)
				idx -= 1
				continue
			var to: Vector3 = n.global_position - f.global_position
			to.y = 0.0
			if to.length() <= reach + 0.6:
				_break_crate(idx, i)
				break
			idx -= 1


func _break_crate(index: int, slot: int) -> void:
	var entry = _crates[index]
	var n: Node3D = entry["node"]
	var is_bomb: bool = entry["bomb"]
	var pos: Vector3 = n.global_position
	_crates.remove_at(index)
	n.queue_free()
	if is_bomb:
		ctx.set_score(slot, maxi(0, ctx.scores[slot] - BOMB_PENALTY))
		ctx.bump_detail(slot, "mistakes")
		AudioManager.play_sfx("explode", pos)
		EventBus.shake(0.6, 0.35)
		var f := ctx.fighter(slot)
		if f != null and is_instance_valid(f):
			var away: Vector3 = f.global_position - pos
			away.y = 0.0
			f.take_hit(-1, away.normalized() if away.length() > 0.1 else Vector3.FORWARD, 16.0, 0.0)
		ctx.world_root.add_child(MeshFactory.burst(Color("#ff5f8d"), 16))
	else:
		var gain := int(CRATE_POINTS * ctx.powerups.point_multiplier(slot))
		ctx.add_score(slot, gain)
		ctx.bump_detail(slot, "crates")
		AudioManager.play_sfx("crate_break", pos)
		var burst := MeshFactory.burst(Color("#ffc46b"), 10)
		ctx.world_root.add_child(burst)
		burst.global_position = pos


func is_round_over() -> bool:
	return ctx.early_finish


func ai_script() -> Script:
	return load("res://src/ai/brains/smasher_brain.gd")


func detail_rows() -> Array:
	return [
		{"key": "results.stat.crates", "field": "crates"},
		{"key": "results.stat.mistakes", "field": "mistakes"},
	]


func crate_entries() -> Array:
	return _crates


func cleanup() -> void:
	for c in _crates:
		if is_instance_valid(c["node"]):
			c["node"].queue_free()
	_crates.clear()
