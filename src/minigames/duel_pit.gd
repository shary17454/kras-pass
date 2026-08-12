extends MiniGameController
## Duel Pit — arcade fighting with accumulating damage.
##
## Three lives each. Damage does not kill; it makes you lighter, so the same
## clean hit that bounced off at 0% launches you off the platform at 120%. That
## single rule is what gives a light-contact brawl a real skill ceiling.

const START_LIVES := 3


func configure() -> void:
	eliminate_on_fall = true
	lives_per_player = START_LIVES


func build() -> void:
	for i in ctx.player_count():
		var f := ctx.fighter(i)
		if f != null and is_instance_valid(f):
			f.reset_damage()


func on_round_start() -> void:
	reset_lives()
	for i in ctx.player_count():
		var f := ctx.fighter(i)
		if f != null and is_instance_valid(f):
			f.reset_damage()


func tick(_delta: float) -> void:
	pass


func on_credited_knockout(attacker: int, _victim: int) -> void:
	ctx.bump_detail(attacker, "knockouts")


func _handle_out(slot: int) -> void:
	# Reset damage on every life so a comeback is possible; keeping it would
	# make the last life unplayable.
	var f := ctx.fighter(slot)
	if f != null and is_instance_valid(f):
		f.reset_damage()
	super._handle_out(slot)


func compute_scores() -> Array[int]:
	# Lives remaining is the score; a survivor with two lives beats one with one.
	var out: Array[int] = []
	for i in ctx.player_count():
		out.append(lives(i) * 10 + int(ctx.details[i].get("knockouts", 0)))
	return out


func is_round_over() -> bool:
	if ctx.early_finish:
		return true
	var standing := 0
	for i in ctx.player_count():
		if ctx.is_alive(i):
			standing += 1
	return standing <= 1


func hud_value(slot: int) -> String:
	if not ctx.is_alive(slot):
		return Loc.t("hud.eliminated")
	var f := ctx.fighter(slot)
	var pct: int = int(f.damage_percent) if f != null and is_instance_valid(f) else 0
	return "♥%d   %d%%" % [lives(slot), pct]


func ai_script() -> Script:
	return load("res://src/ai/brains/duellist_brain.gd")


func detail_rows() -> Array:
	return [
		{"key": "results.stat.knockouts", "field": "knockouts"},
		{"key": "results.stat.falls", "field": "falls"},
	]


func music_track() -> String:
	return "arena_b"
