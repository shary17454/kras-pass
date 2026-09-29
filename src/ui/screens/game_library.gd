extends Screen


func build() -> void:
	title(Loc.t("library.title"))
	var random := UIKit.button(Loc.t("party.anything"), UIKit.SIZE_HEADING)
	random.pressed.connect(func():
		var games := Progression.playable_games()
		if not games.is_empty():
			var game := games[randi_range(0, games.size() - 1)]
			SceneRouter.go_to("quick_play", {"game_id": game.id, "random_arena": true}))
	body.add_child(random)
	# Screen.setup() already wraps body in a ScrollContainer. A second one here
	# expands to the full list height and traps touch drags over the cards.
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	var fit := func(): grid.columns = 1 if get_viewport_rect().size.x < get_viewport_rect().size.y else 3
	get_viewport().size_changed.connect(fit)
	tree_exiting.connect(func(): get_viewport().size_changed.disconnect(fit))
	fit.call()
	for game in Registry.minigames():
		var unlocked := Progression.is_game_unlocked(game.id)
		var card := Widgets.minigame_card(game, unlocked)
		var button := Widgets.selectable(card, func():
			SceneRouter.go_to("quick_play", {"game_id": game.id}))
		button.disabled = not unlocked
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var entry := UIKit.vbox(8)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_child(button)
		var favorite := UIKit.checkbox(Loc.t("party.favorite"), PartyLibrary.favorites().has(game.id))
		favorite.disabled = not unlocked
		favorite.toggled.connect(func(_on): PartyLibrary.toggle_favorite(game.id))
		entry.add_child(favorite)
		grid.add_child(entry)
		if first_focus == null and unlocked:
			first_focus = button
