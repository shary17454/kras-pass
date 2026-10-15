extends RefCounted

class TimingProbe extends "res://src/ai/brains/dodger_brain.gd":
	var eta := 1.0
	func _incoming_arm(_arena: Arena, _pos: Vector3) -> Dictionary:
		return {"eta": eta, "origin": Vector3.ZERO, "length": 9.0}


func run(t: TestHarness, host: Node) -> void:
	t.suite("dodger own jump timing")
	var arena := Arena.new()
	arena.def = ArenaDef.new()
	host.add_child(arena)
	arena.current_radius = 10.0
	var body := Fighter.new()
	arena.add_child(body)
	body.set_physics_process(false)
	var ctx := MatchContext.new()
	ctx.arena = arena
	ctx.config = MatchConfig.build("sweeper_storm", ["fanoos"], 0, 1, 937)
	ctx.fighters.append(body)
	var brain := TimingProbe.new()
	brain.configure(0, ctx, 3, 937)
	brain.accuracy = 1.0
	for character in Registry.characters():
		body.data = character
		body._apply_character()
		for gravity in [1.0, 0.5]:
			for jump in [1.0, 1.2]:
				body.mutator["gravity"] = gravity
				body.mods["jump"] = jump
				brain.on_round_start()
				brain.decide(0.1)
				var apex: float = body.jump_velocity * jump / body._gravity()
				t.near(brain._lead, apex, 0.0001, "%s times its own jump apex under gravity/jump modifiers" % character.id)
				var before: float = brain._lead
				body.jump_velocity *= 0.8
				brain.decide(0.1)
				t.near(brain._lead, before, 0.0001, "an encounter retains one timing decision, not a reroll each tick")
				body._apply_character()
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	collider.shape = box
	floor_body.add_child(collider)
	arena.add_child(floor_body)
	floor_body.position.y = -0.5
	body.data = Registry.character("fanoos")
	body._apply_character()
	body.mutator["gravity"] = 1.0
	body.mods["jump"] = 1.0
	body.global_position = arena.global_position + Vector3.UP
	body.velocity = Vector3.ZERO
	for step in 60:
		await host.get_tree().physics_frame
		body.tick(InputFrame.new(), 1.0 / 60.0)
	t.ok(body.is_on_floor(), "retry fixture uses actual floor contact")
	brain.on_round_start()
	brain.eta = 0.1
	body.mods["frozen"] = 0.15
	var frame := InputFrame.new()
	var jumps := 0
	var blocked_jumps := 0
	for step in 30:
		await host.get_tree().physics_frame
		if step % 6 == 0:
			brain.bits = 0
			brain.decide(0.1)
		frame.prev_bits = frame.bits
		frame.bits = brain._take_actions()
		var grounded := body.is_on_floor()
		var blocked := float(body.mods["frozen"]) > 1.0 / 60.0
		body.tick(frame, 1.0 / 60.0)
		if grounded and body.velocity.y > 1.0:
			jumps += 1
			if blocked:
				blocked_jumps += 1
	t.equal(blocked_jumps, 0, "jump retries cannot bypass the real freeze timer")
	t.ok(jumps > 0, "persistent incoming threat retries a jump edge after freeze expires")
	arena.queue_free()
	await host.get_tree().process_frame
