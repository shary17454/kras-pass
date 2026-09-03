class_name InputFrame
extends RefCounted
## One player's intent for one physics tick.
##
## This is the single currency of control in the whole game. A human pad, a
## keyboard profile, an AI brain, a replay file and (later) a network packet all
## produce the exact same struct, and `Fighter` cannot tell them apart. Every
## mini-game therefore works with bots, with local players and over the network
## without a line of per-source branching.

enum Btn { JUMP = 1, ACTION = 2, ATTACK = 4, DASH = 8, ABILITY = 16 }

## Analog movement intent in arena space, magnitude clamped to 1.
var move := Vector2.ZERO
## Secondary stick / aim intent. Falls back to `move` when a device has no
## second stick, so aim-using games stay playable on keyboard.
var aim := Vector2.ZERO
var bits := 0
var prev_bits := 0
## Set when the owning device vanished mid-match; the match layer pauses on it.
var disconnected := false


func held(b: Btn) -> bool:
	return (bits & b) != 0


func just_pressed(b: Btn) -> bool:
	return (bits & b) != 0 and (prev_bits & b) == 0


func just_released(b: Btn) -> bool:
	return (bits & b) == 0 and (prev_bits & b) != 0


func any_pressed() -> bool:
	return bits != 0 and prev_bits == 0


func effective_aim() -> Vector2:
	return aim if aim.length_squared() > 0.04 else move


func clear() -> void:
	prev_bits = bits
	move = Vector2.ZERO
	aim = Vector2.ZERO
	bits = 0


func copy_from(other: InputFrame) -> void:
	prev_bits = bits
	move = other.move
	aim = other.aim
	bits = other.bits
	disconnected = other.disconnected


## Compact form used by the replay recorder and the future network transport:
## 2 quantized axes pairs + a button byte fits in 5 bytes per player per tick.
## Nine bytes: two int16 axes per stick, then the button mask.
##
## The sticks used to be single bytes, which quantised every axis to 1/127 —
## about eight thousandths of a stick. That is invisible while a body is only
## being integrated, and it stops being invisible the moment bodies collide:
## an eight-thousandth difference decides whether two fighters touch at all,
## and a replay of a brawl drifted metres from the match it was recording. The
## extra four bytes per player per tick — roughly 240 bytes a second for four
## players — buy two orders of magnitude of stick precision.
const BYTES := 9


func encode() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(BYTES)
	out.encode_s16(0, int(round(clampf(move.x, -1.0, 1.0) * 32767.0)))
	out.encode_s16(2, int(round(clampf(move.y, -1.0, 1.0) * 32767.0)))
	out.encode_s16(4, int(round(clampf(aim.x, -1.0, 1.0) * 32767.0)))
	out.encode_s16(6, int(round(clampf(aim.y, -1.0, 1.0) * 32767.0)))
	out[8] = bits & 0xFF
	return out


func decode(data: PackedByteArray, offset: int = 0) -> void:
	prev_bits = bits
	move = Vector2(data.decode_s16(offset) / 32767.0, data.decode_s16(offset + 2) / 32767.0)
	aim = Vector2(data.decode_s16(offset + 4) / 32767.0, data.decode_s16(offset + 6) / 32767.0)
	bits = data[offset + 8]
