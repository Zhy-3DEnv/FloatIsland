extends Button

@export var mobile_action: StringName = &""
## 为 true 时按下即触发一次（如冲刺），而非持续按住
@export var tap_to_trigger := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	button_down.connect(_on_down)
	button_up.connect(_on_up)


func _on_down() -> void:
	if tap_to_trigger and mobile_action == &"boost":
		MobileInput.request_dash()
		return
	if mobile_action.is_empty():
		return
	MobileInput.set_hold_action(mobile_action, true)


func _on_up() -> void:
	if mobile_action.is_empty():
		return
	MobileInput.set_hold_action(mobile_action, false)
