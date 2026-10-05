class_name ReplayInputBuffer
extends RefCounted
## Fixed-stride inputs without one allocation/Array entry per simulation tick.

const CHUNK_TICKS := 3600
var _chunks: Array[PackedByteArray] = []
var _active := PackedByteArray()
var _stride := 0
var _count := 0


func append(packet: PackedByteArray) -> bool:
	if packet.is_empty() or (_stride != 0 and packet.size() != _stride):
		return false
	if _stride == 0:
		_stride = packet.size()
	_active.append_array(packet)
	_count += 1
	if _count % CHUNK_TICKS == 0:
		_chunks.append(_active)
		_active = PackedByteArray()
	return true


func packet_at(tick: int) -> PackedByteArray:
	if tick < 0 or tick >= _count:
		return PackedByteArray()
	var start := (tick % CHUNK_TICKS) * _stride
	var chunk := int(tick / CHUNK_TICKS)
	return _chunks[chunk].slice(start, start + _stride) if chunk < _chunks.size() else _active.slice(start, start + _stride)


func size() -> int:
	return _count


func byte_size() -> int:
	return _count * _stride


func is_empty() -> bool:
	return _count == 0


func clear() -> void:
	_chunks.clear()
	_active = PackedByteArray()
	_stride = 0
	_count = 0


func snapshot() -> ReplayInputBuffer:
	var copy := ReplayInputBuffer.new()
	copy._chunks.assign(_chunks)
	copy._active = _active.duplicate()
	copy._stride = _stride
	copy._count = _count
	return copy


func flatten() -> PackedByteArray:
	var flat := PackedByteArray()
	for chunk in _chunks:
		flat.append_array(chunk)
	flat.append_array(_active)
	return flat


func to_array() -> Array:
	var packets: Array = []
	for tick in _count:
		packets.append(packet_at(tick))
	return packets


static func from_flat(flat: PackedByteArray, stride: int) -> ReplayInputBuffer:
	var buffer := ReplayInputBuffer.new()
	if stride <= 0 or flat.size() % stride != 0:
		return buffer
	buffer._stride = stride
	buffer._count = int(flat.size() / stride)
	var chunk_bytes := CHUNK_TICKS * stride
	for start in range(0, flat.size(), chunk_bytes):
		var chunk := flat.slice(start, mini(start + chunk_bytes, flat.size()))
		if chunk.size() == chunk_bytes:
			buffer._chunks.append(chunk)
		else:
			buffer._active = chunk
	return buffer
