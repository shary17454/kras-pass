extends "res://src/minigames/kart_sprint.gd"
## Rocket Rally — Kart Sprint with weapons.
##
## Inherits the whole race: laps, checkpoints, boost pads, off-track respawn and
## the finishing-order scoring all come from Kart Sprint unchanged. What this
## game adds is the reason to look behind you.
##
## Crates sit on the racing line and hand out one of four items. Items are drawn
## with a bias toward the back of the field, because a weapon race where the
## leader also gets the best weapon is decided on lap one.
##
## Design rule that shaped the numbers below: nothing here removes a player from
## the race. A hit spins you out for a moment. Losing three seconds while three
## rivals go past is already the harshest punishment a 90-second race can carry.

const MISSILE_POOL := "race_missile"

enum Item { NONE, BOMB, MISSILE, BOOST, SHIELD }

const ITEM_GLYPHS := {
	Item.NONE: "",
	Item.BOMB: "✺",
	Item.MISSILE: "➤",
	Item.BOOST: "▶",
	Item.SHIELD: "◇",
}

## Crates respawn rather than running out: a race whose crates are all gone by
## lap two turns into a plain time trial for the second half.
const CRATE_RESPAWN := 7.0
const SPIN_SECONDS := 1.15
const BOMB_ARM_DELAY := 0.55
const BOMB_LIFETIME := 9.0
const BOMB_RADIUS := 3.2

var held: Array[int] = []
var shielded: Array[float] = []
var _crates: Array = []
var _bombs: Array = []
var _missiles: Array[Projectile] = []


## Two laps, not three. These circuits are ~175 m round against Kart Sprint's
## 97 m, so three laps would be a 530 m race inside a 140 s clock — the field
## would still be driving when the whistle went.
func laps() -> int:
	return 2


func build() -> void:
	super.build()
	var n := ctx.player_count()
	held.resize(n)
	held.fill(Item.NONE)
	shielded.resize(n)
	shielded.fill(0.0)
	Pool.define(MISSILE_POOL, func(): return Projectile.new(),
		int(Balance.num("tuning", "performance.pool_prewarm_projectiles", 24)))
	_build_crates()


func _build_crates() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	# One crate per kart, per row. Three crates for four karts denied exactly one
	# driver an item at every single row, and the driver denied is always the one
	# who arrives last — i.e. always the back of the starting grid. The balance
	# simulator caught it at 40 runs as a flagged spawn-slot advantage (18%),
	# well above the fair-game null for that sample size.
	for row in 5:
		var t := (float(row) + 0.5) / 5.0
		var here := arena.track_point(t)
		var ahead := arena.track_point(t + 0.01)
		var fwd := (ahead - here)
		fwd.y = 0.0
		if fwd.length_squared() < 0.001:
			continue
		fwd = fwd.normalized()
		var side := Vector3(-fwd.z, 0.0, fwd.x)
		# Lane spacing, not half-width: four lanes span 3x this, and the narrowest
		# circuit is 7m across, so a kart plus clearance has to fit inside it.
		var spread: float = minf(arena.track_width * 0.22, 1.7)
		for lane: float in [-1.5, -0.5, 0.5, 1.5]:
			var pos := here + side * spread * lane + Vector3(0, 0.85, 0)
			var mesh := MeshFactory.crate(1.05, UIKit.ACCENT, UIKit.ACCENT_2)
			mesh.position = pos
			ctx.world_root.add_child(mesh)
			_crates.append({"pos": pos, "node": mesh, "cooldown": 0.0})


func allows_attack() -> bool:
	return true


## The crates *are* this game's item system. Letting the generic power-up
## bubbles spawn on top of them puts two unrelated pickup economies on the same
## road, and the player cannot tell from a glance which one they just drove
## through.
func uses_powerups() -> bool:
	return false


func on_round_start() -> void:
	super.on_round_start()
	held.fill(Item.NONE)
	shielded.fill(0.0)
	for crate in _crates:
		crate["cooldown"] = 0.0
		if is_instance_valid(crate["node"]):
			crate["node"].visible = true
	for b in _bombs:
		if is_instance_valid(b["node"]):
			b["node"].queue_free()
	_bombs.clear()
	for m in _missiles:
		if is_instance_valid(m):
			Pool.release(MISSILE_POOL, m)
	_missiles.clear()


func tick(delta: float) -> void:
	super.tick(delta)
	_tick_crates(delta)
	_tick_items(delta)
	_tick_bombs(delta)
	_tick_missiles(delta)


