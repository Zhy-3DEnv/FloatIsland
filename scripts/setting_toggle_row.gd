extends HBoxContainer

@export var setting_key: StringName = &"flight_auto_fall"
@export var label_text: String = ""

@onready var name_label: Label = %NameLabel
@onready var toggle: CheckButton = %Toggle


func _ready() -> void:
	if label_text.is_empty():
		label_text = FlightSettings.BOOL_LABELS.get(setting_key, str(setting_key))
	name_label.text = label_text
	toggle.toggled.connect(_on_toggled)
	sync_from_settings()


func sync_from_settings() -> void:
	toggle.set_pressed_no_signal(FlightSettings.get_bool(setting_key))


func _on_toggled(pressed: bool) -> void:
	FlightSettings.set_bool(setting_key, pressed)
