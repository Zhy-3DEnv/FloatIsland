extends Control

signal direction_changed(direction: Vector2)

@export var radius := 90.0
@export var deadzone := 0.08

var direction := Vector2.ZERO

var _base_center := Vector2.ZERO
var _pointer := Vector2.ZERO
var _pressed := false
var _touch_id := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	_base_center = size * 0.5
	_pointer = _base_center


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not _pressed:
			_pressed = true
			_touch_id = event.index
			_base_center = _clamp_to_rect(event.position)
			_handle_drag(event.position)
			accept_event()
		elif not event.pressed and event.index == _touch_id:
			_release()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_handle_drag(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _pressed:
			_pressed = true
			_touch_id = 0
			_base_center = _clamp_to_rect(event.position)
			_handle_drag(event.position)
			accept_event()
		elif not event.pressed and _pressed:
			_release()
			accept_event()
	elif event is InputEventMouseMotion and _pressed:
		_handle_drag(event.position)
		accept_event()


func _clamp_to_rect(local_pos: Vector2) -> Vector2:
	return Vector2(
		clampf(local_pos.x, radius, size.x - radius),
		clampf(local_pos.y, radius, size.y - radius),
	)


func _handle_drag(local_pos: Vector2) -> void:
	var offset := local_pos - _base_center
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_pointer = _base_center + offset
	direction = offset / radius
	if direction.length() < deadzone:
		direction = Vector2.ZERO
	else:
		var scaled := (direction.length() - deadzone) / (1.0 - deadzone)
		direction = direction.normalized() * scaled
	direction_changed.emit(direction)
	queue_redraw()


func _release() -> void:
	_pressed = false
	_touch_id = -1
	_base_center = size * 0.5
	_pointer = _base_center
	direction = Vector2.ZERO
	direction_changed.emit(direction)
	queue_redraw()


func _draw() -> void:
	if not _pressed:
		return
	draw_circle(_base_center, radius, Color(1.0, 1.0, 1.0, 0.14))
	draw_arc(_base_center, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.36), 2.5)
	draw_circle(_pointer, 30.0, Color(1.0, 1.0, 1.0, 0.48))
