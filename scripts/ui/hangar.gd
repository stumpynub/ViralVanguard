extends Control
## Hangar / loadout screen. Three slots (weapon, armour, skill), a settings gear and DEPLOY.
## Tapping a slot opens the side panel with every option from the database plus its stats.

signal deploy_requested

const POPS := {"weapon": ["WEAPON", "10 classes"], "armor": ["ARMOR", "9 frames"], "skill": ["SKILL", "6 abilities"], "settings": ["SETTINGS", "Controls and view"]}

@export var stage: Node3D
@export var avatar_view: Control
@export var operative_class: Label
@export var operative_name: Label
@export var operative_perk: Label
@export var weapon_slot: Button
@export var armor_slot: Button
@export var skill_slot: Button
@export var settings_button: Button
@export var deploy_button: Button
@export var popup: Control
@export var popup_title: Label
@export var popup_subtitle: Label
@export var close_button: Button
@export var grid: GridContainer
@export var details: RichTextLabel
@export var bars: VBoxContainer
@export var settings_box: Control
@export var sensitivity: Slider
@export var fov: Slider
@export var vol_game: Slider
@export var vol_music: Slider
@export var ads_mode: OptionButton
@export var done_button: Button
@export var drag_hint: Control
@export var backdrop: TextureRect
@export var mode_button: Button
@export var title_label: Label

@export_group("Online")
@export var mp_panel: Control
@export var name_edit: LineEdit
@export var quick_play: Button
@export var host_private: Button
@export var code_edit: LineEdit
@export var join_button: Button
@export var lan_row: Control
@export var host_lan: Button
@export var address_edit: LineEdit
@export var join_ip: Button
@export var status_label: Label

var _pop := ""


func _ready() -> void:
	weapon_slot.pressed.connect(open_pop.bind("weapon"))
	armor_slot.pressed.connect(open_pop.bind("armor"))
	skill_slot.pressed.connect(open_pop.bind("skill"))
	settings_button.pressed.connect(open_pop.bind("settings"))
	close_button.pressed.connect(open_pop.bind(""))
	done_button.pressed.connect(open_pop.bind(""))
	deploy_button.pressed.connect(func(): deploy_requested.emit())
	if mode_button:
		mode_button.pressed.connect(func():
			Net.game_mode = "duel" if Net.game_mode == "coop" else "coop"
			_sync_mode())
		_sync_mode()
	if ads_mode.item_count == 0:
		ads_mode.add_item("Toggle (tap RMB)")
		ads_mode.add_item("Hold RMB")
	sensitivity.value = Game.settings.sensitivity
	fov.value = Game.settings.fov
	vol_game.value = Game.settings.vol_game
	vol_music.value = Game.settings.vol_music
	ads_mode.selected = 1 if Game.settings.ads_mode == "hold" else 0
	sensitivity.value_changed.connect(func(v): Game.set_setting("sensitivity", v))
	fov.value_changed.connect(func(v): Game.set_setting("fov", v))
	vol_game.value_changed.connect(func(v): Game.set_setting("vol_game", v))
	vol_game.drag_ended.connect(func(_c): Sfx.beep(660, 0.12, "sine", 0.12))
	vol_music.value_changed.connect(func(v): Game.set_setting("vol_music", v))
	ads_mode.item_selected.connect(func(i): Game.set_setting("ads_mode", "hold" if i == 1 else "toggle"))
	avatar_view.gui_input.connect(_on_avatar_input)
	if stage.has_signal("lightning_struck"):
		stage.lightning_struck.connect(_on_lightning)
	_setup_online()
	render()


var _glitch := 0.0
var _next_glitch := 3.0


func _process(delta: float) -> void:
	if not visible:
		return
	# the city drifts a little with the mouse
	if backdrop and backdrop.material:
		var vp := get_viewport_rect().size
		var m := (get_viewport().get_mouse_position() / vp - Vector2(0.5, 0.5)) * 2.0
		var cur = backdrop.material.get_shader_parameter("parallax")
		if cur == null:
			cur = Vector2.ZERO
		backdrop.material.set_shader_parameter("parallax", cur.lerp(m, minf(1.0, delta * 2.0)))
	# the title glitches now and then
	_next_glitch -= delta
	if _next_glitch <= 0.0:
		_next_glitch = randf_range(2.5, 7.0)
		_glitch = 1.0
	_glitch = maxf(0.0, _glitch - delta * 4.0)
	if title_label and title_label.material:
		title_label.material.set_shader_parameter("glitch", _glitch)


