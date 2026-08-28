extends Node
func _diff(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

func _flat(img: Image) -> bool:
	var c0 := img.get_pixel(20, 20)
	for p in [[960,540],[300,800],[1600,200],[960,1000],[100,540]]:
		if _diff(img.get_pixel(p[0], p[1]), c0) > 0.05:
			return false
	return true

func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/kp_flow_%s.png" % tag)
	print("%-12s شاشة=%-12s %s" % [tag, SceneRouter.current_id, "SOLID سوداء/مسطّحة" if _flat(img) else "OK فيها محتوى"])

func _ready() -> void:
	Loc.set_locale("ar")
	for id in ["boot", "main_menu", "quick_play", "characters", "adventure", "tournament", "settings"]:
		SceneRouter.go_to(id, {}, false, 0.0)
		for i in 70:
			await get_tree().process_frame
		_shot(id)
	get_tree().quit()
