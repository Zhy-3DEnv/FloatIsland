extends Node

signal energy_changed(current: int, target: int)
signal island_unlocked(island_name: String)
signal island_completed(island_name: String, energy: int)
signal mission_target_changed
signal game_won
signal game_started
signal mission_progress(message: String)

enum IslandType { RELAY, HARVEST }

const HUB_ISLAND := "floating_island_3d_model"
const START_HEIGHT_OFFSET := 25.0

const ENERGY_PER_ISLAND := 10
const ENERGY_TARGET := 50
const FINAL_ISLAND_ENERGY_GATE := 30

const M1_ISLAND_ORDER: Array[String] = [
	"floating_island_05",
	"floating_island_01",
	"floating_island_06",
	"floating_island_10",
	"floating_island_08",
]

const M1_ISLAND_TYPE: Dictionary = {
	"floating_island_05": IslandType.RELAY,
	"floating_island_01": IslandType.HARVEST,
	"floating_island_06": IslandType.RELAY,
	"floating_island_10": IslandType.HARVEST,
	"floating_island_08": IslandType.RELAY,
}

const M1_STARTER_ISLANDS: Array[String] = [
	"floating_island_05",
	"floating_island_01",
]

var energy: int = 0
var _completed: Dictionary = {}
var _unlocked: Dictionary = {}
var _game_started := false
var _game_won := false


func _ready() -> void:
	_reset_unlock_state()


func start_game() -> void:
	if _game_started:
		return
	_game_started = true
	game_started.emit()
	mission_target_changed.emit()
	var tree := get_tree()
	if tree == null:
		return
	var intro_timer := tree.create_timer(3.0)
	intro_timer.timeout.connect(_on_intro_finished, CONNECT_ONE_SHOT)


func _on_intro_finished() -> void:
	if not _game_started or _game_won:
		return
	var cd: Node = _countdown()
	if cd and not cd.running and not cd.finished:
		cd.start_countdown()


func is_game_started() -> bool:
	return _game_started


func is_game_won() -> bool:
	return _game_won


func is_game_active() -> bool:
	var cd: Node = _countdown()
	return (
		_game_started
		and cd != null
		and cd.running
		and not _game_won
		and not cd.finished
	)


func get_spawn_position(islands_root: Node) -> Vector3:
	var start := islands_root.get_node_or_null(HUB_ISLAND)
	if start:
		return start.global_position + Vector3(0.0, START_HEIGHT_OFFSET, 0.0)
	return Vector3(0.0, START_HEIGHT_OFFSET, 0.0)


func get_energy_target() -> int:
	return ENERGY_TARGET


func is_m1_island(island_name: String) -> bool:
	return M1_ISLAND_ORDER.has(island_name)


func is_island_unlocked(island_name: String) -> bool:
	return _unlocked.get(island_name, false)


func is_island_completed(island_name: String) -> bool:
	return _completed.get(island_name, false)


func get_island_type(island_name: String) -> int:
	return M1_ISLAND_TYPE.get(island_name, IslandType.RELAY)


func get_unlocked_incomplete_islands() -> Array[String]:
	var result: Array[String] = []
	for island_name in M1_ISLAND_ORDER:
		if is_island_unlocked(island_name) and not is_island_completed(island_name):
			result.append(island_name)
	return result


func get_nearest_mission_target(islands_root: Node, from_position: Vector3) -> String:
	var best_name := ""
	var best_dist := INF
	for island_name in get_unlocked_incomplete_islands():
		var pos := get_island_marker_position(islands_root, island_name)
		if pos == Vector3.ZERO:
			continue
		var dist := from_position.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best_name = island_name
	return best_name


func get_island_marker_position(islands_root: Node, island_name: String) -> Vector3:
	var island := islands_root.get_node_or_null(island_name)
	if island:
		var mission := island.get_node_or_null("IslandMission")
		if mission:
			return mission.global_position + Vector3(0.0, 4.0, 0.0)
		return island.global_position + Vector3(0.0, 8.0, 0.0)
	return Vector3.ZERO


func is_relay_island(island_name: String) -> bool:
	return get_island_type(island_name) == IslandType.RELAY


func get_mission_action_text(island_name: String) -> String:
	if is_relay_island(island_name):
		return "按顺序穿过蓝色光环"
	return "落岛后靠近共鸣光点并停留"


