class_name AIBrain
extends RefCounted
## Base opponent intelligence.
##
## Design rule: bots must use observable cues rather than hidden game state.
## Shared fighter perception retains delayed positions and velocities, with
## aim error scaled by `accuracy`. Shared visibility checks include the camera
## frustum and visible world-body occlusion. Specialised controller and
## object queries must be reviewed separately for visibility and reaction delay.
## Difficulty must not grant hidden movement or damage bonuses.
##
## Subclasses in `src/ai/` override `decide()` to express one game's strategy.
## Everything else — the decision clock, edge safety, aim noise, deliberate
## mistakes — is shared.

const Btn := InputFrame.Btn
const HISTORY_SAMPLE_INTERVAL := 1.0 / 20.0
const HISTORY_CAP := 32
const OCCLUSION_SKIP_LIMIT := 8

var _sight_query := PhysicsRayQueryParameters3D.new()

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
var personality := "balanced"

## Output for this tick; `decide()` writes these.
var move := Vector2.ZERO
var aim := Vector2.ZERO
var bits := 0

var _decision_clock := 0.0
var _history_times := PackedFloat32Array()
var _history_positions: Array[PackedVector3Array] = []
var _history_velocities: Array[PackedVector3Array] = []
var _history_damage: Array[PackedFloat32Array] = []
var _history_balls: Array[Dictionary] = []
var _first_seen_times := PackedFloat64Array()
var _tracks_balls := false
var _tracks_damage := false
var _history_head := 0
var _history_count := 0
var _history_sample_clock := 0.0
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
	if bool(ctx.config.rule("ai_personalities", false)):
		_apply_personality(seed_value, player_slot)
	_noise_phase = rng.randf() * TAU
	on_configured()


func _apply_personality(seed_value: int, player_slot: int) -> void:
	var personalities := ["aggressive", "cautious", "collector", "chaser", "defensive"]
	personality = personalities[posmod(seed_value + player_slot, personalities.size())]
	match personality:
		"aggressive":
			aggression = minf(1.0, aggression * 1.15)
			risk = minf(1.0, risk * 1.1)
		"cautious":
			risk *= 0.75
			aggression *= 0.85
		"collector":
			powerup_interest = minf(1.0, powerup_interest * 1.2)
			aggression *= 0.9
		"chaser":
			strategy = minf(1.0, strategy * 1.15)
		"defensive":
			edge_awareness = minf(1.0, edge_awareness * 1.15)
			risk *= 0.85


## Hook for subclasses that need per-match state.
func on_configured() -> void:
	pass


func on_round_start() -> void:
	_decision_clock = 0.0
	_history_times.clear()
	_history_positions.clear()
	_history_velocities.clear()
	_history_damage.clear()
	_history_balls.clear()
	_first_seen_times.clear()
	_history_head = 0
	_history_count = 0
	_history_sample_clock = 0.0
	move = Vector2.ZERO
	bits = 0


## Called every physics tick by MatchScene.
func tick(delta: float) -> void:
	_time += delta
	_history_sample_clock -= delta
	if _history_sample_clock <= 0.0:
		_record_history()
		_history_sample_clock = HISTORY_SAMPLE_INTERVAL
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
	_publish_output(m.limit_length(1.0))


## Game-specific safety checks must see the final noisy input, not a proposal.
func _publish_output(movement: Vector2) -> void:
	InputRouter.push_virtual(slot, movement, aim, bits)


# --- perception ------------------------------------------------------------

