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

const MatchResourcePreparation = preload("res://src/match/match_resource_preparation.gd")

const SCREENS := {
	"game_library": "res://src/ui/screens/game_library.gd",
	"boot": "res://src/ui/screens/boot_screen.gd",
	"main_menu": "res://src/ui/screens/main_menu.gd",
	"adventure": "res://src/ui/screens/adventure_map.gd",
	"quick_play": "res://src/ui/screens/quick_play.gd",
	"tournament": "res://src/ui/screens/tournament_setup.gd",
	"playlist_builder": "res://src/ui/screens/playlist_builder.gd",
	"local_play": "res://src/ui/screens/local_play.gd",
	"online": "res://src/ui/screens/online_screen.gd",
	"training": "res://src/ui/screens/training_screen.gd",
	"daily": "res://src/ui/screens/daily_screen.gd",
	"characters": "res://src/ui/screens/character_gallery.gd",
	"rewards": "res://src/ui/screens/rewards_screen.gd",
	"achievements": "res://src/ui/screens/achievements_screen.gd",
	"stats": "res://src/ui/screens/stats_screen.gd",
	"settings": "res://src/ui/screens/settings_screen.gd",
	"touch_layout": "res://src/ui/screens/touch_layout_screen.gd",
	"updates": "res://src/ui/screens/updates_screen.gd",
	"credits": "res://src/ui/screens/credits_screen.gd",
	"customize": "res://src/ui/screens/customize_screen.gd",
	"profile": "res://src/ui/screens/profile_screen.gd",
	"account": "res://src/ui/screens/account_screen.gd",
	"results": "res://src/ui/screens/results_screen.gd",
	"replays": "res://src/ui/screens/replay_library.gd",
	"replay_player": "res://src/ui/screens/replay_player.gd",
	"standings": "res://src/ui/screens/standings_screen.gd",
	"match": "res://src/match/match_scene.gd",
}

var holder_layer: CanvasLayer
var holder: Control
var overlay: ColorRect
var loading_progress: ProgressBar
var toast_layer: CanvasLayer
var current_id := ""
var current_node: Node
var _stack: Array = []
var _busy := false
var _prefetch_job: Node
var _prefetch_paths := PackedStringArray()
var _prefetch_ready := false
var _prefetch_generation := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Keep screens on an explicit canvas layer. iOS may otherwise leave Control
	# screens parented under a plain Node with no usable rect, which presents as
	# only the clear colour being visible.
	holder_layer = CanvasLayer.new()
	holder_layer.layer = 0
	holder_layer.name = "ScreenLayer"
	add_child(holder_layer)
	holder = Control.new()
	holder.name = "ScreenHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder_layer.add_child(holder)
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.name = "TransitionLayer"
	add_child(layer)
	overlay = ColorRect.new()
	overlay.color = Color(0.03, 0.03, 0.06, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)
	loading_progress = ProgressBar.new()
	loading_progress.show_percentage = false
	loading_progress.max_value = 1.0
	loading_progress.set_anchors_preset(Control.PRESET_CENTER)
	loading_progress.offset_left = -100.0
	loading_progress.offset_right = 100.0
	loading_progress.offset_top = -5.0
	loading_progress.offset_bottom = 5.0
	loading_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_progress.hide()
	overlay.add_child(loading_progress)
	toast_layer = CanvasLayer.new()
	toast_layer.layer = 90
	toast_layer.name = "ToastLayer"
	add_child(toast_layer)


## Replace the current screen. `push` keeps the previous id on the back stack.
func go_to(id: String, args: Dictionary = {}, push: bool = true, fade: float = 0.22) -> bool:
	if _busy:
		# Two buttons pressed on the same frame must not open two screens.
		return false
	if not SCREENS.has(id):
		Log.e("unknown screen '%s'" % id, "Router")
		return false
	_busy = true
	var previous_id := current_id
	var requested_epoch := Net.epoch
	var requested_room := Net.room_code
	await _fade(1.0, fade)
	var preparation: Node
	var prepared := true
	if id == "match":
		preparation = MatchResourcePreparation.new()
		add_child(preparation)
		loading_progress.value = 0.0
		loading_progress.show()
		var previous_mode := Node.PROCESS_MODE_INHERIT
		var previous_node := current_node
		if is_instance_valid(previous_node):
			previous_mode = previous_node.process_mode
			previous_node.process_mode = Node.PROCESS_MODE_DISABLED
		var config = args.get("config")
		if config is MatchConfig:
			prepared = _match_session_is_current(config, requested_epoch, requested_room)
			if prepared:
				prepared = await _prepare_match(preparation, config)
				prepared = prepared and _match_session_is_current(config, requested_epoch, requested_room)
			if not prepared and config.context == MatchConfig.Context.ONLINE:
				Log.w("online match changed or could not be prepared", "Router")
		else:
			Log.e("match resource preparation requires a config", "Router")
			prepared = false
		if is_instance_valid(previous_node):
			previous_node.process_mode = previous_mode
	var swapped := prepared and _swap(id, args)
	loading_progress.hide()
	if preparation != null:
		preparation.release()
	if swapped and push and previous_id != "" and previous_id != id:
		_stack.append({"id": previous_id, "args": {}})
	await _fade(0.0, fade)
	_busy = false
	transition_finished.emit()
	return swapped


