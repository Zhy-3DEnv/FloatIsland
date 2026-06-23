extends Node

## 自动试玩驱动：模拟玩家飞至祭坛、启动 M1 任务并依次完成穿环/采集。

enum Phase {
	WARMUP,
	FLY_TO_ALTAR,
	WAIT_GAME_START,
	NAVIGATE,
	HOLD_NODE,
	WAIT_ISLAND_COMPLETE,
	FINISHED,
	FAILED,
}

const PHASE_NAMES := {
	Phase.WARMUP: "准备",
	Phase.FLY_TO_ALTAR: "前往祭坛",
	Phase.WAIT_GAME_START: "等待任务开始",
	Phase.NAVIGATE: "导航目标",
	Phase.HOLD_NODE: "共鸣采集",
	Phase.WAIT_ISLAND_COMPLETE: "等待岛屿完成",
	Phase.FINISHED: "试玩完成",
	Phase.FAILED: "试玩失败",
}

const ARRIVE_HORIZONTAL := 5.0
const ARRIVE_VERTICAL := 4.0
const HOLD_NODE_SECONDS := 1.1
const ISLAND_COMPLETE_TIMEOUT := 20.0
const ALTAR_TIMEOUT := 45.0
const GAME_START_TIMEOUT := 12.0

var _phase := Phase.WARMUP
var _phase_timer := 0.0
var _hold_timer := 0.0
var _player: CharacterBody3D
var _current_island := ""
var _targets: Array[Vector3] = []
var _target_index := 0
var _status := ""
var _hud_layer: CanvasLayer
var _hud_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	set_physics_process(true)
	call_deferred("_begin")


func _begin() -> void:
	await get_tree().create_timer(0.6).timeout
	_find_player()
	if _player == null:
		_fail("找不到 Player 节点")
		return
	_player.set_bot_active(true)
	_phase = Phase.FLY_TO_ALTAR
	_phase_timer = 0.0
	_status = "飞向天枢岛祭坛"


func _physics_process(delta: float) -> void:
	_phase_timer += delta
	if _player == null:
		_find_player()
		return

	match _phase:
		Phase.FLY_TO_ALTAR:
			_tick_fly_to_altar(delta)
		Phase.WAIT_GAME_START:
			_tick_wait_game_start()
		Phase.NAVIGATE:
			_tick_navigate(delta)
		Phase.HOLD_NODE:
			_tick_hold_node(delta)
		Phase.WAIT_ISLAND_COMPLETE:
			_tick_wait_island_complete()
		Phase.FINISHED, Phase.FAILED:
			_player.set_bot_input(Vector2.ZERO, false)

	_update_hud()


func _tick_fly_to_altar(delta: float) -> void:
	var altar := _get_altar_position()
	if altar == Vector3.ZERO:
		_fail("找不到祭坛")
		return
	if _arrived_at(altar):
		_phase = Phase.WAIT_GAME_START
		_phase_timer = 0.0
		_player.set_bot_input(Vector2.ZERO, false)
		_status = "已抵达祭坛，等待任务启动"
		return
	if _phase_timer > ALTAR_TIMEOUT:
		GameManager.start_game()
		_start_next_mission()
		return
	_steer_toward(altar, delta)


func _tick_wait_game_start() -> void:
	if GameManager.is_game_started():
		_start_next_mission()
		return
	if _phase_timer > GAME_START_TIMEOUT:
		GameManager.start_game()
		_start_next_mission()


func _tick_navigate(delta: float) -> void:
	if _targets.is_empty():
		_phase = Phase.WAIT_ISLAND_COMPLETE
		_phase_timer = 0.0
		return
	if _target_index >= _targets.size():
		_phase = Phase.WAIT_ISLAND_COMPLETE
		_phase_timer = 0.0
		_status = "目标点已走完，等待岛屿结算"
		return

	var target := _targets[_target_index]
	if _arrived_at(target):
		if _is_harvest_island(_current_island):
			_phase = Phase.HOLD_NODE
			_hold_timer = 0.0
			_player.set_bot_input(Vector2.ZERO, false)
			_status = "停留共鸣节点 %d/%d" % [_target_index + 1, _targets.size()]
		else:
			_target_index += 1
			_status = "穿环进度 %d/%d" % [_target_index, _targets.size()]
		return
	_steer_toward(target, delta)


func _tick_hold_node(delta: float) -> void:
	_player.set_bot_input(Vector2.ZERO, false)
	_hold_timer += delta
	if _hold_timer >= HOLD_NODE_SECONDS:
		_target_index += 1
		_phase = Phase.NAVIGATE
		_status = "采集进度 %d/%d" % [_target_index, _targets.size()]


func _tick_wait_island_complete() -> void:
	_player.set_bot_input(Vector2.ZERO, false)
	if _current_island != "" and GameManager.is_island_completed(_current_island):
		if GameManager.is_game_won():
			_finish("任务胜利")
		else:
			_start_next_mission()
		return
	if _phase_timer > ISLAND_COMPLETE_TIMEOUT:
		_status = "岛屿超时，尝试下一目标"
		_start_next_mission()


