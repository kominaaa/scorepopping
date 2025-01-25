extends Node3D

@export var bubble_scene: PackedScene  # Assigner votre scène de bulle ici
@export var spawn_interval: float = 1.0  # Intervalle de spawn en secondes
@export var x_range: Vector2 = Vector2(-0.7, 0.7)  # Plage de spawn en X
@export var y_range: Vector2 = Vector2(-0.4, 0.4)  # Plage de spawn en Y
@export var z_position: float = 0.0  # Position fixe sur Z

var spawn_timer: Timer
var bubbles: Array = []  # Liste des bulles présentes sur l'espace de jeu

func _ready():
	# Crée un timer pour gérer le spawn
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(Callable(self, "_spawn_bubble"))
	add_child(spawn_timer)

	# Spawner la première bulle immédiatement au hasard
	_spawn_bubble(true)

	# Démarrer le timer pour les prochaines bulles
	spawn_timer.start()

func _spawn_bubble(at_random: bool = false):
	# Vérifie que la scène de bulle est assignée
	if bubble_scene == null:
		print("Bubble scene is not assigned!")
		return

	# Nettoyer les bulles supprimées avant de calculer les positions
	_cleanup_bubbles()

	# Calcul de la position de la nouvelle bulle
	var spawn_pos: Vector3
	if at_random or bubbles.is_empty():
		# Génère une position aléatoire pour la première bulle
		spawn_pos = _random_position()
	else:
		# Trouve la position la plus éloignée des bulles existantes
		spawn_pos = _find_farthest_position()

	# Instance une bulle
	var bubble = bubble_scene.instantiate()
	bubble.global_transform.origin = spawn_pos

	# Fixe l'échelle par défaut pour ignorer l'échelle héritée
	bubble.scale = Vector3(1.0, 1.0, 1.0)

	# Connecter le signal "bubble_destroyed"
	bubble.connect("bubble_destroyed", Callable(self, "_on_bubble_destroyed"))

	# Ajoute la bulle à la scène et à la liste
	add_child(bubble)
	bubbles.append(bubble)

func _random_position() -> Vector3:
	# Génère une position aléatoire dans la plage définie
	var x_pos = randf_range(x_range.x, x_range.y)
	var y_pos = randf_range(y_range.x, y_range.y)
	return Vector3(x_pos, y_pos, z_position)

func _find_farthest_position() -> Vector3:
	# Teste plusieurs positions aléatoires et choisit la plus éloignée des bulles existantes
	var farthest_position: Vector3 = Vector3.ZERO
	var max_distance: float = -INF

	for i in range(50):  # Teste 50 positions aléatoires
		var candidate = _random_position()
		var min_distance = INF

		# Calculer la distance minimale entre cette position et toutes les bulles existantes
		for bubble in bubbles:
			if bubble and not bubble.is_queued_for_deletion():
				var distance = candidate.distance_to(bubble.global_transform.origin)
				min_distance = min(min_distance, distance)

		# Si cette position a la plus grande distance minimale, elle devient la meilleure
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
	# Retirer la bulle de la liste lorsqu'elle est supprimée
	if bubble in bubbles:
		bubbles.erase(bubble)
