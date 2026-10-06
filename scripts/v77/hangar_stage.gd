class_name V77HangarStage
extends Node3D
## v77 3D hangar avatar (A3): the operative on a turntable in a studio light rig, a glowing floor ring in the armour
## colour, the NEON CORE hologram scroll behind it, drifting embers, and the chosen weapon in its hands.
## Drag to turn (with momentum); it auto-rotates when left alone. Rendered into a transparent SubViewport.

const HOLD_POS := Vector3(-0.06122, 1.27678, 0.22556)     ## v77 OP.GP / OP.GB: where the held gun sits
const HOLD_BASIS := [Vector3(0.67152, 0.0, -0.74099), Vector3(0.37124, 0.86545, 0.33643), Vector3(0.64128, -0.50100, 0.58116)]

var cam: Camera3D
var spin: Node3D
var body: MeshInstance3D
var ring_mat: StandardMaterial3D
var held: Node3D
var holo: Node3D
var holo_mat: ShaderMaterial
var op_mat: ShaderMaterial
var tier := -1
var vel := 0.0
var dragging := false
var resume_at := 0.0
var t := 0.0
var offset_x := 0.0
var offset_target := 0.0
var embers: MultiMeshInstance3D


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#8a94c0")
	e.ambient_light_energy = .4
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.1
	env.environment = e
	add_child(env)
	cam = Camera3D.new()
	cam.fov = 8
	cam.near = .5
	cam.far = 160
	add_child(cam)
	cam.current = true
	var key := DirectionalLight3D.new()
	key.light_color = Color("#e4ecff")
	key.light_energy = 2.2
	key.shadow_enabled = true
	add_child(key)
	key.look_at_from_position(Vector3(1.4, 3.2, 2.6), Vector3(0, .95, 0))
	for L in [[Color("#4aa8ff"), 4.0, Vector3(-1.4, 2.1, -1.3)], [Color("#ff2bd6"), 2.4, Vector3(1.4, 1.6, -1.3)], [Color("#7f8cff"), .7, Vector3(-.9, 1.2, 2.2)]]:
		var o := OmniLight3D.new()
		o.light_color = L[0]
		o.light_energy = L[1]
		o.omni_range = 7
		o.position = L[2]
		add_child(o)
	# floor: contact shadow catcher, dark pad, glowing ring
	var sh := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	sp.size = Vector2(2.2, 2.2)
	sh.mesh = sp
	var shm := StandardMaterial3D.new()
	shm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	shm.albedo_color = Color(0, 0, 0, 0)
	shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh.material_override = shm
	add_child(sh)
	var pad := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = .66; pc.bottom_radius = .66; pc.height = .002; pc.radial_segments = 48
	pad.mesh = pc
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(0.02, 0.012, 0.06, .6)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pad.material_override = pm
	pad.position.y = .001
	add_child(pad)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = .66
	tm.outer_radius = .685
	tm.rings = 72
	ring.mesh = tm
	ring.scale = Vector3(1, .05, 1)
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color("#ff2bd6")
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color.a = .8
	ring.material_override = ring_mat
	ring.position.y = .003
	add_child(ring)
	_build_holo()
	_build_embers()
	spin = Node3D.new()
	add_child(spin)
	body = MeshInstance3D.new()
	body.scale = Vector3.ONE * (1.92 / 11.9)
	op_mat = ShaderMaterial.new()
	op_mat.shader = load("res://shaders/operative.gdshader")
	body.material_override = op_mat
	spin.add_child(body)
	_frame()


