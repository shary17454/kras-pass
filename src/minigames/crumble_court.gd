extends MiniGameController
## Crumble Court — the floor is the enemy.
##
## Standing on a tile arms it; a moment later it drops. The tension comes from
## the fact that the safest-looking ground is the ground nobody has walked on,
## which is always the ground furthest from where you are.


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
	var arena := ctx.arena as Arena
	if arena == null:
		return
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f) or not f.is_on_floor():
			continue
		var tile := arena.tile_at(f.global_position)
		if tile != null:
			tile.touch()


func on_sudden_death() -> void:
	# Everything still standing starts falling; the round resolves in seconds.
	var arena := ctx.arena as Arena
	if arena == null:
		return
	var i := 0
	for tile in arena.tiles:
		if tile.state == ArenaTile.State.SOLID and i % 2 == 0:
			tile.touch()
		i += 1


func ai_script() -> Script:
	return load("res://src/ai/brains/platform_brain.gd")


func hud_value(slot: int) -> String:
	return Loc.t("hud.eliminated") if not ctx.is_alive(slot) else "●"


func detail_rows() -> Array:
	return [{"key": "results.stat.falls", "field": "falls"}]
