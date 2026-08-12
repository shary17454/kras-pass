class_name PowerUpSystem
extends Node3D
## Spawns pickups and applies their effects.
##
## Effects are recomputed from scratch every tick rather than incrementally
## patched, which makes stacking, expiry and overlapping pickups correct by
## construction — the class of bug where a player keeps double speed forever
## because two timers expired in the wrong order simply cannot happen here.

const POOL_KEY := "powerup_pickup"

var ctx: MatchContext
var pool: Array[PowerUpDef] = []
var enabled := true

var _active_pickups: Array[PowerUpPickup] = []
var _effects: Array = []   # {slot, def, remaining}
var _spawn_timer := 0.0
var _interval := 7.0
var _jitter := 2.5
var _max_active := 4
var _bob := 0.28
var _spin := 1.8
var _pickup_radius := 1.15


func setup(context: MatchContext) -> void:
	ctx = context
	var t := Balance.table("tuning").get("powerups", {})
	_interval = float(t.get("spawn_interval", 7.0))
	_jitter = float(t.get("spawn_interval_jitter", 2.5))
	_max_active = int(t.get("max_active", 4))
	_bob = float(t.get("bob_height", 0.28))
	_spin = float(t.get("spin_speed", 1.8))
	_pickup_radius = float(t.get("pickup_radius", 1.15))
	pool = Registry.powerups_for(ctx.definition.category_name())
	enabled = ctx.config.allow_powerups and not pool.is_empty()
	Pool.define(POOL_KEY, func(): return PowerUpPickup.new(),
		int(Balance.num("tuning", "performance.pool_prewarm_pickups", 12)))
	_spawn_timer = _interval * 0.5


func tick(delta: float) -> void:
	if ctx == null:
		return
	_tick_effects(delta)
	if not enabled:
		return
	for p in _active_pickups:
		if is_instance_valid(p):
			p.tick(delta, _spin, _bob)
	_apply_magnets(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _interval + ctx.rng.randf_range(-_jitter, _jitter)
		if _active_pickups.size() < _max_active:
			_spawn_one()


## Immediately clears every timed effect. Used between rounds so nobody starts
## round two with leftover double points.
func clear_all() -> void:
	_effects.clear()
	for slot in ctx.fighters.size():
		_recompute(slot)
	for p in _active_pickups.duplicate():
		_retire(p)


func active_effects_for(slot: int) -> Array:
	var out: Array = []
	for e in _effects:
		if int(e["slot"]) == slot:
			out.append({"id": e["def"].id, "glyph": e["def"].glyph, "color": e["def"].color, "remaining": e["remaining"]})
	return out


func point_multiplier(slot: int) -> float:
	var f := ctx.fighter(slot)
	return float(f.mods["points"]) if f != null else 1.0


## Spawn a specific power-up at a position — used by mini-games that want a
## scripted pickup rather than the ambient spawner.
func spawn_at(id: String, pos: Vector3) -> void:
	var d := Registry.powerup(id)
	if d == null:
		return
	_make_pickup(d, pos)


func _spawn_one() -> void:
	var d := _weighted_pick()
	if d == null:
		return
	_make_pickup(d, _random_spawn_position())


func _make_pickup(d: PowerUpDef, pos: Vector3) -> void:
	var p: PowerUpPickup = Pool.acquire(POOL_KEY)
	if p == null:
		return
	if p.get_parent() == null:
		add_child(p)
	p.configure(d)
	p.place(pos)
	# The AI finds power-ups the same way it finds anything else: by group.
	p.add_to_group("powerups")
	if not p.collected.is_connected(_on_collected):
		p.collected.connect(_on_collected)
	_active_pickups.append(p)


func _weighted_pick() -> PowerUpDef:
	var total := 0.0
	for d in pool:
		total += d.weight
	if total <= 0.0:
		return null
	var roll := ctx.rng.randf() * total
	for d in pool:
		roll -= d.weight
		if roll <= 0.0:
			return d
	return pool[pool.size() - 1]


func _random_spawn_position() -> Vector3:
	var arena := ctx.arena as Arena
	if arena == null:
		return Vector3(0, 1.4, 0)
	for attempt in 12:
		var ang := ctx.rng.randf() * TAU
		var r := sqrt(ctx.rng.randf()) * arena.current_radius * 0.78
		var p := arena.global_position + Vector3(cos(ang) * r, 1.4, sin(ang) * r)
		if arena.is_inside(p, 1.5):
			return p
	return arena.global_position + Vector3(0, 1.4, 0)


func _on_collected(pickup: PowerUpPickup, slot: int) -> void:
	var d := pickup.def
	_retire(pickup)
	AudioManager.play_sfx("powerup", pickup.global_position)
	Stats.record_powerup()
	EventBus.powerup_collected.emit(slot, d.id)
	if d.targets_rivals:
		for i in ctx.fighters.size():
			if i != slot and ctx.is_alive(i):
				_apply(i, d)
	else:
		_apply(slot, d)


func _retire(p: PowerUpPickup) -> void:
	_active_pickups.erase(p)
	Pool.release(POOL_KEY, p)


func _apply(slot: int, d: PowerUpDef) -> void:
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f):
		return
	match d.kind:
		"bomb":
			_shockwave(slot, d.magnitude)
			return
		"heal":
			f.heal(d.magnitude)
			f.reset_damage()
			return
		"freeze":
			f.freeze(d.duration)
			return
	if d.instant:
		return
	# Same power-up twice refreshes rather than stacks: two Rushes should not
	# make a character uncontrollable.
	for e in _effects:
		if int(e["slot"]) == slot and e["def"].id == d.id:
			e["remaining"] = d.duration
			_recompute(slot)
			return
	_effects.append({"slot": slot, "def": d, "remaining": d.duration})
	_recompute(slot)


