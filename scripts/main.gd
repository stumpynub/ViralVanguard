extends Node
## Top-level flow: hangar -> (solo or online session) -> match -> pause / game over -> back to the hangar.
## Online sessions come from the Net autoload; this node only reacts to them.

@export var arena_scene: PackedScene = preload("res://scenes/world/arena.tscn")
## The 1v1 sniper duel (Net.game_mode == "duel").
@export var duel_scene: PackedScene = preload("res://scenes/world/arena_duel.tscn")
@export var hangar: Control
@export var hangar_layer: CanvasLayer
@export var hud: CanvasLayer
@export var pause_menu: CanvasLayer
@export var end_screen: CanvasLayer
@export var end_stats: Label
@export var world: Node
@export var cinematic: DeployCinematic
## Play the district fly-through on every deploy (skippable).
@export var play_cinematic := true
## Auto-pause when the window loses focus (tests turn this off; never pauses an online match).
@export var pause_on_focus_loss := true

var arena: Arena


func _ready() -> void:
	if end_stats == null:
		end_stats = end_screen.get_node("%EndStats")
	hangar.deploy_requested.connect(func(): Net.play_solo())
	Net.session_started.connect(func(_host): deploy())
	Net.session_failed.connect(func(reason): hangar.show_status(reason, true))
	Net.session_ended.connect(func(reason):
		to_hangar()
		hangar.show_status(reason, true))
	pause_menu.get_node("%Resume").pressed.connect(resume)
	pause_menu.get_node("%PauseHangar").pressed.connect(leave_match)
	end_screen.get_node("%Redeploy").pressed.connect(redeploy)
	end_screen.get_node("%EndHangar").pressed.connect(leave_match)
	to_hangar()
	_url_options.call_deferred()


## Web build URL options (handy for testing and self-hosted invite links):
##   ?quick=1     start Quick Play right away
##   ?room=ABCDE  join that private room
##   ?name=ACE    callsign
func _url_options() -> void:
	if not OS.has_feature("web"):
		return
	var q = JavaScriptBridge.eval("window.location.search", true)
	if typeof(q) != TYPE_STRING or q == "":
		return
	var opts := {}
	for part in String(q).trim_prefix("?").split("&", false):
		var kv := part.split("=")
		opts[kv[0]] = kv[1].uri_decode() if kv.size() > 1 else "1"
	if opts.has("name"):
		Game.settings.player_name = str(opts.name).to_upper().left(16)
	if opts.has("room"):
		Net.join_code(str(opts.room))
	elif opts.has("quick"):
		Net.quick_play()


func _unhandled_input(event: InputEvent) -> void:
	if arena == null:
		return
	if event.is_action_pressed("pause"):
		if pause_menu.visible:
			resume()
		elif arena.running:
			pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_on_focus_loss and arena and arena.running and not pause_menu.visible and not Net.is_online():
		pause()


func deploy() -> void:
	_clear_arena()
	get_tree().paused = false
	arena = (duel_scene if Net.game_mode == "duel" else arena_scene).instantiate()
	arena.name = "Arena"            # same node path on every peer, so RPCs line up
	world.add_child(arena)
	arena.start_match()
	arena.game_over.connect(_on_game_over)
	hud.bind(arena)
	hangar_layer.visible = false
	end_screen.visible = false
	pause_menu.visible = false
	hud.visible = true
	Sfx.music("game")
	if play_cinematic and cinematic:
		hud.visible = false
		arena.player.inv_t = 999.0
		var swarm: Node3D = arena.get_node("Enemies")
		swarm.visible = false
		cinematic.play(arena)
		await cinematic.finished
		if not is_instance_valid(arena) or arena.player == null:
			return
		swarm.visible = true
		arena.player.inv_t = 1.0
		arena.player.camera.make_current()
		hud.visible = not end_screen.visible
		if not pause_menu.visible and not end_screen.visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Online the world keeps running; the menu just frees the mouse.
func pause() -> void:
	if not Net.is_online():
		get_tree().paused = true
	pause_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	pause_menu.visible = false
	get_tree().paused = false
	if arena and arena.player and not arena.player.is_dead():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func leave_match() -> void:
	Net.leave()
	to_hangar()


func to_hangar() -> void:
	_clear_arena()
	get_tree().paused = false
	pause_menu.visible = false
	end_screen.visible = false
	hud.visible = false
	hangar_layer.visible = true
	hangar.render()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.music("menu")


func _on_game_over(score: int, wave: int) -> void:
	hud.visible = false
	end_stats.text = "SCORE %d · WAVE %d" % [score, wave]
	var title := end_screen.get_node_or_null("Center/V/Title") as Label
	if title:
		title.text = "OVERRUN"
	if arena is DuelArena:
		# duel: score = my kills, wave = the winner's kills (-1 = I won)
		if title:
			title.text = "VICTORY" if wave < 0 else "DEFEATED"
		end_stats.text = "%d KILLS%s" % [score, "" if wave < 0 else "  ·  THEY TOOK %d" % wave]
	var redeploy_btn: Button = end_screen.get_node("%Redeploy")
	redeploy_btn.disabled = not Net.is_host()
	redeploy_btn.text = "REDEPLOY" if Net.is_host() else "WAITING FOR HOST"
	end_screen.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Host (or solo): start a fresh match for everyone in the session.
func redeploy() -> void:
	if not Net.is_host():
		return
	deploy()
	if Net.is_online():
		_net_redeploy.rpc()


@rpc("authority", "call_remote", "reliable")
func _net_redeploy() -> void:
	deploy()


func _clear_arena() -> void:
	if arena:
		arena.queue_free()
		world.remove_child(arena)
		arena = null
