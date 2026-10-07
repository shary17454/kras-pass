extends "res://src/ai/brains/generic_brain.gd"
## Crumble Court: keep moving toward solid ground.
##
## The bot evaluates the tiles around it exactly as they are drawn — solid,
## shaking, gone — and heads for the nearest solid one that is not directly
## under a rival. `edge_awareness` governs how far ahead it plans, so Easy bots
## routinely paint themselves into a corner.

var _target_tile: ArenaTile
var _warning_tile: ArenaTile
var _warning_seen_at := 0.0
var _rival_warning_tile: ArenaTile
var _rival_warning_seen_at := 0.0


func on_round_start() -> void:
	super.on_round_start()
	_target_tile = null
	_warning_tile = null
	_warning_seen_at = 0.0
	_rival_warning_tile = null
	_rival_warning_seen_at = 0.0


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return

	var current := _ground_tile(arena, me.global_position)
	if can_observe(current) and current.state == ArenaTile.State.WARNING:
		if current != _warning_tile:
			_warning_tile = current
			_warning_seen_at = _time
	else:
		_warning_tile = null
	var unsafe := current == null or current.state != ArenaTile.State.SOLID
	if not can_observe(_target_tile) or _target_tile.state != ArenaTile.State.SOLID:
		_target_tile = _pick_tile(arena, me.global_position)
	# Keep ground control when the next visible step is fresh; jump to rescue
	# a trapped route rather than hop on every floor warning.
	if _warning_tile != null and _time - _warning_seen_at >= reaction_time and me.is_on_floor() \
			and (not can_observe(_target_tile) or _target_tile.state != ArenaTile.State.SOLID):
		maybe_jump(edge_awareness)

	if can_observe(_target_tile):
		var offset := Vector2(_target_tile.global_position.x - me.global_position.x,
			_target_tile.global_position.z - me.global_position.z)
		var speed := me.top_speed * float(me.mods["speed"]) * float(me.mutator["speed"])
		var planar_velocity := Vector2(me.velocity.x, me.velocity.z)
		var control := 1.0 if me.is_on_floor() else me.air_control
		var braking_distance := planar_velocity.length_squared() / maxf(2.0 * me.acceleration * control, 0.001)
		# Input is held until the next ordinary decision; brake before overshooting.
		var arrival_distance := maxf(0.25, speed * decision_interval * 1.15 + braking_distance)
		steer_to(_target_tile.global_position, minf(1.0, offset.length() / arrival_distance))
		if unsafe and distance_to(_target_tile.global_position) > 2.4:
			maybe_dash(1.5)
	else:
		steer_to(me.global_position)

	# Opportunistic shove: a rival standing on shaking ground is one nudge from
	# being gone.
	var rival := nearest_rival()
	var in_range := rival >= 0 and distance_to(perceive(rival)) < 2.6
	var their_tile: ArenaTile = arena.tile_at(perceive(rival)) if in_range else null
	var warning_ready := _rival_warning_ready(their_tile)
	if in_range:
		if warning_ready:
			maybe_attack(rival, 2.6)
		elif rng.randf() < aggression * 0.5:
			maybe_attack(rival, 2.6)


func _rival_warning_ready(tile: ArenaTile) -> bool:
	if not can_observe(tile) or tile.state == ArenaTile.State.SOLID:
		_rival_warning_tile = null
		return false
	if tile != _rival_warning_tile:
		_rival_warning_tile = tile
		_rival_warning_seen_at = _time
	return _time - _rival_warning_seen_at + 0.000001 >= reaction_time