func _start_next_mission() -> void:
	var island := _pick_next_island()
	if island == "":
		if GameManager.is_game_won():
			_finish("全部完成")
		else:
			_finish("无可执行任务（能量 %d/%d）" % [GameManager.energy, GameManager.get_energy_target()])
		return

	_current_island = island
	_targets = _collect_island_targets(island)
	_target_index = 0
	_phase = Phase.NAVIGATE
	_phase_timer = 0.0
	_status = "前往 %s" % GameManager.friendly_island_name(island)


func _pick_next_island() -> String:
	var root := get_tree().current_scene
	if root == null or _player == null:
		return ""
	return GameManager.get_nearest_mission_target(root, _player.global_position)


func _collect_island_targets(island_name: String) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var root := get_tree().current_scene
	if root == null:
		return result
	var island := root.get_node_or_null(island_name)
	if island == null:
		return result
	var mission := island.get_node_or_null("IslandMission")
	if mission == null:
		return result

	var island_type: int = GameManager.get_island_type(island_name)
	if island_type == GameManager.IslandType.RELAY:
		var rings := mission.get_node_or_null("Rings")
		if rings:
			for child in rings.get_children():
				result.append(child.global_position)
	elif island_type == GameManager.IslandType.HARVEST:
		var nodes := mission.get_node_or_null("Nodes")
		if nodes:
			for child in nodes.get_children():
				result.append(child.global_position)
	return result


func _steer_toward(target: Vector3, _delta: float) -> void:
	var to := target - _player.global_position
	var horiz := Vector3(to.x, 0.0, to.z)
	var yaw: float = _player.get_camera_yaw()
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var dir := horiz.normalized() if horiz.length() > 0.05 else forward
	var cross_y := forward.cross(dir).y
	var dot := clampf(forward.dot(dir), -1.0, 1.0)
	var yaw_err := atan2(cross_y, dot)
	_player.set_bot_look_delta(Vector2(clampf(yaw_err * 38.0, -2.8, 2.8), 0.0))
	var fly_up := to.y > 2.5
	_player.set_bot_input(Vector2(0.0, -1.0), fly_up)
	if absf(yaw_err) < 0.45 and horiz.length() > 14.0 and _player.get_dash_cooldown_ratio() > 0.97:
		_player.request_bot_dash()


func _arrived_at(target: Vector3) -> bool:
	var to := target - _player.global_position
	return Vector2(to.x, to.z).length() <= ARRIVE_HORIZONTAL and absf(to.y) <= ARRIVE_VERTICAL


func _is_harvest_island(island_name: String) -> bool:
	return GameManager.get_island_type(island_name) == GameManager.IslandType.HARVEST


func _get_altar_position() -> Vector3:
	var root := get_tree().current_scene
	if root == null:
		return Vector3.ZERO
	var altar := root.get_node_or_null("floating_island_3d_model/NexusAltarRoot/NexusAltar")
	if altar:
		return altar.global_position
	altar = root.get_node_or_null("floating_island_3d_model/NexusAltar")
	if altar:
		return altar.global_position
	return Vector3.ZERO


func _find_player() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var node := root.get_node_or_null("Player")
	if node is CharacterBody3D:
		_player = node


func _finish(message: String) -> void:
	_phase = Phase.FINISHED
	_status = message
	if _player:
		_player.set_bot_active(false)


func _fail(message: String) -> void:
	_phase = Phase.FAILED
	_status = message
	if _player:
		_player.set_bot_active(false)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 100
	add_child(_hud_layer)

	_hud_label = Label.new()
	_hud_label.position = Vector2(16, 16)
	_hud_label.add_theme_font_size_override("font_size", 18)
	_hud_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_hud_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_hud_label.add_theme_constant_override("shadow_offset_x", 2)
	_hud_label.add_theme_constant_override("shadow_offset_y", 2)
	_hud_layer.add_child(_hud_label)

	var hint := Label.new()
	hint.text = "自动试玩中 · ESC 退出并接管操控"
	hint.position = Vector2(16, 0)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -40.0
	hint.offset_bottom = -12.0
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.9))
	_hud_layer.add_child(hint)


func _update_hud() -> void:
	if _hud_label == null:
		return
	var cd: Node = get_node_or_null("/root/CountdownManager")
	var time_text := "--:--"
	if cd and "time_remaining" in cd:
		var secs := int(cd.time_remaining)
		time_text = "%02d:%02d" % [secs // 60, secs % 60]

	_hud_label.text = (
		"[自动试玩] %s\n"
		+ "%s\n"
		+ "能量 %d/%d · 倒计时 %s"
		% [
			PHASE_NAMES.get(_phase, "?"),
			_status,
			GameManager.energy,
			GameManager.get_energy_target(),
			time_text,
		]
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_stop_and_handover()


func _stop_and_handover() -> void:
	if _player:
		_player.set_bot_active(false)
	_status = "已停止自动试玩，可手动操作"
	_phase = Phase.FINISHED
	if _hud_label:
		_hud_label.text = "[试玩结束] %s\n按 F5 可重新运行" % _status