func _on_lightning(k: float) -> void:
	if backdrop and backdrop.material:
		backdrop.material.set_shader_parameter("lightning", k)
	if k > 0.5:
		_glitch = maxf(_glitch, 0.6)


func _sync_mode() -> void:
	var duel := Net.game_mode == "duel"
	mode_button.text = "MODE\n" + ("SNIPER DUEL" if duel else "CO-OP")
	deploy_button.text = "PRACTICE" if duel else "PLAY SOLO"
	if quick_play:
		quick_play.text = "FIND A DUEL" if duel else "QUICK PLAY"


func _setup_online() -> void:
	name_edit.text = str(Game.settings.player_name)
	name_edit.text_changed.connect(func(t): Game.set_setting("player_name", t.strip_edges().to_upper()))
	quick_play.pressed.connect(func(): _go(Net.quick_play))
	host_private.pressed.connect(func(): _go(Net.host_private))
	join_button.pressed.connect(func(): _go(Net.join_code.bind(code_edit.text)))
	code_edit.text_submitted.connect(func(_t): join_button.pressed.emit())
	host_lan.pressed.connect(func(): _go(Net.host_lan))
	join_ip.pressed.connect(func(): _go(Net.join_ip.bind(address_edit.text)))
	lan_row.visible = not OS.has_feature("web")     # browsers can't open raw UDP sockets
	Net.status.connect(func(t): show_status(t))


func _go(action: Callable) -> void:
	if name_edit.text.strip_edges() == "":
		name_edit.text = str(Game.settings.player_name)
	show_status("Connecting…")
	_set_buttons(false)
	await action.call()
	_set_buttons(true)


func _set_buttons(on: bool) -> void:
	for b in [quick_play, host_private, join_button, host_lan, join_ip, deploy_button]:
		b.disabled = not on


