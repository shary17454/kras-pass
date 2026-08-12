extends "res://src/ai/brains/generic_brain.gd"
## Star Rush / Crate Relay: collect, then deliver.
##
## The interesting decision is when to stop collecting and bank. Greedy bots
## (high `risk`) hold more before running home; cautious ones deliver early.


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null or controller == null:
		return

	var carrying: int = me.carrying
	var bank_at: int = int(round(lerp(2.0, 6.0, risk)))
	var base: Vector3 = controller.call("base_position", slot) if controller.has_method("base_position") else arena.global_position

	if carrying > 0 and (carrying >= bank_at or _threatened()):
		steer_to(base)
		if distance_to(base) > 5.0:
			maybe_dash(0.8)
		keep_off_edge()
		return

	var loot := nearest_in_group("pickups", _tree) if _tree != null else null
	if loot != null:
		steer_to(loot.global_position)
		if distance_to(loot.global_position) > 5.5:
			maybe_dash(0.5)
		keep_off_edge()
		return

	if carrying > 0:
		steer_to(base)
		keep_off_edge()
		return

	# Nothing to fetch: harass whoever is carrying the most.
	var target := _richest_carrier()
	if target >= 0 and rng.randf() < aggression:
		steer_to(predict(target, 0.25))
		maybe_attack(target, 2.5)
		keep_off_edge()
		return
	super.decide(_delta)


## A rival close enough to hit us is reason to bank early.
func _threatened() -> bool:
	var near := nearest_rival()
	if near < 0:
		return false
	return distance_to(perceive(near)) < lerp(4.5, 2.0, risk)


func _richest_carrier() -> int:
	var best := -1
	var best_n := 0
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f != null and is_instance_valid(f) and f.carrying > best_n:
			best_n = f.carrying
			best = i
	return best if best_n > 0 else nearest_rival()
