extends RefCounted

const Pilot = preload("res://tests/tank_smoke_pilot.gd")


func run(t: TestHarness, _host: Node) -> void:
	t.suite("tank smoke pilot pursuit")
	var center := Vector3.ZERO
	var rival := Vector3(0.0, 0.02, 27.0)
	for clear in [false, true]:
		for origin in [Vector3.ZERO, Vector3(0.0, 0.02, -28.52)]:
			t.equal(Pilot.approach(origin, rival, center, clear), rival,
				"distant rivals remain the route destination, clear=%s" % clear)
	t.equal(Pilot.throttle(27.0, 1.0, true), 1.0, "pursuit continues outside firing range")
	t.equal(Pilot.throttle(8.0, 1.0, true), 0.0, "aligned close engagement stops driving")
	t.ok(not Pilot.can_fire(Vector3.ZERO, rival, Vector3.FORWARD, true),
		"pursuit does not relax firing range")
	t.ok(not Pilot.can_fire(Vector3.ZERO, Vector3(0, 0, 8), Vector3.BACK, false),
		"cover still prevents firing")
	t.ok(Pilot.can_fire(Vector3.ZERO, Vector3(0, 0, 8), Vector3.BACK, true),
		"clear aligned close target can be hit")
	t.ok(not Pilot.can_fire(Vector3.ZERO, Vector3(2, 0, 8), Vector3.BACK, true),
		"narrow chassis alignment is retained")
