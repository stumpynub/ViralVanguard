extends Node
## Multiplayer sessions. Peer-to-peer over WebRTC (works in the itch.io web build with no game server):
## players find each other through a PeerJS signaling relay, then talk directly. The host (peer 1) runs the
## swarm; everyone else joins in progress. Desktop builds without WebRTC fall back to ENet (LAN / direct IP).
##
##   quick_play()        join any public match, or become a host others can join
##   host_private()      host with a 5-letter room code
##   join_code(code)     join a private room
##   host_lan() / join_ip(address)   ENet, for desktop / LAN testing
##   play_solo()         offline

signal status(text: String)
signal session_started(is_host: bool)
signal session_failed(reason: String)
signal session_ended(reason: String)
signal roster_changed

const VERSION := "vv1"                 ## bump when the network protocol changes (old clients can't join new hosts)
const MAX_PLAYERS := 8
const QUICK_ROOMS := 12
const ENET_PORT := 7777
## Signaling relay. The free PeerJS cloud server works out of the box; for a busy game run your own
## (`npx peerjs --port 9000`, or any host) and point this at it.
const SIGNAL_SERVER := "wss://0.peerjs.com:443/"
const SIGNAL_KEY := "peerjs"
const ICE_SERVERS := [
	{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]},
	{"urls": ["stun:global.stun.twilio.com:3478"]},
	# Add a TURN server here for players behind strict NATs, e.g.
	# {"urls": ["turn:turn.example.com:3478"], "username": "user", "credential": "pass"},
]

enum Mode { OFFLINE, HOST, CLIENT }

var mode := Mode.OFFLINE
## "coop" (the swarm, up to MAX_PLAYERS) or "duel" (1v1 sniper duel). Quick play keeps separate room pools;
## private duel codes start with D; whoever joins learns the host's mode in _welcome before deploying.
var game_mode := "coop"
var room := ""                 ## room code shown to players ("" for quick play / offline)
var players := {}              ## peer id -> {name, weapon, armor, skill}

var _sig: PeerJSSignaling
var _rtc: WebRTCMultiplayerPeer
var _pending := {}             ## signaling src -> {pc, gid}
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# everything the session does is echoed to the console (browser dev tools on itch) for troubleshooting
	status.connect(func(t): print("[Net] ", t))
	session_failed.connect(func(t): print("[Net] failed: ", t))
	session_started.connect(func(h): print("[Net] session started as ", "host" if h else "client", " room=", room))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(func(): _end("The host left the match."))


func _process(delta: float) -> void:
	if _sig:
		_sig.poll(delta)


func is_online() -> bool:
	return mode != Mode.OFFLINE


func is_host() -> bool:
	return mode != Mode.CLIENT


func webrtc_available() -> bool:
	if OS.has_feature("web"):
		return true
	var pc := WebRTCPeerConnection.new()
	return pc.initialize({}) == OK


func local_info() -> Dictionary:
	# the duel is a sniper duel: everyone carries the Nightfall
	return {"name": str(Game.settings.player_name), "weapon": "sniper" if game_mode == "duel" else Game.settings.weapon,
		"armor": Game.settings.armor, "skill": Game.settings.skill}


func player_name(id: int) -> String:
	return players.get(id, {}).get("name", "OPERATIVE")


# ------------------------------------------------------------------ session entry points
func play_solo() -> void:
	leave()
	players = {1: local_info()}
	session_started.emit(true)


func quick_play() -> void:
	if not _begin():
		return
	if not await _open_relay():
		return
	for n in range(1, QUICK_ROOMS + 1):
		var room_id := "vv-%s-%s-%d" % [VERSION, "quick" if game_mode == "coop" else "duel", n]
		status.emit("Looking for a match (room %d)…" % n)
		var r := await _join_via(room_id)
		if r == "ok":
			return
		if r == "version":
			_fail("That match runs a different version of the game. Refresh the page.")
			return
		if r == "empty":
			status.emit("Room %d is free: starting a match others can join…" % n)
			if await _claim(room_id):
				return
			# someone grabbed it at the same moment: try joining them instead
			if not await _open_relay():
				return
			if await _join_via(room_id) == "ok":
				return
	_fail("Every public room is full or unreachable. Try again in a minute, or host a private room.")


