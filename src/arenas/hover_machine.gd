class_name HoverMachine
extends Node3D
## The drone that hovers over the arena and keeps rewriting the round.
##
## The spec is explicit that this is a mechanic and not scenery: it drifts above
## the ring, picks a player or a patch of floor, warns everybody, and then does
## something that changes the fight — a boost, a penalty, a crate dropped for
## whoever gets there first, or a timed mark that has to be passed on before it
## detonates.
##
## Three rules shape the implementation:
##
## 1. **Never silent.** Every effect is preceded by a telegraph — the eye
##    flares, the rotor spins up, a preview beam points at the target and an
##    electronic pip plays. A power-down out of nowhere is not difficulty.
## 2. **Skewed, not scripted.** Who gets a boost and who gets a penalty is
##    weighted by standing, so a runaway leader is more likely to be the target
##    of a penalty and a trailing player more likely to catch a boost. The odds
##    stay short of certainty on purpose: the spec asks for competition kept
##    alive, not for a game that visibly forces a result.
## 3. **Deterministic, and on its own stream.** The machine draws from its own
##    generator, seeded from the match seed, rather than from the shared match
##    generator. That is not a style choice: how many numbers the machine draws
##    depends on the fight — a mark that gets passed on changes the next
##    action's odds — and physics is not bit-exact, so sharing the match stream
##    let one nudged contact shift every later draw the power-up spawner made,
##    and a replay diverged by whole power-ups. One system, one stream.
##
## The machine owns no rules of its own. It delivers power-ups through
## `PowerUpSystem`, so anything the pickups can do it can do, and a new effect
## in `data/powerups.json` is available to it with no code here at all.

enum State { DRIFT, TELEGRAPH }
enum Action { BEAM, DROP, MARK }

const MARK_GROUP := "machine_mark"

var ctx: MatchContext
var enabled := true
## Scales the cycle rate. Sudden death drives it above 1 so the machine leans
## on a stalemate instead of watching it.
var urgency := 1.0

var _state: int = State.DRIFT
var _action: int = Action.BEAM
var _timer := 0.0
var _target_slot := -1
var _target_point := Vector3.ZERO
var _pending_id := ""
var _drift_goal := Vector3.ZERO
var _time := 0.0
var _hum_timer := 0.0
var _tuning := {}
var rng := RandomNumberGenerator.new()
var _seed := 1

var _hull: Node3D
var _eye: MeshInstance3D
var _rotor: Node3D
var _beam: MeshInstance3D
var _ground_ring: Node3D

# --- the timed mark --------------------------------------------------------
var _mark_slot := -1
var _mark_left := 0.0
var _mark_grace := 0.0
var _mark_node: Node3D
var _mark_label: Label3D


func setup(context: MatchContext) -> void:
	ctx = context
	_tuning = Balance.table("tuning").get("machine", {})
	_seed = (ctx.config.seed if ctx.config != null else 1) * 31 + 977
	_build()
	reset()


func reset() -> void:
	rng.seed = _seed
	_state = State.DRIFT
	_timer = _cycle_length() * 0.6
	_target_slot = -1
	_pending_id = ""
	_clear_mark()
	_drift_goal = _wander_point()
	global_position = _home() + Vector3(0, 0, 0)
	if _beam != null and is_instance_valid(_beam):
		_beam.visible = false
	if _ground_ring != null and is_instance_valid(_ground_ring):
		_ground_ring.visible = false


func set_urgency(value: float) -> void:
	urgency = maxf(0.2, value)


# --- what the AI is allowed to know ---------------------------------------
## All of this is on screen: the drone's position, the beam it is lining up and
## the marker over a player's head. A bot reading these is reading the same
## picture the player sees.

func is_telegraphing() -> bool:
	return _state == State.TELEGRAPH


func target_slot() -> int:
	return _target_slot if _state == State.TELEGRAPH else -1


func target_point() -> Vector3:
	return _target_point


