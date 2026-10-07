extends RefCounted

class TimingProbe extends "res://src/ai/brains/dodger_brain.gd":
	func _incoming_arm(_arena: Arena, _pos: Vector3) -> Dictionary:
		return {"eta": 1.0, "origin": Vector3.ZERO, "length": 9.0}


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
	arena.queue_free()
	await host.get_tree().process_frame
