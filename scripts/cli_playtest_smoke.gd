extends SceneTree

## 无头冒烟：加载主场景 + 试玩驱动，跑数秒物理帧后退出（0=通过）。

const MAIN_SCENE := "res://scene1.tscn"
const DRIVER_SCRIPT_PATH := "res://scripts/playtest/playtest_driver.gd"
const RUN_SECONDS := 6.0


func _init() -> void:
	call_deferred("_boot")


func _boot() -> void:
	var scene_res := load(MAIN_SCENE) as PackedScene
	if scene_res == null:
		push_error("[playtest-smoke] 无法加载主场景")
		quit(1)
		return
	var root := scene_res.instantiate()
	root.name = "Scene1"
	get_root().add_child(root)
	var driver_script: GDScript = load(DRIVER_SCRIPT_PATH)
	var driver: Node = driver_script.new()
	driver.name = "PlaytestDriver"
	root.add_child(driver)

	var watchdog := Timer.new()
	watchdog.wait_time = RUN_SECONDS
	watchdog.one_shot = true
	watchdog.timeout.connect(func() -> void:
		print("[playtest-smoke] OK (%.1fs)" % RUN_SECONDS)
		quit(0)
	)
	root.add_child(watchdog)
	watchdog.start()