func host_private() -> void:
	if not _begin():
		return
	for attempt in 4:
		var code := "D" if game_mode == "duel" else ""
		while code.length() < 5:
			code += "ABCEFGHJKLMNPQRSTUVWXYZ23456789"[randi() % 31]      # no D: that marks duel rooms
		room = code
		if await _claim("vv-%s-room-%s" % [VERSION, code]):
			return
	_fail("Couldn't reach the matchmaking server. Check your connection.")


func join_code(code: String) -> void:
	code = code.strip_edges().to_upper()
	if code.length() < 4:
		session_failed.emit("Enter the room code your friend sees.")
		return
	if not _begin():
		return
	if not await _open_relay():
		return
	room = code
	game_mode = "duel" if code.begins_with("D") else "coop"
	status.emit("Joining room %s…" % code)
	match await _join_via("vv-%s-room-%s" % [VERSION, code]):
		"ok":
			return
		"version":
			_fail("That room runs a different version of the game. Refresh the page.")
		"full":
			_fail("Room %s is full." % code)
		"nat":
			_fail("Found room %s but couldn't connect directly (strict NAT / firewall)." % code)
		_:
			_fail("Room %s isn't running." % code)


func host_lan() -> void:
	leave()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(ENET_PORT, max_players())
	if err != OK:
		session_failed.emit("Couldn't open port %d (%s)." % [ENET_PORT, error_string(err)])
		return
	multiplayer.multiplayer_peer = p
	mode = Mode.HOST
	room = "LAN %d" % ENET_PORT
	players = {1: local_info()}
	session_started.emit(true)


func join_ip(address: String) -> void:
	leave()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(address.strip_edges() if address.strip_edges() != "" else "127.0.0.1", ENET_PORT)
	if err != OK:
		session_failed.emit("Couldn't connect (%s)." % error_string(err))
		return
	multiplayer.multiplayer_peer = p
	mode = Mode.CLIENT
	status.emit("Connecting to %s…" % address)
	var ok := await _wait_connected(10.0)
	if not ok:
		_fail("No host answered at %s." % address)
		return
	_client_connected()


func leave() -> void:
	if _sig:
		_sig.close()
		_sig = null
	for src in _pending:
		_pending[src].pc.close()
	_pending.clear()
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_rtc = null
	mode = Mode.OFFLINE
	room = ""
	players = {}
	_busy = false


# ------------------------------------------------------------------ WebRTC + PeerJS
func _begin() -> bool:
	if _busy:
		return false
	leave()
	if not webrtc_available():
		session_failed.emit("Online play needs the web build (or the WebRTC extension on desktop). Use Host LAN / Join IP here.")
		return false
	_busy = true
	return true


func _fail(reason: String) -> void:
	leave()
	session_failed.emit(reason)


func _ice() -> Dictionary:
	return {"iceServers": ICE_SERVERS}


# The public PeerJS server only relays offers / answers in PeerJS's own message format (sdp as {type, sdp},
# a connectionId, type "data"); anything else gets the sender disconnected. Candidates are relayed freely,
# so rejections ("room full", "old version") travel as a tagged candidate.
static func _desc(kind: String, sdp: String, conn: String, meta := {}) -> Dictionary:
	var d := {"sdp": {"type": kind, "sdp": sdp}, "type": "data", "connectionId": conn}
	if kind == "offer":
		d.merge({"label": conn, "reliable": true, "serialization": "binary", "browser": "godot", "metadata": meta})
	return d


static func _cand(mid: String, idx: int, cand: String, conn: String) -> Dictionary:
	return {"candidate": {"candidate": cand, "sdpMid": mid, "sdpMLineIndex": idx}, "type": "data", "connectionId": conn}


