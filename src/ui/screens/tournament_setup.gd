extends Screen
## Tournament setup: how many competitors, how many games, how hard, and
## whether the schedule is rolled or hand-picked.

var _players := 4
var _games := 4
var _difficulty := 1
var _hand_picked := false
var _selected: Array[String] = []
var _character_index := 0
var _characters: Array[CharacterData] = []
var _picker_holder: VBoxContainer


func build() -> void:
	title(Loc.t("tournament.title"))
	_characters = Progression.playable_characters()
	if _characters.is_empty():
		body.add_child(UIKit.centered(Loc.t("common.locked"), UIKit.SIZE_HEADING, UIKit.DANGER))
		return
	var last := Progression.last_character()
	for i in _characters.size():
		if _characters[i].id == last:
			_character_index = i

	var columns := UIKit.hbox(32)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var left := UIKit.vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := UIKit.vbox(12)
	right.custom_minimum_size = Vector2(560, 0)
	columns.add_child(left)
	columns.add_child(right)

	var players := UIKit.option(["2", "3", "4"], 2)
	players.item_selected.connect(func(i): _players = i + 2)
	left.add_child(UIKit.row(Loc.t("tournament.players"), players))

	var games := UIKit.option(["3", "4", "5", "6", "8"], 1)
	games.item_selected.connect(func(i): _games = [3, 4, 5, 6, 8][i])
	left.add_child(UIKit.row(Loc.t("tournament.rounds"), games))

	var diff := UIKit.option([
		Loc.t("difficulty.easy"), Loc.t("difficulty.medium"),
		Loc.t("difficulty.hard"), Loc.t("difficulty.expert"),
	], _difficulty)
	diff.item_selected.connect(func(i): _difficulty = i)
	left.add_child(UIKit.row(Loc.t("tournament.difficulty"), diff))

	var selection := UIKit.option([Loc.t("tournament.random"), Loc.t("tournament.pick")], 0)
	selection.item_selected.connect(func(i):
		_hand_picked = i == 1
		_refresh_picker())
	left.add_child(UIKit.row(Loc.t("tournament.selection"), selection))

	var char_row := UIKit.hbox(12)
	var prev := UIKit.icon_button("‹", "")
	prev.pressed.connect(func(): _cycle(-1))
	var next := UIKit.icon_button("›", "")
	next.pressed.connect(func(): _cycle(1))
	_picker_holder = UIKit.vbox(8)
	char_row.add_child(prev)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(260, 300)
	holder.name = "CharHolder"
	char_row.add_child(holder)
	char_row.add_child(next)
	left.add_child(UIKit.heading(Loc.t("quick.character")))
	left.add_child(char_row)

	right.add_child(UIKit.heading(Loc.t("tournament.games")))
	right.add_child(_picker_holder)
	right.add_child(UIKit.spacer(12))
	var start := UIKit.button(Loc.t("tournament.start"), UIKit.SIZE_HEADING)
	start.custom_minimum_size = Vector2(0, 76)
	start.pressed.connect(_start)
	right.add_child(start)
	first_focus = start

	_refresh_character()
	_refresh_picker()


func _cycle(step: int) -> void:
	_character_index = wrapi(_character_index + step, 0, _characters.size())
	_refresh_character()
	AudioManager.play_ui("ui_move")


func _refresh_character() -> void:
	var holder := find_child("CharHolder", true, false)
	if holder == null:
		return
	for c in holder.get_children():
		c.queue_free()
	var card := Widgets.character_card(_characters[_character_index], true, true)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(card)


func _refresh_picker() -> void:
	for c in _picker_holder.get_children():
		c.queue_free()
	if not _hand_picked:
		_picker_holder.add_child(UIKit.label(Loc.t("tournament.random"), UIKit.SIZE_SMALL, UIKit.dim_color()))
		return
	var scroll_and_grid := Widgets.scroll_grid(2)
	var scroll: ScrollContainer = scroll_and_grid[0]
	scroll.custom_minimum_size = Vector2(0, 380)
	_picker_holder.add_child(scroll)
	var grid: GridContainer = scroll_and_grid[1]
	for m in Progression.playable_games():
		var toggle := UIKit.checkbox(m.display_name(), _selected.has(m.id))
		toggle.toggled.connect(func(on):
			if on and not _selected.has(m.id):
				_selected.append(m.id)
			elif not on:
				_selected.erase(m.id))
		grid.add_child(toggle)


func _start() -> void:
	var me := _characters[_character_index]
	Progression.set_last_character(me.id)
	var seed_value := randi() & 0x7FFFFFFF
	var schedule: Array[String] = []
	if _hand_picked and _selected.size() > 0:
		schedule = TournamentSession.random_games(_games, seed_value, _selected)
	else:
		schedule = TournamentSession.random_games(_games, seed_value)
	if schedule.is_empty():
		AudioManager.play_ui("ui_error")
		return

	var players: Array[PlayerConfig] = []
	var pool: Array[String] = []
	for c in Registry.characters():
		if c.id != me.id:
			pool.append(c.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in _players:
		var p := PlayerConfig.new()
		p.slot = i
		if i == 0:
			p.character_id = me.id
			p.is_human = true
		else:
			p.character_id = pool[rng.randi_range(0, pool.size() - 1)] if pool.size() > 0 else me.id
			pool.erase(p.character_id)
			p.is_human = false
			p.ai_difficulty = _difficulty
		players.append(p)

	var session := TournamentSession.new()
	session.setup(players, schedule, seed_value)
	SceneRouter.go_to("standings", {"session": session}, false)
