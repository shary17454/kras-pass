extends Screen
## The roster: every competitor, unlocked or not, with the requirement printed
## on the locked ones so progression is never a mystery.


func build() -> void:
	title(Loc.t("menu.characters"))
	body.add_child(UIKit.label(Loc.t("char.select.hint"), UIKit.SIZE_SMALL, UIKit.dim_color()))
	var scroll_and_grid := Widgets.scroll_grid(4)
	body.add_child(scroll_and_grid[0])
	var grid: GridContainer = scroll_and_grid[1]
	for c in Registry.characters():
		var unlocked := Progression.is_character_unlocked(c.id) or Progression.all_unlocked()
		var card := Widgets.character_card(c, unlocked)
		var entry := Stats.character_entry(c.id)
		if unlocked:
			var v: VBoxContainer = card.get_child(0)
			v.add_child(UIKit.centered("%s %d · %s %d" % [
				Loc.t("stats.plays"), int(entry.get("plays", 0)),
				Loc.t("stats.wins"), int(entry.get("wins", 0)),
			], UIKit.SIZE_TINY, UIKit.dim_color()))
		var button := Widgets.selectable(card, func():
			if unlocked:
				Progression.set_last_character(c.id)
				AudioManager.play_ui("ui_select")
				EventBus.notify(c.display_name(), "◆")
			else:
				AudioManager.play_ui("ui_error"))
		button.custom_minimum_size = Vector2(250, 360)
		grid.add_child(button)
		if first_focus == null:
			first_focus = button