## True when the pending delivery is a penalty, so a bot can decide whether the
## beam is worth standing under.
func target_is_penalty() -> bool:
	if _state != State.TELEGRAPH or _pending_id == "":
		return _action == Action.MARK
	var d := Registry.powerup(_pending_id)
	return d != null and not d.boon


func marked_slot() -> int:
	return _mark_slot


func mark_seconds_left() -> float:
	return _mark_left


# --- per-tick --------------------------------------------------------------

func tick(delta: float) -> void:
	if ctx == null or not enabled:
		return
	_time += delta
	_animate(delta)
	_tick_mark(delta)
	_timer -= delta * urgency
	match _state:
		State.DRIFT:
			_drift(delta)
			if _timer <= 0.0:
				_begin_telegraph()
		State.TELEGRAPH:
			_hover_over_target(delta)
			_aim_beam()
			if _timer <= 0.0:
				_fire()


func _drift(delta: float) -> void:
	var speed := float(_tuning.get("drift_speed", 2.6))
	if global_position.distance_to(_drift_goal) < 1.2:
		_drift_goal = _wander_point()
	global_position = global_position.move_toward(_drift_goal, speed * delta)
	_hum_timer -= delta
	if _hum_timer <= 0.0:
		_hum_timer = float(_tuning.get("hum_period", 2.4))
		AudioManager.play_sfx("machine_hum", global_position)


func _hover_over_target(delta: float) -> void:
	var above := _target_point
	above.y = _home().y
	global_position = global_position.move_toward(above, float(_tuning.get("track_speed", 6.0)) * delta)


func _begin_telegraph() -> void:
	var alive := ctx.alive_slots()
	if alive.is_empty():
		_timer = _cycle_length()
		return
	_action = _pick_action(alive)
	_state = State.TELEGRAPH
	_timer = float(_tuning.get("telegraph_seconds", 1.5)) / urgency
	match _action:
		Action.DROP:
			_target_slot = -1
			_target_point = _ground_point()
			_pending_id = _pick_powerup(alive[rng.randi() % alive.size()], true)
		Action.MARK:
			_target_slot = _pick_target(alive)
			_pending_id = ""
			_target_point = _slot_position(_target_slot)
		_:
			_target_slot = _pick_target(alive)
			_pending_id = _pick_powerup(_target_slot, false)
			_target_point = _slot_position(_target_slot)
	if _pending_id == "" and _action != Action.MARK:
		# Nothing this category allows — skip the cycle rather than fire blanks.
		_state = State.DRIFT
		_timer = _cycle_length()
		return
	AudioManager.play_sfx("machine_alert", global_position)
	if _beam != null and is_instance_valid(_beam):
		_beam.visible = true
	if _ground_ring != null and is_instance_valid(_ground_ring):
		_ground_ring.visible = true
	# Aim before the first frame is drawn. `_aim_beam()` otherwise runs a tick
	# later, and for one rendered frame the column and the floor ring sit at the
	# drone's own origin at full height and unscaled — a flicker in the wrong
	# place, which is worse than no telegraph at all.
	_aim_beam()


func _fire() -> void:
	_state = State.DRIFT
	_timer = _cycle_length()
	if _beam != null and is_instance_valid(_beam):
		_beam.visible = false
	if _ground_ring != null and is_instance_valid(_ground_ring):
		_ground_ring.visible = false
	AudioManager.play_sfx("beam", _target_point)
	EventBus.shake(0.18, 0.2)
	_flash()
	match _action:
		Action.DROP:
			# A crate on the floor is a race, not a gift: the spec wants players
			# fighting over what the machine drops.
			if ctx.powerups != null and _pending_id != "":
				ctx.powerups.spawn_at(_pending_id, _target_point + Vector3(0, 1.2, 0))
		Action.MARK:
			_set_mark(_target_slot)
		_:
			if ctx.powerups != null and _target_slot >= 0 and _pending_id != "":
				ctx.powerups.apply_to(_target_slot, _pending_id)
	_target_slot = -1


