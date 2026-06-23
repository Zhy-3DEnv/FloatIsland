extends Node

const MAIN_SCENE_PATH := "res://scene1.tscn"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_res := load(MAIN_SCENE_PATH) as PackedScene
	if scene_res == null:
		push_error("Failed to load main scene")
		get_tree().quit(1)
		return

	var root := scene_res.instantiate()
	var setup := preload("res://scripts/m1_scene_setup.gd").new()
	setup.apply_to_scene(root)
	_save_scene(root)
	print("[INFO] M1 scene setup complete")
	get_tree().quit()


func _save_scene(root: Node) -> void:
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("Failed to pack scene")
		get_tree().quit(1)
		return
	if ResourceSaver.save(packed, MAIN_SCENE_PATH) != OK:
		push_error("Failed to save scene")
		get_tree().quit(1)
		return
