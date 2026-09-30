extends Node
## JSON-only transport. Never decode remote objects/resources or execute RPC names.
signal message_received(message: Dictionary)
signal transport_lost(reason: String)

var socket: WebSocketPeer
var endpoint := ""
var _pending: Dictionary = {}
var _started := 0
var _opened := false


func connect_room(url: String, first: Dictionary) -> Error:
	close()
	# Plaintext is only permitted on loopback for automated tests/development.
	if not url.begins_with("wss://") and not url.begins_with("ws://127.0.0.1:") and not url.begins_with("ws://localhost:"):
		return ERR_INVALID_PARAMETER
	endpoint = url
	_pending = first.duplicate(true)
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 131072
	socket.outbound_buffer_size = 131072
	socket.max_queued_packets = 256
	_started = Time.get_ticks_msec()
	return socket.connect_to_url(url)


func send(message: Dictionary) -> bool:
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	var packet := message.duplicate(true)
	packet["v"] = 1
	return socket.send_text(JSON.stringify(packet)) == OK


func _process(_delta: float) -> void:
	if socket == null:
		return
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_opened = true
		var packets := 0
		while socket.get_available_packet_count() > 0 and packets < 90:
			packets += 1
			var bytes := socket.get_packet()
			if not socket.was_string_packet() or bytes.size() > 65536:
				close()
				transport_lost.emit("invalid_packet")
				return
			var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			if not parsed is Dictionary:
				continue
			if parsed.get("op") == "hello":
				if int(parsed.get("v", 0)) != 1:
					close()
					transport_lost.emit("protocol_mismatch")
					return
				if not _pending.is_empty():
					send(_pending)
					_pending.clear()
			message_received.emit(parsed)
			if socket == null:
				return
	elif socket.get_ready_state() == WebSocketPeer.STATE_CLOSED or (not _opened and Time.get_ticks_msec() - _started > 10000):
		var reason := "socket_%d" % socket.get_close_code() if _opened else "connect_timeout"
		close()
		transport_lost.emit(reason)


func close() -> void:
	if socket != null:
		socket.close()
	socket = null
	_opened = false
	_pending.clear()
