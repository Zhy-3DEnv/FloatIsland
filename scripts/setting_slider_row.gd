extends VBoxContainer

@export var setting_key: StringName = &"move_speed"
@export var label_text: String = ""

@onready var name_label: Label = %NameLabel
@onready var value_label: Label = %ValueLabel
@onready var slider: Control = %TouchSlider
@onready var minus_btn: Button = %MinusBtn
@onready var plus_btn: Button = %PlusBtn

var _def: Dictionary = {}


func _ready() -> void:
	_def = FlightSettings.SLIDER_DEFS.get(setting_key, {})
	if _def.is_empty():
		push_warning("SettingSliderRow: unknown key %s" % setting_key)
		return

	if label_text.is_empty():
		label_text = _def.get("label", str(setting_key))
	name_label.text = label_text

	slider.min_value = _def["min"]
	slider.max_value = _def["max"]
	slider.step = _def["step"]
	slider.value_changed.connect(_on_slider_changed)
	minus_btn.pressed.connect(_nudge.bind(-float(_def["step"])))
	plus_btn.pressed.connect(_nudge.bind(float(_def["step"])))
	sync_from_settings()


func sync_from_settings() -> void:
	if _def.is_empty():
		return
	var current := FlightSettings.get_value(setting_key)
	slider.set_value_no_signal(current)
	_update_value_label(current)


func _on_slider_changed(value: float) -> void:
	_update_value_label(value)
	FlightSettings.set_value(setting_key, value)


func _nudge(delta: float) -> void:
	var next := clampf(FlightSettings.get_value(setting_key) + delta, _def["min"], _def["max"])
	FlightSettings.set_value(setting_key, next)


func _update_value_label(value: float) -> void:
	if setting_key == &"mouse_sensitivity":
		value_label.text = "%.4f" % value
	elif setting_key == &"boost_multiplier":
		value_label.text = "%.1fx" % value
	elif setting_key == &"fall_gravity_scale":
		value_label.text = "%.1fx" % value
	elif setting_key == &"ui_scale":
		value_label.text = "%.0f%%" % (value * 100.0)
	else:
		value_label.text = "%.1f" % value
