extends SceneTree

const MAIN_SCENE_PATH := "res://scene1.tscn"
const RING_SCENE := "res://scenes/resonance_ring.tscn"
const NODE_SCENE := "res://scenes/resonance_node.tscn"
const WIND_SCENE := "res://scenes/wind_volume.tscn"
const MISSION_SCRIPT := "res://scripts/island_mission.gd"
const ALTAR_SCRIPT := "res://scripts/nexus_altar.gd"

const RELAY_RING_LAYOUT: Dictionary = {
	"floating_island_05": [
		Vector3(0, 10, -15),
		Vector3(0, 12, 0),
		Vector3(0, 8, 12),
	],
	"floating_island_06": [
		Vector3(10, 12, 5),
		Vector3(5, 14, 0),
		Vector3(0, 12, -5),
		Vector3(-5, 10, -8),
	],
	"floating_island_08": [
		Vector3(8, 8, 10),
		Vector3(4, 10, 4),
		Vector3(0, 12, 0),
		Vector3(-4, 10, -6),
		Vector3(-8, 8, -12),
	],
}

const HARVEST_NODE_LAYOUT: Dictionary = {
	"floating_island_01": [
		Vector3(0, 6, 0),
		Vector3(8, 6, -5),
		Vector3(-6, 6, 4),
	],
	"floating_island_3d_model_2": [
		Vector3(0, 5, 0),
		Vector3(10, 5, 8),
		Vector3(5, 12, -8),
	],
}


func _init() -> void:
	_setup_main_scene()
	print("[INFO] M1 missions setup complete")
	quit()


func _setup_main_scene() -> void:
	var scene_res := load(MAIN_SCENE_PATH) as PackedScene
	if scene_res == null:
		printerr("[ERROR] Failed to load main scene")
		quit(1)
		return

	var root := scene_res.instantiate()
	_hide_legacy_stars(root)
	_setup_hub_altar(root)
	_setup_relay_missions(root)
	_setup_harvest_missions(root)
	_setup_wind_volumes(root)
	_save_scene(root)


func _hide_legacy_stars(root: Node) -> void:
	var stars_root := root.get_node_or_null("RouteStars")
	if stars_root:
		root.remove_child(stars_root)
		stars_root.free()


func _setup_hub_altar(root: Node) -> void:
	var hub := root.get_node_or_null("floating_island_3d_model")
	if hub == null:
		printerr("[WARN] Hub island not found")
		return

	var existing := hub.get_node_or_null("NexusAltar")
	if existing:
		existing.free()

	var altar := Area3D.new()
	altar.name = "NexusAltar"
	altar.script = load(ALTAR_SCRIPT)
	altar.collision_layer = 0
	altar.collision_mask = 1
	altar.monitorable = false
	altar.monitoring = true
	altar.position = Vector3(0, 8, 0)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 6.0
	shape.shape = sphere
	altar.add_child(shape)
	shape.owner = root

	var marker := MeshInstance3D.new()
	marker.name = "AltarVisual"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.5
	mesh.bottom_radius = 3.0
	mesh.height = 1.2
	marker.mesh = mesh
	marker.position = Vector3(0, 0.6, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.85, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.75, 1.0)
	mat.emission_energy_multiplier = 0.8
	marker.material_override = mat
	altar.add_child(marker)
	marker.owner = root

	hub.add_child(altar)
	altar.owner = root


func _setup_relay_missions(root: Node) -> void:
	var ring_scene := load(RING_SCENE) as PackedScene
	for island_name: String in RELAY_RING_LAYOUT.keys():
		var positions: Array = RELAY_RING_LAYOUT[island_name]
		var mission := _ensure_mission(root, island_name, "relay")
		var rings_root := _ensure_child(mission, "Rings", root)
		_clear_children(rings_root)
		for i in range(positions.size()):
			var ring: Area3D = ring_scene.instantiate()
			ring.name = "Ring_%d" % i
			ring.position = positions[i]
			ring.set("ring_index", i)
			rings_root.add_child(ring)
			ring.owner = root


func _setup_harvest_missions(root: Node) -> void:
	var node_scene := load(NODE_SCENE) as PackedScene
	for island_name: String in HARVEST_NODE_LAYOUT.keys():
		var positions: Array = HARVEST_NODE_LAYOUT[island_name]
		var mission := _ensure_mission(root, island_name, "harvest")
		var nodes_root := _ensure_child(mission, "Nodes", root)
		_clear_children(nodes_root)
		for i in range(positions.size()):
			var node: Area3D = node_scene.instantiate()
			node.name = "Node_%d" % i
			node.position = positions[i]
			node.set("node_index", i)
			nodes_root.add_child(node)
			node.owner = root


