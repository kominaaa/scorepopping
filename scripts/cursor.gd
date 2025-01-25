extends Node3D

@export var camera: Camera3D
@export var cursor: Node3D
@export var xy_scale_factor: float = 1.0  # Réduction facultative des mouvements sur X et Y

func _process(delta):
	var mouse_pos: Vector2 = DisplayServer.mouse_get_position()
	
	# Normalisation des coordonnées de la souris dans le viewport
	var viewport_size: Vector2 = DisplayServer.window_get_size()
	var normalized_mouse_pos: Vector2 = mouse_pos / viewport_size
	
	# Rayon projeté à partir des coordonnées normalisées
	var ray_origin: Vector3 = camera.project_ray_origin(normalized_mouse_pos * viewport_size)
	var ray_direction: Vector3 = camera.project_ray_normal(normalized_mouse_pos * viewport_size)
	
	# Distance pour positionner le curseur devant la caméra
	var distance: float = 0.1
	var target_position: Vector3 = ray_origin + ray_direction * distance
	
	# Réduction des déplacements sur X et Y si nécessaire
	var adjusted_position: Vector3 = target_position
	adjusted_position.x = ray_origin.x + (target_position.x - ray_origin.x) * xy_scale_factor
	adjusted_position.y = ray_origin.y + (target_position.y - ray_origin.y) * xy_scale_factor
	
	# Met à jour la position du curseur en 3D
	cursor.position = adjusted_position
