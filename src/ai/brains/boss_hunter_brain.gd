extends "res://src/ai/brains/generic_brain.gd"
## Boss fights: hit the soft spot, leave the marked floor.
##
## Two reads, and the order between them is the whole skill. Every boss attack
## is a ring drawn on the ground before it lands, so a competent bot clears the
## ring first and returns to the weak point after; a poor one keeps swinging
## through the warning. `reaction_time` decides how late the ring is noticed and
## `edge_awareness` how reliably it is respected, so the tiers separate on the
## thing the fight is actually about.

func decide(delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		super.decide(delta)
		return

	if controller.has_method("danger_zones") and rng.randf() < edge_awareness:
		for z in controller.call("danger_zones"):
			var pos: Vector3 = z["pos"]
			var r: float = float(z["radius"])
			# Only bail while there is still time to be somewhere else; a tier
			# that reacts slowly discovers the ring too late to leave it.
			if float(z["left"]) > reaction_time * 0.8 and _flat(pos) < r + 0.8:
				steer_away(pos, 1.0)
				maybe_dash(1.3)
				return

	if not controller.has_method("weak_points"):
		super.decide(delta)
		return
	var spots: Array = controller.call("weak_points")
	if spots.is_empty():
		super.decide(delta)
		return
	var best: Vector3 = spots[0]
	for s in spots:
		if _flat(s) < _flat(best):
			best = s
	steer_to(best)
	# Flat distance, always. A weak point mounted on a boss sits metres above
	# the fighter's head, so a 3D measurement never drops below that vertical
	# offset: against the Dreadnought's 2.7 m vent the closest reading a bot
	# could ever take was 2.7, its swing threshold was 2.6, and the fight
	# measured zero damage across every run. Reach is a floor-plan question.
	var d := _flat(best)
	if d < Balance.num("tuning", "fighter.attack_range", 2.15) + 0.6:
		if rng.randf() < attack_chance:
			press(Btn.ATTACK)
	elif d < 9.0:
		maybe_dash(0.8)
	keep_off_edge(3.0)


## Horizontal distance from this bot to a point.
func _flat(point: Vector3) -> float:
	var me := self_body()
	if me == null:
		return INF
	var to: Vector3 = point - me.global_position
	to.y = 0.0
	return to.length()
