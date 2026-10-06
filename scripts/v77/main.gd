extends Node
## Neon Core: boot screen -> hangar (loadout) -> deploy cinematic -> match -> pause / overrun -> hangar.
## Screens follow v77's layout and copy; the game itself is V77Game.

const D = preload("res://scripts/v77/data.gd")
const INK := Color("#f4f0ff")
const DIM := Color("#a99bd6")
const MAG := Color("#ff2bd6")
const CYA := Color("#21e6ff")
const BG := Color("#0a0620")
const GLASS := Color(12 / 255.0, 8 / 255.0, 36 / 255.0, .62)
const GLASS_EDGE := Color(130 / 255.0, 110 / 255.0, 230 / 255.0, .35)

var cfg := {"w": "pulse", "a": "vanguard", "s": "shield", "sn": 1.0, "fov": 85.0, "adsMode": "toggle", "vg": 1.0, "vm": .55}
var game: V77Game
var ui: CanvasLayer
var hangar: Control
var stage: V77HangarStage
var stage_vp: SubViewport
var boot: Control
var pop_panel: PanelContainer
var pop := ""
var slot_buttons := {}
var who_name: Label
var who_cls: Label
var who_perk: Label
var pause_scr: Control
var end_scr: Control
var end_stat: Label
var cut: Control
var cut_t := -1.0
var icons := {}
var font_d: SystemFont
var font_d9: SystemFont
var font_b: SystemFont
const SAVE := "user://neoncore.cfg"


func _ready() -> void:
	_load_cfg()
	font_d = _sysfont(["Orbitron", "Bahnschrift", "Segoe UI", "Arial"], 700)
	font_d9 = _sysfont(["Orbitron", "Bahnschrift", "Segoe UI", "Arial"], 900)
	font_b = _sysfont(["Chakra Petch", "Segoe UI", "Arial"], 500)
	game = V77Game.new()
	game.visible = false
	add_child(game)
	game.died.connect(_on_died)
	game.paused_changed.connect(func(on): pause_scr.visible = on)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_build_hangar()
	_build_pause_end()
	_build_cut()
	_build_boot()
	game.sfx.music_vol = cfg.vm
	game.sfx.master = cfg.vg
	game.sfx.music("menu")
	await get_tree().process_frame
	_bake_icons()
	render_menu()


static func _sysfont(names: Array, weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	return f


func _load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE) == OK:
		for k in cfg:
			cfg[k] = c.get_value("cfg", k, cfg[k])


func _save_cfg() -> void:
	var c := ConfigFile.new()
	for k in cfg:
		c.set_value("cfg", k, cfg[k])
	c.save(SAVE)


func _label(text: String, size: int, color := INK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font if font else font_d)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .8))
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func _glass_box(radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GLASS
	sb.border_color = GLASS_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(8)
	return sb


# ================================================================ boot (v77 #boot)
func _build_boot() -> void:
	boot = Control.new()
	boot.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(boot)
	var bg := ColorRect.new()
	bg.color = Color("#05030c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	boot.add_child(bg)
	var art := TextureRect.new()
	art.texture = load("res://assets/v77/file_02.jpg")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.pivot_offset = get_viewport().get_visible_rect().size / 2
	boot.add_child(art)
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(.02, .01, .05, 0))
	gr.set_color(1, Color(.02, .01, .05, .92))
	gr.add_point(.62, Color(.02, .01, .05, 0))
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boot.add_child(shade)
	var ld := HBoxContainer.new()
	ld.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ld.position = Vector2(-230, -90)
	ld.custom_minimum_size = Vector2(460, 50)
	ld.add_theme_constant_override("separation", 14)
	boot.add_child(ld)
	var crest := TextureRect.new()
	crest.texture = load("res://assets/v77/file_03.png")
	crest.custom_minimum_size = Vector2(44, 44)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.pivot_offset = Vector2(22, 22)
	crest.name = "Crest"
	ld.add_child(crest)
	var colv := VBoxContainer.new()
	colv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colv.alignment = BoxContainer.ALIGNMENT_CENTER
	ld.add_child(colv)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 4)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(120 / 255.0, 170 / 255.0, 1, .16)
	var fgs := StyleBoxFlat.new()
	fgs.bg_color = CYA
	bar.add_theme_stylebox_override("background", bgs)
	bar.add_theme_stylebox_override("fill", fgs)
	colv.add_child(bar)
	var lbl := _label("LOADING NEON CORE", 11, Color("#bfe6ff"), font_b)
	lbl.name = "Lbl"
	colv.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(art, "scale", Vector2.ONE, 14.0).from(Vector2.ONE * 1.08)
	_boot_t = 0.0


