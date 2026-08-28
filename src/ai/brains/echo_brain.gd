extends AIBrain
## Symbol Echo: remember the sequence — imperfectly.
##
## This is the one place a naive AI would be unbeatable, so the memory is
## deliberately lossy: each step has an `accuracy` chance of being recalled, and
## a forgotten step becomes a guess. Expert remembers almost everything; Easy
## remembers about half and fumbles the rest, exactly like a distracted person.
##
## Two properties keep that honest. A belief is *sticky within a step*, because
## re-deciding every tick would average the error away and hand the bot a
## correct answer it never earned. And a belief is *revised once it is proven
## wrong*, because walking into the same wrong pad forever is not forgetfulness,
## it is a soft lock: a miss resets progress to zero, so a bot that keeps its
## disproven guess re-walks the same wrong pad and can never score again.

var _recall_noise := {}
var _ruled_out := {}
var _serial := -1
var _seen_mistakes := 0
var _attempt := -1


func on_round_start() -> void:
	super.on_round_start()
	_forget_all()
	_serial = -1
	_seen_mistakes = 0


func decide(_delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		return
	_sync_sequence()
	if controller.has_method("is_showing") and bool(controller.call("is_showing")):
		# Watching: stand still in the middle so the walk to any pad is even.
		steer_to(ctx.arena_center(), 0.4)
		return
	var want: int = int(controller.call("expected_pad", slot)) if controller.has_method("expected_pad") else -1
	if want < 0:
		steer_to(ctx.arena_center(), 0.3)
		return
	var step: int = int(controller.call("progress_of", slot)) if controller.has_method("progress_of") else 0
	_note_misses(step)
	var believed := _recall(want, step)
	_attempt = believed
	var pos: Vector3 = controller.call("pad_position", believed) if controller.has_method("pad_position") else ctx.arena_center()
	steer_to(pos)
	if distance_to(pos) > 5.0:
		maybe_dash(0.7)


## A new sequence means new things to misremember. Without this the noise
## dictionary outlives the sequence it was rolled for and a single early slip
## follows the bot for the rest of the round.
func _sync_sequence() -> void:
	if not controller.has_method("sequence_serial"):
		return
	var serial := int(controller.call("sequence_serial"))
	if serial != _serial:
		_serial = serial
		_forget_all()


## A miss is the one piece of feedback the bot is allowed to learn from — the
## player gets the same buzzer. Drop the disproven belief and remember not to
## try that pad again for this step.
func _note_misses(step: int) -> void:
	if not controller.has_method("mistakes_of"):
		return
	var total := int(controller.call("mistakes_of", slot))
	if total <= _seen_mistakes:
		return
	_seen_mistakes = total
	if _attempt < 0:
		return
	var failed_step: int = step
	# A miss resets progress to zero, so the step that just failed is whatever
	# the bot was attempting, not the step it is being asked for now.
	if not _ruled_out.has(failed_step):
		_ruled_out[failed_step] = []
	var tried: Array = _ruled_out[failed_step]
	if not tried.has(_attempt):
		tried.append(_attempt)
	_recall_noise.erase(failed_step)
	_attempt = -1


func _forget_all() -> void:
	_recall_noise.clear()
	_ruled_out.clear()
	_attempt = -1


## Returns what this brain *thinks* the step's pad is. Rolled once per step and
## kept, so the mistake is a real memory failure rather than a coin flip the
## bot re-tosses until it wins.
func _recall(true_index: int, step: int) -> int:
	if _recall_noise.has(step):
		return int(_recall_noise[step])
	var tried: Array = _ruled_out.get(step, [])
	var guess := true_index
	if rng.randf() >= accuracy or tried.has(true_index):
		# Forgotten. Guess among the pads this step has not already disproven,
		# which is what a person does after the buzzer.
		var options: Array[int] = []
		for i in 5:
			if not tried.has(i):
				options.append(i)
		if options.is_empty():
			options.append(true_index)
		guess = options[rng.randi_range(0, options.size() - 1)]
	_recall_noise[step] = guess
	return guess
