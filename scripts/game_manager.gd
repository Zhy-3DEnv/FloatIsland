extends Node

signal star_collected(stars: int, total: int, score: int, next_island: String)
signal route_completed(score: int)

## 从起点岛出发，按顺序飞越的岛屿路线（首项为出生点，不放置星星）
const ROUTE: Array[String] = [
	"floating_island_3d_model",
	"floating_island_05",
	"floating_island_01",
	"floating_island_06",
	"floating_island_09",
	"floating_island_08",
	"floating_island_07",
	"floating_island_04",
	"floating_island_03",
	"floating_island_10",
	"floating_island_02",
]

const POINTS_PER_STAR := 100
const START_HEIGHT_OFFSET := 25.0
const STAR_HEIGHT_OFFSET := 4.0

var score: int = 0
var stars_collected: int = 0
var _target_index: int = 1


func get_spawn_position(islands_root: Node) -> Vector3:
	var start := islands_root.get_node_or_null(ROUTE[0])
	if start:
		return start.global_position + Vector3(0.0, START_HEIGHT_OFFSET, 0.0)
	return Vector3(0.0, START_HEIGHT_OFFSET, 0.0)


func get_total_stars() -> int:
	return ROUTE.size() - 1


func get_current_target_island() -> String:
	if _target_index >= ROUTE.size():
		return ""
	return ROUTE[_target_index]


func get_current_target_position(islands_root: Node) -> Vector3:
	var name := get_current_target_island()
	if name.is_empty():
		return Vector3.ZERO
	var island := islands_root.get_node_or_null(name)
	if island:
		return island.global_position + Vector3(0.0, STAR_HEIGHT_OFFSET, 0.0)
	return Vector3.ZERO


func is_target_island(island_name: String) -> bool:
	return island_name == get_current_target_island()


func is_route_finished() -> bool:
	return _target_index >= ROUTE.size()


func is_island_collected(island_name: String) -> bool:
	var idx := ROUTE.find(island_name)
	return idx >= 0 and idx < _target_index


func try_collect_star(island_name: String) -> bool:
	if is_route_finished():
		return false
	if island_name != get_current_target_island():
		return false

	score += POINTS_PER_STAR
	stars_collected += 1
	_target_index += 1

	var next_island := get_current_target_island()
	star_collected.emit(stars_collected, get_total_stars(), score, next_island)

	if is_route_finished():
		route_completed.emit(score)

	return true
