extends CharacterBody3D

signal mode_changed(mode_name: String)

enum MoveMode { FLIGHT, WALK }

const WALK_JUMP := 4.5
const WALK_CAMERA_DISTANCE := 3.2
const TAKEOFF_BOOST := 6.0
const LAND_CONTACT_TIME := 0.08
const LAND_MAX_FALL_SPEED := 4.0
const FLIGHT_SINK_SPEED := 1.2
const GROUND_PROBE_LENGTH := 2.5

@onready var character: Node3D = $Character
@onready var dragon: Node3D = $Dragon
@onready var body_collision: CollisionShape3D = $BodyCollision
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var _mode := MoveMode.FLIGHT
var _camera_yaw := 0.0
var _camera_pitch := -0.25
var _move_velocity := Vector3.ZERO
var _floor_contact_time := 0.0
var _mount_requested := false


func _ready() -> void:
	add_to_group("player")
	floor_max_angle = deg_to_rad(50.0)
	collision_layer = 1
	collision_mask = 1
	body_collision.disabled = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.add_excluded_object(get_rid())
	FlightSettings.settings_changed.connect(_apply_flight_settings)
	_enter_flight_mode(false)


func get_mode_name() -> String:
	return "walk" if _mode == MoveMode.WALK else "flight"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_yaw -= event.relative.x * FlightSettings.mouse_sensitivity
		_camera_pitch -= event.relative.y * FlightSettings.mouse_sensitivity
		_camera_pitch = clampf(_camera_pitch, -1.0, 0.6)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_mount_requested = true
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_apply_camera_rotation()
	match _mode:
		MoveMode.FLIGHT:
			_physics_flight(delta)
		MoveMode.WALK:
			_physics_walk(delta)


func _physics_flight(delta: float) -> void:
	var input_dir := _read_move_input()
	var vertical := _read_vertical_input()

	var speed := FlightSettings.move_speed
	if _is_key(KEY_SHIFT):
		speed *= FlightSettings.boost_multiplier

	var yaw_basis := Basis.from_euler(Vector3(0.0, _camera_yaw, 0.0))
	var forward := -yaw_basis.z
	var right := yaw_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var horiz_dir := forward * (-input_dir.y) + right * input_dir.x
	if horiz_dir.length_squared() > 0.001:
		horiz_dir = horiz_dir.normalized()
		_move_velocity.x = horiz_dir.x * speed
		_move_velocity.z = horiz_dir.z * speed
	else:
		_move_velocity.x = move_toward(_move_velocity.x, 0.0, FlightSettings.drag * speed * delta)
		_move_velocity.z = move_toward(_move_velocity.z, 0.0, FlightSettings.drag * speed * delta)

	if vertical > 0.0:
		_move_velocity.y = vertical * FlightSettings.vertical_speed
	elif vertical < 0.0:
		_move_velocity.y = vertical * FlightSettings.vertical_speed
	else:
		_move_velocity.y = move_toward(
			_move_velocity.y, -FLIGHT_SINK_SPEED, FlightSettings.drag * FlightSettings.vertical_speed * delta
		)

	velocity = _move_velocity
	move_and_slide()
	_move_velocity = velocity

	if _should_land():
		_floor_contact_time += delta
		if _floor_contact_time >= LAND_CONTACT_TIME:
			_enter_walk_mode()
	else:
		_floor_contact_time = 0.0

	dragon.update_pose(delta, _move_velocity, FlightSettings.move_speed)


func _should_land() -> bool:
	if is_on_floor() and velocity.y <= LAND_MAX_FALL_SPEED:
		return true
	return _probe_ground_below()


func _probe_ground_below() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position
	var to := from + Vector3.DOWN * GROUND_PROBE_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	return velocity.y <= LAND_MAX_FALL_SPEED and global_position.y - hit.position.y < 1.2


func _physics_walk(delta: float) -> void:
	if _mount_requested:
		_mount_requested = false
		_enter_flight_mode()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if _is_key(KEY_SPACE) and is_on_floor():
		velocity.y = WALK_JUMP

	var walk_speed := FlightSettings.walk_speed
	var input_dir := _read_move_input()
	var yaw_basis := Basis.from_euler(Vector3(0.0, _camera_yaw, 0.0))
	var forward := -yaw_basis.z
	var right := yaw_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var direction := forward * (-input_dir.y) + right * input_dir.x
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
		character.face_direction(direction, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 10.0 * delta)

	move_and_slide()

	if not is_on_floor() and global_position.y < -80.0:
		global_position = GameManager.get_spawn_position(get_tree().current_scene)
		velocity = Vector3.ZERO
		_enter_flight_mode(false)


func _enter_walk_mode() -> void:
	if _mode == MoveMode.WALK:
		return
	_mode = MoveMode.WALK
	motion_mode = MOTION_MODE_GROUNDED
	floor_snap_length = 0.4
	up_direction = Vector3.UP
	dragon.set_visible_state(false)
	character.set_visible_state(true)
	velocity.y = 0.0
	_move_velocity = Vector3.ZERO
	_floor_contact_time = 0.0
	camera_pivot.position.y = 1.0
	spring_arm.spring_length = WALK_CAMERA_DISTANCE
	mode_changed.emit("walk")


func _enter_flight_mode(boost: bool = true) -> void:
	_mode = MoveMode.FLIGHT
	motion_mode = MOTION_MODE_FLOATING
	floor_snap_length = 0.0
	character.set_visible_state(false)
	dragon.set_visible_state(true)
	_move_velocity = velocity
	if boost:
		_move_velocity.y = maxf(_move_velocity.y, TAKEOFF_BOOST)
	velocity = _move_velocity
	_floor_contact_time = 0.0
	camera_pivot.position.y = 0.05
	_apply_flight_settings()
	mode_changed.emit("flight")


func _apply_flight_settings() -> void:
	if _mode != MoveMode.FLIGHT:
		return
	spring_arm.spring_length = FlightSettings.camera_distance
	camera.fov = FlightSettings.camera_fov


func _apply_camera_rotation() -> void:
	camera_pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)


func _read_move_input() -> Vector2:
	var input_dir := Vector2.ZERO
	if _is_key(KEY_A) or _is_key(KEY_LEFT):
		input_dir.x -= 1.0
	if _is_key(KEY_D) or _is_key(KEY_RIGHT):
		input_dir.x += 1.0
	if _is_key(KEY_W) or _is_key(KEY_UP):
		input_dir.y -= 1.0
	if _is_key(KEY_S) or _is_key(KEY_DOWN):
		input_dir.y += 1.0
	if input_dir.length_squared() > 1.0:
		input_dir = input_dir.normalized()
	return input_dir


func _read_vertical_input() -> float:
	var vertical := 0.0
	if _is_key(KEY_SPACE) or _is_key(KEY_E):
		vertical += 1.0
	if _is_key(KEY_Q) or _is_key(KEY_CTRL):
		vertical -= 1.0
	return vertical


func _is_key(keycode: Key) -> bool:
	return Input.is_key_pressed(keycode) or Input.is_physical_key_pressed(keycode)