## v77 holo scroll: the NEON CORE title on a gently curved sheet between two glowing rollers, scanlines and glitch
func _build_holo() -> void:
	var HW := 2.5
	var HH := 1.42
	var cy := 1.42
	var cz := -1.55
	holo = Node3D.new()
	holo.position = Vector3(0, cy, cz)
	add_child(holo)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var R := 3.2
	var seg := 48
	var ang := HW / R
	for i in seg:
		for j in 2:
			pass
	for i in seg:
		var a0 := -ang / 2 + ang * i / seg
		var a1 := -ang / 2 + ang * (i + 1) / seg
		var p := func(a: float, y: float) -> Vector3: return Vector3(sin(a) * R, y, R - cos(a) * R)
		var u0 := float(i) / seg
		var u1 := float(i + 1) / seg
		var A: Vector3 = p.call(a0, -HH / 2)
		var B: Vector3 = p.call(a1, -HH / 2)
		var Cq: Vector3 = p.call(a1, HH / 2)
		var Dq: Vector3 = p.call(a0, HH / 2)
		for v in [[A, Vector2(u0, 1)], [B, Vector2(u1, 1)], [Cq, Vector2(u1, 0)], [A, Vector2(u0, 1)], [Cq, Vector2(u1, 0)], [Dq, Vector2(u0, 0)]]:
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var sheet := MeshInstance3D.new()
	sheet.mesh = st.commit()
	holo_mat = ShaderMaterial.new()
	holo_mat.shader = load("res://shaders/holo_scroll.gdshader")
	holo_mat.set_shader_parameter("uMap", load("res://assets/v77/file_34.jpg"))
	sheet.material_override = holo_mat
	holo.add_child(sheet)
	var roll := StandardMaterial3D.new()
	roll.albedo_color = Color("#10131c")
	roll.metallic = .85
	roll.roughness = .3
	for sy in [-1, 1]:
		var y: float = sy * (HH / 2 + .035)
		var rl := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = .03; cm.bottom_radius = .03; cm.height = HW * 1.04
		rl.mesh = cm
		rl.material_override = roll
		rl.rotation.z = PI / 2
		rl.position = Vector3(0, y, -.02)
		holo.add_child(rl)
		var ln := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = .033; lm.bottom_radius = .033; lm.height = HW * .96
		ln.mesh = lm
		var lmat := StandardMaterial3D.new()
		lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lmat.albedo_color = Color("#21e6ff") if sy > 0 else Color("#ff2bd6")
		lmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lmat.albedo_color.a = .35
		ln.material_override = lmat
		ln.rotation.z = PI / 2
		ln.position = rl.position
		holo.add_child(ln)
		for sx in [-1, 1]:
			var cap := MeshInstance3D.new()
			var cc := CylinderMesh.new()
			cc.top_radius = .045; cc.bottom_radius = .045; cc.height = .05
			cap.mesh = cc
			cap.material_override = roll
			cap.rotation.z = PI / 2
			cap.position = Vector3(sx * HW * .535, y, -.02)
			holo.add_child(cap)


func _build_embers() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(.018, .018)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("#ff7a3d")
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	mm.mesh = q
	mm.instance_count = 70
	for i in 70:
		var a := randf() * TAU
		var d := .5 + randf() * 1.1
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(cos(a) * d, randf() * 2.4, sin(a) * d - .4)))
	embers = MultiMeshInstance3D.new()
	embers.multimesh = mm
	add_child(embers)


## v77 fit(): the operative fills ~60% of the height with the boots at ~83.5% down; eye-level camera
func _frame() -> void:
	var vp := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1600, 900)
	var aspect := vp.x / maxf(1.0, vp.y)
	var port := vp.y > vp.x
	var f := .5 if port else .6
	var feet := .77 if port else .835
	var tt := tan(deg_to_rad(cam.fov) / 2)
	var V := 1.92 / f
	if V * aspect < 1.8:
		V = 1.8 / aspect
	var cy := (feet - .5) * V
	var d := V / (2 * tt)
	cam.position = Vector3(0, cy, d)
	cam.look_at(Vector3(0, cy, 0))


func show_loadout(armor: Dictionary, weapon: Dictionary) -> void:
	var tr := int(armor.get("tier", 0))
	if tr != tier:
		tier = tr
		body.mesh = load("res://assets/baked/operative/tier%d.res" % tier)
		op_mat.set_shader_parameter("uDet", load("res://assets/v77/file_%d.png" % (28 + tier)))
		op_mat.set_shader_parameter("uGlo", [Vector3(.04, .3, 1), Vector3(.04, .36, 1), Vector3(.08, .62, 1), Vector3(.26, .55, 1)][tier])
	ring_mat.albedo_color = Color(armor.c1, .8)
	if held:
		held.queue_free()
	held = Node3D.new()
	spin.add_child(held)
	var gs: Node3D = load("res://assets/baked/weapons/%s/%s.scn" % [weapon.id, weapon.id]).instantiate()
	held.add_child(gs)
	held.transform = Transform3D(Basis(HOLD_BASIS[0], HOLD_BASIS[1], HOLD_BASIS[2]), HOLD_POS)
	held.scale = Vector3.ONE * 1.1


func drag(dx: float) -> void:
	var k := TAU * 2.2 / clampf(get_viewport().get_visible_rect().size.x, 320, 900)
	var a := dx * k
	spin.rotation.y += a
	vel = vel * .4 + a * 60 * .6
	dragging = true
	resume_at = t + 6


func release() -> void:
	dragging = false
	vel = clampf(vel, -9, 9)


func _process(dt: float) -> void:
	t += dt
	if holo_mat:
		holo_mat.set_shader_parameter("uT", t)
		holo.position.y = 1.42 + sin(t * .8) * .025
		holo.rotation.y = sin(t * .35) * .04
	if op_mat:
		op_mat.set_shader_parameter("uTime", t)
	if not dragging:
		if absf(vel) > .01:
			spin.rotation.y += vel * dt
			vel *= pow(.05, dt)
		elif t > resume_at:
			spin.rotation.y += dt * .35       # auto-rotate when left alone
	offset_x += (offset_target - offset_x) * minf(1, dt * 6)
	cam.h_offset = offset_x
	_frame()
