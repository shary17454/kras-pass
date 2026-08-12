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
func encode() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(5)
	out[0] = int(clampf(move.x, -1.0, 1.0) * 127.0) + 128
	out[1] = int(clampf(move.y, -1.0, 1.0) * 127.0) + 128
	out[2] = int(clampf(aim.x, -1.0, 1.0) * 127.0) + 128
	out[3] = int(clampf(aim.y, -1.0, 1.0) * 127.0) + 128
	out[4] = bits & 0xFF
	return out


func decode(data: PackedByteArray, offset: int = 0) -> void:
	prev_bits = bits
	move = Vector2((data[offset] - 128) / 127.0, (data[offset + 1] - 128) / 127.0)
	aim = Vector2((data[offset + 2] - 128) / 127.0, (data[offset + 3] - 128) / 127.0)
	bits = data[offset + 4]
