extends Node3D

@export var camera: Camera3D
@export var cursor: Node3D

func _process(delta):
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	var mouse_pos: Vector2 = DisplayServer.mouse_get_position()
	
	var viewport_size: Vector2 = DisplayServer.window_get_size()
	var normalized_mouse_pos: Vector2 = mouse_pos / viewport_size / 2.2
	
	var ray_origin: Vector3 = camera.project_ray_origin(normalized_mouse_pos * viewport_size)
	var ray_direction: Vector3 = camera.project_ray_normal(normalized_mouse_pos * viewport_size)
	
	var distance: float = 1.0
	var target_position: Vector3 = ray_origin + ray_direction * distance
	
	cursor.position = target_position
