extends SceneTree

const MAIN_SCENE_PATH := "res://scene1.tscn"


func _init() -> void:
	var scene_res := load(MAIN_SCENE_PATH) as PackedScene
	if scene_res == null:
		printerr("[ERROR] Failed to load main scene")
		quit(1)
		return

	var root := scene_res.instantiate()
	var setup := M1SceneSetup.new()
	setup.apply_full_layout(root)
	_save_scene(root)
	print("[INFO] M1 island layout, rings and wind volumes updated")
	quit()


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