var _boot_t := -1.0

func _step_boot(dt: float) -> void:
	if _boot_t < 0:
		return
	_boot_t += dt
	var crest: Control = boot.find_child("Crest", true, false)
	var steps := floori(_boot_t / .6)       # stepped spin: 45 degree clicks with a little overshoot
	var ph := fmod(_boot_t, .6) / .6
	var ov := sin(minf(1, ph / .25) * PI) * 4 if ph < .25 else 0.0
	crest.rotation = deg_to_rad(steps * 45 + ov)
	var bar: ProgressBar = boot.find_child("Bar", true, false)
	var u := minf(1, _boot_t / 9.2)
	bar.value = (0.02 + .70 * u / .6 if u < .6 else .72 + .21 * (u - .6) / .4) * 100
	if _boot_t >= 9.0:
		(boot.find_child("Lbl", true, false) as Label).text = "READY"
		bar.value = 100
		_boot_t = -1.0
		var tw := create_tween()
		tw.tween_interval(.45)
		tw.tween_property(boot, "modulate:a", 0.0, .6)
		tw.tween_callback(func(): boot.visible = false)


# ================================================================ hangar (v77 #ov)
func _build_hangar() -> void:
	hangar = Control.new()
	hangar.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(hangar)
	var bgc := ColorRect.new()
	bgc.color = BG
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	hangar.add_child(bgc)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/v77/file_01.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	hangar.add_child(bg)
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0, .24, .64, 1])
	gr.colors = PackedColorArray([Color(8 / 255.0, 5 / 255.0, 26 / 255.0, .6), Color(8 / 255.0, 5 / 255.0, 26 / 255.0, 0), Color(8 / 255.0, 5 / 255.0, 26 / 255.0, 0), Color(8 / 255.0, 5 / 255.0, 26 / 255.0, .8)])
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	hangar.add_child(shade)
	# the 3D operative (transparent viewport over the corridor)
	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.mouse_default_cursor_shape = Control.CURSOR_DRAG
	hangar.add_child(svc)
	stage_vp = SubViewport.new()
	stage_vp.transparent_bg = true
	stage_vp.own_world_3d = true
	stage_vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(stage_vp)
	stage = V77HangarStage.new()
	stage_vp.add_child(stage)
	svc.gui_input.connect(_on_stage_input)
	# top left: the NEON CORE logo, then the operative (kept clear of each other)
	var who := VBoxContainer.new()
	who.position = Vector2(22, 16)
	who.add_theme_constant_override("separation", 4)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hangar.add_child(who)
	var logo := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/v77/file_34.jpg")
	at.region = Rect2(78, 64, 870, 456)        # the NEON CORE /// APEX COMBAT lettering, without the frame
	logo.texture = at
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.custom_minimum_size = Vector2(300, 157)
	logo.name = "Logo"
	who.add_child(logo)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	who.add_child(gap)
	who_cls = _label("OPERATIVE · MEDIUM FRAME", 12, DIM)
	who.add_child(who_cls)
	who_name = _label("VANGUARD", 20, INK, font_d9)
	who.add_child(who_name)
	who_perk = _label("", 14, Color(INK, .9), font_b)
	who_perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who_perk.custom_minimum_size = Vector2(320, 0)
	who.add_child(who_perk)
	# drag hint (bottom left, above the bar)
	var hint := _label("⟷  DRAG TO ROTATE", 11, DIM)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(22, -64 - 12 - 40)
	hint.name = "Hint"
	hangar.add_child(hint)
	# bottom loadout bar
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 16
	bar.offset_right = -16
	bar.offset_top = -12 - 76
	bar.offset_bottom = -12
	bar.add_theme_constant_override("separation", 10)
	hangar.add_child(bar)
	for kind in ["weapon", "armor", "skill"]:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 76)
		b.add_theme_stylebox_override("normal", _glass_box())
		var hov := _glass_box()
		hov.border_color = Color(170 / 255.0, 160 / 255.0, 1, .6)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", hov)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var hb := HBoxContainer.new()
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 8
		hb.offset_right = -8
		hb.add_theme_constant_override("separation", 12)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(84, 64)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ic)
		var tx := VBoxContainer.new()
		tx.alignment = BoxContainer.ALIGNMENT_CENTER
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tx.add_theme_constant_override("separation", 1)
		tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tx)
		var k := _label(kind.to_upper(), 11, DIM)
		var n := _label("", 13, INK, font_d9)
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var s := _label("", 13, DIM, font_b)
		s.clip_text = true
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		for l in [k, n, s]:
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tx.add_child(l)
		b.pressed.connect(func(): open_pop(kind))
		bar.add_child(b)
		slot_buttons[kind] = {"btn": b, "icon": ic, "name": n, "sub": s}
	var gear := Button.new()
	gear.text = "⚙"
	gear.custom_minimum_size = Vector2(76, 76)
	gear.add_theme_font_size_override("font_size", 30)
	gear.add_theme_stylebox_override("normal", _glass_box())
	gear.add_theme_stylebox_override("hover", _glass_box())
	gear.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	gear.add_theme_color_override("font_color", INK)
	gear.tooltip_text = "Settings"
	gear.pressed.connect(func(): open_pop("set"))
	bar.add_child(gear)
	var go_btn := Button.new()
	go_btn.text = "DEPLOY"
	go_btn.custom_minimum_size = Vector2(190, 76)
	go_btn.add_theme_font_override("font", font_d9)
	go_btn.add_theme_font_size_override("font_size", 19)
	go_btn.add_theme_color_override("font_color", Color.WHITE)
	go_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	var gs := StyleBoxTexture.new()
	var ggt := GradientTexture2D.new()
	var ggr := Gradient.new()
	ggr.set_color(0, MAG)
	ggr.set_color(1, CYA)
	ggt.gradient = ggr
	ggt.width = 256
	ggt.height = 8
	gs.texture = ggt
	go_btn.add_theme_stylebox_override("normal", gs)
	var gh := gs.duplicate()
	gh.modulate_color = Color(1.15, 1.15, 1.15)
	go_btn.add_theme_stylebox_override("hover", gh)
	go_btn.add_theme_stylebox_override("pressed", gh)
	go_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	go_btn.pressed.connect(deploy)
	bar.add_child(go_btn)
	# pop-up panel (v77 #pop)
	pop_panel = PanelContainer.new()
	pop_panel.add_theme_stylebox_override("panel", _glass_box(14))
	pop_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	pop_panel.offset_left = -560
	pop_panel.offset_right = -16
	pop_panel.offset_top = 16
	pop_panel.offset_bottom = -12 - 76 - 12
	pop_panel.visible = false
	hangar.add_child(pop_panel)


