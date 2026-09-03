extends MiniGameController
## Duo Clash — two against two, and the scoreboard has two rows, not four.
##
## The spec asks for team games, and `supports_teams` had been a flag in the
## data with nothing behind it. Teams change the game in three ways and this
## implements all three: a shove from a partner does nothing, a ring-out pays
## the pair rather than the player, and the round ends when a side is gone
## rather than when one player is left. Everything else — the ring, the
## physics, the drone — is the push-out game the project already had.
##
## Sides are slot parity: 0 and 2 against 1 and 3. That is deliberate rather
## than configurable, because the join screen seats players in slot order, so
## parity puts the two people sitting next to each other on opposite sides —
## which is the seating a couch game wants.

const RING_OUT_POINTS := 2
const SURVIVE_BONUS := 1

var _team_score := [0, 0]


func configure() -> void:
	eliminate_on_fall = true
	lives_per_player = 1
	for slot in ctx.player_count():
		var f := ctx.fighter(slot)
		if f == null or not is_instance_valid(f):
			continue
		var team := slot % 2
		f.teammates.clear()
		for other in ctx.player_count():
			if other != slot and other % 2 == team:
				f.teammates[other] = true
		var p := ctx.config.player_at(slot)
		if p != null:
			p.team = team


func build() -> void:
	_team_score = [0, 0]
	# Sides start apart: mixing the spawn ring would open every round with a
	# partner in the way.
	var arena := ctx.arena as Arena
	if arena == null:
		return
	for slot in ctx.player_count():
		var f := ctx.fighter(slot)
		if f == null or not is_instance_valid(f):
			continue
		var team := slot % 2
		var side := -1.0 if team == 0 else 1.0
		var lane: float = -1.0 if slot < 2 else 1.0
		var pos: Vector3 = arena.global_position + Vector3(
			arena.def.radius * 0.5 * side, 1.4, arena.def.radius * 0.28 * lane)
		f.global_position = pos
		f.set_spawn(pos)


func on_round_start() -> void:
	_team_score = [0, 0]
	var arena := ctx.arena as Arena
	if arena != null:
		arena.reset_hazards()


func team_of(slot: int) -> int:
	return slot % 2


func team_score(team: int) -> int:
	return _team_score[team] if team >= 0 and team < _team_score.size() else 0


func team_alive(team: int) -> int:
	var n := 0
	for slot in ctx.player_count():
		if slot % 2 == team and ctx.is_alive(slot):
			n += 1
	return n


func on_credited_knockout(attacker: int, _victim: int) -> void:
	var team := team_of(attacker)
	_team_score[team] += RING_OUT_POINTS
	ctx.bump_detail(attacker, "knockouts")
	_publish()


func on_fighter_fell(slot: int) -> void:
	super.on_fighter_fell(slot)
	_publish()


## Both partners read the same number, because that is the number that decides
## the match. Survivors add a point each at the whistle so a side that kept
## everybody standing beats a side that traded evenly.
func _publish() -> void:
	for slot in ctx.player_count():
		ctx.set_score(slot, _team_score[team_of(slot)])


func on_round_end() -> void:
	for slot in ctx.player_count():
		if ctx.is_alive(slot):
			_team_score[team_of(slot)] += SURVIVE_BONUS
	_publish()


func is_round_over() -> bool:
	if ctx.early_finish:
		return true
	return team_alive(0) == 0 or team_alive(1) == 0


func is_tied() -> bool:
	return _team_score[0] == _team_score[1]


func hud_value(slot: int) -> String:
	if not ctx.is_alive(slot):
		return Loc.t("hud.eliminated")
	return "%d" % team_score(team_of(slot))


func hud_banner() -> String:
	return Loc.t("duo.score", {"a": _team_score[0], "b": _team_score[1]})


func detail_rows() -> Array:
	return [{"key": "results.stat.knockouts", "field": "knockouts"}]


func ai_script() -> Script:
	return load("res://src/ai/brains/duo_brain.gd")