func _shockwave(slot: int, power: float) -> void:
	var origin := ctx.fighter(slot)
	if origin == null:
		return
	EventBus.shake(0.45, 0.3)
	AudioManager.play_sfx("explode", origin.global_position)
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i):
			continue
		var other := ctx.fighter(i)
		if other == null or not is_instance_valid(other):
			continue
		var to: Vector3 = other.global_position - origin.global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 8.0:
			continue
		var falloff := 1.0 - clampf(dist / 8.0, 0.0, 1.0)
		other.take_hit(slot, to.normalized(), power * (0.4 + 0.6 * falloff), 6.0)


func _tick_effects(delta: float) -> void:
	if _effects.is_empty():
		return
	var touched := {}
	var i := _effects.size() - 1
	while i >= 0:
		var e = _effects[i]
		e["remaining"] = float(e["remaining"]) - delta
		if float(e["remaining"]) <= 0.0:
			touched[int(e["slot"])] = true
			EventBus.powerup_expired.emit(int(e["slot"]), e["def"].id)
			_effects.remove_at(i)
		i -= 1
	for slot in touched:
		_recompute(slot)


## Rebuild a fighter's modifier set from the currently active effects.
func _recompute(slot: int) -> void:
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f):
		return
	var frozen: float = f.mods["frozen"]  # driven by its own timer, not effects
	f.mods = {
		"speed": 1.0, "push": 1.0, "weight": 1.0, "points": 1.0,
		"magnet": 0.0, "shield": 0.0, "frozen": frozen, "jump": 1.0, "dash": 1.0,
	}
	for e in _effects:
		if int(e["slot"]) != slot:
			continue
		var d: PowerUpDef = e["def"]
		match d.kind:
			"speed", "boost": f.mods["speed"] = float(f.mods["speed"]) * d.magnitude
			"slow": f.mods["speed"] = float(f.mods["speed"]) * d.magnitude
			"push": f.mods["push"] = float(f.mods["push"]) * d.magnitude
			"weight": f.mods["weight"] = float(f.mods["weight"]) * d.magnitude
			"points": f.mods["points"] = maxf(float(f.mods["points"]), d.magnitude)
			"magnet": f.mods["magnet"] = maxf(float(f.mods["magnet"]), d.magnitude)
			"shield": f.mods["shield"] = 1.0
			"dash": f.mods["dash"] = maxf(float(f.mods["dash"]), d.magnitude)


## Magnet pulls loose collectibles toward the holder. Collectibles opt in by
## joining the "magnetic" group, so gem/crate games need no extra wiring.
func _apply_magnets(delta: float) -> void:
	var holders: Array = []
	for i in ctx.fighters.size():
		var f := ctx.fighter(i)
		if f != null and is_instance_valid(f) and float(f.mods["magnet"]) > 0.0 and ctx.is_alive(i):
			holders.append(f)
	if holders.is_empty():
		return
	for node in get_tree().get_nodes_in_group("magnetic"):
		if not (node is Node3D):
			continue
		for f in holders:
			var to: Vector3 = f.global_position - node.global_position
			var dist := to.length()
			if dist < float(f.mods["magnet"]) and dist > 0.05:
				node.global_position += to.normalized() * (9.0 * delta) * (1.0 - dist / float(f.mods["magnet"]))
