extends "res://src/ai/brains/generic_brain.gd"
## Fawda: shove like Ring Rumble, but respect the ordnance.
##
## Three reads, in priority order: get away from a bomb that is about to go off,
## throw the one in your hands before it goes off in them, and pick up a fresh
## one when the fuse is long enough to be worth the disarm. `reaction_time` sets
## how late a tier notices a burning fuse and `strategy` how greedily it holds
## on — so Easy fumbles a live bomb and Expert uses it as a weapon.

const PANIC_FUSE := 1.6
const SAFE_PICKUP_FUSE := 2.6
## A thrown bomb leaves at 17 m/s and sheds 14 m/s^2, so it comes to rest about
## ten metres out. Releasing at the edge of that arrives with a spent bomb the
## victim can simply walk away from; inside this, the blast still catches them.
const THROW_RANGE := 6.5
## Picking a bomb up costs you your shove until you let go, and this is a game
## won by shoving. So it is only ever worth it with a rival close enough to
## throw at — scaling the appetite by `strategy` instead made the sharpest
## tiers disarm themselves the most and cost them the round (0.55 -> 0.43).
const WORTH_ARMING := 13.0

var _bomb_history: Array[Dictionary] = []


func on_round_start() -> void:
	super.on_round_start()
	_bomb_history.clear()


func _record_history() -> void:
	super._record_history()
	if controller == null or not controller.has_method("bomb_states"):
		return
	var cues := []
	for cue in controller.call("bomb_states"):
		if can_observe(instance_from_id(int(cue.id)) as Node3D):
			cues.append(cue.duplicate())
	_bomb_history.append({"time": _time, "bombs": cues})
	if _bomb_history.size() > HISTORY_CAP:
		_bomb_history.pop_front()


func _observed_bombs() -> Array:
	if controller == null or not controller.has_method("bomb_states"):
		return []
	var visible := {}
	for cue in controller.call("bomb_states"):
		if can_observe(instance_from_id(int(cue.id)) as Node3D):
			visible[cue.id] = true
	var want := _time - reaction_time + 0.000001
	for index in range(_bomb_history.size() - 1, -1, -1):
		var sample := _bomb_history[index]
		if float(sample.time) > want:
			continue
		var observed := []
		for cue in sample.bombs:
			if visible.has(cue.id):
				observed.append(cue.duplicate())
		return observed
	return []


func decide(delta: float) -> void:
	var me := self_body()
	if me == null or controller == null or not controller.has_method("bomb_states"):
		super.decide(delta)
		return
	var bombs := _observed_bombs()

	if me.carrying > 0:
		# Holding: throw at the nearest rival while there is still fuse, and
		# throw at *anything* once there is not.
		var mine := _held_by_me(bombs)
		var fuse: float = float(mine.get("fuse", 99.0)) if not mine.is_empty() else 99.0
		if fuse < 0.0:
			fuse = 99.0
		var target := priority_rival()
		if target >= 0:
			var spot := predict(target, 0.35)
			steer_to(spot)
			if distance_to(spot) < THROW_RANGE or fuse < PANIC_FUSE:
				tap(Btn.ATTACK)
		elif fuse < PANIC_FUSE:
			tap(Btn.ATTACK)
		return

	# Not holding: flee anything close and nearly spent.
	var danger := _hottest_near(bombs, me.global_position)
	if not danger.is_empty():
		steer_away(danger["pos"], 1.0)
		maybe_dash(1.2)
		keep_off_edge(3.2)
		return

	# Fresh bomb on the floor, enough fuse to use it, and someone worth using
	# it on. `strategy` decides how well the bot spots that third condition,
	# not how much it wants a bomb for its own sake.
	var pick := _best_pickup(bombs, me.global_position)
	if not pick.is_empty() and _rival_within(WORTH_ARMING) and rng.randf() < strategy + 0.25:
		steer_to(pick["pos"])
		return
	super.decide(delta)


func _rival_within(radius: float) -> bool:
	var me := self_body()
	if me == null:
		return false
	for i in ctx.fighters.size():
		if i == slot or not can_target(i):
			continue
		if me.global_position.distance_to(perceive(i)) <= radius:
			return true
	return false


func _held_by_me(bombs: Array) -> Dictionary:
	for b in bombs:
		if int(b["held"]) == slot:
			return b
	return {}


func _hottest_near(bombs: Array, pos: Vector3) -> Dictionary:
	var worst := {}
	for b in bombs:
		if float(b["fuse"]) < 0.0 or float(b["fuse"]) > PANIC_FUSE:
			continue
		var d: float = pos.distance_to(b["pos"])
		if d > 7.0:
			continue
		if worst.is_empty() or d < pos.distance_to(worst["pos"]):
			worst = b
	return worst


func _best_pickup(bombs: Array, pos: Vector3) -> Dictionary:
	var best := {}
	# Opportunistic only, and the radius is not a taste setting — it was swept.
	# 11 m scored 0.43, 6 m scored 0.45, 4.5 m scored 0.51, 3 m scores 0.55,
	# level with ignoring bombs entirely. A detour across the ring costs more
	# ring position than the bomb wins back, and the tiers that detoured
	# hardest lost hardest. A bomb underfoot is free; a bomb across the ring
	# belongs to whoever is already standing next to it.
	var best_d := 3.0
	for b in bombs:
		if int(b["held"]) >= 0 or float(b["fuse"]) < SAFE_PICKUP_FUSE:
			continue
		var d: float = pos.distance_to(b["pos"])
		if d < best_d:
			best_d = d
			best = b
	return best
