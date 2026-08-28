extends MiniGameController
## Paint Grid — territory by attrition.
##
## Every tile you cross becomes yours, including tiles a rival already claimed.
## The score is literally the floor, recomputed on a slow tick because counting
## 150 tiles every frame is waste and nobody can read a score that fast anyway.

const RECOUNT_PERIOD := 0.2

var _recount := 0.0
var _tiles: Array[ArenaTile] = []


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	_tiles = arena.tiles
	for t in _tiles:
		t.owner_slot = -1


func on_round_start() -> void:
	for t in _tiles:
		t.owner_slot = -1
		t.set_color(t.base_color)
	for i in ctx.player_count():
		ctx.set_score(i, 0)


func tick(delta: float) -> void:
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
		if tile == null:
			continue
		if tile.claim(i, UIKit.adapt(ctx.config.players[i].color())):
			AudioManager.play_sfx("tick", f.global_position, 1.0 + i * 0.06)
			_on_tile_claimed(tile, i)
		# A dash paints a small cross, which rewards committed movement over
		# shuffling back and forth on one square.
		if f.is_dashing():
			_paint_neighbours(arena, tile, i)
	_recount -= delta
	if _recount <= 0.0:
		_recount = RECOUNT_PERIOD
		_recount_scores()


func _paint_neighbours(arena: Arena, centre: ArenaTile, slot: int) -> void:
	var col := UIKit.adapt(ctx.config.players[slot].color())
	for t in _tiles:
		if absi(t.grid_x - centre.grid_x) + absi(t.grid_z - centre.grid_z) == 1:
			if t.claim(slot, col):
				_on_tile_claimed(t, slot)


## Hook for family variants: fired once per tile that actually changed hands.
func _on_tile_claimed(_tile: ArenaTile, _slot: int) -> void:
	pass


func _recount_scores() -> void:
	var counts: Array[int] = []
	counts.resize(ctx.player_count())
	counts.fill(0)
	for t in _tiles:
		if t.owner_slot >= 0 and t.owner_slot < counts.size():
			counts[t.owner_slot] += 1
	for i in counts.size():
		if ctx.scores[i] != counts[i]:
			ctx.set_score(i, counts[i])


func on_round_end() -> void:
	_recount_scores()


func is_round_over() -> bool:
	if ctx.early_finish:
		return true
	# Nothing left to claim.
	for t in _tiles:
		if t.owner_slot < 0:
			return false
	return false


func ai_script() -> Script:
	return load("res://src/ai/brains/painter_brain.gd")


func camera_mode() -> int:
	return ArenaCamera.Mode.TOP_DOWN


func uses_powerups() -> bool:
	return true


func detail_rows() -> Array:
	return [{"key": "results.stat.tiles", "field": "tiles"}]


func unclaimed_tile_near(pos: Vector3, slot: int) -> ArenaTile:
	var best: ArenaTile = null
	var best_d := INF
	for t in _tiles:
		if t.owner_slot == slot:
			continue
		var d: float = t.global_position.distance_squared_to(pos)
		# Unowned ground is worth slightly more than stealing, so bots spread
		# out instead of all fighting over the middle.
		if t.owner_slot >= 0:
			d *= 1.6
		if d < best_d:
			best_d = d
			best = t
	return best
