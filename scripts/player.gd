extends CharacterBody3D

signal mode_changed(mode_name: String)

enum MoveMode { FLIGHT, WALK }

const WALK_JUMP := 4.5
const WALK_CAMERA_DISTANCE := 3.2
const TAKEOFF_BOOST := 6.0
const LAND_CONTACT_TIME := 0.08
const LAND_MAX_FALL_SPEED := 4.0
const GROUND_PROBE_LENGTH := 2.5
const CAMERA_HEIGHT := 1.0
const CAMERA_TWEEN_DURATION := 0.35
const TOUCH_LOOK_SCALE := 5.5

const LIFT_MAX := 100.0
const LIFT_FLIGHT_DRAIN := 4.0
const LIFT_GROUND_RECOVERY := 20.0
const STILLNESS_FALL_SPEED := 8.0
const DASH_COOLDOWN := 1.75
const DASH_IMPULSE := 22.0
const DASH_LIFT_COST := 12.0

@onready var avatar = $Avatar
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
var _camera_tween: Tween
var _lift := LIFT_MAX
var _stillness_depth := 0
var _wind_forces: Dictionary = {}
var _dash_cooldown := 0.0
var _shift_was_pressed := false
var _bot_active := false
var _bot_move := Vector2.ZERO
var _bot_fly_up := false
var _bot_dash_pending := false


func _ready() -> void:
	add_to_group("player")
	floor_max_angle = deg_to_rad(50.0)
	collision_layer = 1
	collision_mask = 1
	body_collision.disabled = false
	if not MobileInput.is_touch_device():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.add_excluded_object(get_rid())
	FlightSettings.settings_changed.connect(_apply_flight_settings)
	_enter_flight_mode(false)


func get_mode_name() -> String:
	return "walk" if _mode == MoveMode.WALK else "flight"


func get_move_input_vector() -> Vector2:
	return _read_move_input()


func get_lift_ratio() -> float:
	return clampf(_lift / LIFT_MAX, 0.0, 1.0)


func set_bot_active(active: bool) -> void:
	_bot_active = active
	if not active:
		_bot_move = Vector2.ZERO
		_bot_fly_up = false
		_bot_dash_pending = false


func set_bot_input(move: Vector2, fly_up: bool = false) -> void:
	_bot_move = move
	_bot_fly_up = fly_up


func request_bot_dash() -> void:
	_bot_dash_pending = true


func set_bot_look_delta(delta: Vector2) -> void:
	if _bot_active:
		_apply_look_delta(delta)


func get_camera_yaw() -> float:
	return _camera_yaw


func apply_wind_influence(source: Node, force: Vector3, wind_type: int) -> void:
	_wind_forces[source.get_instance_id()] = {"force": force, "type": wind_type}
	if wind_type == 3:
		_stillness_depth += 1


func remove_wind_influence(source: Node) -> void:
	var key := source.get_instance_id()
	if not _wind_forces.has(key):
		return
	var entry: Dictionary = _wind_forces[key]
	if entry.get("type", -1) == 3:
		_stillness_depth = maxi(0, _stillness_depth - 1)
	_wind_forces.erase(key)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look_delta(event.relative)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_mount_requested = true
		if event.keycode == KEY_ESCAPE and not MobileInput.is_touch_device():
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if MobileInput.is_touch_device():
		_apply_look_delta(MobileInput.take_look_delta())
	_apply_camera_rotation()
	match _mode:
		MoveMode.FLIGHT:
			_physics_flight(delta)
		MoveMode.WALK:
			_physics_walk(delta)


