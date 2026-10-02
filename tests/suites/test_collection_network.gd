extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")
const Items = preload("res://src/net/collectible_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("collection network")
	for game_id in ["gem_grab", "star_rush"]:
		t.test("%s host-owned pickups and carrying" % game_id)
		var cfg := MatchConfig.build(game_id, ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 86)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var game = scene.controller
		var replica = Replica.new()
		scene.ctx.fighters[0].carrying = 3
		scene.ctx.set_score(0, 5)
		var expected_scores: Array = Array(scene.ctx.scores)
		var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
		t.ok(packet.world.items.size() >= 6, "capture live authored pickups")
		t.ok(replica.accept(packet, 4, game_id), "accept serialized world")
		for field in ["items", "carrying"]:
			var bad := packet.duplicate(true)
			bad.world.erase(field)
			t.ok(not replica.accept(bad, 4, game_id), "reject missing " + field)
		var invalid := packet.duplicate(true)
		invalid.world.carrying[0] = 9
		t.ok(not replica.accept(invalid, 4, game_id), "carrying obeys game cap")
		for id in ["", "-1", "01", "+1", " 1", "9223372036854775808"]:
			invalid = packet.duplicate(true)
			invalid.world.items[0].id = id
			t.ok(not replica.accept(invalid, 4, game_id), "reject noncanonical item identity")
		for color in ["red", "fffffffff", "zzzzzzzz", "0xffffff", "-fffffff"]:
			invalid = packet.duplicate(true)
			invalid.world.items[0].color = color
			t.ok(not replica.accept(invalid, 4, game_id), "reject malformed visual color")
		invalid = packet.duplicate(true)
		invalid.world.items[1].id = invalid.world.items[0].id
		t.ok(not replica.accept(invalid, 4, game_id), "reject duplicate identity")
		invalid = packet.duplicate(true)
		invalid.world.items[0].position[0] = INF
		t.ok(not replica.accept(invalid, 4, game_id), "reject non-finite item position")
		invalid = packet.duplicate(true)
		invalid.world.items[0].kind = "crate"
		t.ok(not replica.accept(invalid, 4, game_id), "game controls permitted item kinds")
		replica.render(scene, 0.016)
		t.equal(game._items.size(), 0, "guest releases locally generated pickups")
		var view: Node3D = replica._collectibles
		t.equal(view.views.size(), packet.world.items.size(), "all host pickups appear")
		t.equal(view.find_children("*", "CollisionObject3D", true, false).size(), 0, "replica contains no colliders")
		t.equal(scene.ctx.fighters[0].carrying, 3, "HUD receives host carried count")
		var id: String = packet.world.items[0].id
		var existing: Node3D = view.views[id]
		replica.render(scene, 0.016)
		t.equal(view.views[id], existing, "unchanged snapshots reuse visuals")
		packet.world.items[0].color = "ff0000ff"
		t.ok(replica.accept(packet, 4, game_id), "accept reused pool identity with new appearance")
		replica.render(scene, 0.016)
		t.ok(view.views[id] != existing, "refresh style when pooled item changes")
		packet.world.items.clear()
		packet.world.carrying[0] = 0
		t.ok(replica.accept(packet, 4, game_id), "empty field is valid")
		replica.render(scene, 0.016)
		t.equal(view.views.size(), 0, "collection removes presentation node")
		t.equal(scene.ctx.fighters[0].carrying, 0, "deposit clears carried HUD count")
		t.equal(Array(scene.ctx.scores), expected_scores, "render never awards pickup or deposit points")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
	t.test("bounded collection payload")
	var rows: Array = []
	for i in Items.MAX_ITEMS:
		rows.append({"id": str(9223372036854775807 - i), "kind": "gem", "position": [9999.999, -9999.999, 9999.999],
			"rotation": -3.142, "color": "ffffffff", "size": 0.42, "value": 1000000})
	t.ok(Items.valid(rows, "gem"), "maximum field accepted")
	t.ok(JSON.stringify(rows).to_utf8_buffer().size() < 43000, "bounded rows leave space for players inside snapshot limit")
	rows.append(rows[0].duplicate(true))
	t.ok(not Items.valid(rows, "gem"), "oversized field rejected")
