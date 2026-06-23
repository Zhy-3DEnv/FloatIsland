extends SceneTree

const MAIN_SCENE_PATH := "res://scene1.tscn"
const STAR_HEIGHT_OFFSET := 4.0


func _init() -> void:
	var scene_res := load(MAIN_SCENE_PATH) as PackedScene
	var root := scene_res.instantiate()
	_reposition_stars(root)
	_rebuild_path_markers(root)
	_save_scene(root)
	print("[INFO] Stars lowered to offset %.1f" % STAR_HEIGHT_OFFSET)
	quit()


func _reposition_stars(root: Node) -> void:
	var route_root := root.get_node_or_null("RouteStars")
	if route_root == null:
		return
	for star in route_root.get_children():
		if not star.name.begins_with("Star_"):
			continue
		var island_name: String = star.get("island_name")
		var island := root.get_node_or_null(island_name)
		if island == null:
			continue
		star.position = island.position + Vector3(0.0, STAR_HEIGHT_OFFSET, 0.0)


func _rebuild_path_markers(root: Node) -> void:
	var route := [
		"floating_island_3d_model", "floating_island_05", "floating_island_3d_model_9",
		"floating_island_06", "floating_island_3d_model_2", "floating_island_01",
		"floating_island_3d_model_8", "floating_island_09", "floating_island_08",
		"floating_island_3d_model_11", "floating_island_07", "floating_island_04",
		"floating_island_03", "floating_island_3d_model_3", "floating_island_10",
		"floating_island_3d_model_6", "floating_island_02", "floating_island_3d_model_4",
		"floating_island_3d_model_7", "floating_island_3d_model_5", "floating_island_3d_model_10",
	]
	var markers := root.get_node_or_null("RouteMarkers")
	if markers:
		markers.free()
	markers = Node3D.new()
	markers.name = "RouteMarkers"
	root.add_child(markers)
	markers.owner = root

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.85, 1.0, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.7, 1.0)
	mat.emission_energy_multiplier = 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i in range(route.size() - 1):
		var from_node := root.get_node_or_null(route[i])
		var to_node := root.get_node_or_null(route[i + 1])
		if from_node == null or to_node == null:
			continue
		var from_pos: Vector3 = from_node.position + Vector3(0.0, STAR_HEIGHT_OFFSET * 0.8, 0.0)
		var to_pos: Vector3 = to_node.position + Vector3(0.0, STAR_HEIGHT_OFFSET * 0.8, 0.0)
		var segment := MeshInstance3D.new()
		segment.name = "PathSegment_%02d" % i
		markers.add_child(segment)
		segment.owner = root
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
		for step in range(17):
			var t := float(step) / 16.0
			var pos := from_pos.lerp(to_pos, t)
			pos.y += sin(t * PI) * (STAR_HEIGHT_OFFSET * 0.5)
			mesh.surface_add_vertex(pos)
		mesh.surface_end()
		segment.mesh = mesh


func _save_scene(root: Node) -> void:
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, MAIN_SCENE_PATH)
