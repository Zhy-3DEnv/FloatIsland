extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var slider_container: VBoxContainer = $Panel/Margin/VBox/Scroll/SliderBox
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel

var _sliders: Dictionary = {}


func _ready() -> void:
	panel.visible = false
	_build_sliders()
	FlightSettings.settings_changed.connect(_sync_sliders_from_settings)
	_sync_sliders_from_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_toggle_panel()
			get_viewport().set_input_as_handled()


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		status_label.text = "调节后自动保存 · 关闭面板继续飞行"
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_sliders() -> void:
	for key in FlightSettings.get_setting_names():
		var def: Dictionary = FlightSettings.SLIDER_DEFS[key]
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		name_label.text = def["label"]
		name_label.custom_minimum_size.x = 110.0
		row.add_child(name_label)

		var slider := HSlider.new()
		slider.min_value = def["min"]
		slider.max_value = def["max"]
		slider.step = def["step"]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_slider_changed.bind(key))
		row.add_child(slider)

		var value_label := Label.new()
		value_label.name = "ValueLabel"
		value_label.custom_minimum_size.x = 52.0
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)

		slider_container.add_child(row)
		_sliders[key] = {"slider": slider, "value_label": value_label}


func _sync_sliders_from_settings() -> void:
	for key in _sliders.keys():
		var entry: Dictionary = _sliders[key]
		var slider: HSlider = entry["slider"]
		slider.set_value_no_signal(FlightSettings.get_value(key))
		_update_value_label(key, FlightSettings.get_value(key))


func _on_slider_changed(value: float, key: String) -> void:
	_update_value_label(key, value)
	FlightSettings.set_value(key, value)


func _update_value_label(key: String, value: float) -> void:
	var entry: Dictionary = _sliders[key]
	var label: Label = entry["value_label"]
	if key == "mouse_sensitivity":
		label.text = "%.4f" % value
	elif key == "boost_multiplier":
		label.text = "%.1fx" % value
	else:
		label.text = "%.1f" % value


func _on_reset_pressed() -> void:
	FlightSettings.reset_to_defaults()


func _on_close_pressed() -> void:
	if panel.visible:
		_toggle_panel()
