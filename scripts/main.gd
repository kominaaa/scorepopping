extends Node3D

@export var camera: Camera3D
@export var score_value_label: Label

var score: int = 0

func _ready():
	# Initialisation du score
	score = 0
	if score_value_label:
		score_value_label.text = str(score)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos: Vector2 = event.position
		var from: Vector3 = camera.project_ray_origin(mouse_pos)
		var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * 10000.0

		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		var result: Dictionary = space_state.intersect_ray(query)

		if result:
			var collider = result.collider
			if collider and "on_clicked" in collider:
				collider.on_clicked(result.position)

func increment_score(value: int):
	score += value
	if score_value_label:
		score_value_label.text = str(score)
