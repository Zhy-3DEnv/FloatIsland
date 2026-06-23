extends Node

## 与 project.godot 中的设计分辨率保持一致
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
## 移动端按钮在设计稿中的参考边长
const REFERENCE_BUTTON_PX := 120.0
## 触摸按钮目标最小 dp（Android 建议 ≥48dp，这里取 80dp 更易点按）
const MIN_TOUCH_DP := 80.0

const MIN_AUTO_SCALE := 1.0
const MAX_AUTO_SCALE := 3.5


func _ready() -> void:
	if not _should_apply():
		return
	FlightSettings.settings_changed.connect(_apply_scale)
	get_tree().root.size_changed.connect(_apply_scale)
	call_deferred("_apply_scale")


func _should_apply() -> bool:
	return OS.has_feature("mobile")


func _apply_scale() -> void:
	var root: Window = get_tree().root
	var screen := _as_landscape(Vector2(DisplayServer.screen_get_size()))
	var os_scale := DisplayServer.screen_get_scale()
	if os_scale <= 0.0:
		os_scale = 1.0

	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		dpi = 320.0

	var res_scale := maxf(screen.x / DESIGN_SIZE.x, screen.y / DESIGN_SIZE.y)
	var dpi_scale := (MIN_TOUCH_DP / REFERENCE_BUTTON_PX) * (dpi / 160.0)
	var auto_scale := maxf(maxf(res_scale, dpi_scale), os_scale)
	auto_scale = clampf(auto_scale, MIN_AUTO_SCALE, MAX_AUTO_SCALE)

	var user_scale := FlightSettings.get_value("ui_scale")
	var final_scale := clampf(auto_scale * user_scale, 0.75, 4.0)

	root.content_scale_size = Vector2i(DESIGN_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_factor = final_scale


func _as_landscape(size: Vector2) -> Vector2:
	if size.x < size.y:
		return Vector2(size.y, size.x)
	return size
