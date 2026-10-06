extends Node3D
## Renders the rigged operative in each animation (front + side) to tools/rig/pose_<anim>.png
func _ready() -> void:
	var who: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "sick_operative"
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.25, 0.27, 0.32)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 0.6
	add_child(env)
	var l := DirectionalLight3D.new(); l.rotation = Vector3(-0.6, 0.5, 0); add_child(l)
	var chars: Array[CharacterModel] = []
	for i in 3:
		var c: CharacterModel = load("res://scenes/characters/%s.tscn" % who).instantiate()
		add_child(c)
		c.position.x = (i - 1) * 1.3
		if i == 1: c.rotation.y = PI / 2   # side view
		var gun: Node3D = load("res://scenes/weapons/pulse.tscn").instantiate()
		c.weapon_grip.add_child(gun)
		chars.append(c)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.3
	cam.position = Vector3(0, 0.95, 5); add_child(cam)
	for anim in ["idle", "walk", "run", "sprint", "death", "idle_rifle", "run_rifle", "crouch_rifle", "jump_rifle"]:
		for c in chars:
			c.get_node("Skeleton/WeaponMount/Grip").visible = anim.ends_with("rifle")
			var ap: AnimationPlayer = c.animation_player
			ap.play(anim)
			var len := ap.current_animation_length
			ap.seek(len * (0.25 if c == chars[0] else (0.25 if c == chars[1] else 0.75)) if not anim.begins_with("death") else len, true)
			ap.pause()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/shots/%s_pose_%s.png" % [who, anim])
	get_tree().quit()
