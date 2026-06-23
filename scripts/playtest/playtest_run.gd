extends SceneTree

## 带窗口试玩入口：加载主场景并挂载 PlaytestDriver。

const MAIN_SCENE := "res://scene1.tscn"
const DRIVER_SCRIPT_PATH := "res://scripts/playtest/playtest_driver.gd"


func _init() -> void:
	scene_changed.connect(_on_scene_changed)
	call_deferred("_start")


func _start() -> void:
	change_scene_to_file(MAIN_SCENE)


func _on_scene_changed() -> void:
	call_deferred("_attach_driver")


func _attach_driver() -> void:
	if current_scene == null:
		push_error("Playtest: 主场景为空")
		quit(1)
		return
	if current_scene.get_node_or_null("PlaytestDriver"):
		return
	var driver_script: GDScript = load(DRIVER_SCRIPT_PATH)
	if driver_script == null:
		push_error("Playtest: 无法加载驱动脚本")
		quit(1)
		return
	var driver: Node = driver_script.new()
	driver.name = "PlaytestDriver"
	current_scene.add_child(driver)
