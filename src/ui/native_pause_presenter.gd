extends RefCounted
## Native presentation only; match authority and pause state stay in Godot.

signal action(command: String)
signal unavailable

const COMMANDS := ["resume", "restart", "settings", "quit"]
var _bridge: Object
var _generation := 0
var active := false


func _init(bridge: Object = null) -> void:
	_bridge = bridge
	if _bridge == null and OS.get_name() == "iOS" and ClassDB.class_exists("KrasAppleBridge"):
		_bridge = ClassDB.instantiate("KrasAppleBridge")
	if _bridge != null and _bridge.has_signal("menu_action"):
		_bridge.connect("menu_action", _on_action)


func show(labels: Dictionary, rtl: bool, allows_restart: bool) -> bool:
	if active or not _supported():
		return false
	_generation += 1
	active = true
	_bridge.call("present_glass_menu", labels, _generation, rtl, allows_restart)
	return true


func _supported() -> bool:
	if not is_instance_valid(_bridge) or not _bridge.has_signal("menu_action"):
		return false
	for method in ["supports_glass_menu", "present_glass_menu", "dismiss_glass_menu", "navigate_glass_menu"]:
		if not _bridge.has_method(method):
			return false
	return _bridge.call("supports_glass_menu") == true


func navigate(direction: int, activate := false) -> void:
	if active:
		_bridge.call("navigate_glass_menu", _generation, clampi(direction, -1, 1), activate)


func dismiss() -> void:
	_generation += 1
	active = false
	if is_instance_valid(_bridge) and _bridge.has_method("dismiss_glass_menu"):
		_bridge.call("dismiss_glass_menu")


func dispose() -> void:
	dismiss()
	if is_instance_valid(_bridge) and _bridge.has_signal("menu_action") and _bridge.is_connected("menu_action", _on_action):
		_bridge.disconnect("menu_action", _on_action)
	_bridge = null


func _on_action(session: int, command: String) -> void:
	if not active or session != _generation:
		return
	if command == "unavailable":
		active = false
		unavailable.emit()
	elif COMMANDS.has(command):
		active = false
		action.emit(command)
