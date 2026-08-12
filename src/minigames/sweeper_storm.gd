extends MiniGameController
## Sweeper Storm — dodge the arena.
##
## Rotating arms accelerate over the round. The arms are arena furniture, so
## this game is almost entirely presentation and rules: what makes it work is
## that the arms speed up on a schedule the player can feel.


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
	pass


func on_sudden_death() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	for child in arena.get_children():
		if child is ArenaHazards.Sweeper:
			child.speed *= 1.9


func hud_value(slot: int) -> String:
	return Loc.t("hud.eliminated") if not ctx.is_alive(slot) else "●"


func ai_script() -> Script:
	return load("res://src/ai/brains/dodger_brain.gd")


func detail_rows() -> Array:
	return [{"key": "results.stat.falls", "field": "falls"}]


func music_track() -> String:
	return "arena_b"