## Connect to the relay under a throwaway id (used to send offers). False (and the session fails) if unreachable.
func _open_relay() -> bool:
	if _sig:
		_sig.close()
	_sig = PeerJSSignaling.new()
	_sig.connect_as("vv-%s-p-%x" % [VERSION, randi()], SIGNAL_SERVER, SIGNAL_KEY)
	if await _first([_sig.opened, "ok"], [_sig.failed, "fail"], 10.0) != "ok":
		_fail("Couldn't reach the matchmaking server. Check your connection.")
		return false
	return true


## Take `room_id` on the relay and host there. False if the id is already held (or the relay dropped us).
## (The relay closes the socket right after ID-TAKEN, and Godot's WebSocket loses that last message, so a
## refusal and a network error look the same here; callers decide what to try next.)
func _claim(room_id: String) -> bool:
	if _sig:
		_sig.close()
	_sig = PeerJSSignaling.new()
	_sig.connect_as(room_id, SIGNAL_SERVER, SIGNAL_KEY)
	if await _first([_sig.opened, "ok"], [_sig.id_taken, "taken"], [_sig.failed, "fail"], 8.0) != "ok":
		_sig = null
		return false
	_rtc = WebRTCMultiplayerPeer.new()
	_rtc.create_server()
	multiplayer.multiplayer_peer = _rtc
	_sig.message.connect(_host_signal)
	_sig.failed.connect(func(_r): status.emit("Matchmaking relay dropped: new players can't join, current ones stay connected."))
	mode = Mode.HOST
	players = {1: local_info()}
	_busy = false
	session_started.emit(true)
	return true


## Offer to join the host of `room_id` through the open relay connection.
## "ok" (connected), "empty" (nobody answered), "full", "version" or "nat" (answered, but no direct link).
func _join_via(room_id: String) -> String:
	var gid := randi_range(2, 0x7ffffff0)
	_rtc = WebRTCMultiplayerPeer.new()
	_rtc.create_client(gid)
	multiplayer.multiplayer_peer = _rtc
	var pc := WebRTCPeerConnection.new()
	pc.initialize(_ice())
	var conn := "dc_%x" % randi()
	var sig := _sig
	pc.session_description_created.connect(func(type: String, sdp: String):
		pc.set_local_description(type, sdp)
		sig.send("OFFER", room_id, _desc("offer", sdp, conn, {"gid": gid, "ver": VERSION})))
	pc.ice_candidate_created.connect(func(mid: String, idx: int, cand: String):
		sig.send("CANDIDATE", room_id, _cand(mid, idx, cand, conn)))
	_rtc.add_peer(pc, 1)
	var answered := [""]
	var on_msg := func(type: String, src: String, p: Dictionary):
		if src != room_id:
			return
		if type == "ANSWER":
			answered[0] = "ok"
			pc.set_remote_description("answer", str(p.get("sdp", {}).get("sdp", "")))
		elif type == "CANDIDATE":
			var c: Dictionary = p.get("candidate", {})
			var text := str(c.get("candidate", ""))
			if text.begins_with("reject:"):
				answered[0] = text.substr(7)
			else:
				pc.add_ice_candidate(str(c.get("sdpMid", "0")), int(c.get("sdpMLineIndex", 0)), text)
		elif type == "EXPIRE":
			answered[0] = "empty"
	sig.message.connect(on_msg)
	pc.create_offer()
	var t := 0.0
	while answered[0] == "" and t < 4.5:
		await get_tree().process_frame
		t += get_process_delta_time()
	var r: String = answered[0] if answered[0] != "" else "empty"
	print("[Net] ", room_id, ": ", r)
	if r == "ok":
		status.emit("Connecting peer-to-peer…")
		if await _wait_connected(15.0):
			sig.message.disconnect(on_msg)
			sig.close()
			_sig = null
			mode = Mode.CLIENT
			_busy = false
			_client_connected()
			return "ok"
		r = "nat"
	if sig.message.is_connected(on_msg):
		sig.message.disconnect(on_msg)
	pc.close()
	_rtc.close()
	_rtc = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	return r


func _reset_transport() -> void:
	if _sig:
		_sig.close()
		_sig = null
	if _rtc:
		_rtc.close()
		_rtc = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


