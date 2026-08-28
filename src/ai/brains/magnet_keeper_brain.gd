extends "res://src/ai/brains/keeper_brain.gd"
## Magnet Court: keep goal, and judge when the magnet earns its charge.
##
## The magnet is a tempo decision, which is exactly what separates the tiers:
## a low-strategy bot burns it on the first scary ball, a high-strategy one
## waits until the pull can catch more than one — the same greed calculus a
## player learns after conceding with an empty meter.

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
	for b in ctx.world_root.get_tree().get_nodes_in_group("balls"):
		if not is_instance_valid(b):
			continue
		var to: Vector3 = me.global_position - b.global_position
		to.y = 0.0
		if to.length() > 6.0:
			continue
		close += 1
		if b.velocity.dot(to) > 0.0:
			incoming += 1
	# Panic threshold scales with strategy: Easy fires at the first incoming
	# ball, Expert holds out for a multi-ball catch unless truly cornered.
	var want: int = 1 if strategy < 0.45 else 2
	if incoming >= want or (incoming >= 1 and close >= 3):
		press(Btn.ABILITY)
