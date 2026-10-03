extends AIBrain
## Goal Guard: stay on your line, intercept, aim clearances at rivals.
##
## Interception uses delayed visible position samples and their inferred motion.

var _goal_axis := Vector3.RIGHT
var _goal_pos := Vector3.ZERO
var _goal_normal := Vector3.FORWARD
var _lane_limit := 0.0
var _tree: SceneTree


func on_configured() -> void:
	_tracks_balls = true
	_tree = Engine.get_main_loop() as SceneTree
	var arena := ctx.arena as Arena
	if arena == null:
		return
	var side: int = controller.side_for(slot) if controller.has_method("side_for") else slot % 4
	var r := arena.def.radius - 2.2
	var spots := [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]
	_goal_pos = arena.global_position + spots[side]
	_goal_axis = Vector3.FORWARD if side < 2 else Vector3.RIGHT
	_goal_normal = (arena.global_position - _goal_pos).normalized()
	_lane_limit = maxf(0.0, arena.def.radius - 2.0)


func decide(_delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		return
	var ball := _most_dangerous_ball()
	if ball == null:
		steer_to(_goal_pos)
		return
	var observed := perceive_ball(ball)
	var position: Vector3 = observed["position"]
	var velocity: Vector3 = observed["velocity"]

	# Sphere contact occurs ahead of the player's lane, at the shield.
	var contact_plane := _goal_pos
	if controller.has_method("keeper_contact_offset"):
		contact_plane += _goal_normal * controller.keeper_contact_offset(float(observed.get("radius", 0.0)))
	var lead := 0.0
	var normal_speed := velocity.dot(_goal_normal)
	if absf(normal_speed) > 0.001:
		var arrival := (contact_plane - position).dot(_goal_normal) / normal_speed
		if arrival > 0.0:
			lead = lerpf(minf(0.05, arrival), minf(arrival, 3.0), prediction)
	var future: Vector3 = position + velocity * lead
	var along := clampf(_goal_axis.dot(future - _goal_pos), -_lane_limit, _lane_limit)
	var intercept := _goal_pos + _goal_axis * along
	# Goal Guard constrains all keepers to this lane, including human players.
	var closing := me.global_position.distance_to(position)
	steer_to(intercept)

	if closing < 2.8 and rng.randf() < attack_chance:
		press(Btn.ATTACK)
		# Face a rival's goal so the clearance is a shot, not a giveaway.
		var victim := leader_rival()
		if victim >= 0:
			var to := perceive(victim) - me.global_position
			aim = Vector2(to.x, to.z).normalized()
	if closing < 5.0 and closing > 2.5:
		maybe_dash(1.1)


func _most_dangerous_ball() -> GameBall:
	if _tree == null:
		return null
	var best: GameBall = null
	var best_score := -INF
	for node in _tree.get_nodes_in_group("balls"):
		var b := node as GameBall
		if not can_observe(b):
			continue
		var observed := perceive_ball(b)
		if observed.is_empty():
			continue
		var to: Vector3 = _goal_pos - Vector3(observed["position"])
		var dist := to.length()
		if dist < 0.01:
			continue
		# Threat = how directly it is travelling at our goal, over distance.
		var heading: float = Vector3(observed["velocity"]).normalized().dot(to.normalized())
		var score: float = heading * 12.0 - dist * 0.35
		if score > best_score:
			best_score = score
			best = b
	return best
