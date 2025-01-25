extends Node3D

@export var camera: Camera3D
@export var bubble_scene: PackedScene

var bubbles: Array = []

func _ready():
	# Réinitialiser les bulles
	bubbles.clear()
	_spawn_bubble()

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
			if collider:
				if "on_clicked" in collider:  # Vérifie que la méthode existe
					collider.on_clicked(result.position)

func _spawn_bubble():
	# Instancier une nouvelle bulle
	var bubble = bubble_scene.instantiate()
	add_child(bubble)
	bubbles.append(bubble)

	# Connecter le signal collision_detected dynamiquement
	if "collision_detected" in bubble:
		bubble.collision_detected.connect(Callable(self, "_on_bubble_collision"))

func _on_bubble_collision():
	# Gérer la fin de partie et redémarrer
	print("Collision detected between bubbles! Restarting game...")
	_restart_game()

func _restart_game():
	# Déconnecter et supprimer les bulles existantes
	for bubble in bubbles:
		if "collision_detected" in bubble:
			bubble.collision_detected.disconnect(Callable(self, "_on_bubble_collision"))
		bubble.queue_free()  # Supprime la bulle de la scène
	bubbles.clear()  # Nettoyer la liste des bulles

	# Réinitialiser la scène en la rechargeant
	var current_scene_path = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file(current_scene_path)
