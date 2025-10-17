extends Node3D

# Referencje do węzłów
@onready var xr_origin = $XROrigin3D
@onready var xr_camera = $XROrigin3D/XRCamera3D
@onready var left_controller = $XROrigin3D/XRController3D2
@onready var right_controller = $XROrigin3D/XRController3D

# Ustawienia ruchu
@export var move_speed: float = 3.0
@export var turn_angle: float = 30.0
@export var smooth_turn_speed: float = 90.0
@export var use_smooth_turning: bool = true

# Ustawienia teleportacji
@export var teleport_enabled: bool = true
@export var max_teleport_distance: float = 10.0
@export var teleport_button: String = "trigger_click"

# Zmienne wewnętrzne
var velocity: Vector3 = Vector3.ZERO
var gravity: float = 9.8
var is_grounded: bool = false
var grabbed_object_left = null
var grabbed_object_right = null

# Wskaźnik teleportacji (opcjonalnie)
var teleport_marker: MeshInstance3D
var is_teleport_valid: bool = false
var teleport_target: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Inicjalizacja kontrolerów
	if left_controller:
		left_controller.button_pressed.connect(_on_left_button_pressed)
		left_controller.button_released.connect(_on_left_button_released)
	
	if right_controller:
		right_controller.button_pressed.connect(_on_right_button_pressed)
		right_controller.button_released.connect(_on_right_button_released)
	
	# Tworzenie markera teleportacji
	if teleport_enabled:
		_create_teleport_marker()

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_rotation(delta)
	_apply_gravity(delta)
	_check_ground()

# ===== RUCH =====
func _handle_movement(delta: float) -> void:
	if not left_controller:
		return
	
	# Pobieranie wejścia z joysticka lewego kontrolera
	var input_vector = Vector2(
		left_controller.get_vector2("primary").x,
		-left_controller.get_vector2("primary").y
	)
	
	if input_vector.length() > 0.1:
		# Kierunek względem kamery
		var camera_basis = xr_camera.global_transform.basis
		var forward = camera_basis.z
		var right = camera_basis.x
		
		# Płaski ruch (bez Y)
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()
		
		# Obliczanie kierunku ruchu
		var move_direction = (forward * input_vector.y + right * input_vector.x).normalized()
		
		# Aplikowanie ruchu
		xr_origin.global_position += move_direction * move_speed * delta

# ===== OBRÓT =====
func _handle_rotation(delta: float) -> void:
	if not right_controller:
		return
	
	var turn_input = right_controller.get_vector2("primary").x
	
	if use_smooth_turning:
		# Płynny obrót
		if abs(turn_input) > 0.1:
			xr_origin.rotate_y(deg_to_rad(-turn_input * smooth_turn_speed * delta))
	else:
		# Skokowy obrót (snap turning)
		if abs(turn_input) > 0.5 and not has_meta("turn_cooldown"):
			var angle = turn_angle if turn_input > 0 else -turn_angle
			xr_origin.rotate_y(deg_to_rad(-angle))
			
			# Cooldown na obrót
			set_meta("turn_cooldown", true)
			get_tree().create_timer(0.3).timeout.connect(func(): remove_meta("turn_cooldown"))

# ===== GRAWITACJA =====
func _apply_gravity(delta: float) -> void:
	if not is_grounded:
		velocity.y -= gravity * delta
		xr_origin.global_position += Vector3(0, velocity.y * delta, 0)
	else:
		velocity.y = 0

func _check_ground() -> void:
	# Raycast w dół do sprawdzenia podłoża
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		xr_origin.global_position,
		xr_origin.global_position + Vector3(0, -0.2, 0)
	)
	
	var result = space_state.intersect_ray(query)
	is_grounded = result.size() > 0

