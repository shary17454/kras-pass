extends AIBrain
## Blast Ball: keep away from the bomb, or shove it at someone else.
##
## The trade-off is real for a human too — the only way to move the ball is to
## touch it, and touching it late is how you get caught by the blast.

var _tree: SceneTree


func on_configured() -> void:
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

	var fuse: float = ball.fuse
	var dist := me.global_position.distance_to(ball.global_position)
	# How long a bot is willing to stay near the bomb scales with risk and with
	# how quickly it can react if things go wrong.
	var commit_window: float = lerp(2.4, 1.1, risk) + reaction_time

	if fuse > commit_window and dist < 9.0 and rng.randf() < aggression + 0.25:
		# Approach from the side opposite the rival we want to send it toward.
		var victim := _best_victim(ball.global_position)
		var push_from: Vector3 = ball.global_position
		if victim >= 0:
			var dir: Vector3 = perceive(victim) - ball.global_position
			dir.y = 0.0
			if dir.length() > 0.5:
				push_from = ball.global_position - dir.normalized() * 1.4
		steer_to(push_from)
		if dist < 3.0:
			press(Btn.ATTACK)
		if dist > 5.0:
			maybe_dash(0.8)
	else:
		steer_away(ball.global_position)
		if dist < 5.0:
			maybe_dash(1.3)
	keep_off_edge(2.4)


func _ball() -> GameBall:
	if _tree == null:
		return null
	for b in _tree.get_nodes_in_group("balls"):
		if is_instance_valid(b):
			return b
	return null


## Prefer sending the bomb at whoever is nearest the ball but not us.
func _best_victim(from: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i):
			continue
		var d: float = perceive(i).distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = i
	return best
