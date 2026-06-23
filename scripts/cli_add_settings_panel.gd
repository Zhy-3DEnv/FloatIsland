extends SceneTree

const MAIN_SCENE_PATH := "res://scene1.tscn"
const HUD_SCENE_PATH := "res://scenes/game_hud.tscn"
const SETTINGS_PANEL_PATH := "res://scenes/settings_panel.tscn"


func _init() -> void:
	var scene_res := load(MAIN_SCENE_PATH) as PackedScene
	if scene_res == null:
		printerr("[ERROR] Failed to load main scene")
		quit(1)
		return

	var root := scene_res.instantiate()
	var hud := root.get_node_or_null("GameHUD")
	if hud == null:
		var hud_scene := load(HUD_SCENE_PATH) as PackedScene
		hud = hud_scene.instantiate()
		hud.name = "GameHUD"
		root.add_child(hud)
		hud.owner = root
		print("[INFO] GameHUD added to main scene")

	if hud.get_node_or_null("SettingsPanel") == null:
		var panel_scene := load(SETTINGS_PANEL_PATH) as PackedScene
		var panel := panel_scene.instantiate()
		panel.name = "SettingsPanel"
		hud.add_child(panel)
		panel.owner = root
		print("[INFO] SettingsPanel added under GameHUD")

	var legacy := root.get_node_or_null("SettingsPanel")
	if legacy:
		legacy.free()
		print("[INFO] Removed legacy root SettingsPanel")

	_save_scene(root)
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
