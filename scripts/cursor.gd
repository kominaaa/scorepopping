extends Node3D

@export var camera: Camera3D
@export var cursor: Node3D
@export var distance: float = 1.0

@export var bump_scale: float = 1.15
@export var bump_duration: float = 0.08

var base_scale: Vector3

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	if cursor == null:
		push_error("CursorController : cursor non assigné")
		return

	base_scale = cursor.scale

func _process(delta: float) -> void:
	if camera == null or cursor == null:
		return

	var vp := camera.get_viewport()
	var mouse_pos := vp.get_mouse_position()

	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	cursor.global_position = ray_origin + ray_dir * distance

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		play_bump()

func play_bump() -> void:
	# Reset immédiat pour éviter l'accumulation
	cursor.scale = base_scale

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		cursor,
		"scale",
		base_scale * bump_scale,
		bump_duration
	)

	tween.tween_property(
		cursor,
		"scale",
		base_scale,
		bump_duration * 1.2
	)
