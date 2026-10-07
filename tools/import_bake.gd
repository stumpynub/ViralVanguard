extends SceneTree
## Builds a Godot scene from a v77 bake (tools/bake/export.js output in bake/<name>/):
##   textures  -> res://assets/baked/<name>/tex/<id>.res  (lossless, mipmapped, as v77 drew them)
##   materials -> ShaderMaterials on shaders/v77_material.gdshaderinc (variants generated per render mode)
##   nodes     -> Node3D tree, MeshInstance3D / MultiMeshInstance3D / sprite quads, lights
##   result    -> res://assets/baked/<name>/<name>.scn
##   godot --headless --path . --script res://tools/import_bake.gd -- <name>

const PI_ := PI
const FLIP := true      ## reverse triangle winding: three winds front faces counter-clockwise, Godot clockwise (without
                        ## this the whole city rendered inside out: far inner walls, mirrored text, no ground plane)
var base := ""
var out := ""
var m: Dictionary
var bin: PackedByteArray
var cur_order := 0          ## renderOrder of the node being built (three draws lower first)
var tex_cache := {}
var mat_cache := {}
var shader_cache := {}
var mesh_cache := {}
var stats := {"meshes": 0, "multimesh": 0, "sprites": 0, "lights": 0, "skipped": {}}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var name: String = args[0] if args.size() > 0 else "city"
	base = ProjectSettings.globalize_path("res://bake/%s/" % name)
	out = "res://assets/baked/%s/" % name
	name = name.get_file()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out + "tex"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/baked/shaders"))
	m = JSON.parse_string(FileAccess.get_file_as_string(base + "scene.json"))
	bin = FileAccess.get_file_as_bytes(base + "geometry.bin")
	if "prepare" in args:
		_prepare()
		quit()
		return
	var t0 := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = name.to_pascal_case()
	var nodes: Array = m.nodes
	var made: Array = []
	made.resize(nodes.size())
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		var node := _node(n, i)
		made[i] = node
		var parent: Node = root if int(n.parent) < 0 else made[int(n.parent)]
		if parent == null:
			parent = root
		parent.add_child(node)
	for i in nodes.size():
		_own(made[i], root)
	var env: Dictionary = m.env if m.env is Dictionary else {}
	root.set_meta("v77_env", env)
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, out + name + ".scn", ResourceSaver.FLAG_COMPRESS)
	print("import %s: %s  nodes=%d  err=%d  %d ms" % [name, stats, nodes.size(), err, Time.get_ticks_msec() - t0])
	quit()


func _own(n: Node, root: Node) -> void:
	if n == null:
		return
	n.owner = root
	for c in n.get_children():
		if c.owner == null:
			_own(c, root)


# ------------------------------------------------------------------ binary helpers
func _floats(a: Dictionary) -> PackedFloat32Array:
	var off: int = a.off
	var count: int = int(a.n) * int(a.s)
	return bin.slice(off, off + count * 4).to_float32_array()


func _ints(a: Dictionary) -> PackedInt32Array:
	var off: int = a.off
	return bin.slice(off, off + int(a.n) * 4).to_int32_array()


func _xform(e: Array) -> Transform3D:      # three.js column-major Matrix4 -> Transform3D
	return Transform3D(Basis(Vector3(e[0], e[1], e[2]), Vector3(e[4], e[5], e[6]), Vector3(e[8], e[9], e[10])), Vector3(e[12], e[13], e[14]))


# ------------------------------------------------------------------ nodes
func _node(n: Dictionary, idx: int) -> Node3D:
	var node: Node3D
	cur_order = int(n.get("renderOrder", 0))
	var t: String = n.type
	if n.has("light"):
		node = _light(n)
	elif t == "Sprite" and n.has("geo"):
		node = _sprite(n)
	elif n.has("geo") and n.has("instances"):
		node = _multimesh(n)
	elif n.has("geo"):
		node = _mesh(n)
	else:
		node = Node3D.new()
	if node == null:
		node = Node3D.new()
	node.name = ("%s_%d" % [n.name, idx]) if str(n.name) != "" else "%s_%d" % [t, idx]
	node.transform = _xform(n.matrix)
	node.visible = bool(n.visible)
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if n.get("castShadow", false) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if int(n.get("renderOrder", 0)) != 0:
			(node as GeometryInstance3D).sorting_offset = float(n.renderOrder) * 0.01
	if n.has("userData") and n.userData is Dictionary:
		node.set_meta("v77", n.userData)
	return node