func _record_history() -> void:
	if _first_seen_times.size() != ctx.fighters.size():
		_first_seen_times.resize(ctx.fighters.size())
		_first_seen_times.fill(INF)
	var positions := PackedVector3Array()
	var velocities := PackedVector3Array()
	var damage := PackedFloat32Array()
	positions.resize(ctx.fighters.size())
	velocities.resize(ctx.fighters.size())
	damage.resize(ctx.fighters.size())
	var previous := (_history_head + _history_count - 1) % HISTORY_CAP if _history_count > 0 else -1
	var balls := _ball_snapshot(previous)
	for i in ctx.fighters.size():
		var f := ctx.fighters[i]
		if can_observe(f):
			_first_seen_times[i] = minf(_first_seen_times[i], _time)
			positions[i] = f.global_position
			velocities[i] = f.velocity
			if _tracks_damage:
				# Duel HUD displays whole percentages, not private fractional damage.
				damage[i] = floorf(f.damage_percent)
		else:
			# Keep a last-seen location, never sample hidden movement or velocity.
			positions[i] = _history_positions[previous][i] if previous >= 0 else Vector3.ZERO
			velocities[i] = Vector3.ZERO
			damage[i] = _history_damage[previous][i] if previous >= 0 else 0.0
	if _history_count < HISTORY_CAP:
		_history_positions.append(positions)
		_history_velocities.append(velocities)
		_history_damage.append(damage)
		_history_balls.append(balls)
		_history_times.append(_time)
		_history_count += 1
		return
	_history_positions[_history_head] = positions
	_history_velocities[_history_head] = velocities
	_history_damage[_history_head] = damage
	_history_balls[_history_head] = balls
	_history_times[_history_head] = _time
	_history_head = (_history_head + 1) % HISTORY_CAP


func _ball_snapshot(previous: int) -> Dictionary:
	var snapshot := {}
	if not _tracks_balls or not is_instance_valid(ctx.world_root) or not ctx.world_root.is_inside_tree():
		return snapshot
	for node in ctx.world_root.get_tree().get_nodes_in_group("balls"):
		if not node is GameBall or not can_observe(node) or not ctx.world_root.is_ancestor_of(node):
			continue
		var ball := node as GameBall
		var id := ball.get_instance_id()
		var position := ball.global_position
		var velocity := Vector3.ZERO
		# Infer motion from successive visible samples, not private momentum.
		if previous >= 0:
			var old: Dictionary = _history_balls[previous].get(id, {})
			var elapsed := _time - float(_history_times[previous])
			if not old.is_empty() and int(old["generation"]) == ball.launch_generation and elapsed > 0.000001:
				velocity = (position - Vector3(old["position"])) / elapsed
		var fuse := -1.0
		if can_observe(ball._label):
			fuse = ball._label.text.to_float()
		snapshot[id] = {"position": position, "velocity": velocity, "fuse": fuse,
			"radius": ball.visible_radius(),
			"generation": ball.launch_generation}
	return snapshot


func perceive_ball(ball: GameBall) -> Dictionary:
	if not can_observe(ball) or not is_instance_valid(ctx.world_root) or not ctx.world_root.is_ancestor_of(ball):
		return {}
	var want := _time - reaction_time
	var idx := _history_index(want + 0.000001)
	if idx < 0 or float(_history_times[idx]) > want + 0.000001:
		return {}
	var sample: Dictionary = _history_balls[idx].get(ball.get_instance_id(), {})
	# A relaunch reuses the node, not the preceding ball's observed trajectory.
	if sample.is_empty() or int(sample["generation"]) != ball.launch_generation:
		return {}
	return sample.duplicate()


func can_observe(node: Node3D) -> bool:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_visible_in_tree():
		return false
	var camera: Camera3D = ctx.observation_camera if ctx != null else null
	var has_camera := is_instance_valid(camera)
	var has_geometry := false
	# Compound actor origins are not rendered cues. Inspect actual body parts;
	# keep both hierarchy traversal and candidate rays independently bounded.
	var pending: Array[Node] = [node]
	var visited := 0
	var points_left := 12
	var truncated := false
	while not pending.is_empty() and visited < 32 and points_left > 0:
		var candidate: Node = pending.pop_back()
		visited += 1
		if candidate.is_queued_for_deletion():
			continue
		if candidate is GeometryInstance3D:
			has_geometry = true
			var rendered: bool = candidate.is_visible_in_tree() and (not has_camera or candidate.layers & camera.cull_mask != 0)
			if candidate is MeshInstance3D and candidate.mesh == null:
				rendered = false
			if rendered:
				if not has_camera:
					return true
				points_left -= 1
				if _point_in_view(candidate.global_position) and _world_sight_clear(node, candidate.global_position):
					return true
				if candidate is MeshInstance3D:
					var bounds: AABB = candidate.get_aabb()
					for corner in 8:
						if points_left <= 0:
							break
						points_left -= 1
						var point: Vector3 = candidate.global_transform * bounds.get_endpoint(corner)
						if _point_in_view(point) and _world_sight_clear(node, point):
							return true
		# Preserve child order: the primary body mesh precedes accessories.
		var children := candidate.get_children()
		truncated = truncated or children.size() > 32 - visited
		for index in range(mini(children.size(), 32 - visited) - 1, -1, -1):
			if pending.size() + visited < 32:
				pending.append(children[index])
			else:
				truncated = true
	# Geometry-free authored markers preserve their existing logical contract.
	# Exhausting a traversal budget is not evidence that geometry is absent.
	if has_geometry or truncated or not pending.is_empty():
		return false
	return not has_camera or (_point_in_view(node.global_position) and _world_sight_clear(node, node.global_position))


