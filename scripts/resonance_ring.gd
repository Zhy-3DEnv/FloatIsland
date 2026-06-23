extends Area3D

@export var ring_index: int = 0

const RING_INNER := 2.8
const RING_OUTER := 3.6
const PASS_RADIUS := 5.5

var _visual: Node3D
var _mesh: MeshInstance3D
var _passed := false
var _mission_active := false
var _highlighted := false
var _ring_material: StandardMaterial3D


func _ready() -> void:
	ensure_visual_mesh()
	ensure_collision()
	body_entered.connect(_on_body_entered)
	monitoring = false
	visible = false
	set_physics_process(false)
	_refresh_visual()


func set_mission_highlight(highlighted: bool, interactive: bool) -> void:
	_highlighted = highlighted
	_mission_active = interactive
	monitoring = interactive and not _passed
	set_physics_process(interactive and not _passed)
	visible = highlighted or _passed
	_refresh_visual()


func set_mission_active(active: bool) -> void:
	set_mission_highlight(active, active)


func _physics_process(_delta: float) -> void:
	if not _mission_active or _passed:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	if global_position.distance_to(player.global_position) <= PASS_RADIUS:
		_try_pass(player)


func _on_body_entered(body: Node3D) -> void:
	_try_pass(body)


func _try_pass(body: Node3D) -> void:
	if not _mission_active or _passed:
		return
	if not body.is_in_group("player"):
		return
	var mission := _find_mission_parent()
	if mission == null:
		return
	_passed = true
	monitoring = false
	set_physics_process(false)
	_play_pass_effect()
	mission.register_ring_passed(ring_index)


func _play_pass_effect() -> void:
	if _ring_material:
		_ring_material.emission = Color(1.0, 0.9, 0.3)
		_ring_material.emission_energy_multiplier = 2.5
	if _visual:
		var tween := create_tween()
		tween.tween_property(_visual, "scale", Vector3.ONE * 1.15, 0.12)
		tween.tween_property(_visual, "scale", Vector3.ONE, 0.18)
	_refresh_visual()


func ensure_collision() -> void:
	var kept: CollisionShape3D = null
	for child in get_children():
		if child is CollisionShape3D:
			if kept == null:
				kept = child as CollisionShape3D
			else:
				child.queue_free()
	if kept == null:
		kept = CollisionShape3D.new()
		kept.name = "CollisionShape3D"
		add_child(kept)
	var sphere := SphereShape3D.new()
	sphere.radius = PASS_RADIUS
	kept.shape = sphere


func ensure_visual_mesh() -> void:
	_visual = _find_visual()
	if _visual == null:
		_visual = Node3D.new()
		_visual.name = "RingVisual"
		add_child(_visual)
	_mesh = _find_mesh()
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Torus"
		var torus := TorusMesh.new()
		torus.inner_radius = RING_INNER
		torus.outer_radius = RING_OUTER
		torus.rings = 24
		torus.ring_segments = 36
		_mesh.mesh = torus
		_mesh.rotation.x = PI * 0.5
		_visual.add_child(_mesh)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.85, 1.0, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.8, 1.0)
	mat.emission_energy_multiplier = 1.2
	_ring_material = mat
	_mesh.set_surface_override_material(0, _ring_material)


func _find_visual() -> Node3D:
	for node_name in ["RingVisual", "RingVisual2"]:
		var node := get_node_or_null(node_name) as Node3D
		if node:
			return node
	return null


func _find_mesh() -> MeshInstance3D:
	if _visual == null:
		return null
	return _visual.get_node_or_null("Torus") as MeshInstance3D


func _refresh_visual() -> void:
	if _ring_material == null:
		return
	if _passed:
		_ring_material.albedo_color = Color(1.0, 0.85, 0.2, 0.9)
		_ring_material.emission = Color(1.0, 0.85, 0.2)
		_ring_material.emission_energy_multiplier = 2.0
	elif _mission_active:
		_ring_material.albedo_color = Color(0.35, 0.9, 1.0, 0.85)
		_ring_material.emission = Color(0.35, 0.85, 1.0)
		_ring_material.emission_energy_multiplier = 2.0
	elif _highlighted:
		_ring_material.albedo_color = Color(0.35, 0.85, 1.0, 0.55)
		_ring_material.emission = Color(0.3, 0.8, 1.0)
		_ring_material.emission_energy_multiplier = 1.2
	else:
		_ring_material.albedo_color = Color(0.5, 0.5, 0.5, 0.2)
		_ring_material.emission = Color(0.4, 0.4, 0.4)
		_ring_material.emission_energy_multiplier = 0.3


func _find_mission_parent() -> Node:
	var node: Node = get_parent()
	while node:
		if node.has_method("register_ring_passed"):
			return node
		node = node.get_parent()
	return null
