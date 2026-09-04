class_name CharacterRig
extends RefCounted
## Procedural animation for a body that has no skeleton.
##
## The spec asks for standing, walking, running, sliding, jumping, attacking,
## taking a hit, spinning, falling and reacting — and these characters are
## generated primitives, so there is nothing to import and nothing to rig. What
## there is: two arm hinges, two leg hinges, two eyes and a mouth, all named by
## `MeshFactory.character_body()`.
##
## That turns out to be enough, because a cartoon walk has never needed more
## than a counter-swing and a bounce. Everything here is driven from state the
## fighter already computes — speed, whether it is on the floor, whether it is
## swinging, how close the edge is — so no animation state machine exists to
## fall out of sync with the physics.
##
## Cost is four rotations and three scales per body per frame, and the whole
## thing is skipped when the nodes are absent (karts, mounts, headless).

const IDLE_RATE := 3.4
const WALK_RATE := 15.0

var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _eye_l: Node3D
var _eye_r: Node3D
var _mouth: Node3D
var _phase := 0.0
var _bound := false


## Find the parts in a freshly built visual. Returns false when this body has
## none — a kart, for instance — so the caller can stop asking.
func bind(visual: Node3D) -> bool:
	_arm_l = _find(visual, "ArmL")
	_arm_r = _find(visual, "ArmR")
	_leg_l = _find(visual, "LegL")
	_leg_r = _find(visual, "LegR")
	_eye_l = _find(visual, "EyeL")
	_eye_r = _find(visual, "EyeR")
	_mouth = _find(visual, "Mouth")
	_bound = _arm_l != null and _leg_l != null
	return _bound


func is_bound() -> bool:
	return _bound


## `state` carries what the fighter already knows about itself:
##   speed, on_floor, attacking, dashing, hurt, frozen, panic
func tick(delta: float, state: Dictionary) -> void:
	if not _bound:
		return
	var speed: float = clampf(float(state.get("speed", 0.0)), 0.0, 1.4)
	var on_floor: bool = bool(state.get("on_floor", true))
	var frozen: bool = bool(state.get("frozen", false))
	var hurt: float = float(state.get("hurt", 0.0))
	var panic: float = float(state.get("panic", 0.0))

	if frozen:
		# Stiff, wide-eyed and silent. Nothing swings while a body is iced.
		_set_limbs(0.0, 0.0, 0.0)
		_set_face(1.15, 0.6)
		return

	# The cycle runs faster the faster the body travels, so walking and running
	# are the same animation at two speeds rather than two animations.
	_phase += delta * lerpf(IDLE_RATE, WALK_RATE, speed)
	var swing := sin(_phase) * lerpf(0.06, 0.85, speed)
	var lift := absf(cos(_phase)) * lerpf(0.0, 0.12, speed)

	if not on_floor:
		# Airborne: legs tuck, arms come up. This is also what a fighter looks
		# like on the way off the rim, which is exactly the read we want.
		_set_limbs(0.55, -1.5, 0.0)
		_set_face(1.35, 1.5)
		return

	if hurt > 0.0:
		# Flail: arms out sideways, eyes screwed shut, mouth open.
		var flail := sin(_phase * 5.0) * 1.1
		_apply(_arm_l, -1.1, flail)
		_apply(_arm_r, -1.1, -flail)
		_apply(_leg_l, swing * 0.4, 0.0)
		_apply(_leg_r, -swing * 0.4, 0.0)
		_set_face(0.25, 1.8)
		return

	if bool(state.get("attacking", false)):
		# One arm through the swing, the other counterweighting it.
		_apply(_arm_r, -2.1, 0.0)
		_apply(_arm_l, 0.9, 0.0)
		_apply(_leg_l, 0.25, 0.0)
		_apply(_leg_r, -0.25, 0.0)
		_set_face(1.1, 1.3)
		return

	if bool(state.get("dashing", false)):
		# Both arms back, legs trailing: a body committed to going forward.
		_apply(_arm_l, 1.5, 0.2)
		_apply(_arm_r, 1.5, -0.2)
		_apply(_leg_l, -0.5, 0.0)
		_apply(_leg_r, -0.2, 0.0)
		_set_face(1.25, 0.8)
		return

	_apply(_leg_l, swing, 0.0)
	_apply(_leg_r, -swing, 0.0)
	_apply(_arm_l, -swing * 0.75, 0.0)
	_apply(_arm_r, swing * 0.75, 0.0)
	if _leg_l != null:
		_leg_l.position.y += 0.0   # hinges stay put; the lift is in the swing
	# Panic near the rim widens the eyes and opens the mouth well before the
	# player is actually pushed — a warning that costs no HUD space.
	_set_face(lerpf(1.0, 1.5, panic), lerpf(0.9, 1.7, panic) + lift)


func _apply(hinge: Node3D, pitch: float, roll: float) -> void:
	if hinge == null or not is_instance_valid(hinge):
		return
	hinge.rotation.x = pitch
	hinge.rotation.z = roll


func _set_limbs(legs: float, arms: float, roll: float) -> void:
	_apply(_leg_l, legs, roll)
	_apply(_leg_r, legs * 0.6, -roll)
	_apply(_arm_l, arms, roll)
	_apply(_arm_r, arms, -roll)


## Eyes scale up to widen, down to squint; the mouth stretches vertically to
## open. Two numbers cover every expression this art style can carry.
func _set_face(eyes: float, mouth: float) -> void:
	if _eye_l != null and is_instance_valid(_eye_l):
		_eye_l.scale = Vector3(1.0, clampf(eyes, 0.15, 1.8), 1.0)
	if _eye_r != null and is_instance_valid(_eye_r):
		_eye_r.scale = Vector3(1.0, clampf(eyes, 0.15, 1.8), 1.0)
	if _mouth != null and is_instance_valid(_mouth):
		_mouth.scale = Vector3(clampf(1.0 + (mouth - 1.0) * 0.35, 0.6, 1.6),
			clampf(mouth, 0.4, 2.2), 1.0)


static func _find(node: Node, name: String) -> Node3D:
	if node == null:
		return null
	var found := node.find_child(name, true, false)
	return found as Node3D
