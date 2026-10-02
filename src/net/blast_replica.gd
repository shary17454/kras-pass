extends RefCounted
## Presentation only. Fuse, contacts, eliminations and rearming belong to host.
const Number = preload("res://src/net/goal_guard_replica.gd")
var explosion_sequence := -1


static func capture(game: Node) -> Dictionary:
	var ball: GameBall = game.ball
	return {"position": Number._vec(ball.global_position),
		"velocity": Number._vec(ball.velocity), "generation": ball.launch_generation,
		"fuse": maxf(0.0, ball.fuse), "fuse_max": ball.fuse_max,
		"detonated": ball.detonated, "explosion_sequence": game.explosion_sequence,
		"explosion_position": Number._vec(game.explosion_position)}


static func valid(world: Variant) -> bool:
	if not world is Dictionary or not world.get("detonated") is bool:
		return false
	for key in ["position", "velocity", "explosion_position"]:
		if not world.get(key) is Array or world[key].size() != 3:
			return false
		for value in world[key]:
			if not Number._number(value) or absf(value) > 10000.0:
				return false
	for key in ["generation", "explosion_sequence"]:
		if not Number._number(world.get(key)) or world[key] != floorf(world[key]) \
				or world[key] < 0 or world[key] > 1000000:
			return false
	if not Number._number(world.get("fuse")) or not Number._number(world.get("fuse_max")):
		return false
	if world.fuse_max <= 0 or world.fuse_max > 60 or world.fuse < 0 or world.fuse > world.fuse_max:
		return false
	return not world.detonated or world.fuse == 0


func render(game: Node, world: Dictionary, delta: float, snap: bool, play_events: bool) -> void:
	var ball: GameBall = game.ball
	ball.set_monitoring(false)
	ball.collision_layer = 0
	ball.collision_mask = 0
	var position := Vector3(world.position[0], world.position[1], world.position[2])
	var teleport := snap or ball.launch_generation != int(world.generation) \
		or ball.global_position.distance_to(position) > 6.0
	ball.global_position = position if teleport else ball.global_position.lerp(position, clampf(delta * 22.0, 0.0, 1.0))
	ball.velocity = Vector3(world.velocity[0], world.velocity[1], world.velocity[2])
	ball.speed = ball.velocity.length()
	ball.launch_generation = int(world.generation)
	ball.fuse = float(world.fuse)
	ball.fuse_max = float(world.fuse_max)
	ball.detonated = world.detonated
	ball._update_fuse_visual()
	ball.visible = not ball.detonated
	if play_events and explosion_sequence >= 0 and int(world.explosion_sequence) > explosion_sequence:
		game.present_explosion(Vector3(world.explosion_position[0], world.explosion_position[1], world.explosion_position[2]))
	explosion_sequence = maxi(explosion_sequence, int(world.explosion_sequence))
