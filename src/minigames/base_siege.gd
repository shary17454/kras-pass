extends MiniGameController
## Base Siege — four crystals, and yours is the only one you cannot break.
##
## The spec asks for a defend-a-base game, which is the one shape in the list
## that forces a player to be in two places at once. Every swing you spend on a
## rival's crystal is a swing you are not spending guarding your own, and the
## crystals block line of sight, so the arena reads as four corners under
## pressure rather than one scrum in the middle.
##
## Falling out is not the loss condition here — respawning is fine. Losing your
## crystal is.

const BASE_HEALTH := 100.0
const HIT_DAMAGE := 13.0
const RAM_DAMAGE := 9.0
const HIT_POINTS := 1
const DESTROY_POINTS := 6
const REACH := 2.7
const RAM_REACH := 2.2
const HIT_COOLDOWN := 0.3

var _bases: Array = []      # {slot, node, body, health, crystal, ring, cooldown}
var presentation_only := false
var _action_batch := false
var _pending_hits := {}
var _pending_eliminations := {}


func begin_action_batch() -> void:
	_reset_action_batch()
	_action_batch = not presentation_only


func resolve_action_batch() -> void:
	if not _action_batch:
		return
	var slots: Array = _pending_hits.keys()
	slots.sort()
	for slot in slots:
		var command: Dictionary = _pending_hits[slot]
		var base: Dictionary = command.base
		if float(base.health) <= 0.0 or float(base.cooldown) > 0.0:
			continue
		# Accepted commands survive another base's destruction, not input guards.
		_damage(base, int(command.attacker), float(command.amount))
		base.cooldown = maxf(0.0, HIT_COOLDOWN - float(command.elapsed))
		var fighter := ctx.fighter(int(command.attacker))
		if is_instance_valid(fighter) and command.impulse != Vector3.ZERO:
			fighter.apply_impulse(command.impulse)
	var eliminated: Array = _pending_eliminations.keys()
	eliminated.sort()
	_reset_action_batch()
	for slot in eliminated:
		if ctx.is_alive(int(slot)):
			ctx.eliminate(int(slot))


func _reset_action_batch() -> void:
	_action_batch = false
	_pending_hits.clear()
	_pending_eliminations.clear()


func _request_damage(base: Dictionary, attacker: int, amount: float, impulse := Vector3.ZERO) -> void:
	if not _action_batch:
		_damage(base, attacker, amount)
		if impulse != Vector3.ZERO:
			ctx.fighter(attacker).apply_impulse(impulse)
		return
	var to: Vector3 = base.node.global_position - ctx.fighter(attacker).global_position
	to.y = 0.0
	var command := {"base": base, "attacker": attacker, "amount": amount,
		"distance": to.length_squared(), "impulse": impulse, "elapsed": 0.0}
	var slot := int(base.slot)
	# One cooldown-protected hit per base, nearest then stable slot for a tie.
	if _pending_hits.has(slot):
		var previous: Dictionary = _pending_hits[slot]
		if float(previous.distance) < float(command.distance) or \
				(float(previous.distance) == float(command.distance) and int(previous.attacker) <= attacker):
			return
	_pending_hits[slot] = command


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	for slot in ctx.player_count():
		_bases.append(_make_base(arena, slot))
	for i in ctx.fighters.size():
		var f := ctx.fighter(i)
		if f != null and is_instance_valid(f) and not f.attacked.is_connected(_on_attacked):
			f.attacked.connect(_on_attacked)


func on_round_start() -> void:
	_reset_action_batch()
	if presentation_only:
		return
	var contenders: Array = ctx.config.rule("online_contenders", []) \
		if ctx.config.context == MatchConfig.Context.ONLINE else []
	for base in _bases:
		var active := contenders.is_empty() or contenders.has(int(base["slot"]))
		base["health"] = BASE_HEALTH if active else 0.0
		base["cooldown"] = 0.0
		base["hits"] = 0
		var node: Node3D = base["node"]
		if is_instance_valid(node):
			node.visible = active
		var body: StaticBody3D = base["body"]
		if is_instance_valid(body):
			body.collision_layer = 1 if active else 0
		_refresh_base(base)


