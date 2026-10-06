extends SceneTree
func _init() -> void:
	var city: Node = load("res://assets/baked/city/city.scn").instantiate()
	for n in city.find_children("*", "MeshInstance3D", true, false):
		if str(n.name) in ["Mesh_107", "Mesh_117"] or str(n.get_parent().name) == "Mesh_117":
			var mesh: Mesh = n.mesh
			var mat := mesh.surface_get_material(0) as ShaderMaterial
			print(n.name, " parent ", n.get_parent().name, " vis ", n.visible, " aabb ", mesh.get_aabb(), " verts ", mesh.surface_get_array_len(0), " idx ", mesh.surface_get_array_index_len(0), " shader ", mat.shader.resource_path.get_file(), " col ", mat.get_shader_parameter("v_color"), " vcol ", mat.get_shader_parameter("v_vertex_colors"), " xf ", n.global_transform.origin if n.is_inside_tree() else n.transform.origin)
	quit()