func _physics_flight(delta: float) -> void:
	var input_dir := _read_move_input()
	var vertical := _read_vertical_input()
	var in_stillness := _stillness_depth > 0
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)

	if _consume_dash_input():
		_try_dash(input_dir)

	var speed := FlightSettings.move_speed
	var move_dir := _read_flight_move_direction(input_dir)
	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
		_move_velocity.x = move_dir.x * speed
		_move_velocity.z = move_dir.z * speed
		if absf(input_dir.y) > 0.001:
			_move_velocity.y = move_dir.y * speed
		var face_dir := Vector3(move_dir.x, 0.0, move_dir.z)
		if face_dir.length_squared() > 0.001:
			avatar.face_direction(face_dir.normalized(), delta)
	else:
		_move_velocity.x = move_toward(_move_velocity.x, 0.0, FlightSettings.drag * speed * delta)
		_move_velocity.z = move_toward(_move_velocity.z, 0.0, FlightSettings.drag * speed * delta)

	if vertical > 0.0 and not in_stillness:
		_move_velocity.y = vertical * FlightSettings.vertical_speed
	elif absf(input_dir.y) <= 0.001:
		if in_stillness:
			_move_velocity.y = minf(_move_velocity.y, -STILLNESS_FALL_SPEED)
			_move_velocity.y += get_gravity().y * FlightSettings.fall_gravity_scale * 2.0 * delta
		elif FlightSettings.flight_auto_fall:
			_move_velocity.y += get_gravity().y * FlightSettings.fall_gravity_scale * delta
			_move_velocity.y = maxf(_move_velocity.y, -FlightSettings.fall_max_speed)
		else:
			_move_velocity.y = move_toward(
				_move_velocity.y, 0.0, FlightSettings.drag * FlightSettings.vertical_speed * delta
			)

	_apply_wind_forces(delta)

	_lift = maxf(0.0, _lift - LIFT_FLIGHT_DRAIN * delta)

	velocity = _move_velocity
	move_and_slide()
	_move_velocity = velocity

	if _should_land():
		_floor_contact_time += delta
		if _floor_contact_time >= LAND_CONTACT_TIME:
			_enter_walk_mode()
	else:
		_floor_contact_time = 0.0

	avatar.update_flight_pose(delta, _move_velocity, FlightSettings.move_speed)


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
	if _mount_requested or MobileInput.consume_takeoff():
		_mount_requested = false
		_enter_flight_mode()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if (_is_key(KEY_SPACE) or MobileInput.jump) and is_on_floor():
		velocity.y = WALK_JUMP

	var walk_speed := FlightSettings.walk_speed
	var input_dir := _read_move_input()
	var direction := _read_camera_horizontal_direction(input_dir)
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
		avatar.face_direction(direction, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 10.0 * delta)

	move_and_slide()

	if is_on_floor():
		_lift = minf(LIFT_MAX, _lift + LIFT_GROUND_RECOVERY * delta)

	if not is_on_floor() and global_position.y < -80.0:
		_respawn_at_hub()


func _respawn_at_hub() -> void:
	global_position = GameManager.get_spawn_position(get_tree().current_scene)
	velocity = Vector3.ZERO
	_move_velocity = Vector3.ZERO
	_lift = LIFT_MAX
	_stillness_depth = 0
	_wind_forces.clear()
	_enter_flight_mode(false)
	if GameManager.is_game_started():
		var cd: Node = _countdown()
		if cd and not cd.finished:
			cd.apply_fall_penalty()


func _enter_walk_mode() -> void:
	if _mode == MoveMode.WALK:
		return
	_mode = MoveMode.WALK
	motion_mode = MOTION_MODE_GROUNDED
	floor_snap_length = 0.4
	up_direction = Vector3.UP
	avatar.set_flight_mode(false)
	velocity.y = 0.0
	_move_velocity = Vector3.ZERO
	_floor_contact_time = 0.0
	_tween_camera_distance(WALK_CAMERA_DISTANCE)
	_lift = minf(LIFT_MAX, _lift + LIFT_GROUND_RECOVERY * 0.5)
	mode_changed.emit("walk")


func _enter_flight_mode(boost: bool = true) -> void:
	_mode = MoveMode.FLIGHT
	motion_mode = MOTION_MODE_FLOATING
	floor_snap_length = 0.0
	avatar.set_flight_mode(true)
	_move_velocity = velocity
	if boost:
		_move_velocity.y = maxf(_move_velocity.y, TAKEOFF_BOOST)
	velocity = _move_velocity
	_floor_contact_time = 0.0
	_apply_flight_settings()
	mode_changed.emit("flight")


func _apply_flight_settings() -> void:
	if _mode != MoveMode.FLIGHT:
		return
	_tween_camera_distance(FlightSettings.camera_distance)
	camera.fov = FlightSettings.camera_fov


func _tween_camera_distance(target_distance: float) -> void:
	if _camera_tween:
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(spring_arm, "spring_length", target_distance, CAMERA_TWEEN_DURATION)


