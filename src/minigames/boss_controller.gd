extends MiniGameController
## Shared spine for the championship bosses.
##
## A boss fight inverts the usual match: the four competitors are not each
## other's problem, a scripted opponent is. But it is still a *party* game, so
## they are not allies either — damage is scored per player, and the trophy goes
## to whoever contributed most to the kill. That single rule keeps four players
## shoving each other out of the good firing angle while a boss stomps the
## arena, which is the tone the mode wants.
##
## Subclasses implement `boss_build`, `boss_think` and `weak_points`; everything
## here is the part every boss shares: health, phases, telegraphs, the shared
## health bar, and deciding when the fight is over.

## Every attack a boss makes is announced before it lands. A boss that can hit
## you without warning is not difficult, it is unfair — and on a phone the
## warning has to be on the floor, not in a corner of the HUD.
const TELEGRAPH_COLOR := Color("#ff5f8d")

var boss_health := 1000.0
var boss_max_health := 1000.0
var phase := 0
## Fractions of max health at which the boss changes behaviour, high to low.
var phase_thresholds: Array[float] = [0.66, 0.33]
var boss_node: Node3D
var boss_defeated := false

var _telegraphs: Array = []
var _shots: Array = []
var _hit_flash := 0.0


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	boss_node = Node3D.new()
	ctx.world_root.add_child(boss_node)
	var arena := ctx.arena as Arena
	boss_node.global_position = (arena.global_position if arena != null else Vector3.ZERO) + Vector3(0, 1.0, 0)
	boss_health = boss_max_health
	phase = 0
	boss_defeated = false
	boss_build()


func on_round_start() -> void:
	boss_health = boss_max_health
	phase = 0
	boss_defeated = false
	_clear_telegraphs()


