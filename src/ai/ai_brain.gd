class_name AIBrain
extends RefCounted
## Base opponent intelligence.
##
## Design rule, enforced by construction: **an AI may only read what a human
## player can see on screen, and only after a human-plausible delay.** Every
## world query goes through `perceive()`, which returns a position from
## `reaction_time` seconds ago plus aim error scaled by `accuracy`. Higher
## difficulties are faster and more accurate, never better informed — there is
## no hidden state, no perfect prediction and no rubber-band speed bonus.
##
## Subclasses in `src/ai/` override `decide()` to express one game's strategy.
## Everything else — the decision clock, edge safety, aim noise, deliberate
## mistakes — is shared.

const Btn := InputFrame.Btn

var slot := 0
var ctx: MatchContext
## The game being played. Specialised brains query it for game-specific state
## (the next checkpoint, the safe colour, the zone position) — all of which is
## information the human player can also see on screen.
var controller: MiniGameController
var profile := {}
var rng := RandomNumberGenerator.new()

var reaction_time := 0.3
var decision_interval := 0.22
var accuracy := 0.7
var prediction := 0.4
var aggression := 0.5
var risk := 0.4
var strategy := 0.5
var input_noise := 0.14
var dash_chance := 0.35
var attack_chance := 0.55
var powerup_interest := 0.6
var edge_awareness := 0.7
var mistake_chance := 0.1

## Output for this tick; `decide()` writes these.
var move := Vector2.ZERO
var aim := Vector2.ZERO
var bits := 0

var _decision_clock := 0.0
var _history: Array = []          # ring of {t, positions}
var _time := 0.0
var _mistake_timer := 0.0
var _noise_phase := 0.0


func configure(player_slot: int, context: MatchContext, difficulty: int, seed_value: int) -> void:
	slot = player_slot
	ctx = context
	rng.seed = seed_value + player_slot * 7919
	var profiles := Balance.list("ai", "profiles")
	var idx := clampi(difficulty, 0, profiles.size() - 1)
	profile = profiles[idx] if profiles.size() > 0 else {}
	reaction_time = float(profile.get("reaction_time", 0.3))
	decision_interval = float(profile.get("decision_interval", 0.22))
	accuracy = float(profile.get("accuracy", 0.7))
	prediction = float(profile.get("prediction", 0.4))
	aggression = float(profile.get("aggression", 0.5))
	risk = float(profile.get("risk", 0.4))
	strategy = float(profile.get("strategy", 0.5))
	input_noise = float(profile.get("input_noise", 0.14))
	dash_chance = float(profile.get("dash_chance", 0.35))
	attack_chance = float(profile.get("attack_chance", 0.55))
	powerup_interest = float(profile.get("powerup_interest", 0.6))
	edge_awareness = float(profile.get("edge_awareness", 0.7))
	mistake_chance = float(profile.get("mistake_chance", 0.1))
	_noise_phase = rng.randf() * TAU
	on_configured()


## Hook for subclasses that need per-match state.
func on_configured() -> void:
	pass


func on_round_start() -> void:
	_decision_clock = 0.0
	_history.clear()
	move = Vector2.ZERO
	bits = 0


## Called every physics tick by MatchScene.
func tick(delta: float) -> void:
	_time += delta
	_record_history()
	_mistake_timer = maxf(0.0, _mistake_timer - delta)
	_decision_clock -= delta
	if _decision_clock <= 0.0:
		_decision_clock = decision_interval * rng.randf_range(0.85, 1.15)
		bits = 0
		if _mistake_timer <= 0.0 and rng.randf() < mistake_chance:
			# A deliberate lapse: freeze or wander for a beat. This is what
			# makes Easy feel like a distracted friend instead of a slow robot.
			_mistake_timer = rng.randf_range(0.25, 0.7)
		if _mistake_timer > 0.0:
			move = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.4
		else:
			decide(delta)
	_publish()


## Override in subclasses. Write `move`, `aim` and `bits`.
func decide(_delta: float) -> void:
	var me := self_body()
	if me == null:
		return
	steer_to(ctx.arena_center())
	keep_off_edge()


func _publish() -> void:
	var m := move
	if input_noise > 0.0:
		# Low-frequency drift rather than per-frame jitter, so imprecision looks
		# like a human hand and not like static.
		_noise_phase += 0.09
		m += Vector2(sin(_noise_phase * 1.7), cos(_noise_phase * 1.3)) * input_noise * 0.5
	InputRouter.push_virtual(slot, m.limit_length(1.0), aim, bits)


