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

	var margin := arena.edge_distance(me.global_position)
	if margin < 4.0:
		drive_to(arena.retreat_point(me.global_position))
		return

	var target := priority_rival()
	if target < 0:
		drive_to(arena.global_position)
		return
	var spot := predict(target, 0.45)
	var dist := distance_to(spot)

	if _state == "backoff":
		drive_to(me.global_position + (me.global_position - spot).normalized() * 8.0)
		if _state_timer <= 0.0 or dist > lerp(9.0, 6.0, aggression):
			_state = "hunt"
		return

	drive_to(spot)
	# Too close and too slow to hurt anyone: reverse out and try again.
	if dist < 4.0 and me.speed_ratio() < 0.45 and rng.randf() < strategy:
		_state = "backoff"
		_state_timer = 0.9
	if dist < 10.0 and me.speed_ratio() > 0.6:
		maybe_dash(1.2)
