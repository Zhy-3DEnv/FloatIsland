extends Area3D

@export var island_name: String = ""

@onready var visual: Node3D = $StarVisual
@onready var glow: MeshInstance3D = $StarVisual/Glow
@onready var core: MeshInstance3D = $StarVisual/Core

var _spin_speed := 2.2
var _bob_time := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_gm().star_collected.connect(_on_route_progress)
	_refresh_state()


func _process(delta: float) -> void:
	if not visible:
		return

	_bob_time += delta
	visual.position.y = sin(_bob_time * 2.5) * 0.25
	visual.rotation.y += delta * _spin_speed

	var gm := _gm()
	if gm.is_target_island(island_name):
		var pulse := 1.0 + sin(_bob_time * 4.0) * 0.15
		visual.scale = Vector3.ONE * pulse


func _on_body_entered(body: Node3D) -> void:
	if not monitoring:
		return
	if not body is CharacterBody3D:
		return
	if _gm().try_collect_star(island_name):
		_play_collect_effect()


func _on_route_progress(_stars: int, _total: int, _score: int, _next: String) -> void:
	_refresh_state()


func _refresh_state() -> void:
	var gm := _gm()
	if gm.is_target_island(island_name):
		monitoring = true
		visible = true
		_set_brightness(1.0)
	else:
		monitoring = false
		visible = false


func _set_brightness(amount: float) -> void:
	for mesh in [glow, core]:
		var mat := mesh.get_active_material(0) as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 0.6 * amount


func _play_collect_effect() -> void:
	monitoring = false
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(hide)


func _gm() -> Node:
	return get_node("/root/GameManager")
