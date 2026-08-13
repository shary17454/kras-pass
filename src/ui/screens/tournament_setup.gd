extends Screen
## Tournament setup: how many competitors, how many games, how hard, and
## whether the schedule is rolled, hand-picked, or a one-tap party preset.
##
## A preset (Quick / Chaos / Skill / Family / …) is `PlaylistGenerator` plus a
## fixed set of match modifiers, applied to every game in the cup — see
## `data/mutators.json`. Picking "Custom" hands control back to the manual
## games-count / difficulty / hand-pick controls that were already here.

const PRESET_CUSTOM := "custom"

var _players := 4
var _games := 4
var _difficulty := 1
var _hand_picked := false
var _selected: Array[String] = []
var _character_index := 0
var _characters: Array[CharacterData] = []
var _picker_holder: VBoxContainer
var _preset_id := PRESET_CUSTOM
var _preset_ids: Array[String] = []
var _custom_rows: Array[Control] = []
var _preset_summary: Label


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

	_preset_ids = [PRESET_CUSTOM]
	_preset_ids.append_array(PlaylistGenerator.preset_ids())
	var preset_labels: Array = []
	for pid in _preset_ids:
		preset_labels.append(Loc.t("preset.%s" % pid))
	var preset_picker := UIKit.option(preset_labels, 0)
	preset_picker.item_selected.connect(func(i):
		_preset_id = _preset_ids[i]
		_apply_preset_visibility())
	left.add_child(UIKit.row(Loc.t("party.preset"), preset_picker))
	_preset_summary = UIKit.label("", UIKit.SIZE_TINY, UIKit.ACCENT_2)
	_preset_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_preset_summary)

	var games := UIKit.option(["3", "4", "5", "6", "8"], 1)
	games.item_selected.connect(func(i): _games = [3, 4, 5, 6, 8][i])
	var games_row := UIKit.row(Loc.t("tournament.rounds"), games)
	left.add_child(games_row)
	_custom_rows.append(games_row)

	var diff := UIKit.option([
		Loc.t("difficulty.easy"), Loc.t("difficulty.medium"),
		Loc.t("difficulty.hard"), Loc.t("difficulty.expert"),
	], _difficulty)
	diff.item_selected.connect(func(i): _difficulty = i)
	var diff_row := UIKit.row(Loc.t("tournament.difficulty"), diff)
	left.add_child(diff_row)
	_custom_rows.append(diff_row)

	var selection := UIKit.option([Loc.t("tournament.random"), Loc.t("tournament.pick")], 0)
	selection.item_selected.connect(func(i):
		_hand_picked = i == 1
		_refresh_picker())
	var selection_row := UIKit.row(Loc.t("tournament.selection"), selection)
	left.add_child(selection_row)
	_custom_rows.append(selection_row)

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

	var games_heading := UIKit.heading(Loc.t("tournament.games"))
	right.add_child(games_heading)
	right.add_child(_picker_holder)
	_custom_rows.append(games_heading)
	_custom_rows.append(_picker_holder)
	right.add_child(UIKit.spacer(12))
	var start := UIKit.button(Loc.t("tournament.start"), UIKit.SIZE_HEADING)
	start.custom_minimum_size = Vector2(0, 76)
	start.pressed.connect(_start)
	right.add_child(start)
	first_focus = start

	_refresh_character()
	_refresh_picker()
	_apply_preset_visibility()


## "Custom" shows the manual controls this screen always had; any preset hides
## them and shows what it will do instead, since the preset already decided.
func _apply_preset_visibility() -> void:
	var custom := _preset_id == PRESET_CUSTOM
	for row in _custom_rows:
		if is_instance_valid(row):
			row.visible = custom
	if custom:
		_preset_summary.text = ""
		return
	var meta := PlaylistGenerator.preset_meta(_preset_id)
	var parts: Array[String] = []
	# JSON has no int/float distinction, so a bare Loc.t substitution here would
	# print "8.0" instead of "8" — cast explicitly.
	parts.append(Loc.t("party.games_count", {"n": int(meta.get("games_count", 8))}))
	parts.append(Loc.t(PlayerConfig.DIFFICULTY_KEYS[clampi(int(meta.get("difficulty", 1)), 0, 3)]))
	var cats: Array = meta.get("categories", [])
	if not cats.is_empty():
		var names: Array[String] = []
		for c in cats:
			var key := "category.%s" % String(c)
			names.append(Loc.t(key) if Loc.has(key) else String(c))
		parts.append(", ".join(names))
	var mut_ids: Array = meta.get("mutators", [])
	if not mut_ids.is_empty():
		var glyphs: Array[String] = []
		for m in mut_ids:
			glyphs.append(Loc.t("mutator.%s" % String(m)))
		parts.append(", ".join(glyphs))
	if not bool(meta.get("powerups", true)):
		parts.append(Loc.t("common.off") + " " + Loc.t("quick.powerups"))
	_preset_summary.text = "  ·  ".join(parts)


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
	var custom := _preset_id == PRESET_CUSTOM
	var players := _build_players(me, seed_value)

	var session: TournamentSession
	if custom:
		var schedule: Array[String] = TournamentSession.random_games(_games, seed_value,
			_selected if _hand_picked and _selected.size() > 0 else [])
		if schedule.is_empty():
			AudioManager.play_ui("ui_error")
			return
		session = TournamentSession.new()
		session.setup(players, schedule, seed_value)
	else:
		session = TournamentSession.from_preset(_preset_id, players, seed_value,
			_selected if _hand_picked and _selected.size() > 0 else [])
		if session.game_ids.is_empty():
			AudioManager.play_ui("ui_error")
			return
	SceneRouter.go_to("standings", {"session": session}, false)


func _build_players(me: CharacterData, seed_value: int) -> Array[PlayerConfig]:
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
			p.ai_difficulty = _difficulty  # overwritten by from_preset() for a preset run
		players.append(p)
	return players
