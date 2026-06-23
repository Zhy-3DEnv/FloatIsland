extends Control

signal value_changed(value: float)

@export var min_value := 0.0
@export var max_value := 1.0
@export var step := 0.1

var value := 0.0

@export var track_height := 10.0
@export var grab_radius := 11.0
@export var side_margin := 2.0

var _dragging := false
var _touch_id := -1


func _ready() -> void:
	custom_minimum_size.y = 36.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func set_value_no_signal(new_value: float) -> void:
	value = _snap(clampf(new_value, min_value, max_value))
	queue_redraw()


func get_ratio() -> float:
	if is_equal_approx(max_value, min_value):
		return 0.0
	return (value - min_value) / (max_value - min_value)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_touch_id = event.index
			_set_from_x(event.position.x)
			accept_event()
		elif event.index == _touch_id:
			_stop_drag()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_set_from_x(event.position.x)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_touch_id = 0
			_set_from_x(event.position.x)
			accept_event()
		elif _dragging:
			_stop_drag()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)
		accept_event()


func _stop_drag() -> void:
	_dragging = false
	_touch_id = -1


func _track_bounds() -> Vector2:
	var left := side_margin
	var right := maxf(left + 1.0, size.x - side_margin)
	return Vector2(left, right)


func _set_from_x(local_x: float) -> void:
	var bounds := _track_bounds()
	var t := inverse_lerp(bounds.x, bounds.y, local_x)
	var new_value := _snap(lerpf(min_value, max_value, clampf(t, 0.0, 1.0)))
	if not is_equal_approx(new_value, value):
		value = new_value
		value_changed.emit(value)
	queue_redraw()


func _snap(raw: float) -> float:
	if step <= 0.0:
		return raw
	return snapped(raw, step)


func _grab_center_x() -> float:
	var bounds := _track_bounds()
	return lerpf(bounds.x, bounds.y, get_ratio())


func _draw() -> void:
	var center_y := size.y * 0.5
	var bounds := _track_bounds()
	var grab_x := _grab_center_x()

	draw_line(
		Vector2(bounds.x, center_y),
		Vector2(bounds.y, center_y),
		Color(1.0, 1.0, 1.0, 0.18),
		track_height,
		true,
	)
	draw_line(
		Vector2(bounds.x, center_y),
		Vector2(grab_x, center_y),
		Color(0.35, 0.62, 0.95, 0.88),
		track_height,
		true,
	)

	var grab_color := Color(0.92, 0.95, 1.0, 0.98) if _dragging else Color(1.0, 1.0, 1.0, 0.85)
	draw_circle(Vector2(grab_x, center_y), grab_radius, grab_color)
	draw_arc(Vector2(grab_x, center_y), grab_radius, 0.0, TAU, 32, Color(0.18, 0.42, 0.72, 0.9), 1.5)