func _match_session_is_current(config: MatchConfig, expected_epoch: int, expected_room: String) -> bool:
	if config.context != MatchConfig.Context.ONLINE:
		return true
	if Net.mode == Net.Mode.LOCAL or Net.state != Net.State.IN_MATCH \
			or Net.epoch != expected_epoch or Net.room_code != expected_room \
			or Net.room_state not in ["loading", "playing"]:
		return false
	var rules = Net.match_data.get("config")
	return rules is Dictionary and rules.get("game") == config.minigame_id \
		and rules.get("arena") == config.arena_id and Net.match_data.get("seed") == config.seed


func _prepare_match(preparation: Node, config: MatchConfig) -> bool:
	var paths := MatchResourcePreparation.paths_for(config)
	if paths.is_empty():
		Log.e("match has no valid resource plan", "Router")
		return false
	var job := _prefetch_job
	if is_instance_valid(job) and _prefetch_paths == paths:
		while is_instance_valid(job) and _prefetch_job == job and not _prefetch_ready:
			await get_tree().process_frame
		if is_instance_valid(job) and _prefetch_job == job and _prefetch_ready:
			preparation.resources.assign(job.resources)
			clear_match_prefetch()
			loading_progress.value = 1.0
			return true
	clear_match_prefetch()
	var loaded: bool = await preparation.prepare(paths, func(value: float): loading_progress.value = value)
	if not loaded:
		Log.e("match resource preparation failed: %s" % preparation.error_path, "Router")
	return loaded


func prefetch_match(config: MatchConfig) -> bool:
	var paths := MatchResourcePreparation.paths_for(config)
	if config == null or config.context != MatchConfig.Context.TOURNAMENT or paths.is_empty():
		clear_match_prefetch()
		return false
	if is_instance_valid(_prefetch_job) and paths == _prefetch_paths:
		return true
	clear_match_prefetch()
	_prefetch_paths = paths
	_prefetch_job = _new_prefetch_job()
	add_child(_prefetch_job)
	_run_prefetch(_prefetch_job, paths, _prefetch_generation)
	return true


func _new_prefetch_job() -> Node:
	return MatchResourcePreparation.new()


func prefetch_from_screen(source: Node, config: MatchConfig) -> bool:
	if not is_instance_valid(source) or source.is_queued_for_deletion() or current_node != source \
			or current_id not in ["match", "standings"]:
		return false
	return prefetch_match(config)


func _run_prefetch(job: Node, paths: PackedStringArray, generation: int) -> void:
	var loaded: bool = await job.prepare(paths)
	if generation != _prefetch_generation or not is_instance_valid(job) or _prefetch_job != job:
		return
	_prefetch_ready = loaded
	if not loaded:
		clear_match_prefetch()


func clear_match_prefetch() -> void:
	_prefetch_generation += 1
	var job := _prefetch_job
	_prefetch_job = null
	_prefetch_paths.clear()
	_prefetch_ready = false
	if is_instance_valid(job):
		job.release()


func replace(id: String, args: Dictionary = {}) -> void:
	await go_to(id, args, false)


func back(fallback: String = "main_menu") -> void:
	if _busy:
		return
	if _stack.is_empty():
		await go_to(fallback, {}, false)
		return
	var entry: Dictionary = _stack.pop_back()
	if not await go_to(String(entry["id"]), entry.get("args", {}), false):
		_stack.append(entry)


func clear_stack() -> void:
	_stack.clear()


func stack_depth() -> int:
	return _stack.size()


## Convenience used by every mode entry point.
func start_match(config: MatchConfig, on_finished: Callable = Callable()) -> void:
	var args := {"config": config, "on_finished": on_finished}
	var session = on_finished.get_object() if on_finished.is_valid() else null
	if session is TournamentSession and config != null and config.context == MatchConfig.Context.TOURNAMENT:
		args["next_config"] = session.following_config()
	await go_to("match", args)


func _swap(id: String, args: Dictionary) -> bool:
	var script := _load_screen_script(id)
	if script == null or not script.can_instantiate():
		Log.e("failed to load screen script for '%s'" % id, "Router")
		return false
	var candidate = script.new()
	if not candidate is Node:
		if candidate is Object and not candidate is RefCounted:
			candidate.free()
		Log.e("screen script for '%s' is not a Node" % id, "Router")
		return false
	var node: Node = candidate
	if id not in ["match", "standings"]:
		clear_match_prefetch()
	if current_node != null and is_instance_valid(current_node):
		if current_node.has_method("teardown"):
			current_node.call("teardown")
		current_node.queue_free()
		current_node = null
	node.name = id
	holder.add_child(node)
	if node is Control:
		var control := node as Control
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.offset_left = 0.0
		control.offset_top = 0.0
		control.offset_right = 0.0
		control.offset_bottom = 0.0
	current_node = node
	current_id = id
	if node.has_method("setup"):
		node.call("setup", args)
	screen_changed.emit(id)
	Log.d("screen -> %s" % id, "Router")
	return true


func _load_screen_script(id: String) -> Script:
	return load(SCREENS[id]) as Script


func _fade(target: float, duration: float) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	if duration <= 0.0 or DisplayServer.get_name() == "headless":
		overlay.color.a = target
		return
	var tw := create_tween()
	tw.tween_property(overlay, "color:a", target, duration)
	await tw.finished
