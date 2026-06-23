extends CanvasLayer

@onready var timer_label: Label = $StatusPanel/VBox/TimerLabel
@onready var stability_bar: ProgressBar = $StatusPanel/VBox/StabilityBar
@onready var energy_label: Label = $StatusPanel/VBox/EnergyLabel
@onready var target_label: Label = $StatusPanel/VBox/TargetLabel
@onready var objective_label: Label = $StatusPanel/VBox/ObjectiveLabel
@onready var objective_detail_label: Label = $StatusPanel/VBox/ObjectiveDetailLabel
@onready var hint_label: Label = $StatusPanel/VBox/HintLabel
@onready var mode_label: Label = $StatusPanel/VBox/ModeLabel
@onready var lift_bar: ProgressBar = $StatusPanel/VBox/LiftBar
@onready var lift_label: Label = $StatusPanel/VBox/LiftLabel
@onready var intro_panel: PanelContainer = $IntroPanel
@onready var intro_text: Label = $IntroPanel/Margin/VBox/IntroText
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_title: Label = $ResultPanel/Margin/VBox/Title
@onready var result_body: Label = $ResultPanel/Margin/VBox/Body
@onready var toast_label: Label = $ToastLabel

var _toast_timer := 0.0
var _controls_hint := ""
var _showing_mission_hint := false


func _ready() -> void:
	intro_panel.visible = false
	result_panel.visible = false
	toast_label.visible = false

	var gm := _gm()
	gm.energy_changed.connect(_on_energy_changed)
	gm.island_unlocked.connect(_on_island_unlocked)
	gm.island_completed.connect(_on_island_completed)
	gm.mission_target_changed.connect(_refresh_guidance)
	gm.game_started.connect(_on_game_started)
	gm.game_won.connect(_on_game_won)
	gm.mission_progress.connect(_on_mission_progress)

	var cd: Node = _countdown()
	if cd:
		cd.time_changed.connect(_on_time_changed)
		cd.countdown_started.connect(_on_countdown_started)
		cd.victory.connect(_on_victory)
		cd.defeat.connect(_on_defeat)
		_on_time_changed(cd.time_remaining, cd.get_stability_percent())
	_on_energy_changed(gm.energy, gm.get_energy_target())
	_refresh_guidance()

	if MobileInput.is_touch_device():
		_controls_hint = "左半屏摇杆 · 其余区域转视角 · 设 打开设置"
	else:
		_controls_hint = "WASD 飞行 · 空格/E 上升 · Shift 冲刺 · 坠崖扣 5 秒"
	hint_label.text = _controls_hint
	call_deferred("_connect_player")


func _process(delta: float) -> void:
	_update_timer_display()
	_update_guidance()
	_update_lift_bar()
	_update_toast(delta)


func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_signal("mode_changed"):
		player.mode_changed.connect(_on_mode_changed)
		_on_mode_changed(player.get_mode_name())


func _on_mode_changed(mode_name: String) -> void:
	var show_lift := mode_name == "flight"
	lift_bar.visible = show_lift
	lift_label.visible = show_lift
	if mode_name == "walk":
		mode_label.text = "模式 · 陆地行走"
	else:
		mode_label.text = "模式 · 龙翼飞行"
	_apply_hint_text()


func _on_game_started() -> void:
	intro_panel.visible = true
	intro_text.text = (
		"心核裂解，天枢失稳。\n"
		+ "10 分钟内回收 50 点共鸣能量。\n\n"
		+ "第一步（任选一座）：\n"
		+ "· 浮岛 01 — 落岛采集共鸣点（推荐新手）\n"
		+ "· 浮岛 05 — 飞行穿过蓝色光环\n\n"
		+ "跟随蓝色光柱与屏幕箭头前进。"
	)
	await get_tree().create_timer(4.5).timeout
	intro_panel.visible = false
	_refresh_guidance()
	_refresh_all_missions()
	_show_toast("看左上角任务指引 · 光柱指向最近目标岛", 4.0)


func _on_countdown_started() -> void:
	_show_toast("倒计时开始！飞往浮岛 01 或 浮岛 05", 3.5)
	_refresh_guidance()


func _on_time_changed(seconds_left: float, stability_percent: float) -> void:
	_set_timer_display(seconds_left, stability_percent)


func _update_timer_display() -> void:
	var cd: Node = _countdown()
	if cd and cd.running and not cd.finished:
		_set_timer_display(cd.time_remaining, cd.get_stability_percent())


func _set_timer_display(seconds_left: float, stability_percent: float) -> void:
	if timer_label:
		timer_label.text = _format_time(seconds_left)
	if stability_bar:
		stability_bar.value = stability_percent


