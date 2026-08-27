extends Node
## Entry point. Validates content, then hands control to the router.
##
## Deliberately tiny: everything with state is an autoload, so the boot scene
## has nothing to tear down and the test harness can drive the same services
## without ever loading this scene.


func _ready() -> void:
	Log.i("Kras Pass %s starting (%s)" % [
		ProjectSettings.get_setting("application/config/version", "?"),
		OS.get_name(),
	], "Main")
	# Content problems are fatal in a debug build and merely loud in a release
	# one — a player should never be dropped at a black screen because a JSON
	# key was misspelled.
	var problems := Registry.validate()
	for p in problems:
		Log.e("content: %s" % p, "Main")
	if not problems.is_empty() and OS.is_debug_build():
		Log.e("%d content problems found — see log above" % problems.size(), "Main")
	SceneRouter.go_to("main_menu", {}, false, 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveSystem.flush()
		get_tree().quit()
