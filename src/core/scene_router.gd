extends Node
## Screen navigation. Autoload name: `SceneRouter`.
##
## One holder node, one screen at a time, an explicit back-stack and a fade
## overlay. Screens never instantiate each other — they ask the router — which
## is what makes "no dead ends in navigation" a property that can be tested:
## `tests/test_navigation.gd` walks every registered screen and asserts each one
## can reach the main menu.

signal screen_changed(id: String)
signal transition_finished()

const SCREENS := {
	"boot": "res://src/ui/screens/boot_screen.gd",
	"main_menu": "res://src/ui/screens/main_menu.gd",
	"adventure": "res://src/ui/screens/adventure_map.gd",
	"quick_play": "res://src/ui/screens/quick_play.gd",
	"tournament": "res://src/ui/screens/tournament_setup.gd",
	"local_play": "res://src/ui/screens/local_play.gd",
	"online": "res://src/ui/screens/online_screen.gd",
	"training": "res://src/ui/screens/training_screen.gd",
	"daily": "res://src/ui/screens/daily_screen.gd",
	"characters": "res://src/ui/screens/character_gallery.gd",
	"rewards": "res://src/ui/screens/rewards_screen.gd",
	"achievements": "res://src/ui/screens/achievements_screen.gd",
	"stats": "res://src/ui/screens/stats_screen.gd",
	"settings": "res://src/ui/screens/settings_screen.gd",
	"profile": "res://src/ui/screens/profile_screen.gd",
	"results": "res://src/ui/screens/results_screen.gd",
	"standings": "res://src/ui/screens/standings_screen.gd",
	"match": "res://src/match/match_scene.gd",
}

var holder: Node
var overlay: ColorRect
var toast_layer: CanvasLayer
var current_id := ""
var current_node: Node
var _stack: Array = []
var _busy := false
var _pending_args := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Parented to the router itself rather than deferred onto the root: the very
	# first `go_to()` happens inside Main._ready, and a deferred add would leave
	# the boot screen outside the tree with a null `get_tree()`.
	holder = Node.new()
	holder.name = "ScreenHolder"
	add_child(holder)
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.name = "TransitionLayer"
	add_child(layer)
	overlay = ColorRect.new()
	overlay.color = Color(0.03, 0.03, 0.06, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)
	toast_layer = CanvasLayer.new()
	toast_layer.layer = 90
	toast_layer.name = "ToastLayer"
	add_child(toast_layer)


## Replace the current screen. `push` keeps the previous id on the back stack.
func go_to(id: String, args: Dictionary = {}, push: bool = true, fade: float = 0.22) -> void:
	if _busy:
		# Two buttons pressed on the same frame must not open two screens.
		return
	if not SCREENS.has(id):
		Log.e("unknown screen '%s'" % id, "Router")
		return
	_busy = true
	_pending_args = args
	if push and current_id != "" and current_id != id:
		_stack.append({"id": current_id, "args": {}})
	await _fade(1.0, fade)
	_swap(id, args)
	await _fade(0.0, fade)
	_busy = false
	transition_finished.emit()


func replace(id: String, args: Dictionary = {}) -> void:
	await go_to(id, args, false)


func back(fallback: String = "main_menu") -> void:
	if _busy:
		return
	if _stack.is_empty():
		await go_to(fallback, {}, false)
		return
	var entry: Dictionary = _stack.pop_back()
	await go_to(String(entry["id"]), entry.get("args", {}), false)


func clear_stack() -> void:
	_stack.clear()


func stack_depth() -> int:
	return _stack.size()


## Convenience used by every mode entry point.
func start_match(config: MatchConfig, on_finished: Callable = Callable()) -> void:
	await go_to("match", {"config": config, "on_finished": on_finished})


func _swap(id: String, args: Dictionary) -> void:
	if current_node != null and is_instance_valid(current_node):
		if current_node.has_method("teardown"):
			current_node.call("teardown")
		current_node.queue_free()
		current_node = null
	var script: Script = load(SCREENS[id])
	if script == null:
		Log.e("failed to load screen script for '%s'" % id, "Router")
		return
	var node: Node = script.new()
	node.name = id
	holder.add_child(node)
	current_node = node
	current_id = id
	if node.has_method("setup"):
		node.call("setup", args)
	screen_changed.emit(id)
	Log.d("screen -> %s" % id, "Router")


func _fade(target: float, duration: float) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	if duration <= 0.0 or DisplayServer.get_name() == "headless":
		overlay.color.a = target
		return
	var tw := create_tween()
	tw.tween_property(overlay, "color:a", target, duration)
	await tw.finished
