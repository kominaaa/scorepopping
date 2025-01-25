extends Node3D

@export var camera: Camera3D
@export var score_value_label: Label
@export var game_over_label: Label

var score: int = 0
var game_over: bool = false
var allow_restart: bool = false

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
	game_over = true
	allow_restart = false  # Bloque l'interaction immédiatement
	get_tree().paused = true
	if game_over_label:
		game_over_label.show()
		game_over_label.text = "Game Over! Click to play again."
	# Démarre un délai avant d'autoriser le restart
	_create_restart_delay_timer(2.0)

func _unhandled_input(event):
	if game_over and allow_restart and event is InputEventMouseButton and event.pressed:
		_restart_game()

func _restart_game():
	game_over = false
	get_tree().paused = false
	var current_scene_path = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file(current_scene_path)

func _create_restart_delay_timer(delay: float):
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = delay
	timer.connect("timeout", Callable(self, "_allow_restart"))
	add_child(timer)
	timer.start()

func _allow_restart():
	allow_restart = true