# ===== TELEPORTACJA =====   (obecnie zbugowane, zaznaczyć checmark do wyłączenia)
func _create_teleport_marker() -> void:
	teleport_marker = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.3
	cylinder.bottom_radius = 0.3
	cylinder.height = 0.05
	teleport_marker.mesh = cylinder
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 1, 0, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	teleport_marker.material_override = material
	
	teleport_marker.visible = false
	add_child(teleport_marker)

func _show_teleport_ray() -> void:
	if not teleport_marker or not right_controller:
		return
	
	# Raycast z prawego kontrolera
	var space_state = get_world_3d().direct_space_state
	var from = right_controller.global_position
	var forward = -right_controller.global_transform.basis.z
	var to = from + forward * max_teleport_distance
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		teleport_target = result.position
		teleport_marker.global_position = teleport_target
		teleport_marker.visible = true
		is_teleport_valid = true
		
		# Zmiana koloru na zielony
		var mat = teleport_marker.material_override as StandardMaterial3D
		mat.albedo_color = Color(0, 1, 0, 0.5)
	else:
		is_teleport_valid = false
		teleport_marker.visible = false

func _execute_teleport() -> void:
	if is_teleport_valid:
		# Teleportacja z zachowaniem wysokości kamery
		var camera_offset = xr_camera.position
		camera_offset.y = 0  # Ignorujemy wysokość kamery
		
		xr_origin.global_position = teleport_target - camera_offset
	
	teleport_marker.visible = false
	is_teleport_valid = false

# ===== PRZYCISKI =====
func _on_left_button_pressed(button: String) -> void:
	match button:
		"grip_click":
			_try_grab_object(left_controller, "left")
			print("Lewy grip wciśnięty")
		"trigger_click":
			print("Lewy trigger wciśnięty")

func _on_left_button_released(button: String) -> void:
	match button:
		"grip_click":
			_release_object("left")

func _on_right_button_pressed(button: String) -> void:
	match button:
		"grip_click":
			_try_grab_object(right_controller, "right")
			print("Prawy grip wciśnięty")
		"trigger_click":
			if teleport_enabled:
				_show_teleport_ray()
			else:
				print("Prawy trigger wciśnięty")

func _on_right_button_released(button: String) -> void:
	match button:
		"grip_click":
			_release_object("right")
		"trigger_click":
			if teleport_enabled:
				_execute_teleport()

# ===== CHWYTANIE OBIEKTÓW =====
func _try_grab_object(controller: XRController3D, hand: String) -> void:
	# Szukanie obiektów w zasięgu (wymaga Area3D na kontrolerze)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	var sphere = SphereShape3D.new()
	sphere.radius = 0.15
	query.shape = sphere
	query.transform = controller.global_transform
	
	var results = space_state.intersect_shape(query, 1)
	
	if results.size() > 0:
		var obj = results[0].collider
		if obj.is_in_group("grabbable"):
			if hand == "left":
				grabbed_object_left = obj
			else:
				grabbed_object_right = obj
			
			# Zmiana rodzica obiektu na kontroler
			if obj is RigidBody3D:
				obj.freeze = true
			
			var original_global_pos = obj.global_position
			var original_global_rot = obj.global_rotation
			
			obj.get_parent().remove_child(obj)
			controller.add_child(obj)
			
			obj.global_position = original_global_pos
			obj.global_rotation = original_global_rot

func _release_object(hand: String) -> void:
	var obj = grabbed_object_left if hand == "left" else grabbed_object_right
	
	if obj:
		var original_global_pos = obj.global_position
		var original_global_rot = obj.global_rotation
		
		obj.get_parent().remove_child(obj)
		get_tree().root.add_child(obj)
		
		obj.global_position = original_global_pos
		obj.global_rotation = original_global_rot
		
		if obj is RigidBody3D:
			obj.freeze = false
			# Dodanie prędkości przy rzucaniu
			var controller = left_controller if hand == "left" else right_controller
			if controller.get("linear_velocity"):
				obj.linear_velocity = controller.get("linear_velocity")
		
		if hand == "left":
			grabbed_object_left = null
		else:
			grabbed_object_right = null
