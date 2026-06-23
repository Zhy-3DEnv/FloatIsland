extends Node3D

const OceanTile = preload("res://scenes/ocean/water_plane.tscn")
const SpawnPoint = preload("res://resources/grid_spawn_info.tres")

var _tiles: Array[MeshInstance3D] = []


func create_ocean_tiles() -> void:
	for i in 17:
		var spawn_location: Vector2 = SpawnPoint.spawnPoints[i]
		var tile_subdivision: int = SpawnPoint.subdivision[i]
		var tile_scale: int = SpawnPoint.scale[i]
		var instance: MeshInstance3D = OceanTile.instantiate()

		add_child(instance)
		_tiles.append(instance)

		instance.position = Vector3(spawn_location.x, 0.0, spawn_location.y) * 10.05
		instance.mesh.set_subdivide_width(tile_subdivision)
		instance.mesh.set_subdivide_depth(tile_subdivision)
		instance.set_scale(Vector3(tile_scale, 1.0, tile_scale))


func _ready() -> void:
	create_ocean_tiles()
	_update_ocean_center()


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		position.x = player.global_position.x
		position.z = player.global_position.z
	_update_ocean_center()


func _update_ocean_center() -> void:
	for tile in _tiles:
		var material := tile.get_surface_override_material(0) as ShaderMaterial
		if material:
			material.set_shader_parameter("ocean_center", global_position)
