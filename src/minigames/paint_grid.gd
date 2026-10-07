extends MiniGameController
## Paint Grid — territory by attrition.
##
## Every tile you cross becomes yours, including tiles a rival already claimed.
## The score is literally the floor, recomputed on a slow tick because counting
## 150 tiles every frame is waste and nobody can read a score that fast anyway.

const RECOUNT_PERIOD := 0.2

var _recount := 0.0
var _tiles: Array[ArenaTile] = []
var _claims := {}
var _claim_priority := 0


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
	_claims.clear()
	_claim_priority = posmod(ctx.config.seed + ctx.round_index, ctx.player_count())
	_recount = 0.0
	for t in _tiles:
		t.owner_slot = -1
		t.set_color(t.base_color)
	for i in ctx.player_count():
		ctx.set_score(i, 0)


func tick(delta: float) -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	_claims.clear()
	var centres := {}
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f) or not f.is_on_floor():
			continue
		var tile := arena.tile_at(f.global_position)
		if tile == null:
			continue
		centres[i] = tile
		_request_claim(tile, i)
		# A dash paints a small cross, which rewards committed movement over
		# shuffling back and forth on one square.
		if f.is_dashing():
			_paint_neighbours(arena, tile, i)
	# Resolve once after every fighter has submitted its movement for this tick.
	# Tile-centre proximity wins; exact ties rotate rather than favouring slot 4.
	for tile in _tiles:
		if not _claims.has(tile):
			continue
		var winner := _claim_winner(tile)
		if tile.claim(winner, UIKit.adapt(ctx.config.players[winner].color())):
			if centres.get(winner) == tile:
				AudioManager.play_sfx("tick", ctx.fighter(winner).global_position, 1.0 + winner * 0.06)
			_on_tile_claimed(tile, winner)
	_claims.clear()
	_claim_priority = (_claim_priority + 1) % ctx.player_count()
	_recount -= delta
	if _recount <= 0.0:
		_recount = RECOUNT_PERIOD
		_recount_scores()


func _paint_neighbours(arena: Arena, centre: ArenaTile, slot: int) -> void:
	for t in _tiles:
		if absi(t.grid_x - centre.grid_x) + absi(t.grid_z - centre.grid_z) == 1:
			_request_claim(t, slot)


func _request_claim(tile: ArenaTile, slot: int) -> void:
	if not _claims.has(tile):
		_claims[tile] = []
	if not _claims[tile].has(slot):
		_claims[tile].append(slot)


func _claim_winner(tile: ArenaTile) -> int:
	var winner := -1
	var distance := INF
	var priority := ctx.player_count()
	for slot: int in _claims[tile]:
		var offset: Vector3 = ctx.fighter(slot).global_position - tile.global_position
		var candidate_distance := Vector2(offset.x, offset.z).length_squared()
		var candidate_priority := posmod(slot - _claim_priority, ctx.player_count())
		if candidate_distance < distance - 0.0001 or (absf(candidate_distance - distance) <= 0.0001 and candidate_priority < priority):
			winner = slot
			distance = candidate_distance
			priority = candidate_priority
	return winner


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


func unclaimed_tile_near(pos: Vector3, slot: int, observable: Callable = Callable()) -> ArenaTile:
	var best: ArenaTile = null
	var best_d := INF
	for t in _tiles:
		if not is_instance_valid(t) or (observable.is_valid() and not observable.call(t)):
			continue
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
