@tool
extends Node3D

const BANK_SPEED := 10.0
const IDLE_WING_AMP := 0.35
const FLY_WING_AMP := 0.75
const TRANSITION_DURATION := 0.35

@export_group("Wing Flap Timing")
## 扑翼基础频率（越大扇动越快；约 6≈每秒 0.5 拍，12≈每秒 1 拍）
@export_range(1.0, 24.0, 0.1) var wing_flap_speed := 6.0:
	set(value):
		wing_flap_speed = value
		_sync_editor_preview()
## 悬停/低速时的频率倍率（相对 wing_flap_speed）
@export_range(0.1, 2.0, 0.01) var wing_flap_idle_rate := 0.55:
	set(value):
		wing_flap_idle_rate = value
		_sync_editor_preview()
## 全速飞行时的频率倍率（相对 wing_flap_speed）
@export_range(0.1, 2.0, 0.01) var wing_flap_fly_rate := 0.45:
	set(value):
		wing_flap_fly_rate = value
		_sync_editor_preview()

@export_group("Wing Upstroke")
## 肩关节上扑幅度倍率（仅影响上展，下扑不变）
@export_range(0.1, 1.5, 0.01) var upstroke_shoulder_scale := 0.62:
	set(value):
		upstroke_shoulder_scale = value
		_sync_editor_preview()
## 中段指节（MidFingerPivot）上卷幅度
@export_range(0.0, 1.0, 0.01) var upstroke_finger_flex := 0.38:
	set(value):
		upstroke_finger_flex = value
		_sync_editor_preview()
## 翼尖（TipFingerPivot）Z 轴上卷倍率，相对 upstroke_finger_flex
@export_range(0.5, 2.0, 0.01) var upstroke_tip_flex_z := 1.1:
	set(value):
		upstroke_tip_flex_z = value
		_sync_editor_preview()
## 翼尖（TipFingerPivot）X 轴 cup 起幅度，相对 upstroke_finger_flex
@export_range(0.0, 0.8, 0.01) var upstroke_tip_flex_x := 0.15:
	set(value):
		upstroke_tip_flex_x = value
		_sync_editor_preview()

@export_group("Wing Joint Bend")
## 中段指节 Z 轴弯曲倍率（相对肩关节，越大弯折越明显）
@export_range(0.0, 1.5, 0.01) var span_mid_follow := 0.58:
	set(value):
		span_mid_follow = value
		_sync_editor_preview()
## 翼尖 Z 轴弯曲倍率（通常大于中段）
@export_range(0.0, 2.0, 0.01) var span_tip_follow := 1.05:
	set(value):
		span_tip_follow = value
		_sync_editor_preview()
## 指节 X 轴随 Z 弯曲的混合比（增加翼面立体感，保持较小避免前后晃）
@export_range(0.0, 0.6, 0.01) var span_x_blend := 0.28:
	set(value):
		span_x_blend = value
		_sync_editor_preview()
## 中段相对肩关节的相位滞后（扑翼周期比例，产生关节跟随感）
@export_range(0.0, 0.25, 0.005) var joint_lag_mid := 0.07:
	set(value):
		joint_lag_mid = value
		_sync_editor_preview()
## 翼尖相对肩关节的相位滞后（通常大于中段）
@export_range(0.0, 0.35, 0.005) var joint_lag_tip := 0.14:
	set(value):
		joint_lag_tip = value
		_sync_editor_preview()

@export_group("Editor Preview")
@export var editor_preview_wings := false:
	set(value):
		editor_preview_wings = value
		_sync_editor_preview()
@export var editor_animate := true:
	set(value):
		editor_animate = value
		_sync_editor_preview()
@export_range(0.0, 1.0, 0.001) var editor_stroke := 0.0:
	set(value):
		editor_stroke = value
		_sync_editor_preview()
@export_range(0.0, 1.0, 0.01) var editor_speed_ratio := 0.5:
	set(value):
		editor_speed_ratio = value
		_sync_editor_preview()

@onready var core: Node3D = $Core
@onready var dragon_addons: Node3D = $DragonAddons
@onready var wing_left_pivot: Node3D = $DragonAddons/WingLeftPivot
@onready var wing_right_pivot: Node3D = $DragonAddons/WingRightPivot
@onready var wing_left_mid: Node3D = $DragonAddons/WingLeftPivot/MidFingerPivot
@onready var wing_left_tip: Node3D = $DragonAddons/WingLeftPivot/MidFingerPivot/TipFingerPivot
@onready var wing_right_mid: Node3D = $DragonAddons/WingRightPivot/MidFingerPivot
@onready var wing_right_tip: Node3D = $DragonAddons/WingRightPivot/MidFingerPivot/TipFingerPivot