func _mesh_for(gi: int, mats) -> ArrayMesh:
	var key := str(gi) + "|" + str(mats) + "|" + str(cur_order)
	if mesh_cache.has(key):
		return mesh_cache[key]
	var g: Dictionary = m.geometries[gi]
	if not g.has("position"):
		return null
	var pos := _floats(g.position)
	var nv: int = int(g.position.n)
	var verts := PackedVector3Array()
	verts.resize(nv)
	var ps: int = int(g.position.s)
	for i in nv:
		verts[i] = Vector3(pos[i * ps], pos[i * ps + 1], pos[i * ps + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	if g.has("normal"):
		var nr := _floats(g.normal)
		var normals := PackedVector3Array()
		normals.resize(nv)
		for i in nv:
			normals[i] = Vector3(nr[i * 3], nr[i * 3 + 1], nr[i * 3 + 2])
		arrays[Mesh.ARRAY_NORMAL] = normals
	if g.has("uv"):
		var uv := _floats(g.uv)
		var uvs := PackedVector2Array()
		uvs.resize(nv)
		for i in nv:
			uvs[i] = Vector2(uv[i * 2], 1.0 - uv[i * 2 + 1])   # three's UV v runs up; Godot's down
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if g.has("uv2"):
		var uv2 := _floats(g.uv2)
		var uv2s := PackedVector2Array()
		uv2s.resize(nv)
		for i in nv:
			uv2s[i] = Vector2(uv2[i * 2], 1.0 - uv2[i * 2 + 1])
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	if not g.has("uv2") and g.has("extra"):
		for ex in g.extra:
			if str(ex[0]) == "seed":      # v77 puddles: per-vertex seed, carried in UV2.x
				var sd := _floats(ex[1])
				var s2 := PackedVector2Array()
				s2.resize(nv)
				for i in nv:
					s2[i] = Vector2(sd[i], 0.0)
				arrays[Mesh.ARRAY_TEX_UV2] = s2
	if g.has("color"):
		var c := _floats(g.color)
		var cs: int = int(g.color.s)
		var cols := PackedColorArray()
		cols.resize(nv)
		for i in nv:
			cols[i] = Color(c[i * cs], c[i * cs + 1], c[i * cs + 2], c[i * cs + 3] if cs == 4 else 1.0)
		arrays[Mesh.ARRAY_COLOR] = cols
	var index := PackedInt32Array()
	if g.has("index"):
		index = _ints(g.index)
	else:
		index.resize(nv)
		for i in nv:
			index[i] = i
	# three winds counter-clockwise front faces; Godot treats clockwise as front: flip each triangle
	var groups: Array = g.get("groups", [])
	if groups.is_empty():
		groups = [[0, index.size(), 0]]
	var mesh := ArrayMesh.new()
	for gr in groups:
		var start: int = gr[0]
		var count: int = mini(int(gr[1]) if float(gr[1]) < 1e15 else index.size(), index.size() - start)
		var sub := index.slice(start, start + count)
		for k in range(0, sub.size() - 2, 3) if FLIP else []:
			var tmp := sub[k + 1]
			sub[k + 1] = sub[k + 2]
			sub[k + 2] = tmp
		var a2 := arrays.duplicate()
		a2[Mesh.ARRAY_INDEX] = sub
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
		var mi: int = int(gr[2])
		var mat_index = mats[mi] if mats is Array and mi < mats.size() else mats
		if mat_index != null:
			mesh.surface_set_material(mesh.get_surface_count() - 1, _material(int(mat_index), false, g.has("color")))
	mesh_cache[key] = mesh
	return mesh


func _mesh(n: Dictionary) -> Node3D:
	var mesh := _mesh_for(int(n.geo), n.mat)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	stats.meshes += 1
	return mi


## Instanced meshes become one MeshInstance3D per instance sharing the mesh (headless Godot keeps no MultiMesh
## instance data, so a saved MultiMesh would come back empty). Instance colours tint a per-colour material copy.
func _multimesh(n: Dictionary) -> Node3D:
	var mesh := _mesh_for(int(n.geo), n.mat)
	if mesh == null:
		return null
	var group := Node3D.new()
	var count: int = int(n.instances.n)
	var f := bin.slice(int(n.instances.off), int(n.instances.off) + count * 64).to_float32_array()
	var has_col: bool = n.has("instanceColors")
	var cf := PackedFloat32Array()
	if has_col:
		cf = bin.slice(int(n.instanceColors.off), int(n.instanceColors.off) + count * 12).to_float32_array()
	var tinted := {}
	for i in count:
		var mi := MeshInstance3D.new()
		mi.name = "i%d" % i
		mi.mesh = mesh
		mi.transform = _xform(Array(f.slice(i * 16, i * 16 + 16)))
		if has_col:
			var c := Vector3(cf[i * 3], cf[i * 3 + 1], cf[i * 3 + 2])
			var key := "%.4f,%.4f,%.4f" % [c.x, c.y, c.z]
			if not tinted.has(key):
				var mats: Array = []
				for sidx in mesh.get_surface_count():
					var sm := mesh.surface_get_material(sidx) as ShaderMaterial
					if sm:
						var c2: ShaderMaterial = sm.duplicate()
						var base: Vector4 = c2.get_shader_parameter("v_color")
						c2.set_shader_parameter("v_color", Vector4(base.x * c.x, base.y * c.y, base.z * c.z, base.w))
						mats.append(c2)
					else:
						mats.append(null)
				tinted[key] = mats
			var ms: Array = tinted[key]
			for sidx in ms.size():
				if ms[sidx]:
					mi.set_surface_override_material(sidx, ms[sidx])
		group.add_child(mi)
	stats.multimesh += count
	return group


func _sprite(n: Dictionary) -> Node3D:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mat := _material(int(n.mat), true, false)
	if mat == null:
		return null
	var sm: ShaderMaterial = mat.duplicate()
	var c: Array = n.get("center", [0.5, 0.5])
	sm.set_shader_parameter("v_sprite_center", Vector2(c[0], c[1]))
	q.material = sm
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	stats.sprites += 1
	return mi


func _light(n: Dictionary) -> Node3D:
	var L: Dictionary = n.light
	var col := Color(L.color[0], L.color[1], L.color[2]).linear_to_srgb() if L.color else Color.WHITE
	match str(L.type):
		"DirectionalLight":
			var d := DirectionalLight3D.new()
			d.light_color = col
			d.light_energy = float(L.intensity)
			d.shadow_enabled = bool(L.castShadow)
			d.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			d.directional_shadow_max_distance = 180.0
			d.shadow_bias = 0.04
			d.shadow_normal_bias = 1.0
			d.set_meta("v77_target", L.target)
			stats.lights += 1
			return d
		"PointLight":
			var o := OmniLight3D.new()
			o.light_color = col
			o.light_energy = float(L.intensity)
			o.omni_range = float(L.distance) if float(L.distance) > 0.0 else 4096.0
			o.omni_attenuation = 0.0
			o.shadow_enabled = false
			o.set_meta("v77_decay", L.decay)
			stats.lights += 1
			return o
		"HemisphereLight":
			var h := Node3D.new()
			h.set_meta("v77_hemi", [L.color, L.groundColor, L.intensity])
			stats.lights += 1
			return h
		"SpotLight":
			var s := SpotLight3D.new()
			s.light_color = col
			s.light_energy = float(L.intensity)
			s.spot_range = float(L.distance) if float(L.distance) > 0.0 else 4096.0
			s.spot_angle = rad_to_deg(float(L.angle))
			s.spot_attenuation = 0.0
			stats.lights += 1
			return s
	return Node3D.new()


# ------------------------------------------------------------------ textures
func _texture(id) -> Texture2D:
	if id == null:
		return null
	var key := int(id)
	if tex_cache.has(key):
		return tex_cache[key]
	var path := out + "tex/%d.png" % key
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex == null:
		push_warning("missing texture %d (run the prepare pass and --import first)" % key)
	tex_cache[key] = tex
	return tex


## Pass 1: every texture as a PNG under res:// (flipped where three uploads unflipped) with an import file asking
## for lossless + mipmaps. Godot imports them before pass 2 builds the scene.
func _prepare() -> void:
	for t in m.textures:
		if not t.file:
			continue
		var img := Image.load_from_file(base + str(t.file))
		if img == null:
			continue
		if bool(t.get("flipY", true)) == false:
			img.flip_y()
		var png := out + "tex/%d.png" % int(t.id)
		img.save_png(png)
		var imp := FileAccess.open(png + ".import", FileAccess.WRITE)
		var mips := "true" if t.get("mips", true) else "false"
		imp.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=" + mips + "\nprocess/fix_alpha_border=true\ndetect_3d/compress_to=0\n")
		imp.close()
	print("prepared %d textures" % m.textures.size())


func _uv_matrix(id) -> Basis:
	# three's texture.matrix maps (u, v) -> (u', v'); with v flipped on import: v_g = 1 - v
	if id == null:
		return Basis()
	var e: Array = m.textures[int(id)].uvMatrix
	# three Matrix3 column-major: [a d g ; b e h ; c f i]
	var a: float = e[0]; var b: float = e[1]; var d: float = e[3]; var ee: float = e[4]; var g: float = e[6]; var h: float = e[7]
	# u' = a u + d v + g ; v' = b u + e v + h ; with v = 1 - vg and vg' = 1 - v'
	var u_u := a
	var u_v := -d
	var u_c := d + g
	var v_u := -b
	var v_v := ee
	var v_c := 1.0 - (ee + h)
	return Basis(Vector3(u_u, v_u, 0), Vector3(u_v, v_v, 0), Vector3(u_c, v_c, 1))


# ------------------------------------------------------------------ materials
func _shader(unshaded: bool, sprite: bool, e: Dictionary) -> Shader:
	var modes: Array[String] = []
	var blending: int = int(e.get("blending", 1))
	var transparent: bool = e.get("transparent", false) or float(e.get("opacity", 1.0)) < 1.0 or e.get("depthWrite", true) == false
	if blending == 2:
		modes.append("blend_add")
	elif blending == 5 or blending == 4:
		modes.append("blend_premul_alpha")
	elif blending == 3:
		modes.append("blend_sub")
	match int(e.get("side", 0)):
		1: modes.append("cull_front")
		2: modes.append("cull_disabled")
		_: modes.append("cull_back")
	if transparent and e.get("depthWrite", true):
		modes.append("depth_draw_always")
	elif transparent or not e.get("depthWrite", true):
		modes.append("depth_draw_never")
	if e.get("depthTest", true) == false:
		modes.append("depth_test_disabled")
	if unshaded:
		modes.append("unshaded")
	if not e.get("fog", true):
		modes.append("fog_disabled")
	var key := ",".join(modes) + ("|S" if sprite else "") + ("|U" if unshaded else "") + ("|T" if transparent or blending != 1 else "")
	if shader_cache.has(key):
		return shader_cache[key]
	var code := "shader_type spatial;\nrender_mode %s;\n" % ", ".join(modes)
	if transparent or blending != 1:
		code += "#define V77_TRANSPARENT\n"
	if unshaded:
		code += "#define V77_UNSHADED\n"
	if sprite:
		code += "#define V77_SPRITE\n"
	code += "#include \"res://shaders/v77_material.gdshaderinc\"\n"
	var path := "res://assets/baked/shaders/v77_%d.gdshader" % shader_cache.size()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(code)
	f.close()
	var sh := Shader.new()
	sh.code = code
	sh.resource_path = path
	shader_cache[key] = sh
	return sh


func _material(idx: int, sprite: bool, has_vcol: bool) -> Material:
	var key := "%d|%s|%d" % [idx, sprite, cur_order]
	if mat_cache.has(key):
		return mat_cache[key]
	var e: Dictionary = m.materials[idx]
	var t: String = e.type
	if t == "ShaderMaterial":
		var sm := _manual(e)
		mat_cache[key] = sm
		return sm
	var unshaded := t == "MeshBasicMaterial" or t == "SpriteMaterial" or t == "MeshLambertMaterial" and false
	var mat := ShaderMaterial.new()
	mat.shader = _shader(unshaded, sprite or t == "SpriteMaterial", e)
	var c: Array = e.color if e.color else [1, 1, 1]
	mat.set_shader_parameter("v_color", Vector4(c[0], c[1], c[2], float(e.get("opacity", 1.0))))
	mat.set_shader_parameter("v_vertex_colors", bool(e.get("vertexColors", false)) and has_vcol)
	if e.get("map") != null:
		mat.set_shader_parameter("v_use_map", true)
		mat.set_shader_parameter("v_map", _texture(e.map))
		mat.set_shader_parameter("v_map_srgb", int(m.textures[int(e.map)].encoding) == 3001)
		mat.set_shader_parameter("v_map_uv", _uv_matrix(e.map))
	if e.get("alphaMap") != null:
		mat.set_shader_parameter("v_use_alpha_map", true)
		mat.set_shader_parameter("v_alpha_map", _texture(e.alphaMap))
		mat.set_shader_parameter("v_alpha_uv", _uv_matrix(e.alphaMap))
	mat.set_shader_parameter("v_alpha_test", float(e.get("alphaTest", 0.0)))
	var em: Array = e.emissive if e.get("emissive") else [0, 0, 0]
	var ei := float(e.get("emissiveIntensity", 1.0)) if e.get("emissiveIntensity") != null else 1.0
	mat.set_shader_parameter("v_emissive", Vector3(em[0], em[1], em[2]) * ei)
	if e.get("emissiveMap") != null:
		mat.set_shader_parameter("v_use_emissive_map", true)
		mat.set_shader_parameter("v_emissive_map", _texture(e.emissiveMap))
		mat.set_shader_parameter("v_emissive_map_srgb", int(m.textures[int(e.emissiveMap)].encoding) == 3001)
		mat.set_shader_parameter("v_emissive_uv", _uv_matrix(e.emissiveMap))
	if not unshaded:
		mat.set_shader_parameter("v_roughness", float(e.get("roughness", 1.0)) if e.get("roughness") != null else 1.0)
		mat.set_shader_parameter("v_metalness", float(e.get("metalness", 0.0)) if e.get("metalness") != null else 0.0)
		if e.get("roughnessMap") != null:
			mat.set_shader_parameter("v_use_rough_map", true)
			mat.set_shader_parameter("v_rough_map", _texture(e.roughnessMap))
			mat.set_shader_parameter("v_rough_uv", _uv_matrix(e.roughnessMap))
		if e.get("metalnessMap") != null:
			mat.set_shader_parameter("v_use_metal_map", true)
			mat.set_shader_parameter("v_metal_map", _texture(e.metalnessMap))
		if e.get("normalMap") != null:
			mat.set_shader_parameter("v_use_normal_map", true)
			mat.set_shader_parameter("v_normal_map", _texture(e.normalMap))
			mat.set_shader_parameter("v_normal_uv", _uv_matrix(e.normalMap))
			var ns: Array = e.normalScale if e.get("normalScale") else [1, 1]
			mat.set_shader_parameter("v_normal_scale", Vector2(ns[0], -float(ns[1])))
		if e.get("clearcoat") != null:
			mat.set_shader_parameter("v_clearcoat", float(e.clearcoat))
			mat.set_shader_parameter("v_clearcoat_roughness", float(e.get("clearcoatRoughness", 0.0)))
	if e.get("lightMap") != null:
		mat.set_shader_parameter("v_use_light_map", true)
		mat.set_shader_parameter("v_light_map", _texture(e.lightMap))
		mat.set_shader_parameter("v_light_map_intensity", float(e.get("lightMapIntensity", 1.0)))
	mat.set_shader_parameter("v_fog", bool(e.get("fog", true)))
	if t == "SpriteMaterial":
		mat.set_shader_parameter("v_sprite_rotation", float(e.get("rotation", 0.0)))
		mat.set_shader_parameter("v_size_attenuation", bool(e.get("sizeAttenuation", true)))
	# onBeforeCompile patches, from what each patch injected into a stand-in shader
	var po = e.get("patchOut")
	if po is Dictionary and not po.has("error"):
		var fs: String = po.get("fs", "")
		var u: Dictionary = po.get("uniforms", {})
		if u.has("uClipA"):
			var A: Array = u.uClipA
			var B: Array = u.uClipB
			var Y: Array = u.uClipY
			var n := mini(A.size(), 48)
			var pa := PackedVector4Array()
			var pb := PackedVector4Array()
			var py := PackedFloat32Array()
			pa.resize(48); pb.resize(48); py.resize(48)
			for i in n:
				pa[i] = Vector4(A[i][0], A[i][1], A[i][2], A[i][3])
				pb[i] = Vector4(B[i][0], B[i][1], B[i][2], B[i][3])
				py[i] = float(Y[i])
			mat.set_shader_parameter("v_clip_count", n)
			mat.set_shader_parameter("v_clip_a", pa)
			mat.set_shader_parameter("v_clip_b", pb)
			mat.set_shader_parameter("v_clip_y", py)
		var rx := RegEx.create_from_string("vec3\\(1\\.07,\\.97,\\.85\\),([0-9.]+)\\)")
		var r := rx.search(fs)
		if r:
			mat.set_shader_parameter("v_neutral", float(r.get_string(1)))
		if fs.contains("gl_FragColor.rgb*gl_FragColor.a"):
			mat.set_shader_parameter("v_premultiply", true)
	mat.render_priority = clampi(cur_order, -128, 127)
	mat_cache[key] = mat
	return mat


## v77's hand-written ShaderMaterials: matched by their fragment code to the Godot ports in shaders/manual/.
func _manual(e: Dictionary) -> Material:
	var fs: String = e.get("fragmentShader", "")
	var name := ""
	if fs.contains("crater("):
		name = "planet"
	elif fs.contains("bands=") and fs.contains("uT*.012"):
		name = "planet_clouds"
	elif fs.contains("vec3(.3,.55,1.)*g*"):
		name = "planet_rim"
	elif fs.contains("iri=.5+.5*cos"):
		name = "puddle"
	elif fs.contains("shock=1.+"):
		name = "jet_plume"
	var path := "res://shaders/manual/%s.gdshader" % name
	if name == "" or not ResourceLoader.exists(path):
		stats.skipped[name if name != "" else fs.substr(0, 40)] = stats.skipped.get(name, 0) + 1
		var hide := StandardMaterial3D.new()
		hide.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hide.albedo_color = Color(0, 0, 0, 0)
		return hide
	var sm := ShaderMaterial.new()
	sm.shader = load(path)
	for k in e.get("uniforms", {}):
		var u = e.uniforms[k]
		if u is Dictionary:
			if u.has("v"):
				sm.set_shader_parameter(k, u.v)
			elif u.has("vec"):
				var v: Array = u.vec
				sm.set_shader_parameter(k, Vector3(v[0], v[1], v[2]) if v.size() == 3 else Vector2(v[0], v[1]))
			elif u.has("color"):
				sm.set_shader_parameter(k, Vector3(u.color[0], u.color[1], u.color[2]))
	return sm