func _tick_crates(delta: float) -> void:
	for crate in _crates:
		var node: Node3D = crate["node"]
		if float(crate["cooldown"]) > 0.0:
			crate["cooldown"] = float(crate["cooldown"]) - delta
			if float(crate["cooldown"]) <= 0.0 and is_instance_valid(node):
				node.visible = true
				AudioManager.play_sfx("tick", crate["pos"], 0.4)
			continue
		if is_instance_valid(node):
			node.rotation.y += delta * 1.6
		for i in ctx.fighters.size():
			var f := ctx.fighter(i)
			if f == null or not is_instance_valid(f) or not ctx.is_alive(i):
				continue
			if held[i] != Item.NONE:
				continue
			var to: Vector3 = f.global_position - crate["pos"]
			to.y = 0.0
			if to.length() > 1.9:
				continue
			held[i] = _roll_item(i)
			crate["cooldown"] = CRATE_RESPAWN
			if is_instance_valid(node):
				node.visible = false
			ctx.bump_detail(i, "crates")
			AudioManager.play_sfx("pickup", f.global_position)
			break


## Item odds by position. Last place gets the tools to close a gap; the leader
## gets the tools to defend one. Without this the race is over at the first
## crate row, which the balance simulator reported as a 0.41 before the weight
## split and 0.55 after.
func _roll_item(slot: int) -> int:
	var behind := 0
	for i in ctx.fighters.size():
		if i != slot and _progress_of(i) > _progress_of(slot):
			behind += 1
	var pool: Array[int] = []
	if behind == 0:
		pool = [Item.BOMB, Item.BOMB, Item.SHIELD, Item.SHIELD, Item.MISSILE, Item.BOOST]
	elif behind == 1:
		pool = [Item.BOMB, Item.MISSILE, Item.MISSILE, Item.SHIELD, Item.BOOST, Item.BOOST]
	else:
		pool = [Item.MISSILE, Item.MISSILE, Item.MISSILE, Item.BOOST, Item.BOOST, Item.SHIELD]
	return pool[ctx.rng.randi_range(0, pool.size() - 1)]


func _progress_of(slot: int) -> int:
	if slot >= lap.size():
		return 0
	return lap[slot] * 1000 + _next_cp[slot]


func _tick_items(delta: float) -> void:
	for i in ctx.fighters.size():
		shielded[i] = maxf(0.0, shielded[i] - delta)
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		if held[i] == Item.NONE:
			continue
		if InputRouter.frame(i).just_pressed(InputFrame.Btn.ATTACK):
			_use(i, f)


func _use(slot: int, f) -> void:
	var item: int = held[slot]
	held[slot] = Item.NONE
	match item:
		Item.BOOST:
			f.apply_impulse(f.facing.normalized() * 13.0)
			AudioManager.play_sfx("dash", f.global_position)
		Item.SHIELD:
			shielded[slot] = 6.0
			AudioManager.play_sfx("pickup", f.global_position)
		Item.BOMB:
			_drop_bomb(slot, f)
		Item.MISSILE:
			_launch_missile(slot, f)


## Bombs are dropped behind, which is why they arm on a delay: a bomb that is
## live the instant it leaves the kart detonates on the kart that dropped it
## every time the road curves.
func _drop_bomb(slot: int, f) -> void:
	var mesh := MeshFactory.sphere(0.42, UIKit.DANGER, 0.9)
	var pos: Vector3 = f.global_position - f.facing.normalized() * 2.4 + Vector3(0, 0.45, 0)
	mesh.position = pos
	ctx.world_root.add_child(mesh)
	_bombs.append({"pos": pos, "node": mesh, "owner": slot, "arm": BOMB_ARM_DELAY, "life": BOMB_LIFETIME})
	AudioManager.play_sfx("bounce", pos, 0.7)


func _tick_bombs(delta: float) -> void:
	var i := _bombs.size() - 1
	while i >= 0:
		var b = _bombs[i]
		b["arm"] = float(b["arm"]) - delta
		b["life"] = float(b["life"]) - delta
		var node: Node3D = b["node"]
		if is_instance_valid(node):
			node.scale = Vector3.ONE * (1.0 + sin(float(b["life"]) * 9.0) * 0.09)
		var done := float(b["life"]) <= 0.0
		if not done and float(b["arm"]) <= 0.0:
			for s in ctx.fighters.size():
				if s == int(b["owner"]) and float(b["arm"]) > -0.9:
					continue
				var f := ctx.fighter(s)
				if f == null or not is_instance_valid(f) or not ctx.is_alive(s):
					continue
				var to: Vector3 = f.global_position - b["pos"]
				to.y = 0.0
				if to.length() <= BOMB_RADIUS:
					_detonate(b, int(b["owner"]))
					done = true
					break
		if done:
			if is_instance_valid(node):
				node.queue_free()
			_bombs.remove_at(i)
		i -= 1


