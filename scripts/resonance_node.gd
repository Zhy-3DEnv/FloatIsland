extends Area3D

@export var node_index: int = 0
@export var resonate_time := 0.8

var _visual: Node3D
var _glow: MeshInstance3D
var _core: MeshInstance3D
var _mission_active := false
var _highlighted := false
var _activated := false
var _player_inside := false
var _hold_time := 0.0
var _bob_time := 0.0


func _ready() -> void:
	ensure_visual_mesh()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = false
	visible = false
	_duplicate_materials()
	_refresh_visual()


func ensure_visual_mesh() -> void:
	_resolve_visual_nodes()
	if _glow != null and _core != null:
		return
	if _visual == null or _visual == self:
		_visual = Node3D.new()
		_visual.name = "NodeVisual"
		add_child(_visual)
	if _glow == null:
		_glow = MeshInstance3D.new()
		_glow.name = "Glow"
		var glow_mesh := SphereMesh.new()
		glow_mesh.radius = 0.55
		glow_mesh.height = 1.1
		_glow.mesh = glow_mesh
		var glow_mat := StandardMaterial3D.new()
		glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow_mat.albedo_color = Color(0.4, 0.9, 1.0, 0.45)
		glow_mat.emission_enabled = true
		glow_mat.emission = Color(0.35, 0.85, 1.0)
		glow_mat.emission_energy_multiplier = 1.0
		glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.set_surface_override_material(0, glow_mat)
		_visual.add_child(_glow)
	if _core == null:
		_core = MeshInstance3D.new()
		_core.name = "Core"
		var core_mesh := SphereMesh.new()
		core_mesh.radius = 0.22
		core_mesh.height = 0.44
		_core.mesh = core_mesh
		var core_mat := StandardMaterial3D.new()
		core_mat.albedo_color = Color(0.5, 0.95, 1.0)
		core_mat.emission_enabled = true
		core_mat.emission = Color(0.4, 0.9, 1.0)
		core_mat.emission_energy_multiplier = 1.4
		core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_core.set_surface_override_material(0, core_mat)
		_visual.add_child(_core)


func _resolve_visual_nodes() -> void:
	for node_name in ["NodeVisual", "NodeVisual2"]:
		var node := get_node_or_null(node_name) as Node3D
		if node == null:
			continue
		_visual = node
		_glow = node.get_node_or_null("Glow") as MeshInstance3D
		_core = node.get_node_or_null("Core") as MeshInstance3D
		if _glow or _core:
			return
	# 手改场景可能只剩空壳节点，用自身碰撞体作占位
	if _visual == null:
		_visual = self


func _duplicate_materials() -> void:
	for mesh in [_glow, _core]:
		if mesh == null:
			continue
		var mat := mesh.get_active_material(0) as StandardMaterial3D
		if mat:
			mesh.set_surface_override_material(0, mat.duplicate())


func _process(delta: float) -> void:
	if not visible:
		return
	_bob_time += delta
	if _visual and _visual != self:
		_visual.position.y = sin(_bob_time * 2.5) * 0.2
	if not _mission_active or _activated:
		return
	if _player_inside:
		_hold_time += delta
		_pulse_visual(1.0 + _hold_time / resonate_time * 0.3)
		if _hold_time >= resonate_time:
			_activate()
	else:
		_hold_time = 0.0
		_pulse_visual(1.0)


func set_mission_highlight(highlighted: bool, interactive: bool) -> void:
	_highlighted = highlighted
	_mission_active = interactive
	monitoring = interactive and not _activated
	visible = highlighted or _activated
	if not interactive:
		_hold_time = 0.0
		_player_inside = false
	_refresh_visual()


func set_mission_active(active: bool) -> void:
	set_mission_highlight(active, active)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_hold_time = 0.0


func _activate() -> void:
	if _activated:
		return
	_activated = true
	_mission_active = false
	monitoring = false
	_player_inside = false
	var mission := _find_mission_parent()
	if mission:
		mission.register_node_activated(node_index)
	if _visual and _visual != self:
		var tween := create_tween()
		tween.tween_property(_visual, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _pulse_visual(scale_factor: float) -> void:
	if _visual and _visual != self:
		_visual.scale = Vector3.ONE * scale_factor


func _refresh_visual() -> void:
	for mesh in [_glow, _core]:
		if mesh == null:
			continue
		var mat := mesh.get_active_material(0) as StandardMaterial3D
		if mat == null:
			continue
		if _activated:
			mat.emission_energy_multiplier = 0.0
		elif _mission_active:
			mat.emission_energy_multiplier = 1.2
		elif _highlighted:
			mat.emission_energy_multiplier = 0.75
		else:
			mat.emission_energy_multiplier = 0.15


func _find_mission_parent() -> Node:
	var node: Node = get_parent()
	while node:
		if node.has_method("register_node_activated"):
			return node
		node = node.get_parent()
	return null
