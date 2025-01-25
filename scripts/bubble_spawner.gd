extends Node3D

@export var bubble_scene: PackedScene
@export var spawn_interval: float = 1.0
@export var x_range: Vector2 = Vector2(-0.3, 0.3)
@export var y_range: Vector2 = Vector2(-0.2, 0.2)
@export var z_position: float = 0.0

var spawn_timer: Timer

func _ready():
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_spawn_bubble)
	add_child(spawn_timer)
	spawn_timer.start()

func _spawn_bubble():
	if bubble_scene == null:
		print("Bubble scene is not assigned!")
		return

	var x_pos = randf_range(x_range.x, x_range.y)
	var y_pos = randf_range(y_range.x, y_range.y)

	var bubble = bubble_scene.instantiate()
	bubble.global_transform.origin = Vector3(x_pos, y_pos, z_position)

	bubble.scale = Vector3(1.0, 1.0, 1.0)

	add_child(bubble)
