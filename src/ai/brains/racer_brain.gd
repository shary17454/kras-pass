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
	var aim_point := next
	# Look-ahead blending: aim between this checkpoint and the direction of
	# travel around the loop.
	var arena := ctx.arena as Arena
	if arena != null and prediction > 0.2:
		var outward := next - arena.global_position
		outward.y = 0.0
		if outward.length() > 0.1:
			var tangent := Vector3(-outward.z, 0, outward.x).normalized()
			aim_point = next + tangent * lerp(0.0, 5.5, prediction)
	drive_to(aim_point)
	if me.speed_ratio() > 0.75 and rng.randf() < dash_chance * 0.5:
		press(Btn.DASH)
