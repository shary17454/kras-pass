extends MiniGameController
## Bumper Bowl — score by launching rivals out of the bowl.
##
## Unlike Ring Rumble, a ring-out is not fatal: you respawn and the *attacker*
## banks a point. That single rule change turns the same push-out verbs into an
## aggressive, high-scoring game instead of a cautious one.

const RING_OUT_POINTS := 2
const BUMPER_ASSIST_POINTS := 1


func configure() -> void:
	eliminate_on_fall = false     # respawn instead of elimination
	lives_per_player = 99


func build() -> void:
	pass


func on_credited_knockout(attacker: int, _victim: int) -> void:
	ctx.add_score(attacker, int(RING_OUT_POINTS * ctx.powerups.point_multiplier(attacker)))
	ctx.bump_detail(attacker, "knockouts")
	AudioManager.play_sfx("score")


func on_fighter_fell(slot: int) -> void:
	var f := ctx.fighter(slot)
	# A bumper launch has no attacker, so credit the player currently leading
	# nobody — i.e. award nothing but still keep the round flowing.
	if f != null and f.last_attacker() < 0:
		ctx.bump_detail(slot, "falls")
	super.on_fighter_fell(slot)


func is_round_over() -> bool:
	return ctx.early_finish


func hud_value(slot: int) -> String:
	return str(ctx.scores[slot])


func detail_rows() -> Array:
	return [
		{"key": "results.stat.knockouts", "field": "knockouts"},
		{"key": "results.stat.falls", "field": "falls"},
	]


func music_track() -> String:
	return "arena_b"