func _apply_camera_rotation() -> void:
	camera_pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)


func _apply_look_delta(relative: Vector2) -> void:
	if relative.length_squared() < 0.0001:
		return
	var scale := TOUCH_LOOK_SCALE if MobileInput.is_touch_device() else 1.0
	_camera_yaw -= relative.x * FlightSettings.mouse_sensitivity * scale
	_camera_pitch -= relative.y * FlightSettings.mouse_sensitivity * scale
	_camera_pitch = clampf(_camera_pitch, -1.0, 0.6)


func _read_move_input() -> Vector2:
	if _bot_active:
		return _bot_move
	var input_dir := Vector2.ZERO
	if _is_key(KEY_A) or _is_key(KEY_LEFT):
		input_dir.x -= 1.0
	if _is_key(KEY_D) or _is_key(KEY_RIGHT):
		input_dir.x += 1.0
	if _is_key(KEY_W) or _is_key(KEY_UP):
		input_dir.y -= 1.0
	if _is_key(KEY_S) or _is_key(KEY_DOWN):
		input_dir.y += 1.0
	if MobileInput.move_vector.length_squared() > 0.001:
		input_dir = MobileInput.move_vector
	if input_dir.length_squared() > 1.0:
		input_dir = input_dir.normalized()
	return input_dir


func _read_camera_horizontal_direction(input_dir: Vector2) -> Vector3:
	var yaw_basis := Basis.from_euler(Vector3(0.0, _camera_yaw, 0.0))
	var forward := -yaw_basis.z
	var right := yaw_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return forward * (-input_dir.y) + right * input_dir.x


func _read_flight_move_direction(input_dir: Vector2) -> Vector3:
	var cam_basis := Basis.from_euler(Vector3(_camera_pitch, _camera_yaw, 0.0))
	var cam_forward := -cam_basis.z
	var cam_right := cam_basis.x
	cam_right.y = 0.0
	if cam_right.length_squared() > 0.001:
		cam_right = cam_right.normalized()

	var move_dir := Vector3.ZERO
	if absf(input_dir.x) > 0.001:
		move_dir += cam_right * input_dir.x
	if absf(input_dir.y) > 0.001:
		move_dir += cam_forward * (-input_dir.y)
	return move_dir


func _read_vertical_input() -> float:
	if _bot_active and _bot_fly_up:
		return 1.0
	var vertical := 0.0
	if _is_key(KEY_SPACE) or _is_key(KEY_E) or MobileInput.fly_up:
		vertical += 1.0
	return vertical


func get_dash_cooldown_ratio() -> float:
	if DASH_COOLDOWN <= 0.0:
		return 1.0
	return 1.0 - clampf(_dash_cooldown / DASH_COOLDOWN, 0.0, 1.0)


func _consume_dash_input() -> bool:
	if _bot_active and _bot_dash_pending:
		_bot_dash_pending = false
		return true
	var shift_now := _is_key(KEY_SHIFT)
	var shift_just := shift_now and not _shift_was_pressed
	_shift_was_pressed = shift_now
	return shift_just or MobileInput.consume_dash()


func _try_dash(input_dir: Vector2) -> void:
	if _dash_cooldown > 0.0 or _lift < DASH_LIFT_COST or _stillness_depth > 0:
		return
	var dash_dir := _read_flight_move_direction(input_dir)
	if dash_dir.length_squared() < 0.001:
		dash_dir = _read_camera_horizontal_direction(Vector2(0.0, -1.0))
	dash_dir.y = 0.0
	if dash_dir.length_squared() < 0.001:
		return
	dash_dir = dash_dir.normalized()
	_move_velocity += dash_dir * DASH_IMPULSE
	_dash_cooldown = DASH_COOLDOWN
	_lift = maxf(0.0, _lift - DASH_LIFT_COST)


func _is_key(keycode: Key) -> bool:
	return Input.is_key_pressed(keycode) or Input.is_physical_key_pressed(keycode)


func _countdown() -> Node:
	return get_node_or_null("/root/CountdownManager")


func _apply_wind_forces(delta: float) -> void:
	for entry: Dictionary in _wind_forces.values():
		_move_velocity += entry["force"] * delta
