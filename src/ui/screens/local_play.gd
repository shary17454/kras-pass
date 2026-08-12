extends Screen
## Local party: four slots, press-a-button to join, AI fills the rest.
##
## Joining is device-driven rather than menu-driven, which is the only version
## of this screen that works when someone walks in halfway through and picks up
## a pad.

const SLOTS := 4

var _slots: Array = []
var _cards: Array = []
var _game_index := 0
var _games: Array[MiniGameDef] = []
var _difficulty := 1
var _rounds := 1
var _game_holder: Control


func build() -> void:
	title(Loc.t("local.title"))
	_games = Progression.playable_games()
	for i in SLOTS:
		_slots.append({"kind": "empty", "device": {}, "character": "", "difficulty": _difficulty})
	# Slot 1 starts on the keyboard so a solo player can always begin.
	_slots[0] = {"kind": "human", "device": {"type": InputRouter.Source.KEYBOARD, "id": 0},
		"character": Progression.last_character(), "difficulty": _difficulty}
	_slots[1]["kind"] = "ai"
	_slots[2]["kind"] = "ai"
	_slots[3]["kind"] = "ai"
	_assign_characters()

	body.add_child(UIKit.label(Loc.t("local.join_hint"), UIKit.SIZE_SMALL, UIKit.dim_color()))

	var row := UIKit.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	for i in SLOTS:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(280, 340)
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(holder)
		_cards.append(holder)

	var controls := UIKit.hbox(14)
	body.add_child(controls)
	_game_holder = Control.new()
	_game_holder.custom_minimum_size = Vector2(320, 150)
	_game_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prev := UIKit.icon_button("‹", "")
	prev.pressed.connect(func(): _cycle_game(-1))
	var next := UIKit.icon_button("›", "")
	next.pressed.connect(func(): _cycle_game(1))
	controls.add_child(prev)
	controls.add_child(_game_holder)
	controls.add_child(next)

	var diff := UIKit.option([
		Loc.t("difficulty.easy"), Loc.t("difficulty.medium"),
		Loc.t("difficulty.hard"), Loc.t("difficulty.expert"),
	], _difficulty)
	diff.item_selected.connect(func(i):
		_difficulty = i
		for s in _slots:
			s["difficulty"] = i)
	controls.add_child(UIKit.row(Loc.t("quick.difficulty"), diff))

	var start := UIKit.button(Loc.t("local.start"), UIKit.SIZE_HEADING)
	start.custom_minimum_size = Vector2(0, 72)
	start.pressed.connect(_start)
	body.add_child(start)
	first_focus = start

	_refresh_cards()
	_refresh_game()


func _process(_delta: float) -> void:
	# Poll for a device that wants in and is not already bound to a slot.
	var taken: Array = []
	for s in _slots:
		if s["kind"] == "human":
			taken.append(s["device"])
	var request := InputRouter.poll_join_request(taken)
	if request.is_empty():
		return
	for i in SLOTS:
		if _slots[i]["kind"] != "human":
			_slots[i]["kind"] = "human"
			_slots[i]["device"] = request
			AudioManager.play_ui("ui_select")
			_refresh_cards()
			return


func _assign_characters() -> void:
	var pool: Array[CharacterData] = Progression.playable_characters()
	if pool.is_empty():
		return
	for i in SLOTS:
		if String(_slots[i]["character"]) == "":
			_slots[i]["character"] = pool[i % pool.size()].id


func _refresh_cards() -> void:
	for i in SLOTS:
		var holder: Control = _cards[i]
		for c in holder.get_children():
			c.queue_free()
		var v := UIKit.vbox(6)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(v)
		var kind := String(_slots[i]["kind"])
		var label := Loc.t("player.p%d" % (i + 1)) if kind == "human" else (
			Loc.t("local.slot_ai") if kind == "ai" else Loc.t("local.slot_empty"))
		v.add_child(UIKit.centered(label, UIKit.SIZE_BODY, UIKit.ACCENT if kind == "human" else UIKit.dim_color(), true))
		var c := Registry.character(String(_slots[i]["character"]))
		if c != null:
			v.add_child(Widgets.character_card(c, true, kind == "human"))
		var swap := UIKit.button(Loc.t("common.next"), UIKit.SIZE_TINY)
		swap.pressed.connect(func(): _cycle_character(i))
		v.add_child(swap)
		var toggle := UIKit.button(Loc.t("local.add_ai") if kind == "empty" else Loc.t("local.remove"), UIKit.SIZE_TINY)
		toggle.pressed.connect(func(): _cycle_kind(i))
		v.add_child(toggle)


func _cycle_kind(index: int) -> void:
	# Slot 1 always has someone in it; the party cannot be empty.
	var order := ["empty", "ai", "human"]
	var current := order.find(String(_slots[index]["kind"]))
	var next: String = order[(current + 1) % order.size()]
	if index == 0 and next == "empty":
		next = "ai"
	_slots[index]["kind"] = next
	if next != "human":
		_slots[index]["device"] = {}
	_refresh_cards()
	AudioManager.play_ui("ui_move")


func _cycle_character(index: int) -> void:
	var pool := Progression.playable_characters()
	if pool.is_empty():
		return
	var current := 0
	for i in pool.size():
		if pool[i].id == String(_slots[index]["character"]):
			current = i
	_slots[index]["character"] = pool[(current + 1) % pool.size()].id
	_refresh_cards()
	AudioManager.play_ui("ui_move")


func _cycle_game(step: int) -> void:
	if _games.is_empty():
		return
	_game_index = wrapi(_game_index + step, 0, _games.size())
	_refresh_game()
	AudioManager.play_ui("ui_move")


func _refresh_game() -> void:
	for c in _game_holder.get_children():
		c.queue_free()
	if _games.is_empty():
		return
	var card := Widgets.minigame_card(_games[_game_index], true)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_holder.add_child(card)
	_rounds = _games[_game_index].default_rounds


func _start() -> void:
	if _games.is_empty():
		AudioManager.play_ui("ui_error")
		return
	var def := _games[_game_index]
	var cfg := MatchConfig.new()
	cfg.minigame_id = def.id
	cfg.context = MatchConfig.Context.QUICK
	cfg.rounds = _rounds
	cfg.sudden_death = def.supports_sudden_death
	cfg.seed = randi() & 0x7FFFFFFF
	cfg.arena_id = def.arena_ids[0] if def.arena_ids.size() > 0 else ""

	var slot := 0
	for i in SLOTS:
		if String(_slots[i]["kind"]) == "empty":
			continue
		if slot >= def.max_players:
			break
		var p := PlayerConfig.new()
		p.slot = slot
		p.character_id = String(_slots[i]["character"])
		p.is_human = String(_slots[i]["kind"]) == "human"
		p.ai_difficulty = int(_slots[i]["difficulty"])
		if p.is_human:
			var device: Dictionary = _slots[i]["device"]
			p.device_type = 1 if int(device.get("type", InputRouter.Source.KEYBOARD)) == InputRouter.Source.PAD else 0
			p.device_id = int(device.get("id", 0))
		cfg.players.append(p)
		slot += 1

	if cfg.players.size() < def.min_players:
		AudioManager.play_ui("ui_error")
		EventBus.notify(Loc.t("local.join_hint"))
		return
	SceneRouter.start_match(cfg)
