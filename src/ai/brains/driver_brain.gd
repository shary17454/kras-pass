extends AIBrain
## Scrap Karts: line up a ram, then commit.
##
## A kart that simply drives at its target never lands a hard hit, because both
## karts end up matching speed. This one backs off to build a run-up when it is
## too close, which is exactly the behaviour a human learns in the first round.

var _state := "hunt"
var _state_timer := 0.0


func decide(delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return
	_state_timer -= decision_interval

	# A kart cannot stop. A fixed four-metre margin is a walker's margin: at
	# full tilt this thing covers that in half a second and the wheels are
	# still pointed at the drop, so the bail-out has to start at the distance
	# it actually needs to turn, which grows with speed.
	var margin := arena.edge_distance(me.global_position)
	if margin < lerpf(3.5, 9.0, clampf(me.speed_ratio(), 0.0, 1.0)):
		drive_to(arena.retreat_point(me.global_position))
		return

	var target := priority_rival()
	if target < 0:
		drive_to(arena.global_position)
		return
	var spot := predict(target, 0.45)
	var dist := distance_to(spot)

	if _state == "backoff":
		# Backing off is for building a run-up, not for leaving the arena.
		# Reversing blindly away from the rival pointed the kart at whatever
		# was behind it — usually the rim — and because `strategy` decides who
		# backs off at all, the sharpest tier drove itself off the edge most
		# often: every profile knob measured *better* when it was turned down,
		# and strategy alone was worth 0.44 against 0.52.
		var away: Vector3 = me.global_position - spot
		away.y = 0.0
		if away.length() < 0.2:
			away = -me.facing
		away = away.normalized()
		var goal: Vector3 = me.global_position + away * 8.0
		if arena.edge_distance(goal) < 3.0:
			# No room behind: peel off along the floor instead, which keeps the
			# separation without spending the arena to get it.
			var inward: Vector3 = arena.global_position - me.global_position
			inward.y = 0.0
			if inward.length() > 0.2:
				goal = me.global_position + (away + inward.normalized() * 1.4).normalized() * 8.0
		drive_to(goal)
		if _state_timer <= 0.0 or dist > lerp(9.0, 6.0, aggression):
			_state = "hunt"
		return

	# Drive straight at them. Aiming at the flank was tried — the damage model
	# rewards it — and measured worse (0.50 -> 0.47): steering at an offset
	# point makes a kart sweep past the target and connect with nothing, and a
	# ram that misses is worth less than a head-on that lands. The angle has to
	# come from how the chase develops, not from aiming beside the rival.
	drive_to(spot)
	# Too close and too slow to hurt anyone: reverse out and try again.
	if dist < 4.0 and me.speed_ratio() < 0.45 and rng.randf() < strategy:
		_state = "backoff"
		_state_timer = 0.9
	if dist < 10.0 and me.speed_ratio() > 0.6:
		maybe_dash(1.2)
