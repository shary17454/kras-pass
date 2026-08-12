extends Screen
## Daily Challenge — one fixed setup per calendar day.
##
## The seed is derived from the date, so the game, arena, opponents and every
## random spawn are identical for everyone on the same day. Completing it once
## per day pays gems.

const REWARD_GEMS := 12

var _seed := 0
var _def: MiniGameDef
var _arena_id := ""
var _difficulty := 2
var _done_today := false


func setup(a: Dictionary) -> void:
	_roll()
	super.setup(a)


func _roll() -> void:
	var date := Time.get_date_dict_from_system()
	var key := "%04d%02d%02d" % [date["year"], date["month"], date["day"]]
	_seed = int(key.hash()) & 0x7FFFFFFF
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var pool := Progression.playable_games()
	if pool.is_empty():
		return
	_def = pool[rng.randi_range(0, pool.size() - 1)]
	_arena_id = _def.arena_ids[rng.randi_range(0, _def.arena_ids.size() - 1)] if _def.arena_ids.size() > 0 else ""
	_difficulty = rng.randi_range(1, 3)
	_done_today = String(SaveSystem.player_branch("daily_done").get("key", "")) == key


func build() -> void:
	title(Loc.t("daily.title"))
	if _def == null:
		body.add_child(UIKit.centered(Loc.t("common.locked"), UIKit.SIZE_HEADING, UIKit.DANGER))
		return
	body.add_child(UIKit.label(Loc.t("daily.seeded"), UIKit.SIZE_SMALL, UIKit.dim_color()))

	var card := Widgets.minigame_card(_def, true)
	card.custom_minimum_size = Vector2(560, 200)
	body.add_child(card)

	var arena := Registry.arena(_arena_id)
	body.add_child(UIKit.label("%s: %s" % [Loc.t("quick.arena"), arena.display_name() if arena != null else "—"], UIKit.SIZE_BODY))
	body.add_child(UIKit.label("%s: %s" % [Loc.t("quick.difficulty"),
		Loc.t(PlayerConfig.DIFFICULTY_KEYS[_difficulty])], UIKit.SIZE_BODY))
	body.add_child(UIKit.label(Loc.t("daily.reward", {"n": REWARD_GEMS}), UIKit.SIZE_BODY, UIKit.ACCENT_2, true))

	if _done_today:
		body.add_child(UIKit.label(Loc.t("daily.completed"), UIKit.SIZE_BODY, UIKit.OK, true))
	var start := UIKit.button(Loc.t("common.start"), UIKit.SIZE_HEADING)
	start.custom_minimum_size = Vector2(0, 72)
	start.pressed.connect(_start)
	body.add_child(start)
	first_focus = start


func _start() -> void:
	var cfg := MatchConfig.new()
	cfg.minigame_id = _def.id
	cfg.arena_id = _arena_id
	cfg.context = MatchConfig.Context.QUICK
	cfg.rounds = _def.default_rounds
	cfg.seed = _seed
	cfg.subtitle_key = "daily.title"
	var me := PlayerConfig.new()
	me.slot = 0
	me.character_id = Progression.last_character()
	me.is_human = true
	cfg.players.append(me)
	var pool := Registry.characters()
	for i in mini(3, _def.max_players - 1):
		var o := PlayerConfig.new()
		o.slot = i + 1
		o.character_id = pool[(i + 1) % pool.size()].id
		o.is_human = false
		o.ai_difficulty = _difficulty
		cfg.players.append(o)
	# The screen is freed the moment the match opens, so the reward callback
	# cannot live on it. A RefCounted helper kept alive by the Callable can.
	var reward := DailyReward.new()
	var date := Time.get_date_dict_from_system()
	reward.day_key = "%04d%02d%02d" % [date["year"], date["month"], date["day"]]
	reward.already_done = _done_today
	reward.config = cfg
	SceneRouter.start_match(cfg, Callable(reward, "on_match_finished"))


class DailyReward extends RefCounted:
	var day_key := ""
	var already_done := false
	var config: MatchConfig

	func on_match_finished(result: MatchResult) -> void:
		if result.place_of(0) == 1 and not already_done:
			SaveSystem.set_player_branch("daily_done", {"key": day_key})
			SaveSystem.flush()
			Progression.grant_gems(REWARD_GEMS)
		SceneRouter.go_to("results", {"result": result, "config": config}, false)
