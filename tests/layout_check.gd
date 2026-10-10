extends Node
## Guards against screens that build correctly but land off-screen.
##
## This needs a real window and cannot move into `test_runner.tscn`: the entry
## animation early-returns under the headless display server, so the whole
## class of "the layout is fine but something parked it outside the viewport"
## bug is invisible to the headless suite by construction. That is how a boot
## screen that rendered nothing but the background colour shipped — the game
## played its music, every assertion passed, and the player saw black.
##
## Arabic is the default locale on an Arabic system and RTL is where this fails
## first: a stale pre-layout position reads as (0, 0) under LTR, which merely
## nudges the screen, but as the far right edge under RTL, which throws all of
## it out of view. Both directions are checked so neither regresses alone.
##
##   godot --path . tests/layout_check.tscn -- --test-data-dir=/tmp/kras-layout-save
##
## Exits non-zero when anything with a drawable rect sits fully outside the
## viewport horizontally. Vertical overflow is legitimate — the long screens put
## their content in a ScrollContainer — so only the horizontal axis is fatal.

# These need a live match, a finished result or a stored replay to open.
const NEEDS_ARGS := ["match", "results", "replay_player", "standings"]
const SETTLE_FRAMES := 40
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(540, 960), Vector2i(1366, 1024), Vector2i(1024, 1366)]

var _failures: Array[String] = []
var _checked := 0
var _shots: Array[Dictionary] = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or SaveSystem.storage_root == SaveSystem.DIR:
		push_error("Layout QA requires a real renderer and isolated --test-data-dir")
		get_tree().quit(2)
		return
	var selected := PackedStringArray()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screens="):
			selected = argument.trim_prefix("--screens=").split(",", false)
			if selected.is_empty():
				push_error("Layout QA screen selection cannot be empty")
				get_tree().quit(2)
				return
	for id in selected:
		if not SceneRouter.SCREENS.has(id) or id in NEEDS_ARGS:
			push_error("Layout QA requires a supported default-state screen: " + id)
			get_tree().quit(2)
			return
	var output := SaveSystem.storage_root.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(output)
	var initial_errors := Log.error_count()
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for resolution in RESOLUTIONS:
			get_window().size = resolution
			for i in SETTLE_FRAMES:
				await get_tree().process_frame
			for id in SceneRouter.SCREENS.keys():
				var screen_id := String(id)
				if screen_id in NEEDS_ARGS or not selected.is_empty() and not screen_id in selected:
					continue
				var label := "%s/%s/%dx%d" % [locale, screen_id, resolution.x, resolution.y]
				var errors_before := Log.error_count()
				var failures_before := _failures.size()
				var opened := await SceneRouter.go_to(screen_id, {}, false, 0.0)
				for i in SETTLE_FRAMES:
					await get_tree().process_frame
				if not opened or SceneRouter.current_node == null or SceneRouter.current_id != screen_id:
					_failures.append(label + " never opened")
					continue
				_checked += 1
				_scan(SceneRouter.current_node, label)
				if screen_id == "quick_play":
					for issue in picker_issues(SceneRouter.current_node):
						_failures.append(label + " :: " + issue)
				await RenderingServer.frame_post_draw
				var image := get_viewport().get_texture().get_image()
				var file := output.path_join(label.replace("/", "-") + ".png")
				var colors := {}
				for x in range(0, image.get_width(), 11):
					for y in range(0, image.get_height(), 11):
						colors[image.get_pixel(x, y).to_html()] = true
				if image.save_png(file) != OK or colors.size() < 15:
					_failures.append(label + " has no qualifying rendered capture")
				if Log.error_count() != errors_before:
					_failures.append(label + " logged a runtime error")
				_shots.append({"screen": screen_id, "locale": locale,
					"resolution": [resolution.x, resolution.y], "image": file,
					"nonblank_colors": colors.size(), "passed": _failures.size() == failures_before})
	if Log.error_count() != initial_errors:
		_failures.append("runtime errors occurred during layout QA")
	var report := FileAccess.open(SaveSystem.storage_root.path_join("layout-report.json"), FileAccess.WRITE)
	if report == null:
		_failures.append("cannot write layout report")
	else:
		report.store_string(JSON.stringify({"scope": "default-state menus, two locales, four desktop window sizes; not device or interactive acceptance",
			"excluded": NEEDS_ARGS, "selected_screens": selected,
			"checked": _checked, "shots": _shots, "failures": _failures}, "  "))
		report.close()

	print("layout check: %d screens" % _checked)
	if _failures.is_empty():
		print("OK — every screen renders inside the viewport")
	else:
		for f in _failures:
			print("  layout issue: %s" % f)
		print("FAILED — %d layout issue(s)" % _failures.size())
	AudioManager.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	OS.delay_msec(100)
	get_tree().quit(0 if _failures.is_empty() else 1)


static func picker_issues(screen: Node) -> Array[String]:
	var issues: Array[String] = []
	for key in ["_game_card_holder", "_character_card_holder"]:
		var holder := screen.get(key) as Control
		if holder == null or holder.get_child_count() != 1:
			issues.append(key + " has no single settled card")
			continue
		var card := holder.get_child(0) as Control
		if card == null or not holder.get_global_rect().grow(1.0).encloses(card.get_global_rect()):
			issues.append(key + " card exceeds its layout allocation")
			continue
		var row := holder.get_parent() as Control
		var column := row.get_parent()
		var next := row.get_index() + 1
		if next < column.get_child_count():
			var following := column.get_child(next) as Control
			if following != null and card.get_global_rect().end.y > following.get_global_rect().position.y + 1.0:
				issues.append(key + " card overlaps the following section")
	return issues


func _scan(node: Node, label: String) -> void:
	var view := get_viewport().get_visible_rect()
	if node is Control:
		var c := node as Control
		var r := c.get_global_rect()
		# Zero-sized spacers and hidden branches draw nothing, so they cannot
		# be the reason a player sees an empty screen.
		if c.is_visible_in_tree() and r.size.x > 1.0 and r.size.y > 1.0:
			if r.position.x >= view.end.x or r.end.x <= view.position.x:
				_failures.append("%s :: %s [%s] at %s" % [label, c.name, c.get_class(), str(r)])
	for child in node.get_children():
		_scan(child, label)
