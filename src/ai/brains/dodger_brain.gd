extends "res://src/ai/brains/generic_brain.gd"
## Sweeper Storm: read the arms and get out of the way.
##
## Threat is judged from the arm's current angle and rotation direction — both
## plainly visible — with a `reaction_time` delay before the bot commits to a
## dodge, which is why lower tiers get swept.

var _dodge_until := 0.0


func decide(delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return
	_dodge_until -= decision_interval

	var threat = _incoming_arm(arena, me.global_position)
	if threat != null:
		var to_me: Vector3 = me.global_position - threat.global_position
		to_me.y = 0.0
		# Run along the arm's radius, away from the sweep, not across it.
		var radial := to_me.normalized()
		var escape: Vector3 = me.global_position + radial * 4.0
		if arena.edge_distance(escape) < 2.5:
			escape = me.global_position - radial * 4.0
		steer_to(escape)
		if _dodge_until <= 0.0:
			_dodge_until = 0.5
			maybe_dash(1.6)
			maybe_jump(0.35)
		return

	# Safe: drift to the middle band, which has the most escape routes.
	var to_centre := arena.global_position - me.global_position
	to_centre.y = 0.0
	var d := to_centre.length()
	var band := arena.current_radius * 0.5
	if absf(d - band) > 2.0:
		steer_to(arena.global_position + (me.global_position - arena.global_position).normalized() * band, 0.7)
	else:
		super.decide(delta)


func _incoming_arm(arena: Arena, pos: Vector3):
	var warn: float = lerp(0.5, 1.4, edge_awareness)
	for child in arena.get_children():
		var sweeper := child as ArenaHazards.Sweeper
		if sweeper == null:
			continue
		var to: Vector3 = pos - sweeper.global_position
		to.y = 0.0
		var dist := to.length()
		if dist > sweeper.length + 1.0:
			continue
		var arm: Vector3 = sweeper.global_transform.basis.x
		arm.y = 0.0
		var angle := to.normalized().angle_to(arm.normalized())
		# Time until the arm reaches us, given its rotation speed.
		var eta := angle / maxf(absf(sweeper.speed), 0.05)
		if eta < warn:
			return sweeper
	return null
