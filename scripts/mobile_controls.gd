extends CanvasLayer

@onready var jump_btn: Button = $Root/Actions/Row2/JumpBtn
@onready var fly_up_btn: Button = $Root/Actions/Row1/FlyUpBtn
@onready var boost_btn: Button = $Root/Actions/Row1/BoostBtn
@onready var move_joystick: Control = $Root/MoveJoystick


func _ready() -> void:
	visible = MobileInput.is_touch_device()
	if not visible:
		return
	move_joystick.direction_changed.connect(_on_move_changed)
	call_deferred("_connect_player")


func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_signal("mode_changed"):
		player.mode_changed.connect(_on_mode_changed)
		_on_mode_changed(player.get_mode_name())


func _on_move_changed(direction: Vector2) -> void:
	MobileInput.set_move_vector(direction)


func _on_mode_changed(mode_name: String) -> void:
	var walk := mode_name == "walk"
	jump_btn.visible = walk
	fly_up_btn.visible = not walk
	boost_btn.visible = not walk


func _on_takeoff_pressed() -> void:
	MobileInput.request_takeoff()


func _on_settings_pressed() -> void:
	var panel := get_tree().get_first_node_in_group("settings_panel")
	if panel and panel.has_method("toggle_visible"):
		panel.toggle_visible()
