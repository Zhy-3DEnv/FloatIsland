extends Node3D

## 关卡手改后补挂 M1 脚本；出生区自动开任务，修复计时/采集失效
const MISSION_SCRIPT := preload("res://scripts/island_mission.gd")
const ALTAR_SCRIPT := preload("res://scripts/nexus_altar.gd")
const RING_SCRIPT := preload("res://scripts/resonance_ring.gd")
const NODE_SCRIPT := preload("res://scripts/resonance_node.gd")

const RELAY_ISLANDS: Array[String] = [
	"floating_island_05",
	"floating_island_06",
	"floating_island_08",
]

var _start_zone: Area3D


func _ready() -> void:
	call_deferred("_bootstrap_m1")


func _bootstrap_m1() -> void:
	_ensure_nexus_altar()
	_ensure_mission_start_zone()
	for island_name: String in GameManager.M1_ISLAND_ORDER:
		_ensure_island_mission(island_name)
	_ensure_pickup_scripts()
	_ensure_mission_beacon()
	call_deferred("_try_auto_start_mission")


func _ensure_mission_beacon() -> void:
	var existing := get_node_or_null("MissionBeacon")
	if existing:
		existing.free()
	var beacon := Node3D.new()
	beacon.name = "MissionBeacon"
	beacon.script = load("res://scripts/mission_beacon_3d.gd")
	add_child(beacon)


func _ensure_mission_start_zone() -> void:
	_start_zone = get_node_or_null("MissionStartZone") as Area3D
	if _start_zone:
		_start_zone.queue_free()
	_start_zone = Area3D.new()
	_start_zone.name = "MissionStartZone"
	add_child(_start_zone)
	_start_zone.global_position = GameManager.get_spawn_position(self)
	_start_zone.collision_layer = 0
	_start_zone.collision_mask = 1
	_start_zone.monitorable = false
	_start_zone.monitoring = true
	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 45.0
	shape_node.shape = sphere
	_start_zone.add_child(shape_node)
	_start_zone.body_entered.connect(_on_start_zone_body_entered)


func _on_start_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_try_start_mission()


func _try_auto_start_mission() -> void:
	if GameManager.is_game_started():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or _start_zone == null:
		return
	if _start_zone.overlaps_body(player):
		_try_start_mission()


func _try_start_mission() -> void:
	if not GameManager.is_game_started():
		GameManager.start_game()


func _ensure_nexus_altar() -> void:
	var altar := find_child("NexusAltar", true, false) as Area3D
	if altar == null:
		push_warning("[M1Bootstrap] NexusAltar not found")
		return
	if altar.get_script() != ALTAR_SCRIPT:
		altar.set_script(ALTAR_SCRIPT)
	altar.collision_layer = 0
	altar.collision_mask = 1
	altar.monitorable = false
	altar.monitoring = true
	for child in altar.get_children():
		if child is CollisionShape3D:
			var shape := (child as CollisionShape3D).shape
			if shape is SphereShape3D:
				(shape as SphereShape3D).radius = maxf((shape as SphereShape3D).radius, 12.0)
			return
	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 12.0
	shape_node.shape = sphere
	altar.add_child(shape_node)


func _ensure_island_mission(island_name: String) -> void:
	var island := get_node_or_null(island_name)
	if island == null:
		return
	var mission := island.get_node_or_null("IslandMission") as Node3D
	if mission == null:
		return
	if mission.get_script() != MISSION_SCRIPT:
		mission.set_script(MISSION_SCRIPT)
	mission.set("island_name", island_name)
	mission.set("mission_type", "relay" if island_name in RELAY_ISLANDS else "harvest")
	if mission.has_method("_refresh_active_state"):
		mission._refresh_active_state()


func _ensure_pickup_scripts() -> void:
	for ring in _find_all_rings():
		if ring.get_script() != RING_SCRIPT:
			ring.set_script(RING_SCRIPT)
		else:
			if ring.has_method("ensure_visual_mesh"):
				ring.ensure_visual_mesh()
			if ring.has_method("ensure_collision"):
				ring.ensure_collision()
	for node in _find_all_nodes():
		if node.get_script() != NODE_SCRIPT:
			node.set_script(NODE_SCRIPT)
		elif node.has_method("ensure_visual_mesh"):
			node.ensure_visual_mesh()


func _find_all_rings() -> Array[Area3D]:
	var result: Array[Area3D] = []
	for island_name: String in GameManager.M1_ISLAND_ORDER:
		var rings := get_node_or_null("%s/IslandMission/Rings" % island_name)
		if rings == null:
			continue
		for child in rings.get_children():
			if child is Area3D:
				result.append(child)
	return result


func _find_all_nodes() -> Array[Area3D]:
	var result: Array[Area3D] = []
	for island_name: String in GameManager.M1_ISLAND_ORDER:
		if island_name in RELAY_ISLANDS:
			continue
		var nodes := get_node_or_null("%s/IslandMission/Nodes" % island_name)
		if nodes == null:
			continue
		for child in nodes.get_children():
			if child is Area3D:
				result.append(child)
	return result
