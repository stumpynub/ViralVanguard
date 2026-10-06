extends CanvasLayer
## In-match HUD: wave / score / health, weapon card, ammo, skill + grenade + streak status, kill feed,
## minimap, jet fuel, screen overlays (damage, overshield, chrono, heal) and the rifle scope.

@export var wave_label: Label
@export var score_label: Label
@export var hp_bar: ProgressBar
@export var hp_label: Label
@export var kill_feed: VBoxContainer
@export var weapon_name: Label
@export var ammo_label: Label
@export var other_weapon: Label
@export var skill_label: Label
@export var skill_bar: ProgressBar
@export var blast_label: Label
@export var stun_label: Label
@export var streak_labels: Array[NodePath] = []
@export var jet_bar: ProgressBar
@export var crosshair: Control
@export var minimap: Control
@export var damage_overlay: CanvasItem
@export var shield_overlay: CanvasItem
@export var chrono_overlay: CanvasItem
@export var heal_overlay: CanvasItem
@export var scope: CanvasItem
@export var hint: Label

var arena: Arena
var player: Player
var _dmg := 0.0
var _heal := 0.0
var _grapple_poll := 0
var _respawn_label: Label
var _team_label: RichTextLabel
var _respawn_at := -1.0


var _hit_t := 0.0
var _hit_head := false
var _hitmark: Control
var _breath: ProgressBar


func bind(a: Arena) -> void:
	arena = a
	player = a.player
	if _hitmark == null:
		_hitmark = Control.new()
		_hitmark.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hitmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hitmark.draw.connect(_draw_hitmark)
		add_child(_hitmark)
		_breath = ProgressBar.new()
		_breath.show_percentage = false
		_breath.max_value = 1.0
		_breath.custom_minimum_size = Vector2(120, 4)
		_breath.set_anchors_preset(Control.PRESET_CENTER)
		_breath.position = Vector2(-60, 120)
		_breath.size = Vector2(120, 4)
		_breath.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_breath)
	player.hit_confirmed.connect(func(head):
		_hit_t = 0.32 if head else 0.18
		_hit_head = head)
	a.score_changed.connect(func(s): score_label.text = str(s))
	a.wave_changed.connect(func(w): wave_label.text = str(w))
	a.kill_feed.connect(_feed)
	player.health_changed.connect(_on_health)
	player.damaged.connect(func(): _dmg = 0.9)
	player.healed.connect(func(): _heal = 0.9)
	player.weapons.weapon_changed.connect(_on_weapon)
	player.weapons.ammo_changed.connect(_on_ammo)
	_on_weapon(player.weapons.weapon, player.weapons.slots[player.weapons.cur ^ 1])
	_on_ammo(player.weapons.ammo, player.weapons.weapon.magazine, false)
	_on_health(player.hp, player.max_hp)
	jet_bar.visible = player.jet_available()
	minimap.cache_city(a)
	for c in kill_feed.get_children():
		c.queue_free()
	_build_team_widgets()
	a.local_player_died.connect(func(t): _respawn_at = Time.get_ticks_msec() / 1000.0 + t)
	a.local_player_respawned.connect(func(): _respawn_at = -1.0)
	_respawn_at = -1.0


func _build_team_widgets() -> void:
	if _respawn_label == null:
		_respawn_label = Label.new()
		_respawn_label.set_anchors_preset(Control.PRESET_CENTER)
		_respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_respawn_label.add_theme_font_size_override("font_size", 26)
		_respawn_label.add_theme_color_override("font_shadow_color", Color("#c8101a"))
		_respawn_label.add_theme_constant_override("shadow_outline_size", 12)
		_respawn_label.position = Vector2(-300, 60)
		_respawn_label.size = Vector2(600, 80)
		add_child(_respawn_label)
	if _team_label == null:
		_team_label = RichTextLabel.new()
		_team_label.bbcode_enabled = true
		_team_label.fit_content = true
		_team_label.scroll_active = false
		_team_label.position = Vector2(20, 196)
		_team_label.size = Vector2(240, 200)
		_team_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_team_label.add_theme_font_size_override("normal_font_size", 11)
		add_child(_team_label)
	_respawn_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and visible:
		minimap.toggle_big()


