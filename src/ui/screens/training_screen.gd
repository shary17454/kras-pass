extends Screen
## Training: any unlocked game, no clock, instant restarts.
##
## Uses `MatchConfig.Context.TRAINING`, which the match layer reads to disable
## the timer and skip stats recording — practice should not pollute the profile.

var _index := 0
var _games: Array[MiniGameDef] = []
var _opponents := 1
var _difficulty := 1
var _holder: Control


func build() -> void:
	title(Loc.t("training.title"))
	body.add_child(UIKit.label(Loc.t("training.pick"), UIKit.SIZE_SMALL, UIKit.dim_color()))
	body.add_child(UIKit.label(Loc.t("training.hint"), UIKit.SIZE_TINY, UIKit.dim_color()))
	_games = Progression.playable_games()
	if _games.is_empty():
		return

	var row := UIKit.hbox(12)
	var prev := UIKit.icon_button("‹", "")
	prev.pressed.connect(func(): _cycle(-1))
	var next := UIKit.icon_button("›", "")
	next.pressed.connect(func(): _cycle(1))
	_holder = Control.new()
	_holder.custom_minimum_size = Vector2(340, 170)
	_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(prev)
	row.add_child(_holder)
	row.add_child(next)
	body.add_child(row)

	var opp := UIKit.option(["0", "1", "2", "3"], _opponents)
	opp.item_selected.connect(func(i): _opponents = i)
	body.add_child(UIKit.row(Loc.t("quick.opponents"), opp))

	var diff := UIKit.option([
		Loc.t("difficulty.easy"), Loc.t("difficulty.medium"),
		Loc.t("difficulty.hard"), Loc.t("difficulty.expert"),
	], _difficulty)
	diff.item_selected.connect(func(i): _difficulty = i)
	body.add_child(UIKit.row(Loc.t("quick.difficulty"), diff))

	var start := UIKit.button(Loc.t("common.start"), UIKit.SIZE_HEADING)
	start.custom_minimum_size = Vector2(0, 72)
	start.pressed.connect(_start)
	body.add_child(start)
	first_focus = start
	_refresh()


func _cycle(step: int) -> void:
	_index = wrapi(_index + step, 0, _games.size())
	_refresh()
	AudioManager.play_ui("ui_move")


func _refresh() -> void:
	for c in _holder.get_children():
		c.queue_free()
	var card := Widgets.minigame_card(_games[_index], true)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(card)


func _start() -> void:
	var def := _games[_index]
	var cfg := MatchConfig.new()
	cfg.minigame_id = def.id
	cfg.arena_id = def.arena_ids[0] if def.arena_ids.size() > 0 else ""
	cfg.context = MatchConfig.Context.TRAINING
	cfg.rounds = 1
	cfg.seed = randi() & 0x7FFFFFFF
	cfg.subtitle_key = "training.title"
	var me := PlayerConfig.new()
	me.slot = 0
	me.character_id = Progression.last_character()
	me.is_human = true
	cfg.players.append(me)
	var pool := Progression.playable_characters()
	var count := clampi(_opponents, maxi(0, def.min_players - 1), def.max_players - 1)
	for i in count:
		var o := PlayerConfig.new()
		o.slot = i + 1
		o.character_id = pool[(i + 1) % pool.size()].id
		o.is_human = false
		o.ai_difficulty = _difficulty
		cfg.players.append(o)
	SceneRouter.start_match(cfg)
