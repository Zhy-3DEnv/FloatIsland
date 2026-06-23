extends CSGBox3D

@export var clouds_to_spawn = 3
@export var cloud: PackedScene

var rng = RandomNumberGenerator.new()

func _ready():
	spawn_clouds()
	
func spawn_clouds():
	while clouds_to_spawn >= 0:
		clouds_to_spawn -= 1
		
		var x = rng.randf_range(size.x/2, -size.x/2)
		var y = rng.randf_range(size.y/2, -size.y/2)
		var z = rng.randf_range(size.z/2, -size.z/2)
		
		var spawn_pos = Vector3(x,y,z)
		var cloud_instance = cloud.instantiate()
		add_child(cloud_instance)
		cloud_instance.global_position = global_position + spawn_pos
