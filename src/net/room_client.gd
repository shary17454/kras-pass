extends Node
## JSON-only transport. Never decode remote objects/resources or execute RPC names.
signal message_received(message: Dictionary)
signal transport_lost(reason: String)

const PROTOCOL_VERSION := 2

var socket: WebSocketPeer
var endpoint := ""
var _pending: Dictionary = {}
var _started := 0
var _opened := false


func connect_room(url: String, first: Dictionary) -> Error:
	close()
	# Plaintext is only permitted on loopback for automated tests/development.
	if not allowed_endpoint(url):
		return ERR_INVALID_PARAMETER
	endpoint = url
	_pending = first.duplicate(true)
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 131072
	socket.outbound_buffer_size = 131072
	socket.max_queued_packets = 256
	_started = Time.get_ticks_msec()
	return socket.connect_to_url(url)


static func allowed_endpoint(url: String) -> bool:
	if url.begins_with("wss://"):
		return true
	if not url.begins_with("ws://"):
		return false
	# Validate the complete authority: a loopback-looking username is not a host.
	var authority := url.substr(5).get_slice("/", 0).get_slice("?", 0).get_slice("#", 0)
	var parts := authority.split(":")
	if parts.size() != 2 or parts[0] not in ["127.0.0.1", "localhost"]:
		return false
	var port := parts[1]
	if port.is_empty() or port.length() > 5:
		return false
	for i in port.length():
		if port.unicode_at(i) < 48 or port.unicode_at(i) > 57:
			return false
	return port.to_int() >= 1 and port.to_int() <= 65535


func send(message: Dictionary) -> bool:
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	var packet := message.duplicate(true)
	packet["v"] = PROTOCOL_VERSION
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
				if not compatible_hello(parsed):
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


static func compatible_hello(message: Dictionary) -> bool:
	var version: Variant = message.get("v")
	return message.get("op") == "hello" and (version is int or version is float) \
		and version == PROTOCOL_VERSION


func close() -> void:
	if socket != null:
		socket.close()
	socket = null
	_opened = false
	_pending.clear()
