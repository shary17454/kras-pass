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
	for h in arena.get_children():
		if h is ArenaHazards.ShrinkRing:
			h.start_delay = 0.0
			h.rate = maxf(h.rate, 1.2)
			# Room for one. Stopping at a 3.6 m island let every remaining
			# fighter stand inside it indefinitely once knockback stopped being
			# a catapult, and a sudden death that can stalemate is not sudden —
			# the round hung until the harness timeout. The ring now closes to
			# less than a body's width, which is a guarantee, not a pressure.
			h.min_radius = 0.9


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
