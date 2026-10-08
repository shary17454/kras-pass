extends Screen
## Daily Challenge — one fixed setup per calendar day.
##
## The seed is derived from the date, so the game, arena, opponents and every
## random spawn are identical for everyone on the same day. Completing it once
## per day pays gems.

const Daily = preload("res://src/progression/daily_challenge.gd")
const REWARD_GEMS := Daily.REWARD_GEMS

var _def: MiniGameDef
var _arena_id := ""
var _difficulty := 2
var _done_today := false
var _plan := {}
var _starting := false


func setup(a: Dictionary) -> void:
	_roll()
	super.setup(a)


func _roll() -> void:
	_plan = Daily.plan(Daily.today_key())
	if _plan.is_empty():
		return
	_def = Registry.minigame(String(_plan.game))
	_arena_id = String(_plan.arena)
	_difficulty = int(_plan.difficulty)
	_done_today = Daily.claimed(SaveSystem.active_profile_id(), String(_plan.key))


func build() -> void:
	var back := UIKit.button("←" if not Loc.is_rtl() else "→", UIKit.SIZE_BODY)
	back.custom_minimum_size = Vector2(64, 64)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(go_back)
	header.add_child(back)
	var heading := _line(Loc.t("daily.title"), UIKit.SIZE_HEADING, UIKit.ACCENT, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	if _def == null:
		body.add_child(UIKit.centered(Loc.t("common.locked"), UIKit.SIZE_HEADING, UIKit.DANGER))
		return
	body.add_child(_line(Loc.t("daily.seeded"), UIKit.SIZE_SMALL, UIKit.dim_color()))

	var card := Widgets.minigame_card(_def, true)
	card.custom_minimum_size = Vector2(0, 185)
	var content: VBoxContainer = card.get_child(0)
	content.get_child(1).custom_minimum_size.x = 0
	var stats: Label = content.get_child(2)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(card)

	var arena := Registry.arena(_arena_id)
	body.add_child(_line("%s: %s" % [Loc.t("quick.arena"), arena.display_name() if arena != null else "—"], UIKit.SIZE_BODY))
	body.add_child(_line("%s: %s" % [Loc.t("quick.difficulty"),
		Loc.t(PlayerConfig.DIFFICULTY_KEYS[_difficulty])], UIKit.SIZE_BODY))
	body.add_child(_line("%s: %s" % [Loc.t("quick.character"),
		Registry.character(String(_plan.character)).display_name()], UIKit.SIZE_BODY))
	for modifier in _plan.mutators:
		body.add_child(_line(Loc.t("mutator.%s" % modifier), UIKit.SIZE_BODY))
	var record := Daily.record(SaveSystem.active_profile_id(), _plan)
	body.add_child(_line(Loc.t("daily.attempts", {"n": int(record.get("attempts", 0))}), UIKit.SIZE_SMALL))
	if record.get("best_score") != null:
		var best := str(record.best_score)
		if _def.scoring == MiniGameDef.Scoring.RACE_TIME:
			best = "%.2f" % (float(record.best_score) / 100.0)
		body.add_child(_line(Loc.t("daily.best", {"n": best}), UIKit.SIZE_SMALL))
	if record.get("best_time") != null:
		body.add_child(_line(Loc.t("daily.best_time", {"n": "%.2f" % float(record.best_time)}), UIKit.SIZE_SMALL))
	body.add_child(_line(Loc.t("daily.reward", {"n": REWARD_GEMS}), UIKit.SIZE_BODY, UIKit.ACCENT_2, true))

	if _done_today:
		body.add_child(_line(Loc.t("daily.completed"), UIKit.SIZE_BODY, UIKit.OK, true))
	var start := UIKit.button(Loc.t("common.start"), UIKit.SIZE_HEADING)
	start.custom_minimum_size = Vector2(0, 72)
	start.pressed.connect(_start)
	body.get_parent().get_parent().add_child(start)
	first_focus = start


func _line(text: String, font_size: int, color: Color = Color.TRANSPARENT, bold := false) -> Label:
	var label := UIKit.label(text, font_size, color, bold)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _start() -> void:
	if _starting or _plan.is_empty():
		return
	_starting = true
	var profile_id := SaveSystem.active_profile_id()
	var cfg := Daily.configuration(_plan, profile_id)
	# The screen is freed the moment the match opens, so the reward callback
	# cannot live on it. A RefCounted helper kept alive by the Callable can.
	var reward := DailyReward.new()
	reward.plan = _plan.duplicate(true)
	reward.profile_id = profile_id
	reward.attempt = Daily.begin_attempt(profile_id, _plan)
	reward.config = cfg
	SceneRouter.start_match(cfg, Callable(reward, "on_match_finished"))


class DailyReward extends RefCounted:
	var plan := {}
	var profile_id := ""
	var attempt := 0
	var handled := false
	var config: MatchConfig

	func on_match_finished(result: MatchResult) -> void:
		if handled:
			return
		handled = true
		Daily.complete_attempt(profile_id, plan, attempt, result)
		SceneRouter.go_to("results", {"result": result, "config": config}, false)
