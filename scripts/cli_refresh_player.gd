extends SceneTree

const MAIN_SCENE_PATH := "res://scene1.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player.tscn"


func _init() -> void:
	var scene_res := load(MAIN_SCENE_PATH) as PackedScene
	var root := scene_res.instantiate()

	var old_player := root.get_node_or_null("Player")
	var spawn_pos := Vector3(0.0, 25.0, 0.0)
	if old_player:
		spawn_pos = old_player.position
		old_player.free()

	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var player := player_scene.instantiate()
	player.name = "Player"
	player.position = spawn_pos
	root.add_child(player)
	player.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, MAIN_SCENE_PATH)
	print("[INFO] Player replaced with Character + Dragon split scene")
	quit()
