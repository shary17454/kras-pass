extends MiniGameController
## Bumper Bowl — score by launching rivals out of the bowl.
##
## Unlike Ring Rumble, a ring-out is not fatal: you respawn and the *attacker*
## banks a point. That single rule change turns the same push-out verbs into an
## aggressive, high-scoring game instead of a cautious one.

const RING_OUT_POINTS := 2
## Everyone still in the bowl banks this when a rival goes out, whoever sent
## them. Measured: the bumpers preempt nearly every player-driven ejection —
## six matches produced 305 ring-outs but only 6 that a player could be credited
## for, so a rule that pays only for credited knockouts left 34 of 40 rounds
## tied four-way on zero. Falls are the signal this arena actually generates;
## staying in the bowl while rivals do not is the skill it actually tests.
const SURVIVOR_POINTS := 1


func configure() -> void:
	eliminate_on_fall = false     # respawn instead of elimination
	lives_per_player = 99


func build() -> void:
	pass


func on_credited_knockout(attacker: int, _victim: int) -> void:
	# `_handle_out` already counts this on the attacker's knockout tally, so
	# counting it again here doubled the number on the results screen.
	ctx.add_score(attacker, int(RING_OUT_POINTS * ctx.powerups.point_multiplier(attacker)))
	AudioManager.play_sfx("score")


func on_fighter_fell(slot: int) -> void:
	super.on_fighter_fell(slot)
	_pay_survivors(slot)


func on_fighter_knocked_out(slot: int, by_slot: int) -> void:
	super.on_fighter_knocked_out(slot, by_slot)
	_pay_survivors(slot)


## Pay everyone who is not the one who just went out.
func _pay_survivors(fallen: int) -> void:
	for i in ctx.fighters.size():
		if i == fallen or not ctx.is_alive(i):
			continue
		ctx.add_score(i, int(SURVIVOR_POINTS * ctx.powerups.point_multiplier(i)))


# A bumper launch has no attacker, so nobody banks points for it — which is
# already what the base class does, and it counts the fall itself in
# `_handle_out`. Counting it again here made every uncredited ring-out show up
# twice on the results screen, and in this arena the bumpers cause nearly all of
# them, so the falls column read roughly double the truth.


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
