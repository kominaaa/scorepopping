extends Node3D

@export var bubble_scene: PackedScene  # Scène de bulle
@export var spawn_interval: float = 1.0  # Intervalle de spawn en secondes
@export var x_range: Vector2 = Vector2(-0.7, 0.7)  # Plage de spawn en X
@export var y_range: Vector2 = Vector2(-0.4, 0.4)  # Plage de spawn en Y
@export var z_position: float = 0.0  # Position fixe sur Z

var spawn_timer: Timer
var bubbles: Array = []  # Liste des bulles actives

func _ready():
	# Créer un Timer pour gérer le spawn
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(Callable(self, "_spawn_bubble"))
	add_child(spawn_timer)

	# Spawner une première bulle
	_spawn_bubble(true)

	# Démarrer le Timer
	spawn_timer.start()

func _spawn_bubble(at_random: bool = false):
	_cleanup_bubbles()

	var spawn_pos: Vector3
	if at_random or bubbles.is_empty():
		spawn_pos = _random_position()
	else:
		spawn_pos = _find_farthest_position()

	# Instancier la bulle
	var bubble = bubble_scene.instantiate()
	bubble.global_transform.origin = spawn_pos
	add_child(bubble)

	# Connecter les signaux
	bubble.connect("bubble_destroyed", Callable(self, "_on_bubble_destroyed"))

	# Ajouter la bulle à la liste
	bubbles.append(bubble)

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
	# Supprimer les bulles qui ont été supprimées de la liste
	var valid_bubbles = []
	for bubble in bubbles:
		if bubble and not bubble.is_queued_for_deletion():
			valid_bubbles.append(bubble)
	bubbles = valid_bubbles

func _on_bubble_destroyed(bubble: Node3D) -> void:
	if bubble in bubbles:
		bubbles.erase(bubble)
