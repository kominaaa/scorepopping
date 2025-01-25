extends Node3D

@export var bubble_scene: PackedScene
@export var spawn_interval: float = 1.0
@export var x_range: Vector2 = Vector2(-0.7, 0.7)
@export var y_range: Vector2 = Vector2(-0.4, 0.4)
@export var z_position: float = 0.0
@export var min_spawn_distance: float = 0.2
@export var max_spawn_attempts: int = 50

var spawn_timer: Timer
var bubbles: Array = []

func _ready():
	# Créer un timer pour gérer le spawn
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(Callable(self, "_spawn_bubble"))
	add_child(spawn_timer)

	# Spawner une première bulle
	_spawn_bubble(true)

	# Démarrer le Timer
	spawn_timer.start()

func _process(delta: float):
	# Vérification explicite des collisions entre les bulles
	_check_collisions()

func _spawn_bubble(at_random: bool = false):
	_cleanup_bubbles()

	var spawn_pos: Vector3
	var spawn_successful = false

	for attempt in range(max_spawn_attempts):
		if at_random or bubbles.is_empty():
			spawn_pos = _random_position()
		else:
			spawn_pos = _find_farthest_position()

		# Vérifier la distance minimale avec les autres bulles
		var is_valid_position = true
		for bubble in bubbles:
			if bubble and not bubble.is_queued_for_deletion():
				if spawn_pos.distance_to(bubble.global_transform.origin) < min_spawn_distance:
					is_valid_position = false
					break

		if is_valid_position:
			spawn_successful = true
			break

	# Spawner la bulle uniquement si une position valide a été trouvée
	if spawn_successful:
		var bubble = bubble_scene.instantiate()
		bubble.global_transform.origin = spawn_pos
		add_child(bubble)

		# Connecter les signaux
		bubble.connect("bubble_destroyed", Callable(self, "_on_bubble_destroyed"))
		bubble.connect("collision_detected", Callable(self, "_on_bubble_collision"))

		# Ajouter la bulle à la liste
		bubbles.append(bubble)
	else:
		print("No valid position found for spawning a bubble.")

func _random_position() -> Vector3:
	var x_pos = randf_range(x_range.x, x_range.y)
	var y_pos = randf_range(y_range.x, y_range.y)
	return Vector3(x_pos, y_pos, z_position)

func _find_farthest_position() -> Vector3:
	var farthest_position: Vector3 = Vector3.ZERO
	var max_distance: float = -INF

	for i in range(50):
		var candidate = _random_position()
		var min_distance = INF

		for bubble in bubbles:
			if bubble and not bubble.is_queued_for_deletion():
				var distance = candidate.distance_to(bubble.global_transform.origin)
				min_distance = min(min_distance, distance)

		if min_distance > max_distance:
			max_distance = min_distance
			farthest_position = candidate

	return farthest_position

func _cleanup_bubbles():
	var valid_bubbles = []
	for bubble in bubbles:
		if bubble and not bubble.is_queued_for_deletion():
			valid_bubbles.append(bubble)
	bubbles = valid_bubbles


func _on_bubble_destroyed(bubble: Node3D) -> void:
	if bubble in bubbles:
		bubbles.erase(bubble)

func _on_bubble_collision():
	print("Collision detected! Restarting game...")
	_restart_game()

func _check_collisions():
	# Vérifie les collisions entre toutes les bulles
	for i in range(bubbles.size()):
		for j in range(i + 1, bubbles.size()):
			var bubble_a = bubbles[i]
			var bubble_b = bubbles[j]

			if bubble_a and bubble_b and not bubble_a.is_queued_for_deletion() and not bubble_b.is_queued_for_deletion():
				var distance = bubble_a.global_transform.origin.distance_to(bubble_b.global_transform.origin)
				if distance < min_spawn_distance:
					_on_bubble_collision()

func _restart_game():
	for bubble in bubbles:
		if bubble:
			bubble.queue_free()
	bubbles.clear()

	# Réinitialiser la scène
	var current_scene_path = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file(current_scene_path)
