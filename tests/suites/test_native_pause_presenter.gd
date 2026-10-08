extends RefCounted

const Presenter = preload("res://src/ui/native_pause_presenter.gd")

class Bridge extends RefCounted:
	signal menu_action(session: int, command: String)
	var supported := true
	var requests: Array[Dictionary] = []
	var navigation: Array = []
	var dismissed := 0
	func supports_glass_menu() -> bool: return supported
	func present_glass_menu(labels: Dictionary, session: int, rtl: bool, restart: bool) -> void:
		requests.append({"labels": labels.duplicate(true), "session": session, "rtl": rtl, "restart": restart})
	func dismiss_glass_menu() -> void: dismissed += 1
	func navigate_glass_menu(session: int, direction: int, activate: bool) -> void:
		navigation.append([session, direction, activate])

class LegacyBridge extends RefCounted:
	signal menu_action(session: int, command: String)

class FixtureTransport extends Node:
	func send(_message: Dictionary) -> bool:
		return true


func run(t: TestHarness, host: Node) -> void:
	t.suite("native pause presentation and stale responses")
	var legacy := Presenter.new(LegacyBridge.new())
	t.ok(not legacy.show({}, false, true), "old native bridge falls back safely")
	legacy.dispose()
	var bridge := Bridge.new()
	var presenter := Presenter.new(bridge)
	var actions: Array[String] = []
	var failures: Array = []
	presenter.action.connect(func(command): actions.append(command))
	presenter.unavailable.connect(func(): failures.append(true))
	bridge.supported = false
	t.ok(not presenter.show({}, false, true), "unsupported iOS falls back")
	t.equal(bridge.requests.size(), 0, "unsupported platform never presents native UI")
	bridge.supported = true
	t.ok(presenter.show({"title": "test"}, true, false), "supported bridge receives presentation")
	t.ok(bridge.requests[0].rtl and not bridge.requests[0].restart, "RTL and online restart restriction reach bridge")
	t.ok(not presenter.show({}, false, true), "double opening does not create duplicate presentation")
	presenter.navigate(10)
	t.equal(bridge.navigation[0], [bridge.requests[0].session, 1, false], "controller navigation is scoped and bounded")
	presenter.navigate(0)
	t.equal(bridge.navigation[1], [bridge.requests[0].session, 0, false], "cancel is forwarded to native confirmation instead of discarding its parent menu")
	bridge.menu_action.emit(bridge.requests[0].session, "unknown")
	t.ok(presenter.active and actions.is_empty(), "unknown native command cannot mutate match")
	presenter.dismiss()
	bridge.menu_action.emit(bridge.requests[0].session, "quit")
	t.ok(actions.is_empty(), "late response after dismissal is ignored")
	t.ok(presenter.show({}, false, true), "new presentation may open after dismissal")
	bridge.menu_action.emit(bridge.requests[0].session, "resume")
	t.ok(presenter.active and actions.is_empty(), "old session cannot resume a new menu")
	bridge.menu_action.emit(bridge.requests[1].session, "unavailable")
	t.ok(not presenter.active and failures.size() == 1, "late native failure requests Godot fallback exactly once")
	bridge.menu_action.emit(bridge.requests[1].session, "unavailable")
	t.equal(failures.size(), 1, "duplicate failure does not duplicate fallback")
	presenter.show({}, false, true)
	bridge.menu_action.emit(bridge.requests[2].session, "settings")
	t.equal(actions, ["settings"], "current session delivers a permitted command")
	presenter.dispose()
	t.equal(bridge.get_signal_connection_list("menu_action").size(), 0, "disposal disconnects native callback")
	await _match_flow(t, host, false)
	await _match_flow(t, host, true)


func _match_flow(t: TestHarness, host: Node, online: bool) -> void:
	t.suite("native pause match flow " + ("online" if online else "local"))
	var saved_transport: Node = Net.transport
	var saved_match: Dictionary = Net.match_data
	var transport := FixtureTransport.new()
	if online:
		host.add_child(transport)
		Net.transport = transport
		Net.match_data = {"fixture": true}
	var cfg := MatchConfig.build("ring_rumble", ["fanoos", "nabta", "ramla", "sakhra"], 1, 1, 712)
	if online: cfg.context = MatchConfig.Context.ONLINE
	var scene = load("res://src/match/match_scene.gd").new()
	var bridge := Bridge.new()
	scene._native_pause.dispose()
	scene._native_pause = Presenter.new(bridge)
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	t.ok(scene.ctx != null and not scene._aborted, "fixture starts a real match before pause testing")
	scene._toggle_pause()
	t.equal(scene._paused, not online, "online menu never pauses match authority")
	t.equal(scene._pause_menu.get_child_count(), 0, "native menu does not duplicate Godot card")
	t.equal(bridge.requests[0].restart, not online, "online restart is disabled in native menu")
	for key in ["title", "resume", "restart", "settings", "quit", "confirm", "cancel"]:
		t.ok(not String(bridge.requests[0].labels[key]).is_empty(), "native label uses localization: " + key)
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	scene._input(cancel)
	t.ok(not bridge.navigation.is_empty(), "configured controller cancel produces a navigation command")
	if not bridge.navigation.is_empty():
		t.equal(bridge.navigation[-1], [bridge.requests[0].session, 0, false], "actual controller cancel reaches the current native dialog")
	t.ok(scene._pause_menu != null and scene._native_pause.active, "controller cancel waits for native confirmation handling")
	for command in [[JOY_BUTTON_DPAD_UP, -1, false], [JOY_BUTTON_DPAD_DOWN, 1, false], [JOY_BUTTON_A, 0, true]]:
		var event := InputEventJoypadButton.new()
		event.button_index = command[0]
		event.pressed = true
		var before: int = bridge.navigation.size()
		scene._input(event)
		t.equal(bridge.navigation.size(), before + 1, "controller menu action is routed once")
		if bridge.navigation.size() > before:
			t.equal(bridge.navigation[-1], [bridge.requests[0].session, command[1], command[2]], "controller direction and activation preserve native session")
	bridge.menu_action.emit(bridge.requests[0].session, "resume")
	t.ok(not scene._paused and scene._pause_menu == null, "native resume restores original match flow")
	scene._toggle_pause()
	var session: int = bridge.requests[-1].session
	bridge.menu_action.emit(session, "unavailable")
	t.ok(scene._pause_menu.get_child_count() > 0, "presentation failure restores original Godot controls")
	t.equal(scene._paused, not online, "fallback preserves authority and local pause")
	scene._toggle_pause()
	scene.teardown()
	bridge.menu_action.emit(session, "quit")
	t.ok(not scene._aborted, "stale post-teardown response cannot leave a match")
	t.equal(bridge.get_signal_connection_list("menu_action").size(), 0, "match teardown disconnects native signal")
	scene.queue_free()
	Net.transport = saved_transport
	Net.match_data = saved_match
	if online:
		transport.queue_free()
	else:
		transport.free()
	await host.get_tree().process_frame
