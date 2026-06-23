extends Node3D

## 在当前目标浮岛上空显示脉动光柱，便于远距离辨认
const BEAM_HEIGHT := 80.0
const BEAM_RADIUS := 1.2

var _beam: MeshInstance3D
var _base_ring: MeshInstance3D
var _pulse := 0.0
var _visible_target := false


func _ready() -> void:
	_build_visuals()
	visible = false
	GameManager.game_started.connect(_on_mission_changed)
	GameManager.mission_target_changed.connect(_on_mission_changed)
	GameManager.island_completed.connect(_on_mission_changed)
	GameManager.game_won.connect(_on_mission_changed)
	var cd: Node = get_node_or_null("/root/CountdownManager")
	if cd:
		cd.countdown_started.connect(_on_mission_changed)


func _process(delta: float) -> void:
	_pulse += delta
	_update_beacon()
	if _beam:
		var pulse_scale := 1.0 + sin(_pulse * 2.2) * 0.12
		_beam.scale = Vector3(pulse_scale, 1.0, pulse_scale)


func _on_mission_changed(_a = null, _b = null) -> void:
	_update_beacon()


func _update_beacon() -> void:
	if not GameManager.is_game_started() or GameManager.is_game_won():
		visible = false
		return
	var root := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if root == null or player == null:
		visible = false
		return
	var target_name := GameManager.get_nearest_mission_target(root, player.global_position)
	if target_name.is_empty():
		visible = false
		return
	var marker := GameManager.get_island_marker_position(root, target_name)
	if marker == Vector3.ZERO:
		visible = false
		return
	global_position = marker + Vector3(0.0, 6.0, 0.0)
	visible = true
	_visible_target = true


func _build_visuals() -> void:
	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = BEAM_RADIUS
	cylinder.bottom_radius = BEAM_RADIUS * 1.4
	cylinder.height = BEAM_HEIGHT
	_beam.mesh = cylinder
	_beam.position.y = BEAM_HEIGHT * 0.5
	var beam_mat := StandardMaterial3D.new()
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.albedo_color = Color(0.35, 0.85, 1.0, 0.35)
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(0.3, 0.8, 1.0)
	beam_mat.emission_energy_multiplier = 1.5
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = beam_mat
	add_child(_beam)

	_base_ring = MeshInstance3D.new()
	_base_ring.name = "BaseRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 4.0
	torus.outer_radius = 5.0
	_base_ring.mesh = torus
	_base_ring.rotation.x = PI * 0.5
	var ring_mat := beam_mat.duplicate() as StandardMaterial3D
	ring_mat.albedo_color = Color(0.4, 0.9, 1.0, 0.55)
	ring_mat.emission_energy_multiplier = 2.0
	_base_ring.material_override = ring_mat
	add_child(_base_ring)
