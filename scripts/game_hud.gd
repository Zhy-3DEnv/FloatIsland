extends CanvasLayer

@onready var score_label: Label = $Panel/VBox/ScoreLabel
@onready var stars_label: Label = $Panel/VBox/StarsLabel
@onready var target_label: Label = $Panel/VBox/TargetLabel
@onready var hint_label: Label = $Panel/VBox/HintLabel
@onready var mode_label: Label = $Panel/VBox/ModeLabel


func _ready() -> void:
	var gm := _gm()
	gm.star_collected.connect(_on_star_collected)
	gm.route_completed.connect(_on_route_completed)
	_refresh()
	call_deferred("_connect_player")


func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_signal("mode_changed"):
		player.mode_changed.connect(_on_mode_changed)
		_on_mode_changed(player.get_mode_name())


func _on_mode_changed(mode_name: String) -> void:
	if mode_name == "walk":
		mode_label.text = "模式 · 角色行走"
		hint_label.text = "WASD 行走 · 空格 跳跃 · F 召唤飞龙"
	else:
		mode_label.text = "模式 · 骑龙飞行"
		hint_label.text = "WASD 飞行 · 空格/E 上升 · Q 下降 · 落岛切换为角色"


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var gm := _gm()
	if player == null or gm.is_route_finished():
		return
	var target_pos: Vector3 = gm.get_current_target_position(_get_islands_root())
	if target_pos != Vector3.ZERO:
		var dist: float = player.global_position.distance_to(target_pos)
		target_label.text = "下一目标 · 距离 %.0fm" % dist


func _on_star_collected(stars: int, total: int, score: int, next_island: String) -> void:
	stars_label.text = "星星 %d / %d" % [stars, total]
	score_label.text = "积分 %d" % score
	if next_island.is_empty():
		target_label.text = "全部完成！"
	else:
		target_label.text = "下一目标 · %s" % _friendly_name(next_island)
	_refresh()


func _on_route_completed(score: int) -> void:
	var gm := _gm()
	score_label.text = "积分 %d" % score
	stars_label.text = "星星 %d / %d" % [gm.get_total_stars(), gm.get_total_stars()]
	target_label.text = "巡游完成！"
	hint_label.text = "恭喜完成全部浮岛路线"


func _refresh() -> void:
	var gm := _gm()
	stars_label.text = "星星 %d / %d" % [gm.stars_collected, gm.get_total_stars()]
	score_label.text = "积分 %d" % gm.score
	var next: String = gm.get_current_target_island()
	if next.is_empty():
		target_label.text = "准备起飞"
	else:
		target_label.text = "下一目标 · %s" % _friendly_name(next)


func _get_islands_root() -> Node:
	return get_tree().current_scene


func _friendly_name(island_name: String) -> String:
	if island_name == "floating_island_3d_model":
		return "起点岛"
	if island_name.begins_with("floating_island_"):
		return "浮岛 %s" % island_name.trim_prefix("floating_island_")
	return island_name


func _gm() -> Node:
	return get_node("/root/GameManager")
