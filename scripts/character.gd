extends Node3D

@onready var body_mesh: MeshInstance3D = $Body
@onready var head_mesh: MeshInstance3D = $Head


func set_visible_state(show_character: bool) -> void:
	visible = show_character
	if show_character:
		rotation.y = 0.0


func face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.001:
		return
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, delta * 10.0)
