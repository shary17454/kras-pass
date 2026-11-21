extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("collector delayed competition cues")
	var context := MatchContext.new()
	context.config = MatchConfig.build("gem_grab", ["fanoos", "fanoos"], 0, 3, 451)
	context.alive.assign([true, true])
	var world := Node3D.new()
	host.add_child(world)
	context.world_root = world
	for index in 2:
		var fighter := Fighter.new()
		world.add_child(fighter)
		fighter.set_physics_process(false)
		fighter.position = Vector3(index * 3, 1, 0)
		context.fighters.append(fighter)
	var near := Collectible.new()
	var far := Collectible.new()
	world.add_child(near)
	world.add_child(far)
	near.add_to_group("pickups")
	far.add_to_group("pickups")
	near.place(Vector3(5, 1, 0))
	far.place(Vector3(0, 1, 6))
	var brain = load("res://src/ai/brains/collector_brain.gd").new()
	brain.configure(0, context, 3, 451)
	brain.reaction_time = 0.2
	# The stationary loot is already known before the rival first appears.
	brain._time = -0.3
	brain.perceived_object_position(near)
	brain.perceived_object_position(far)
	brain._time = 0.0
	t.equal(brain._preferred_loot(), near, "unknown competitor does not reveal immediate competition")
	brain._record_history()
	brain._time = 0.3
	context.fighter(1).velocity = Vector3.LEFT * 5
	brain._record_history()
	t.equal(brain._preferred_loot(), far, "newly observed away motion remains delayed")
	brain._time = 0.6
	brain._record_history()
	t.equal(brain._preferred_loot(), near, "observed rival moving away does not make reachable loot contested")
	context.fighter(1).velocity = Vector3.RIGHT * 5
	brain._record_history()
	t.equal(brain._preferred_loot(), near, "private current velocity cannot change delayed competition")
	brain._time = 0.9
	brain._record_history()
	t.equal(brain._preferred_loot(), far, "approaching competitor affects preference after reaction delay")
	context.fighter(1).hide()
	t.equal(brain._preferred_loot(), near, "hidden competitor cannot keep a gem contested")
	context.fighter(1).show()
	context.fighter(1).position = Vector3(4.5, 1, 0)
	context.fighter(1).velocity = Vector3.LEFT * 5
	brain._time = 1.2
	brain._record_history()
	brain._time = 1.5
	brain._record_history()
	t.equal(brain._preferred_loot(), far, "competitor already within pickup reach remains a real risk while moving away")
	world.queue_free()
	await host.get_tree().process_frame
