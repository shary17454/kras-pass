extends "res://src/minigames/goal_guard.gd"
## Magnet Court — Goal Guard where your best save is also your best shot.
##
## Each keeper carries a magnet on a recharging meter. Fire it and for a beat
## every ball nearby bends toward you and sticks; when the beat ends the caught
## balls all launch together, hard, away from your wall. Holding forever is not
## an option — the charge is the timer — so the skill is *when*: a panic grab
## saves one goal, a greedy grab under the right traffic turns defence into a
## three-ball counter-attack.

const MAGNET_RADIUS := 6.5
const MAGNET_TIME := 1.1
const MAGNET_PULL := 34.0
const RECHARGE_TIME := 7.0
const RELEASE_SPEED := 17.0

var _magnet_until: Array[float] = []
var _charge: Array[float] = []
var _held := {}


func configure() -> void:
	super.configure()
	_magnet_until.resize(4)
	_magnet_until.fill(0.0)
	_charge.resize(4)
	_charge.fill(1.0)


func on_round_start() -> void:
	super.on_round_start()
	_magnet_until.fill(0.0)
	_charge.fill(1.0)
	_held.clear()


func tick(delta: float) -> void:
	super.tick(delta)
	for i in ctx.player_count():
		if _charge[i] < 1.0:
			_charge[i] = minf(1.0, _charge[i] + delta / RECHARGE_TIME)
		if _magnet_until[i] > 0.0:
			_magnet_until[i] -= delta
			if _magnet_until[i] <= 0.0:
				_release(i)
			else:
				_attract(i, delta)
		elif ctx.is_alive(i) and _charge[i] >= 1.0 \
				and InputRouter.frame(i).just_pressed(InputFrame.Btn.ABILITY):
			_activate(i)


func _activate(slot: int) -> void:
	_charge[slot] = 0.0
	_magnet_until[slot] = MAGNET_TIME
	var f := ctx.fighter(slot)
	if f != null and is_instance_valid(f):
		AudioManager.play_sfx("powerup", f.global_position)


func _attract(slot: int, delta: float) -> void:
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f):
		return
	for b in balls:
		if not is_instance_valid(b):
			continue
		var holder := int(_held.get(b.get_instance_id(), -1))
		if holder >= 0 and holder != slot:
			continue
		var to: Vector3 = f.global_position - b.global_position
		to.y = 0.0
		var d := to.length()
		if d > MAGNET_RADIUS:
			continue
		if d < 1.5:
			# Caught: park it in orbit and remember whose it is. The catch also
			# claims the touch, so a goal off the release credits the thrower.
			_held[b.get_instance_id()] = slot
			b.last_toucher = slot
			b.velocity = b.velocity.limit_length(2.0)
		else:
			b.velocity = b.velocity.move_toward(to.normalized() * MAGNET_PULL, MAGNET_PULL * 2.0 * delta)


func _release(slot: int) -> void:
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f):
		_held.clear()
		return
	var away := _away_from_goal(slot)
	var released := 0
	for b in balls:
		if not is_instance_valid(b) or int(_held.get(b.get_instance_id(), -1)) != slot:
			continue
		# Fan the volley a little so three balls do not fly as one.
		var jitter := ctx.rng.randf_range(-0.35, 0.35)
		var dir := away.rotated(Vector3.UP, jitter)
		b.launch(b.global_position, dir, RELEASE_SPEED)
		b.last_toucher = slot
		released += 1
	for k in _held.keys():
		if int(_held[k]) == slot:
			_held.erase(k)
	if released > 0:
		ctx.bump_detail(slot, "volleys", released)
		AudioManager.play_sfx("shoot", f.global_position)


## Straight back across the court, away from this keeper's own wall.
func _away_from_goal(slot: int) -> Vector3:
	var side := int(_side_of_slot.get(slot, slot % 4))
	var dirs := [Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)]
	return dirs[side]


## The AI reads the same meter the HUD shows.
func magnet_ready(slot: int) -> bool:
	return _charge[slot] >= 1.0 and _magnet_until[slot] <= 0.0


func hud_value(slot: int) -> String:
	var base := str(ctx.scores[slot])
	if _magnet_until[slot] > 0.0:
		return base + " ⌁"
	return base + (" ●" if _charge[slot] >= 1.0 else " ○")


func ai_script() -> Script:
	return load("res://src/ai/brains/magnet_keeper_brain.gd")


func detail_rows() -> Array:
	return [
		{"key": "results.stat.saves", "field": "saves"},
		{"key": "results.stat.volleys", "field": "volleys"},
	]
