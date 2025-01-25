extends Node3D

@export var camera: Camera3D
@export var score_value_label: Label
@export var game_over_label: Label

var score: int = 0
var game_over: bool = false

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)

	score = 0
	if score_value_label:
		score_value_label.text = str(score)
	if game_over_label:
		game_over_label.hide()

func increment_score(value: int):
	score += value
	if score_value_label:
		score_value_label.text = str(score)

func end_game():
	# Activer le Game Over et mettre le jeu en pause
	game_over = true
	get_tree().paused = true
	if game_over_label:
		game_over_label.show()
		game_over_label.text = "Game Over! Cliquez pour rejouer."

func _unhandled_input(event):
	if game_over and event is InputEventMouseButton and event.pressed:
		_restart_game()

func _restart_game():
	game_over = false
	get_tree().paused = false
	var current_scene_path = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file(current_scene_path)
