extends AIBrain
## Kart Sprint: follow the racing line through the checkpoints.
##
## Skill shows up as how far ahead the bot aims. A low-skill driver steers at
## the next checkpoint and takes every corner wide; a high-skill one aims past
## it, which naturally produces an apex.


func decide(_delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		return
	var next: Vector3 = controller.call("next_checkpoint", slot) if controller.has_method("next_checkpoint") else ctx.arena_center()
	# Aim dead at the checkpoint. Every corner-cutting scheme tried here —
	# tangent lookahead, a capped lean toward the following checkpoint — made
	# the best drivers *slower*, because any standing offset near a 3.6 m
	# capture radius occasionally turns into a missed checkpoint and a missed
	# checkpoint costs a full loop. Solo probes made it unambiguous: with the
	# cut the top tier covered 60-70% of the bottom tier's distance; without
	# it, 135%. Skill still separates the field through steering accuracy,
	# input noise, decision rate and boost usage.
	var aim_point := next
	# Detour through a boost pad when one sits close to the racing line. The
	# pads are the track's only free speed and they are big glowing squares:
	# planning a line through one is exactly what a practised player does, and
	# `strategy` gates how far off the line a bot will bend to take one.
	if controller.has_method("boost_pad_positions") and rng.randf() < strategy:
		var best_pad := Vector3.INF
		var best_cost := lerp(1.2, 5.0, strategy)
		for pad in controller.call("boost_pad_positions", slot):
			var p3 := pad as Vector3
			var ahead: float = me.facing.dot((p3 - me.global_position).normalized())
			if ahead < 0.5:
				continue
			var detour: float = _line_distance(me.global_position, aim_point, p3)
			if detour < best_cost:
				best_cost = detour
				best_pad = p3
		if best_pad != Vector3.INF:
			aim_point = best_pad
	drive_to(aim_point)
	if me.speed_ratio() > 0.75 and rng.randf() < dash_chance * 0.5:
		press(Btn.DASH)


## Perpendicular distance from point `p` to the segment a->b.
func _line_distance(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	ab.y = 0.0
	if ab.length_squared() < 0.01:
		return (p - a).length()
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var closest := a + ab * t
	var d := p - closest
	d.y = 0.0
	return d.length()
