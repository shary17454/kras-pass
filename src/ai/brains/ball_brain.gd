extends AIBrain
## Blast Ball: keep away from the bomb, or shove it at someone else.
##
## The trade-off is real for a human too — the only way to move the ball is to
## touch it, and touching it late is how you get caught by the blast.

var _tree: SceneTree


func on_configured() -> void:
	_tracks_balls = true
	_tree = Engine.get_main_loop() as SceneTree


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return
	var ball := _ball()
	if ball == null:
		steer_to(arena.global_position)
		return

	var observed := perceive_ball(ball)
	var position := _anticipated_position(observed)
	var fuse: float = observed["fuse"]
	if fuse < 0.0:
		steer_to(arena.global_position)
		return
	# The displayed countdown was sampled before the reaction delay elapsed.
	fuse = maxf(0.0, fuse - maxf(0.0, float(observed.get("age", 0.0))))
	var dist := me.global_position.distance_to(position)
	var walk_speed := me.top_speed * float(me.mods["speed"]) * float(me.mutator["speed"])
	# Aggression does not buy escape time. Better planning tempers risk and
	# reserves movement plus the next decision before committing to contact.
	var blast_radius := Balance.num("tuning", "ball.explosive_radius", 5.0)
	var escape_time := blast_radius / maxf(walk_speed, 0.1)
	var commit_window: float = lerp(2.4, 1.1, risk * (1.0 - strategy)) \
		+ reaction_time + decision_interval + escape_time
	# Deflection requires contact, not the attack button's three-metre range.
	# Reserve the approach using visible ball size and our own collision body.
	var contact_distance := maxf(0.0, float(observed.get("radius", 0.0)))
	var body := me.get_node_or_null("Body") as CollisionShape3D
	if body != null and body.shape is CapsuleShape3D:
		var scale_size := body.global_basis.get_scale().abs()
		contact_distance += body.shape.radius * maxf(scale_size.x, scale_size.z)
	var travel_time := maxf(0.0, dist - contact_distance) / maxf(walk_speed, 0.1)
	# These are our own status timers; Fighter cannot steer until both expire.
	var movement_delay := maxf(maxf(0.0, me._stun), maxf(0.0, float(me.mods["frozen"])))

	var approach := fuse > commit_window + travel_time + movement_delay and dist < 9.0 and rng.randf() < aggression + 0.25
	var push_from: Vector3 = position
	if approach:
		# Approach from the side opposite the rival we want to send it toward.
		var victim := _best_victim(position)
		if victim >= 0:
			var dir: Vector3 = perceive(victim) - position
			dir.y = 0.0
			if dir.length() > 0.5:
				dir = dir.normalized()
				push_from = position - dir * 1.4
				var alignment := me.global_position - push_from
				alignment.y = 0.0
				# The ball deflects on contact, not on an attack at a distance.
				# Once lined up, cross its visible position instead of parking
				# beyond the combined ball/player collision radii.
				if alignment.length() < 0.9:
					push_from = position + dir * 0.8
				else:
					# Fund the selected line-up route and subsequent contact, not
					# the shorter direct path we are no longer steering along.
					travel_time = (alignment.length() + maxf(0.0, 1.4 - contact_distance)) / maxf(walk_speed, 0.1)
					approach = fuse > commit_window + travel_time + movement_delay
	if approach:
		steer_to(push_from)
		if dist < 3.0:
			tap(Btn.ATTACK)
		if dist > 5.0:
			maybe_dash(0.8)
		keep_off_edge(2.4)
	else:
		var escape_position := _estimated_position_now(observed)
		_escape_observed_ball(escape_position)
		if me.global_position.distance_to(escape_position) < 5.0:
			maybe_dash(1.3)


func _anticipated_position(observed: Dictionary) -> Vector3:
	# Estimate from successive visible samples; never read private momentum.
	var horizon := minf(0.35, reaction_time + decision_interval) * prediction
	return Vector3(observed["position"]) + Vector3(observed.get("velocity", Vector3.ZERO)) * horizon


func _estimated_position_now(observed: Dictionary) -> Vector3:
	# Leading an interception is useful; leading radial escape can invert it
	# before a fast incoming ball actually crosses us. Advance only sample age.
	var age := maxf(0.0, float(observed.get("age", reaction_time)))
	var horizon := minf(0.35, age) * prediction
	return Vector3(observed["position"]) + Vector3(observed.get("velocity", Vector3.ZERO)) * horizon


func _escape_observed_ball(position: Vector3) -> void:
	steer_away(position)
	if move.length_squared() < 0.001:
		move = Vector2.RIGHT
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null or arena.edge_distance(me.global_position) > 2.4:
		return
	if rng.randf() > edge_awareness:
		return
	var walk_speed := me.top_speed * float(me.mods["speed"]) * float(me.mutator["speed"])
	var step := maxf(0.75, walk_speed * decision_interval)
	var best := Vector2.ZERO
	var separation := -INF
	# Edge correction must not blindly steer toward the approaching bomb.
	# Compare bounded next steps using visible geometry and the observed cue.
	for angle in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, PI * 0.75, -PI * 0.75, PI]:
		var direction := move.normalized().rotated(angle)
		var target := me.global_position + Vector3(direction.x, 0, direction.y) * step
		if not arena.is_inside(target, 0.15):
			continue
		var distance := target.distance_squared_to(position)
		if distance > separation:
			separation = distance
			best = direction
	if best != Vector2.ZERO:
		move = best
	else:
		steer_to(arena.retreat_point(me.global_position))


func _ball() -> GameBall:
	if _tree == null:
		return null
	for b in _tree.get_nodes_in_group("balls"):
		if b is GameBall and can_observe(b) and not perceive_ball(b).is_empty():
			return b
	return null


## Prefer sending the bomb at whoever is nearest the ball but not us.
func _best_victim(from: Vector3) -> int:
	var candidates: Array[int] = []
	var best_d := INF
	for i in ctx.fighters.size():
		if i == slot or not can_target(i):
			continue
		var d: float = perceive(i).distance_squared_to(from)
		if is_equal_approx(d, best_d):
			candidates.append(i)
		elif d < best_d:
			best_d = d
			candidates.assign([i])
	if candidates.is_empty():
		return -1
	return candidates[0] if candidates.size() == 1 else candidates[rng.randi_range(0, candidates.size() - 1)]
