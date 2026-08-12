extends Screen
## Quick Play — pick a game, a competitor and the shape of the match, then go.
##
## Every control here maps to one field of `MatchConfig`; the screen has no
## gameplay knowledge of its own, which is why adding a mini-game never means
## editing it.

var _game_index := 0
var _character_index := 0
var _games: Array[MiniGameDef] = []
var _characters: Array[CharacterData] = []
var _opponents := 3
var _difficulty := 1
var _rounds := 1
var _arena_index := 0
var _powerups := true

var _game_card_holder: Control
var _character_card_holder: Control
var _arena_option: OptionButton
var _rounds_option: OptionButton


func build() -> void:
	title(Loc.t("quick.title"))
	_games = Progression.playable_games()
	_characters = Progression.playable_characters()
	if _games.is_empty() or _characters.is_empty():
		body.add_child(UIKit.centered(Loc.t("common.locked"), UIKit.SIZE_HEADING, UIKit.DANGER))
		return
	var last := Progression.last_character()
	for i in _characters.size():
		if _characters[i].id == last:
			_character_index = i
	_rounds = _games[_game_index].default_rounds

	var columns := UIKit.hbox(32)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)

	var left := UIKit.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := UIKit.vbox(12)
	right.custom_minimum_size = Vector2(560, 0)
	if Loc.is_rtl():
		columns.add_child(right)
		columns.add_child(left)
	else:
		columns.add_child(left)
		columns.add_child(right)

	left.add_child(UIKit.heading(Loc.t("quick.game")))
	_game_card_holder = _picker(left, func(step): _cycle_game(step))
	left.add_child(UIKit.heading(Loc.t("quick.character")))
	_character_card_holder = _picker(left, func(step): _cycle_character(step))

	right.add_child(UIKit.heading(Loc.t("quick.title")))
	var opp := UIKit.option(["0", "1", "2", "3"], _opponents)
	opp.item_selected.connect(func(i): _opponents = i)
	right.add_child(UIKit.row(Loc.t("quick.opponents"), opp))

	var diff := UIKit.option([
		Loc.t("difficulty.easy"), Loc.t("difficulty.medium"),
		Loc.t("difficulty.hard"), Loc.t("difficulty.expert"),
	], _difficulty)
	diff.item_selected.connect(func(i): _difficulty = i)
	right.add_child(UIKit.row(Loc.t("quick.difficulty"), diff))

	_arena_option = UIKit.option([], 0)
	_arena_option.item_selected.connect(func(i): _arena_index = i)
	right.add_child(UIKit.row(Loc.t("quick.arena"), _arena_option))

	_rounds_option = UIKit.option(["1", "2", "3", "5"], 0)
	_rounds_option.item_selected.connect(func(i): _rounds = [1, 2, 3, 5][i])
	right.add_child(UIKit.row(Loc.t("quick.rounds"), _rounds_option))

	var pu := UIKit.checkbox("", _powerups)
	pu.toggled.connect(func(v): _powerups = v)
	right.add_child(UIKit.row(Loc.t("quick.powerups"), pu))

	right.add_child(UIKit.spacer(18))
	var start := UIKit.button(Loc.t("quick.start"), UIKit.SIZE_HEADING)
	start.custom_minimum_size = Vector2(0, 76)
	start.pressed.connect(_start)
	right.add_child(start)
	first_focus = start

	_refresh_game()
	_refresh_character()


func _picker(parent: VBoxContainer, on_step: Callable) -> Control:
	var row := UIKit.hbox(12)
	var prev := UIKit.icon_button("‹", "")
	prev.pressed.connect(func(): on_step.call(-1))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(320, 160)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var next := UIKit.icon_button("›", "")
	next.pressed.connect(func(): on_step.call(1))
	row.add_child(prev)
	row.add_child(holder)
	row.add_child(next)
	parent.add_child(row)
	return holder


func _cycle_game(step: int) -> void:
	_game_index = wrapi(_game_index + step, 0, _games.size())
	_rounds = _games[_game_index].default_rounds
	_arena_index = 0
	_refresh_game()
	AudioManager.play_ui("ui_move")


func _cycle_character(step: int) -> void:
	_character_index = wrapi(_character_index + step, 0, _characters.size())
	_refresh_character()
	AudioManager.play_ui("ui_move")


func _refresh_game() -> void:
	for c in _game_card_holder.get_children():
		c.queue_free()
	var def := _games[_game_index]
	var card := Widgets.minigame_card(def, true)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_card_holder.add_child(card)
	_arena_option.clear()
	for aid in def.arena_ids:
		var a := Registry.arena(aid)
		_arena_option.add_item(a.display_name() if a != null else aid)
	if def.arena_ids.size() > 1:
		_arena_option.add_item(Loc.t("common.random"))
	_arena_option.selected = 0
	_rounds_option.selected = [1, 2, 3, 5].find(def.default_rounds) if [1, 2, 3, 5].has(def.default_rounds) else 0
	_rounds = def.default_rounds


func _refresh_character() -> void:
	for c in _character_card_holder.get_children():
		c.queue_free()
	var card := Widgets.character_card(_characters[_character_index], true, true)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_character_card_holder.add_child(card)


func _start() -> void:
	var def := _games[_game_index]
	var me := _characters[_character_index]
	Progression.set_last_character(me.id)

	var cfg := MatchConfig.new()
	cfg.minigame_id = def.id
	cfg.context = MatchConfig.Context.QUICK
	cfg.rounds = _rounds
	cfg.allow_powerups = _powerups
	cfg.sudden_death = def.supports_sudden_death
	cfg.seed = randi() & 0x7FFFFFFF
	var rng := RandomNumberGenerator.new()
	rng.seed = cfg.seed
	if _arena_index >= def.arena_ids.size():
		cfg.arena_id = def.arena_ids[rng.randi_range(0, def.arena_ids.size() - 1)]
	else:
		cfg.arena_id = def.arena_ids[_arena_index]

	var p := PlayerConfig.new()
	p.slot = 0
	p.character_id = me.id
	p.is_human = true
	cfg.players.append(p)

	var pool: Array[String] = []
	for c in Registry.characters():
		if c.id != me.id:
			pool.append(c.id)
	var count := clampi(_opponents, maxi(0, def.min_players - 1), def.max_players - 1)
	for i in count:
		var o := PlayerConfig.new()
		o.slot = i + 1
		o.character_id = pool[rng.randi_range(0, pool.size() - 1)] if pool.size() > 0 else me.id
		o.is_human = false
		o.ai_difficulty = _difficulty
		cfg.players.append(o)
		pool.erase(o.character_id)

	SceneRouter.start_match(cfg)