func _on_stage_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		stage.drag(ev.relative.x)
		(hangar.find_child("Hint", true, false) as Control).modulate.a = 0
	elif ev is InputEventMouseButton and not ev.pressed:
		stage.release()


func render_menu() -> void:
	var w := D.pick(D.WEAPONS, cfg.w)
	var a := D.pick(D.ARMORS, cfg.a)
	var s := D.pick(D.SKILLS, cfg.s)
	stage.show_loadout(a, w)
	who_name.text = a.name.to_upper()
	who_cls.text = "OPERATIVE · %s FRAME" % a.cls.to_upper()
	who_perk.text = a.perk
	var sb: Dictionary = slot_buttons
	sb.weapon.name.text = w.name.to_upper()
	sb.weapon.sub.text = w.cls
	sb.weapon.icon.texture = icons.get("weapon_" + w.id)
	sb.armor.name.text = a.name.to_upper()
	sb.armor.sub.text = a.cls + " frame"
	sb.armor.icon.texture = icons.get("armor_" + a.id)
	sb.skill.name.text = s.name.to_upper()
	sb.skill.sub.text = "%ss recharge" % str(s.cd)
	sb.skill.icon.texture = icons.get("skill_" + s.id)
	for k in ["weapon", "armor", "skill"]:
		var st: StyleBoxFlat = (sb[k].btn as Button).get_theme_stylebox("normal")
		var c := Color(w.hex if k == "weapon" else (a.c1 if k == "armor" else s.col))
		st.border_color = c if pop == k else GLASS_EDGE
		st.set_border_width_all(2 if pop == k else 1)
	stage.offset_target = -0.0 if pop == "" else .32
	_render_pop()