func _world_sight_clear(target: Node3D, point: Vector3) -> bool:
	if not target.is_inside_tree():
		return false
	var camera := ctx.observation_camera
	var origin := camera.global_position + camera.global_basis.x * camera.h_offset + camera.global_basis.y * camera.v_offset
	var follow := camera as ArenaCamera
	if follow != null and not follow.shared_world and follow.mode in [ArenaCamera.Mode.WORLD, ArenaCamera.Mode.CHASE]:
		var reference := follow.local_target as Fighter
		var me := self_body()
		if is_instance_valid(reference) and me != null:
			var angle := me.facing.signed_angle_to(reference.facing, Vector3.UP)
			origin = me.global_position + (origin - reference.global_position).rotated(Vector3.UP, -angle)
	_sight_query.from = origin
	_sight_query.to = point
	_sight_query.collision_mask = 1
	_sight_query.collide_with_areas = false
	_sight_query.collide_with_bodies = true
	_sight_query.hit_from_inside = true
	_sight_query.exclude = []
	# Invisible collision proxies are not visual obstacles. Bound retries so a
	# stack of hidden bodies cannot create an unbounded physics-query loop.
	for attempt in OCCLUSION_SKIP_LIMIT:
		var hit := target.get_world_3d().direct_space_state.intersect_ray(_sight_query)
		if hit.is_empty():
			return true
		var body := hit.get("collider") as Node3D
		# Surface contact at the requested point is not an intervening wall.
		# This also avoids treating a ground-level cue as buried in its floor.
		if Vector3(hit["normal"]).length_squared() > 0.0 and Vector3(hit["position"]).distance_squared_to(point) <= 0.000001:
			return true
		if body == target or (body != null and (body.is_ancestor_of(target) or target.is_ancestor_of(body))):
			return true
		if body == null or _has_visible_geometry(body, camera.cull_mask):
			return false
		var excluded := _sight_query.exclude
		excluded.append(hit["rid"])
		_sight_query.exclude = excluded
	return false


func _has_visible_geometry(root: Node, cull_mask: int) -> bool:
	if root is CollisionObject3D and root.has_meta("observation_mesh"):
		var geometry := root.get_node_or_null(NodePath(root.get_meta("observation_mesh"))) as GeometryInstance3D
		return geometry != null and geometry.is_visible_in_tree() and geometry.layers & cull_mask != 0
	if root is GeometryInstance3D and root.is_visible_in_tree() and root.layers & cull_mask != 0:
		return true
	for child in root.get_children():
		if _has_visible_geometry(child, cull_mask):
			return true
	return false


func _point_in_view(position: Vector3) -> bool:
	var camera := ctx.observation_camera
	var view := camera.global_transform.orthonormalized()
	view.origin += view.basis.x * camera.h_offset + view.basis.y * camera.v_offset
	var local := view.affine_inverse() * _view_position(position)
	var clip: Vector4 = camera.get_camera_projection() * Vector4(local.x, local.y, local.z, 1.0)
	# Use the camera's actual projection, including in the headless renderer.
	return clip.is_finite() and clip.w > 0.0 and absf(clip.x) <= clip.w \
		and absf(clip.y) <= clip.w and absf(clip.z) <= clip.w


