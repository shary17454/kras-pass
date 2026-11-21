extends "res://src/ai/brains/generic_brain.gd"
## Star Rush / Crate Relay: collect, then deliver.
##
## The interesting decision is when to stop collecting and bank. Greedy bots
## (high `risk`) hold more before running home; cautious ones deliver early.

var _cargo_history := {}


func on_configured() -> void:
	super.on_configured()
	_cargo_history.clear()


func on_round_start() -> void:
	super.on_round_start()
	_cargo_history.clear()


func _record_history() -> void:
	super._record_history()
	for i in ctx.fighters.size():
		if i != slot:
			_perceived_cargo(i)


## Cargo is public in the delivery HUD, but changes still require reaction time.
func _perceived_cargo(target_slot: int) -> int:
	var rival := ctx.fighter(target_slot)
	if target_slot == slot or not ctx.is_alive(target_slot) or not can_observe(rival):
		_cargo_history.erase(target_slot)
		return 0
	var history: Array = _cargo_history.get(target_slot, [])
	if history.is_empty() or float(history.back()["time"]) < _time:
		history.append({"time": _time, "count": rival.carrying})
	while history.size() > HISTORY_CAP:
		history.pop_front()
	_cargo_history[target_slot] = history
	var want := _time - reaction_time + 0.000001
	for i in range(history.size() - 1, -1, -1):
		if float(history[i]["time"]) <= want:
			return int(history[i]["count"])
	return 0


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null or controller == null:
		return

	var carrying: int = me.carrying
	# Clamped to the game's real capacity: Star Rush can hold up to 8, so a
	# greedy bot banks at 6; Crate Relay holds exactly 1, so bank_at collapses
	# to 1 and a bot delivers the instant it is holding something instead of
	# wandering off toward the next crate it cannot pick up.
	var bank_at: int = mini(controller.max_carry(), int(round(lerp(2.0, 6.0, risk))))
	var base: Vector3 = controller.call("base_position", slot) if controller.has_method("base_position") else arena.global_position

	if carrying > 0 and (carrying >= bank_at or _threatened()):
		steer_to(base)
		if distance_to(base) > 5.0:
			maybe_dash(0.8)
		keep_off_edge()
		return

	var loot := nearest_in_group("pickups", _tree) if _tree != null else null
	if loot != null:
		var position := perceived_object_position(loot)
		steer_to(position)
		if distance_to(position) > 5.5:
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
		var carried := _perceived_cargo(i)
		if carried > best_n:
			best_n = carried
			best = i
	return best if best_n > 0 else nearest_rival()
