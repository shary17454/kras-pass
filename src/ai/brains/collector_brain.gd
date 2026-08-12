extends "res://src/ai/brains/generic_brain.gd"
## Gem Grab / general pickup logic.
##
## The interesting judgement is *when to stop collecting and go take someone
## else's*. An early version had high-skill bots mugging the leader almost every
## decision, which made Expert opponents score worse than Easy ones — they spent
## the round chasing instead of banking. The rule now is the one a good human
## uses: pick up whatever is close first, and only detour to a rival when the
## gap is genuinely worth it and they are genuinely reachable.

const CLOSE_LOOT := 6.5
const MUG_RANGE := 8.0
const MUG_GAP := 5


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return

	if arena.edge_distance(me.global_position) < 2.6:
		steer_to(arena.retreat_point(me.global_position))
		return

	var loot := nearest_in_group("pickups", _tree) if _tree != null else null
	var loot_distance := distance_to(loot.global_position) if loot != null else INF

	# Anything within easy reach is free value; take it before anything else.
	if loot != null and loot_distance < CLOSE_LOOT:
		_go_get(loot, loot_distance)
		return

	var target := leader_rival()
	if target >= 0:
		var gap: int = ctx.scores[target] - ctx.scores[slot]
		var spot := predict(target, 0.25)
		var reach := distance_to(spot)
		# Worth mugging only when they are meaningfully ahead, close enough to
		# catch, and not further away than the loot we would otherwise fetch.
		if gap >= MUG_GAP and reach < MUG_RANGE and reach < loot_distance \
				and rng.randf() < aggression * strategy:
			steer_to(spot)
			maybe_attack(target, 2.6)
			maybe_dash(0.8)
			keep_off_edge()
			return

	if loot != null:
		_go_get(loot, loot_distance)
		return

	super.decide(_delta)


func _go_get(loot: Node3D, distance: float) -> void:
	steer_to(loot.global_position)
	if distance > 4.5:
		maybe_dash(0.7)
	# Swat anyone standing between us and the pickup, but never detour for it.
	var rival := nearest_rival()
	if rival >= 0 and distance_to(perceive(rival)) < 2.2:
		maybe_attack(rival, 2.4)
	keep_off_edge()