func _make_base(arena: Arena, slot: int) -> Dictionary:
	var ang := TAU * float(slot) / float(maxi(ctx.player_count(), 1)) - PI * 0.5
	var r: float = arena.def.radius * 0.66
	var pos: Vector3 = arena.global_position + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
	var col := UIKit.adapt(ctx.config.players[slot].color())
	var node := Node3D.new()
	node.name = "Base%d" % slot
	ctx.world_root.add_child(node)
	node.global_position = pos

	var plinth := MeshFactory.cylinder(1.5, 0.5, col.darkened(0.45), 0.05)
	plinth.position = Vector3(0, 0.25, 0)
	node.add_child(plinth)
	var crystal := MeshFactory.gem(0.95, col)
	crystal.name = "Crystal"
	crystal.position = Vector3(0, 1.35, 0)
	node.add_child(crystal)
	var ring := MeshFactory.torus(1.55, 1.75, col, 1.2)
	ring.position = Vector3(0, 0.06, 0)
	node.add_child(ring)

	# Solid: the crystals are cover, which is what stops a four-way siege from
	# collapsing into everyone standing in the middle.
	var body := StaticBody3D.new()
	body.set_meta("observation_mesh", NodePath("../Crystal"))
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.1
	cyl.height = 2.2
	shape.shape = cyl
	shape.position = Vector3(0, 1.1, 0)
	body.add_child(shape)
	node.add_child(body)

	# Own crystal at your back: spawn beside it, so defending is the default
	# position and leaving is the decision.
	var f := ctx.fighter(slot)
	var spawn := pos + Vector3(cos(ang), 0, sin(ang)) * -2.6 + Vector3(0, 1.3, 0)
	if f != null and is_instance_valid(f):
		f.global_position = spawn
		f.set_spawn(spawn)

	return {"slot": slot, "node": node, "body": body, "health": BASE_HEALTH,
		"crystal": crystal, "ring": ring, "cooldown": 0.0, "hits": 0, "colour": col}


func tick(delta: float) -> void:
	if presentation_only:
		return
	for base in _bases:
		base["cooldown"] = maxf(0.0, float(base["cooldown"]) - delta)
		# Swings preceded this clock; rams originate after it. Preserve that age.
		if _action_batch and _pending_hits.has(int(base.slot)):
			_pending_hits[int(base.slot)].elapsed += delta
		if float(base["health"]) <= 0.0:
			continue
		var crystal: Node3D = base["crystal"]
		if is_instance_valid(crystal):
			crystal.rotation.y += delta * 0.9
			crystal.position.y = 1.35 + sin(float(base["slot"]) + Time.get_ticks_msec() * 0.0016) * 0.07
		_check_rams(base)


## A charge into a crystal chips it. Cheaper than a swing per hit, but it costs
## nothing to line up, which gives the heavy characters a way to siege that
## does not depend on attack timing.
func _check_rams(base: Dictionary) -> void:
	if presentation_only or float(base["health"]) <= 0.0 or float(base["cooldown"]) > 0.0:
		return
	# Swings run before rams, retaining their authored one-hit cooldown priority.
	if _action_batch and _pending_hits.has(int(base["slot"])):
		return
	var node: Node3D = base["node"]
	if not is_instance_valid(node):
		return
	for i in ctx.fighters.size():
		if i == int(base["slot"]) or not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f) or not f.alive or not f.is_dashing():
			continue
		var to: Vector3 = node.global_position - f.global_position
		to.y = 0.0
		if to.length() > RAM_REACH + 1.1:
			continue
		_request_damage(base, i, RAM_DAMAGE, -to.normalized() * 4.0)
		if not _action_batch:
			return


func _on_attacked(slot: int) -> void:
	if presentation_only:
		return
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f) or not ctx.is_alive(slot) or not f.alive:
		return
	for base in _bases:
		if int(base["slot"]) == slot or float(base["health"]) <= 0.0:
			continue
		if float(base["cooldown"]) > 0.0:
			continue
		var node: Node3D = base["node"]
		if not is_instance_valid(node):
			continue
		var to: Vector3 = node.global_position - f.global_position
		to.y = 0.0
		var dist := to.length()
		if dist > REACH + 1.1 or dist < 0.01:
			continue
		if f.facing.normalized().dot(to / dist) < 0.2:
			continue
		_request_damage(base, slot, HIT_DAMAGE)
		return


func _damage(base: Dictionary, attacker: int, amount: float) -> void:
	if presentation_only:
		return
	base["cooldown"] = HIT_COOLDOWN
	base["hits"] = int(base["hits"]) + 1
	base["health"] = maxf(0.0, float(base["health"]) - amount)
	ctx.add_score(attacker, maxi(1, int(round(HIT_POINTS * ctx.powerups.point_multiplier(attacker)))))
	ctx.bump_detail(attacker, "base_hits")
	var node: Node3D = base["node"]
	AudioManager.play_sfx("crate_break", node.global_position, 1.15)
	InputRouter.rumble(attacker, 0.4, 0.1)
	EventBus.shake(0.12, 0.14)
	if DisplayServer.get_name() != "headless":
		var burst := MeshFactory.burst(base["colour"], 8, 2.4, 0.4)
		node.add_child(burst)
		burst.position = Vector3(0, 1.35, 0)
	_refresh_base(base)
	if float(base["health"]) <= 0.0:
		_destroy(base, attacker)


