extends AIBrain
## Relic Hold. Three states, and which one applies is on screen for everybody:
## run with it, chase whoever has it, or go get the loose one.

var _tree: SceneTree


func on_configured() -> void:
	_tree = Engine.get_main_loop() as SceneTree


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null or controller == null:
		return
	var holder: int = controller.call("holder")

	if holder == slot:
		# Carrying: put distance between us and the nearest rival, and stay off
		# the rim, because a carrier cannot fight back and a shove is a steal.
		var chaser := nearest_rival()
		if chaser >= 0:
			var away: Vector3 = me.global_position - perceive(chaser)
			away.y = 0.0
			if away.length() > 0.1:
				steer_to(me.global_position + away.normalized() * 6.0)
				maybe_dash(0.8)
		else:
			steer_to(arena.retreat_point(me.global_position))
		keep_off_edge(4.0)
		return

	if holder >= 0:
		# Somebody else has it. Line the shove up outward so the steal also
		# threatens a ring-out.
		var spot := predict(holder, 0.3)
		var outward: Vector3 = spot - arena.global_position
		outward.y = 0.0
		var approach := spot if outward.length() < 0.5 else spot - outward.normalized() * 1.5
		steer_to(approach)
		maybe_attack(holder, 2.5)
		var gap := distance_to(spot)
		if gap > 4.0 and gap < 12.0:
			maybe_dash(1.0)
		keep_off_edge(3.0)
		return

	# Loose relic: race for it.
	var target: Vector3 = controller.call("relic_position")
	steer_to(target)
	if distance_to(target) > 4.0:
		maybe_dash(0.7)
	keep_off_edge(2.6)