func _view_position(position: Vector3) -> Vector3:
	var camera := ctx.observation_camera as ArenaCamera
	if camera == null or camera.shared_world or camera.mode not in [ArenaCamera.Mode.WORLD, ArenaCamera.Mode.CHASE]:
		return position
	var reference := camera.local_target as Fighter
	var me := self_body()
	if not is_instance_valid(reference) or me == null:
		return position
	# Translate the existing follow-camera projection to this bot's own visible
	# position and heading, without allocating or rendering additional cameras.
	var angle := me.facing.signed_angle_to(reference.facing, Vector3.UP)
	return reference.global_position + (position - me.global_position).rotated(Vector3.UP, angle)


## Ring-buffer slot holding the newest sample at or before `want`, so both
## `perceive()` and `_perceived_velocity()` look up the same delayed instant
## instead of one reading history and the other reading the live frame.
func _history_index(want: float) -> int:
	for offset in range(_history_count - 1, -1, -1):
		var idx := (_history_head + offset) % HISTORY_CAP
		if float(_history_times[idx]) <= want:
			return idx
	return _history_head if _history_count > 0 else -1


## Distinguish unknown locations from valid origin coordinates and last-seen
## memory. New knowledge becomes actionable only after the reaction delay.
func has_observed(target_slot: int) -> bool:
	if target_slot < 0 or target_slot >= _first_seen_times.size():
		return false
	return _first_seen_times[target_slot] <= _time - reaction_time + 0.000001


## Delayed observed position, or a visible fallback before the first sample.
func perceive(target_slot: int) -> Vector3:
	if target_slot < 0 or target_slot >= ctx.fighters.size():
		return Vector3.ZERO
	var idx := _history_index(_time - reaction_time)
	if idx >= 0:
		return _history_positions[idx][target_slot]
	var f := ctx.fighter(target_slot)
	return f.global_position if can_observe(f) else Vector3.ZERO


## Same delay as `perceive()`, for the velocity `predict()` leads with — a
## target's exact current velocity is not something a human opponent can read
## either, so the aim lead is built from the same stale snapshot as its position.
func _perceived_velocity(target_slot: int) -> Vector3:
	if target_slot < 0 or target_slot >= ctx.fighters.size():
		return Vector3.ZERO
	var idx := _history_index(_time - reaction_time)
	if idx >= 0:
		return _history_velocities[idx][target_slot]
	var f := ctx.fighter(target_slot)
	return f.velocity if can_observe(f) else Vector3.ZERO


func perceived_damage(target_slot: int) -> float:
	if not _tracks_damage or not has_observed(target_slot) or not can_observe(ctx.fighter(target_slot)):
		return 0.0
	var want := _time - reaction_time
	var idx := _history_index(want + 0.000001)
	if idx < 0 or float(_history_times[idx]) > want + 0.000001:
		return 0.0
	return _history_damage[idx][target_slot]


## Where a target will be shortly, blended by `prediction`. At low skill this
## returns almost the stale position; at Expert it leads the target properly.
func predict(target_slot: int, lead: float = 0.35) -> Vector3:
	var f := ctx.fighter(target_slot)
	if f == null or not is_instance_valid(f):
		return Vector3.ZERO
	var seen := perceive(target_slot)
	var velocity := _perceived_velocity(target_slot)
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
		if i == slot or not ctx.is_alive(i) or not can_observe(ctx.fighter(i)):
			continue
		var d := me.global_position.distance_squared_to(perceive(i))
		if d < best_d:
			best_d = d
			best = i
	return best


