extends SceneTree

const MAIN_SCENE_PATH := "res://scene1.tscn"
const STAR_SCENE_PATH := "res://scenes/star.tscn"
const HUD_SCENE_PATH := "res://scenes/game_hud.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player.tscn"
const ENV_PATH := "res://environments/dream_sky.tres"

const ROUTE: Array[String] = [
	"floating_island_3d_model",
	"floating_island_05",
	"floating_island_3d_model_9",
	"floating_island_06",
	"floating_island_3d_model_2",
	"floating_island_01",
	"floating_island_3d_model_8",
	"floating_island_09",
	"floating_island_08",
	"floating_island_3d_model_11",
	"floating_island_07",
	"floating_island_04",
	"floating_island_03",
	"floating_island_3d_model_3",
	"floating_island_10",
	"floating_island_3d_model_6",
	"floating_island_02",
	"floating_island_3d_model_4",
	"floating_island_3d_model_7",
	"floating_island_3d_model_5",
	"floating_island_3d_model_10",
]

const ISLAND_SCALE := 5.0
const START_HEIGHT_OFFSET := 25.0
const STAR_HEIGHT_OFFSET := 4.0


func _init() -> void:
	var scene_res := load(MAIN_SCENE_PATH) as PackedScene
	if scene_res == null:
		printerr("[ERROR] Failed to load main scene")
		quit(1)
		return

	var root := scene_res.instantiate()
	_scale_islands(root)
	_ensure_sky(root)
	_reposition_stars(root)
	_rebuild_path_markers(root)
	_ensure_player(root)

	_save_scene(root)
	print("[INFO] Scene updated: islands x5, skybox, stars, player")
	quit()


func _scale_islands(root: Node) -> void:
	for child in root.get_children():
		if not str(child.name).contains("floating_island"):
			continue
		if not child is Node3D:
			continue
		var island := child as Node3D
		var t := island.transform
		island.transform = Transform3D(
			Basis(t.basis.x * ISLAND_SCALE, t.basis.y * ISLAND_SCALE, t.basis.z * ISLAND_SCALE),
			t.origin
		)
		print("[INFO] Scaled %s x%.0f" % [island.name, ISLAND_SCALE])


func _ensure_sky(root: Node) -> void:
	var existing := root.get_node_or_null("WorldEnvironment")
	if existing:
		existing.free()

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := load(ENV_PATH) as Environment
	world_env.environment = env
	root.add_child(world_env)
	world_env.owner = root
	print("[INFO] Skybox applied")


func _reposition_stars(root: Node) -> void:
	var route_root := root.get_node_or_null("RouteStars")
	if route_root == null:
		return

	for star in route_root.get_children():
		if not star.name.begins_with("Star_"):
			continue
		var island_name: String = star.get("island_name")
		var island := root.get_node_or_null(island_name)
		if island == null:
			continue
		star.position = island.position + Vector3(0.0, STAR_HEIGHT_OFFSET, 0.0)


func _rebuild_path_markers(root: Node) -> void:
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
		var from_node := root.get_node_or_null(ROUTE[i])
		var to_node := root.get_node_or_null(ROUTE[i + 1])
		if from_node == null or to_node == null:
			continue
		var from_pos: Vector3 = from_node.position + Vector3(0.0, STAR_HEIGHT_OFFSET * 0.6, 0.0)
		var to_pos: Vector3 = to_node.position + Vector3(0.0, STAR_HEIGHT_OFFSET * 0.6, 0.0)
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
		pos.y += sin(t * PI) * (STAR_HEIGHT_OFFSET * 0.35)
		mesh.surface_add_vertex(pos)
	mesh.surface_end()
	segment.mesh = mesh


func _ensure_player(root: Node) -> void:
	var player := root.get_node_or_null("Player")
	if player == null:
		var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
		player = player_scene.instantiate()
		player.name = "Player"
		root.add_child(player)
		player.owner = root

	var start := root.get_node_or_null(ROUTE[0])
	if start:
		player.position = start.position + Vector3(0.0, START_HEIGHT_OFFSET, 0.0)


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