# --- choices ---------------------------------------------------------------

func _cycle_length() -> float:
	var base := float(_tuning.get("cycle_seconds", 9.0))
	var jitter := float(_tuning.get("cycle_jitter", 2.5))
	return maxf(1.5, base + rng.randf_range(-jitter, jitter))


func _pick_action(alive: Array) -> int:
	var beam := float(_tuning.get("beam_weight", 1.0))
	var drop := float(_tuning.get("drop_weight", 1.0))
	var mark := float(_tuning.get("mark_weight", 0.55)) if alive.size() >= 2 and _mark_slot < 0 else 0.0
	var roll := rng.randf() * (beam + drop + mark)
	if roll < beam:
		return Action.BEAM
	if roll < beam + drop:
		return Action.DROP
	return Action.MARK


func _pick_target(alive: Array) -> int:
	return int(alive[rng.randi() % alive.size()])


## Boost or penalty, decided by where the target stands. The leader is more
## likely to be handed a problem and the player at the back more likely to be
## handed a way in — but both stay possible either way, which is the difference
## between a comeback mechanic and a rigged one.
func _pick_powerup(slot: int, for_ground: bool) -> String:
	var boon := true
	if for_ground:
		# Anyone can reach a dropped crate, so a penalty on the floor would be
		# a trap nobody chooses to walk into. Ground drops are boosts.
		boon = true
	else:
		var chance := _boon_chance(slot)
		boon = rng.randf() < chance
	var pool: Array = Registry.machine_powerups(ctx.definition.category_name(), boon)
	if pool.is_empty():
		pool = Registry.machine_powerups(ctx.definition.category_name(), not boon)
	if pool.is_empty():
		return ""
	var total := 0.0
	for d in pool:
		total += d.weight
	var roll := rng.randf() * maxf(total, 0.001)
	for d in pool:
		roll -= d.weight
		if roll <= 0.0:
			return d.id
	return pool[pool.size() - 1].id


func _boon_chance(slot: int) -> float:
	var low := float(_tuning.get("leader_boon_chance", 0.25))
	var high := float(_tuning.get("trailer_boon_chance", 0.8))
	var rank := _rank_fraction(slot)
	return lerpf(low, high, rank)


## 0.0 for the player in front, 1.0 for the player at the back. Ties share the
## middle, and a game with no score yet reads as a flat 0.5 — no skew at all
## until somebody is actually ahead.
func _rank_fraction(slot: int) -> float:
	var alive := ctx.alive_slots()
	if alive.size() < 2 or slot < 0 or slot >= ctx.scores.size():
		return 0.5
	var mine := ctx.scores[slot]
	var better := 0
	var worse := 0
	for i in alive:
		if i == slot:
			continue
		if ctx.scores[i] > mine:
			better += 1
		elif ctx.scores[i] < mine:
			worse += 1
	if better == 0 and worse == 0:
		return 0.5
	return clampf(float(better) / float(better + worse), 0.0, 1.0)


# --- the timed mark --------------------------------------------------------

func _set_mark(slot: int) -> void:
	if slot < 0 or not ctx.is_alive(slot):
		return
	_mark_slot = slot
	_mark_left = float(_tuning.get("mark_seconds", 8.0))
	_mark_grace = float(_tuning.get("mark_pass_grace", 0.7))
	if _mark_node == null or not is_instance_valid(_mark_node):
		_build_mark()
	if _mark_node != null:
		_mark_node.visible = true
	EventBus.notify(Loc.t("machine.marked", {"name": _player_name(slot)}), "⌛")


