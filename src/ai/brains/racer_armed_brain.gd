extends "res://src/ai/brains/racer_brain.gd"
## Rocket Rally: drive the racing line, then decide when to spend the item.
##
## Driving is inherited untouched. Everything here is about *timing*, because
## that is the only part of a weapon race a skilled player is better at — the
## item you draw is luck, the moment you spend it is not.
##
## Skill is expressed as patience. A low-skill bot fires the instant it picks
## anything up; a high-skill one holds a bomb until somebody is actually on its
## tail and holds a boost until the road ahead is straight.

## The game script is preloaded purely for its `Item` enum. The dependency only
## runs this way — the game loads this brain at runtime — so there is no cycle.
const Race := preload("res://src/minigames/sabaq_sawarikh.gd")

const MISSILE_RANGE := 46.0
const BOMB_TRIGGER := 11.0


func decide(delta: float) -> void:
	super.decide(delta)
	if controller == null or not controller.has_method("item_of"):
		return
	var me := self_body()
	if me == null:
		return
	var item: int = controller.call("item_of", slot)
	if item == Race.Item.NONE:
		return
	if _should_use(item, me):
		press(Btn.ATTACK)


func _should_use(item: int, me: Fighter) -> bool:
	# Impatience is the low-skill failure mode, so it is modelled directly:
	# below this bar the bot spends whatever it has as soon as it has it.
	if rng.randf() > strategy:
		return true
	match item:
		Race.Item.SHIELD:  # Purely defensive; there is no clever moment for it.
			return true
		Race.Item.BOOST:  # Only worth it pointing down the road, not at a wall.
			return _aimed_at_line(me) and me.speed_ratio() > 0.55
		Race.Item.MISSILE:  # Needs somebody ahead on the road, not merely near.
			var target: int = controller.call("rival_ahead", slot) \
				if controller.has_method("rival_ahead") else -1
			if target < 0:
				return false
			return me.global_position.distance_to(predict(target, 0.4)) < MISSILE_RANGE
		Race.Item.BOMB:  # A mine is worth nothing dropped on an empty road.
			return _tailed()
	return false


## Is anyone close behind? Uses the delayed view like every other perception:
## a bot that reads live positions to time a mine is reading a rival's mind.
func _tailed() -> bool:
	var me := self_body()
	if me == null:
		return false
	var back := -me.facing.normalized()
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i):
			continue
		var seen := perceive(i)
		if seen == Vector3.ZERO:
			continue
		var to := seen - me.global_position
		to.y = 0.0
		if to.length() > BOMB_TRIGGER:
			continue
		if to.normalized().dot(back) > 0.55:
			return true
	return false


## Roughly pointing at the next checkpoint, i.e. the road ahead is straight
## enough that spending a boost is not spending it into a wall.
func _aimed_at_line(me: Fighter) -> bool:
	if controller == null or not controller.has_method("next_checkpoint"):
		return true
	var next: Vector3 = controller.call("next_checkpoint", slot)
	var to := next - me.global_position
	to.y = 0.0
	if to.length_squared() < 0.01:
		return true
	return me.facing.normalized().dot(to.normalized()) > 0.86
