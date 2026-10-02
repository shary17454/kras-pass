extends RefCounted
const Plan = preload("res://src/ai/forge_feeding_plan.gd")

func run(t: TestHarness) -> void:
	t.suite("forge visible feeding geometry")
	var center := Vector3(20, 0, -10)
	var point := center + Vector3(5, 0.7, 0)
	var plan := Plan.build(center + Vector3(3, 0, 0), center, 13, [point], [])
	t.ok(plan.hot, "hot slag preferred")
	t.ok(not plan.attack, "cannot push slag outward from the inside")
	t.ok(plan.target.is_equal_approx(point + Vector3(0.9, 0, 0)), "approach opposite intake")
	plan = Plan.build(center + Vector3(6, 0, 0), center, 13, [point], [])
	t.ok(plan.attack, "aligned close fighter may feed")
	plan = Plan.build(center + Vector3(5, 0, 1), center, 13, [point], [])
	t.ok(not plan.attack, "sideways blow would miss intake")
	plan = Plan.build(center + Vector3(8, 0, 0), center, 13, [point], [])
	t.ok(not plan.attack, "must reach slag before attacking")
	plan = Plan.build(center, center, 13, [center + Vector3(25, 0, 0)], [point])
	t.ok(not plan.hot, "lost slag does not trap bots at wall")
	t.ok(plan.target.is_equal_approx(point + Vector3(1.5, 0, 0)), "crate also approached from outside")
	t.empty(Plan.build(center, center, 13, [], []), "no imaginary targets")
	t.empty(Plan.build(center, center, 13, [center], []), "zero radial vector handled safely")
	for angle in 16:
		var outward := Vector3(cos(float(angle) * TAU / 16), 0, sin(float(angle) * TAU / 16))
		point = center + outward * 5
		plan = Plan.build(center + outward * 6, center, 13, [point], [])
		t.ok(plan.attack, "feeding works at every visible angle")
		var direction: Vector3 = point - (center + outward * 6)
		t.ok(direction.normalized().dot((center - point).normalized()) > 0.99, "shove points inward")