func _detonate(bomb: Dictionary, owner: int) -> void:
	var pos: Vector3 = bomb["pos"]
	var burst := MeshFactory.burst(UIKit.DANGER, 16, 3.4, 0.6)
	ctx.world_root.add_child(burst)
	burst.global_position = pos
	EventBus.shake(0.4, 0.28)
	AudioManager.play_sfx("explode", pos)
	for s in ctx.fighters.size():
		var f := ctx.fighter(s)
		if f == null or not is_instance_valid(f) or not ctx.is_alive(s):
			continue
		var to: Vector3 = f.global_position - pos
		to.y = 0.0
		if to.length() > BOMB_RADIUS:
			continue
		_spin_out(s, owner, to.normalized() if to.length() > 0.05 else Vector3.FORWARD)


func _launch_missile(slot: int, f) -> void:
	var target := rival_ahead(slot)
	var shot: Projectile = Pool.acquire(MISSILE_POOL)
	if shot == null:
		return
	if shot.get_parent() == null:
		ctx.world_root.add_child(shot)
	shot.configure(UIKit.adapt(ctx.config.players[slot].color()))
	if not shot.hit_fighter.is_connected(_on_missile_hit):
		shot.hit_fighter.connect(_on_missile_hit)
	var dir: Vector3 = f.facing.normalized()
	shot.fire(f.global_position + Vector3(0, 0.9, 0) + dir * 2.0, dir, slot, 30.0, 0.0, 60.0)
	if target >= 0:
		shot.guide(ctx, target, 2.6)
	_missiles.append(shot)
	AudioManager.play_sfx("swing", f.global_position, 0.8)


## The kart directly ahead on the road, not the nearest one in space: on a
## circuit the nearest rival is often a lap behind and on the other side of a
## wall, and firing at them feels broken even when the maths is right.
func rival_ahead(slot: int) -> int:
	var mine := _progress_of(slot)
	var best := -1
	var best_gap := 1 << 30
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i):
			continue
		var gap := _progress_of(i) - mine
		if gap > 0 and gap < best_gap:
			best_gap = gap
			best = i
	if best >= 0:
		return best
	# Nobody ahead: the leader's missile chases whoever is closest behind.
	for i in ctx.fighters.size():
		if i != slot and ctx.is_alive(i):
			return i
	return -1


func _tick_missiles(delta: float) -> void:
	var i := _missiles.size() - 1
	while i >= 0:
		var m := _missiles[i]
		if not is_instance_valid(m) or not m.active:
			if is_instance_valid(m):
				Pool.release(MISSILE_POOL, m)
			_missiles.remove_at(i)
		else:
			m.tick(delta)
		i -= 1


func _on_missile_hit(p: Projectile, shooter: int, victim: int) -> void:
	_spin_out(victim, shooter, p.direction)


## One shared punishment for every weapon, so the player learns a single rule:
## being hit costs you a moment, never the race.
func _spin_out(slot: int, by_slot: int, push: Vector3) -> void:
	if shielded[slot] > 0.0:
		shielded[slot] = 0.0
		AudioManager.play_sfx("bounce", ctx.fighter(slot).global_position if ctx.fighter(slot) != null else Vector3.ZERO)
		return
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f):
		return
	f.stun(SPIN_SECONDS)
	f.apply_impulse(push.normalized() * 7.0 + Vector3.UP * 2.0)
	ctx.bump_detail(slot, "spun")
	if by_slot >= 0 and by_slot != slot:
		ctx.bump_detail(by_slot, "hits")
	AudioManager.play_sfx("hit", f.global_position)


## Read by the armed racer brain. A bot knowing what it is holding is not a
## cheat: the human sees the same glyph on their own chip.
func item_of(slot: int) -> int:
	if slot < 0 or slot >= held.size():
		return Item.NONE
	return held[slot]


func held_glyph(slot: int) -> String:
	if slot < 0 or slot >= held.size():
		return ""
	return String(ITEM_GLYPHS.get(held[slot], ""))


func hud_value(slot: int) -> String:
	var base := super.hud_value(slot)
	var glyph := held_glyph(slot)
	if shielded[slot] > 0.0:
		glyph = String(ITEM_GLYPHS[Item.SHIELD]) + glyph
	return base if glyph == "" else "%s %s" % [base, glyph]


func detail_rows() -> Array:
	return [
		{"key": "results.stat.time", "field": "time"},
		{"key": "results.stat.hits", "field": "hits"},
		{"key": "results.stat.crates", "field": "crates"},
	]


func ai_script() -> Script:
	return load("res://src/ai/brains/racer_armed_brain.gd")


func music_track() -> String:
	return "tension"


func cleanup() -> void:
	super.cleanup()
	for b in _bombs:
		if is_instance_valid(b["node"]):
			b["node"].queue_free()
	_bombs.clear()
	for m in _missiles:
		if is_instance_valid(m):
			Pool.release(MISSILE_POOL, m)
	_missiles.clear()
	for c in _crates:
		if is_instance_valid(c["node"]):
			c["node"].queue_free()
	_crates.clear()
