extends SceneTree

const MAIN_SCENE_PATH := "res://scene1.tscn"
const ISLAND_SCENE_PATH := "res://TripoModels/floating_island_3d_model_1/floating_island_3d_model_1.fbx"
const ISLAND_PREFIX := "floating_island_3d_model_"

## 角色胶囊高约 1.4m；路线岛 scale≈7；model_1 网格较小，景观岛 scale 14–26
const SCALE_MIN := 14.0
const SCALE_MAX := 26.0

## [pos, scale, rot_y] — 环绕主路线、高低错落，增强飞行巡游层次感
const PLACEMENTS: Array = [
	{"name": "floating_island_3d_model_2", "pos": Vector3(-58.0, 22.0, 30.0), "scale": 22.0, "rot_y": 0.8},
	{"name": "floating_island_3d_model_3", "pos": Vector3(65.0, 30.0, -20.0), "scale": 18.0, "rot_y": 2.1},
	{"name": "floating_island_3d_model_4", "pos": Vector3(10.0, -12.0, 62.0), "scale": 20.0, "rot_y": 4.5},
	{"name": "floating_island_3d_model_5", "pos": Vector3(-70.0, 8.0, -45.0), "scale": 24.0, "rot_y": 1.2},
	{"name": "floating_island_3d_model_6", "pos": Vector3(48.0, 15.0, 35.0), "scale": 16.0, "rot_y": 3.7},
	{"name": "floating_island_3d_model_7", "pos": Vector3(-35.0, -8.0, 65.0), "scale": 17.0, "rot_y": 5.0},
	{"name": "floating_island_3d_model_8", "pos": Vector3(0.0, 35.0, -55.0), "scale": 15.0, "rot_y": 0.3},
	{"name": "floating_island_3d_model_9", "pos": Vector3(-50.0, 12.0, 10.0), "scale": 19.0, "rot_y": 2.8},
	{"name": "floating_island_3d_model_10", "pos": Vector3(72.0, -6.0, 48.0), "scale": 21.0, "rot_y": 1.6},
	{"name": "floating_island_3d_model_11", "pos": Vector3(-20.0, 28.0, -68.0), "scale": 23.0, "rot_y": 4.0},
]


func _init() -> void:
	var scene_res := load(MAIN_SCENE_PATH) as PackedScene
	if scene_res == null:
		printerr("[ERROR] Failed to load main scene")
		quit(1)
		return

	var island_scene := load(ISLAND_SCENE_PATH) as PackedScene
	if island_scene == null:
		printerr("[ERROR] Failed to load island scene: ", ISLAND_SCENE_PATH)
		quit(1)
		return

	var root := scene_res.instantiate()
	_remove_orphan_islands(root)
	_place_scenery_islands(root, island_scene)
	_save_scene(root)
	print("[INFO] Scenery islands placed (%d instances)" % PLACEMENTS.size())
	quit()


func _remove_orphan_islands(root: Node) -> void:
	for child in root.get_children():
		if child.name == "floating_island_3d_model_1":
			child.free()
			print("[INFO] Removed orphan floating_island_3d_model_1")
		elif child.name.begins_with(ISLAND_PREFIX) and child.name != "floating_island_3d_model":
			var found := false
			for p in PLACEMENTS:
				if p["name"] == child.name:
					found = true
					break
			if not found:
				child.free()
				print("[INFO] Removed unlisted %s" % child.name)


func _place_scenery_islands(root: Node, island_scene: PackedScene) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260618

	for placement in PLACEMENTS:
		var island_name: String = placement["name"]
		var pos: Vector3 = placement["pos"]
		var base_scale: float = placement["scale"]
		var rot_y: float = placement["rot_y"]

		var scale_jitter := rng.randf_range(-1.5, 1.5)
		var scale_val := clampf(base_scale + scale_jitter, SCALE_MIN, SCALE_MAX)
		rot_y += rng.randf_range(-0.25, 0.25)

		var island := root.get_node_or_null(island_name)
		if island == null:
			island = island_scene.instantiate() as Node3D
			island.name = island_name
			root.add_child(island)
			island.owner = root
			print("[INFO] Created %s" % island_name)
		else:
			print("[INFO] Repositioned %s" % island_name)

		island.transform = _make_transform(pos, scale_val, rot_y)
		print("  pos=%s scale=%.1f rot_y=%.2f" % [pos, scale_val, rot_y])


func _make_transform(pos: Vector3, scale_val: float, rot_y: float) -> Transform3D:
	var basis := Basis.IDENTITY.scaled(Vector3.ONE * scale_val)
	basis = basis.rotated(Vector3.UP, rot_y)
	return Transform3D(basis, pos)


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
