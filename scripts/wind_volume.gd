extends Area3D

enum WindType { UP, DOWN, CROSS, STILLNESS }

@export var wind_type: WindType = WindType.UP
@export var wind_strength := 6.0
@export var cross_direction: Vector3 = Vector3(1.0, 0.0, 0.0)

var _force := Vector3.ZERO


func _ready() -> void:
	_force = _compute_force()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("apply_wind_influence"):
			body.apply_wind_influence(self, _force, wind_type)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("apply_wind_influence"):
		body.apply_wind_influence(self, _force, wind_type)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("remove_wind_influence"):
		body.remove_wind_influence(self)


func _compute_force() -> Vector3:
	match wind_type:
		WindType.UP:
			return Vector3.UP * wind_strength
		WindType.DOWN:
			return Vector3.DOWN * wind_strength
		WindType.STILLNESS:
			return Vector3.DOWN * 8.0
		_:
			var dir := cross_direction
			dir.y = 0.0
			if dir.length_squared() < 0.001:
				dir = Vector3.RIGHT
			return dir.normalized() * wind_strength