func get_guidance(islands_root: Node, player_position: Vector3) -> Dictionary:
	var result := {
		"target_name": "",
		"target_label": "",
		"objective": "等待任务开始",
		"detail": "",
		"distance": 0.0,
	}
	if not is_game_started():
		result.objective = "任务即将开始"
		result.detail = "准备前往外围浮岛回收共鸣能量"
		return result
	if is_game_won():
		result.objective = "任务完成"
		result.detail = "天枢已稳定"
		return result

	var unlocked := get_unlocked_incomplete_islands()
	if unlocked.is_empty():
		result.objective = "全部岛屿已谐振"
		result.detail = "返回天枢岛"
		return result

	var target_name := get_nearest_mission_target(islands_root, player_position)
	if target_name.is_empty():
		target_name = unlocked[0]
	var target_pos := get_island_marker_position(islands_root, target_name)
	var dist := player_position.distance_to(target_pos) if target_pos != Vector3.ZERO else 0.0
	var friendly := friendly_island_name(target_name)

	result.target_name = target_name
	result.target_label = friendly
	result.distance = dist

	if energy == 0 and unlocked.size() >= 2:
		result.objective = "第一步：任选一座浮岛出发"
		result.detail = (
			"浮岛 01 落岛采集（新手推荐） · 浮岛 05 飞行穿环\n"
			+ "跟随蓝色光柱与屏幕箭头"
		)
		return result

	if dist > 90.0:
		result.objective = "飞往 %s" % friendly
		result.detail = "抬头找蓝色光柱 · 或看屏幕边缘箭头"
	elif dist > 35.0:
		result.objective = "接近 %s" % friendly
		result.detail = get_mission_action_text(target_name)
	elif is_relay_island(target_name):
		result.objective = "在 %s 穿环谐振" % friendly
		result.detail = "起飞！按顺序穿过蓝色光环（亮环=当前，非地面晶体）"
	else:
		result.objective = "在 %s 采集" % friendly
		result.detail = "先落岛（自动下马），靠近地面光点站定约 1 秒"

	return result


func complete_island(island_name: String) -> bool:
	if not is_m1_island(island_name):
		return false
	if not is_island_unlocked(island_name) or is_island_completed(island_name):
		return false

	_completed[island_name] = true
	energy += ENERGY_PER_ISLAND
	energy_changed.emit(energy, ENERGY_TARGET)
	island_completed.emit(island_name, energy)
	_refresh_unlocks()

	if energy >= ENERGY_TARGET:
		_win_game()
	else:
		mission_target_changed.emit()

	return true


func retry_game() -> void:
	energy = 0
	_game_started = false
	_game_won = false
	_completed.clear()
	_reset_unlock_state()
	var cd: Node = _countdown()
	if cd:
		cd.reset_for_retry()
	energy_changed.emit(energy, ENERGY_TARGET)
	mission_target_changed.emit()


func _win_game() -> void:
	if _game_won:
		return
	_game_won = true
	var cd: Node = _countdown()
	if cd:
		cd.stop_with_victory()
	game_won.emit()


func _reset_unlock_state() -> void:
	_unlocked.clear()
	for island_name in M1_STARTER_ISLANDS:
		_unlocked[island_name] = true


func _refresh_unlocks() -> void:
	var changed := false

	if is_island_completed("floating_island_05") or is_island_completed("floating_island_01"):
		if _try_unlock("floating_island_06"):
			changed = true

	if is_island_completed("floating_island_06"):
		if _try_unlock("floating_island_10"):
			changed = true

	if energy >= FINAL_ISLAND_ENERGY_GATE:
		if _try_unlock("floating_island_08"):
			changed = true

	if changed:
		mission_target_changed.emit()


func _try_unlock(island_name: String) -> bool:
	if _unlocked.get(island_name, false):
		return false
	_unlocked[island_name] = true
	island_unlocked.emit(island_name)
	return true


func friendly_island_name(island_name: String) -> String:
	if island_name == HUB_ISLAND:
		return "天枢岛"
	if island_name == "floating_island_05":
		return "浮岛 05"
	if island_name == "floating_island_01":
		return "浮岛 01"
	if island_name == "floating_island_06":
		return "浮岛 06"
	if island_name == "floating_island_10":
		return "浮岛 10"
	if island_name == "floating_island_08":
		return "浮岛 08"
	if island_name.begins_with("floating_island_3d_model_"):
		return "景观浮岛 %s" % island_name.trim_prefix("floating_island_3d_model_")
	if island_name.begins_with("floating_island_"):
		return "浮岛 %s" % island_name.trim_prefix("floating_island_")
	return island_name


func _countdown() -> Node:
	return get_node_or_null("/root/CountdownManager")