func open_pop(k: String) -> void:
	pop = "" if pop == k else k
	render_menu()


func _render_pop() -> void:
	for c in pop_panel.get_children():
		c.queue_free()
	pop_panel.visible = pop != ""
	if pop == "":
		return
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pop_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var titles := {"weapon": ["WEAPON", "10 classes"], "armor": ["ARMOR", "9 frames"], "skill": ["SKILL", "6 abilities"], "set": ["SETTINGS", "Controls and view"]}
	head.add_child(_label(titles[pop][0], 20, INK, font_d9))
	var sub := _label("   " + titles[pop][1], 12, DIM, font_b)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(sub)
	var x := Button.new()
	x.text = "✕"
	x.flat = true
	x.add_theme_font_size_override("font_size", 18)
	x.pressed.connect(func(): open_pop(pop))
	head.add_child(x)
	if pop == "set":
		_render_settings(v)
	else:
		var arr: Array = D.WEAPONS if pop == "weapon" else (D.ARMORS if pop == "armor" else D.SKILLS)
		var key := "w" if pop == "weapon" else ("a" if pop == "armor" else "s")
		var grid := GridContainer.new()
		grid.columns = 5 if pop == "weapon" else 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		v.add_child(grid)
		for it in arr:
			var t := Button.new()
			t.custom_minimum_size = Vector2(96, 92) if pop == "weapon" else Vector2(160, 96)
			var sel: bool = it.id == cfg[key]
			var c := Color(it.get("hex", it.get("c1", it.get("col", "#21e6ff"))))
			var st := _glass_box(10)
			st.border_color = c if sel else GLASS_EDGE
			st.set_border_width_all(2 if sel else 1)
			t.add_theme_stylebox_override("normal", st)
			t.add_theme_stylebox_override("hover", st)
			t.add_theme_stylebox_override("pressed", st)
			t.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			t.tooltip_text = it.name
			var tv := VBoxContainer.new()
			tv.set_anchors_preset(Control.PRESET_FULL_RECT)
			tv.alignment = BoxContainer.ALIGNMENT_CENTER
			tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.add_child(tv)
			var ic := TextureRect.new()
			ic.texture = icons.get(pop + "_" + it.id)
			ic.custom_minimum_size = Vector2(0, 52)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tv.add_child(ic)
			var lab: String = D.SHORT[it.id] if pop == "weapon" else (it.short if pop == "skill" else it.name.to_upper())
			var l := _label(lab, 11, c if sel else INK)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tv.add_child(l)
			var id: String = it.id
			t.pressed.connect(func():
				cfg[key] = id
				_save_cfg()
				render_menu())
			grid.add_child(t)
		# details + stat bars
		var it2 := D.pick(arr, cfg[key])
		var det := VBoxContainer.new()
		det.add_theme_constant_override("separation", 6)
		v.add_child(det)
		var title := ""
		var body := ""
		var bars := []
		if pop == "weapon":
			title = "%s · %s" % [it2.name.to_upper(), it2.cls.to_upper()]
			body = "%s Carried at %s. Reload: %s." % [it2.desc, it2.carry.to_lower(), it2.rlName.to_lower()]
			bars = [["DAMAGE", it2.dmg * it2.pel, 110, ("%d×%d" % [it2.dmg, it2.pel]) if it2.pel > 1 else str(it2.dmg)], ["RATE", 1 / it2.rate, 20, "%d/m" % roundi(60 / it2.rate)], ["MAG", it2.mag, 45, str(it2.mag)], ["RELOAD", 2.7 - it2.rl, 1.7, "%ss" % str(it2.rl)]]
		elif pop == "armor":
			title = "%s · %s" % [it2.name.to_upper(), it2.cls.to_upper()]
			body = it2.perk
			bars = [["HEALTH", it2.hp, 190, str(it2.hp)], ["SPEED", it2.spd, 1.2, "%d%%" % roundi(it2.spd * 100)], ["ARMOR", it2.dr, .25, "%d%%" % roundi(it2.dr * 100)], ["REGEN", it2.reg, 7, "%s/s" % str(it2.reg)]]
		else:
			title = it2.name.to_upper()
			body = it2.desc
			bars = [["RECHARGE", 20 - it2.cd, 16, "%ss" % str(it2.cd)]]
		det.add_child(_label(title, 14, INK, font_d9))
		var bl := _label(body, 14, Color(INK, .88), font_b)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size = Vector2(500, 0)
		det.add_child(bl)
		for b in bars:
			det.add_child(_stat_bar(b[0], float(b[1]) / float(b[2]), b[3]))
	var done := Button.new()
	done.text = "DONE"
	done.custom_minimum_size = Vector2(0, 44)
	done.add_theme_font_override("font", font_d9)
	done.add_theme_font_size_override("font_size", 14)
	done.add_theme_stylebox_override("normal", _glass_box(8))
	done.add_theme_stylebox_override("hover", _glass_box(8))
	done.pressed.connect(func(): open_pop(pop))
	v.add_child(done)


