extends SceneTree

const MAIN_SCENE_PATH := "res://scene1.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player.tscn"


func _init() -> void:
	_refresh_player_instance()
	print("[INFO] Dragon player refreshed in main scene")
	quit()


func _refresh_player_instance() -> void:
	var scene_res := load(MAIN_SCENE_PATH) as PackedScene
	if scene_res == null:
		printerr("[ERROR] Failed to load main scene")
		quit(1)
		return

	var root := scene_res.instantiate()
	var old_player := root.get_node_or_null("Player")
	if old_player:
		root.remove_child(old_player)
		old_player.free()

	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		printerr("[ERROR] Failed to load dragon scene")
		quit(1)
		return

	var dragon := player_scene.instantiate()
	dragon.name = "Player"
	root.add_child(dragon)
	dragon.owner = root
	dragon.position = Vector3(0.0, 12.0, 0.0)

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		printerr("[ERROR] Failed to pack scene")
		quit(1)
		return
	if ResourceSaver.save(packed, MAIN_SCENE_PATH) != OK:
		printerr("[ERROR] Failed to save scene")
		quit(1)
		return
