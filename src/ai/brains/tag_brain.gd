extends AIBrain
## Tag Hunt. Chase when it is you, run when it is not, and never back yourself
## onto the rim while looking over your shoulder.

var _idle_phase := 0.0   ## drawn, never derived from slot — see generic_brain


func on_configured() -> void:
	_idle_phase = rng.randf() * TAU


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null or controller == null:
		return
	var hunter: int = controller.call("hunter")

	if hunter == slot:
		var prey := nearest_rival()
		if prey < 0:
			steer_to(arena.retreat_point(me.global_position))
			return
		# Lead the target: a hunter that steers at where somebody was never
		# closes the last metre.
		steer_to(predict(prey, 0.45))
		if distance_to(perceive(prey)) < 6.0:
			maybe_dash(1.2)
		keep_off_edge(2.4)
		return

	if hunter < 0:
		steer_to(arena.retreat_point(me.global_position))
		return

	var threat := perceive(hunter)
	var gap := me.global_position.distance_to(threat)
	if gap > 9.0:
		# Far enough to breathe: drift toward open space near the middle rather
		# than stand still, so there is somewhere to run when they arrive.
		var angle := _idle_phase + _time * 0.5
		var r: float = arena.current_radius * 0.5
		steer_to(arena.global_position + Vector3(cos(angle) * r, 0, sin(angle) * r), 0.75)
		keep_off_edge(3.0)
		return
	var away: Vector3 = me.global_position - threat
	away.y = 0.0
	if away.length() < 0.1:
		away = me.facing
	# Run along the ring rather than straight out: fleeing radially ends at the
	# edge with a hunter behind you, which is how a runner traps themselves.
	var tangent: Vector3 = away.normalized().cross(Vector3.UP)
	var inward: Vector3 = arena.global_position - me.global_position
	inward.y = 0.0
	if tangent.dot(inward) < 0.0:
		tangent = -tangent
	var margin := arena.edge_distance(me.global_position)
	var blend: float = clampf(1.0 - margin / 6.0, 0.0, 1.0)
	steer_to(me.global_position + away.normalized().lerp(tangent, blend) * 6.0)
	if gap < 3.4:
		maybe_dash(1.1)
	keep_off_edge(2.6)
