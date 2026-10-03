extends "res://src/ai/brains/keeper_brain.gd"
## Magnet Court: keep goal, and judge when the magnet earns its charge.
##
## The magnet is a tempo decision, which is exactly what separates the tiers:
## a low-strategy bot burns it on the first scary ball, a high-strategy one
## waits for a multi-ball catch unless one visible ball is about to hit.

const MagnetCourt = preload("res://src/minigames/magnet_court.gd")

func decide(delta: float) -> void:
	super.decide(delta)
	if controller == null or not controller.has_method("magnet_ready"):
		return
	if not bool(controller.call("magnet_ready", slot)):
		return
	var me := self_body()
	if me == null:
		return
	var close := 0
	var incoming := 0
	var urgent := false
	for b in ctx.world_root.get_tree().get_nodes_in_group("balls"):
		if not b is GameBall or not can_observe(b):
			continue
		var observed := perceive_ball(b)
		if observed.is_empty():
			continue
		var to: Vector3 = me.global_position - Vector3(observed["position"])
		to.y = 0.0
		if to.length() > 6.0:
			continue
		close += 1
		var velocity: Vector3 = observed["velocity"]
		velocity.y = 0.0
		if velocity.dot(to) > 0.0:
			incoming += 1
			var arrival := velocity.dot(to) / velocity.length_squared()
			var miss_distance := (to - velocity * arrival).length()
			# Spend the charge before a fast single ball reaches catching range.
			# Both timing and trajectory come from delayed visible observations.
			if arrival <= MagnetCourt.MAGNET_TIME * 0.5 and miss_distance <= MagnetCourt.CATCH_RADIUS:
				urgent = true
	# Panic threshold scales with strategy: Easy fires at the first incoming
	# ball, Expert holds out for a multi-ball catch unless truly cornered.
	var want: int = 1 if strategy < 0.45 else 2
	if incoming >= want or (incoming >= 1 and close >= 3) or urgent:
		press(Btn.ABILITY)
