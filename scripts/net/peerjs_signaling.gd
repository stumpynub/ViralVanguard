class_name PeerJSSignaling
extends RefCounted
## Minimal client for a PeerJS signaling server (the free public one at 0.peerjs.com, or a self-hosted
## `npx peerjs --port 9000`). It only relays small JSON messages (WebRTC offers / answers / ICE candidates)
## between two ids; game traffic never touches it.

signal opened                       ## the server accepted our id
signal id_taken                     ## someone already holds the id we asked for (e.g. a room's host)
signal failed(reason: String)
signal message(type: String, src: String, payload: Dictionary)

var id := ""
var is_open := false

var _ws := WebSocketPeer.new()
var _url := ""
var _heartbeat := 0.0
var _closed := false


## server: e.g. "wss://0.peerjs.com:443/" (must end with "/"), key: the server key ("peerjs" for the cloud server)
func connect_as(peer_id: String, server: String, key := "peerjs") -> void:
	id = peer_id
	var token := "%x" % (randi() & 0xffffffff)
	_url = "%speerjs?key=%s&id=%s&token=%s&version=1.5.4" % [server, key, peer_id, token]
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 18
	is_open = false
	_closed = false
	var err := _ws.connect_to_url(_url)
	if err != OK:
		_closed = true
		failed.emit("cannot reach the matchmaking server (%s)" % error_string(err))


func send(type: String, dst: String, payload: Dictionary = {}) -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify({"type": type, "dst": dst, "payload": payload}))


func close() -> void:
	_closed = true
	is_open = false
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.close()


## Call every frame.
func poll(delta: float) -> void:
	if _closed:
		return
	_ws.poll()
	# read everything queued first: the server often sends a message (e.g. ID-TAKEN) and closes right after
	while _ws.get_available_packet_count() > 0 and not _closed:
		var txt := _ws.get_packet().get_string_from_utf8()
		var msg = JSON.parse_string(txt)
		if typeof(msg) != TYPE_DICTIONARY:
			continue
		var type: String = msg.get("type", "")
		match type:
			"OPEN":
				is_open = true
				opened.emit()
			"ID-TAKEN":
				_closed = true
				_ws.close()
				id_taken.emit()
				return
			"ERROR", "INVALID-KEY":
				failed.emit(str(msg.get("payload", {}).get("msg", type)))
			_:
				var payload = msg.get("payload", {})
				message.emit(type, str(msg.get("src", "")), payload if typeof(payload) == TYPE_DICTIONARY else {})
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		_closed = true
		if not is_open:
			failed.emit("matchmaking server closed the connection (%d)" % _ws.get_close_code())
		else:
			is_open = false
			failed.emit("lost the matchmaking server")
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	_heartbeat -= delta
	if _heartbeat <= 0.0:
		_heartbeat = 5.0
		_ws.send_text('{"type":"HEARTBEAT"}')