## Rival with the highest score — the one a strategic AI should target.
func leader_rival() -> int:
	var best_score := -2147483648
	var candidates: Array[int] = []
	for i in ctx.scores.size():
		if i == slot or not ctx.is_alive(i) or not can_observe(ctx.fighter(i)):
			continue
		if candidates.is_empty() or ctx.scores[i] > best_score:
			best_score = ctx.scores[i]
			candidates.clear()
			candidates.append(i)
		elif ctx.scores[i] == best_score:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	if candidates.size() == 1:
		return candidates[0]
	# Randomize only actual co-leaders, not lower scores encountered on the way.
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## Blend of "closest" and "most dangerous", weighted by strategy. A low-skill
## bot fixates on whoever is nearby; a high-skill bot goes after the leader.
func priority_rival() -> int:
	var near := nearest_rival()
	var lead := leader_rival()
	if lead == -1:
		return near
	if near == -1:
		return lead
	# A runaway leader pulls attention: the wider the gap, the likelier every
	# bot independently picks them. `strategy` still sets the baseline, so a
	# low tier keeps swinging at whoever is closest.
	var bias: float = clampf(strategy + leader_gap() * 0.45, 0.0, 0.95)
	return lead if rng.randf() < bias else near


## The rival closest to going out. Standing next to the rim is the most
## readable weakness in a push-out game and the spec asks the AI to punish it;
## `edge_awareness` doubles as how well this bot reads the geometry, so a low
## tier goes for whoever is nearest instead.
func edge_pressured_rival(threshold: float = 4.0) -> int:
	var arena := ctx.arena as Arena
	if arena == null or rng.randf() > edge_awareness:
		return -1
	var best := -1
	var best_margin := threshold
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i) or not can_observe(ctx.fighter(i)):
			continue
		var margin := arena.edge_distance(perceive(i))
		if margin < best_margin:
			best_margin = margin
			best = i
	return best


## Is this player visibly buffed? The aura, the size and the glyph row are all
## on screen, so avoiding a rival who just caught a strength power-up is
## reading the picture rather than reading the state.
func is_empowered(check_slot: int) -> bool:
	var f := ctx.fighter(check_slot)
	if not can_observe(f):
		return false
	return float(f.mods["push"]) > 1.2 or float(f.mods["weight"]) > 1.3 \
		or float(f.mods["size"]) > 1.2 or float(f.mods["shield"]) > 0.0


## How far ahead the leader is, as a fraction of the field's spread. Bots read
## the same scoreboard the players do, and when someone is running away with it
## they all independently decide the leader is the problem — which looks like a
## temporary alliance without any of them talking to each other.
func leader_gap() -> float:
	if ctx.scores.size() < 2:
		return 0.0
	var best := ctx.scores[0]
	var worst := ctx.scores[0]
	var second := -2147483648
	for sc in ctx.scores:
		if sc > best:
			second = best
			best = sc
		elif sc > second:
			second = sc
		worst = mini(worst, sc)
	var spread := maxi(best - worst, 1)
	return clampf(float(best - second) / float(spread), 0.0, 1.0)


# --- the hover machine, as seen from the ground ----------------------------
## Everything below is visible: the drone, the beam it is lining up, and the
## marker over somebody's head.

func machine() -> Node:
	return ctx.machine


## True when the drone is lining up something unpleasant on this bot. The
## reaction is deliberately gated on `accuracy`, so a low tier stands in the
## beam and a high tier steps out of it.
func machine_threatens_me() -> bool:
	var m := ctx.machine
	if m == null or not is_instance_valid(m):
		return false
	if not m.is_telegraphing() or not m.target_is_penalty():
		return false
	if m.target_slot() != slot:
		return false
	return rng.randf() < accuracy


## The floor spot the drone is about to drop something on, or ZERO.
func machine_drop_point() -> Vector3:
	var m := ctx.machine
	if m == null or not is_instance_valid(m) or not m.is_telegraphing():
		return Vector3.ZERO
	if m.target_slot() >= 0 or m.target_is_penalty():
		return Vector3.ZERO
	return m.target_point()


func marked_slot() -> int:
	var m := ctx.machine
	return m.marked_slot() if m != null and is_instance_valid(m) else -1


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
	if me == null or not me.can_attack or target_slot < 0 or not can_observe(ctx.fighter(target_slot)):
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
		if not can_observe(n):
			continue
		if n.has_method("is_available") and not n.call("is_available"):
			continue
		var d: float = me.global_position.distance_squared_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best
