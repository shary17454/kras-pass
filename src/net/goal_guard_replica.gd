extends RefCounted
## Host-owned ball state. Array slots are stable until a round reset; launch
## generations distinguish a goal teleport from ordinary interpolated travel.

static func capture(game: Node) -> Dictionary:
	var rows: Array = []
	for ball: GameBall in game.balls:
		rows.append({"position": _vec(ball.global_position), "velocity": _vec(ball.velocity),
			"heavy": ball.heavy, "generation": ball.launch_generation})
	return {"balls": rows, "charges": Array(game.charges)}


static func valid(data: Variant, count: int, extra_balls: int = 0) -> bool:
	if count < 2 or count > 4 or not data is Dictionary:
		return false
	if not data.get("balls") is Array or data.balls.is_empty() or data.balls.size() > count + extra_balls:
		return false
	if not data.get("charges") is Array or data.charges.size() != count:
		return false
	for charge in data.charges:
		if not _number(charge) or charge < 0.0 or charge > 1.0:
			return false
	for row in data.balls:
		if not row is Dictionary or not row.get("heavy") is bool:
			return false
		var generation: Variant = row.get("generation")
		if not _number(generation) or generation != floorf(float(generation)) \
				or generation < 0 or generation > 1000000:
			return false
		for key in ["position", "velocity"]:
			if not row.get(key) is Array or row[key].size() != 3:
				return false
			for value in row[key]:
				if not _number(value) or absf(float(value)) > 10000.0:
					return false
	return true


static func render(game: Node, data: Dictionary, delta: float, snap: bool) -> void:
	while game.balls.size() > data.balls.size():
		var removed: GameBall = game.balls.pop_back()
		removed.hide()
		removed.queue_free()
	while game.balls.size() < data.balls.size():
		var created := GameBall.new()
		game.ctx.world_root.add_child(created)
		created.launch_generation = -1
		game.balls.append(created)
	for i in data.balls.size():
		var ball: GameBall = game.balls[i]
		var row: Dictionary = data.balls[i]
		# Replica balls never participate in local rules or collision detection.
		ball.set_monitoring(false)
		ball.collision_layer = 0
		ball.collision_mask = 0
		if ball._mesh == null or ball.heavy != bool(row.heavy):
			ball.configure(Color("#ff8470") if row.heavy else Color("#fbe5a0"), 0.72, row.heavy)
		var position := Vector3(row.position[0], row.position[1], row.position[2])
		var teleport := snap or ball.launch_generation != int(row.generation) \
			or ball.global_position.distance_to(position) > 6.0
		ball.global_position = position if teleport else ball.global_position.lerp(position, clampf(delta * 22.0, 0.0, 1.0))
		ball.velocity = Vector3(row.velocity[0], row.velocity[1], row.velocity[2])
		ball.speed = ball.velocity.length()
		ball.launch_generation = int(row.generation)
		ball._mesh.rotate_x(delta * ball.speed * 0.35)
	for slot in game.ctx.player_count():
		game.charges[slot] = float(data.charges[slot])
		var fighter: Fighter = game.ctx.fighter(slot)
		var side: int = game.side_for(slot)
		var paddle: Node3D = game.paddles[slot]
		paddle.visible = fighter.visible and fighter.alive
		paddle.global_position = fighter.global_position + game.NORMALS[side] * 0.8
		paddle.rotation.y = PI * 0.5 if side < 2 else 0.0
		paddle.scale.x = 1.25 if fighter.is_attacking() else 1.0


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
