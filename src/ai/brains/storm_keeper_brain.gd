extends "res://src/ai/brains/keeper_brain.gd"
## Storm Heart: goalkeeping plus one extra read — the wind-up.
##
## When the turbine telegraphs, the correct play is to abandon whatever ball
## you were shadowing and get home before the volley leaves on an unknown
## bearing. How reliably a bot makes that trade is `strategy`, so low tiers
## keep chasing and get caught up-court, exactly like a keeper who never looks
## at the machine.

func decide(delta: float) -> void:
	if controller != null and controller.has_method("is_winding") \
			and bool(controller.call("is_winding")) and rng.randf() < strategy:
		steer_to(_goal_pos)
		maybe_dash(0.8)
		return
	super.decide(delta)
