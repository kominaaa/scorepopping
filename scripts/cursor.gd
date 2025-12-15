extends Node3D

@export var camera: Camera3D
@export var cursor: Node3D
@export var distance: float = 1.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _process(delta: float) -> void:
	if camera == null or cursor == null:
		return

	var vp := camera.get_viewport()
	var mouse_pos: Vector2 = vp.get_mouse_position() # coord pixels DANS le viewport

	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_pos)

	cursor.global_position = ray_origin + ray_dir * distance
