extends MiniGameController
## Scrap Karts — vehicular demolition.
##
## Karts take damage from being rammed, and how much depends on the *closing*
## speed, not on who hit whom. Reversing into someone at full tilt is as
## effective as charging them head-on, which is the kind of detail that makes a
## simple ram loop worth mastering.

var health: Array[float] = []
var _max_health := 100.0
var _ram_damage := 18.0
var _threshold := 7.0
const FLANK_BONUS := 2.2

var _hit_cooldown := {}
var _backwash := 0.2
var _bars: Array = []
var ram_serial := 0
var ram_position := Vector3.ZERO
var wrecks: Array[int] = []
var _ram_ranks := {}


func configure() -> void:
	eliminate_on_fall = true
	lives_per_player = 1
	# Wrecks reward engagement; surviving still determines the winner.
	survival_knockout_weight = 4
	var t := Balance.table("tuning").get("vehicle", {})
	_max_health = float(t.get("max_health", 100.0))
	_backwash = float(t.get("ram_backwash", 0.2))
	_ram_damage = float(t.get("ram_damage", 18.0))
	_threshold = float(t.get("ram_speed_threshold", 7.0))


func build() -> void:
	health.resize(ctx.player_count())
	health.fill(_max_health)
	wrecks.resize(ctx.player_count())
	wrecks.fill(0)
	_ram_ranks.clear()
	for i in ctx.player_count():
		_bars.append(_make_bar(i))


func _make_bar(slot: int) -> Node3D:
	var f := ctx.fighter(slot)
	if f == null:
		return null
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 82
	label.pixel_size = 0.005
	label.outline_size = 18
	label.position = Vector3(0, 2.3, 0)
	label.modulate = UIKit.adapt(ctx.config.players[slot].color())
	f.add_child(label)
	return label


func locomotion() -> int:
	return Fighter.Locomotion.DRIVE


func camera_mode() -> int:
	return ArenaCamera.Mode.ARENA


func on_round_start() -> void:
	health.fill(_max_health)
	_hit_cooldown.clear()
	ram_serial = 0
	ram_position = Vector3.ZERO
	wrecks.fill(0)
	_ram_ranks.clear()
	for fighter in ctx.fighters:
		if fighter != null and is_instance_valid(fighter):
			fighter.face_direction(ctx.arena_center() - fighter.global_position)


func tick(delta: float) -> void:
	for k in _hit_cooldown.keys():
		_hit_cooldown[k] = float(_hit_cooldown[k]) - delta
		if float(_hit_cooldown[k]) <= 0.0:
			_hit_cooldown.erase(k)
	_resolve_rams()
	_refresh_bars()


func _resolve_rams() -> void:
	var hits: Array[Dictionary] = []
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var a := ctx.fighter(i)
		if a == null or not is_instance_valid(a):
			continue
		for j in range(i + 1, ctx.fighters.size()):
			if not ctx.is_alive(j):
				continue
			var b := ctx.fighter(j)
			if b == null or not is_instance_valid(b):
				continue
			var offset: Vector3 = b.global_position - a.global_position
			offset.y = 0.0
			if offset.length() > 2.6:
				continue
			var key := "%d_%d" % [i, j]
			if _hit_cooldown.has(key):
				continue
			var dir := offset.normalized()
			# Only motion into the contact closes the gap; sliding past or separating does not.
			var closing: float = maxf(0.0, (a.velocity - b.velocity).dot(dir))
			if closing < _threshold:
				continue
			_hit_cooldown[key] = 0.5
			# Whoever is driving *into* the contact deals the damage.
			var a_into: float = a.velocity.dot(dir)
			var b_into: float = -b.velocity.dot(dir)
			var scale := closing / maxf(_threshold, 0.1)
			# Where you hit them matters as much as how hard. A kart caught
			# across the flank or from behind cannot brace or bounce off; a
			# head-on is two chassis meeting and both crews walking away. Flat
			# 0.6/0.2 damage made every exchange mutually destructive, so the
			# tiers that aimed well simply engaged more and died sooner —
			# precision had no payoff and every profile knob measured *better*
			# turned down. Angle is what precision buys.
			var flank_a := _flank_multiplier(b, dir)
			var flank_b := _flank_multiplier(a, -dir)
			if is_equal_approx(a_into, b_into):
				# Neither rider is the attacker in an equal closing contact.
				# Share the existing primary/backwash budget, not the slot order.
				_queue_ram_hit(hits, j, i, _ram_damage * scale * (0.6 * flank_a + _backwash) * 0.5, dir)
				_queue_ram_hit(hits, i, j, _ram_damage * scale * (0.6 * flank_b + _backwash) * 0.5, -dir)
			elif a_into > b_into:
				_queue_ram_hit(hits, j, i, _ram_damage * scale * 0.6 * flank_a, dir)
				_queue_ram_hit(hits, i, j, _ram_damage * scale * _backwash, -dir)
			else:
				_queue_ram_hit(hits, i, j, _ram_damage * scale * 0.6 * flank_b, -dir)
				_queue_ram_hit(hits, j, i, _ram_damage * scale * _backwash, dir)
			ram_serial += 1
			ram_position = a.global_position
			EventBus.shake(0.35, 0.2)
			AudioManager.play_sfx("hit", a.global_position)
	# All contacts describe the same physics frame; an early wreck cannot
	# erase its already-occurring contact with the next rider.
	_apply_ram_hits(hits)