func _setup_wind_volumes(root: Node) -> void:
	var wind_scene := load(WIND_SCENE) as PackedScene
	var hub := root.get_node_or_null("floating_island_3d_model")
	var island_a := root.get_node_or_null("floating_island_05")
	var island_c := root.get_node_or_null("floating_island_06")
	var island_d := root.get_node_or_null("floating_island_3d_model_2")
	var island_e := root.get_node_or_null("floating_island_08")

	var container := root.get_node_or_null("M1WindVolumes")
	if container:
		container.free()
	container = Node3D.new()
	container.name = "M1WindVolumes"
	root.add_child(container)
	container.owner = root

	if hub and island_a:
		var mid: Vector3 = hub.global_position.lerp(island_a.global_position, 0.5)
		_add_wind(container, wind_scene, mid + Vector3(0, 12, 0), 0, 6.0, Vector3.ZERO, root)

	if island_c:
		_add_wind(
			container,
			wind_scene,
			island_c.global_position + Vector3(8, 14, 2),
			2,
			5.0,
			Vector3(1, 0, 0),
			root
		)

	if island_c and island_d:
		var mid_cd: Vector3 = island_c.global_position.lerp(island_d.global_position, 0.45)
		_add_wind(container, wind_scene, mid_cd + Vector3(0, 10, 0), 1, 4.0, Vector3.ZERO, root)

	if island_d and island_e:
		var approach: Vector3 = island_d.global_position.lerp(island_e.global_position, 0.72)
		_add_wind(container, wind_scene, approach + Vector3(-6, 6, 0), 0, 7.0, Vector3.ZERO, root)
		_add_wind(container, wind_scene, approach + Vector3(6, 6, 0), 0, 7.0, Vector3.ZERO, root)
		_add_stillness(container, approach + Vector3(0, 4, 0), root)


func _add_wind(
	parent: Node3D,
	scene: PackedScene,
	global_pos: Vector3,
	wind_type: int,
	strength: float,
	cross_dir: Vector3,
	scene_root: Node
) -> void:
	var wind: Area3D = scene.instantiate()
	wind.name = "Wind_%s" % str(wind.get_instance_id())
	wind.global_position = global_pos
	wind.set("wind_type", wind_type)
	wind.set("wind_strength", strength)
	wind.set("cross_direction", cross_dir)
	parent.add_child(wind)
	wind.owner = scene_root


func _add_stillness(parent: Node3D, global_pos: Vector3, scene_root: Node) -> void:
	var area := Area3D.new()
	area.name = "StillnessZone"
	area.script = load("res://scripts/wind_volume.gd")
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitorable = false
	area.monitoring = true
	area.global_position = global_pos
	area.set("wind_type", 3)
	area.set("wind_strength", 8.0)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(14, 8, 14)
	shape.shape = box
	area.add_child(shape)
	shape.owner = scene_root

	parent.add_child(area)
	area.owner = scene_root


func _ensure_mission(root: Node, island_name: String, mission_type: String) -> Node3D:
	var island := root.get_node_or_null(island_name)
	if island == null:
		printerr("[WARN] Island not found: %s" % island_name)
		return Node3D.new()

	var existing := island.get_node_or_null("IslandMission")
	if existing:
		existing.free()

	var mission := Node3D.new()
	mission.name = "IslandMission"
	mission.script = load(MISSION_SCRIPT)
	mission.set("island_name", island_name)
	mission.set("mission_type", mission_type)
	island.add_child(mission)
	mission.owner = root
	return mission


func _ensure_child(parent: Node, child_name: String, scene_root: Node) -> Node3D:
	var child := parent.get_node_or_null(child_name)
	if child == null:
		child = Node3D.new()
		child.name = child_name
		parent.add_child(child)
		child.owner = scene_root
	return child as Node3D


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.free()


func _save_scene(root: Node) -> void:
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		printerr("[ERROR] Failed to pack scene")
		quit(1)
		return
	if ResourceSaver.save(packed, MAIN_SCENE_PATH) != OK:
		printerr("[ERROR] Failed to save scene")
		quit(1)
		return
