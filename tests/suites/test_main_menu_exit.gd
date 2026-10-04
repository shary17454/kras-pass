extends RefCounted

class Menu extends "res://src/ui/screens/main_menu.gd":
	var quits := 0
	func _quit_application() -> void:
		quits += 1


func run(t: TestHarness, host: Node) -> void:
	t.suite("main menu exit confirmation")
	var saved_stack := SceneRouter._stack.duplicate(true)
	var menu := Menu.new()
	host.add_child(menu)
	menu.setup({})
	menu.go_back()
	t.equal(menu.quits, 0, "root back does not immediately exit")
	t.not_null(menu._quit_dialog, "root back opens a confirmation")
	t.ok(menu._quit_dialog.visible, "confirmation is visible")
	var first := menu._quit_dialog
	menu.go_back()
	menu._confirm_quit()
	t.ok(menu._quit_dialog == first, "back and explicit quit reuse one dialog")
	var count := 0
	for child in menu.get_children():
		if child is ConfirmationDialog:
			count += 1
	t.equal(count, 1, "repeated requests do not accumulate modal nodes")
	first.get_cancel_button().pressed.emit()
	await host.get_tree().process_frame
	t.equal(menu.quits, 0, "cancel preserves the running game")
	t.ok(not first.visible, "cancel closes the confirmation")
	menu.go_back()
	t.ok(menu._quit_dialog == first and first.visible, "confirmation can reopen after cancel")
	first.get_ok_button().pressed.emit()
	await host.get_tree().process_frame
	t.equal(menu.quits, 1, "confirm invokes the exit action exactly once")
	t.ok(not first.visible, "confirm closes the modal")
	menu.queue_free()
	await host.get_tree().process_frame
	t.ok(not is_instance_valid(first), "menu teardown releases its confirmation")
	SceneRouter._stack = saved_stack
