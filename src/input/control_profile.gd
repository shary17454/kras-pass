class_name ControlProfile
extends RefCounted
## How a mini-game wants to be driven by touch.
##
## A profile chooses the *movement* widget and nothing else — the action buttons
## are derived from the game's declared `controls`, so a game never states its
## touch layout twice and never states it in code. Declared per game in
## `data/minigames.json` as `"control_profile": "steering"`.
##
## This is the whole reason all 21 games work on a phone without a single
## `if touch` inside any of them.

enum Kind {
	MOVEMENT_ACTION,  # stick + the game's action buttons — the default
	DUAL_ACTION,      # stick + a wider button cluster (4 verbs)
	STEERING,         # steer left/right + throttle, for DRIVE locomotion
	REACTION,         # no stick; the whole screen is one button
	MEMORY,           # stick only, enlarged; no action buttons
	AIM_AND_MOVE,     # move stick + aim stick
}

const NAMES := {
	Kind.MOVEMENT_ACTION: "movement_action",
	Kind.DUAL_ACTION: "dual_action",
	Kind.STEERING: "steering",
	Kind.REACTION: "reaction",
	Kind.MEMORY: "memory",
	Kind.AIM_AND_MOVE: "aim_and_move",
}

## Buttons a profile is willing to show, in the order they are laid out.
const BUTTON_ORDER := ["attack", "shoot", "action", "jump", "dash", "boost", "ability"]

## Which InputFrame bit each declared control maps to.
const BUTTON_BITS := {
	"jump": InputFrame.Btn.JUMP,
	"action": InputFrame.Btn.ACTION,
	"attack": InputFrame.Btn.ATTACK,
	"shoot": InputFrame.Btn.ATTACK,
	"dash": InputFrame.Btn.DASH,
	"boost": InputFrame.Btn.DASH,
	"ability": InputFrame.Btn.ABILITY,
}


static func from_string(s: String) -> Kind:
	for k in NAMES:
		if NAMES[k] == s:
			return k
	return Kind.MOVEMENT_ACTION


static func name_of(k: Kind) -> String:
	return NAMES.get(k, "movement_action")


static func shows_move_stick(k: Kind) -> bool:
	return k != Kind.REACTION and k != Kind.STEERING


static func shows_aim_stick(k: Kind) -> bool:
	return k == Kind.AIM_AND_MOVE


static func shows_steering(k: Kind) -> bool:
	return k == Kind.STEERING


## A reaction game turns the entire screen into one button, because asking a
## player to find a 90-pixel target is the opposite of a reflex test.
static func full_screen_tap(k: Kind) -> int:
	return InputFrame.Btn.ATTACK if k == Kind.REACTION else 0


static func stick_scale(k: Kind) -> float:
	return 1.25 if k == Kind.MEMORY else 1.0


## Buttons to draw, derived from what the game says it uses. Duplicate bits are
## collapsed, so a game declaring both "attack" and "shoot" gets one button.
static func buttons_for(k: Kind, control_hints: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	if k == Kind.REACTION or k == Kind.MEMORY:
		return out
	var seen_bits := {}
	var limit := 4 if k == Kind.DUAL_ACTION else 3
	for name in BUTTON_ORDER:
		if not control_hints.has(name):
			continue
		var bit: int = BUTTON_BITS[name]
		if seen_bits.has(bit):
			continue
		seen_bits[bit] = true
		out.append(name)
		if out.size() >= limit:
			break
	return out
