extends AIBrain
## Quick Draw: press on the signal, and sometimes jump the gun.
##
## The bot's press comes `reaction_time` after the signal appears — the same
## information a human has, delayed the same way. False starts are modelled by
## `mistake_chance`, so higher tiers are not just faster, they are steadier.

var _armed := false
var _fire_at := -1.0
var _false_start_roll := -1.0


func decide(_delta: float) -> void:
	if controller == null:
		return
	var signalled: bool = bool(controller.call("is_signalled")) if controller.has_method("is_signalled") else false
	var locked: bool = bool(controller.call("is_locked", slot)) if controller.has_method("is_locked") else false
	if locked:
		return

	if not signalled:
		_armed = false
		_fire_at = -1.0
		# Roll once per waiting phase for an itchy trigger finger.
		if _false_start_roll < 0.0:
			_false_start_roll = rng.randf()
		if _false_start_roll < mistake_chance * 0.6:
			_false_start_roll = 1.0
			press(Btn.ATTACK)
		return

	_false_start_roll = -1.0
	var age: float = float(controller.call("signal_age")) if controller.has_method("signal_age") else 0.0
	if not _armed:
		_armed = true
		_fire_at = reaction_time * rng.randf_range(0.85, 1.25)
	if age >= _fire_at:
		press(Btn.ATTACK)
