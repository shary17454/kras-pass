extends Screen


func build() -> void:
	title(Loc.t("library.title"))
	var parts := Widgets.scroll_grid(3)
	var scroll: ScrollContainer = parts[0]
	var grid: GridContainer = parts[1]
	body.add_child(scroll)
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
		grid.add_child(button)
		if first_focus == null and unlocked:
			first_focus = button
