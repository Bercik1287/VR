extends Node3D

@onready var raycast = $LaserRay
@onready var laser_mesh = $LaserMesh  
@onready var input_action = "vr_spust_prawy"  

func _process(_delta):
	# Aktualizuj laser długość i pozycję
	if raycast.is_colliding():
		var hit_pos = raycast.get_collision_point()
		var distance = global_position.distance_to(hit_pos)
		laser_mesh.scale.z = distance
	else:
		laser_mesh.scale.z = 10.0  

	
	if Input.is_action_just_pressed(input_action):
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider is MeshInstance3D:
			
				var mat = collider.get_active_material(0)
				if mat:
					mat.albedo_color = Color.RED
