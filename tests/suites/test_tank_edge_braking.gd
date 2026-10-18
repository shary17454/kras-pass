extends RefCounted

const ROSTERS := [
	["nabta", "sakhra", "fanoos", "ramla"],
	["barq", "mowja", "ghaim", "turs"],
]

class LegacyDriver:
	extends "res://src/ai/brains/driver_brain.gd"

	func retreat_drive_from_edge() -> bool:
		var me := self_body()
		var arena := ctx.arena as Arena
		var margin := arena.edge_distance(me.global_position)
		if margin < lerpf(3.5, 9.0, clampf(me.speed_ratio(), 0.0, 1.0)):
			var retreat := arena.retreat_point(me.global_position)
			drive_to(retreat)
			var inward := retreat - me.global_position
			inward.y = 0.0
			if inward.length_squared() > 0.01:
				inward = inward.normalized()
				var outward_speed := maxf(0.0, -me.velocity.dot(inward))
				var stopping_distance := outward_speed * outward_speed / maxf(2.0 * me.acceleration, 0.1) \
					+ outward_speed * decision_interval
				if me.facing.dot(inward) < 0.0 and stopping_distance >= maxf(0.0, margin - 1.0):
					move.y = 1.0
			return true
		return false


func run(t: TestHarness, host: Node) -> void:
	t.suite("tank edge braking uses real drive integration")
	for arena_id in ["tank_foundry", "tank_oasis", "tank_frost"]:
		for roster in ROSTERS:
			var characters: Array[String] = []
			characters.assign(roster)
			var config := MatchConfig.build("tank_arena", characters, 0, 3, 510161)
			config.arena_id = arena_id
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			scene.setup({"config": config})
			scene.set_physics_process(false)
			scene.ctx.observation_camera = null
			for fighter in scene.ctx.fighters:
				fighter.set_physics_process(false)
			for crate in scene.controller.crates:
				crate.node.hide()
			for slot in 4:
				var me: Fighter = scene.ctx.fighter(slot)
				for difficulty in 4:
					var brain = load("res://src/ai/brains/tank_brain.gd").new()
					brain.configure(slot, scene.ctx, difficulty, 510161)
					brain.controller = scene.controller
					for outward in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
						me.global_position = scene.arena.global_position + outward * (scene.arena.current_radius - 2.0)
						me.global_position.y = 100.0
						me.facing = outward
						me._steer = atan2(outward.x, outward.z)
						me.velocity = outward * me.top_speed
						brain.decide(1.0 / 60.0)
						var label: String = "%s/%s/tier%d/%s" % [arena_id, characters[slot], difficulty, outward]
						t.ok(brain.move.y > 0.0, label + " brakes outward momentum rather than applying forward throttle")
						var before := me.velocity.dot(outward)
						me._integrate_drive(Vector3(brain.move.x, 0, brain.move.y), 1.0 / 60.0)
						t.ok(me.velocity.dot(outward) < before, label + " braking reduces outward speed with ordinary physics")
						me.facing = -outward
						me._steer = atan2(-outward.x, -outward.z)
						me.velocity = -outward * me.top_speed
						brain.decide(1.0 / 60.0)
						t.ok(brain.move.y < 0.0, label + " inward motion keeps its escape throttle")
					brain.controller = null
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame
	await _check_driver_equivalence(t, host)


func _check_driver_equivalence(t: TestHarness, host: Node) -> void:
	t.suite("shared retreat preserves legacy kart decisions and RNG")
	for roster in ROSTERS:
		var characters: Array[String] = []
		characters.assign(roster)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("scrap_karts", characters, 0, 3, 510162)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		for slot in 4:
			var me: Fighter = scene.ctx.fighter(slot)
			for difficulty in 4:
				for outward in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
					for speed in [0.0, 0.5, 1.0]:
						for clearance in [2.0, 8.0, 15.0]:
							for heading in [-1.0, 1.0]:
								me.global_position = scene.arena.global_position + outward * (scene.arena.current_radius - clearance)
								me.global_position.y = 100.0
								me.facing = outward * heading
								me.velocity = outward * me.top_speed * speed
								var legacy := LegacyDriver.new()
								var shared = load("res://src/ai/brains/driver_brain.gd").new()
								for brain in [legacy, shared]:
									brain.configure(slot, scene.ctx, difficulty, 510162)
									brain.controller = scene.controller
									brain.decide(1.0 / 60.0)
								t.equal(shared.move, legacy.move, "extraction preserves steering and throttle")
								t.equal(shared.rng.state, legacy.rng.state, "extraction preserves seeded decisions")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