func _stat_bar(label: String, k: float, txt: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := _label(label, 11, DIM)
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.value = clampf(k, .04, 1) * 100
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.custom_minimum_size = Vector2(0, 6)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var a := StyleBoxFlat.new()
	a.bg_color = Color(1, 1, 1, .12)
	var b := StyleBoxFlat.new()
	b.bg_color = CYA
	pb.add_theme_stylebox_override("background", a)
	pb.add_theme_stylebox_override("fill", b)
	h.add_child(pb)
	var t := _label(txt, 12, INK)
	t.custom_minimum_size = Vector2(70, 0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(t)
	return h


func _render_settings(v: VBoxContainer) -> void:
	for row in [["Look sensitivity", "sn", .4, 2.5, .05], ["Field of view", "fov", 70, 110, 1], ["Game volume", "vg", 0, 1, .01], ["Music volume", "vm", 0, 1, .01]]:
		var h := HBoxContainer.new()
		var l := _label(row[0], 14, INK, font_b)
		l.custom_minimum_size = Vector2(170, 0)
		h.add_child(l)
		var s := HSlider.new()
		s.min_value = row[2]
		s.max_value = row[3]
		s.step = row[4]
		s.value = cfg[row[1]]
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k: String = row[1]
		s.value_changed.connect(func(val):
			cfg[k] = val
			game.sfx.master = cfg.vg
			game.sfx.music_vol = cfg.vm
			_save_cfg())
		h.add_child(s)
		v.add_child(h)
	var ah := HBoxContainer.new()
	var al := _label("Aim down sights", 14, INK, font_b)
	al.custom_minimum_size = Vector2(170, 0)
	ah.add_child(al)
	var ob := OptionButton.new()
	ob.add_item("Toggle")
	ob.add_item("Hold")
	ob.selected = 0 if cfg.adsMode == "toggle" else 1
	ob.item_selected.connect(func(i):
		cfg.adsMode = "toggle" if i == 0 else "hold"
		_save_cfg())
	ah.add_child(ob)
	v.add_child(ah)
	var p := _label("DESKTOP  WASD, mouse, RMB aim, Shift sprint, C crouch (hold: prone, while sprinting: slide), Space jump (again in mid-air: double jump), R reload, X swap, E lethal, G stun, Q skill, 4/5/6 streaks, V 180, M map, P or Esc pause.\n\nTIP  Shoot the base of a tower to drop the blocks above it.", 13, Color(INK, .85), font_b)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.custom_minimum_size = Vector2(500, 0)
	v.add_child(p)


# ================================================================ icons (rendered once from the real models)
func _bake_icons() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 160)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#9aa6ff")
	e.ambient_light_energy = 1.4
	env.environment = e
	root.add_child(env)
	var L := DirectionalLight3D.new()
	L.light_energy = 2.0
	root.add_child(L)
	L.look_at_from_position(Vector3(1, 2, 2), Vector3.ZERO)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	for w in D.WEAPONS:
		var g: Node3D = load("res://assets/baked/weapons/%s/%s.scn" % [w.id, w.id]).instantiate()
		root.add_child(g)
		var aabb := _aabb(g)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = maxf(aabb.size.z * .62, aabb.size.y * 1.05) * 1.15
		var c := aabb.get_center()
		cam.look_at_from_position(c + Vector3(1.5, .08, 0), c)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		icons["weapon_" + w.id] = ImageTexture.create_from_image(vp.get_texture().get_image())
		g.queue_free()
		await get_tree().process_frame
	# armour: the operative bust in each frame's tier, with its colour ring
	vp.size = Vector2i(160, 160)
	for a in D.ARMORS:
		var t := int(a.get("tier", 0))
		var mi := MeshInstance3D.new()
		mi.mesh = load("res://assets/baked/operative/tier%d.res" % t)
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/operative.gdshader")
		sm.set_shader_parameter("uDet", load("res://assets/v77/file_%d.png" % (28 + t)))
		sm.set_shader_parameter("uGlo", Color(a.c1))
		mi.material_override = sm
		mi.scale = Vector3.ONE * (1.92 / 11.9)
		root.add_child(mi)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 1.05
		cam.look_at_from_position(Vector3(.0, 1.45, 3), Vector3(0, 1.45, 0))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		icons["armor_" + a.id] = ImageTexture.create_from_image(vp.get_texture().get_image())
		mi.queue_free()
		await get_tree().process_frame
	vp.queue_free()
	for s in D.SKILLS:
		icons["skill_" + s.id] = _skill_icon(s.id, Color(s.col))
	render_menu()


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Skill glyphs drawn large and clean (dash bolt, shield, drone, chrono clock, nanite cross, grapple hook)
func _skill_icon(id: String, c: Color) -> Texture2D:
	var S := 128
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var line := func(a: Vector2, b: Vector2, w: float):
		var n := int(a.distance_to(b) * 2) + 1
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			for dy in range(-int(w), int(w) + 1):
				for dx in range(-int(w), int(w) + 1):
					if dx * dx + dy * dy <= w * w:
						var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
						if q.x >= 0 and q.y >= 0 and q.x < S and q.y < S:
							img.set_pixelv(q, c)
	var poly := func(pts: Array, w: float):
		for i in pts.size() - 1:
			line.call(pts[i], pts[i + 1], w)
	var circle := func(cc: Vector2, r: float, w: float):
		var pts := []
		for i in 65:
			pts.append(cc + Vector2(cos(TAU * i / 64), sin(TAU * i / 64)) * r)
		poly.call(pts, w)
	match id:
		"dash": poly.call([Vector2(74, 14), Vector2(40, 70), Vector2(64, 70), Vector2(54, 114), Vector2(90, 54), Vector2(66, 54), Vector2(74, 14)], 4)
		"shield": poly.call([Vector2(64, 14), Vector2(104, 28), Vector2(100, 70), Vector2(64, 112), Vector2(28, 70), Vector2(24, 28), Vector2(64, 14)], 4); poly.call([Vector2(64, 40), Vector2(64, 86)], 4); poly.call([Vector2(44, 60), Vector2(84, 60)], 4)
		"drone": circle.call(Vector2(64, 64), 22, 4); poly.call([Vector2(20, 40), Vector2(44, 52)], 4); poly.call([Vector2(108, 40), Vector2(84, 52)], 4); circle.call(Vector2(64, 64), 6, 3)
		"chrono": circle.call(Vector2(64, 66), 40, 4); poly.call([Vector2(64, 66), Vector2(64, 40)], 4); poly.call([Vector2(64, 66), Vector2(84, 76)], 4); poly.call([Vector2(52, 16), Vector2(76, 16)], 4)
		"nanite": poly.call([Vector2(64, 24), Vector2(64, 104)], 7); poly.call([Vector2(24, 64), Vector2(104, 64)], 7)
		"grapple": poly.call([Vector2(30, 100), Vector2(80, 50)], 4); poly.call([Vector2(80, 50), Vector2(80, 22)], 4); poly.call([Vector2(80, 50), Vector2(108, 50)], 4); poly.call([Vector2(80, 50), Vector2(100, 30)], 4)
	return ImageTexture.create_from_image(img)


# ================================================================ deploy cinematic (v77 CUT)
var SH: Array = []

func _build_cut() -> void:
	var VS := func(x: float, y: float, z: float) -> Vector3: return Vector3(x * D.MAPK, y, z * D.MAPK)
	SH = [
		{"n": "CENTRAL SPIRE PLAZA", "d": "Ground zero. The Spire still broadcasts over the Grand Plaza.", "a": VS.call(-46, 6, 58), "b": VS.call(-30, 16, 40), "la": Vector3(0, 24, 0), "lb": Vector3(0, 70, 0)},
		{"n": "GRAND PLAZA MARKET", "d": "Neon stalls, transit canopy and close-quarters cover.", "a": VS.call(76, 3.2, 46), "b": VS.call(62, 4.5, 42), "la": VS.call(48, 2.5, 26), "lb": VS.call(40, 4, 18)},
		{"n": "SKY-BRIDGE ROW", "d": "Glass corridors 22-32 m up, threaded through the towers. Launch pads put you on the roofs.", "a": VS.call(-20, 62, 70), "b": VS.call(-12, 50, 55), "la": Vector3(-40 * D.MAPK, 28, -77 * D.MAPK), "lb": Vector3(-20 * D.MAPK, 28, -77 * D.MAPK)},
		{"n": "THE BAY", "d": "Black water, sea walls and the mountains of the far shore.", "a": VS.call(-205, 40, 72), "b": VS.call(-198, 50, 30), "la": VS.call(-110, 4, -30), "lb": VS.call(-60, 30, -90)},
		{"n": "CENTRAL SPIRE PLAZA", "d": "The podium lifts ride the Spire to its first observation deck.", "a": VS.call(26, 2.2, -22), "b": VS.call(19, 3.2, -27), "la": Vector3(0, 22, 0), "lb": Vector3(0, 95, 0)},
		{"n": "GRAND PLAZA MARKET", "d": "Transit canopy overhead; launch pads throw you onto its roof.", "a": VS.call(28, 2.6, 6), "b": VS.call(36, 3.4, 10), "la": VS.call(56, 2.4, 30), "lb": VS.call(62, 3, 34)},
	]
	cut = Control.new()
	cut.set_anchors_preset(Control.PRESET_FULL_RECT)
	cut.visible = false
	cut.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(cut)
	for top in [true, false]:
		var lb := ColorRect.new()
		lb.color = Color.BLACK
		lb.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		lb.custom_minimum_size = Vector2(0, 90)
		if not top:
			lb.offset_top = -90
		else:
			lb.offset_bottom = 90
		cut.add_child(lb)
	var cap := VBoxContainer.new()
	cap.name = "Cap"
	cap.position = Vector2(48, 120)
	cut.add_child(cap)
	cap.add_child(_label("SECTOR 01", 12, CYA))
	cap.add_child(_label("", 30, INK, font_d9))
	var dl := _label("", 15, Color(INK, .85), font_b)
	dl.custom_minimum_size = Vector2(560, 0)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.add_child(dl)
	var ld := VBoxContainer.new()
	ld.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ld.position = Vector2(-220, -78)
	ld.custom_minimum_size = Vector2(440, 0)
	cut.add_child(ld)
	ld.add_child(_label("DEPLOYING TO NEON CORE CITY", 11, Color("#bfe6ff")))
	var pb := ProgressBar.new()
	pb.name = "CutBar"
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 4)
	var a := StyleBoxFlat.new()
	a.bg_color = Color(1, 1, 1, .15)
	var b := StyleBoxFlat.new()
	b.bg_color = CYA
	pb.add_theme_stylebox_override("background", a)
	pb.add_theme_stylebox_override("fill", b)
	ld.add_child(pb)
	ld.add_child(_label("CLICK OR PRESS SPACE TO SKIP", 10, DIM))
	var tip := _label("", 13, Color(INK, .8), font_b)
	tip.name = "Tip"
	tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tip.position = Vector2(-300, -30)
	tip.custom_minimum_size = Vector2(600, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cut.add_child(tip)
	cut.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: _end_cut())


