extends "res://src/ai/brains/generic_brain.gd"
## Paint Grid: claim ground, prefer unclaimed, occasionally raid a rival's block.


func decide(_delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		return
	var tile = controller.call("unclaimed_tile_near", me.global_position, slot) \
		if controller.has_method("unclaimed_tile_near") else null
	if tile == null or not is_instance_valid(tile):
		super.decide(_delta)
		return
	steer_to(tile.global_position)
	# Dash paints a cross, so a strategic bot saves it for dense unclaimed areas
	# rather than firing it off the moment it is available.
	if strategy > 0.4 and distance_to(tile.global_position) < 2.0:
		maybe_dash(1.4)
	elif distance_to(tile.global_position) > 6.0:
		maybe_dash(0.7)
