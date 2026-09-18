extends Screen
## Cosmetic preferences: a colour palette and a title, both purely visual and
## both unlocked through the same rule engine as characters and mini-games.
## Recolouring reuses `CharacterData.color`/`accent`, so no new art is needed.

var _titles_box: VBoxContainer


func build() -> void:
	title(Loc.t("menu.customize"))

	body.add_child(UIKit.label(Loc.t("customize.palettes"), UIKit.SIZE_HEADING, UIKit.ACCENT, true))
	var scroll_and_grid := Widgets.scroll_grid(4)
	body.add_child(scroll_and_grid[0])
	scroll_and_grid[0].custom_minimum_size = Vector2(0, 260)
	var grid: GridContainer = scroll_and_grid[1]
	for p in Registry.palettes():
		var pid := String(p.get("id", ""))
		var unlocked := Progression.is_palette_unlocked(pid)
		var selected := pid == Progression.selected_palette()
		var card := Widgets.palette_card(pid, unlocked, selected)
		var button := Widgets.selectable(card, func():
			if unlocked:
				Progression.set_selected_palette(pid)
				AudioManager.play_ui("ui_select")
				_refresh()
			else:
				AudioManager.play_ui("ui_error"))
		button.custom_minimum_size = Vector2(220, 220)
		grid.add_child(button)
		if first_focus == null:
			first_focus = button

	body.add_child(UIKit.label(Loc.t("customize.titles"), UIKit.SIZE_HEADING, UIKit.ACCENT, true))
	_titles_box = UIKit.vbox(8)
	body.add_child(_titles_box)
	_refresh()


func _refresh() -> void:
	for c in _titles_box.get_children():
		c.queue_free()
	for t in Registry.titles():
		var tid := String(t.get("id", ""))
		var unlocked := Progression.is_title_unlocked(tid)
		var selected := tid == Progression.selected_title()
		var b := UIKit.button(
			Loc.t("title.%s.name" % tid) if unlocked else "%s — %s" % [
				Loc.t("common.locked"), Progression.unlock_hint(t.get("unlock", {}))],
			UIKit.SIZE_SMALL)
		b.disabled = not unlocked
		if selected:
			b.text = "✓ " + b.text
		if unlocked:
			b.pressed.connect(func():
				Progression.set_selected_title(tid)
				AudioManager.play_ui("ui_select")
				_refresh())
		_titles_box.add_child(b)
