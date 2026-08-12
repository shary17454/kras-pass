extends MiniGameController
## Rising Tide — climb the spire while the water comes up.
##
## The arena already owns the water; this game only decides what touching it
## means and hands the AI a reason to go up. Shoving still works, and shoving
## someone off a ledge into rising water is the fastest way to end them.


func configure() -> void:
	eliminate_on_fall = true
	lives_per_player = 1


func build() -> void:
	pass


func on_round_start() -> void:
	var arena := ctx.arena as Arena
	if arena != null:
		arena.reset_hazards()


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