func tick(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
	_tick_telegraphs(delta)
	_tick_shots(delta)
	if boss_defeated:
		return
	boss_think(delta)


## Is `fighter` close enough to hit `point`?
##
## Horizontal distance, plus a generous vertical tolerance. Every reach check
## elsewhere in the project flattens Y first, and bosses are the one place that
## matters: a weak point mounted on a six-metre body sits further above the
## fighter's head than the whole attack range, so a 3D distance test makes it
## unreachable by construction. All four bosses measured zero damage before
## this — the fights were literally unwinnable.
func in_reach(fighter: Node3D, point: Vector3, extra: float = 0.0) -> bool:
	if fighter == null or not is_instance_valid(fighter):
		return false
	var to: Vector3 = point - fighter.global_position
	if absf(to.y) > 5.5:
		return false
	to.y = 0.0
	return to.length() <= Balance.num("tuning", "fighter.attack_range", 2.15) + extra


# --- damage ----------------------------------------------------------------

## Subclasses call this when a player lands a legitimate hit. Damage is banked
## as that player's score, so the results screen ranks contribution.
func damage_boss(amount: float, by_slot: int) -> void:
	if boss_defeated or amount <= 0.0:
		return
	boss_health = maxf(0.0, boss_health - amount)
	_hit_flash = 0.12
	if by_slot >= 0:
		ctx.add_score(by_slot, int(amount))
		ctx.bump_detail(by_slot, "damage", int(amount))
	AudioManager.play_sfx("hit", boss_node.global_position if boss_node != null else Vector3.ZERO)
	var want := 0
	for i in phase_thresholds.size():
		if boss_health / boss_max_health <= phase_thresholds[i]:
			want = i + 1
	if want != phase:
		phase = want
		on_phase_changed(phase)
		EventBus.shake(0.5, 0.4)
		AudioManager.play_sfx("powerup")
	if boss_health <= 0.0:
		_defeat()


func _defeat() -> void:
	boss_defeated = true
	_clear_telegraphs()
	EventBus.shake(0.9, 0.8)
	AudioManager.play_sfx("victory")
	if boss_node != null and is_instance_valid(boss_node):
		var burst := MeshFactory.burst(TELEGRAPH_COLOR, 30, 5.0, 1.2)
		ctx.world_root.add_child(burst)
		burst.global_position = boss_node.global_position
		boss_node.visible = false
	ctx.early_finish = true


# --- telegraphed attacks ---------------------------------------------------

## Mark a patch of floor, then run `on_land` there once the warning expires.
## This is the only way a boss is allowed to hit anyone.
func telegraph(centre: Vector3, radius: float, warn: float, on_land: Callable) -> void:
	var ring := MeshFactory.torus(radius - 0.25, radius, TELEGRAPH_COLOR, 1.8)
	ring.position = centre + Vector3(0, 0.12, 0)
	ctx.world_root.add_child(ring)
	_telegraphs.append({"node": ring, "left": warn, "total": warn,
		"pos": centre, "radius": radius, "cb": on_land})
	AudioManager.play_sfx("tick", centre, 0.7)


func _tick_telegraphs(delta: float) -> void:
	var i := _telegraphs.size() - 1
	while i >= 0:
		var t = _telegraphs[i]
		t["left"] = float(t["left"]) - delta
		var node: Node3D = t["node"]
		if is_instance_valid(node):
			# The ring fills in as the warning runs out, so "how long have I
			# got" is legible at a glance from anywhere on the arena.
			var f: float = 1.0 - clampf(float(t["left"]) / maxf(float(t["total"]), 0.01), 0.0, 1.0)
			node.scale = Vector3(0.35 + 0.65 * f, 1.0, 0.35 + 0.65 * f)
		if float(t["left"]) <= 0.0:
			_telegraphs.remove_at(i)
			if is_instance_valid(node):
				node.queue_free()
			var cb: Callable = t["cb"]
			if cb.is_valid():
				cb.call(t["pos"], float(t["radius"]))
		i -= 1


## The standard payload: a shove and a flash inside the marked circle.
func strike(centre: Vector3, radius: float, power: float = 26.0) -> void:
	var burst := MeshFactory.burst(TELEGRAPH_COLOR, 16, radius)
	ctx.world_root.add_child(burst)
	burst.global_position = centre
	AudioManager.play_sfx("explode", centre)
	EventBus.shake(0.45, 0.3)
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var away: Vector3 = f.global_position - centre
		away.y = 0.0
		if away.length() > radius:
			continue
		f.take_hit(-1, away.normalized() if away.length() > 0.1 else Vector3.FORWARD,
			power * (1.0 - away.length() / radius * 0.4), 0.0, true)
		ctx.bump_detail(i, "hits_taken")


func _clear_telegraphs() -> void:
	for t in _telegraphs:
		if is_instance_valid(t["node"]):
			t["node"].queue_free()
	_telegraphs.clear()


# --- projectiles -----------------------------------------------------------

func fire_shot(from: Vector3, dir: Vector3, speed: float, damage: float, range_: float) -> void:
	var p := Projectile.new()
	ctx.world_root.add_child(p)
	p.configure(TELEGRAPH_COLOR)
	p.fire(from, dir, -1, speed, damage, range_)
	_shots.append(p)


func _tick_shots(delta: float) -> void:
	var i := _shots.size() - 1
	while i >= 0:
		var p = _shots[i]
		if not is_instance_valid(p) or not p.active:
			if is_instance_valid(p):
				p.queue_free()
			_shots.remove_at(i)
		else:
			p.tick(delta)
		i -= 1


# --- hooks -----------------------------------------------------------------

## Build the boss's body and any props. `boss_node` already exists.
func boss_build() -> void:
	pass


## One decision tick. Telegraph attacks here; never hit anyone directly.
func boss_think(_delta: float) -> void:
	pass


func on_phase_changed(_new_phase: int) -> void:
	pass


## Marked floor a brain should not be standing on: position, radius and the
## seconds left. All of it is drawn on the ground already.
func danger_zones() -> Array:
	var out: Array = []
	for t in _telegraphs:
		out.append({"pos": t["pos"], "radius": float(t["radius"]), "left": float(t["left"])})
	return out


## Positions a brain should attack, so bots know where the boss is soft.
func weak_points() -> Array:
	return [boss_node.global_position] if boss_node != null and is_instance_valid(boss_node) else []


# --- shared presentation ---------------------------------------------------

func is_round_over() -> bool:
	return ctx.early_finish or boss_defeated


func hud_value(slot: int) -> String:
	return str(ctx.scores[slot])


func hud_banner() -> String:
	var pct := int(round(boss_health / maxf(boss_max_health, 1.0) * 100.0))
	var filled := int(round(pct / 10.0))
	return "%s%s %d%%" % ["█".repeat(filled), "░".repeat(10 - filled), pct]


func ai_script() -> Script:
	return load("res://src/ai/brains/boss_hunter_brain.gd")


func detail_rows() -> Array:
	return [
		{"key": "results.stat.damage", "field": "damage"},
		{"key": "results.stat.hits_taken", "field": "hits_taken"},
	]


func music_track() -> String:
	return "boss"


func cleanup() -> void:
	_clear_telegraphs()
	for p in _shots:
		if is_instance_valid(p):
			p.queue_free()
	_shots.clear()
	if boss_node != null and is_instance_valid(boss_node):
		boss_node.queue_free()
