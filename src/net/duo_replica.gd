extends RefCounted

const Duel = preload("res://src/net/duel_replica.gd")
const Sweeper = preload("res://src/net/sweeper_replica.gd")
const Bumper = preload("res://src/net/bumper_replica.gd")
const Number = preload("res://src/net/goal_guard_replica.gd")
var _bumper: RefCounted


static func capture(game: Node) -> Dictionary:
	var world := Duel.capture(game)
	world["team_scores"] = game._team_score.duplicate()
	world["arena"] = game.ctx.arena.def.id
	world["hazards"] = Sweeper.capture(game) if world.arena == "sweeper_ring" else Bumper.capture(game)
	return world


static func valid(world: Variant, count: int, arena_id := "") -> bool:
	if not world is Dictionary or world.size() != 5:
		return false
	if not Duel.valid({"lives": world.get("lives"), "damage": world.get("damage")}, count):
		return false
	for life in world.lives:
		if life > 2:
			return false
	if not world.get("team_scores") is Array or world.team_scores.size() != 2:
		return false
	for score in world.team_scores:
		if not Number._number(score) or score != floorf(score) or score < 0 or score > 100000:
			return false
	if not world.get("arena") is String or world.arena not in ["sweeper_ring", "bumper_bowl"]:
		return false
	if arena_id != "" and world.arena != arena_id:
		return false
	return Sweeper.valid(world.get("hazards")) if world.arena == "sweeper_ring" else Bumper.valid(world.get("hazards"))


func render(game: Node, world: Dictionary, round_index: int, feedback: bool) -> void:
	Duel.render(game, world)
	game._team_score.assign([int(world.team_scores[0]), int(world.team_scores[1])])
	if world.arena == "sweeper_ring":
		Sweeper.render(game, world.hazards)
	else:
		if _bumper == null:
			_bumper = Bumper.new()
		_bumper.render(game, world.hazards, round_index, feedback)