## The mark moves by touch: run into a rival and it is theirs. That is the whole
## game of it — the marked player has to close distance while everyone else
## keeps away, which turns a penalty into a chase the whole ring can see.
func _tick_mark(delta: float) -> void:
	if _mark_slot < 0:
		return
	if not ctx.is_alive(_mark_slot):
		_clear_mark()
		return
	_mark_grace = maxf(0.0, _mark_grace - delta)
	_mark_left -= delta
	var carrier := ctx.fighter(_mark_slot)
	if carrier == null or not is_instance_valid(carrier):
		_clear_mark()
		return
	if _mark_node != null and is_instance_valid(_mark_node):
		_mark_node.global_position = carrier.global_position + Vector3(0, 2.5, 0)
		_mark_node.rotation.y += delta * 2.6
		var urgent: float = clampf(1.0 - _mark_left / maxf(float(_tuning.get("mark_seconds", 8.0)), 0.01), 0.0, 1.0)
		_mark_node.scale = Vector3.ONE * (1.0 + sin(_time * lerpf(6.0, 22.0, urgent)) * 0.12)
		if _mark_label != null and is_instance_valid(_mark_label):
			_mark_label.text = "%d" % int(ceil(maxf(_mark_left, 0.0)))
			_mark_label.modulate = Color(1.0, lerpf(0.9, 0.25, urgent), lerpf(0.4, 0.2, urgent))
	if _mark_left <= 0.0:
		_detonate_mark(carrier)
		return
	if _mark_grace > 0.0:
		return
	var radius := float(_tuning.get("mark_pass_radius", 1.8))
	for i in ctx.fighters.size():
		if i == _mark_slot or not ctx.is_alive(i):
			continue
		var other := ctx.fighter(i)
		if other == null or not is_instance_valid(other):
			continue
		if carrier.global_position.distance_to(other.global_position) <= radius:
			_mark_slot = i
			_mark_grace = float(_tuning.get("mark_pass_grace", 0.7))
			AudioManager.play_sfx("bounce", other.global_position, 0.8)
			InputRouter.rumble(i, 0.5, 0.14)
			return


## Time up. The spec offers a crush, a freeze, a lost point or a ring-out; this
## is a freeze plus a shove toward the rim, which is all four at once depending
## on where the carrier was standing when the clock ran out.
func _detonate_mark(carrier: Fighter) -> void:
	var slot := _mark_slot
	var away := carrier.global_position - ctx.arena_center()
	away.y = 0.0
	if away.length_squared() < 0.04:
		away = carrier.facing
	carrier.freeze(float(_tuning.get("mark_penalty_freeze", 2.2)))
	carrier.take_hit(-1, away.normalized(), float(_tuning.get("mark_penalty_push", 13.0)), 8.0, true)
	AudioManager.play_sfx("explode", carrier.global_position)
	EventBus.shake(0.5, 0.32)
	InputRouter.rumble(slot, 0.95, 0.3)
	EventBus.notify(Loc.t("machine.mark_blown", {"name": _player_name(slot)}), "✺")
	_clear_mark()


func _clear_mark() -> void:
	_mark_slot = -1
	_mark_left = 0.0
	if _mark_node != null and is_instance_valid(_mark_node):
		_mark_node.visible = false


# --- geometry helpers ------------------------------------------------------

func _home() -> Vector3:
	return ctx.arena_center() + Vector3(0, float(_tuning.get("height", 7.6)), 0)


func _wander_point() -> Vector3:
	var arena := ctx.arena as Arena
	var radius: float = (arena.current_radius if arena != null else ctx.arena_radius()) * 0.6
	var ang := rng.randf() * TAU
	var r := sqrt(rng.randf()) * radius
	return _home() + Vector3(cos(ang) * r, rng.randf_range(-0.6, 0.6), sin(ang) * r)


func _ground_point() -> Vector3:
	var arena := ctx.arena as Arena
	if arena == null:
		return ctx.arena_center()
	for attempt in 12:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * arena.current_radius * 0.74
		var p := arena.global_position + Vector3(cos(ang) * r, 0.4, sin(ang) * r)
		if arena.is_inside(p, 1.6):
			return p
	return arena.global_position + Vector3(0, 0.4, 0)