const TIPS := ["Stand in a cyan lift beam to ride up to highways, bridges and the Spire deck.", "Blue launch pads throw you onto the sky-bridge roofs.", "Hold jump in mid-air to burn your jetpack (Warden and Ascendant frames).", "Tap 180 to whip round on spiders closing from behind.", "Shoot the base of a tower to drop the blocks above it.", "Grapple near a roof edge to pull yourself up onto the ledge.", "Scoped rifles zoom to 4x when you aim down sights."]
const CUT_DUR := 2.3

func _step_cut(dt: float) -> void:
	if cut_t < 0:
		return
	cut_t += dt
	var total := SH.size() * CUT_DUR
	var i := mini(SH.size() - 1, floori(cut_t / CUT_DUR))
	var u := clampf((cut_t - i * CUT_DUR) / CUT_DUR, 0, 1)
	var e := u * u * (3 - 2 * u)
	var s: Dictionary = SH[i]
	var C := game.C
	C.position = s.a.lerp(s.b, e)
	C.look_at(s.la.lerp(s.lb, e))
	C.rotation.z += sin(cut_t * .7) * .01
	C.fov = 58 - 6 * u
	var cap: VBoxContainer = cut.find_child("Cap", true, false)
	(cap.get_child(0) as Label).text = "SECTOR 0%d" % (i + 1)
	(cap.get_child(1) as Label).text = s.n
	(cap.get_child(2) as Label).text = s.d
	cap.modulate.a = minf(1, u * CUT_DUR / .5)
	(cut.find_child("CutBar", true, false) as ProgressBar).value = minf(100, cut_t / total * 100)
	if cut_t >= total:
		_end_cut()


