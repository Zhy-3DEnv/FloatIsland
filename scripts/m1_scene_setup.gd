extends RefCounted

class_name M1SceneSetup

const RING_SCENE := "res://scenes/resonance_ring.tscn"
const NODE_SCENE := "res://scenes/resonance_node.tscn"
const WIND_SCENE := "res://scenes/wind_volume.tscn"
const MISSION_SCRIPT := "res://scripts/island_mission.gd"
const ALTAR_SCRIPT := "res://scripts/nexus_altar.gd"
const START_HEIGHT_OFFSET := 25.0

## 任务岛拉开至 40–60m 半径，飞行巡游更明显
const ISLAND_LAYOUT: Dictionary = {
	"floating_island_3d_model": {"pos": Vector3(0, 0, 0), "scale": 6.0, "rot_y": 0.0},
	"floating_island_05": {"pos": Vector3(42, 3, -20), "scale": 7.0, "rot_y": 0.5},
	"floating_island_01": {"pos": Vector3(24, 8, 32), "scale": 7.0, "rot_y": 1.0},
	"floating_island_06": {"pos": Vector3(-32, 12, 28), "scale": 7.0, "rot_y": 2.2},
	"floating_island_10": {"pos": Vector3(38, 5, 42), "scale": 7.0, "rot_y": 0.7},
	"floating_island_08": {"pos": Vector3(4, 0, -48), "scale": 7.5, "rot_y": 3.8},
	"floating_island_02": {"pos": Vector3(-52, 10, -30), "scale": 6.0, "rot_y": 1.3},
	"floating_island_03": {"pos": Vector3(58, 2, -36), "scale": 6.0, "rot_y": 2.1},
	"floating_island_04": {"pos": Vector3(16, -4, -58), "scale": 6.5, "rot_y": 3.2},
	"floating_island_07": {"pos": Vector3(-40, 14, -14), "scale": 6.5, "rot_y": 1.7},
	"floating_island_09": {"pos": Vector3(-8, 16, 52), "scale": 6.0, "rot_y": 0.3},
}

## 世界空间米制坐标（由 IslandMission 反缩放抵消父级 scale）
const RELAY_RING_LAYOUT: Dictionary = {
	"floating_island_05": [
		Vector3(0, 5, -6),
		Vector3(0, 6.5, 0),
		Vector3(0, 5, 6),
	],
	"floating_island_06": [
		Vector3(-4, 5, 4),
		Vector3(0, 6.5, 1),
		Vector3(4, 6, -2),
		Vector3(0, 5, -5),
	],
	"floating_island_08": [
		Vector3(0, 4.5, -7),
		Vector3(-3, 6, -3),
		Vector3(0, 7, 0),
		Vector3(3, 6, 3),
		Vector3(0, 4.5, 7),
	],
}

const HARVEST_NODE_LAYOUT: Dictionary = {
	"floating_island_01": [
		Vector3(0, 3.5, 0),
		Vector3(4, 3.5, -3),
		Vector3(-3.5, 3.5, 3.5),
	],
	"floating_island_10": [
		Vector3(0, 3.5, 0),
		Vector3(4, 3.5, 4),
		Vector3(-3.5, 5, -3),
	],
}


func apply_island_layout(root: Node) -> void:
	for island_name: String in ISLAND_LAYOUT.keys():
		var island := root.get_node_or_null(island_name)
		if island == null or not island is Node3D:
			continue
		var data: Dictionary = ISLAND_LAYOUT[island_name]
		(island as Node3D).transform = _make_island_transform(
			data["pos"], data["scale"], data["rot_y"]
		)


func apply_player_spawn(root: Node) -> void:
	var player := root.get_node_or_null("Player")
	if player == null:
		return
	var hub := root.get_node_or_null("floating_island_3d_model")
	if hub:
		player.position = hub.position + Vector3(0.0, START_HEIGHT_OFFSET, 0.0)


func apply_full_layout(root: Node) -> void:
	apply_island_layout(root)
	apply_to_scene(root)
	apply_player_spawn(root)


