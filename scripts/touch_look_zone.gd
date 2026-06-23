extends Control

var _active_touch := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_touch < 0:
			_active_touch = event.index
			accept_event()
		elif not event.pressed and event.index == _active_touch:
			_active_touch = -1
			accept_event()
	elif event is InputEventScreenDrag:
		if _active_touch < 0 or event.index == _active_touch:
			MobileInput.add_look_delta(event.relative)
			accept_event()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		MobileInput.add_look_delta(event.relative)
		accept_event()
