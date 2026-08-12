extends Screen
## Online lobby.
##
## The transport is not shipped in 1.0. Rather than showing four dead buttons,
## this screen runs the *real* lobby flow against `Net`'s local session backend:
## a room is created, it has a working code, participants ready up, and the
## start button builds a genuine MatchConfig. When a network transport is added,
## the only change here is that `Net.online_available` becomes true.

var _code_label: Label
var _peer_box: VBoxContainer
var _status: Label


func setup(a: Dictionary) -> void:
	super.setup(a)
	Net.session_state_changed.connect(_on_state)
	Net.peer_joined.connect(func(_p): _refresh_peers())
	Net.peer_ready_changed.connect(func(_i, _r): _refresh_peers())


func build() -> void:
	title(Loc.t("online.title"))
	var notice := UIKit.label(Loc.t("online.unavailable"), UIKit.SIZE_SMALL, UIKit.ACCENT)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(notice)

	var columns := UIKit.hbox(28)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var left := UIKit.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := UIKit.vbox(12)
	right.custom_minimum_size = Vector2(520, 0)
	columns.add_child(left)
	columns.add_child(right)

	var create := UIKit.button(Loc.t("online.create"))
	create.pressed.connect(_create_room)
	left.add_child(create)
	first_focus = create

	var join := UIKit.button(Loc.t("online.join"))
	join.disabled = not Net.online_available
	join.tooltip_text = Loc.t("common.soon")
	join.pressed.connect(func(): Net.join_online(""))
	left.add_child(join)

	var quick := UIKit.button(Loc.t("online.quick_match"))
	quick.disabled = not Net.online_available
	quick.tooltip_text = Loc.t("common.soon")
	left.add_child(quick)

	var invite := UIKit.button(Loc.t("online.friends"))
	invite.disabled = not Net.online_available
	invite.tooltip_text = Loc.t("common.soon")
	left.add_child(invite)

	_status = UIKit.label("", UIKit.SIZE_SMALL, UIKit.dim_color())
	left.add_child(_status)

	right.add_child(UIKit.heading(Loc.t("online.code")))
	_code_label = UIKit.label("—", UIKit.SIZE_TITLE, UIKit.ACCENT_2, true)
	right.add_child(_code_label)
	_peer_box = UIKit.vbox(8)
	right.add_child(_peer_box)

	var ready := UIKit.button(Loc.t("online.ready"))
	ready.pressed.connect(func():
		Net.set_ready(Net.local_peer_id, not bool(Net.peers.get(Net.local_peer_id, {}).get("ready", false))))
	right.add_child(ready)

	var start := UIKit.button(Loc.t("common.start"), UIKit.SIZE_HEADING)
	start.pressed.connect(_start_local_session)
	right.add_child(start)

	_refresh_peers()
	_on_state(int(Net.state))


func _create_room() -> void:
	Net.host_local(4)
	Net.add_local_participant("local.slot_ai")
	Net.add_local_participant("local.slot_ai")
	Net.add_local_participant("local.slot_ai")
	for id in Net.peers.keys():
		if id != Net.local_peer_id:
			Net.set_ready(id, true)
	_code_label.text = Net.room_code
	_refresh_peers()
	AudioManager.play_ui("ui_select")


func _refresh_peers() -> void:
	if _peer_box == null or not is_instance_valid(_peer_box):
		return
	for c in _peer_box.get_children():
		c.queue_free()
	if Net.peers.is_empty():
		_peer_box.add_child(UIKit.label(Loc.t("common.none"), UIKit.SIZE_SMALL, UIKit.dim_color()))
		return
	for p in Net.peers.values():
		var row := UIKit.panel(UIKit.PANEL, 10)
		var h := UIKit.hbox(12)
		row.add_child(h)
		var name := UIKit.label(Loc.t(String(p["name"])), UIKit.SIZE_SMALL)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name)
		h.add_child(UIKit.label(
			Loc.t("online.ready") if bool(p["ready"]) else Loc.t("online.not_ready"),
			UIKit.SIZE_SMALL, UIKit.OK if bool(p["ready"]) else UIKit.dim_color()))
		_peer_box.add_child(row)


func _on_state(state: int) -> void:
	if _status == null or not is_instance_valid(_status):
		return
	match state:
		Net.State.LOBBY:
			_status.text = "%s: %s" % [Loc.t("online.code"), Net.room_code]
		Net.State.OFFLINE:
			_status.text = Loc.t("common.none")
		_:
			_status.text = ""


## Runs the lobby's chosen setup through the ordinary local match path — the
## same code an online start would take once packets exist.
func _start_local_session() -> void:
	if Net.state != Net.State.LOBBY:
		AudioManager.play_ui("ui_error")
		EventBus.notify(Loc.t("online.create"))
		return
	var games := Progression.playable_games()
	if games.is_empty():
		return
	var def: MiniGameDef = games[randi() % games.size()]
	var cfg := MatchConfig.new()
	cfg.minigame_id = def.id
	cfg.arena_id = def.arena_ids[0] if def.arena_ids.size() > 0 else ""
	cfg.context = MatchConfig.Context.ONLINE
	cfg.rounds = def.default_rounds
	cfg.seed = randi() & 0x7FFFFFFF
	cfg.subtitle_key = "online.title"
	var pool := Progression.playable_characters()
	var i := 0
	for p in Net.peers.values():
		if i >= def.max_players:
			break
		var pc := PlayerConfig.new()
		pc.slot = i
		pc.character_id = pool[i % pool.size()].id
		pc.is_human = int(p["id"]) == Net.local_peer_id
		pc.ai_difficulty = PlayerConfig.Difficulty.MEDIUM
		pc.peer_id = int(p["id"])
		cfg.players.append(pc)
		i += 1
	Net.request_start(cfg)
	SceneRouter.start_match(cfg)


func teardown() -> void:
	Net.leave()