var _wing_phase := 0.0
var _is_flight := true
var _transition_tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		_sync_editor_preview()
		return
	_set_addons_strength(1.0, false)


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_sync_editor_preview")


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	if not editor_preview_wings:
		return
	var step := delta if delta > 0.0 else 1.0 / 60.0
	_run_editor_preview(step)


func _sync_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return

	set_process(editor_preview_wings)
	process_mode = Node.PROCESS_MODE_ALWAYS if editor_preview_wings else Node.PROCESS_MODE_INHERIT
	if editor_preview_wings:
		_run_editor_preview(0.0)


func _run_editor_preview(delta: float) -> void:
	if not _resolve_wing_nodes():
		push_warning("Avatar: 编辑器预览找不到翅膀节点，请确认 WingLeftPivot / MidFingerPivot 等节点存在。")
		return

	dragon_addons.visible = true
	_set_addons_strength(1.0, false)

	var stroke: Dictionary
	if editor_animate:
		var step := delta if delta > 0.0 else 1.0 / 60.0
		_wing_phase += _flap_phase_delta(step, editor_speed_ratio)
		stroke = _pterosaur_stroke(_wing_phase)
	else:
		stroke = _stroke_at_cycle(editor_stroke)

	var amp := lerpf(IDLE_WING_AMP, FLY_WING_AMP, editor_speed_ratio)
	_apply_wing_pose(wing_left_pivot, wing_left_mid, wing_left_tip, stroke, amp, 1.0)
	_apply_wing_pose(wing_right_pivot, wing_right_mid, wing_right_tip, stroke, amp, -1.0)


func _resolve_wing_nodes() -> bool:
	if core == null:
		core = get_node_or_null("Core") as Node3D
	if dragon_addons == null:
		dragon_addons = get_node_or_null("DragonAddons") as Node3D
	if wing_left_pivot == null:
		wing_left_pivot = get_node_or_null("DragonAddons/WingLeftPivot") as Node3D
	if wing_right_pivot == null:
		wing_right_pivot = get_node_or_null("DragonAddons/WingRightPivot") as Node3D
	if wing_left_mid == null:
		wing_left_mid = get_node_or_null("DragonAddons/WingLeftPivot/MidFingerPivot") as Node3D
	if wing_left_tip == null:
		wing_left_tip = get_node_or_null("DragonAddons/WingLeftPivot/MidFingerPivot/TipFingerPivot") as Node3D
	if wing_right_mid == null:
		wing_right_mid = get_node_or_null("DragonAddons/WingRightPivot/MidFingerPivot") as Node3D
	if wing_right_tip == null:
		wing_right_tip = get_node_or_null("DragonAddons/WingRightPivot/MidFingerPivot/TipFingerPivot") as Node3D
	return (
		core != null
		and dragon_addons != null
		and wing_left_pivot != null
		and wing_right_pivot != null
		and wing_left_mid != null
		and wing_left_tip != null
		and wing_right_mid != null
		and wing_right_tip != null
	)


func set_flight_mode(enabled: bool, animated: bool = true) -> void:
	if _is_flight == enabled:
		return
	_is_flight = enabled

	if enabled:
		dragon_addons.visible = true
		if animated:
			_tween_addons(0.0, 1.0)
		else:
			_set_addons_strength(1.0, false)
	else:
		if animated:
			_tween_addons(1.0, 0.0, true)
		else:
			_set_addons_strength(0.0, false)
			dragon_addons.visible = false
		_reset_flight_pose()


func update_flight_pose(delta: float, move_velocity: Vector3, reference_speed: float) -> void:
	if not _is_flight:
		return

	var horiz_vel := Vector3(move_velocity.x, 0.0, move_velocity.z)
	var speed_ratio := clampf(horiz_vel.length() / maxf(reference_speed, 0.01), 0.0, 1.0)

	if horiz_vel.length_squared() > 0.5:
		var local_vel := core.global_transform.basis.inverse() * horiz_vel.normalized()
		core.rotation.z = lerp(core.rotation.z, -local_vel.x * 0.35, BANK_SPEED * delta)
		core.rotation.x = lerp(core.rotation.x, -move_velocity.y * 0.06, BANK_SPEED * delta)
	else:
		core.rotation.z = lerp(core.rotation.z, 0.0, BANK_SPEED * delta)
		core.rotation.x = lerp(core.rotation.x, 0.0, BANK_SPEED * delta)

	_wing_phase += _flap_phase_delta(delta, speed_ratio)
	var amp := lerpf(IDLE_WING_AMP, FLY_WING_AMP, speed_ratio)
	var stroke := _pterosaur_stroke(_wing_phase)

	_apply_wing_pose(wing_left_pivot, wing_left_mid, wing_left_tip, stroke, amp, 1.0)
	_apply_wing_pose(wing_right_pivot, wing_right_mid, wing_right_tip, stroke, amp, -1.0)


