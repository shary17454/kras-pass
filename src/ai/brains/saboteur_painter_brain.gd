extends "res://src/ai/brains/painter_brain.gd"
## Mukharrib: paint, but never paint into the drone's shadow.
##
## One extra read on top of the painter: while a patch is marked, painting it is
## wasted effort and standing on it is a shove. High tiers steer clear and spend
## those seconds elsewhere; low tiers keep colouring squares that are about to
## be scrubbed, which is exactly the mistake a new player makes.

const AVOID_RADIUS := 3.4


func decide(delta: float) -> void:
	if controller != null and controller.has_method("scrub_target"):
		var mark: Vector3 = controller.call("scrub_target")
		var me := self_body()
		if mark != Vector3.INF and me != null and rng.randf() < edge_awareness:
			if me.global_position.distance_to(mark) < AVOID_RADIUS:
				steer_away(mark, 1.0)
				maybe_dash(0.7)
				return
	super.decide(delta)
