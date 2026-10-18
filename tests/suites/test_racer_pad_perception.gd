extends RefCounted

class PadController extends MiniGameController:
	var pad: MeshInstance3D
	var available := true
	func next_checkpoint(_slot: int) -> Vector3:
		return Vector3(8, 100, 0)
	func boost_pad_positions(_slot: int) -> Array:
		return [pad.global_position] if available else []
	func boost_pad_nodes() -> Array[Node3D]:
		return [pad]
	func boost_pad_available(_slot: int, node: Node3D) -> bool:
		return node == pad and available

class Observer extends "res://src/ai/brains/racer_brain.gd":
	var destination := Vector3.INF
	func drive_to(target: Vector3, _reverse_when_stuck: bool = true) -> void:
		destination = target
	func maybe_dash(_scale: float = 1.0) -> void:
		pass

func run(t: TestHarness, host: Node) -> void:
	t.suite("racer boost-pad perception")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("kart_sprint", ["fanoos", "nabta", "ramla", "sakhra"], 0, 3, 917)})
	scene.set_physics_process(false)
	scene.ctx.observation_camera = null
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
		fighter.hide()
	var me: Fighter = scene.ctx.fighter(0)
	me.show()
	me.global_position = Vector3(0, 100, 0)
	me.face_direction(Vector3.RIGHT)
	var pad := MeshFactory.box(Vector3.ONE, Color.GREEN)
	scene.add_child(pad)
	pad.global_position = Vector3(4, 100, 0)
	var controller := PadController.new()
	controller.pad = pad
	for difficulty in 4:
		var brain := Observer.new()
		brain.configure(0, scene.ctx, difficulty, 917)
		brain.controller = controller
		brain.strategy = 1.0
		brain._time = 10.0
		pad.show()
		controller.available = true
		brain.decide(0.1)
		t.equal(brain.destination, controller.next_checkpoint(0), "new pad waits for the profile reaction delay")
		brain._time += brain.reaction_time
		brain.decide(0.1)
		t.equal(brain.destination, pad.global_position, "observed pad becomes a valid detour after the delay")
		pad.hide()
		brain.decide(0.1)
		t.equal(brain.destination, controller.next_checkpoint(0), "hidden pad cannot divert the racing line")
		pad.show()
		brain.decide(0.1)
		t.equal(brain.destination, controller.next_checkpoint(0), "reappearing pad needs fresh observation")
		brain._time += brain.reaction_time
		brain.decide(0.1)
		t.equal(brain.destination, pad.global_position, "reappearing pad can be reacquired")
		controller.available = false
		brain.decide(0.1)
		t.equal(brain.destination, controller.next_checkpoint(0), "recharging pad cannot attract a bot")
		controller.available = true
		brain.decide(0.1)
		t.equal(brain.destination, controller.next_checkpoint(0), "recharged pad needs fresh observation")
		brain._time += brain.reaction_time
		brain.decide(0.1)
		t.equal(brain.destination, pad.global_position, "recharged pad matures normally")
		brain.on_round_start()
		brain.decide(0.1)
		t.equal(brain.destination, controller.next_checkpoint(0), "round restart discards old pad observations")
	controller.free()
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