func _make_island_transform(pos: Vector3, scale_val: float, rot_y: float) -> Transform3D:
	var basis := Basis.IDENTITY.scaled(Vector3.ONE * scale_val)
	basis = basis.rotated(Vector3.UP, rot_y)
	return Transform3D(basis, pos)


func apply_to_scene(root: Node) -> void:
	_hide_legacy_stars(root)
	_remove_legacy_path_markers(root)
	_setup_hub_altar(root)
	_setup_relay_missions(root)
	_setup_harvest_missions(root)
	_setup_wind_volumes(root)


func _hide_legacy_stars(root: Node) -> void:
	var stars_root := root.get_node_or_null("RouteStars")
	if stars_root == null:
		return
	root.remove_child(stars_root)
	stars_root.free()


func _remove_legacy_path_markers(root: Node) -> void:
	var markers := root.get_node_or_null("RouteMarkers")
	if markers == null:
		return
	root.remove_child(markers)
	markers.free()


func _setup_hub_altar(root: Node) -> void:
	var hub := root.get_node_or_null("floating_island_3d_model")
	if hub == null:
		push_warning("Hub island not found")
		return

	var existing_root := hub.get_node_or_null("NexusAltarRoot")
	if existing_root:
		existing_root.free()
	var existing := hub.get_node_or_null("NexusAltar")
	if existing:
		existing.free()

	var hub_scale := _get_uniform_scale(hub as Node3D)
	var altar_root := Node3D.new()
	altar_root.name = "NexusAltarRoot"
	altar_root.scale = Vector3.ONE / hub_scale
	hub.add_child(altar_root)
	_set_owner_recursive(root, altar_root)

	var altar := Area3D.new()
	altar.name = "NexusAltar"
	altar.script = load(ALTAR_SCRIPT)
	altar.collision_layer = 0
	altar.collision_mask = 1
	altar.monitorable = false
	altar.monitoring = true
	altar.position = Vector3(0, 5, 0)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 4.0
	shape.shape = sphere
	altar.add_child(shape)
	_set_owner_recursive(root, shape)

	altar_root.add_child(altar)
	_set_owner_recursive(root, altar)


func _setup_relay_missions(root: Node) -> void:
	var ring_scene := load(RING_SCENE) as PackedScene
	for island_name: String in RELAY_RING_LAYOUT.keys():
		var positions: Array = RELAY_RING_LAYOUT[island_name]
		var mission := _ensure_mission(root, island_name, "relay")
		var rings_root := _ensure_child(root, mission, "Rings")
		_clear_children(rings_root)
		for i in range(positions.size()):
			var ring: Area3D = ring_scene.instantiate()
			ring.name = "Ring_%d" % i
			ring.position = positions[i]
			ring.set("ring_index", i)
			rings_root.add_child(ring)
			_set_owner_recursive(root, ring)


func _setup_harvest_missions(root: Node) -> void:
	var node_scene := load(NODE_SCENE) as PackedScene
	for island_name: String in HARVEST_NODE_LAYOUT.keys():
		var positions: Array = HARVEST_NODE_LAYOUT[island_name]
		var mission := _ensure_mission(root, island_name, "harvest")
		var nodes_root := _ensure_child(root, mission, "Nodes")
		_clear_children(nodes_root)
		for i in range(positions.size()):
			var node: Area3D = node_scene.instantiate()
			node.name = "Node_%d" % i
			node.position = positions[i]
			node.set("node_index", i)
			nodes_root.add_child(node)
			_set_owner_recursive(root, node)