func show_status(text: String, error := false) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", Color("#ff3a3a") if error else Color("#8a8890"))
	_set_buttons(true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") and _pop != "":
		open_pop("")
		get_viewport().set_input_as_handled()
	elif _pop == "" and event is InputEventKey and event.keycode in [KEY_LEFT, KEY_RIGHT]:
		stage.key_spin((-1.0 if event.keycode == KEY_LEFT else 1.0) if event.pressed else 0.0)


func _on_avatar_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		stage.drag(event.relative.x)
		drag_hint.modulate.a = 0.0
	elif event is InputEventMouseButton and not event.pressed:
		stage.release()


func open_pop(kind: String) -> void:
	_pop = "" if _pop == kind else kind
	render()


func render() -> void:
	var w := Game.weapon()
	var a := Game.armor()
	var s := Game.skill()
	stage.show_loadout(a, w, s)
	stage.focus(1.0 if _pop != "" else 0.0)
	operative_name.text = a.display_name.to_upper()
	operative_class.text = "OPERATIVE · %s FRAME" % a.armor_class.to_upper()
	operative_perk.text = a.perk
	_slot(weapon_slot, "WEAPON", w.display_name, w.weapon_class, w.icon, w.color)
	_slot(armor_slot, "ARMOR", a.display_name, a.armor_class + " frame", a.icon, a.primary_color)
	_slot(skill_slot, "SKILL", s.display_name, "%ds recharge" % int(s.cooldown), s.icon, s.color)
	popup.visible = _pop != ""
	mp_panel.visible = _pop == ""
	if _pop == "":
		return
	popup_title.text = POPS[_pop][0]
	popup_subtitle.text = POPS[_pop][1]
	settings_box.visible = _pop == "settings"
	grid.visible = _pop != "settings"
	for c in grid.get_children():
		c.queue_free()
	for c in bars.get_children():
		c.queue_free()
	match _pop:
		"weapon":
			grid.columns = 5
			for x in Game.DB.weapons:
				_tile(x.id, x.short_name, x.icon, x.color, x.id == w.id, "weapon")
			details.text = "[b]%s · %s[/b]\n%s Carried at %s. Reload: %s." % [w.display_name.to_upper(), w.weapon_class.to_upper(), w.description, w.carry.to_lower(), w.reload_name.to_lower()]
			_bar("DAMAGE", w.damage * w.pellets, 110, ("%d×%d" % [w.damage, w.pellets]) if w.pellets > 1 else str(int(w.damage)))
			_bar("RATE", 1.0 / w.fire_interval, 20, "%d/m" % roundi(60.0 / w.fire_interval))
			_bar("MAG", w.magazine, 45, str(w.magazine))
			_bar("RELOAD", 2.7 - w.reload_time, 1.7, "%ss" % w.reload_time)
		"armor":
			grid.columns = 3
			for x in Game.DB.armors:
				_tile(x.id, x.display_name.to_upper(), x.icon, x.primary_color, x.id == a.id, "armor")
			details.text = "[b]%s · %s[/b]\n%s" % [a.display_name.to_upper(), a.armor_class.to_upper(), a.perk]
			_bar("HEALTH", a.max_health, 190, str(a.max_health))
			_bar("SPEED", a.speed, 1.2, "%d%%" % roundi(a.speed * 100))
			_bar("ARMOR", a.damage_reduction, 0.25, "%d%%" % roundi(a.damage_reduction * 100))
			_bar("REGEN", a.regen, 7, "%s/s" % a.regen)
		"skill":
			grid.columns = 3
			for x in Game.DB.skills:
				_tile(x.id, x.short_name, x.icon, x.color, x.id == s.id, "skill")
			details.text = "[b]%s[/b]\n%s" % [s.display_name.to_upper(), s.description]
			_bar("RECHARGE", 20 - s.cooldown, 16, "%ss" % s.cooldown)
		"settings":
			details.text = "[b]DESKTOP[/b]\nWASD move, mouse aim, LMB fire, RMB aim, Shift sprint, Space jump (hold in mid-air for jetpack on Mk III+), C crouch (hold: prone, while sprinting: slide), R reload, X swap, E blast, G stun, Q skill, 4/5/6 streaks, V quick 180, T first / third person, M map, P / Esc pause.\n\n[b]TIP[/b]\nShoot the base of a tower to drop the blocks above it."


func _slot(b: Button, kind: String, title: String, sub: String, icon: Texture2D, col: Color) -> void:
	b.icon = icon
	b.text = "%s\n%s\n%s" % [kind, title.to_upper(), sub]
	var open := _pop == kind.to_lower()
	b.add_theme_color_override("icon_normal_color", Color("#e0302a") if open else Color("#b8b4ac"))
	b.add_theme_color_override("font_color", Color("#ff3a3a") if open else Color("#d9d6d0"))


func _tile(id: String, label: String, icon: Texture2D, col: Color, selected: bool, kind: String) -> void:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = selected
	b.text = label
	b.icon = icon
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = true
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_pressed_color", Color("#ff3a3a"))
	b.add_theme_color_override("icon_pressed_color", Color("#ff3a3a"))
	b.add_theme_color_override("icon_normal_color", Color("#8a8890"))
	b.theme_type_variation = &"Tile"
	b.pressed.connect(func():
		Game.set_setting(kind, id)
		render())
	grid.add_child(b)


func _bar(label: String, v: float, max_v: float, txt: String) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(70, 0)
	l.theme_type_variation = &"StatLabel"
	var p := ProgressBar.new()
	p.max_value = 1.0
	p.value = clampf(v / max_v, 0.04, 1.0)
	p.show_percentage = false
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.custom_minimum_size = Vector2(0, 6)
	var t := Label.new()
	t.text = txt
	t.custom_minimum_size = Vector2(52, 0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	t.theme_type_variation = &"StatLabel"
	row.add_child(l)
	row.add_child(p)
	row.add_child(t)
	bars.add_child(row)
