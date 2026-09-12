extends Node


func _ready() -> void:
	var saved = UserSettings.get_value("fps_limit")
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		SceneRouter.go_to("settings", {}, false, 0.0)
		for i in 3:
			await get_tree().process_frame
		var options := SceneRouter.current_node.find_child("FrameRateOptions", true, false) as OptionButton
		assert(options != null)
		assert(options.get_item_text(2) == Loc.t("settings.fps.60"))
		assert(options.get_item_text(3) == Loc.t("settings.fps.120"))
		assert(options.item_selected.get_connections().size() > 0)
		assert(UserSettings.get_value("fps_limit") == saved)
	print("FPS settings: 60 and 120 labels and selection handler verified in Arabic and English")
	get_tree().quit()
