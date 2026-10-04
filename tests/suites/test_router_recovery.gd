extends RefCounted

class FaultRouter extends "res://src/core/scene_router.gd":
	var fail := true
	func _load_screen_script(id: String) -> Script:
		return null if fail else load(SCREENS[id]) as Script


func run(t: TestHarness, host: Node) -> void:
	t.suite("screen transition recovery")
	var router := FaultRouter.new()
	host.add_child(router)
	var previous := Control.new()
	router.holder.add_child(previous)
	router.current_node = previous
	router.current_id = "settings"
	t.ok(not await router.go_to("main_menu", {}, true, 0.0), "failed transition returns false")
	t.equal(router.current_id, "settings", "failed load keeps previous screen identity")
	t.ok(router.current_node == previous, "failed load keeps previous node")
	t.ok(not previous.is_queued_for_deletion(), "previous screen is not queued for destruction")
	t.equal(router.stack_depth(), 0, "failed forward transition does not push history")
	t.ok(not router._busy, "failed transition unlocks navigation")
	t.equal(router.overlay.color.a, 0.0, "failed transition restores visible screen")
	router._stack = [{"id": "main_menu", "args": {}}]
	await router.back()
	t.equal(router.stack_depth(), 1, "failed back transition preserves history entry")
	t.equal(router.current_id, "settings", "failed back does not change identity")
	router.fail = false
	t.ok(await router.go_to("main_menu", {}, true, 0.0), "successful transition returns true")
	t.equal(router.current_id, "main_menu", "normal route still replaces the screen")
	t.ok(router.current_node != previous, "normal route installs a new node")
	t.ok(previous.is_queued_for_deletion(), "normal route releases the previous node")
	t.equal(router.stack_depth(), 2, "only successful forward navigation adds history")
	router.fail = true
	router._stack = [{"id": "main_menu", "args": {}}]
	await router.back()
	t.equal(router.stack_depth(), 1, "failed same-id reload also preserves history")
	router._busy = true
	t.ok(not await router.go_to("settings", {}, true, 0.0), "concurrent request is still rejected")
	t.equal(router.stack_depth(), 1, "rejected concurrent request leaves history intact")
	router._busy = false
	router.queue_free()
	await host.get_tree().process_frame
