extends RefCounted

class PainterProbe extends "res://src/ai/brains/painter_brain.gd":
	var destination := Vector3.INF
	func steer_to(target: Vector3, _urgency: float = 1.0) -> void:
		destination = target


func run(t: TestHarness, host: Node) -> void:
	t.suite("AI rendered tile targets")
	for id in ["paint_grid", "mnatiq", "mukharrib", "color_stand"]:
		for difficulty in 4:
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			scene.setup({"config": MatchConfig.build(id, ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 717), "on_finished": func(_r): pass})
			scene.set_physics_process(false)
			for body in scene.ctx.fighters:
				body.set_physics_process(false)
			# Remove camera framing from this fixture: actual node visibility is
			# sufficient to reproduce the hidden-nearest information leak.
			scene.ctx.observation_camera = null
			var game = scene.controller
			var hidden: ArenaTile = game._tiles[0]
			var visible: ArenaTile = game._tiles[1]
			var me: Fighter = scene.ctx.fighter(0)
			me.global_position = hidden.global_position + Vector3.UP
			for tile: ArenaTile in game._tiles:
				tile.set_physics_process(false)
				tile.hide()
				if id == "color_stand":
					tile.tag = "unmatched"
				else:
					tile.owner_slot = 0
			visible.show()
			if id == "color_stand":
				hidden.tag = game.called_tag()
				visible.tag = game.called_tag()
				var brain = load("res://src/ai/brains/color_brain.gd").new()
				brain.configure(0, scene.ctx, difficulty, 717)
				brain.controller = game
				brain.on_round_start()
				brain.decide(0.01)
				brain._time = 2.0
				brain.decide(0.01)
				t.equal(brain._committed, visible, "color difficulty %d selects visible alternative to hidden nearest" % difficulty)
				visible.hide()
				brain.move = Vector2.RIGHT
				brain.decide(0.01)
				t.ok(brain._committed == null, "color difficulty %d drops hidden commitment" % difficulty)
				t.equal(brain.move, Vector2.ZERO, "color difficulty %d stops when no safe tile is observable" % difficulty)
				visible.show()
				brain.decide(0.01)
				t.equal(brain._committed, visible, "color difficulty %d reacquires rendered safe ground" % difficulty)
			else:
				hidden.owner_slot = -1
				visible.owner_slot = -1
				var brain := PainterProbe.new()
				brain.configure(0, scene.ctx, difficulty, 717)
				brain.controller = game
				t.ok(not brain.can_observe(hidden) and brain.can_observe(visible), "%s fixture distinguishes hidden and rendered ground" % id)
				brain.decide(0.01)
				t.equal(brain.destination, visible.global_position, "%s difficulty %d selects visible alternative to hidden nearest" % [id, difficulty])
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame
