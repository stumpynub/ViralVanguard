extends Node
## Signaling checks against the live PeerJS relay (desktop: no WebRTC, so only the relay side is exercised).
func _ready() -> void:
	Net._busy = true
	print("open relay: ", await Net._open_relay())
	var room := "vv-%s-quick-1" % Net.VERSION
	print("claim room 1 (held by a web host?): ", await Net._claim(room))
	get_tree().quit()
