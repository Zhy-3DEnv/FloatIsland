extends SceneTree

const MAIN_SCENE_PATH := "res://scene1.tscn"
const STAR_SCENE_PATH := "res://scenes/star.tscn"
const STAR_HEIGHT_OFFSET := 4.0

## 将景观岛穿插进巡游路线，形成绕场飞行
const ROUTE: Array[String] = [
	"floating_island_3d_model",
	"floating_island_05",
	"floating_island_3d_model_9",
	"floating_island_06",
	"floating_island_3d_model_2",
	"floating_island_01",
	"floating_island_3d_model_8",
	"floating_island_09",
	"floating_island_08",
	"floating_island_3d_model_11",
	"floating_island_07",
	"floating_island_04",
	"floating_island_03",
	"floating_island_3d_model_3",
	"floating_island_10",
	"floating_island_3d_model_6",
	"floating_island_02",
	"floating_island_3d_model_4",
	"floating_island_3d_model_7",
	"floating_island_3d_model_5",
	"floating_island_3d_model_10",
]

const SCENERY_ISLANDS: Array[String] = [
	"floating_island_3d_model_2",
	"floating_island_3d_model_3",
	"floating_island_3d_model_4",
	"floating_island_3d_model_5",
	"floating_island_3d_model_6",
	"floating_island_3d_model_7",
	"floating_island_3d_model_8",
	"floating_island_3d_model_9",
	"floating_island_3d_model_10",
	"floating_island_3d_model_11",
]


func _init() -> void:
	var scene_res := load(MAIN_SCENE_PATH) as PackedScene
	if scene_res == null:
		printerr("[ERROR] Failed to load main scene")
		quit(1)
		return

	var root := scene_res.instantiate()
	var collision_count := _add_island_collisions(root)
	_ensure_stars(root)
	_rebuild_path_markers(root)
	_save_scene(root)
	print("[INFO] Collision added to %d islands, stars & path updated" % collision_count)
	quit()


func _add_island_collisions(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if not str(child.name).contains("floating_island"):
			continue
		if child.get_node_or_null("IslandCollision") != null:
			continue
		count += _create_collision_for_node(child, root)
	return count


func _create_collision_for_node(island: Node, scene_root: Node) -> int:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(island, meshes)
	if meshes.is_empty():
		printerr("[WARN] No mesh found for %s" % island.name)
		return 0

	var static_body := StaticBody3D.new()
	static_body.name = "IslandCollision"
	island.add_child(static_body)
	static_body.owner = scene_root

	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue
		var shape := mesh_instance.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = mesh_instance.transform
		static_body.add_child(collision)
		collision.owner = scene_root

	print("[INFO] Collision -> %s" % island.name)
	return 1


func _ensure_stars(root: Node) -> void:
	var route_root := root.get_node_or_null("RouteStars")
	if route_root == null:
		route_root = Node3D.new()
		route_root.name = "RouteStars"
		root.add_child(route_root)
		route_root.owner = root

	var star_scene := load(STAR_SCENE_PATH) as PackedScene
	for island_name in ROUTE.slice(1):
		var island := root.get_node_or_null(island_name)
		if island == null:
			printerr("[WARN] Island not found: %s" % island_name)
			continue

		var star_name := "Star_%s" % island_name
		var star := route_root.get_node_or_null(star_name)
		if star == null:
			star = star_scene.instantiate()
			star.name = star_name
			route_root.add_child(star)
			star.owner = root
			print("[INFO] Star created -> %s" % island_name)

		star.set("island_name", island_name)
		star.position = _star_position_for_island(island as Node3D)

	# 移除已不在路线中的旧星星
	for star in route_root.get_children():
		if not star.name.begins_with("Star_"):
			continue
		var island_name: String = star.get("island_name")
		if island_name not in ROUTE:
			star.free()
			print("[INFO] Removed orphan star %s" % star.name)


func _star_position_for_island(island: Node3D) -> Vector3:
	var top_y := island.position.y
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(island, meshes)
	for mi in meshes:
		if mi.mesh == null:
			continue
		var aabb := mi.mesh.get_aabb()
		for i in 8:
			var world := island.global_transform * mi.transform * aabb.get_endpoint(i)
			top_y = maxf(top_y, world.y)
	return Vector3(island.position.x, top_y + STAR_HEIGHT_OFFSET, island.position.z)


func _rebuild_path_markers(root: Node) -> void:
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

	for i in range(ROUTE.size() - 1):
		var from_node := root.get_node_or_null(ROUTE[i])
		var to_node := root.get_node_or_null(ROUTE[i + 1])
		if from_node == null or to_node == null:
			continue
		var from_pos: Vector3 = _star_position_for_island(from_node as Node3D) * 0.6 + from_node.position * 0.4
		var to_pos: Vector3 = _star_position_for_island(to_node as Node3D) * 0.6 + to_node.position * 0.4
		from_pos.y = maxf(from_pos.y, from_node.position.y + STAR_HEIGHT_OFFSET * 0.6)
		to_pos.y = maxf(to_pos.y, to_node.position.y + STAR_HEIGHT_OFFSET * 0.6)
		_add_path_segment(markers, from_pos, to_pos, mat, i, root)


func _add_path_segment(
	parent: Node3D,
	from_pos: Vector3,
	to_pos: Vector3,
	mat: StandardMaterial3D,
	index: int,
	scene_root: Node
) -> void:
	var segment := MeshInstance3D.new()
	segment.name = "PathSegment_%02d" % index
	parent.add_child(segment)
	segment.owner = scene_root

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	var steps := 16
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var pos := from_pos.lerp(to_pos, t)
		pos.y += sin(t * PI) * (STAR_HEIGHT_OFFSET * 0.35)
		mesh.surface_add_vertex(pos)
	mesh.surface_end()
	segment.mesh = mesh


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)


func _save_scene(root: Node) -> void:
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		printerr("[ERROR] Failed to pack scene")
		quit(1)
		return
	if ResourceSaver.save(packed, MAIN_SCENE_PATH) != OK:
		printerr("[ERROR] Failed to save scene")
		quit(1)
		return
