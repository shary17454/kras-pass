extends "res://src/ai/brains/generic_brain.gd"
## Rising Tide: go up, and push whoever is above you back down.

var _ledge_target := Vector3.INF


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return
	var water := arena.water_level()
	var urgency := clampf(3.0 / maxf(0.4, me.global_position.y - water), 0.2, 1.0)

	# A rival directly above is worth attacking: knocking them down costs them
	# far more than the detour costs us.
	var above := _rival_above()
	if above >= 0 and rng.randf() < aggression * 0.8:
		steer_to(predict(above, 0.25))
		maybe_attack(above, 2.5)
		maybe_jump(0.5)
		return

	if _ledge_target == Vector3.INF or me.global_position.distance_to(_ledge_target) < 1.6:
		_ledge_target = _find_higher_ground(me.global_position)
	steer_to(_ledge_target, urgency)
	# Jump when close to the ledge edge; the exact window is skill-scaled.
	var flat := Vector2(_ledge_target.x - me.global_position.x, _ledge_target.z - me.global_position.z).length()
	if _ledge_target.y > me.global_position.y + 0.6 and flat < lerp(3.4, 2.0, accuracy):
		press(Btn.JUMP)
	if flat > 6.0:
		maybe_dash(0.6)


func _rival_above() -> int:
	var me := self_body()
	if me == null:
		return -1
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i):
			continue
		var p := perceive(i)
		if p.y > me.global_position.y + 0.8 and Vector2(p.x - me.global_position.x, p.z - me.global_position.z).length() < 4.0:
			return i
	return -1


## Nearest static body whose top is above us. Uses the same visible geometry a
## player reads, not a hand-authored path.
func _find_higher_ground(from: Vector3) -> Vector3:
	var arena := ctx.arena as Arena
	if arena == null:
		return from
	var best := from
	var best_score := -INF
	for node in arena.get_node_or_null("Static").get_children() if arena.has_node("Static") else []:
		if not (node is Node3D):
			continue
		var p: Vector3 = node.global_position
		if p.y <= from.y + 0.4:
			continue
		var dist := Vector2(p.x - from.x, p.z - from.z).length()
		if dist > 14.0:
			continue
		var score := (p.y - from.y) * 2.0 - dist * 0.5
		if score > best_score:
			best_score = score
			best = p + Vector3(0, 1.0, 0)
	if best == from:
		return arena.global_position + Vector3(0, from.y, 0)
	return best
