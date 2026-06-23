extends Control

## 屏幕边缘 / 视野内目标方向指示（箭头指向下一座任务岛）
@export var margin := 56.0
@export var arrow_radius := 14.0
@export var arrow_color := Color(0.45, 0.88, 1.0, 0.95)
@export var on_screen_color := Color(0.55, 0.95, 1.0, 0.85)

var _target_world := Vector3.ZERO
var _has_target := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameManager.game_started.connect(_refresh_target)
	GameManager.mission_target_changed.connect(_refresh_target)
	GameManager.island_completed.connect(_refresh_target)
	GameManager.game_won.connect(_hide)
	var cd: Node = get_node_or_null("/root/CountdownManager")
	if cd:
		cd.countdown_started.connect(_refresh_target)


func _process(_delta: float) -> void:
	if _has_target and GameManager.is_game_started() and not GameManager.is_game_won():
		_refresh_target()
	queue_redraw()


func _hide(_a = null) -> void:
	_has_target = false
	queue_redraw()


func _refresh_target(_a = null, _b = null) -> void:
	if not GameManager.is_game_started() or GameManager.is_game_won():
		_has_target = false
		queue_redraw()
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var root := get_tree().current_scene
	if player == null or root == null:
		_has_target = false
		return
	var island_name := GameManager.get_nearest_mission_target(root, player.global_position)
	if island_name.is_empty():
		_has_target = false
		return
	_target_world = GameManager.get_island_marker_position(root, island_name)
	_has_target = _target_world != Vector3.ZERO
	queue_redraw()


func _draw() -> void:
	if not _has_target:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var screen_pos: Vector2 = camera.unproject_position(_target_world)
	var rect := get_viewport_rect()
	var center := rect.size * 0.5

	if rect.has_point(screen_pos) and screen_pos.x >= 0 and screen_pos.y >= 0:
		draw_circle(screen_pos, 10.0, on_screen_color)
		_draw_arrow_head(screen_pos, (screen_pos - center).normalized(), 12.0)
		return

	var dir := (screen_pos - center)
	if dir.length_squared() < 0.001:
		dir = Vector2.UP
	dir = dir.normalized()

	var half := rect.size * 0.5 - Vector2(margin, margin)
	var tx := 1.0 if absf(dir.x) < 0.001 else half.x / absf(dir.x)
	var ty := 1.0 if absf(dir.y) < 0.001 else half.y / absf(dir.y)
	var t := minf(tx, ty)
	var edge_pos := center + dir * t
	_draw_arrow_head(edge_pos, dir, arrow_radius)


func _draw_arrow_head(pos: Vector2, dir: Vector2, radius: float) -> void:
	var angle := dir.angle()
	var p1 := pos + Vector2.from_angle(angle) * radius
	var p2 := pos + Vector2.from_angle(angle + 2.4) * radius * 0.65
	var p3 := pos + Vector2.from_angle(angle - 2.4) * radius * 0.65
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), arrow_color)
