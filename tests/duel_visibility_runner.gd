extends "res://tests/duel_visibility_physics_host.gd"


func _ready() -> void:
	set_physics_process(false)
	if SaveSystem.storage_root == SaveSystem.DIR:
		push_error("Duel visibility tests require isolated storage")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var t := TestHarness.new()
	print("DUEL_PHYSICS_SETTINGS=" + JSON.stringify({
		"separate_thread": ProjectSettings.get_setting_with_override("physics/3d/run_on_separate_thread"),
		"physics_engine": ProjectSettings.get_setting_with_override("physics/3d/physics_engine"),
		"ticks": Engine.physics_ticks_per_second, "host": OS.get_name(), "performanceScope": "headless_CPU_not_iPhone"}))
	var suite: Script = load("res://tests/suites/test_duel_visibility.gd")
	if suite == null or not suite.can_instantiate():
		get_tree().quit(1)
		return
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	await suite.new().run(t, self)
	await get_tree().process_frame
	var nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	t.equal(nodes_after, nodes_before, "focused fixtures retain no additional nodes")
	print("DUEL_VISIBILITY_NODE_COUNTS=" + JSON.stringify({"before": nodes_before, "after": nodes_after}))
	AudioManager.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	OS.delay_msec(100)
	get_tree().quit(t.report())