func _slot_position(slot: int) -> Vector3:
	var f := ctx.fighter(slot)
	return f.global_position if f != null and is_instance_valid(f) else ctx.arena_center()


func _player_name(slot: int) -> String:
	var p := ctx.config.player_at(slot) if ctx.config != null else null
	return p.display_name() if p != null else "P%d" % (slot + 1)


# --- presentation ----------------------------------------------------------

func _build() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Sized and coloured for the camera this game actually uses. The first pass
	# was a 0.66 m dark grey hull, which from a 22 m arena camera read as a
	# pebble on the ice — I only saw it in a screenshot, because a headless
	# test cannot tell you that a mechanic is invisible.
	_hull = Node3D.new()
	_hull.name = "Hull"
	add_child(_hull)
	var shell := MeshFactory.cylinder(1.05, 0.4, Color(0.86, 0.9, 0.98), 0.22)
	_hull.add_child(shell)
	var dome := MeshFactory.sphere(0.68, Color(0.98, 0.99, 1.0), 0.18)
	dome.position = Vector3(0, 0.24, 0)
	_hull.add_child(dome)
	var stripe := MeshFactory.torus(0.98, 1.14, Color(1.0, 0.62, 0.25), 1.1)
	stripe.position = Vector3(0, 0.02, 0)
	_hull.add_child(stripe)
	var skirt := MeshFactory.cone(0.8, 0.5, Color(0.42, 0.47, 0.62))
	skirt.rotation.x = PI
	skirt.position = Vector3(0, -0.36, 0)
	_hull.add_child(skirt)
	_eye = MeshFactory.sphere(0.3, Color(1.0, 0.72, 0.3), 3.0)
	_eye.position = Vector3(0, -0.56, 0)
	_hull.add_child(_eye)
	for i in 3:
		var ang := TAU * float(i) / 3.0
		var leg := MeshFactory.box(Vector3(0.16, 0.42, 0.16), Color(0.3, 0.34, 0.46))
		leg.position = Vector3(cos(ang) * 0.78, -0.3, sin(ang) * 0.78)
		_hull.add_child(leg)
	_rotor = Node3D.new()
	_rotor.name = "Rotor"
	add_child(_rotor)
	var ring := MeshFactory.torus(1.2, 1.46, Color(0.66, 0.86, 1.0), 0.9)
	_rotor.add_child(ring)
	for i in 4:
		var ang := TAU * float(i) / 4.0
		var blade := MeshFactory.box(Vector3(0.8, 0.05, 0.2), Color(0.9, 0.96, 1.0), 0.5)
		blade.position = Vector3(cos(ang) * 1.32, 0.1, sin(ang) * 1.32)
		blade.rotation.y = -ang
		_rotor.add_child(blade)
	# The beam is one unit tall and scaled to reach its target, so aiming is a
	# transform rather than a rebuilt mesh every frame.
	_beam = MeshFactory.cylinder(0.62, 1.0, Color(1.0, 0.85, 0.45), 2.2)
	_beam.name = "Beam"
	_beam.material_override = MeshFactory.transparent(Color(1.0, 0.86, 0.5), 0.62)
	_beam.visible = false
	add_child(_beam)
	# From a high camera a column is nearly edge-on and easy to miss, so the
	# spot on the floor carries the warning: that is the shape a player reads
	# without looking up.
	_ground_ring = Node3D.new()
	_ground_ring.name = "TargetRing"
	_ground_ring.visible = false
	add_child(_ground_ring)
	var outer := MeshFactory.torus(1.5, 1.9, Color(1.0, 0.6, 0.28), 1.6)
	_ground_ring.add_child(outer)
	var inner := MeshFactory.torus(0.5, 0.8, Color(1.0, 0.86, 0.45), 1.4)
	_ground_ring.add_child(inner)


