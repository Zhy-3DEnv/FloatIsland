extends Node3D

@export_range(0.0, 1.0, 0.01) var preview_speed_ratio := 0.5
@export var reference_speed := 14.0

@onready var _avatar: Node3D = $Avatar


func _ready() -> void:
	_avatar.set_flight_mode(true, false)


func _process(delta: float) -> void:
	var velocity := Vector3(0.0, 0.0, -reference_speed * preview_speed_ratio)
	_avatar.update_flight_pose(delta, velocity, reference_speed)