## Host side of signaling: a joiner sent an offer.
func _host_signal(type: String, src: String, p: Dictionary) -> void:
	var conn := str(p.get("connectionId", ""))
	if type == "OFFER":
		print("[Net] offer from ", src)
		var meta: Dictionary = p.get("metadata", {})
		if meta.get("ver", "") != VERSION:
			_sig.send("CANDIDATE", src, _cand("0", 0, "reject:version", conn))
			return
		if players.size() + _pending.size() >= max_players():
			_sig.send("CANDIDATE", src, _cand("0", 0, "reject:full", conn))
			return
		var gid := int(meta.get("gid", 0))
		var pc := WebRTCPeerConnection.new()
		pc.initialize(_ice())
		pc.session_description_created.connect(func(t: String, sdp: String):
			pc.set_local_description(t, sdp)
			_sig.send("ANSWER", src, _desc(t, sdp, conn)))
		pc.ice_candidate_created.connect(func(mid: String, idx: int, cand: String):
			_sig.send("CANDIDATE", src, _cand(mid, idx, cand, conn)))
		_rtc.add_peer(pc, gid)
		_pending[src] = {"pc": pc, "gid": gid}
		pc.set_remote_description("offer", str(p.get("sdp", {}).get("sdp", "")))
		get_tree().create_timer(20.0).timeout.connect(func(): _pending.erase(src))
	elif type == "CANDIDATE" and _pending.has(src):
		var c: Dictionary = p.get("candidate", {})
		_pending[src].pc.add_ice_candidate(str(c.get("sdpMid", "0")), int(c.get("sdpMLineIndex", 0)), str(c.get("candidate", "")))


func _wait_connected(timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and multiplayer.get_peers().has(1):
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


## Await whichever of several signals fires first. Each arg is [Signal, result]; the last arg is a timeout.
func _first(a: Array, b: Array, c = null, d = null) -> String:
	var opts: Array = [a, b]
	var timeout := 10.0
	for x in [c, d]:
		if x is Array:
			opts.append(x)
		elif x != null:
			timeout = float(x)
	var res := [""]
	var cbs := []
	for o in opts:
		var cb := func(_a = null, _b = null, _c = null): if res[0] == "": res[0] = o[1]
		o[0].connect(cb)
		cbs.append([o[0], cb])
	var t := 0.0
	while res[0] == "" and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	for pair in cbs:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	return res[0] if res[0] != "" else "timeout"


# ------------------------------------------------------------------ roster
func _client_connected() -> void:
	players = {}
	_register.rpc_id(1, local_info())       # the host answers with _welcome (its game mode), then we deploy


## Host -> a new client: which game this session plays. The client deploys only after this.
@rpc("authority", "call_remote", "reliable")
func _welcome(m: String) -> void:
	game_mode = m
	session_started.emit(false)


func max_players() -> int:
	return 2 if game_mode == "duel" else MAX_PLAYERS


## Client -> host: who I am and what I'm carrying.
@rpc("any_peer", "reliable")
func _register(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var n := str(info.get("name", "OPERATIVE")).left(16)
	info["name"] = n if n.strip_edges() != "" else "OPERATIVE"
	if game_mode == "duel" and players.size() >= 2 and not players.has(id):
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var fresh := not players.has(id)
	players[id] = info
	if fresh:
		_welcome.rpc_id(id, game_mode)
	for src in _pending.keys():
		if _pending[src].gid == id:
			_pending.erase(src)
	_roster.rpc(players)
	roster_changed.emit()


## Host -> everyone: the full player list.
@rpc("authority", "call_remote", "reliable")
func _roster(list: Dictionary) -> void:
	players = list
	roster_changed.emit()


## Anyone -> host: my loadout changed (e.g. weapon swap); host re-broadcasts.
func update_local_info() -> void:
	if mode == Mode.CLIENT:
		_register.rpc_id(1, local_info())
	elif players.has(1):
		players[1] = local_info()
		if mode == Mode.HOST:
			_roster.rpc(players)
		roster_changed.emit()


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if players.erase(id) and multiplayer.is_server():
		_roster.rpc(players)
		roster_changed.emit()


func _end(reason: String) -> void:
	leave()
	session_ended.emit(reason)
