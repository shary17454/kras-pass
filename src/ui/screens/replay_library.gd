extends Screen
## The saved-replay library.
##
## Recordings are cheap (a 90-second four-player match is a few hundred
## kilobytes), so the library keeps the last forty and prefers to drop the ones
## the highlight detector found nothing in.


func setup(a: Dictionary) -> void:
	super.setup(a)
	Replays.library_changed.connect(_rebuild)


func build() -> void:
	title(Loc.t("replay.title"))
	var entries := Replays.index()
	header.add_child(UIKit.label("%d · %.1f MB" % [entries.size(), Replays.total_bytes() / 1048576.0],
		UIKit.SIZE_SMALL, UIKit.dim_color()))

	if entries.is_empty():
		body.add_child(UIKit.centered(Loc.t("replay.empty"), UIKit.SIZE_BODY, UIKit.dim_color()))
		return

	var pair := Widgets.scroll_grid(1)
	body.add_child(pair[0])
	var grid: GridContainer = pair[1]
	for e in entries:
		grid.add_child(_row(e))

	var wipe := UIKit.button(Loc.t("replay.delete_all"), UIKit.SIZE_SMALL)
	wipe.add_theme_color_override("font_color", UIKit.DANGER)
	wipe.pressed.connect(func():
		Replays.erase_all()
		_rebuild())
	body.add_child(wipe)


func _row(entry: Dictionary) -> Control:
	var game := Registry.minigame(String(entry.get("game", "")))
	var arena := Registry.arena(String(entry.get("arena", "")))
	var card := UIKit.panel(UIKit.PANEL, 14)
	var h := UIKit.hbox(16)
	card.add_child(h)

	h.add_child(UIKit.label(game.icon_glyph if game != null else "◆", UIKit.SIZE_HEADING, UIKit.ACCENT, true))

	var info := UIKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label(game.display_name() if game != null else String(entry.get("game", "")),
		UIKit.SIZE_BODY, UIKit.text_color(), true))
	var when := Time.get_datetime_dict_from_unix_time(int(entry.get("created_at", 0)))
	info.add_child(UIKit.label("%s · %s · %s %s · %.0fs" % [
		"%04d-%02d-%02d %02d:%02d" % [when["year"], when["month"], when["day"], when["hour"], when["minute"]],
		arena.display_name() if arena != null else "",
		Loc.t("results.winner", {"name": String(entry.get("winner", "—"))}),
		"",
		float(entry.get("seconds", 0.0)),
	], UIKit.SIZE_TINY, UIKit.dim_color()))
	h.add_child(info)

	var count := int(entry.get("highlights", 0))
	if count > 0:
		h.add_child(UIKit.label("★ %d" % count, UIKit.SIZE_SMALL, UIKit.ACCENT_2, true))

	var play := UIKit.button(Loc.t("replay.watch"), UIKit.SIZE_SMALL)
	play.custom_minimum_size = Vector2(150, 0)
	play.pressed.connect(func(): SceneRouter.go_to("replay_player", {"id": String(entry["id"])}))
	h.add_child(play)
	if first_focus == null:
		first_focus = play

	var del := UIKit.button("✕", UIKit.SIZE_SMALL)
	del.pressed.connect(func():
		Replays.erase(String(entry["id"]))
		_rebuild())
	h.add_child(del)
	return card


func _rebuild() -> void:
	SceneRouter.go_to("replays", {}, false, 0.0)
