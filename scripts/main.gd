extends Node3D

@export var camera: Camera3D
@export var score_value_label: Label
@export var game_over_label: Label

var score: int = 0
var game_over: bool = false

func _ready():
	# Initialisation du score et du label de fin de partie
	score = 0
	if score_value_label:
		score_value_label.text = str(score)
	if game_over_label:
		game_over_label.visible = false  # Cacher le label au démarrage

func _input(event: InputEvent) -> void:
	# Si le jeu est terminé et le joueur clique, redémarrez le jeu
	if game_over and event is InputEventMouseButton and event.pressed:
		_restart_game()
		return

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

func end_game():
	# Met le jeu en pause et affiche le label de fin de partie
	game_over = true
	get_tree().paused = true
	if game_over_label:
		game_over_label.visible = true
		game_over_label.text = "Game Over! Cliquez pour rejouer."

func _restart_game():
	# Réinitialise le jeu
	game_over = false
	get_tree().paused = false
	var current_scene_path = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file(current_scene_path)