# --- perception ------------------------------------------------------------

func _record_history() -> void:
	var snapshot := []
	for f in ctx.fighters:
		snapshot.append(f.global_position if f != null and is_instance_valid(f) else Vector3.ZERO)
	_history.append({"t": _time, "p": snapshot})
	# Keep a little more than the slowest reaction time.
	while _history.size() > 2 and float(_history[0]["t"]) < _time - 0.7:
		_history.pop_front()


## Position of `target_slot` as this brain currently believes it to be: the true
## position delayed by `reaction_time`. Never the exact live value.
func perceive(target_slot: int) -> Vector3:
	if target_slot < 0 or target_slot >= ctx.fighters.size():
		return Vector3.ZERO
	var want := _time - reaction_time
	for i in range(_history.size() - 1, -1, -1):
		if float(_history[i]["t"]) <= want:
			return _history[i]["p"][target_slot]
	if _history.size() > 0:
		return _history[0]["p"][target_slot]
	var f := ctx.fighter(target_slot)
	return f.global_position if f != null and is_instance_valid(f) else Vector3.ZERO


## Where a target will be shortly, blended by `prediction`. At low skill this
## returns almost the stale position; at Expert it leads the target properly.
func predict(target_slot: int, lead: float = 0.35) -> Vector3:
	var f := ctx.fighter(target_slot)
	if f == null or not is_instance_valid(f):
		return Vector3.ZERO
	var seen := perceive(target_slot)
	var velocity: Vector3 = f.velocity
	velocity.y = 0.0
	return seen + velocity * lead * prediction


func self_body() -> Fighter:
	return ctx.fighter(slot)


func nearest_rival() -> int:
	var me := self_body()
	if me == null:
		return -1
	var best := -1
	var best_d := INF
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i):
			continue
		var d := me.global_position.distance_squared_to(perceive(i))
		if d < best_d:
			best_d = d
			best = i
	return best


## Rival with the highest score — the one a strategic AI should target.
func leader_rival() -> int:
	var best := -1
	var best_score := -2147483648
	for i in ctx.scores.size():
		if i == slot or not ctx.is_alive(i):
			continue
		if ctx.scores[i] > best_score:
			best_score = ctx.scores[i]
			best = i
	return best


## Blend of "closest" and "most dangerous", weighted by strategy. A low-skill
## bot fixates on whoever is nearby; a high-skill bot goes after the leader.
func priority_rival() -> int:
	var near := nearest_rival()
	var lead := leader_rival()
	if lead == -1:
		return near
	if near == -1:
		return lead
	return lead if rng.randf() < strategy else near


func distance_to(pos: Vector3) -> float:
	var me := self_body()
	return me.global_position.distance_to(pos) if me != null else INF


# --- steering helpers ------------------------------------------------------

func steer_to(target: Vector3, urgency: float = 1.0) -> void:
	var me := self_body()
	if me == null:
		return
	var to := target - me.global_position
	move = Vector2(to.x, to.z)
	if move.length() > 0.05:
		move = move.normalized() * clampf(urgency, 0.0, 1.0)
	# Aim error: a wrong-by-a-few-degrees push is what separates Medium from
	# Expert far more convincingly than a slower reaction alone.
	var err := (1.0 - accuracy) * 0.55
	if err > 0.0:
		move = move.rotated(rng.randf_range(-err, err))


## Steering for DRIVE locomotion, where the stick means "turn / throttle"
## rather than "go this way". Sharp corrections cut the throttle, which is what
## stops a bot kart from oscillating down a straight.
func drive_to(target: Vector3, reverse_when_stuck: bool = true) -> void:
	var me := self_body()
	if me == null:
		return
	var to := target - me.global_position
	to.y = 0.0
	if to.length() < 0.2:
		move = Vector2.ZERO
		return
	var desired := atan2(to.x, to.z)
	var current := atan2(me.facing.x, me.facing.z)
	var diff := wrapf(desired - current, -PI, PI)
	var err := (1.0 - accuracy) * 0.35
	if err > 0.0:
		diff += rng.randf_range(-err, err)
	var steer := clampf(diff * 1.8, -1.0, 1.0)
	var throttle := clampf(1.0 - absf(diff) / PI * 1.1, -0.2, 1.0)
	# Nearly reversed and barely moving: back up rather than grind the wall.
	if reverse_when_stuck and absf(diff) > 2.3 and me.speed_ratio() < 0.15:
		move = Vector2(-steer, 0.85)
		return
	move = Vector2(-steer, -maxf(throttle, 0.25))


