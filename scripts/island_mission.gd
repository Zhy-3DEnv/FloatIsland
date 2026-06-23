extends Node3D

signal mission_completed

@export var island_name: String = ""
@export var mission_type: String = "relay"

var _next_ring_index := 0
var _nodes_done: Dictionary = {}


func _ready() -> void:
	GameManager.island_unlocked.connect(_on_island_unlocked)
	GameManager.island_completed.connect(_on_island_completed)
	GameManager.game_started.connect(_refresh_active_state)
	var cd: Node = _countdown()
	if cd:
		cd.countdown_started.connect(_refresh_active_state)
	_refresh_active_state()
	# 手改场景后 IslandMission 脚本可能晚于子节点 _ready，再刷一次环状态
	call_deferred("_refresh_active_state")


func register_ring_passed(ring_index: int) -> void:
	if not _is_active():
		return
	if mission_type != "relay":
		return
	if ring_index != _next_ring_index:
		return
	_next_ring_index += 1
	GameManager.mission_progress.emit("第 %d 环完成" % (ring_index + 1))
	var total := _count_rings()
	if _next_ring_index >= total:
		_finish_mission()
	else:
		_refresh_active_state()


func register_node_activated(node_index: int) -> void:
	if not _is_active():
		return
	if mission_type != "harvest":
		return
	if _nodes_done.get(node_index, false):
		return
	_nodes_done[node_index] = true
	if _nodes_done.size() >= _count_nodes():
		_finish_mission()


func _finish_mission() -> void:
	if GameManager.complete_island(island_name):
		mission_completed.emit()
	_refresh_active_state()


func _is_active() -> bool:
	return (
		GameManager.is_game_active()
		and GameManager.is_island_unlocked(island_name)
		and not GameManager.is_island_completed(island_name)
	)


func _refresh_active_state() -> void:
	var show := (
		GameManager.is_game_started()
		and GameManager.is_island_unlocked(island_name)
		and not GameManager.is_island_completed(island_name)
	)
	var interact := show and GameManager.is_game_active()
	if mission_type == "relay" and has_node("Rings"):
		var rings := get_node("Rings")
		for i in range(rings.get_child_count()):
			var child := rings.get_child(i)
			var idx := _get_ring_index(child, i)
			var is_current := idx == _next_ring_index
			var is_upcoming := idx > _next_ring_index
			if child.has_method("set_mission_highlight"):
				child.set_mission_highlight(show and (is_current or is_upcoming), interact and is_current)
			elif child.has_method("set_mission_active"):
				child.set_mission_active(interact and is_current)
		return
	for child in get_children():
		_set_child_active(child, interact, show)


func _set_child_active(node: Node, interactive: bool, shown: bool) -> void:
	if node.has_method("set_mission_highlight"):
		node.set_mission_highlight(shown, interactive)
	elif node.has_method("set_mission_active"):
		node.set_mission_active(interactive)
	for child in node.get_children():
		_set_child_active(child, interactive, shown)


func _count_rings() -> int:
	return get_node_or_null("Rings").get_child_count() if has_node("Rings") else 0


func _get_ring_index(child: Node, fallback: int) -> int:
	if child.get("ring_index") != null:
		return int(child.get("ring_index"))
	return fallback


func _count_nodes() -> int:
	return get_node_or_null("Nodes").get_child_count() if has_node("Nodes") else 0


func _countdown() -> Node:
	return get_node_or_null("/root/CountdownManager")


func _on_island_unlocked(unlocked_name: String) -> void:
	if unlocked_name == island_name:
		_refresh_active_state()


func _on_island_completed(completed_name: String, _energy: int) -> void:
	if completed_name == island_name:
		_refresh_active_state()
