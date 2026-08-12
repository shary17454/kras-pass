extends MiniGameController
## Ring Rumble — the flagship push-out game.
##
## Four competitors on a ring that shrinks as the clock runs down. No lives, no
## respawns: leaving the ring ends your round. Sudden death cuts the ring hard
## so a stalemate cannot survive.
##
## This is the smallest complete mini-game in the project, and a good template:
## it is 60 lines of rules on top of the shared match layer.


func configure() -> void:
	eliminate_on_fall = true
	lives_per_player = 1


func build() -> void:
	# Nothing to spawn — the arena's shrink hazard is the whole gimmick.
	pass


func on_round_start() -> void:
	var arena := ctx.arena as Arena
	if arena != null:
		arena.reset_hazards()


func tick(_delta: float) -> void:
	# Award a small survival tick so a player who dominates the whole round out-
	# scores one who happened to be second-to-last in a fast round.
	pass


func on_sudden_death() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	# Collapse the ring toward the centre immediately; anyone loitering at the
	# rim is now standing on nothing.
	var shrink := Balance.num("tuning", "match.sudden_death_shrink", 0.55)
	for h in arena.get_children():
		if h is ArenaHazards.ShrinkRing:
			h.start_delay = 0.0
			h.rate = maxf(h.rate, 1.2)
			h.min_radius = maxf(3.0, arena.def.radius * shrink * 0.5)


func on_credited_knockout(attacker: int, _victim: int) -> void:
	# Ring-outs you caused are shown on the results screen even though the
	# ranking itself is survival-based.
	ctx.bump_detail(attacker, "knockouts", 0)


func hud_value(slot: int) -> String:
	if not ctx.is_alive(slot):
		return Loc.t("hud.eliminated")
	return "●"


func detail_rows() -> Array:
	return [
		{"key": "results.stat.knockouts", "field": "knockouts"},
		{"key": "results.stat.falls", "field": "falls"},
	]


func music_track() -> String:
	return "arena"
