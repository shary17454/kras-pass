extends AIBrain
## Goal Guard: stay on your line, intercept, aim clearances at rivals.
##
## Interception uses `predict()`, so a low-skill keeper reacts to where the ball
## *was* and gets beaten by pace, while an Expert keeper meets it early. That is
## the honest way to model "better goalkeeping" without giving anyone the ball's
## exact velocity for free.

var _goal_axis := Vector3.RIGHT
var _goal_pos := Vector3.ZERO
var _tree: SceneTree


func on_configured() -> void:
	_tree = Engine.get_main_loop() as SceneTree
	var arena := ctx.arena as Arena
	if arena == null:
		return
	var side := slot % 4
	var r := arena.def.radius - 2.2
	var spots := [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]
	_goal_pos = arena.global_position + spots[side]
	_goal_axis = Vector3.FORWARD if side < 2 else Vector3.RIGHT


func decide(_delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		return
	var ball := _most_dangerous_ball()
	if ball == null:
		steer_to(_goal_pos)
		return

	# Stand between the ball and the goal, sliding along the goal line.
	var lead: float = lerp(0.05, 0.45, prediction)
	var future: Vector3 = ball.global_position + ball.velocity * lead
	var intercept := _goal_pos + _goal_axis * _goal_axis.dot(future - _goal_pos)
	# Step off the line to meet a ball that is already close, if brave enough.
	var closing := me.global_position.distance_to(ball.global_position)
	if closing < lerp(3.0, 7.0, risk):
		intercept = intercept.lerp(future, 0.6)
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
		if b == null or not is_instance_valid(b):
			continue
		var to: Vector3 = _goal_pos - b.global_position
		var dist := to.length()
		if dist < 0.01:
			continue
		# Threat = how directly it is travelling at our goal, over distance.
		var heading: float = b.velocity.normalized().dot(to.normalized())
		var score: float = heading * 12.0 - dist * 0.35
		if score > best_score:
			best_score = score
			best = b
	return best
