extends Node


func _ready() -> void:
	Loc.set_locale("ar")
	var saved: Dictionary = Progression._p.duplicate(true)
	if not Progression._p["games"].has("sabaq_sawarikh"):
		Progression._p["games"].append("sabaq_sawarikh")
	SceneRouter.go_to("quick_play", {"game_id": "sabaq_sawarikh"}, false, 0.0)
	for i in 45:
		await get_tree().process_frame
	var screen = SceneRouter.current_node
	assert(screen._laps_row.visible)
	assert(screen._laps_option.item_count == 8)
	for i in 8:
		screen._laps_option.select(i)
		screen._laps_option.item_selected.emit(i)
		assert(screen._laps == i + 3)
		assert(screen._laps_option.get_item_text(i) == str(i + 3))
	await RenderingServer.frame_post_draw
	var orientation := "portrait" if get_viewport().get_visible_rect().size.x < get_viewport().get_visible_rect().size.y else "landscape"
	get_viewport().get_texture().get_image().save_png("/tmp/kras-race-laps-setup-%s.png" % orientation)
	screen._laps_option.show_popup()
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/kras-race-laps-options-%s.png" % orientation)
	Progression._p = saved
	print("Race setup: all eight lap choices from 3 to 10 verified")
	get_tree().quit()
