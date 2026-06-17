extends SceneTree

const SCENE_PATH := "res://scene1.tscn"
const ISLAND_SCENE_PATH := "res://TripoModels/floating_island_3d_model/floating_island_3d_model.fbx"
const DUPLICATE_COUNT := 10


func _init() -> void:
	var scene_res := load(SCENE_PATH) as PackedScene
	if scene_res == null:
		printerr("[ERROR] Failed to load scene: ", SCENE_PATH)
		quit(1)
		return

	var root := scene_res.instantiate()
	var island_scene := load(ISLAND_SCENE_PATH) as PackedScene
	if island_scene == null:
		printerr("[ERROR] Failed to load island scene: ", ISLAND_SCENE_PATH)
		quit(1)
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in DUPLICATE_COUNT:
		var island := island_scene.instantiate() as Node3D
		island.name = "floating_island_%02d" % (i + 1)

		var pos := Vector3(
			rng.randf_range(-45.0, 45.0),
			rng.randf_range(-8.0, 28.0),
			rng.randf_range(-45.0, 45.0)
		)
		var scale_value := rng.randf_range(0.35, 1.75)

		island.position = pos
		island.scale = Vector3.ONE * scale_value
		island.rotation.y = rng.randf_range(0.0, TAU)

		root.add_child(island)
		island.owner = root
		print("[INFO] Added %s | pos=%s | scale=%.2f | rot_y=%.2f" % [
			island.name, pos, scale_value, island.rotation.y
		])

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		printerr("[ERROR] Failed to pack scene")
		quit(1)
		return

	if ResourceSaver.save(packed, SCENE_PATH) != OK:
		printerr("[ERROR] Failed to save scene")
		quit(1)
		return

	print("[INFO] Successfully duplicated %d floating islands into %s" % [DUPLICATE_COUNT, SCENE_PATH])
	quit()