func _pick_tile(arena: Arena, from: Vector3) -> ArenaTile:
	var origin := _ground_tile(arena, from)
	if origin == null:
		return null
	var visible_ground := {}
	for tile in arena.tiles:
		if can_observe(tile) and tile.is_standable():
			visible_ground[Vector2i(tile.grid_x, tile.grid_z)] = tile
	var start := Vector2i(origin.grid_x, origin.grid_z)
	# Cardinal steps cannot cut diagonally across the corner of a missing tile.
	var first_steps := {start: origin}
	var pending: Array[ArenaTile] = [origin]
	var cursor := 0
	while cursor < pending.size():
		var tile := pending[cursor]
		cursor += 1
		var cell := Vector2i(tile.grid_x, tile.grid_z)
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if first_steps.has(next) or not visible_ground.has(next):
				continue
			var neighbour: ArenaTile = visible_ground[next]
			if Vector2(neighbour.global_position.x - from.x, neighbour.global_position.z - from.z).length() > 12.0:
				continue
			first_steps[next] = neighbour if cell == start else first_steps[cell]
			pending.append(neighbour)
	var candidates: Array[ArenaTile] = []
	var best_score := -INF
	for cell in first_steps:
		var t: ArenaTile = visible_ground.get(cell)
		if t == null or t.state != ArenaTile.State.SOLID:
			continue
		var d: float = Vector2(t.global_position.x - from.x, t.global_position.z - from.z).length()
		if d > 12.0:
			continue
		var score := -d
		# Prefer tiles with solid neighbours: a lone island is a death sentence.
		score += _solid_neighbours(arena, t, visible_ground) * lerp(0.4, 2.4, edge_awareness)
		var step: ArenaTile = first_steps[cell]
		# A promising destination cannot make its shaking first step safe.
		# Keep it as a fallback, but favour escaping onto untouched ground.
		if step.state == ArenaTile.State.WARNING:
			score -= 24.0 * edge_awareness
		if _occupied(t):
			score -= 4.0
		if candidates.is_empty() or (score > best_score and not is_equal_approx(score, best_score)):
			best_score = score
			candidates.clear()
			candidates.append(step)
		elif is_equal_approx(score, best_score) and step not in candidates:
			candidates.append(step)
	if candidates.is_empty():
		return null
	if candidates.size() == 1:
		return candidates[0]
	# A route with several equally good destinations still gets one vote.
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _ground_tile(arena: Arena, from: Vector3) -> ArenaTile:
	var nearest := arena.tile_at(from)
	if can_observe(nearest) and nearest.is_standable():
		return nearest
	var me := self_body()
	if me == null or not me.is_on_floor() or me.global_position.distance_to(from) > 0.01:
		return null
	var reach := 0.52
	var shape := me.get_node_or_null("Body") as CollisionShape3D
	if shape != null and shape.shape is CapsuleShape3D:
		reach = (shape.shape as CapsuleShape3D).radius + 0.1
	# A capsule may still stand on the visible neighbour of the nearest hole.
	# Read only its own current contact; stale/hidden support cannot form a route.
	for index in me.get_slide_collision_count():
		var contact := me.get_slide_collision(index)
		if contact.get_normal().dot(me.up_direction) < cos(me.floor_max_angle) \
				or contact.get_position().distance_to(from) > reach:
			continue
		var tile := contact.get_collider() as ArenaTile
		if tile in arena.tiles and can_observe(tile) and tile.is_standable():
			return tile
	return null


func _solid_neighbours(arena: Arena, tile: ArenaTile, visible_ground: Dictionary = {}) -> float:
	if visible_ground.is_empty():
		visible_ground = {}
		for t in arena.tiles:
			if can_observe(t) and t.state == ArenaTile.State.SOLID:
				visible_ground[Vector2i(t.grid_x, t.grid_z)] = t
	var n := 0.0
	for x in range(-1, 2):
		for z in range(-1, 2):
			var t: ArenaTile = visible_ground.get(Vector2i(tile.grid_x + x, tile.grid_z + z))
			if t != null and t != tile and t.state == ArenaTile.State.SOLID:
				n += 1.0
	return n


func _occupied(tile: ArenaTile) -> bool:
	for i in ctx.fighters.size():
		if i == slot or not can_target(i):
			continue
		if perceive(i).distance_to(tile.global_position) < 1.2:
			return true
	return false