func steer_away(target: Vector3, urgency: float = 1.0) -> void:
	var me := self_body()
	if me == null:
		return
	var to := me.global_position - target
	move = Vector2(to.x, to.z)
	if move.length() > 0.05:
		move = move.normalized() * clampf(urgency, 0.0, 1.0)


## Override the current steer when standing too close to a lethal edge.
## Weighted by `edge_awareness`, so Easy bots really do walk off the ring.
func keep_off_edge(threshold: float = 3.0) -> void:
	var arena := ctx.arena as Arena
	var me := self_body()
	if arena == null or me == null:
		return
	var margin := arena.edge_distance(me.global_position)
	if margin > threshold:
		return
	if rng.randf() > edge_awareness:
		return
	var inward := arena.retreat_point(me.global_position) - me.global_position
	var away := Vector2(inward.x, inward.z)
	if away.length() > 0.05:
		var blend := clampf(1.0 - margin / maxf(threshold, 0.01), 0.0, 1.0)
		move = move.lerp(away.normalized(), blend).limit_length(1.0)


func press(button: int) -> void:
	bits |= button


func maybe_dash(chance_scale: float = 1.0) -> void:
	var me := self_body()
	if me == null or not me.can_dash:
		return
	# The dash meter is a resource now. Pressing an empty button is not a
	# mistake a human makes twice, and a bot that does it looks broken rather
	# than beatable.
	if not me.can_afford_dash():
		return
	if rng.randf() >= dash_chance * chance_scale * decision_interval * 6.0:
		return
	# A dash is a commitment you cannot steer out of: the 15.5 impulse alone
	# carries ~1.7 m against damping, riding on top of full walk speed for the
	# dash window plus the slide after it — call it five metres of travel that
	# is decided the moment the button goes down. Isolating knobs showed this
	# is the single biggest skill-eraser in every push-out game: with dashes
	# and no attacks the Expert edge collapses to 0.45 while attacks alone
	# score 0.61, because a charge dash near the rim follows the victim
	# straight over it, at every tier alike. So project the real travel and
	# refuse the dashes that end in the void — at `edge_awareness` odds, so the
	# tiers that are supposed to yeet themselves still do.
	# …but only where a fall actually ends the round. On respawn tracks the
	# guard was a regression: a ring lane is ~7 m wide, so the 5 m projection
	# on a curve lands outside the lane constantly and the most edge-aware tier
	# refused nearly every dash — the exact opposite of skilled racing, where
	# boosting on the straights is the whole advantage.
	var fall_is_lethal: bool = controller == null or bool(controller.get("eliminate_on_fall"))
	if fall_is_lethal and rng.randf() < edge_awareness:
		var arena := ctx.arena as Arena
		if arena != null:
			var dir := Vector3(move.x, 0.0, move.y)
			if dir.length_squared() > 0.05:
				var land: Vector3 = me.global_position + dir.normalized() * 5.0
				if arena.edge_distance(land) < 1.2:
					return
	press(Btn.DASH)


func maybe_attack(target_slot: int, range_: float = 2.4) -> void:
	var me := self_body()
	if me == null or not me.can_attack or target_slot < 0:
		return
	var target := predict(target_slot, 0.2)
	if me.global_position.distance_to(target) > range_:
		return
	if rng.randf() < attack_chance:
		press(Btn.ATTACK)


func maybe_jump(chance: float = 0.5) -> void:
	var me := self_body()
	if me == null or not me.can_jump:
		return
	if rng.randf() < chance:
		press(Btn.JUMP)


## Nearest node in a group (pickups, gems, crates…). Returns null when empty.
func nearest_in_group(group: String, tree: SceneTree) -> Node3D:
	var me := self_body()
	if me == null:
		return null
	var best: Node3D = null
	var best_d := INF
	for n in tree.get_nodes_in_group(group):
		if not (n is Node3D) or not is_instance_valid(n):
			continue
		if n.has_method("is_available") and not n.call("is_available"):
			continue
		var d: float = me.global_position.distance_squared_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best