func _refresh_base(base: Dictionary) -> void:
	var crystal: Node3D = base["crystal"]
	if not is_instance_valid(crystal):
		return
	# Shrinking and sinking: how much of a crystal is left is readable across
	# the arena without a health bar in the way of the fight.
	var k: float = clampf(float(base["health"]) / BASE_HEALTH, 0.0, 1.0)
	crystal.scale = Vector3.ONE * lerpf(0.45, 1.0, k)
	var ring: Node3D = base["ring"]
	if is_instance_valid(ring):
		ring.scale = Vector3(lerpf(0.6, 1.0, k), 1.0, lerpf(0.6, 1.0, k))


func _destroy(base: Dictionary, attacker: int) -> void:
	if presentation_only:
		return
	var slot := int(base["slot"])
	ctx.add_score(attacker, DESTROY_POINTS)
	ctx.bump_detail(attacker, "bases_broken")
	var node: Node3D = base["node"]
	if is_instance_valid(node):
		if DisplayServer.get_name() != "headless":
			var burst := MeshFactory.burst(base["colour"], 22, 4.5, 0.7)
			node.add_child(burst)
			burst.position = Vector3(0, 1.3, 0)
		node.visible = false
	var body: StaticBody3D = base["body"]
	if is_instance_valid(body):
		body.collision_layer = 0
	AudioManager.play_sfx("explode", node.global_position if is_instance_valid(node) else ctx.arena_center())
	EventBus.shake(0.5, 0.35)
	EventBus.notify(Loc.t("siege.broken", {"name": player_name(slot)}), "✖")
	if ctx.is_alive(slot):
		if _action_batch:
			_pending_eliminations[slot] = true
		else:
			ctx.eliminate(slot)


# --- shared-layer answers --------------------------------------------------

## Authoritative health for HUD/replay. AI uses base_observation below.
func base_health(slot: int) -> float:
	for base in _bases:
		if int(base["slot"]) == slot:
			return float(base["health"])
	return 0.0


func base_visible(slot: int) -> bool:
	for base in _bases:
		if int(base["slot"]) == slot:
			var node: Node3D = base["node"]
			return is_instance_valid(node) and not node.is_queued_for_deletion() \
				and node.is_visible_in_tree()
	return false


func base_observation(slot: int, observable: Callable) -> Dictionary:
	if not observable.is_valid():
		return {}
	for base in _bases:
		if int(base["slot"]) != slot:
			continue
		var crystal := base.get("crystal") as Node3D
		if not is_instance_valid(crystal) or not observable.call(crystal):
			return {}
		var position := crystal.global_position
		position.y = ctx.arena_center().y
		return {"id": crystal.get_instance_id(), "position": position,
			"health": int(round(float(base["health"]) / BASE_HEALTH * 100.0))}
	return {}


func base_position(slot: int) -> Vector3:
	for base in _bases:
		if int(base["slot"]) == slot:
			var node: Node3D = base["node"]
			if is_instance_valid(node):
				return node.global_position
	return ctx.arena_center()


func is_round_over() -> bool:
	return ctx.early_finish or ctx.alive_count() <= 1


func hud_value(slot: int) -> String:
	if not ctx.is_alive(slot):
		return Loc.t("hud.eliminated")
	var pct := int(round(base_health(slot) / BASE_HEALTH * 100.0))
	return "%d\n◈%d%%" % [ctx.scores[slot], pct]


func ai_script() -> Script:
	return load("res://src/ai/brains/siege_brain.gd")


func detail_rows() -> Array:
	return [
		{"key": "results.stat.base_hits", "field": "base_hits"},
		{"key": "results.stat.bases_broken", "field": "bases_broken"},
	]


func cleanup() -> void:
	_reset_action_batch()
	for fighter in ctx.fighters:
		if is_instance_valid(fighter) and fighter.attacked.is_connected(_on_attacked):
			fighter.attacked.disconnect(_on_attacked)
	for base in _bases:
		var node: Node3D = base["node"]
		if is_instance_valid(node):
			node.queue_free()
	_bases.clear()
	presentation_only = false