func _on_health(hp: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "%d / %d" % [ceili(hp), int(max_hp)]


func _on_weapon(w: WeaponData, other: WeaponData) -> void:
	weapon_name.text = w.display_name.to_upper()
	other_weapon.text = other.short_name
	ammo_label.add_theme_color_override("font_shadow_color", w.color)


func _on_ammo(ammo: int, mag: int, reloading: bool) -> void:
	ammo_label.text = "--" if reloading else "%d/%d" % [ammo, mag]


func _feed(text: String) -> void:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(260, 0)
	l.text = "[center]" + text + "[/center]"
	l.add_theme_font_size_override("normal_font_size", 11)
	kill_feed.add_child(l)
	kill_feed.move_child(l, 0)
	while kill_feed.get_child_count() > 4:
		var last := kill_feed.get_child(kill_feed.get_child_count() - 1)
		kill_feed.remove_child(last)
		last.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_callback(l.queue_free)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var ab := player.abilities
	var w := player.weapons
	_dmg *= 0.9
	_heal *= 0.94
	damage_overlay.modulate.a = maxf(_dmg, 0.35 if player.hp < player.max_hp * 0.35 else 0.0)
	shield_overlay.modulate.a = move_toward(shield_overlay.modulate.a, 1.0 if player.shield_t > 0.0 else 0.0, delta * 5.0)
	chrono_overlay.modulate.a = move_toward(chrono_overlay.modulate.a, 1.0 if player.chrono_t > 0.0 else 0.0, delta * 5.0)
	heal_overlay.modulate.a = _heal
	var sk := ab.skill
	skill_label.text = ("%ds" % ceili(ab.skill_cd)) if ab.skill_cd > 0.0 else sk.short_name
	skill_bar.value = 1.0 - ab.skill_cd / (sk.cooldown * ab.cdr()) if ab.skill_cd > 0.0 else 1.0
	blast_label.text = ("%ds" % ceili(ab.blast_cd)) if ab.blast_cd > 0.0 else "BLAST"
	stun_label.text = "STUN x%d" % ab.stun_n
	for i in streak_labels.size():
		var s: Dictionary = Abilities.STREAKS[i]
		var lab := get_node(streak_labels[i]) as Label
		if ab.streak_used[i]:
			lab.text = "USED"
		elif ab.streak_ready(i):
			lab.text = "[%d] %s" % [i + 4, s.name]
		else:
			lab.text = "%d/%d" % [mini(arena.streak_kills, s.kills), s.kills]
		lab.modulate = Color(1, 1, 1, 1.0 if ab.streak_ready(i) else 0.45)
	jet_bar.value = player.jet_fuel
	if _respawn_at > 0.0:
		_respawn_label.visible = true
		var left := maxf(0.0, _respawn_at - Time.get_ticks_msec() / 1000.0)
		var alive := arena.living_players().size()
		_respawn_label.text = ("DOWN · RESPAWNING IN %d" % ceili(left)) if alive > 0 or Net.is_online() else "DOWN"
	else:
		_respawn_label.visible = false
	if Net.is_online():
		var lines := PackedStringArray()
		if Net.room != "":
			lines.append("[color=#8a8890]ROOM[/color] [color=#ffffff]%s[/color]" % Net.room)
		for id in arena.players:
			var p: Player = arena.players[id]
			if not is_instance_valid(p):
				continue
			var col := "#ff2a3d" if p.is_dead() else ("#d9d6d0" if id == arena.me() else "#e6e2da")
			lines.append("[color=%s]%s[/color] [color=#8a8890]%d[/color]" % [col, Net.player_name(id), ceili(p.hp)])
		_team_label.text = "\n".join(lines)
		_team_label.visible = true
	else:
		_team_label.visible = false
	crosshair.modulate.a = 0.8 * (1.0 - w.ads) + 0.1
	scope.visible = w.scoped_view()
	if _breath:
		_breath.visible = scope.visible and w.weapon.hold_breath > 0.0
		_breath.value = w.breath
		_breath.modulate = Color("#ff3a3a") if w.winded else (Color.WHITE if w.holding_breath else Color(1, 1, 1, 0.45))
	if _hitmark:
		_hit_t = maxf(0.0, _hit_t - get_process_delta_time())
		_hitmark.queue_redraw()
	crosshair.visible = not scope.visible
	_grapple_poll += 1
	if _grapple_poll % 5 == 0 and sk.id == "grapple":
		var cam := player.camera
		crosshair.grapple_ok = ab.skill_cd <= 0.0 and player.grapple.is_empty() and not arena.raycast(cam.global_position, cam.global_position - cam.global_basis.z * Player.GRAPPLE_RANGE, Arena.LAYER_WORLD).is_empty()


func _draw_hitmark() -> void:
	if _hit_t <= 0.0:
		return
	var c := _hitmark.size * 0.5
	var k := _hit_t / (0.32 if _hit_head else 0.18)
	var col := (Color("#ff2a1a") if _hit_head else Color(1, 1, 1)) * Color(1, 1, 1, k)
	var r0 := 7.0 + (1.0 - k) * 4.0
	var r1 := r0 + (11.0 if _hit_head else 7.0)
	for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var n: Vector2 = d.normalized()
		_hitmark.draw_line(c + n * r0, c + n * r1, col, 3.0 if _hit_head else 2.0, true)
