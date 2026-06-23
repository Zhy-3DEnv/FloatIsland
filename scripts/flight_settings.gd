extends Node

signal settings_changed

const SAVE_PATH := "user://flight_settings.cfg"

var move_speed: float = 14.0
var walk_speed: float = 5.0
var vertical_speed: float = 4.0
var fall_gravity_scale: float = 1.2
var fall_max_speed: float = 10.0
var boost_multiplier: float = 1.5
var mouse_sensitivity: float = 0.002
var drag: float = 6.0
var camera_distance: float = 2.0
var camera_fov: float = 72.0
var ui_scale: float = 1.0
var flight_auto_fall: bool = false

const DEFAULTS := {
	"move_speed": 14.0,
	"walk_speed": 5.0,
	"vertical_speed": 4.0,
	"fall_gravity_scale": 1.2,
	"fall_max_speed": 10.0,
	"boost_multiplier": 1.5,
	"mouse_sensitivity": 0.002,
	"drag": 6.0,
	"camera_distance": 2.0,
	"camera_fov": 72.0,
	"ui_scale": 1.0,
}

const SLIDER_DEFS := {
	"move_speed": {"label": "飞行水平速度", "min": 2.0, "max": 30.0, "step": 0.5},
	"walk_speed": {"label": "行走速度", "min": 2.0, "max": 15.0, "step": 0.5},
	"vertical_speed": {"label": "飞行垂直速度", "min": 1.0, "max": 12.0, "step": 0.5},
	"fall_gravity_scale": {"label": "下落重力倍率", "min": 0.3, "max": 4.0, "step": 0.1},
	"fall_max_speed": {"label": "最大下落速度", "min": 2.0, "max": 30.0, "step": 0.5},
	"boost_multiplier": {"label": "加速倍率", "min": 1.0, "max": 3.0, "step": 0.1},
	"mouse_sensitivity": {"label": "鼠标灵敏度", "min": 0.0005, "max": 0.01, "step": 0.0005},
	"drag": {"label": "减速阻尼", "min": 1.0, "max": 20.0, "step": 0.5},
	"camera_distance": {"label": "相机距离", "min": 0.8, "max": 8.0, "step": 0.1},
	"camera_fov": {"label": "视野 FOV", "min": 50.0, "max": 100.0, "step": 1.0},
	"ui_scale": {"label": "界面缩放", "min": 0.7, "max": 1.5, "step": 0.05},
}

const BOOL_DEFAULTS := {
	"flight_auto_fall": false,
}

const BOOL_LABELS := {
	"flight_auto_fall": "骑龙自动下落",
}


func _ready() -> void:
	load_settings()


func get_setting_names() -> Array[String]:
	var names: Array[String] = []
	for key in SLIDER_DEFS.keys():
		names.append(key)
	return names


func get_value(key: String) -> float:
	return get(key)


func set_value(key: String, value: float) -> void:
	if not DEFAULTS.has(key):
		return
	set(key, value)
	save_settings()
	settings_changed.emit()


func get_bool(key: String) -> bool:
	return get(key)


func set_bool(key: String, value: bool) -> void:
	if not BOOL_DEFAULTS.has(key):
		return
	set(key, value)
	save_settings()
	settings_changed.emit()


func load_settings() -> void:
	for key in DEFAULTS.keys():
		set(key, DEFAULTS[key])
	for key in BOOL_DEFAULTS.keys():
		set(key, BOOL_DEFAULTS[key])

	_apply_platform_speed_defaults()

	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_apply_platform_speed_defaults()
		settings_changed.emit()
		return

	for key in DEFAULTS.keys():
		var val: float = cfg.get_value("flight", key, DEFAULTS[key])
		set(key, val)
	for key in BOOL_DEFAULTS.keys():
		var val: bool = cfg.get_value("flight", key, BOOL_DEFAULTS[key])
		set(key, val)

	_apply_platform_speed_defaults()
	settings_changed.emit()


func _apply_platform_speed_defaults() -> void:
	if not OS.has_feature("mobile"):
		return
	# 移动端与编辑器保持同一套默认手感，避免存档里偏高的速度值
	move_speed = minf(move_speed, DEFAULTS["move_speed"])
	walk_speed = minf(walk_speed, DEFAULTS["walk_speed"])
	vertical_speed = minf(vertical_speed, DEFAULTS["vertical_speed"])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in DEFAULTS.keys():
		cfg.set_value("flight", key, get(key))
	for key in BOOL_DEFAULTS.keys():
		cfg.set_value("flight", key, get(key))
	cfg.save(SAVE_PATH)


func reset_to_defaults() -> void:
	for key in DEFAULTS.keys():
		set(key, DEFAULTS[key])
	for key in BOOL_DEFAULTS.keys():
		set(key, BOOL_DEFAULTS[key])
	save_settings()
	settings_changed.emit()
