extends SceneTree

const MAIN_SCENE_PATH := "res://scene1.tscn"
const STAR_SCENE_PATH := "res://scenes/star.tscn"
const HUD_SCENE_PATH := "res://scenes/game_hud.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player.tscn"

const ROUTE: Array[String] = [
	"floating_island_3d_model",
	"floating_island_05",
	"floating_island_01",
	"floating_island_06",
	"floating_island_09",
	"floating_island_08",
	"floating_island_07",
	"floating_island_04",
	"floating_island_03",
	"floating_island_10",
	"floating_island_02",
]

const START_HEIGHT_OFFSET := 25.0
const STAR_HEIGHT_OFFSET := 4.0


func _init() -> void:
	_setup_main_scene()
	print("[INFO] Route, stars and HUD setup complete")
	quit()


func _setup_main_scene() -> void:
	var scene_res := load(MAIN_SCENE_PATH) as PackedScene
	if scene_res == null:
		printerr("[ERROR] Failed to load main scene")
		quit(1)
		return

	var root := scene_res.instantiate()
	_ensure_player(root)
	_ensure_hud(root)
	_ensure_stars(root)
	_ensure_path_markers(root)

	var player := root.get_node("Player")
	var start := root.get_node_or_null(ROUTE[0])
	if start:
		player.position = start.position + Vector3(0.0, START_HEIGHT_OFFSET, 0.0)

	_save_scene(root)
	print("[INFO] Player spawn: %s" % str(player.position))


func _ensure_player(root: Node) -> void:
	var existing := root.get_node_or_null("Player")
	if existing:
		root.remove_child(existing)
		existing.free()

	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var player := player_scene.instantiate()
	player.name = "Player"
	root.add_child(player)
	player.owner = root


func _ensure_hud(root: Node) -> void:
	var existing := root.get_node_or_null("GameHUD")
	if existing:
		return
	var hud_scene := load(HUD_SCENE_PATH) as PackedScene
	var hud := hud_scene.instantiate()
	root.add_child(hud)
	hud.owner = root


func _ensure_stars(root: Node) -> void:
	var route_root := root.get_node_or_null("RouteStars")
	if route_root:
		route_root.free()

	route_root = Node3D.new()
	route_root.name = "RouteStars"
	root.add_child(route_root)
	route_root.owner = root

	var star_scene := load(STAR_SCENE_PATH) as PackedScene
	for i in range(1, ROUTE.size()):
		var island_name: String = ROUTE[i]
		var island := root.get_node_or_null(island_name)
		if island == null:
			printerr("[WARN] Island not found: %s" % island_name)
			continue

		var star: Area3D = star_scene.instantiate()
		star.name = "Star_%s" % island_name
		route_root.add_child(star)
		star.owner = root
		if star.has_method("set"):
			star.set("island_name", island_name)
		star.position = island.position + Vector3(0.0, STAR_HEIGHT_OFFSET, 0.0)
		print("[INFO] Star placed at %s" % island_name)


func _ensure_path_markers(root: Node) -> void:
	var markers := root.get_node_or_null("RouteMarkers")
	if markers:
		markers.free()

	markers = Node3D.new()
	markers.name = "RouteMarkers"
	root.add_child(markers)
	markers.owner = root

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.85, 1.0, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.7, 1.0)
	mat.emission_energy_multiplier = 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i in range(ROUTE.size() - 1):
		var from_name: String = ROUTE[i]
		var to_name: String = ROUTE[i + 1]
		var from_node := root.get_node_or_null(from_name)
		var to_node := root.get_node_or_null(to_name)
		if from_node == null or to_node == null:
			continue

		var from_pos: Vector3 = from_node.position + Vector3(0.0, 3.0, 0.0)
		var to_pos: Vector3 = to_node.position + Vector3(0.0, 3.0, 0.0)
		_add_path_segment(markers, from_pos, to_pos, mat, i, root)


func _add_path_segment(
	parent: Node3D,
	from_pos: Vector3,
	to_pos: Vector3,
	mat: StandardMaterial3D,
	index: int,
	scene_root: Node
) -> void:
	var segment := MeshInstance3D.new()
	segment.name = "PathSegment_%02d" % index
	parent.add_child(segment)
	segment.owner = scene_root

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	var steps := 16
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var pos := from_pos.lerp(to_pos, t)
		pos.y += sin(t * PI) * 3.0
		mesh.surface_add_vertex(pos)
	mesh.surface_end()
	segment.mesh = mesh


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
