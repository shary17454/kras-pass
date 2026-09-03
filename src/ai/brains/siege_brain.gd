extends AIBrain
## Base Siege. Two jobs and never enough time for both: break the weakest
## crystal, or turn round and defend your own when somebody is standing on it.


func decide(_delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		return

	var intruder := _intruder_at_home()
	# Defend only when there is genuinely someone there. `risk` decides how
	# willing this profile is to abandon its own crystal for a better target,
	# so a reckless tier keeps sieging while its own base comes down.
	if intruder >= 0 and rng.randf() > risk * 0.6:
		var spot := predict(intruder, 0.3)
		steer_to(spot)
		maybe_attack(intruder, 2.4)
		if distance_to(spot) > 4.0:
			maybe_dash(1.0)
		return

	var target := _weakest_rival_base()
	if target < 0:
		var rival := nearest_rival()
		if rival >= 0:
			steer_to(predict(rival, 0.3))
			maybe_attack(rival, 2.4)
		return
	var base: Vector3 = controller.call("base_position", target)
	var gap := distance_to(base)
	steer_to(base)
	if gap < 3.0:
		# Close enough: swing at the crystal. The controller checks reach and
		# facing, so pressing attack near it is all this has to do.
		press(Btn.ATTACK)
		var guard := nearest_rival()
		if guard >= 0 and distance_to(perceive(guard)) < 2.4:
			maybe_attack(guard, 2.4)
	elif gap < 12.0:
		maybe_dash(0.8)


## Whoever is closest to my crystal, if they are close enough to be a problem.
func _intruder_at_home() -> int:
	var home: Vector3 = controller.call("base_position", slot)
	if float(controller.call("base_health", slot)) <= 0.0:
		return -1
	var best := -1
	var best_d := 5.0
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i):
			continue
		var d := home.distance_to(perceive(i))
		if d < best_d:
			best_d = d
			best = i
	return best


## The crystal nearest to breaking, with distance as the tie-break — a bot that
## always picks the weakest one walks past a full crystal at its feet.
##
## The jitter is not decoration. Four crystals on a ring means two of them are
## exactly equidistant from any bot, and a deterministic comparison resolves
## every one of those ties toward the lowest index: slot 0 was attacked by two
## bots at once, slot 2 by nobody, and the balance simulator read it as a 25%
## spawn-slot advantage. Same class of bug as handing out three crates to four
## players — a symmetric arena made asymmetric by iteration order.
func _weakest_rival_base() -> int:
	var me := self_body()
	if me == null:
		return -1
	var best := -1
	var best_cost := INF
	for i in ctx.fighters.size():
		if i == slot:
			continue
		var health: float = controller.call("base_health", i)
		if health <= 0.0:
			continue
		var pos: Vector3 = controller.call("base_position", i)
		var cost := health * 0.6 + me.global_position.distance_to(pos) * lerpf(3.0, 1.0, strategy)
		cost += rng.randf_range(-4.0, 4.0)
		if cost < best_cost:
			best_cost = cost
			best = i
	return best