func _queue_ram_hit(hits: Array[Dictionary], victim: int, attacker: int, amount: float, dir: Vector3) -> void:
	hits.append({"victim": victim, "attacker": attacker, "amount": amount, "direction": dir})


## 1.0 head-on, rising toward `FLANK_BONUS` as the hit swings round to the
## victim's side or back. `impact` points from the attacker toward the victim.
func _flank_multiplier(victim, impact: Vector3) -> float:
	if victim == null or not is_instance_valid(victim):
		return 1.0
	var facing: Vector3 = victim.facing
	facing.y = 0.0
	var hit: Vector3 = impact
	hit.y = 0.0
	if facing.length() < 0.1 or hit.length() < 0.1:
		return 1.0
	# -1 means the impact arrives straight at the nose, +1 straight up the back.
	var alignment: float = facing.normalized().dot(hit.normalized())
	return lerpf(1.0, FLANK_BONUS, clampf((alignment + 1.0) * 0.5, 0.0, 1.0))


func _damage(victim: int, attacker: int, amount: float, dir: Vector3) -> void:
	if not ctx.is_alive(attacker):
		return
	var hits: Array[Dictionary] = []
	_queue_ram_hit(hits, victim, attacker, amount, dir)
	_apply_ram_hits(hits)


func _apply_ram_hits(hits: Array[Dictionary]) -> void:
	var contributions := {}
	for hit in hits:
		var victim: int = hit.victim
		if not ctx.is_alive(victim):
			continue
		var attacker: int = hit.attacker
		var amount: float = hit.amount
		health[victim] = maxf(0.0, health[victim] - amount)
		var f := ctx.fighter(victim)
		if f != null and is_instance_valid(f):
			f.take_ram_hit(attacker, hit.direction, amount * 0.5)
		var row: Dictionary = contributions.get(victim, {})
		row[attacker] = float(row.get(attacker, 0.0)) + amount
		contributions[victim] = row
	var destroyed: Array[int] = []
	var credits := {}
	for victim in contributions:
		var strongest := 0.0
		var leaders: Array[int] = []
		var row: Dictionary = contributions[victim]
		for attacker in row:
			var amount: float = row[attacker]
			if is_equal_approx(amount, strongest):
				leaders.append(attacker)
			elif amount > strongest:
				strongest = amount
				leaders.assign([attacker])
		credits[victim] = leaders
		var f := ctx.fighter(victim)
		if f != null and is_instance_valid(f):
			# A tied push has no single owner for a later fall. A direct wreck
			# below credits the equally strongest contributors together.
			f._last_hit_by = leaders[0] if leaders.size() == 1 else -1
			if leaders.size() != 1:
				f._last_hit_timer = 0.0
		if health[victim] <= 0.0:
			destroyed.append(victim)
	var tied_rank := ctx.elimination_order.size() + 1
	for victim in destroyed:
		if destroyed.size() > 1:
			_ram_ranks[victim] = tied_rank
		wrecks[victim] += 1
		for attacker in credits[victim]:
			ctx.bump_detail(attacker, "knockouts")
		ctx.bump_detail(victim, "falls")
		var f := ctx.fighter(victim)
		var wreck_position := f.global_position if f != null else Vector3.ZERO
		ctx.eliminate(victim)
		AudioManager.play_sfx("explode", wreck_position)


func compute_scores() -> Array[int]:
	if _ram_ranks.is_empty() or def == null or def.scoring != MiniGameDef.Scoring.SURVIVAL:
		return super.compute_scores()
	var scores := ctx.survival_scores()
	for slot in scores.size():
		if not ctx.is_alive(slot) and _ram_ranks.has(slot):
			scores[slot] = int(_ram_ranks[slot])
		scores[slot] = scores[slot] * 2 + int(ctx.details[slot].get("knockouts", 0)) * survival_knockout_weight
	return _prioritize_survivors(scores)


func _refresh_bars() -> void:
	for i in _bars.size():
		var label = _bars[i]
		if label == null or not is_instance_valid(label):
			continue
		var pct := int(round(health[i] / _max_health * 100.0))
		label.text = "%d%%" % pct
		label.visible = ctx.is_alive(i)


func on_fighter_fell(slot: int) -> void:
	health[slot] = 0.0
	super.on_fighter_fell(slot)


func ai_script() -> Script:
	return load("res://src/ai/brains/driver_brain.gd")


func hud_value(slot: int) -> String:
	if not ctx.is_alive(slot):
		return Loc.t("hud.eliminated")
	return "%d%%" % int(round(health[slot] / _max_health * 100.0))


func detail_rows() -> Array:
	return [{"key": "results.stat.knockouts", "field": "knockouts"}]


func music_track() -> String:
	return "arena_b"
