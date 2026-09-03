extends MiniGameController
## Tag Hunt — one hunter, three runners, and the role changes hands on contact.
##
## The spec lists a chase as its own kind of mini-game, and a chase is not a
## brawl: nobody is trying to remove anybody, everyone is trying not to be the
## one holding the role. Being the hunter costs you points every second you
## keep it and pays three the moment you pass it on, so the pressure inverts
## the instant you touch somebody — which is the whole joke of playing tag.

const TAG_POINTS := 3
const FREE_SECONDS := 2.6
const TAG_RADIUS := 1.7
const HANDOVER_GRACE := 1.3
const HUNTER_SPEED := 1.13

var _hunter := -1
var _grace := 0.0
var _free_accum: Array[float] = []
var _mark: Node3D
var _base_speed := {}


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	_free_accum.resize(ctx.player_count())
	_free_accum.fill(0.0)
	for i in ctx.fighters.size():
		var f := ctx.fighter(i)
		if f != null and is_instance_valid(f):
			_base_speed[i] = f.top_speed


func on_round_start() -> void:
	_free_accum.fill(0.0)
	_set_hunter(ctx.rng.randi() % maxi(ctx.player_count(), 1))
	_grace = HANDOVER_GRACE


func tick(delta: float) -> void:
	_grace = maxf(0.0, _grace - delta)
	if _hunter < 0 or not ctx.is_alive(_hunter):
		_set_hunter(_pick_any_alive())
		return
	var hunter := ctx.fighter(_hunter)
	if hunter == null or not is_instance_valid(hunter):
		return
	if _mark != null and is_instance_valid(_mark):
		_mark.global_position = hunter.global_position + Vector3(0, 2.35, 0)
		_mark.rotation.y += delta * 3.4
	# Staying free pays, slowly. Without it a stalemate where nobody can catch
	# anybody scores nothing at all and the round is decided by the first tag.
	for i in ctx.fighters.size():
		if i == _hunter or not ctx.is_alive(i):
			continue
		_free_accum[i] += delta
		if _free_accum[i] >= FREE_SECONDS:
			_free_accum[i] -= FREE_SECONDS
			ctx.add_score(i, maxi(1, int(round(ctx.powerups.point_multiplier(i)))))
	if _grace > 0.0:
		return
	for i in ctx.fighters.size():
		if i == _hunter or not ctx.is_alive(i):
			continue
		var other := ctx.fighter(i)
		if other == null or not is_instance_valid(other):
			continue
		if hunter.global_position.distance_to(other.global_position) > TAG_RADIUS:
			continue
		_tag(i)
		return


func _tag(victim: int) -> void:
	var scorer := _hunter
	ctx.add_score(scorer, TAG_POINTS)
	ctx.bump_detail(scorer, "tags")
	AudioManager.play_sfx("score")
	var f := ctx.fighter(victim)
	if f != null and is_instance_valid(f):
		f.apply_impulse(Vector3.UP * 3.2)
		AudioManager.play_sfx("bounce", f.global_position)
	InputRouter.rumble(victim, 0.7, 0.18)
	InputRouter.rumble(scorer, 0.45, 0.12)
	EventBus.notify(Loc.t("tag.passed", {"name": _name_of(victim)}), "☄")
	_set_hunter(victim)
	_grace = HANDOVER_GRACE


## The hunter is a little faster, or a full field of equals never produces a
## tag at all. Speed is written straight onto the fighter and restored on
## handover: the power-up and mutator channels are owned by their own systems
## and rebuilt from scratch whenever they change, so a game that borrowed one
## would have its role bonus quietly erased by the next pickup.
func _set_hunter(slot: int) -> void:
	if _hunter >= 0:
		var previous := ctx.fighter(_hunter)
		if previous != null and is_instance_valid(previous):
			previous.top_speed = float(_base_speed.get(_hunter, previous.top_speed))
	_hunter = slot
	if _hunter < 0:
		_clear_mark()
		return
	var f := ctx.fighter(_hunter)
	if f != null and is_instance_valid(f):
		f.top_speed = float(_base_speed.get(_hunter, f.top_speed)) * HUNTER_SPEED
		_build_mark(f)


func _pick_any_alive() -> int:
	var alive := ctx.alive_slots()
	return int(alive[0]) if not alive.is_empty() else -1


func _build_mark(f: Fighter) -> void:
	_clear_mark()
	if DisplayServer.get_name() == "headless":
		return
	_mark = Node3D.new()
	_mark.name = "HunterMark"
	ctx.world_root.add_child(_mark)
	for i in 3:
		var ang := TAU * float(i) / 3.0
		var spike := MeshFactory.cone(0.18, 0.46, Color(1.0, 0.35, 0.42))
		spike.position = Vector3(cos(ang) * 0.34, 0.0, sin(ang) * 0.34)
		spike.rotation.x = PI
		_mark.add_child(spike)
	var ring := MeshFactory.torus(0.38, 0.56, Color(1.0, 0.5, 0.35), 1.7)
	_mark.add_child(ring)
	_mark.global_position = f.global_position + Vector3(0, 2.35, 0)


func _clear_mark() -> void:
	if _mark != null and is_instance_valid(_mark):
		_mark.queue_free()
	_mark = null


func _name_of(slot: int) -> String:
	var p := ctx.config.player_at(slot)
	return p.display_name() if p != null else "P%d" % (slot + 1)


# --- shared-layer answers --------------------------------------------------

func hunter() -> int:
	return _hunter


func handover_grace() -> float:
	return _grace


func hud_value(slot: int) -> String:
	return "%d%s" % [ctx.scores[slot], "  ☄" if slot == _hunter else ""]


func hud_banner() -> String:
	if _hunter < 0:
		return ""
	return Loc.t("tag.hunter", {"name": _name_of(_hunter)})


func ai_script() -> Script:
	return load("res://src/ai/brains/tag_brain.gd")


func detail_rows() -> Array:
	return [{"key": "results.stat.tags", "field": "tags"}]


func cleanup() -> void:
	_set_hunter(-1)
	_clear_mark()
