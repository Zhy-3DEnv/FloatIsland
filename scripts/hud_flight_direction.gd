extends Control

## 罗盘环半径（可在编辑器调整）
@export var ring_radius := 38.0
## 方向圆点半径
@export var dot_radius := 7.0
## 圆点最大偏移（相对环心）
@export var max_offset := 30.0
## 低于此输入强度时不显示方向点
@export var deadzone := 0.08
@export var ring_color := Color(1.0, 1.0, 1.0, 0.28)
@export var center_color := Color(1.0, 1.0, 1.0, 0.45)
@export var dot_color := Color(0.45, 0.78, 1.0, 0.95)

var _input_dir := Vector2.ZERO
var _active := false
var _player: Node3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_connect_player")


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player and _player.has_signal("mode_changed"):
		_player.mode_changed.connect(_on_mode_changed)
		if _player.has_method("get_mode_name"):
			_on_mode_changed(_player.get_mode_name())


func _process(_delta: float) -> void:
	if _player == null or not _player.has_method("get_move_input_vector"):
		_input_dir = Vector2.ZERO
		queue_redraw()
		return

	_input_dir = _player.get_move_input_vector()
	queue_redraw()


func _on_mode_changed(mode_name: String) -> void:
	_active = mode_name == "flight"
	visible = _active
	if not _active:
		_input_dir = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if not _active:
		return

	var center := size * 0.5
	draw_arc(center, ring_radius, 0.0, TAU, 64, ring_color, 2.0, true)
	draw_circle(center, 3.0, center_color)

	if _input_dir.length() < deadzone:
		return

	var offset := _input_dir * max_offset
	draw_circle(center + offset, dot_radius, dot_color)