func _end_cut() -> void:
	if cut_t < 0:
		return
	cut_t = -1.0
	cut.visible = false
	game.C.fov = cfg.fov
	game.start_play()


func _input(ev: InputEvent) -> void:
	if cut_t >= 0 and ev is InputEventKey and ev.pressed and ev.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		_end_cut()
		get_viewport().set_input_as_handled()
	elif boot.visible and _boot_t >= 0 and (ev is InputEventKey or ev is InputEventMouseButton) and ev.pressed:
		_boot_t = maxf(_boot_t, 8.9)     # any key skips the boot screen


# ================================================================ flow
func deploy() -> void:
	pop = ""
	pop_panel.visible = false
	hangar.visible = false
	end_scr.visible = false
	pause_scr.visible = false
	game.visible = true
	game.hud.visible = true
	game.deploy(cfg)
	cut.visible = true
	cut_t = 0.0
	(cut.find_child("Tip", true, false) as Label).text = "TIP  ·  " + TIPS[randi() % TIPS.size()]


func to_hangar() -> void:
	game.go = false
	game.visible = false
	game.hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_scr.visible = false
	end_scr.visible = false
	hangar.visible = true
	game.sfx.music("menu")
	render_menu()


func _on_died(score: int, wave: int) -> void:
	end_stat.text = "SCORE %d · WAVE %d" % [score, wave]
	end_scr.visible = true


