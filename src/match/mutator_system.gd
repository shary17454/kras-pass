class_name MutatorSystem
extends RefCounted
## Match modifiers, applied from data.
##
## A mutator changes how a round feels without any mini-game knowing it exists:
## the same twenty-one games become low-gravity games, icy games, giant games or
## no-power-up games. That is content multiplied by a factor, for one file.
##
## Chaos mode schedules mutators to switch mid-round. The schedule is drawn from
## the match seed, so everyone in a party — and any replay — sees the same
## sequence at the same moment.

const CHAOS_INTERVAL := 25.0

var ctx: MatchContext
var active: Array[String] = []

var _defs := {}
var _schedule: Array = []
var _next_event := 0
var _elapsed := 0.0
var _chaos := false
var _base_friction := 0.0


func setup(context: MatchContext, ids: Array, chaos: bool = false) -> void:
	ctx = context
	_chaos = chaos
	for d in Balance.list("mutators", "mutators"):
		_defs[String(d.get("id", ""))] = d
	active.clear()
	for id in ids:
		if _compatible(String(id)):
			active.append(String(id))
	_base_friction = Balance.num("tuning", "fighter.friction", 36.0)
	if _chaos:
		_build_chaos_schedule()
	apply()


## A mutator has to make sense for this game and not contradict one already on.
func _compatible(id: String) -> bool:
	var d: Dictionary = _defs.get(id, {})
	if d.is_empty():
		return false
	var categories: Array = d.get("categories", [])
	if not categories.is_empty() and not categories.has(ctx.definition.category_name()):
		return false
	for other in active:
		if (d.get("excludes", []) as Array).has(other):
			return false
		var od: Dictionary = _defs.get(other, {})
		if (od.get("excludes", []) as Array).has(id):
			return false
	return true


## Chaos draws its whole timeline up front from the seed, so it is reproducible
## rather than a stream of surprises the replay cannot recreate.
func _build_chaos_schedule() -> void:
	_schedule.clear()
	var pool: Array = []
	for id in _defs.keys():
		var d: Dictionary = _defs[id]
		var categories: Array = d.get("categories", [])
		if categories.is_empty() or categories.has(ctx.definition.category_name()):
			pool.append(id)
	if pool.is_empty():
		return
	var duration: float = ctx.definition.duration
	var at := CHAOS_INTERVAL
	while at < duration:
		_schedule.append({"at": at, "id": String(pool[ctx.rng.randi_range(0, pool.size() - 1)])})
		at += CHAOS_INTERVAL


func tick(delta: float) -> void:
	if not _chaos or _next_event >= _schedule.size():
		return
	_elapsed += delta
	var event: Dictionary = _schedule[_next_event]
	if _elapsed < float(event["at"]):
		return
	_next_event += 1
	var id := String(event["id"])
	# Swap rather than accumulate: three stacked speed mutators is not chaos,
	# it is a bug the player cannot read.
	active.clear()
	if _compatible(id):
		active.append(id)
	apply()
	var d: Dictionary = _defs.get(id, {})
	EventBus.notify(Loc.t("mutator.%s" % id), String(d.get("glyph", "✦")))


## (Re)apply every active mutator. Cheap enough to call on any change.
func apply() -> void:
	var gravity := 1.0
	var speed := 1.0
	var size := 1.0
	var friction := 1.0
	var knockback := 1.0
	var hazard := 1.0
	var camera := 1.0
	var powerup_rate := 1.0
	var powerups_on := true
	var round_length := 1.0

	for id in active:
		var d: Dictionary = _defs.get(id, {})
		var m := float(d.get("magnitude", 1.0))
		match String(d.get("kind", "")):
			"gravity": gravity *= m
			"speed": speed *= m
			"size": size *= m
			"friction": friction *= m
			"knockback": knockback *= m
			"hazard_rate": hazard *= m
			"camera": camera *= m
			"powerup_rate": powerup_rate *= m
			"powerups_off": powerups_on = false
			"round_length": round_length *= m

	for f in ctx.fighters:
		if not is_instance_valid(f):
			continue
		f.mutator["gravity"] = gravity
		f.mutator["speed"] = speed
		f.mutator["knockback_taken"] = knockback
		f.mutator["friction"] = friction
		f.friction = _base_friction * friction
		f.set_body_scale(size)

	if ctx.powerups != null:
		ctx.powerups.enabled = powerups_on and ctx.config.allow_powerups \
			and ctx.powerups.pool.size() > 0
		ctx.powerups.interval_scale = powerup_rate

	var arena := ctx.arena as Arena
	if arena != null:
		arena.set_hazard_speed(hazard)
	if camera != 1.0:
		EventBus.notify(Loc.t("mutator.close_camera"), "◎")


func round_length_scale() -> float:
	var scale := 1.0
	for id in active:
		var d: Dictionary = _defs.get(id, {})
		if String(d.get("kind", "")) == "round_length":
			scale *= float(d.get("magnitude", 1.0))
	return scale


func camera_scale() -> float:
	var scale := 1.0
	for id in active:
		var d: Dictionary = _defs.get(id, {})
		if String(d.get("kind", "")) == "camera":
			scale *= float(d.get("magnitude", 1.0))
	return scale


func glyphs() -> String:
	var out := ""
	for id in active:
		out += String(_defs.get(id, {}).get("glyph", "✦"))
	return out


## Which mutators may be offered for a given game, for the party setup screen.
static func available_for(def: MiniGameDef) -> Array[String]:
	var out: Array[String] = []
	for d in Balance.list("mutators", "mutators"):
		var categories: Array = d.get("categories", [])
		if categories.is_empty() or categories.has(def.category_name()):
			out.append(String(d.get("id", "")))
	return out
