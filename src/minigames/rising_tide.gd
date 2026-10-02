extends MiniGameController
## Rising Tide — climb the spire while the water comes up.
##
## The arena already owns the water; this game only decides what touching it
## means and hands the AI a reason to go up. Shoving still works, and shoving
## someone off a ledge into rising water is the fastest way to end them.

var _eliminated_at: Dictionary = {}


func configure() -> void:
	eliminate_on_fall = true
	lives_per_player = 1


func build() -> void:
	pass


func on_round_start() -> void:
	_eliminated_at.clear()
	var arena := ctx.arena as Arena
	if arena != null:
		arena.reset_hazards()


func _handle_out(slot: int) -> void:
	var was_alive := ctx.is_alive(slot)
	super._handle_out(slot)
	if was_alive and not ctx.is_alive(slot):
		_eliminated_at[slot] = ctx.arena._water._age


func compute_scores() -> Array[int]:
	var ranks := ctx.survival_scores()
	for slot in _eliminated_at:
		# Water processes a batch of victims; iteration order is not survival skill.
		var rank := 1
		for other in _eliminated_at:
			if float(_eliminated_at[other]) < float(_eliminated_at[slot]) and not is_equal_approx(float(_eliminated_at[other]), float(_eliminated_at[slot])):
				rank += 1
		ranks[slot] = rank
	for slot in ranks.size():
		ranks[slot] = ranks[slot] * 2 + int(ctx.details[slot].get("knockouts", 0)) * survival_knockout_weight
	return ranks


func tick(_delta: float) -> void:
	# Survival time is the reward loop; the score itself comes from elimination
	# order, so nothing to accumulate here.
	pass


func on_sudden_death() -> void:
	# Water speed doubles; nobody outlasts this for long.
	var arena := ctx.arena as Arena
	if arena == null:
		return
	for child in arena.get_children():
		if child is ArenaHazards.RisingWater:
			child.speed *= 2.4


func hud_value(slot: int) -> String:
	if not ctx.is_alive(slot):
		return Loc.t("hud.eliminated")
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f):
		return "●"
	return "%.0fm" % maxf(0.0, f.global_position.y)


func hud_banner() -> String:
	var arena := ctx.arena as Arena
	if arena == null:
		return ""
	var level := arena.water_level()
	return "" if level == -INF else "≋ %.1f" % level


func ai_script() -> Script:
	return load("res://src/ai/brains/climber_brain.gd")


func detail_rows() -> Array:
	return [{"key": "results.stat.falls", "field": "falls"}]


func music_track() -> String:
	return "tension"