func _animate(delta: float) -> void:
	if _rotor != null and is_instance_valid(_rotor):
		_rotor.rotation.y += delta * (7.0 if _state == State.TELEGRAPH else 3.2)
	if _hull != null and is_instance_valid(_hull):
		_hull.position.y = sin(_time * 2.1) * 0.12
		_hull.rotation.y += delta * 0.5
	if _eye != null and is_instance_valid(_eye):
		var lit := _state == State.TELEGRAPH
		var pulse := 1.0 + (sin(_time * 24.0) * 0.35 if lit else sin(_time * 3.0) * 0.08)
		_eye.scale = Vector3.ONE * pulse
		var mat := _eye.material_override as StandardMaterial3D
		if mat != null:
			mat.emission = Color(1.0, 0.35, 0.28) if lit and target_is_penalty() else Color(1.0, 0.82, 0.4)


func _aim_beam() -> void:
	if _beam == null or not is_instance_valid(_beam):
		return
	if _target_slot >= 0:
		_target_point = _slot_position(_target_slot)
	var from := global_position + Vector3(0, -0.5, 0)
	var length: float = maxf(0.6, from.distance_to(_target_point))
	_beam.global_position = (from + _target_point) * 0.5
	var dir := (_target_point - from).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		_beam.look_at(_beam.global_position + dir, Vector3.UP)
		_beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	# Scale *after* aiming, never before: `look_at` rebuilds the basis from an
	# orthonormal one and throws the scale away. Setting the length first and
	# then only restoring width left the beam a one-metre stub pointing at a
	# target ten metres away — which is precisely as visible as no beam at all.
	# Widen as the telegraph runs out, so the last half-second is unmistakable.
	var t: float = 1.0 - clampf(_timer / maxf(float(_tuning.get("telegraph_seconds", 1.5)), 0.01), 0.0, 1.0)
	var width := lerpf(0.6, 1.5, t)
	_beam.scale = Vector3(width, length, width)
	if _ground_ring != null and is_instance_valid(_ground_ring):
		_ground_ring.global_position = _target_point + Vector3(0, 0.16, 0)
		_ground_ring.rotation.y += 0.06
		# Closing in rather than growing: a ring that tightens onto the spot
		# says "here, now" far better than one that spreads.
		var k := lerpf(1.35, 0.85, t)
		_ground_ring.scale = Vector3(k, 1.0, k)


func _flash() -> void:
	if DisplayServer.get_name() == "headless" or ctx.world_root == null:
		return
	var burst := MeshFactory.burst(Color(1.0, 0.88, 0.5), 14, 3.2, 0.5)
	ctx.world_root.add_child(burst)
	burst.global_position = _target_point + Vector3(0, 0.6, 0)


func _build_mark() -> void:
	if DisplayServer.get_name() == "headless" or ctx.world_root == null:
		return
	_mark_node = Node3D.new()
	_mark_node.name = "MachineMark"
	_mark_node.add_to_group(MARK_GROUP)
	ctx.world_root.add_child(_mark_node)
	var ring := MeshFactory.torus(0.34, 0.5, Color(1.0, 0.55, 0.3), 1.4)
	ring.rotation.x = PI * 0.5
	_mark_node.add_child(ring)
	var spike := MeshFactory.cone(0.24, 0.42, Color(1.0, 0.42, 0.3))
	spike.rotation.x = PI
	spike.position = Vector3(0, -0.34, 0)
	_mark_node.add_child(spike)
	_mark_label = Label3D.new()
	_mark_label.text = "8"
	_mark_label.font_size = 128
	_mark_label.pixel_size = 0.013
	_mark_label.outline_size = 18
	_mark_label.outline_modulate = Color(0.05, 0.06, 0.12, 0.9)
	_mark_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark_label.no_depth_test = true
	_mark_label.position = Vector3(0, 0.95, 0)
	_mark_node.add_child(_mark_label)
