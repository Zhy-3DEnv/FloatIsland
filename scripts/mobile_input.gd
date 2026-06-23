extends Node

var move_vector := Vector2.ZERO
var look_delta := Vector2.ZERO
var fly_up := false
var fly_down := false
var jump := false
var boost := false
var takeoff_requested := false
var _dash_requested := false


func request_dash() -> void:
	_dash_requested = true


func consume_dash() -> bool:
	if not _dash_requested:
		return false
	_dash_requested = false
	return true


func is_touch_device() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func set_move_vector(value: Vector2) -> void:
	move_vector = value


func add_look_delta(delta: Vector2) -> void:
	look_delta += delta


func take_look_delta() -> Vector2:
	var delta := look_delta
	look_delta = Vector2.ZERO
	return delta


func set_hold_action(action: StringName, pressed: bool) -> void:
	match action:
		&"fly_up":
			fly_up = pressed
		&"fly_down":
			fly_down = pressed
		&"boost":
			boost = pressed
		&"jump":
			jump = pressed


func request_takeoff() -> void:
	takeoff_requested = true


func consume_takeoff() -> bool:
	if takeoff_requested:
		takeoff_requested = false
		return true
	return false
