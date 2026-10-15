class_name LocalVehicleViews
extends CanvasLayer
## Close views of one shared simulation, only for local world-scale vehicles.

var ctx: MatchContext
var hud: MatchHUD
var cameras: Array[ArenaCamera] = []
var panels: Array[SubViewportContainer] = []
var overlays: Array[Control] = []
var viewports: Array[SubViewport] = []
var radars: Array[Control] = []
var slots: Array[int] = []
var _labels: Array[Label] = []
var _cues: Array = []
var _root_viewport: Viewport
var _previous_disable_3d := false
var _stopped := false


func setup(context: MatchContext, match_hud: MatchHUD, humans: Array[int]) -> void:
	ctx = context
	hud = match_hud
	slots.assign(humans)
	layer = 1
	_root_viewport = get_viewport()
	_previous_disable_3d = _root_viewport.disable_3d
	for slot in slots:
		var panel := SubViewportContainer.new()
		panel.name = "VehicleViewP%d" % (slot + 1)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
		panel.stretch = true
		panel.clip_contents = true
		add_child(panel)
		panels.append(panel)
		var viewport := SubViewport.new()
		viewport.name = "SharedWorldView"
		viewport.world_3d = ctx.arena.get_world_3d()
		viewport.gui_disable_input = true
		viewport.physics_object_picking = false
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		panel.add_child(viewport)
		viewports.append(viewport)
		var camera := ArenaCamera.new()
		viewport.add_child(camera)
		camera.targets = ctx.fighters
		camera.local_target = ctx.fighter(slot)
		camera.configure(ArenaCamera.Mode.WORLD, ctx.arena)
		camera.mode = ArenaCamera.Mode.CHASE if ctx.arena.def.shape == "circuit" else ArenaCamera.Mode.WORLD
		camera._distance = 7.0
		camera._height = 4.5
		camera.follow_distance = 7.0
		camera.follow_height = 4.5
		camera.follow_lookahead = 1.5
		camera.close_follow = true
		camera.fov = 48.0
		camera.current = true
		cameras.append(camera)
		var overlay := Control.new()
		overlay.name = "VehicleOverlayP%d" % (slot + 1)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.layout_direction = Control.LAYOUT_DIRECTION_LTR
		overlay.clip_contents = true
		overlay.z_index = 10
		add_child(overlay)
		overlays.append(overlay)
		var player: PlayerConfig = ctx.config.players[slot]
		var label := UIKit.label("P%d %s  %s" % [slot + 1, player.symbol(), player.display_name()], 20, Color.WHITE, true)
		label.layout_direction = Control.LAYOUT_DIRECTION_LTR
		label.position = Vector2(8, 4)
		label.z_index = 5
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(label)
		_labels.append(label)
		if ctx.definition.id == "tank_arena":
			var radar: Control = load("res://src/ui/tank_radar.gd").new()
			radar.embedded = true
			radar.ctx = ctx
			overlay.add_child(radar)
			radar.scale = Vector2.ONE * 0.45
			radars.append(radar)
		var cues: Array[OffscreenPlayerCue] = []
		for rival in ctx.config.players:
			var cue := OffscreenPlayerCue.new()
			overlay.add_child(cue)
			cue.configure(rival)
			cue.scale = Vector2.ONE * 0.55
			cues.append(cue)
		_cues.append(cues)
	# Do not draw an unused fifth 3D view, or duplicate actors/physics worlds.
	_root_viewport.disable_3d = true
	ctx.observation_camera = cameras[0]
	hud.local_vehicle_views = true
	UserSettings.changed.connect(_quality_changed)
	_apply_quality()
	_layout()


static func regions(view: Vector2, top: float, bottom: float, count: int, inset: Vector4 = Vector4.ZERO) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if count < 2 or count > 4:
		return out
	var gap := 4.0
	var rows := 1 if count == 2 else 2
	var width := maxf(2.0, (view.x - inset.x - inset.z - gap) * 0.5)
	var height := maxf(2.0, (bottom - top - gap * (rows - 1)) / rows)
	for index in count:
		var cell_width := view.x - inset.x - inset.z if count == 3 and index == 2 else width
		out.append(Rect2(Vector2(inset.x + (index % 2) * (width + gap), top + int(index / 2) * (height + gap)), Vector2(cell_width, height)))
	return out


func _process(_delta: float) -> void:
	_layout()
	for index in cameras.size():
		var bounds := Rect2(Vector2(20, 34), Vector2(viewports[index].size) - Vector2(40, 54))
		var results: Array[Dictionary] = []
		for slot in ctx.player_count():
			var cue := {}
			if slot != slots[index] and OffscreenPlayerCue.eligible(ctx, slot):
				cue = OffscreenPlayerCue.project(cameras[index], ctx.fighter(slot).global_position + Vector3.UP * 0.6, bounds)
			results.append(cue)
		OffscreenPlayerCue.separate(results, bounds)
		for slot in results.size():
			var result := results[slot]
			if not result.is_empty():
				result = result.duplicate()
				# OffscreenPlayerCue is drawn at half size in these compact views.
				result.position += _cues[index][slot].size * 0.5 * (1.0 - 0.55)
			_cues[index][slot].place(result)


func _layout() -> void:
	var view := _root_viewport.get_visible_rect().size
	var inset := Platform.safe_insets()
	var top := maxf(hud.occupied_top() + 8.0, inset.y)
	var bottom := view.y - inset.w
	var touches := hud.touch_sources.size()
	if touches > 1:
		bottom = minf(bottom, TouchSource.party_region(view, 0, touches).position.y - 8.0)
	elif touches == 1:
		bottom = minf(bottom, view.y * (0.76 if view.x < view.y else 0.80))
	var cells := regions(view, top, bottom, slots.size(), inset)
	for index in cells.size():
		panels[index].position = cells[index].position
		panels[index].size = cells[index].size
		overlays[index].position = cells[index].position
		overlays[index].size = cells[index].size
		_labels[index].size = Vector2(maxf(2, cells[index].size.x - 16), 30)
		_labels[index].position = Vector2(8, 4)
		if index < radars.size():
			radars[index].position = Vector2(cells[index].size.x - 58.0, 28.0)


func _quality_changed(key: String, _value) -> void:
	if key in ["graphics_quality", "battery_saver", "*"]:
		_apply_quality()


func _apply_quality() -> void:
	for viewport in viewports:
		viewport.scaling_3d_scale = minf(1.0, _root_viewport.scaling_3d_scale)
		viewport.msaa_3d = _root_viewport.msaa_3d
		viewport.screen_space_aa = _root_viewport.screen_space_aa
		viewport.use_taa = _root_viewport.use_taa


func stop() -> void:
	if _stopped:
		return
	_stopped = true
	set_process(false)
	for viewport in viewports:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for camera in cameras:
		camera.set_process(false)
	if is_instance_valid(_root_viewport):
		_root_viewport.disable_3d = _previous_disable_3d


func _exit_tree() -> void:
	stop()
