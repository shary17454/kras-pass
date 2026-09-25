extends Screen

var _roster: PartyRoster
var _games: Array[MiniGameDef] = []
var _game_index := 0
var _arena: OptionButton
var _arena_index := 0
var _laps := 3
var _difficulty := 1
var _error: Label
var _laps_row: Control


func build() -> void:
	title(Loc.t("local.title"))
	_games = Progression.playable_games()
	if _games.is_empty():
		return
	var labels: Array = []
	for game in _games:
		labels.append(game.display_name())
	var game_picker := UIKit.option(labels, 0)
	game_picker.item_selected.connect(func(i):
		_game_index = i
		_refresh_arenas())
	body.add_child(UIKit.row(Loc.t("tournament.games"), game_picker))
	_arena = UIKit.option([], 0)
	_arena.item_selected.connect(func(i): _arena_index = i)
	body.add_child(UIKit.row(Loc.t("quick.arena"), _arena))
	_refresh_arenas()
	var difficulties: Array = []
	for key in PlayerConfig.DIFFICULTY_KEYS:
		difficulties.append(Loc.t(key))
	var difficulty := UIKit.option(difficulties, 1)
	difficulty.item_selected.connect(func(i): _difficulty = i)
	body.add_child(UIKit.row(Loc.t("quick.difficulty"), difficulty))
	var laps := UIKit.option(["3", "4", "5", "6", "7", "8", "9", "10"], 0)
	laps.item_selected.connect(func(i): _laps = i + 3)
	_laps_row = UIKit.row(Loc.t("race.laps"), laps)
	body.add_child(_laps_row)
	_laps_row.visible = _games[_game_index].id in ["kart_sprint", "sabaq_sawarikh"]
	_roster = PartyRoster.new()
	body.add_child(_roster)
	_roster.setup()
	_error = UIKit.centered("", UIKit.SIZE_SMALL, UIKit.DANGER)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_error)
	var start := UIKit.button(Loc.t("local.start"), UIKit.SIZE_HEADING)
	start.pressed.connect(_start)
	body.add_child(start)
	first_focus = start


func _refresh_arenas() -> void:
	_arena.clear()
	_arena_index = 0
	if _laps_row != null:
		_laps_row.visible = _games[_game_index].id in ["kart_sprint", "sabaq_sawarikh"]
	for id in _games[_game_index].arena_ids:
		_arena.add_item(Registry.arena(id).display_name())


func _start() -> void:
	var error := _roster.validation_error()
	if not error.is_empty():
		_error.text = Loc.t(error)
		return
	var def := _games[_game_index]
	var cfg := MatchConfig.new()
	cfg.minigame_id = def.id
	cfg.arena_id = def.arena_ids[_arena_index]
	cfg.seed = randi() & 0x7FFFFFFF
	cfg.rounds = def.default_rounds
	cfg.sudden_death = def.supports_sudden_death
	cfg.players = _roster.save_roster(_difficulty)
	cfg.rules["race_laps"] = _laps
	SceneRouter.start_match(cfg)
