extends AIBrain
## Default opponent: a competent arena brawler.
##
## Used directly by every push-out / control / combat game and as the base for
## the specialised brains. Its behaviour is a small utility contest between four
## drives — take a power-up, attack a rival, escape the edge, reposition — with
## the weights coming from the difficulty profile rather than from hard-coded
## thresholds, so raising a bot's skill really does change how it *plays* and
## not just how fast it twitches.

var _tree: SceneTree


func on_configured() -> void:
	_tree = Engine.get_main_loop() as SceneTree


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return

	var margin := arena.edge_distance(me.global_position)
	var target := priority_rival()

	# 1. Self-preservation always outranks offence when genuinely cornered, but
	#    a risk-taking bot tolerates a tighter margin before bailing out.
	var panic_margin: float = lerp(3.6, 1.6, risk)
	if margin < panic_margin:
		steer_to(arena.retreat_point(me.global_position))
		if margin < panic_margin * 0.55:
			maybe_dash(1.4)
		return

	# 2. Power-ups, when this profile cares about them and one is close enough
	#    to be worth the detour.
	var pickup := nearest_in_group("powerups", _tree) if _tree != null else null
	if pickup != null and rng.randf() < powerup_interest:
		var d := distance_to(pickup.global_position)
		if d < 9.0:
			steer_to(pickup.global_position)
			if d > 4.0:
				maybe_dash(0.6)
			return

	# 3. Offence: line the rival up between us and the nearest edge, so a
	#    successful hit actually removes them instead of just annoying them.
	if target >= 0 and rng.randf() < aggression + 0.2:
		var spot := predict(target, 0.3)
		var to_target := distance_to(spot)
		var shove_dir := _best_shove_position(spot, arena)
		steer_to(shove_dir)
		maybe_attack(target, 2.5)
		if to_target > 4.5 and to_target < 11.0:
			maybe_dash(0.9)
		keep_off_edge(panic_margin)
		return

	# 4. Idle: circle the middle rather than stand still, which keeps low-skill
	#    bots from looking frozen. Driven by simulated time (`_time`), not the
	#    wall clock — under fast-forward play (the balance simulator, automated
	#    tests) a wall-clock angle barely advances between ticks and bots would
	#    look frozen anyway, which is the opposite of the point.
	var angle := float(slot) * TAU * 0.25 + _time * 0.4
	var r: float = arena.current_radius * 0.45
	steer_to(arena.global_position + Vector3(cos(angle) * r, 0, sin(angle) * r), 0.7)
	keep_off_edge(panic_margin)


## Stand on the far side of the target from the arena centre, so pushing them
## sends them outward. A crude idea, but it is exactly what a good human does.
func _best_shove_position(target_pos: Vector3, arena: Arena) -> Vector3:
	var me := self_body()
	if me == null:
		return target_pos
	var outward := target_pos - arena.global_position
	outward.y = 0.0
	if outward.length() < 0.5:
		return target_pos
	var approach := target_pos - outward.normalized() * 1.6
	# Only bother lining up when we are not already on top of them; otherwise
	# commit to the hit.
	return approach if me.global_position.distance_to(target_pos) > 2.6 else target_pos
