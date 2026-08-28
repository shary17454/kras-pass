extends "res://src/ai/brains/generic_brain.gd"
## Sweeper Storm: read the arms and get out of the way.
##
## The arena is the whole puzzle here. The arms reach almost to the rim, so on a
## tight ring there is no patch of floor to run to — running radially just moves
## you along the arm. The only real out is over the top, and the window is
## narrow: with a 9.0 jump against 26 gravity the fighter clears the 1.3 m arm
## for roughly 0.28 s around the apex. So this brain is a timing brain, not a
## pathing brain, and the tiers separate on *when* they leave the ground.
##
## Everything it reads is on screen: the arm's angle, the direction it turns and
## how fast it is turning right now. It never looks at the hazard's schedule.

## Leaving the ground this long before the arm arrives puts the apex on the hit.
const JUMP_LEAD := 0.34
## Clear of the arm's reach by this much counts as standing safely outside it.
const OUTSIDE_MARGIN := 1.2
## …but not so far out that the next knock sends you off the rim. The band has
## to clear this much *and* be wide enough to stand in, because parking four
## bots on a thread of floor next to a lethal edge kills them faster than the
## arms do — measured: herding them into a 0.7 m band cut survival from 5.7 s
## to 3.5 s.
const RIM_MARGIN := 3.0
const BAND_MIN_WIDTH := 1.0

var _dodge_until := 0.0
var _lead := -1.0


func on_round_start() -> void:
	super.on_round_start()
	_lead = -1.0


func decide(delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return
	_dodge_until -= decision_interval

	var threat := _incoming_arm(arena, me.global_position)
	if threat.is_empty():
		# Threat gone: forget this encounter's timing so the next one is rolled
		# fresh. Reusing it would make every dodge in the round identical.
		_lead = -1.0
		_drift(arena, me, delta)
		return

	var sweeper: ArenaHazards.Sweeper = threat["sweeper"]
	var eta: float = threat["eta"]
	if _lead < 0.0:
		# One timing decision per encounter. A tier's accuracy is how well it
		# judges the moment; re-rolling every tick would let the bot stumble
		# into a perfect jump by sheer repetition.
		var slop: float = (1.0 - accuracy) * 0.5
		_lead = clampf(JUMP_LEAD + rng.randfn(0.0, slop), 0.08, 0.75)

	var hub_dist: float = (me.global_position - sweeper.global_position).length()
	var outside: float = sweeper.length + OUTSIDE_MARGIN
	var rim: float = arena.current_radius - RIM_MARGIN
	if outside + BAND_MIN_WIDTH <= rim:
		# The ring leaves a real band past the arm's tip. Standing there beats
		# timing a jump every pass, and noticing it is what edge_awareness buys.
		# Hug the inner lip of the band, not its middle: every metre further out
		# is a metre closer to falling off.
		var out_dir: Vector3 = me.global_position - sweeper.global_position
		out_dir.y = 0.0
		if out_dir.length_squared() < 0.01:
			out_dir = Vector3.FORWARD
		steer_to(sweeper.global_position + out_dir.normalized() * (outside + 0.4))
		if hub_dist < outside and _dodge_until <= 0.0:
			_dodge_until = 0.5
			maybe_dash(1.2)
		return

	# No band to run to: hold still enough to keep the jump honest and go over.
	steer_to(me.global_position, 0.15)
	if eta <= _lead and me.can_jump and me.is_on_floor():
		press(Btn.JUMP)
	elif eta > _lead * 2.5 and _dodge_until <= 0.0:
		# Plenty of time — use it to slide off the arm's line rather than stand
		# in it, which is what makes the next pass survivable.
		_dodge_until = 0.6
		maybe_dash(0.8)


## Idle behaviour: sit in the middle band, which keeps every escape open.
func _drift(arena: Arena, me: Node3D, delta: float) -> void:
	var to_centre: Vector3 = arena.global_position - me.global_position
	to_centre.y = 0.0
	var d := to_centre.length()
	var band := arena.current_radius * 0.5
	if absf(d - band) > 2.0:
		var away: Vector3 = me.global_position - arena.global_position
		away.y = 0.0
		if away.length_squared() < 0.01:
			away = Vector3.FORWARD
		steer_to(arena.global_position + away.normalized() * band, 0.7)
	else:
		super.decide(delta)


## The nearest arm that will actually sweep over us, with the time it needs to
## get here. Empty when nothing is bearing down.
func _incoming_arm(arena: Arena, pos: Vector3) -> Dictionary:
	var warn: float = lerp(0.5, 1.4, edge_awareness)
	var best := {}
	for child in arena.get_children():
		var sweeper := child as ArenaHazards.Sweeper
		if sweeper == null:
			continue
		var to: Vector3 = pos - sweeper.global_position
		to.y = 0.0
		var dist := to.length()
		if dist > sweeper.length + 1.0 or dist < 0.05:
			continue
		var arm: Vector3 = sweeper.global_transform.basis.x
		arm.y = 0.0
		if arm.length_squared() < 0.0001:
			continue
		var omega := sweeper.current_speed()
		if absf(omega) < 0.001:
			continue
		# `angle_to` is unsigned, so the previous reading treated an arm that
		# had just swept past as exactly as dangerous as one bearing down — and
		# because a higher tier watches a wider window, it panicked *more*. The
		# arm only reaches us by turning its own way, so measure the arc it
		# still has to cover in its direction of travel: one moving away scores
		# nearly a full turn and is correctly ignored.
		var a := arm.normalized()
		var t := to.normalized()
		var travel := atan2(a.cross(t).y, a.dot(t)) * signf(omega)
		if travel < 0.0:
			travel += TAU
		var eta := travel / absf(omega)
		if eta >= warn:
			continue
		if best.is_empty() or eta < float(best["eta"]):
			best = {"sweeper": sweeper, "eta": eta}
	return best