func _screen(title: String, buttons: Array, extra: Array = []) -> Control:
	var c := ColorRect.new()
	c.color = Color(.04, .024, .125, .78)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	ui.add_child(c)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	c.add_child(v)
	var t := _label(title, 54, INK, font_d9)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", MAG)
	t.add_theme_constant_override("shadow_outline_size", 12)
	v.add_child(t)
	for x in extra:
		v.add_child(x)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(180, 52)
		btn.add_theme_font_override("font", font_d9)
		btn.add_theme_font_size_override("font_size", 16)
		var st := _glass_box(6)
		if b[2]:
			var gt := GradientTexture2D.new()
			var gr := Gradient.new()
			gr.set_color(0, MAG)
			gr.set_color(1, CYA)
			gt.gradient = gr
			gt.width = 128
			gt.height = 8
			var sbt := StyleBoxTexture.new()
			sbt.texture = gt
			btn.add_theme_stylebox_override("normal", sbt)
			btn.add_theme_stylebox_override("hover", sbt)
		else:
			btn.add_theme_stylebox_override("normal", st)
			btn.add_theme_stylebox_override("hover", st)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.pressed.connect(b[1])
		h.add_child(btn)
	return c


func _build_pause_end() -> void:
	pause_scr = _screen("PAUSED", [["RESUME", func(): game.set_paused(false), true], ["HANGAR", to_hangar, false]])
	end_stat = _label("", 16, CYA)
	end_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var p := _label("The swarm took the arena. Change your loadout or drop straight back in.", 15, Color(INK, .85), font_b)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_scr = _screen("OVERRUN", [["REDEPLOY", deploy, true], ["HANGAR", to_hangar, false]], [end_stat, p])


func _process(dt: float) -> void:
	_step_boot(dt)
	_step_cut(dt)