func face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.001:
		return
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, delta * 10.0)


func _flap_phase_delta(delta: float, speed_ratio: float) -> float:
	var rate := lerpf(wing_flap_idle_rate, wing_flap_fly_rate, speed_ratio)
	return delta * wing_flap_speed * rate


func _pterosaur_stroke(phase: float) -> Dictionary:
	return _stroke_at_cycle(fposmod(phase, TAU) / TAU)


func _stroke_at_cycle(cycle: float) -> Dictionary:
	var lift := cos(cycle * TAU)
	var lift_mid := cos(fposmod(cycle - joint_lag_mid, 1.0) * TAU)
	var lift_tip := cos(fposmod(cycle - joint_lag_tip, 1.0) * TAU)
	var down := (1.0 - lift) * 0.5

	return {
		"lift": lift,
		"lift_mid": lift_mid,
		"lift_tip": lift_tip,
		"down": down,
		"fold": (lift + 1.0) * 0.5,
	}


func _scaled_wing_lift(raw_lift: float) -> float:
	return raw_lift * upstroke_shoulder_scale if raw_lift > 0.0 else raw_lift


func _apply_wing_pose(
		shoulder: Node3D,
		mid_finger: Node3D,
		tip_finger: Node3D,
		stroke: Dictionary,
		amp: float,
		side: float) -> void:
	var lift: float = stroke.lift
	var lift_mid: float = stroke.get("lift_mid", lift)
	var lift_tip: float = stroke.get("lift_tip", lift)
	var fold: float = stroke.fold

	var shoulder_z := -_scaled_wing_lift(lift) * amp * side
	var mid_bend := -_scaled_wing_lift(lift_mid) * amp * span_mid_follow * side
	var tip_bend := -_scaled_wing_lift(lift_tip) * amp * span_tip_follow * side
	var curl_mid := -fold * upstroke_finger_flex * side
	var curl_tip_z := -fold * upstroke_finger_flex * upstroke_tip_flex_z * side
	var curl_tip_x := -fold * upstroke_finger_flex * upstroke_tip_flex_x * side

	shoulder.rotation.x = 0.0
	shoulder.rotation.y = 0.0
	shoulder.rotation.z = shoulder_z

	var mid_z := mid_bend + curl_mid
	var tip_z := tip_bend + curl_tip_z

	mid_finger.rotation.z = mid_z
	mid_finger.rotation.x = mid_z * span_x_blend
	mid_finger.rotation.y = 0.0

	tip_finger.rotation.z = tip_z
	tip_finger.rotation.x = tip_z * span_x_blend + curl_tip_x
	tip_finger.rotation.y = 0.0


func _tween_addons(from_strength: float, to_strength: float, hide_when_done: bool = false) -> void:
	if _transition_tween:
		_transition_tween.kill()
	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_method(_set_addons_strength, from_strength, to_strength, TRANSITION_DURATION)
	if hide_when_done:
		_transition_tween.tween_callback(func() -> void:
			if to_strength <= 0.01:
				dragon_addons.visible = false
		)


func _set_addons_strength(strength: float, _update_children: bool = true) -> void:
	strength = clampf(strength, 0.0, 1.0)
	dragon_addons.scale = Vector3.ONE * lerpf(0.001, 1.0, strength)


func _reset_flight_pose() -> void:
	core.rotation = Vector3.ZERO
	_reset_wing_pivots(wing_left_pivot, wing_left_mid, wing_left_tip)
	_reset_wing_pivots(wing_right_pivot, wing_right_mid, wing_right_tip)


func _reset_wing_pivots(shoulder: Node3D, mid_finger: Node3D, tip_finger: Node3D) -> void:
	shoulder.rotation = Vector3.ZERO
	mid_finger.rotation = Vector3.ZERO
	tip_finger.rotation = Vector3.ZERO
