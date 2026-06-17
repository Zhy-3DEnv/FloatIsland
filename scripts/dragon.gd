extends Node3D

const BANK_SPEED := 10.0
const WING_FLAP_SPEED := 10.0
const IDLE_WING_AMP := 0.35
const FLY_WING_AMP := 0.75

@onready var visual: Node3D = $Visual
@onready var wing_left_pivot: Node3D = $Visual/WingLeftPivot
@onready var wing_right_pivot: Node3D = $Visual/WingRightPivot

var _wing_time := 0.0


func set_visible_state(show_dragon: bool) -> void:
	visible = show_dragon
	if not show_dragon:
		_reset_pose()


func update_pose(delta: float, move_velocity: Vector3, reference_speed: float) -> void:
	if not visible:
		return

	var horiz_vel := Vector3(move_velocity.x, 0.0, move_velocity.z)
	var speed_ratio := clampf(horiz_vel.length() / maxf(reference_speed, 0.01), 0.0, 1.0)

	if horiz_vel.length_squared() > 0.5:
		var local_vel := visual.global_transform.basis.inverse() * horiz_vel.normalized()
		visual.rotation.z = lerp(visual.rotation.z, -local_vel.x * 0.45, BANK_SPEED * delta)
		visual.rotation.x = lerp(visual.rotation.x, -move_velocity.y * 0.08, BANK_SPEED * delta)
		var target_yaw := atan2(horiz_vel.x, horiz_vel.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, delta * 8.0)
	else:
		visual.rotation.z = lerp(visual.rotation.z, 0.0, BANK_SPEED * delta)
		visual.rotation.x = lerp(visual.rotation.x, 0.0, BANK_SPEED * delta)

	_wing_time += delta * WING_FLAP_SPEED * (0.6 + speed_ratio * 0.8)
	var amp := lerpf(IDLE_WING_AMP, FLY_WING_AMP, speed_ratio)
	var flap := sin(_wing_time) * amp
	wing_left_pivot.rotation.x = 0.2 + flap
	wing_right_pivot.rotation.x = 0.2 - flap
	wing_left_pivot.rotation.z = 0.35 + flap * 0.25
	wing_right_pivot.rotation.z = -0.35 - flap * 0.25


func _reset_pose() -> void:
	visual.rotation = Vector3.ZERO
	wing_left_pivot.rotation = Vector3(0.2, 0.0, 0.35)
	wing_right_pivot.rotation = Vector3(0.2, 0.0, -0.35)
