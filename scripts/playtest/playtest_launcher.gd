extends Node

const MAIN_SCENE := "res://scene1.tscn"
const DRIVER_SCRIPT_PATH := "res://scripts/playtest/playtest_driver.gd"


func _ready() -> void:
	call_deferred("_boot")


func _boot() -> void:
	var err := get_tree().change_scene_to_file(MAIN_SCENE)
	if err != OK:
		push_error("Playtest: 无法加载主场景 (%s)" % err)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var root := get_tree().current_scene
	if root == null:
		push_error("Playtest: 主场景为空")
		return
	var driver_script: GDScript = load(DRIVER_SCRIPT_PATH)
	var driver: Node = driver_script.new()
	driver.name = "PlaytestDriver"
	root.add_child(driver)