func _on_energy_changed(current: int, target: int) -> void:
	energy_label.text = "共鸣能量 %d / %d" % [current, target]


func _on_island_unlocked(island_name: String) -> void:
	_show_toast("新目标可及 · %s" % _gm().friendly_island_name(island_name), 2.0)
	_refresh_guidance()


func _on_island_completed(island_name: String, energy: int) -> void:
	_show_toast(
		"%s 完成 · +%d 能量" % [_gm().friendly_island_name(island_name), GameManager.ENERGY_PER_ISLAND],
		2.0
	)
	if energy >= GameManager.FINAL_ISLAND_ENERGY_GATE and island_name != "floating_island_08":
		_show_toast("最终地脉苏醒 · 前往浮岛 08", 3.0)
	_refresh_guidance()


func _on_mission_progress(message: String) -> void:
	_show_toast(message, 2.0)


func _on_game_won() -> void:
	_refresh_guidance()


func _on_victory() -> void:
	result_panel.visible = true
	result_title.text = "天枢停降"
	result_body.text = "共鸣重聚，天枢停降。群岛得保。"


func _on_defeat() -> void:
	result_panel.visible = true
	result_title.text = "天枢坠落"
	result_body.text = "天枢坠落……一切归于静寂。\n按 R 重试"


func _update_guidance() -> void:
	var gm := _gm()
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var guide: Dictionary = gm.get_guidance(_get_islands_root(), player.global_position)
	objective_label.text = "▶ %s" % guide.get("objective", "")
	var detail: String = guide.get("detail", "")
	objective_detail_label.text = detail
	objective_detail_label.visible = not detail.is_empty()

	var dist: float = guide.get("distance", 0.0)
	var target_name: String = guide.get("target_label", "")
	if not gm.is_game_started():
		target_label.text = "任务准备中"
	elif gm.is_game_won():
		target_label.text = "巡游完成"
	elif target_name.is_empty():
		target_label.text = "暂无目标"
	elif dist > 0.0:
		target_label.text = "导航 · %s · %.0fm" % [target_name, dist]
	else:
		target_label.text = "导航 · %s" % target_name

	_showing_mission_hint = gm.is_game_started() and not gm.is_game_won()
	_apply_hint_text()


func _refresh_guidance() -> void:
	_update_guidance()


func _apply_hint_text() -> void:
	if not _showing_mission_hint:
		hint_label.text = _controls_hint
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		hint_label.text = _controls_hint
		return
	var guide: Dictionary = _gm().get_guidance(_get_islands_root(), player.global_position)
	var dist: float = guide.get("distance", 999.0)
	if dist > 90.0:
		hint_label.text = "操控：%s ｜ 远处看蓝色光柱" % _short_controls_hint()
	elif dist > 35.0:
		hint_label.text = "操控：%s ｜ 快到了，注意减速" % _short_controls_hint()
	else:
		hint_label.text = "操控：%s" % _short_controls_hint()


func _short_controls_hint() -> String:
	if MobileInput.is_touch_device():
		return "摇杆移动 · 右半屏转视角"
	return "WASD · 空格上升 · Shift 冲刺"


func _update_lift_bar() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("get_lift_ratio"):
		return
	if not lift_bar.visible:
		return
	var ratio: float = player.get_lift_ratio()
	lift_bar.value = ratio * 100.0


func _show_toast(text: String, duration: float) -> void:
	toast_label.text = text
	toast_label.visible = true
	_toast_timer = duration


func _update_toast(delta: float) -> void:
	if _toast_timer <= 0.0:
		return
	_toast_timer -= delta
	if _toast_timer <= 0.0:
		toast_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			var cd: Node = _countdown()
			if cd and (cd.finished or _gm().is_game_won()):
				_retry_game()


func _retry_game() -> void:
	_gm().retry_game()
	get_tree().reload_current_scene()


func _format_time(seconds_left: float) -> String:
	var total := maxi(0, int(ceil(seconds_left)))
	var minutes := total / 60
	var seconds := total % 60
	return "%d:%02d" % [minutes, seconds]


func _get_islands_root() -> Node:
	return get_tree().current_scene


func _gm() -> Node:
	return get_node("/root/GameManager")


func _countdown() -> Node:
	return get_node_or_null("/root/CountdownManager")


func _refresh_all_missions() -> void:
	var root := _get_islands_root()
	if root == null:
		return
	for island_name: String in _gm().M1_ISLAND_ORDER:
		var mission := root.get_node_or_null("%s/IslandMission" % island_name)
		if mission and mission.has_method("_refresh_active_state"):
			mission._refresh_active_state()
