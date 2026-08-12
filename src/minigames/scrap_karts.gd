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
var _hit_cooldown := {}
var _bars: Array = []


func configure() -> void:
	eliminate_on_fall = true
	lives_per_player = 1
	var t := Balance.table("tuning").get("vehicle", {})
	_max_health = float(t.get("max_health", 100.0))
	_ram_damage = float(t.get("ram_damage", 18.0))
	_threshold = float(t.get("ram_speed_threshold", 7.0))


func build() -> void:
	health.resize(ctx.player_count())
	health.fill(_max_health)
	for i in ctx.player_count():
		_bars.append(_make_bar(i))


func _make_bar(slot: int) -> Node3D:
	var f := ctx.fighter(slot)
	if f == null:
		return null
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
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


func tick(delta: float) -> void:
	for k in _hit_cooldown.keys():
		_hit_cooldown[k] = float(_hit_cooldown[k]) - delta
		if float(_hit_cooldown[k]) <= 0.0:
			_hit_cooldown.erase(k)
	_resolve_rams()
	_refresh_bars()


func _resolve_rams() -> void:
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
			var closing: float = (a.velocity - b.velocity).length()
			if closing < _threshold:
				continue
			_hit_cooldown[key] = 0.5
			# Whoever is driving *into* the contact deals the damage.
			var dir := offset.normalized()
			var a_into: float = a.velocity.dot(dir)
			var b_into: float = -b.velocity.dot(dir)
			var scale := closing / maxf(_threshold, 0.1)
			if a_into > b_into:
				_damage(j, i, _ram_damage * scale * 0.6, dir)
				_damage(i, j, _ram_damage * scale * 0.2, -dir)
			else:
				_damage(i, j, _ram_damage * scale * 0.6, -dir)
				_damage(j, i, _ram_damage * scale * 0.2, dir)
			EventBus.shake(0.35, 0.2)
			AudioManager.play_sfx("hit", a.global_position)


func _damage(victim: int, attacker: int, amount: float, dir: Vector3) -> void:
	if not ctx.is_alive(victim):
		return
	health[victim] = maxf(0.0, health[victim] - amount)
	var f := ctx.fighter(victim)
	if f != null and is_instance_valid(f):
		f.take_hit(attacker, dir, amount * 0.5, 0.0, true)
	if health[victim] <= 0.0:
		ctx.bump_detail(attacker, "knockouts")
		ctx.bump_detail(victim, "falls")
		ctx.eliminate(victim)
		AudioManager.play_sfx("explode", f.global_position if f != null else Vector3.ZERO)


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
