extends Node
## Apple identity is verified by the server. Sessions live only in iOS Keychain.
signal changed

const ENDPOINT := "https://kras-pass-production.up.railway.app"
var busy := false
var signed_in := false
var status_key := ""
var _bridge: RefCounted
var _token := ""
var _all_games := false
var _expires := 0
var _generation := 0
var _pending_profile := ""
var _pending_generation := -1
var _challenge := ""
var _deleting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "iOS" and ClassDB.class_exists("KrasAppleBridge"):
		_bridge = ClassDB.instantiate("KrasAppleBridge")
		_bridge.connect("identity_received", _identity_received)
	SaveSystem.active_profile_changed.connect(func(_id): _profile_changed())
	_profile_changed()


func available() -> bool:
	return _bridge != null


func has_all_games() -> bool:
	return signed_in and _all_games and Time.get_unix_time_from_system() < _expires


func _profile_changed() -> void:
	_generation += 1
	_token = ""
	signed_in = false
	_all_games = false
	_expires = 0
	status_key = ""
	changed.emit()
	if available():
		_token = _bridge.call("load_session", SaveSystem.active_profile_id())
		if not _token.is_empty():
			refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_node_ready() and not busy and not _token.is_empty():
		refresh()


func refresh() -> void:
	var generation := _generation
	var token := _token
	var result := await _request("/account", HTTPClient.METHOD_GET, {}, token)
	if generation != _generation or token != _token:
		return
	_apply_access(result.get("data", {}) if result.get("code", 0) == 200 else {})
	if result.get("code", 0) == 401:
		_clear_local()
	changed.emit()


func sign_in() -> void:
	_begin(false)


func delete_account() -> void:
	if signed_in:
		_begin(true)


func _begin(deleting: bool) -> void:
	if not available() or busy:
		return
	busy = true
	status_key = "account.connecting"
	_pending_profile = SaveSystem.active_profile_id()
	_pending_generation = _generation
	_deleting = deleting
	changed.emit()
	var result := await _request("/auth/apple/challenge", HTTPClient.METHOD_POST)
	if _pending_generation != _generation:
		_finish("")
		return
	var data: Dictionary = result.get("data", {})
	if result.get("code", 0) != 200 or String(data.get("nonce", "")).length() != 43:
		_finish("account.unavailable" if result.get("code", 0) == 503 else "account.failed")
		return
	_challenge = String(data.get("id", ""))
	_bridge.call("sign_in", String(data["nonce"]))


func _identity_received(identity: String, code: String, error: String) -> void:
	if not busy:
		return
	if _pending_generation != _generation or _pending_profile != SaveSystem.active_profile_id():
		_finish("")
		return
	if not error.is_empty() or identity.is_empty():
		_finish("" if error == "cancelled" else "account.failed")
		return
	var generation := _generation
	var result := await _request("/account" if _deleting else "/auth/apple/exchange",
		HTTPClient.METHOD_DELETE if _deleting else HTTPClient.METHOD_POST,
		{"challenge": _challenge, "identity_token": identity, "authorization_code": code},
		_token if _deleting else "")
	if generation != _generation:
		# A request that finished after a profile switch must never grant access.
		var discarded := String(result.get("data", {}).get("token", ""))
		if not discarded.is_empty():
			_request("/auth/logout", HTTPClient.METHOD_POST, {}, discarded)
		_finish("")
		return
	if result.get("code", 0) != 200:
		_finish("account.failed")
		return
	if _deleting:
		_clear_local()
		_finish("account.deleted")
		return
	var data: Dictionary = result.get("data", {})
	var session := String(data.get("token", ""))
	if session.length() != 43 or not _bridge.call("save_session", _pending_profile, session):
		if not session.is_empty():
			_request("/auth/logout", HTTPClient.METHOD_POST, {}, session)
		_finish("account.failed")
		return
	_token = session
	_apply_access(data)
	_finish("account.connected")


func sign_out() -> void:
	if busy:
		return
	var token := _token
	_clear_local()
	status_key = ""
	changed.emit()
	if not token.is_empty():
		_request("/auth/logout", HTTPClient.METHOD_POST, {}, token)


func _clear_local() -> void:
	_generation += 1
	_token = ""
	signed_in = false
	_all_games = false
	_expires = 0
	if available():
		_bridge.call("clear_session", SaveSystem.active_profile_id())


func _apply_access(data: Dictionary) -> void:
	_expires = int(data.get("expires", 0))
	signed_in = not String(data.get("subject", "")).is_empty() and _expires > Time.get_unix_time_from_system()
	_all_games = signed_in and data.get("all_games", false) == true


func _finish(message: String) -> void:
	busy = false
	_challenge = ""
	status_key = message
	changed.emit()


func _request(path: String, method: int, payload: Dictionary = {}, token := "") -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 30.0
	http.body_size_limit = 16384
	http.max_redirects = 0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var started := http.request(ENDPOINT + path, headers, method,
		"" if method == HTTPClient.METHOD_GET else JSON.stringify(payload))
	if started != OK:
		http.queue_free()
		return {}
	var response: Array = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {}
	var parsed = JSON.parse_string(response[3].get_string_from_utf8())
	return {"code": response[1], "data": parsed if parsed is Dictionary else {}}
