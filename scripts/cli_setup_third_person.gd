extends SceneTree

const MAIN_SCENE_PATH := "res://scene1.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player.tscn"


func _init() -> void:
	_add_player_to_main_scene()
	_add_island_collisions()
	_set_main_scene()
	print("[INFO] Third-person player setup complete")
	quit()


func _add_player_to_main_scene() -> void:
	var scene_res := load(MAIN_SCENE_PATH) as PackedScene
	if scene_res == null:
		printerr("[ERROR] Failed to load main scene")
		quit(1)
		return

	var root := scene_res.instantiate()
	if root.get_node_or_null("Player") != null:
		print("[INFO] Player already exists in main scene, skipping")
		_save_scene(root)
		return

	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		printerr("[ERROR] Failed to load player scene")
		quit(1)
		return

	var player := player_scene.instantiate()
	player.name = "Player"
	root.add_child(player)
	player.owner = root
	_save_scene(root)
	print("[INFO] Player added to main scene")


func _add_island_collisions() -> void:
	var scene_res := load(MAIN_SCENE_PATH) as PackedScene
	var root := scene_res.instantiate()
	var collision_count := 0

	for child in root.get_children():
		if not str(child.name).contains("floating_island"):
			continue
		if child.get_node_or_null("IslandCollision") != null:
			continue
		collision_count += _create_collision_for_node(child, root)

	_save_scene(root)
	print("[INFO] Added collision to %d islands" % collision_count)


func _create_collision_for_node(island: Node, scene_root: Node) -> int:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(island, meshes)
	if meshes.is_empty():
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

	return 1


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)


func _set_main_scene() -> void:
	ProjectSettings.set_setting("application/run/main_scene", MAIN_SCENE_PATH)
	ProjectSettings.save()
	print("[INFO] Main scene set to %s" % MAIN_SCENE_PATH)


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
