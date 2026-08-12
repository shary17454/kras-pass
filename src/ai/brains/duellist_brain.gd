extends "res://src/ai/brains/generic_brain.gd"
## Duel Pit: hunt the most damaged rival, back off when you are the fragile one.
##
## Damage percentages are shown on every player's HUD, so reading them is not
## hidden information — it is exactly the read a human makes before committing.


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return

	var margin := arena.edge_distance(me.global_position)
	var fragile: bool = me.damage_percent > lerp(110.0, 70.0, risk)

	# Badly damaged near the rim is how rounds are lost; retreat first.
	if fragile and margin < 5.0:
		steer_to(arena.global_position)
		maybe_dash(1.2)
		return
	if margin < 2.6:
		steer_to(arena.retreat_point(me.global_position))
		maybe_dash(1.3)
		return

	var target := _best_target()
	if target < 0:
		super.decide(_delta)
		return
	var spot := predict(target, 0.28)
	var their := ctx.fighter(target)
	var their_damage: float = their.damage_percent if their != null and is_instance_valid(their) else 0.0

	# A finisher: line them up against the edge when they are ripe.
	if their_damage > 80.0 and strategy > 0.4:
		var outward := spot - arena.global_position
		outward.y = 0.0
		if outward.length() > 0.5:
			steer_to(spot - outward.normalized() * 1.5)
		else:
			steer_to(spot)
	else:
		steer_to(spot)

	var dist := distance_to(spot)
	maybe_attack(target, 2.6)
	if dist > 4.0 and dist < 10.0:
		maybe_dash(1.0)
	keep_off_edge(3.0)


## Prefer the most damaged rival — they fly furthest for the same effort.
func _best_target() -> int:
	var best := -1
	var best_score := -INF
	var me := self_body()
	if me == null:
		return -1
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var dist := me.global_position.distance_to(perceive(i))
		var score: float = f.damage_percent * lerp(0.2, 1.0, strategy) - dist * 2.0
		if score > best_score:
			best_score = score
			best = i
	return best
