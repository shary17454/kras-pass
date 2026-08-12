extends AIBrain
## Symbol Echo: remember the sequence — imperfectly.
##
## This is the one place a naive AI would be unbeatable, so the memory is
## deliberately lossy: each step has an `accuracy` chance of being recalled, and
## a forgotten step becomes a guess. Expert remembers almost everything; Easy
## remembers about half and fumbles the rest, exactly like a distracted person.

var _memory: Array[int] = []
var _recall_noise := {}
var _target_index := -1


func on_round_start() -> void:
	super.on_round_start()
	_memory.clear()
	_recall_noise.clear()


func decide(_delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		return
	if bool(controller.call("is_showing")) if controller.has_method("is_showing") else false:
		# Watching: stand still in the middle so the walk to any pad is even.
		steer_to(ctx.arena_center(), 0.4)
		return
	var want: int = int(controller.call("expected_pad", slot)) if controller.has_method("expected_pad") else -1
	if want < 0:
		steer_to(ctx.arena_center(), 0.3)
		return
	var believed := _recall(want)
	var pos: Vector3 = controller.call("pad_position", believed) if controller.has_method("pad_position") else ctx.arena_center()
	steer_to(pos)
	if distance_to(pos) > 5.0:
		maybe_dash(0.7)


## Returns what this brain *thinks* the next pad is. Wrong answers are sticky —
## re-deciding every tick would average the error away and make the bot correct.
func _recall(true_index: int) -> int:
	var key := "%d_%d" % [_memory.size(), true_index]
	if not _recall_noise.has(key):
		if rng.randf() < accuracy:
			_recall_noise[key] = true_index
		else:
			_recall_noise[key] = rng.randi_range(0, 4)
	return int(_recall_noise[key])