func _setup_wind_volumes(root: Node) -> void:
	var wind_scene := load(WIND_SCENE) as PackedScene
	var hub := root.get_node_or_null("floating_island_3d_model")
	var island_a := root.get_node_or_null("floating_island_05")
	var island_c := root.get_node_or_null("floating_island_06")
	var island_d := root.get_node_or_null("floating_island_10")
	var island_e := root.get_node_or_null("floating_island_08")

	var container := root.get_node_or_null("M1WindVolumes")
	if container:
		container.free()
	container = Node3D.new()
	container.name = "M1WindVolumes"
	root.add_child(container)
	container.owner = root

	if hub and island_a:
		var mid: Vector3 = hub.position.lerp(island_a.position, 0.5)
		_add_wind(container, wind_scene, mid + Vector3(0, 10, 0), 0, 5.0, Vector3.ZERO, root)

	if island_a and root.get_node_or_null("floating_island_01"):
		var island_b := root.get_node_or_null("floating_island_01")
		var mid_ab: Vector3 = island_a.position.lerp(island_b.position, 0.5)
		_add_wind(container, wind_scene, mid_ab + Vector3(0, 9, 0), 0, 4.0, Vector3.ZERO, root)

	if island_c:
		_add_wind(
			container,
			wind_scene,
			island_c.position + Vector3(5, 11, 0),
			2,
			4.0,
			Vector3(1, 0, 0),
			root
		)

	if island_c and island_d:
		var mid_cd: Vector3 = island_c.position.lerp(island_d.position, 0.5)
		_add_wind(container, wind_scene, mid_cd + Vector3(0, 8, 0), 1, 3.5, Vector3.ZERO, root)

	if island_d and island_e:
		var approach: Vector3 = island_d.position.lerp(island_e.position, 0.55)
		_add_wind(container, wind_scene, approach + Vector3(-5, 5, 0), 0, 5.0, Vector3.ZERO, root)
		_add_wind(container, wind_scene, approach + Vector3(5, 5, 0), 0, 5.0, Vector3.ZERO, root)
		_add_stillness(container, approach + Vector3(0, 3, 0), root)


func _add_wind(
	parent: Node3D,
	scene: PackedScene,
	pos: Vector3,
	wind_type: int,
	strength: float,
	cross_dir: Vector3,
	scene_root: Node
) -> void:
	var wind: Area3D = scene.instantiate()
	wind.name = "WindVolume"
	wind.position = pos
	wind.set("wind_type", wind_type)
	wind.set("wind_strength", strength)
	wind.set("cross_direction", cross_dir)
	parent.add_child(wind)
	_set_owner_recursive(scene_root, wind)


func _add_stillness(parent: Node3D, pos: Vector3, scene_root: Node) -> void:
	var area := Area3D.new()
	area.name = "StillnessZone"
	area.script = load("res://scripts/wind_volume.gd")
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitorable = false
	area.monitoring = true
	area.position = pos
	area.set("wind_type", 3)
	area.set("wind_strength", 8.0)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(14, 8, 14)
	shape.shape = box
	area.add_child(shape)

	parent.add_child(area)
	_set_owner_recursive(scene_root, area)


func _ensure_mission(root: Node, island_name: String, mission_type: String) -> Node3D:
	var island := root.get_node_or_null(island_name)
	if island == null:
		push_warning("Island not found: %s" % island_name)
		return Node3D.new()

	var existing := island.get_node_or_null("IslandMission")
	if existing:
		existing.free()

	var mission := Node3D.new()
	mission.name = "IslandMission"
	mission.script = load(MISSION_SCRIPT)
	mission.set("island_name", island_name)
	mission.set("mission_type", mission_type)
	var island_scale := _get_uniform_scale(island as Node3D)
	mission.scale = Vector3.ONE / island_scale
	island.add_child(mission)
	_set_owner_recursive(root, mission)
	return mission


func _get_uniform_scale(node: Node3D) -> float:
	var s := node.transform.basis.get_scale()
	return maxf(s.x, maxf(s.y, s.z))


func _ensure_child(scene_root: Node, parent: Node, child_name: String) -> Node3D:
	var child := parent.get_node_or_null(child_name)
	if child == null:
		child = Node3D.new()
		child.name = child_name
		parent.add_child(child)
		_set_owner_recursive(scene_root, child)
	return child as Node3D


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.free()


func _set_owner_recursive(scene_root: Node, node: Node) -> void:
	node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(scene_root, child)
