extends CanvasLayer

## 在编辑器选中 SettingsPanel 根节点，于 Inspector 的「边距」分组中调整下列数值。

@export_group("边距 · 面板距屏幕")
@export var panel_inset_left := 8.0
@export var panel_inset_top := 12.0
@export var panel_inset_right := 8.0
@export var panel_inset_bottom := 12.0

@export_group("边距 · 标题/按钮区内边距")
@export var inner_margin_left := 16.0
@export var inner_margin_top := 6.0
@export var inner_margin_right := 16.0
@export var inner_margin_bottom := 6.0

@export_group("边距 · 设置项列表左右留白")
@export var content_margin_left := 20.0
@export var content_margin_right := 12.0

@export_group("布局 · 滚动列表高度")
## 开启后 Scroll 占满标题与底部按钮之间的剩余高度（手机端默认行为）
@export var scroll_fill_remaining := true
## >0 时限制 Scroll 最小高度（像素）
@export var scroll_min_height := 0.0
## >0 时限制 Scroll 最大高度（像素）；0 表示不限制
@export var scroll_max_height := 0.0

@onready var panel: PanelContainer = $Panel
@onready var panel_margin: MarginContainer = $Panel/Margin
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var hint_label: Label = $Panel/Margin/VBox/Hint
@onready var scroll: ScrollContainer = $Panel/Margin/VBox/Scroll
@onready var scroll_content: MarginContainer = $Panel/Margin/VBox/Scroll/ContentMargin
@onready var slider_container: VBoxContainer = $Panel/Margin/VBox/Scroll/ContentMargin/SliderBox
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var reset_button: Button = $Panel/Margin/VBox/Buttons/ResetButton
@onready var close_button: Button = $Panel/Margin/VBox/Buttons/CloseButton

var _touch_mode := false


func _ready() -> void:
	add_to_group("settings_panel")
	panel.visible = false
	_touch_mode = MobileInput.is_touch_device()
	_apply_margins()
	_apply_scroll_layout()
	if _touch_mode:
		_apply_mobile_layout()
		hint_label.text = "右侧滚动条浏览 · 拖滑杆或点 ± 微调"
	else:
		hint_label.text = "按 Tab 打开/关闭此面板"
	FlightSettings.settings_changed.connect(_sync_sliders_from_settings)
	_sync_sliders_from_settings()
	call_deferred("_apply_scrollbar_width")


func _apply_margins() -> void:
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = panel_inset_left
	panel.offset_top = panel_inset_top
	panel.offset_right = -panel_inset_right
	panel.offset_bottom = -panel_inset_bottom

	panel_margin.add_theme_constant_override(&"margin_left", int(inner_margin_left))
	panel_margin.add_theme_constant_override(&"margin_top", int(inner_margin_top))
	panel_margin.add_theme_constant_override(&"margin_right", int(inner_margin_right))
	panel_margin.add_theme_constant_override(&"margin_bottom", int(inner_margin_bottom))

	scroll_content.add_theme_constant_override(&"margin_left", int(content_margin_left))
	scroll_content.add_theme_constant_override(&"margin_right", int(content_margin_right))


func _apply_scroll_layout() -> void:
	if scroll_fill_remaining:
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size.y = maxf(scroll_min_height, 0.0)
		return

	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fixed_h := scroll_max_height if scroll_max_height > 0.0 else scroll_min_height
	if fixed_h > 0.0:
		scroll.custom_minimum_size.y = fixed_h
	else:
		scroll.custom_minimum_size.y = 0.0


func _apply_mobile_layout() -> void:
	title_label.add_theme_font_size_override(&"font_size", 16)
	hint_label.add_theme_font_size_override(&"font_size", 12)
	status_label.add_theme_font_size_override(&"font_size", 12)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slider_container.add_theme_constant_override(&"separation", 4)
	for btn in [reset_button, close_button]:
		btn.custom_minimum_size = Vector2(112, 38)
		btn.add_theme_font_size_override(&"font_size", 14)


func _apply_scrollbar_width() -> void:
	var bar_width := 36.0 if _touch_mode else 18.0
	var vbar := scroll.get_v_scroll_bar()
	vbar.custom_minimum_size.x = bar_width
	vbar.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_toggle_panel()
			get_viewport().set_input_as_handled()


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		status_label.text = "调节后自动保存 · 关闭面板继续飞行"
		if not _touch_mode:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if not _touch_mode:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_visible() -> void:
	_toggle_panel()


func _sync_sliders_from_settings() -> void:
	for child in slider_container.get_children():
		if child.has_method("sync_from_settings"):
			child.sync_from_settings()


func _on_reset_pressed() -> void:
	FlightSettings.reset_to_defaults()


func _on_close_pressed() -> void:
	if panel.visible:
		_toggle_panel()
